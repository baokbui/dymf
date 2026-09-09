--!strict
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
local BrainrotService = require(script.Parent.BrainrotService)
local CoinService = require(script.Parent.CoinService)
local EnemyService = require(script.Parent.EnemyService)
local GraveService = require(script.Parent.GraveService)
local PlotService = require(script.Parent.PlotService)
local ProgressService = require(script.Parent.ProgressService)

local LevelService = {}
LevelService.Name = "LevelService"

local log = Logger.new(LevelService.Name)

local PHASE = Constants.PHASE

type PlayerState = {
	currentLevel: number,
	highestUnlockedLevel: number,
	playerHealth: number,
	phase: string,
	activeRun: LevelRun.LevelRun?,
	countdownEnd: number,
	bigWaveWarning: boolean,
	-- One-shot: consumed into LevelStateChanged intro arrays on the next broadcast.
	pendingMonsterIntroIds: { string }?,
	pendingBrainrotIntroIds: { string }?,
}

local states: { [number]: PlayerState } = {}

local function getDefinition(levelNumber: number)
	return Levels.getByNumber(levelNumber)
end

local function buildPayloadForPlayer(player: Player): { [string]: any }
	local state = states[player.UserId]
	if not state then
		return {}
	end

	local definition = getDefinition(state.currentLevel)
	local levelName = if definition then definition.name else "Unknown"
	local payload: { [string]: any } = {
		phase = state.phase,
		levelNumber = state.currentLevel,
		levelName = levelName,
		highestUnlockedLevel = state.highestUnlockedLevel,
		playerHealth = state.playerHealth,
		maxPlayerHealth = ProgressConfig.MAX_PLAYER_HEALTH,
		bigWaveWarning = state.bigWaveWarning,
		canStart = state.phase == PHASE.Preparation,
		progress = 0,
		weather = if definition then definition.weather else nil,
	}

	if state.phase == PHASE.Countdown then
		payload.countdownRemaining = math.max(0, state.countdownEnd - os.clock())
	end

	if state.activeRun and state.phase == PHASE.Active then
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

	return payload
end

local function broadcast(player: Player)
	Remotes.getEvent("LevelStateChanged"):FireClient(player, buildPayloadForPlayer(player))
end

local function setPhase(player: Player, state: PlayerState, phase: string)
	state.phase = phase
	state.bigWaveWarning = false
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
	local monsterIds = ProgressService.consumeMonsterIntrosForDay(player, state.currentLevel)
	state.pendingBrainrotIntroIds = if #brainrotIds > 0 then brainrotIds else nil
	state.pendingMonsterIntroIds = if #monsterIds > 0 then monsterIds else nil
	if #brainrotIds > 0 or #monsterIds > 0 then
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

local function onVictory(player: Player, state: PlayerState)
	local definition = getDefinition(state.currentLevel)
	if not definition then
		return
	end

	-- Keep planted Brainrots (and their HP); clear fight leftovers.
	clearTransientCombat(player)

	local clearedNumber = definition.number
	local leftoverBrains = grantLeftoverCoinBrains(player)
	local brainsEarned = ProgressService.brainsForLevel(clearedNumber)
	local unlockedBrainrotId = ProgressService.grantUnlockForLevel(player, clearedNumber)
	ProgressService.addBrains(player, brainsEarned)
	ProgressService.incrementStat(player, ProgressConfig.STAT_LEVELS_CLEARED)

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
	local MagnetService = require(script.Parent.MagnetService)
	MagnetService.pauseCooldown(player)
	local nextDef = getDefinition(state.currentLevel)
	Remotes.getEvent("LevelStateChanged"):FireClient(player, {
		phase = PHASE.Victory,
		levelNumber = state.currentLevel,
		levelName = if nextDef then nextDef.name else "Unknown",
		highestUnlockedLevel = state.highestUnlockedLevel,
		playerHealth = state.playerHealth,
		maxPlayerHealth = ProgressConfig.MAX_PLAYER_HEALTH,
		canStart = false,
		progress = 0,
		bigWaveWarning = false,
		weather = if nextDef then nextDef.weather else nil,
		reward = {
			clearedLevel = clearedNumber,
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

local function tickActivePlayer(player: Player, state: PlayerState)
	local run = state.activeRun
	if not run or state.phase ~= PHASE.Active then
		return
	end

	local plotModel = PlotService.getPlotModel(player)
	if not plotModel then
		return
	end

	local now = os.clock()
	local step = run:advance(now)

	if step.bigWaveWarning then
		state.bigWaveWarning = true
		broadcast(player)
	elseif step.bigWaveWarningEnd then
		state.bigWaveWarning = false
		broadcast(player)
	end

	if step.spawn then
		local group = run:getCurrentGroup()
		if group then
			local monsterDef = Monsters.get(group.monsterId)
			local span = if monsterDef and monsterDef.laneSpan then monsterDef.laneSpan else 1
			local row = if type(group.row) == "number"
				then math.clamp(math.floor(group.row), 1, GridConfig.ROWS - span + 1)
				else LevelRun.randomRowForSpan(span)
			EnemyService.spawn(plotModel, group.monsterId, row)
		end
	end

	if run:isDoneSpawning() then
		GraveService.notifyWavesComplete(plotModel)
		if EnemyService.countOnPlot(plotModel) == 0 and not GraveService.hasPending(plotModel) then
			onVictory(player, state)
			return
		end
	end

	broadcast(player)
end

-- Countdown overlay (COUNTDOWN_TIME) then Active.
local function beginCountdown(player: Player, state: PlayerState)
	state.activeRun = nil
	state.countdownEnd = os.clock() + LevelConfig.COUNTDOWN_TIME
	local MagnetService = require(script.Parent.MagnetService)
	MagnetService.resumeCooldown(player)
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
	state.activeRun = LevelRun.new(definition)
	local MagnetService = require(script.Parent.MagnetService)
	MagnetService.resumeCooldown(player)
	local DamageMeterService = require(script.Parent.DamageMeterService)
	DamageMeterService.reset(player)
	setPhase(player, state, PHASE.Active)

	-- Fresh seed-packet recharges each Start Day (PvZ-style).
	BrainrotService.clearPlantCooldowns(player)

	if plotModel then
		GraveService.spawnForDay(plotModel, definition)
	end
end

local function tickCountdown(player: Player, state: PlayerState)
	if state.phase ~= PHASE.Countdown then
		return
	end

	if os.clock() < state.countdownEnd then
		return
	end

	local definition = getDefinition(state.currentLevel)
	if not definition then
		beginPreparation(player, state)
		return
	end

	beginActiveRun(player, state, definition)
end

local function onStartLevel(player: Player)
	local state = states[player.UserId]
	if not state then
		return
	end
	-- Defeat uses RewindDay → Preparation; StartLevel only from prep.
	if state.phase ~= PHASE.Preparation then
		return
	end

	local definition = getDefinition(state.currentLevel)
	if not definition then
		return
	end

	-- Brief 3…0 overlay, then Active so players plant while monsters march in.
	ProgressService.checkpointBrainrotXp(player)
	if LevelConfig.COUNTDOWN_TIME > 0 then
		beginCountdown(player, state)
	else
		beginActiveRun(player, state, definition)
	end
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

	state.playerHealth = math.max(0, state.playerHealth - 1)
	broadcast(player)
	if state.playerHealth <= 0 then
		onDefeat(player, state)
	end
end

local function onSelectLevel(player: Player, rawLevel: unknown)
	local state = states[player.UserId]
	if not state then
		return
	end
	-- Day Select from Preparation only (Defeat must Rewind first).
	if state.phase ~= PHASE.Preparation then
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
	local definition = getDefinition(state.currentLevel)
	return if definition then definition.weather else nil
end

-- After lawn restore on join — strip fog-column plants if the current day is NightFog.
function LevelService.applyWeatherRulesForPlayer(player: Player)
	local state = states[player.UserId]
	if state then
		applyWeatherRules(player, state)
	end
end

function LevelService.getCurrentDayForUser(userId: number): number
	local state = states[userId]
	if not state then
		return 1
	end
	return state.currentLevel
end

function LevelService.getSaveProgress(player: Player): (number, number, number)
	local state = states[player.UserId]
	if not state then
		return 1, 1, ProgressConfig.MAX_PLAYER_HEALTH
	end
	return state.currentLevel, state.highestUnlockedLevel, state.playerHealth
end

function LevelService.applySaveProgress(player: Player, currentLevel: number, highestUnlockedLevel: number, playerHealth: number)
	local state = states[player.UserId]
	if not state then
		return
	end

	local maxLevel = Levels.count()
	local sanitizedCurrent = math.clamp(math.floor(currentLevel), 1, math.max(1, maxLevel))
	local sanitizedHighest = math.clamp(math.floor(highestUnlockedLevel), sanitizedCurrent, math.max(1, maxLevel))

	state.currentLevel = sanitizedCurrent
	state.highestUnlockedLevel = sanitizedHighest
	state.playerHealth = math.clamp(math.floor(playerHealth), 1, ProgressConfig.MAX_PLAYER_HEALTH)
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

function LevelService.init()
	if (LevelService :: any)._remotesConnected then
		return
	end
	(LevelService :: any)._remotesConnected = true

	EnemyService.setHouseBreachHandler(onHouseBreach)

	Remotes.getEvent("StartLevel").OnServerEvent:Connect(function(player: Player)
		onStartLevel(player)
	end)
	Remotes.getEvent("SelectLevel").OnServerEvent:Connect(onSelectLevel)
	Remotes.getEvent("RewindDay").OnServerEvent:Connect(onRewindDay)
	Remotes.getEvent("ContinueVictory").OnServerEvent:Connect(onContinueVictory)
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
				if state.phase == PHASE.Countdown then
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
