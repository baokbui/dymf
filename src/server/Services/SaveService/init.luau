--!strict
--[[
	SaveService
	The ONLY system that touches DataStore. Persists player-owned progression
	(level, brains, health, unlocks, loadout, stats) and planted Brainrots on
	the lawn. Match coins are never persisted (Day 1 purse / later days = 0).
	Monsters and other combat transients are not saved.

	Milestone 9 / schema v2 (Milestone 13); lawn restore re-enabled for rejoin.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local LevelConfig = require(Shared.Config.LevelConfig)
local ProgressConfig = require(Shared.Config.ProgressConfig)
local Logger = require(Shared.Utilities.Logger)
local Types = require(Shared.Types)

local BrainrotService = require(script.Parent.BrainrotService)
local CoinService = require(script.Parent.CoinService)
local LevelService = require(script.Parent.LevelService)
local PlotService = require(script.Parent.PlotService)
local ProgressService = require(script.Parent.ProgressService)

local SaveService = {}
SaveService.Name = "SaveService"

local log = Logger.new(SaveService.Name)

local store = DataStoreService:GetDataStore(Constants.SAVE_DATASTORE_NAME)
local AUTOSAVE_INTERVAL = 60
local LOAD_RETRIES = 3
local SAVE_RETRIES = 5
local PLOT_WAIT_TIMEOUT = 10

local loadedProfiles: { [number]: Types.SaveData } = {}
local saveInFlight: { [number]: boolean } = {}

local function deepCopyNumberMap(source: { [string]: number }): { [string]: number }
	local result: { [string]: number } = {}
	for key, value in source do
		result[key] = value
	end
	return result
end

local function deepCopyStringList(source: { string }): { string }
	local result: { string } = {}
	for _, value in source do
		table.insert(result, value)
	end
	return result
end

local function defaultSaveData(): Types.SaveData
	return {
		version = Constants.SAVE_VERSION,
		currentLevel = 1,
		highestLevel = 1,
		coins = EconomyConfig.STARTING_COINS,
		brains = ProgressConfig.STARTING_BRAINS,
		playerHealth = LevelConfig.STARTING_PLAYER_HEALTH,
		brainrots = {},
		unlocks = deepCopyStringList(ProgressConfig.DEFAULT_UNLOCKS),
		equipped = deepCopyStringList(ProgressConfig.DEFAULT_EQUIPPED),
		upgrades = {},
		statistics = {},
	}
end

local function migrateAndSanitize(raw: unknown): Types.SaveData
	if type(raw) ~= "table" then
		return defaultSaveData()
	end

	local save = defaultSaveData()
	local payload = raw :: { [string]: any }

	local currentLevel = payload.currentLevel
	if type(currentLevel) == "number" then
		save.currentLevel = math.max(1, math.floor(currentLevel))
	end

	local highestLevel = payload.highestLevel
	if type(highestLevel) == "number" then
		save.highestLevel = math.max(save.currentLevel, math.floor(highestLevel))
	end

	local coins = payload.coins
	if type(coins) == "number" then
		-- Legacy: ignore persisted match coins; sessions always start at STARTING_COINS.
		save.coins = EconomyConfig.STARTING_COINS
	end

	local brains = payload.brains
	if type(brains) == "number" then
		save.brains = math.max(0, math.floor(brains))
	end

	local playerHealth = payload.playerHealth
	if type(playerHealth) == "number" then
		save.playerHealth = math.clamp(math.floor(playerHealth), 1, ProgressConfig.MAX_PLAYER_HEALTH)
	end

	local unlocks = payload.unlocks
	if type(unlocks) == "table" then
		save.unlocks = {}
		for _, value in unlocks do
			if type(value) == "string" then
				table.insert(save.unlocks, value)
			end
		end
		if #save.unlocks == 0 then
			save.unlocks = deepCopyStringList(ProgressConfig.DEFAULT_UNLOCKS)
		end
	end

	local equipped = payload.equipped
	if type(equipped) == "table" then
		save.equipped = {}
		for _, value in equipped do
			if type(value) == "string" then
				table.insert(save.equipped, value)
			end
		end
		if #save.equipped == 0 then
			save.equipped = deepCopyStringList(ProgressConfig.DEFAULT_EQUIPPED)
		end
	end

	local upgrades = payload.upgrades
	if type(upgrades) == "table" then
		for key, value in upgrades do
			if type(key) == "string" and type(value) == "number" then
				save.upgrades[key] = value
			end
		end
	end

	local statistics = payload.statistics
	if type(statistics) == "table" then
		for key, value in statistics do
			if type(key) == "string" and type(value) == "number" then
				save.statistics[key] = value
			end
		end
	end

	local brainrots = payload.brainrots
	if type(brainrots) == "table" then
		save.brainrots = {}
		for _, entry in brainrots do
			if type(entry) ~= "table" then
				continue
			end
			local row = entry.position and entry.position.row
			local column = entry.position and entry.position.column
			local brainrotId = entry.brainrotId
			local health = entry.health
			if type(brainrotId) ~= "string" or type(row) ~= "number" or type(column) ~= "number" then
				continue
			end
			table.insert(save.brainrots, {
				instanceId = if type(entry.instanceId) == "string" then entry.instanceId else "",
				brainrotId = brainrotId,
				position = {
					row = math.floor(row),
					column = math.floor(column),
				},
				health = if type(health) == "number" then math.max(0, health) else 0,
			})
		end
	end

	save.version = Constants.SAVE_VERSION
	return save
end

local function collectSnapshot(player: Player): Types.SaveData
	local currentLevel, highestUnlockedLevel, playerHealth = LevelService.getSaveProgress(player)
	local progress = ProgressService.getSaveSlice(player)

	local planted: { Types.PlantedBrainrot } = {}
	local plotModel = PlotService.getPlotModel(player)
	if plotModel then
		planted = BrainrotService.getSavePlacements(plotModel)
	end

	return {
		version = Constants.SAVE_VERSION,
		currentLevel = currentLevel,
		highestLevel = highestUnlockedLevel,
		coins = EconomyConfig.STARTING_COINS, -- never persist match purse; applyDayPurse on join
		brains = progress.brains,
		playerHealth = playerHealth,
		brainrots = planted,
		unlocks = progress.unlocks,
		equipped = progress.equipped,
		upgrades = {},
		statistics = progress.statistics,
	}
end

-- Round-trip through JSON so DataStore only ever receives plain serializable tables.
local function encodeForStore(snapshot: Types.SaveData): Types.SaveData?
	local okEncode, encodedOrErr = pcall(function()
		return HttpService:JSONEncode(snapshot)
	end)
	if not okEncode or type(encodedOrErr) ~= "string" then
		log:warn("snapshot JSON encode failed", encodedOrErr)
		return nil
	end
	local okDecode, decodedOrErr = pcall(function()
		return HttpService:JSONDecode(encodedOrErr)
	end)
	if not okDecode or type(decodedOrErr) ~= "table" then
		log:warn("snapshot JSON decode failed", decodedOrErr)
		return nil
	end
	return migrateAndSanitize(decodedOrErr)
end

local function saveKey(userId: number): string
	return string.format("Player_%d", userId)
end

local function loadFromStore(userId: number): Types.SaveData
	local key = saveKey(userId)
	local attempts = 0
	while attempts < LOAD_RETRIES do
		attempts += 1
		local ok, raw = pcall(function()
			return store:GetAsync(key)
		end)
		if ok then
			return migrateAndSanitize(raw)
		end
		log:warn(string.format("GetAsync failed (attempt %d/%d)", attempts, LOAD_RETRIES), raw)
		task.wait(0.75 * attempts)
	end
	return defaultSaveData()
end

local function saveToStore(userId: number, snapshot: Types.SaveData): boolean
	local payload = encodeForStore(snapshot)
	if not payload then
		return false
	end

	local key = saveKey(userId)
	local attempts = 0
	while attempts < SAVE_RETRIES do
		attempts += 1
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(_old)
				return payload
			end)
		end)
		if ok then
			return true
		end
		-- Studio often surfaces transient Roblox-cloud HTTP 500s here; retry with backoff.
		log:warn(string.format("UpdateAsync failed (attempt %d/%d)", attempts, SAVE_RETRIES), err)
		task.wait(math.min(4, 0.6 * (2 ^ (attempts - 1))))
	end
	return false
end

local function waitForPlot(player: Player, timeoutSeconds: number): Model?
	local deadline = os.clock() + timeoutSeconds
	while os.clock() < deadline do
		local plotModel = PlotService.getPlotModel(player)
		if plotModel then
			return plotModel
		end
		task.wait(0.1)
	end
	return nil
end

local function restorePlayer(player: Player, saveData: Types.SaveData)
	local plotModel = waitForPlot(player, PLOT_WAIT_TIMEOUT)
	if not plotModel then
		log:warn("restore skipped (no plot yet)", player.Name)
		return
	end

	ProgressService.applySaveSlice(player, {
		brains = saveData.brains,
		unlocks = saveData.unlocks,
		equipped = saveData.equipped,
		statistics = saveData.statistics,
	})
	LevelService.applySaveProgress(player, saveData.currentLevel, saveData.highestLevel, saveData.playerHealth)
	-- Day 1 → STARTING_COINS; later days → 0.
	CoinService.applyDayPurse(player, saveData.currentLevel)

	local EnemyService = require(script.Parent.EnemyService)
	EnemyService.clearPlot(plotModel)
	CoinService.clearPlot(plotModel)

	-- Restore planted Brainrots (ids, tiles, HP). Clear first so restore is clean.
	BrainrotService.clearPlot(plotModel)
	BrainrotService.restorePlacements(player, saveData.brainrots)
end

local function savePlayer(player: Player, reason: string)
	local userId = player.UserId
	if saveInFlight[userId] then
		return
	end
	saveInFlight[userId] = true

	local ok, err = pcall(function()
		local snapshot = collectSnapshot(player)
		loadedProfiles[userId] = snapshot

		if not saveToStore(userId, snapshot) then
			log:warn("failed save", player.Name, reason)
		else
			log:info("saved", player.Name, reason)
		end
	end)
	saveInFlight[userId] = nil
	if not ok then
		log:warn("save threw", player.Name, reason, err)
	end
end

-- Explicit flush for milestones that advance progression (victory, reset).
function SaveService.saveNow(player: Player, reason: string?)
	savePlayer(player, reason or "manual")
end

function SaveService.resetProgress(player: Player)
	local defaults = defaultSaveData()
	loadedProfiles[player.UserId] = defaults
	saveToStore(player.UserId, defaults)

	ProgressService.reset(player)
	LevelService.applySaveProgress(player, 1, 1, LevelConfig.STARTING_PLAYER_HEALTH)
	CoinService.resetBalance(player)

	local plotModel = PlotService.getPlotModel(player)
	if plotModel then
		BrainrotService.clearPlot(plotModel)
		local EnemyService = require(script.Parent.EnemyService)
		EnemyService.clearPlot(plotModel)
		CoinService.clearPlot(plotModel)
	end

	log:info("progress reset", player.Name)
end

local function onPlayerAdded(player: Player)
	local saveData = loadFromStore(player.UserId)
	loadedProfiles[player.UserId] = saveData

	task.defer(function()
		if Players:GetPlayerByUserId(player.UserId) then
			restorePlayer(player, saveData)
		end
	end)
end

local function onPlayerRemoving(player: Player)
	savePlayer(player, "leave")
	loadedProfiles[player.UserId] = nil
	saveInFlight[player.UserId] = nil
end

function SaveService.init()
	local Remotes = require(Shared.Remotes)
	Remotes.getEvent("ResetProgress").OnServerEvent:Connect(function(player: Player)
		SaveService.resetProgress(player)
	end)

	-- Connect leave-save in init() so it runs before other services' start()
	-- PlayerRemoving handlers (PlotService / BrainrotService clear the lawn).
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			savePlayer(player, "shutdown")
		end
	end)
end

function SaveService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in Players:GetPlayers() do
				savePlayer(player, "autosave")
			end
		end
	end)

	log:info("started")
end

return SaveService
