--!strict
--[[
	LevelService
	The ONLY system that advances campaign levels (PvZ-style). Owns preparation,
	countdown, spawn groups, victory/defeat, rewards, and progression. Drives
	EnemyService for spawns; broadcasts state via LevelStateChanged.

	Milestone 8.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local LevelConfig = require(Shared.Config.LevelConfig)
local Levels = require(Shared.Levels)
local Remotes = require(Shared.Remotes)
local Logger = require(Shared.Utilities.Logger)

local LevelRun = require(script.LevelRun)
local BrainrotService = require(script.Parent.BrainrotService)
local CoinService = require(script.Parent.CoinService)
local EnemyService = require(script.Parent.EnemyService)
local PlotService = require(script.Parent.PlotService)

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

-- PvZ-style reset after clearing a level: empty lawn and starting sun/coins.
local function resetPlotAfterVictory(player: Player)
	local plotModel = PlotService.getPlotModel(player)
	if plotModel then
		BrainrotService.clearPlot(plotModel)
		EnemyService.clearPlot(plotModel)
		CoinService.clearPlot(plotModel)
	end
	CoinService.resetBalance(player)
end

local function onVictory(player: Player, state: PlayerState)
	local definition = getDefinition(state.currentLevel)
	if not definition then
		return
	end

	resetPlotAfterVictory(player)

	local clearedNumber = definition.number
	if state.currentLevel >= state.highestUnlockedLevel then
		state.highestUnlockedLevel = math.min(state.currentLevel + 1, Levels.count())
	end

	local nextDefinition = Levels.getByNumber(state.currentLevel + 1)
	if nextDefinition then
		state.currentLevel += 1
	end

	state.activeRun = nil
	setPhase(player, state, PHASE.Victory)
	log:info(string.format("%s cleared level %d", player.Name, clearedNumber))

	task.delay(RESULT_DISPLAY_TIME, function()
		if states[player.UserId] == state then
			beginPreparation(player, state)
		end
	end)
end

local function onDefeat(player: Player, state: PlayerState)
	local plotModel = PlotService.getPlotModel(player)
	if plotModel then
		EnemyService.clearPlot(plotModel)
	end

	state.activeRun = nil
	state.playerHealth = LevelConfig.STARTING_PLAYER_HEALTH
	setPhase(player, state, PHASE.Defeat)
	log:info(string.format("%s defeated on level %d", player.Name, state.currentLevel))

	task.delay(RESULT_DISPLAY_TIME, function()
		if states[player.UserId] == state then
			beginPreparation(player, state)
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
			EnemyService.spawn(plotModel, group.monsterId, LevelRun.randomRow())
		end
	end

	if run:isDoneSpawning() and EnemyService.countOnPlot(plotModel) == 0 then
		onVictory(player, state)
		return
	end

	broadcast(player)
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

	local plotModel = PlotService.getPlotModel(player)
	if plotModel then
		EnemyService.clearPlot(plotModel)
	end

	state.activeRun = LevelRun.new(definition)
	setPhase(player, state, PHASE.Active)
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

	local plotModel = PlotService.getPlotModel(player)
	if plotModel then
		EnemyService.clearPlot(plotModel)
	end

	state.countdownEnd = os.clock() + LevelConfig.COUNTDOWN_TIME
	setPhase(player, state, PHASE.Countdown)
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

	onDefeat(player, state)
end

local function initPlayer(player: Player)
	states[player.UserId] = {
		currentLevel = 1,
		highestUnlockedLevel = 1,
		playerHealth = LevelConfig.STARTING_PLAYER_HEALTH,
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
	states[player.UserId] = nil
end

function LevelService.getClientState(player: Player): { [string]: any }
	return buildPayloadForPlayer(player)
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
end

function LevelService.start()
	Remotes.getFunction("RequestState").OnServerInvoke = function(player: Player)
		return {
			coins = CoinService.getBalance(player),
			level = LevelService.getClientState(player),
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
