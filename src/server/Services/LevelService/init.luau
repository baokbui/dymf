--!strict
--[[
	LevelService
	The ONLY system that advances campaign levels (PvZ-style). Owns preparation,
	Active spawn groups, victory/defeat, rewards, and progression. Start Day goes
	straight to Active — monsters spawn in the forest and walk in (setup time).
	Drives EnemyService for spawns; broadcasts state via LevelStateChanged.

	Victory keeps planted Brainrots on the plot and commits them for rejoin.
	Leave / autosave persist that checkpoint only — mid-day plants are discarded.
	Coin purse is STARTING_COINS on Day 1 only; after later days end the purse
	resets to 0. Defeat / Day Select wipe the lawn (and the committed checkpoint).

	Milestone 8.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local ProgressConfig = require(Shared.Config.ProgressConfig)
local Levels = require(Shared.Levels)
local Monsters = require(Shared.Monsters)
local Remotes = require(Shared.Remotes)
local Logger = require(Shared.Utilities.Logger)

local LevelRun = require(script.LevelRun)
local BrainrotService = require(script.Parent.BrainrotService)
local CoinService = require(script.Parent.CoinService)
local EnemyService = require(script.Parent.EnemyService)
local PlotService = require(script.Parent.PlotService)
local ProgressService = require(script.Parent.ProgressService)

local LevelService = {}
LevelService.Name = "LevelService"

local log = Logger.new(LevelService.Name)

local PHASE = Constants.PHASE
local RESULT_DISPLAY_TIME = 3

type PlayerState = {
	currentLevel: number,
	highestUnlockedLevel: number,
	playerHealth: number,
	phase: string,
	activeRun: LevelRun.LevelRun?,
	countdownEnd: number,
	bigWaveWarning: boolean,
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
		canStart = state.phase == PHASE.Preparation or state.phase == PHASE.Defeat,
		progress = 0,
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

local function beginPreparation(player: Player, state: PlayerState)
	state.activeRun = nil
	state.bigWaveWarning = false
	setPhase(player, state, PHASE.Preparation)
end

-- Clear combat leftovers. Brainrots stay on victory; coin purse depends on next day.
local function clearTransientCombat(player: Player)
	local plotModel = PlotService.getPlotModel(player)
	if plotModel then
		EnemyService.clearPlot(plotModel)
		CoinService.clearPlot(plotModel)
	end
end

-- Full wipe: Brainrots + monsters + ground coins (defeat / day select).
local function clearLawn(player: Player)
	local plotModel = PlotService.getPlotModel(player)
	if plotModel then
		BrainrotService.clearPlot(plotModel)
		EnemyService.clearPlot(plotModel)
		CoinService.clearPlot(plotModel)
	end
end

local function onVictory(player: Player, state: PlayerState)
	local definition = getDefinition(state.currentLevel)
	if not definition then
		return
	end

	-- Keep planted Brainrots (and their HP); clear fight leftovers.
	clearTransientCombat(player)

	local clearedNumber = definition.number
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
	Remotes.getEvent("LevelStateChanged"):FireClient(player, {
		phase = PHASE.Victory,
		levelNumber = state.currentLevel,
		levelName = if getDefinition(state.currentLevel) then getDefinition(state.currentLevel).name else "Unknown",
		highestUnlockedLevel = state.highestUnlockedLevel,
		playerHealth = state.playerHealth,
		maxPlayerHealth = ProgressConfig.MAX_PLAYER_HEALTH,
		canStart = false,
		progress = 0,
		bigWaveWarning = false,
		reward = {
			clearedLevel = clearedNumber,
			brains = brainsEarned,
			unlockedBrainrotId = unlockedBrainrotId,
		},
	})
	log:info(string.format("%s cleared level %d (+%d brains)", player.Name, clearedNumber, brainsEarned))

	-- Commit lawn checkpoint, then persist (mid-day plants after this only stick on next victory).
	local SaveService = require(script.Parent.SaveService)
	SaveService.commitLawn(player)
	SaveService.saveNow(player, "victory")

	task.delay(RESULT_DISPLAY_TIME, function()
		if states[player.UserId] == state then
			beginPreparation(player, state)
		end
	end)
end

local function onDefeat(player: Player, state: PlayerState)
	local failedLevel = state.currentLevel
	state.activeRun = nil
	state.playerHealth = ProgressConfig.MAX_PLAYER_HEALTH
	-- Full campaign soft-reset: back to Day 1 (keep highestUnlocked for Day Select).
	state.currentLevel = 1
	clearLawn(player)
	CoinService.applyDayPurse(player, 1)
	setPhase(player, state, PHASE.Defeat)
	log:info(string.format("%s defeated on level %d — reset to day 1", player.Name, failedLevel))

	local SaveService = require(script.Parent.SaveService)
	SaveService.clearCommittedLawn(player)
	SaveService.saveNow(player, "defeat")
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
			EnemyService.spawn(plotModel, group.monsterId, LevelRun.randomRowForSpan(span))
		end
	end

	if run:isDoneSpawning() and EnemyService.countOnPlot(plotModel) == 0 then
		onVictory(player, state)
		return
	end

	broadcast(player)
end

-- Optional Countdown → Active bridge (COUNTDOWN_TIME > 0). Live flow skips this.
local function beginActiveRun(player: Player, state: PlayerState, definition)
	local plotModel = PlotService.getPlotModel(player)
	if plotModel then
		EnemyService.clearPlot(plotModel)
	end

	state.countdownEnd = 0
	state.activeRun = LevelRun.new(definition)
	setPhase(player, state, PHASE.Active)

	-- Fresh seed-packet recharges each Start Day (PvZ-style).
	BrainrotService.clearPlantCooldowns(player)
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
	if state.phase ~= PHASE.Preparation and state.phase ~= PHASE.Defeat then
		return
	end

	local definition = getDefinition(state.currentLevel)
	if not definition then
		return
	end

	-- Skip idle countdown: Active immediately so players can plant while the
	-- first monsters spawn in the forest and walk toward the plot.
	beginActiveRun(player, state, definition)
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
	if state.phase ~= PHASE.Preparation and state.phase ~= PHASE.Defeat then
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
	end

	broadcast(player)
end

-- Placement and coin income are only allowed while a level is in progress.
function LevelService.isLevelActive(player: Player): boolean
	local state = states[player.UserId]
	return state ~= nil and state.phase == PHASE.Active
end

function LevelService.init()
	EnemyService.setHouseBreachHandler(onHouseBreach)

	Remotes.getEvent("StartLevel").OnServerEvent:Connect(function(player: Player)
		onStartLevel(player)
	end)
	Remotes.getEvent("SelectLevel").OnServerEvent:Connect(onSelectLevel)
end

function LevelService.start()
	Remotes.getFunction("RequestState").OnServerInvoke = function(player: Player)
		return {
			coins = CoinService.getBalance(player),
			level = LevelService.getClientState(player),
			profile = ProgressService.getClientState(player),
			plantCooldowns = BrainrotService.getPlantCooldowns(player),
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
