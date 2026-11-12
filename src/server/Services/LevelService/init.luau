--!strict
local BattleClock = require(game:GetService("ReplicatedStorage").Shared.Utilities.BattleClock)
--[[
	LevelService
	The ONLY system that advances campaign levels (PvZ-style). Owns preparation,
	Start Day countdown (3…0 overlay), Active spawn groups, victory/defeat,
	rewards, and progression. After 0 the day goes Active — monsters spawn in
	the forest and walk in (that march is setup time).
	Drives EnemyService for spawns; broadcasts state via LevelStateChanged.

	Victory keeps planted Brainrots on the plot and commits them for rejoin.
	Leave / autosave persist that checkpoint only — mid-day plants are discarded.
	Brainrot XP earned during an unfinished or failed day rolls back to the
	Start Day snapshot (committed on victory). Coin purse is STARTING_COINS
	on Day 1 only; after later days end the purse resets to 0. Defeat restores
	the last victory checkpoint on the same day; Rewind grants REWIND_COINS.
	Day Select wipes the lawn and the committed checkpoint.

	Milestone 8.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local GridConfig = require(Shared.Config.GridConfig)
local LevelConfig = require(Shared.Config.LevelConfig)
local ProgressConfig = require(Shared.Config.ProgressConfig)
local DevConfig = require(Shared.Config.DevConfig)
local Levels = require(Shared.Levels)
local Monsters = require(Shared.Monsters)
local Remotes = require(Shared.Remotes)
local Logger = require(Shared.Utilities.Logger)
local WeatherUtil = require(Shared.Utilities.WeatherUtil)

local LevelRun = require(script.LevelRun)
local ChallengeRun = require(script.ChallengeRun)
local ChallengeConfig = require(Shared.Config.DailyChallengeConfig)
local RetentionConfig = require(Shared.Config.RetentionConfig)
local RetentionTime = require(Shared.Utilities.RetentionTime)
local BrainrotService = require(script.Parent.BrainrotService)
local CoinService = require(script.Parent.CoinService)
local EnemyService = require(script.Parent.EnemyService)
local GraveService = require(script.Parent.GraveService)
local PlotService = require(script.Parent.PlotService)
local ProgressService = require(script.Parent.ProgressService)

local LevelService = {}
LevelService.Name = "LevelService"

local log = Logger.new(LevelService.Name)

local PauseScene = require(script.PauseScene)
local PHASE = Constants.PHASE

type PlayerState = {
	currentLevel: number,
	highestUnlockedLevel: number,
	playerHealth: number,
	phase: string,
	activeRun: LevelRun.LevelRun?,
	countdownEnd: number,
	activeStartedAt: number?,
	pausedAt: number?,
	resumeEnd: number?,
	attemptStartHearts: number?,
	bigWaveWarning: boolean,
	-- One-shot: consumed into LevelStateChanged intro arrays on the next broadcast.
	pendingMonsterIntroIds: { string }?,
	pendingBrainrotIntroIds: { string }?,
	pendingMechanicIntroIds: { string }?,
	-- "pending" after Day 40 is cleared, "active" while the Hidden Day runs.
	hiddenDay: string?,
	hiddenBrains: number,
	challenge: ChallengeRun.Run?,
	challengeResult: string?,
	challengeAttemptDay: number?,
	lawnRestored: boolean?,
}

local states: { [number]: PlayerState } = {}

local finishHidden: (player: Player, state: PlayerState, cleared: boolean) -> ()
local beginHiddenDay: (player: Player, state: PlayerState) -> ()

local function getDefinition(levelNumber: number)
	return Levels.getByNumber(levelNumber)
end

local function buildPayloadForPlayer(player: Player): { [string]: any }
	local state = states[player.UserId]
	if not state or not ProgressService.isHydrated(player) then
		return { loading = true }
	end

	local challenge = state.challenge
	local challengeActive = challenge ~= nil and not challenge.settling
	local hiddenShown = not challengeActive and (state.hiddenDay == "pending" or state.hiddenDay == "active")
	local definition = if challengeActive then ChallengeConfig.ENCOUNTER elseif hiddenShown then Levels.getHidden() else getDefinition(state.currentLevel)
	local levelName = if definition then definition.name else "Unknown"
	local payload: { [string]: any } = {
		phase = state.phase,
		levelNumber = state.currentLevel,
		levelName = levelName,
		highestUnlockedLevel = state.highestUnlockedLevel,
		starGoals = if not challengeActive and not hiddenShown then require(Shared.Utilities.FarmProgression).goals(state.currentLevel) else nil,
		playerHealth = if challenge and not challenge.settling then challenge.health else state.playerHealth,
		maxPlayerHealth = if challengeActive then ChallengeConfig.HEARTS else ProgressConfig.MAX_PLAYER_HEALTH,
		challengeActive = challengeActive,
		challengeAvailable = state.phase == PHASE.Preparation and challenge == nil
			and state.lawnRestored == true and state.highestUnlockedLevel >= RetentionConfig.CHALLENGE_MINIMUM_DAY,
		challengeReward = RetentionConfig.brainsFor(RetentionConfig.CHALLENGE_BRAINS, state.highestUnlockedLevel),
		challengeResult = state.challengeResult,
		bigWaveWarning = state.bigWaveWarning,
		canStart = state.phase == PHASE.Preparation and challenge == nil,
		progress = 0,
		weather = if definition then definition.weather else nil,
		hiddenDay = hiddenShown,
	}

	if state.activeStartedAt and (state.phase == PHASE.Active or state.phase == PHASE.Paused or state.phase == PHASE.Resuming) then
		payload.elapsedSeconds = math.max(0, math.floor(BattleClock.now(player) - state.activeStartedAt))
	end

	payload.dayPaused = BattleClock.isPaused(player)
	if state.phase == PHASE.Resuming and state.resumeEnd then payload.resumeRemaining = math.max(0, state.resumeEnd - os.clock()) end
	if state.phase == PHASE.Countdown then
		payload.countdownRemaining = math.max(0, state.countdownEnd - os.clock())
	end

	if state.activeRun and (state.phase == PHASE.Active or state.phase == PHASE.Paused or state.phase == PHASE.Resuming) then
		local plotModel = PlotService.getPlotModel(player)
		if plotModel then
			local alive = EnemyService.countOnPlot(plotModel)
			local run = state.activeRun
			if run.totalToSpawn > 0 then
				payload.progress = math.clamp((run.totalSpawned - alive) / run.totalToSpawn, 0, 1)
			end
			payload.monstersRemaining = alive
		end
	end

	if state.pendingBrainrotIntroIds and #state.pendingBrainrotIntroIds > 0 then
		payload.introducedBrainrotIds = state.pendingBrainrotIntroIds
		state.pendingBrainrotIntroIds = nil
	end
	if state.pendingMonsterIntroIds and #state.pendingMonsterIntroIds > 0 then
		payload.introducedMonsterIds = state.pendingMonsterIntroIds
		payload.introducedMonsterId = state.pendingMonsterIntroIds[1]
		state.pendingMonsterIntroIds = nil
	end
	if state.pendingMechanicIntroIds and #state.pendingMechanicIntroIds > 0 then
		payload.introducedMechanicIds = state.pendingMechanicIntroIds
		state.pendingMechanicIntroIds = nil
	end

	return payload
end

local function broadcast(player: Player)
	Remotes.getEvent("LevelStateChanged"):FireClient(player, buildPayloadForPlayer(player))
end

local function setPhase(player: Player, state: PlayerState, phase: string)
	local resuming = state.phase == PHASE.Resuming and phase == PHASE.Active
	state.phase = phase
	if not resuming and phase ~= PHASE.Paused and phase ~= PHASE.Resuming then state.bigWaveWarning = false end
	broadcast(player)
end

-- NightFog plant stripping. Lawn sand is client-only (DesertVisuals).
local function applyWeatherRules(player: Player, state: PlayerState)
	local definition = getDefinition(state.currentLevel)
	local weather = if definition then definition.weather else nil
	if not WeatherUtil.isNightFog(weather) then
		return
	end
	BrainrotService.clearFogBlockedPlacements(player, weather)
	local SaveService = require(script.Parent.SaveService)
	SaveService.commitLawn(player)
end

local function queueIntros(player: Player, state: PlayerState)
	ProgressService.consumeReachUnlocksForDay(player, state.currentLevel)
	local brainrotIds = ProgressService.consumeBrainrotIntrosForDay(player, state.currentLevel)
	local mechanicIds = ProgressService.consumeMechanicIntrosForDay(player, state.currentLevel)
	local monsterIds = ProgressService.consumeMonsterIntrosForDay(player, state.currentLevel)
	state.pendingBrainrotIntroIds = if #brainrotIds > 0 then brainrotIds else nil
	state.pendingMechanicIntroIds = if #mechanicIds > 0 then mechanicIds else nil
	state.pendingMonsterIntroIds = if #monsterIds > 0 then monsterIds else nil
	if #brainrotIds > 0 or #mechanicIds > 0 or #monsterIds > 0 then
		local SaveService = require(script.Parent.SaveService)
		SaveService.saveNow(player, "unit_intro")
	end
end

local function beginPreparation(player: Player, state: PlayerState)
	state.activeRun = nil
	state.bigWaveWarning = false
	queueIntros(player, state)
	applyWeatherRules(player, state)
	local MagnetService = require(script.Parent.MagnetService)
	MagnetService.pauseCooldown(player)
	setPhase(player, state, PHASE.Preparation)
end

-- Clear combat leftovers. Brainrots stay on victory; coin purse depends on next day.
local function clearTransientCombat(player: Player)
	local plotModel = PlotService.getPlotModel(player)
	if plotModel then
		EnemyService.clearPlot(plotModel)
		CoinService.clearPlot(plotModel)
		GraveService.clearPlot(plotModel)
	end
end

-- Full wipe: Brainrots + monsters + ground coins (defeat / day select).
local function clearLawn(player: Player)
	local plotModel = PlotService.getPlotModel(player)
	if plotModel then
		BrainrotService.clearPlot(plotModel)
		EnemyService.clearPlot(plotModel)
		CoinService.clearPlot(plotModel)
		GraveService.clearPlot(plotModel)
	end
end

-- Pocket coins that are about to be wiped → brains. Ground coins do not count.
local function grantLeftoverCoinBrains(player: Player): number
	local leftover = CoinService.getBalance(player)
	local brains = ProgressService.brainsFromLeftoverCoins(leftover)
	if brains > 0 then
		ProgressService.addBrains(player, brains)
	end
	return brains
end

finishHidden = function(player: Player, state: PlayerState, cleared: boolean)
	require(script.Parent.RetentionService).endRun(player)
	if state.hiddenDay ~= "active" then
		return
	end
	local earned = state.hiddenBrains
	state.hiddenDay = nil
	state.hiddenBrains = 0

	local SaveService = require(script.Parent.SaveService)
	if cleared then
		clearTransientCombat(player)
		ProgressService.commitBrainrotXp(player)
		SaveService.commitLawn(player)
	else
		ProgressService.restoreBrainrotXpCheckpoint(player)
		state.playerHealth = ProgressConfig.MAX_PLAYER_HEALTH
		clearLawn(player)
		SaveService.restoreCommittedLawn(player)
	end

	local leftoverBrains = grantLeftoverCoinBrains(player)
	if earned > 0 then
		ProgressService.addBrains(player, earned)
	end
	CoinService.applyDayPurse(player, state.currentLevel)

	state.activeRun = nil
	state.phase = PHASE.Victory
	state.bigWaveWarning = false
	local MagnetService = require(script.Parent.MagnetService)
	MagnetService.pauseCooldown(player)
	local nextDef = getDefinition(state.currentLevel)
	Remotes.getEvent("LevelStateChanged"):FireClient(player, {
		phase = PHASE.Victory,
		levelNumber = state.currentLevel,
		levelName = "Hidden Day",
		highestUnlockedLevel = state.highestUnlockedLevel,
		playerHealth = state.playerHealth,
		maxPlayerHealth = ProgressConfig.MAX_PLAYER_HEALTH,
		canStart = false,
		progress = 0,
		bigWaveWarning = false,
		weather = if nextDef then nextDef.weather else nil,
		hiddenDay = true,
		reward = {
			hiddenDay = true,
			brains = earned,
			leftoverBrains = leftoverBrains,
		},
	})
	log:info(
		string.format(
			"%s finished hidden day (%s, +%d brains, +%d from leftover coins)",
			player.Name,
			if cleared then "cleared" else "defeated",
			earned,
			leftoverBrains
		)
	)
	SaveService.saveNow(player, "hidden_day")
end

local function onVictory(player: Player, state: PlayerState)
	local definition = getDefinition(state.currentLevel)
	if not definition then
		return
	end

	-- Keep planted Brainrots (and their HP); clear fight leftovers.
	clearTransientCombat(player)

	local stars, shards = require(script.Parent.FarmProgressionService).resolve(player, definition.number, state.playerHealth)
	ProgressService.recordDayStars(player, definition.number, stars)
	ProgressService.addMonsterShards(player, shards)
	local clearedNumber = definition.number
	local leftoverBrains = grantLeftoverCoinBrains(player)
	local brainsEarned = require(Shared.Utilities.FarmProgression).brains(ProgressService.brainsForLevel(clearedNumber), stars)
	local unlockedBrainrotId = ProgressService.grantUnlockForLevel(player, clearedNumber)
	ProgressService.addBrains(player, brainsEarned)
	ProgressService.incrementStat(player, ProgressConfig.STAT_LEVELS_CLEARED)
	require(script.Parent.RetentionService).recordEvent(player, "CampaignDayCleared", 1, "Campaign")

	if state.currentLevel >= state.highestUnlockedLevel then
		state.highestUnlockedLevel = math.min(state.currentLevel + 1, Levels.count())
	end

	local nextDefinition = Levels.getByNumber(state.currentLevel + 1)
	if nextDefinition then
		state.currentLevel += 1
	end

	-- Day 1 purse = STARTING_COINS; later days start at 0.
	CoinService.applyDayPurse(player, state.currentLevel)

	-- Hearts stay progressive across days (only refill on defeat retry / reset).
	state.activeRun = nil
	state.phase = PHASE.Victory
	state.bigWaveWarning = false
	if clearedNumber == 40 then
		state.hiddenDay = "pending"
	end
	local MagnetService = require(script.Parent.MagnetService)
	MagnetService.pauseCooldown(player)
	local enteringHidden = state.hiddenDay == "pending"
	local nextDef = if enteringHidden then Levels.getHidden() else getDefinition(state.currentLevel)
	Remotes.getEvent("LevelStateChanged"):FireClient(player, {
		phase = PHASE.Victory,
		levelNumber = state.currentLevel,
		levelName = if enteringHidden then "Hidden Day" elseif nextDef then nextDef.name else "Unknown",
		highestUnlockedLevel = state.highestUnlockedLevel,
		playerHealth = state.playerHealth,
		maxPlayerHealth = ProgressConfig.MAX_PLAYER_HEALTH,
		canStart = false,
		progress = 0,
		bigWaveWarning = false,
		weather = if nextDef then nextDef.weather else nil,
		hiddenDay = enteringHidden,
		reward = {
			clearedLevel = clearedNumber,
			stars = stars,
			monsterShards = shards,
			brains = brainsEarned,
			leftoverBrains = leftoverBrains,
			unlockedBrainrotId = unlockedBrainrotId,
		},
	})
	log:info(
		string.format(
			"%s cleared level %d (+%d brains, +%d from leftover coins)",
			player.Name,
			clearedNumber,
			brainsEarned,
			leftoverBrains
		)
	)

	-- Commit lawn checkpoint, then persist (mid-day plants after this only stick on next victory).
	ProgressService.commitBrainrotXp(player)
	local SaveService = require(script.Parent.SaveService)
	SaveService.commitLawn(player)
	SaveService.saveNow(player, "victory")
end

local function onDefeat(player: Player, state: PlayerState)
	require(script.Parent.FarmProgressionService).finish(player)
	require(script.Parent.RetentionService).endRun(player)
	local failedLevel = state.currentLevel
	state.activeRun = nil
	state.playerHealth = ProgressConfig.MAX_PLAYER_HEALTH
	-- Stay on the failed day; restore last victory lawn (do not wipe checkpoint).
	-- Brainrot XP from this failed day rolls back to the Start Day snapshot.
	ProgressService.restoreBrainrotXpCheckpoint(player)
	clearLawn(player)
	local SaveService = require(script.Parent.SaveService)
	SaveService.restoreCommittedLawn(player)
	local leftoverBrains = grantLeftoverCoinBrains(player)
	CoinService.applyDayPurse(player, failedLevel)
	applyWeatherRules(player, state)
	local MagnetService = require(script.Parent.MagnetService)
	MagnetService.pauseCooldown(player)
	setPhase(player, state, PHASE.Defeat)
	if leftoverBrains > 0 then
		log:info(
			string.format(
				"%s defeated on day %d — awaiting rewind (+%d brains from leftover coins)",
				player.Name,
				failedLevel,
				leftoverBrains
			)
		)
	else
		log:info(string.format("%s defeated on day %d — awaiting rewind", player.Name, failedLevel))
	end
	SaveService.saveNow(player, "defeat")
end

-- Game Over → Rewind: same day, Preparation (lawn already restored on defeat).
local function onRewindDay(player: Player)
	local state = states[player.UserId]
	if not state or state.phase ~= PHASE.Defeat then
		return
	end
	CoinService.applyRewindPurse(player)
	beginPreparation(player, state)
	local SaveService = require(script.Parent.SaveService)
	SaveService.saveNow(player, "rewind")
	log:info(string.format("%s rewound day %d", player.Name, state.currentLevel))
end

local function onContinueVictory(player: Player)
	local state = states[player.UserId]
	if not state or state.phase ~= PHASE.Victory then
		return
	end
	beginPreparation(player, state)
	log:info(string.format("%s continued after day victory", player.Name))
end

local function finishChallenge(player: Player, state: PlayerState, cleared: boolean)
	local run = state.challenge
	if not run or run.settling then return end
	local plot = PlotService.getPlotModel(player)
	if not plot then return end
	run.settling = true
	state.activeRun = nil
	clearTransientCombat(player)
	ChallengeRun.restore(player, plot, run)
	local analytics = require(script.Parent.RetentionService.Analytics)
	analytics.log(player, if cleared then "Completed" else "Failed", nil, nil, "Challenge")
	state.challengeResult = if cleared then "Challenge cleared · saving reward…" else "Challenge lost · retry for free"
	setPhase(player, state, PHASE.Preparation)
	if not cleared then
		state.challenge = nil
		broadcast(player)
		return
	end

	-- UpdateAsync may yield. Other plots keep ticking while this run settles.
	local day = RetentionTime.dayKey(os.time())
	task.spawn(function()
		local save = require(script.Parent.SaveService)
		while player.Parent and state.challenge == run do
			local ok, reason, reward = save.claimRetentionReward(player, "Challenge", day, ChallengeConfig.ENCOUNTER.id)
			if state.challenge ~= run or not player.Parent then return end
			if reason == "Busy" then
				task.wait(0.2)
				continue
			end
			state.challenge = nil
			if ok then
				state.challengeResult = string.format("Challenge cleared · +%d brains", reward or 0)
				analytics.log(player, "Claimed", reward, nil, "Challenge")
			elseif reason == "AlreadyClaimed" then
				state.challengeResult = "Challenge cleared · today's reward earned"
			else
				state.challengeResult = "Reward unavailable · retry for free"
				analytics.log(player, "Rejected", nil, reason, "Challenge")
			end
			broadcast(player)
			return
		end
	end)
end

local function tickActivePlayer(player: Player, state: PlayerState)
	local run = state.activeRun
	if not run or state.phase ~= PHASE.Active then
		return
	end

	local plotModel = PlotService.getPlotModel(player)
	if not plotModel then
		return
	end

	local now = BattleClock.now(player)
	local step = run:advance(now)

	if step.bigWaveWarning then
		state.bigWaveWarning = true
		broadcast(player)
	elseif step.bigWaveWarningEnd then
		state.bigWaveWarning = false
		broadcast(player)
	end

	if step.spawn then
		local group = step.spawnGroup
		if group then
			local monsterDef = Monsters.get(group.monsterId)
			local span = if monsterDef and monsterDef.laneSpan then monsterDef.laneSpan else 1
			local row = if type(group.row) == "number"
				then math.clamp(math.floor(group.row), 1, GridConfig.ROWS - span + 1)
				else LevelRun.randomRowForSpan(span)
			local allowDuplicate = state.hiddenDay == "active" and group.monsterId == "GoblinElite"
			local instanceId = EnemyService.spawn(plotModel, group.monsterId, row, allowDuplicate)
			if not instanceId then
				log:warn(string.format(
					"spawn attempt %d/%d rejected for %s on %s row %d",
					run.totalSpawned,
					run.totalToSpawn,
					group.monsterId,
					plotModel.Name,
					row
				))
				if state.challenge then
					finishChallenge(player, state, false)
					return
				end
			end
		end
	end

	if run:isDoneSpawning() then
		GraveService.notifyWavesComplete(plotModel)
		if EnemyService.countOnPlot(plotModel) == 0 and not GraveService.hasPending(plotModel) then
			if state.challenge then
				finishChallenge(player, state, true)
			elseif state.hiddenDay == "active" then
				finishHidden(player, state, true)
			else
				onVictory(player, state)
			end
			return
		end
	end

	broadcast(player)
end

-- Countdown overlay (COUNTDOWN_TIME) then Active.
local function beginCountdown(player: Player, state: PlayerState)
	state.activeRun = nil
	state.activeStartedAt = nil
	state.attemptStartHearts = state.playerHealth
	state.countdownEnd = os.clock() + LevelConfig.COUNTDOWN_TIME
	if not state.challenge then require(script.Parent.MagnetService).resumeCooldown(player) end
	setPhase(player, state, PHASE.Countdown)
end

-- Countdown → Active. Live flow always uses COUNTDOWN_TIME > 0.
local function beginActiveRun(player: Player, state: PlayerState, definition)
	local plotModel = PlotService.getPlotModel(player)
	if plotModel then
		EnemyService.clearPlot(plotModel)
		GraveService.clearPlot(plotModel)
	end

	state.countdownEnd = 0
	state.activeRun = LevelRun.new(definition, plotModel)
	state.activeStartedAt = BattleClock.now(player)
	if not state.challenge and state.hiddenDay ~= "active" then
		require(script.Parent.FarmProgressionService).begin(player, definition.number)
	end
	if not state.challenge then require(script.Parent.MagnetService).resumeCooldown(player) end
	local DamageMeterService = require(script.Parent.DamageMeterService)
	DamageMeterService.reset(player)
	setPhase(player, state, PHASE.Active)
	if not state.challenge then
		require(script.Parent.RetentionService).beginRun(player, if state.hiddenDay == "active" then "Hidden" else "Campaign")
	end

	-- Fresh seed-packet recharges each Start Day (PvZ-style).
	BrainrotService.clearPlantCooldowns(player)

	if plotModel then
		GraveService.spawnForDay(plotModel, definition)
	end
end

beginHiddenDay = function(player: Player, state: PlayerState)
	state.hiddenDay = "active"
	state.hiddenBrains = 0
	ProgressService.checkpointBrainrotXp(player)
	if ProgressService.introduceMonster(player, "GoblinKing") then
		state.pendingMonsterIntroIds = { "GoblinKing" }
		local SaveService = require(script.Parent.SaveService)
		SaveService.saveNow(player, "unit_intro")
	end
	local plotModel = PlotService.getPlotModel(player)
	if plotModel then
		GraveService.clearPlot(plotModel)
	end
	local definition = Levels.getHidden()
	if LevelConfig.COUNTDOWN_TIME > 0 then
		beginCountdown(player, state)
	else
		beginActiveRun(player, state, definition)
	end
end

local function tickCountdown(player: Player, state: PlayerState)
	if state.phase ~= PHASE.Countdown then
		return
	end

	if os.clock() < state.countdownEnd then
		return
	end

	local definition = if state.challenge then ChallengeConfig.ENCOUNTER elseif state.hiddenDay == "active" then Levels.getHidden() else getDefinition(state.currentLevel)
	if not definition then
		beginPreparation(player, state)
		return
	end

	beginActiveRun(player, state, definition)
end

local function onStartLevel(player: Player)
	local state = states[player.UserId]
	if not state or not ProgressService.isHydrated(player) then
		return
	end
	-- Defeat uses RewindDay → Preparation; StartLevel only from prep.
	if state.phase ~= PHASE.Preparation or state.challenge then
		return
	end

	local definition = getDefinition(state.currentLevel)
	if not definition then
		return
	end

	state.challengeResult = nil
	-- Brief 3…0 overlay, then Active so players plant while monsters march in.
	if state.hiddenDay == "pending" then
		beginHiddenDay(player, state)
		return
	end
	ProgressService.checkpointBrainrotXp(player)
	if LevelConfig.COUNTDOWN_TIME > 0 then
		beginCountdown(player, state)
	else
		beginActiveRun(player, state, definition)
	end
end

local function onStartChallenge(player: Player)
	local state = states[player.UserId]
	local plot = PlotService.getPlotModel(player)
	if not state or not plot or not state.lawnRestored or state.challenge or state.phase ~= PHASE.Preparation then return end
	if state.highestUnlockedLevel < RetentionConfig.CHALLENGE_MINIMUM_DAY or not ProgressService.isHydrated(player) then return end
	if require(script.Parent.SaveService).isProgressionLocked(player) then return end
	clearTransientCombat(player)
	state.challenge = ChallengeRun.begin(player, plot)
	state.challengeResult = nil
	local day = RetentionTime.dayKey(os.time())
	require(script.Parent.RetentionService.Analytics).log(player,
		if state.challengeAttemptDay == day then "Retried" else "Attempted", nil, nil, "Challenge")
	state.challengeAttemptDay = day
	beginCountdown(player, state)
end

local function onHouseBreach(plotModel: Model, _row: number)
	local ownerUserId = plotModel:GetAttribute("OwnerUserId")
	if type(ownerUserId) ~= "number" then
		return
	end

	local player = Players:GetPlayerByUserId(ownerUserId)
	local state = if player then states[player.UserId] else nil
	if not player or not state or state.phase ~= PHASE.Active then
		return
	end

	local challenge = state.challenge
	if challenge then
		challenge.health = math.max(0, challenge.health - 1)
		broadcast(player)
		if challenge.health == 0 then finishChallenge(player, state, false) end
		return
	end
	require(script.Parent.FarmProgressionService).breach(player)
	state.playerHealth = math.max(0, state.playerHealth - 1)
	require(script.Parent.RetentionService).recordEvent(player, "HouseBreached", 1,
		if state.hiddenDay == "active" then "Hidden" else "Campaign")
	if state.playerHealth <= 0 and state.hiddenDay == "active" then
		finishHidden(player, state, false)
		return
	end
	broadcast(player)
	if state.playerHealth <= 0 then
		onDefeat(player, state)
	end
end

local function onSelectLevel(player: Player, rawLevel: unknown)
	local state = states[player.UserId]
	if not state or not ProgressService.isHydrated(player) then
		return
	end
	-- Day Select from Preparation only (Defeat must Rewind first).
	if state.phase ~= PHASE.Preparation or state.challenge then
		return
	end
	if type(rawLevel) ~= "number" then
		return
	end

	local levelNumber = math.floor(rawLevel)
	if levelNumber < 1 or levelNumber > state.highestUnlockedLevel then
		return
	end
	if not getDefinition(levelNumber) then
		return
	end

	state.currentLevel = levelNumber
	state.hiddenDay = nil
	state.hiddenBrains = 0
	-- Keep progressive hearts when switching days (refill only on defeat / reset).
	-- Day Select starts a fresh lawn — carry-over only applies when advancing via victory.
	state.activeRun = nil
	state.countdownEnd = 0
	state.bigWaveWarning = false

	clearLawn(player)
	CoinService.applyDayPurse(player, levelNumber)
	beginPreparation(player, state)

	-- Persist empty lawn so rejoin doesn't restore plants from the previous day.
	local SaveService = require(script.Parent.SaveService)
	SaveService.clearCommittedLawn(player)
	SaveService.saveNow(player, "day_select")
end

local function initPlayer(player: Player)
	-- SaveService may hydrate an existing Studio player before LevelService.start().
	if states[player.UserId] then return end
	states[player.UserId] = {
		currentLevel = 1,
		highestUnlockedLevel = 1,
		playerHealth = ProgressConfig.MAX_PLAYER_HEALTH,
		phase = PHASE.Preparation,
		activeRun = nil,
		countdownEnd = 0,
		bigWaveWarning = false,
		pendingMonsterIntroIds = nil,
		pendingBrainrotIntroIds = nil,
		pendingMechanicIntroIds = nil,
		hiddenDay = nil,
		hiddenBrains = 0,
	}
	task.defer(function()
		broadcast(player)
	end)
end

local function cleanupPlayer(player: Player)
	-- Defer so SaveService can snapshot level/hearts on the same PlayerRemoving
	-- wave before state is wiped (LevelService starts before SaveService).
	local userId = player.UserId
	task.defer(function()
		PauseScene.resume(player, 0)
		BattleClock.clear(player)
		states[userId] = nil
	end)
end

function LevelService.getClientState(player: Player): { [string]: any }
	return buildPayloadForPlayer(player)
end

function LevelService.getWeather(player: Player): string?
	local state = states[player.UserId]
	if not state then
		return nil
	end
	if state.challenge and not state.challenge.settling then return ChallengeConfig.ENCOUNTER.weather end
	local hiddenShown = state.hiddenDay == "pending" or state.hiddenDay == "active"
	local definition = if hiddenShown then Levels.getHidden() else getDefinition(state.currentLevel)
	return if definition then definition.weather else nil
end

-- Called after the committed lawn is restored on join. Challenge entry waits for this handoff.
function LevelService.applyWeatherRulesForPlayer(player: Player)
	local state = states[player.UserId]
	if state then
		applyWeatherRules(player, state)
		state.lawnRestored = true
		broadcast(player)
	end
end

function LevelService.getCurrentDayForUser(userId: number): number
	local state = states[userId]
	if not state then
		return 1
	end
	return if state.challenge and not state.challenge.settling then ChallengeConfig.ENCOUNTER.number else state.currentLevel
end

function LevelService.isChallengeActiveForUser(userId: number): boolean
	local state = states[userId]
	return state ~= nil and state.challenge ~= nil and not state.challenge.settling
end

function LevelService.isHiddenDayActiveForUser(userId: number): boolean
	local state = states[userId]
	return state ~= nil and state.hiddenDay == "active"
end

function LevelService.getSaveProgress(player: Player): (number, number, number)
	local state = states[player.UserId]
	if not state then
		return 1, 1, ProgressConfig.MAX_PLAYER_HEALTH
	end
	return state.currentLevel, state.highestUnlockedLevel,
		if BattleClock.isPaused(player) and not state.challenge then state.attemptStartHearts or state.playerHealth else state.playerHealth
end

function LevelService.isHiddenDayPending(player: Player): boolean
	local state = states[player.UserId]
	return state ~= nil and state.hiddenDay ~= nil
end

function LevelService.applySaveProgress(
	player: Player,
	currentLevel: number,
	highestUnlockedLevel: number,
	playerHealth: number,
	hiddenDayPending: boolean?
)
	initPlayer(player)
	local state = states[player.UserId]
	if not state then
		return
	end

	local maxLevel = Levels.count()
	local sanitizedCurrent = math.clamp(math.floor(currentLevel), 1, math.max(1, maxLevel))
	local sanitizedHighest = math.clamp(math.floor(highestUnlockedLevel), sanitizedCurrent, math.max(1, maxLevel))

	state.challenge = nil
	state.challengeResult = nil
	state.currentLevel = sanitizedCurrent
	state.highestUnlockedLevel = sanitizedHighest
	state.playerHealth = math.clamp(math.floor(playerHealth), 1, ProgressConfig.MAX_PLAYER_HEALTH)
	state.hiddenDay = if hiddenDayPending == true then "pending" else nil
	state.hiddenBrains = 0
	state.activeRun = nil
	state.countdownEnd = 0
	state.bigWaveWarning = false
	state.phase = PHASE.Preparation

	local plotModel = PlotService.getPlotModel(player)
	if plotModel then
		EnemyService.clearPlot(plotModel)
		GraveService.clearPlot(plotModel)
	end

	broadcast(player)
end

-- TEMP cheat: jump current + unlocked day (see DevConfig.FORCE_DAY).
function LevelService.applyDevDay(player: Player): number?
	if not DevConfig.isActive() then
		return nil
	end
	local forceDay = DevConfig.FORCE_DAY
	if type(forceDay) ~= "number" or forceDay < 1 then
		return nil
	end

	local state = states[player.UserId]
	if not state then
		return nil
	end

	local maxLevel = math.max(1, Levels.count())
	local target = math.clamp(math.floor(forceDay), 1, maxLevel)
	state.currentLevel = target
	state.highestUnlockedLevel = math.max(state.highestUnlockedLevel, target)
	state.activeRun = nil
	state.countdownEnd = 0
	state.bigWaveWarning = false
	state.phase = PHASE.Preparation
	state.hiddenDay = nil
	state.hiddenBrains = 0

	broadcast(player)

	return target
end

-- After join hydrate + optional FORCE_DAY, show any pending unit intros once.
function LevelService.queueJoinIntros(player: Player)
	local state = states[player.UserId]
	if not state then
		return
	end
	queueIntros(player, state)
	broadcast(player)
end

-- Placement and coin income are only allowed while a level is in progress.
function LevelService.isLevelActive(player: Player): boolean
	local state = states[player.UserId]
	return state ~= nil and state.phase == PHASE.Active
end

local function onPauseDay(player: Player)
	local state = states[player.UserId]
	if not state or state.phase ~= PHASE.Active then return end
	local Save = require(script.Parent.SaveService)
	if Save.isProgressionLocked(player) then return end
	local plot = PlotService.getPlotModel(player)
	if not plot then return end
	state.pausedAt = os.clock()
	BattleClock.setPaused(player, true)
	plot:SetAttribute("DayPaused", true)
	require(script.Parent.CombatService).clearPlot(plot)
	require(script.Parent.BrainrotService.Abilities.LineBomb).clearProjectiles(plot)
	PauseScene.pause(player)
	setPhase(player, state, PHASE.Paused)
end

local function onResumeDay(player: Player)
	local state = states[player.UserId]
	if not state or state.phase ~= PHASE.Paused then return end
	state.resumeEnd = os.clock() + LevelConfig.PAUSE_RESUME_SECONDS
	setPhase(player, state, PHASE.Resuming)
end

local function tickResume(player: Player, state: PlayerState)
	if not state.resumeEnd or os.clock() < state.resumeEnd then broadcast(player); return end
	local duration = os.clock() - (state.pausedAt or os.clock())
	state.resumeEnd, state.pausedAt = nil, nil
	BrainrotService.resumeDayTimers(player, duration)
	require(script.Parent.MagnetService).resumeDayTimers(player, duration)
	BattleClock.setPaused(player, false)
	PauseScene.resume(player, duration)
	local plot = PlotService.getPlotModel(player)
	if plot then plot:SetAttribute("DayPaused", nil) end
	setPhase(player, state, PHASE.Active)
end

function LevelService.init()
	if (LevelService :: any)._remotesConnected then
		return
	end
	(LevelService :: any)._remotesConnected = true

	EnemyService.setHouseBreachHandler(onHouseBreach)
	EnemyService.setKillHandler(function(ownerUserId: number, monsterId: string)
		local player = Players:GetPlayerByUserId(ownerUserId)
		local state = states[ownerUserId]
		if not player or not state or state.hiddenDay ~= "active" or state.phase ~= PHASE.Active then
			return
		end
		local amount = ProgressConfig.HIDDEN_DAY_KILL_BRAINS[monsterId]
		if type(amount) ~= "number" or amount <= 0 then
			return
		end
		state.hiddenBrains += amount
	end)

	Remotes.getEvent("PauseDay").OnServerEvent:Connect(onPauseDay)
	Remotes.getEvent("ResumeDay").OnServerEvent:Connect(onResumeDay)
	Remotes.getEvent("StartLevel").OnServerEvent:Connect(function(player: Player)
		if BattleClock.isPaused(player) then return end
		onStartLevel(player)
	end)
	Remotes.getEvent("StartDailyChallenge").OnServerEvent:Connect(function(player, ...) if not BattleClock.isPaused(player) then onStartChallenge(player, ...) end end)
	Remotes.getEvent("SelectLevel").OnServerEvent:Connect(function(player, ...) if not BattleClock.isPaused(player) then onSelectLevel(player, ...) end end)
	Remotes.getEvent("RewindDay").OnServerEvent:Connect(function(player, ...) if not BattleClock.isPaused(player) then onRewindDay(player, ...) end end)
	Remotes.getEvent("ContinueVictory").OnServerEvent:Connect(function(player, ...) if not BattleClock.isPaused(player) then onContinueVictory(player, ...) end end)
end

function LevelService.start()
	if (LevelService :: any)._started then
		return
	end
	(LevelService :: any)._started = true

	Remotes.getFunction("RequestState").OnServerInvoke = function(player: Player)
		local MagnetService = require(script.Parent.MagnetService)
		local DamageMeterService = require(script.Parent.DamageMeterService)
		return {
			coins = CoinService.getBalance(player),
			level = LevelService.getClientState(player),
			profile = ProgressService.getClientState(player),
			plantCooldowns = BrainrotService.getPlantCooldowns(player),
			magnet = MagnetService.getClientState(player),
			damageMeter = DamageMeterService.getClientState(player),
			retention = require(script.Parent.RetentionService).getClientState(player),
		}
	end

	Players.PlayerAdded:Connect(initPlayer)
	Players.PlayerRemoving:Connect(cleanupPlayer)
	for _, player in Players:GetPlayers() do
		initPlayer(player)
	end

	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, player in Players:GetPlayers() do
				local state = states[player.UserId]
				if not state then
					continue
				end
				tickCountdown(player, state)
				if state.phase == PHASE.Resuming then
					tickResume(player, state)
				elseif state.phase == PHASE.Countdown then
					broadcast(player)
				elseif state.phase == PHASE.Active then
					tickActivePlayer(player, state)
				end
			end
		end
	end)

	log:info("started")
end

return LevelService
