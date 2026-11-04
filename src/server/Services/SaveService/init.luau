--!strict
--[[
	SaveService
	The ONLY system that touches DataStore. Persists player-owned progression
	(level, brains, health, unlocks, loadout, stats, Brainrot XP) and a *committed* lawn
	snapshot (Brainrots after the last victory / wipe). Match coins are never
	persisted (Day 1 purse / later days = 0). Mid-day placements are session-
	only until the day is won. Monsters and other combat transients are not saved.

	Schema v11: first-time mixed rewards, weekly quests and atomic Brainrot tickets.
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
local SaveConfig = require(Shared.Config.SaveConfig)
local RetentionTime = require(Shared.Utilities.RetentionTime)
local DailyQuests = require(script.Parent.RetentionService.DailyQuests)
local LoginRewards = require(script.Parent.RetentionService.LoginRewards)
local Achievements = require(script.Parent.RetentionService.Achievements)
local RewardGrant = require(script.Parent.RetentionService.RewardGrant)
local SessionStore = require(script.SessionStore)
local storage = SessionStore.new(store, os.time, function()
	return HttpService:GenerateGUID(false)
end, task.wait, SaveConfig)
local AUTOSAVE_INTERVAL = SaveConfig.AUTOSAVE_INTERVAL
local PLOT_WAIT_TIMEOUT = SaveConfig.PLOT_WAIT_TIMEOUT
local leaving: { [number]: boolean } = {}

local loadedProfiles: { [number]: Types.SaveData } = {}
-- Lawn checkpoint: only updates on victory / wipe / load — never mid-day live plants.
local committedBrainrots: { [number]: { Types.PlantedBrainrot } } = {}
local latestSnapshots: { [number]: Types.SaveData } = {}
local saveInFlight: { [number]: boolean } = {}
local needsResave: { [number]: boolean } = {}

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

local function deepCopyEvolutions(source: { [string]: { string } }?): { [string]: { string } }
	local result: { [string]: { string } } = {}
	if type(source) ~= "table" then
		return result
	end
	for brainrotId, rarities in source do
		if type(brainrotId) == "string" and type(rarities) == "table" then
			result[brainrotId] = deepCopyStringList(rarities)
		end
	end
	return result
end

local function deepCopyPlanted(source: { Types.PlantedBrainrot }): { Types.PlantedBrainrot }
	local result: { Types.PlantedBrainrot } = {}
	for _, entry in source do
		table.insert(result, {
			instanceId = entry.instanceId,
			brainrotId = entry.brainrotId,
			position = {
				row = entry.position.row,
				column = entry.position.column,
			},
			health = entry.health,
			charges = entry.charges,
		})
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
		brainrotXp = {},
		evolutions = {},
		introducedMonsters = {},
		introducedBrainrots = {},
		introducedMechanics = {},
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
		-- Legacy: match coins are not authoritative in DataStore; join purse
		-- comes from applyDayPurse(currentLevel), not this field.
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

	local brainrotXp = payload.brainrotXp
	if type(brainrotXp) == "table" then
		for key, value in brainrotXp do
			if type(key) == "string" and type(value) == "number" then
				save.brainrotXp[key] = value
			end
		end
	end

	local evolutions = payload.evolutions
	if type(evolutions) == "table" then
		save.evolutions = deepCopyEvolutions(evolutions)
	end

	local introducedMonsters = payload.introducedMonsters
	if type(introducedMonsters) == "table" then
		save.introducedMonsters = {}
		for _, value in introducedMonsters do
			if type(value) == "string" then
				table.insert(save.introducedMonsters :: { string }, value)
			end
		end
	end

	local introducedBrainrots = payload.introducedBrainrots
	if type(introducedBrainrots) == "table" then
		save.introducedBrainrots = {}
		for _, value in introducedBrainrots do
			if type(value) == "string" then
				table.insert(save.introducedBrainrots :: { string }, value)
			end
		end
	end

	local introducedMechanics = payload.introducedMechanics
	if type(introducedMechanics) == "table" then
		save.introducedMechanics = {}
		for _, value in introducedMechanics do
			if type(value) == "string" then
				table.insert(save.introducedMechanics :: { string }, value)
			end
		end
	end

	save.hiddenDayPending = payload.hiddenDayPending == true
	save.retention = DailyQuests.sanitize(payload.retention)

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
				charges = if type(entry.charges) == "number" then math.max(0, math.floor(entry.charges)) else nil,
			})
		end
	end

	save.version = Constants.SAVE_VERSION
	return save
end

local function collectSnapshot(player: Player): Types.SaveData
	local currentLevel, highestUnlockedLevel, playerHealth = LevelService.getSaveProgress(player)
	local progress = ProgressService.getSaveSlice(player)
	local planted = deepCopyPlanted(committedBrainrots[player.UserId] or {})

	-- If progression isn't hydrated yet, keep the last loaded/saved profile slice
	-- so an early autosave cannot wipe brains / unlocks / statistics.
	local fallback = loadedProfiles[player.UserId] or latestSnapshots[player.UserId]

	return {
		version = Constants.SAVE_VERSION,
		currentLevel = currentLevel,
		highestLevel = highestUnlockedLevel,
		coins = EconomyConfig.STARTING_COINS, -- never persist match purse; applyDayPurse on join
		brains = if progress then progress.brains elseif fallback then fallback.brains else ProgressConfig.STARTING_BRAINS,
		playerHealth = playerHealth,
		brainrots = planted,
		unlocks = if progress then progress.unlocks elseif fallback then deepCopyStringList(fallback.unlocks) else deepCopyStringList(ProgressConfig.DEFAULT_UNLOCKS),
		equipped = if progress then progress.equipped elseif fallback then deepCopyStringList(fallback.equipped) else deepCopyStringList(ProgressConfig.DEFAULT_EQUIPPED),
		upgrades = if progress
			then progress.upgrades
			elseif fallback then deepCopyNumberMap(fallback.upgrades)
			else {},
		statistics = if progress
			then progress.statistics
			elseif fallback then deepCopyNumberMap(fallback.statistics)
			else {},
		brainrotXp = if progress
			then progress.brainrotXp
			elseif fallback then deepCopyNumberMap(fallback.brainrotXp or {})
			else {},
		evolutions = if progress
			then progress.evolutions
			elseif fallback then deepCopyEvolutions(fallback.evolutions)
			else {},
		introducedMonsters = if progress
			then progress.introducedMonsters
			elseif fallback and fallback.introducedMonsters
			then deepCopyStringList(fallback.introducedMonsters)
			else {},
		introducedBrainrots = if progress
			then progress.introducedBrainrots
			elseif fallback and fallback.introducedBrainrots
			then deepCopyStringList(fallback.introducedBrainrots)
			else {},
		introducedMechanics = if progress
			then progress.introducedMechanics
			elseif fallback and fallback.introducedMechanics
			then deepCopyStringList(fallback.introducedMechanics)
			else {},
		hiddenDayPending = LevelService.isHiddenDayPending(player),
		retention = require(script.Parent.RetentionService).getSaveSlice(player)
			or DailyQuests.sanitize(if fallback then fallback.retention else nil),
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

local function loadFromStore(userId: number): Types.SaveData?
	local raw, reason = storage:acquire(userId)
	if not raw then
		log:warn("profile load refused", userId, reason)
		return nil
	end
	if type(raw.version) == "number" and raw.version > Constants.SAVE_VERSION then
		storage:release(userId)
		log:warn("refusing a newer save schema", userId, raw.version)
		return nil
	end
	return migrateAndSanitize(raw)
end

local function saveToStore(userId: number, snapshot: Types.SaveData, valid: (() -> boolean)?): (boolean, string?)
	local payload = encodeForStore(snapshot)
	if not payload then return false, "SaveUnavailable" end
	return storage:write(userId, payload, valid)
end

local function stopUnsafeSession(player: Player, reason: string?)
	log:warn("stopping session to protect saved progress", player.Name, reason)
	if player.Parent then
		player:Kick("Your progress could not be safely saved. Please rejoin in a moment.")
	end
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

-- Progression (brains / unlocks / stats / day) does not need a plot. Apply it
-- immediately on join so UI and autosave never see empty defaults.
local function hydrateProgression(player: Player, saveData: Types.SaveData)
	ProgressService.applySaveSlice(player, {
		brains = saveData.brains,
		unlocks = saveData.unlocks,
		equipped = saveData.equipped,
		upgrades = saveData.upgrades,
		statistics = saveData.statistics,
		brainrotXp = saveData.brainrotXp,
		evolutions = saveData.evolutions,
		introducedMonsters = saveData.introducedMonsters,
		introducedBrainrots = saveData.introducedBrainrots,
		introducedMechanics = saveData.introducedMechanics,
	})
	LevelService.applySaveProgress(
		player,
		saveData.currentLevel,
		saveData.highestLevel,
		saveData.playerHealth,
		saveData.hiddenDayPending == true
	)
	local forcedDay = LevelService.applyDevDay(player)
	CoinService.applyDayPurse(player, forcedDay or saveData.currentLevel)
	ProgressService.applyDevRoster(player)
	ProgressService.applyDevEvolutions(player)
	ProgressService.applyDevBrains(player)
	CoinService.applyDevPurse(player)
	require(script.Parent.RetentionService).hydrate(player, saveData.retention)
	-- Intro persistence can yield: every save slice must be hydrated first.
	LevelService.queueJoinIntros(player)
end

local function restoreLawn(player: Player, saveData: Types.SaveData)
	local plotModel = waitForPlot(player, PLOT_WAIT_TIMEOUT)
	if not plotModel then
		log:warn("lawn restore skipped (no plot yet)", player.Name)
		return
	end

	local EnemyService = require(script.Parent.EnemyService)
	local GraveService = require(script.Parent.GraveService)
	EnemyService.clearPlot(plotModel)
	GraveService.clearPlot(plotModel)
	CoinService.clearPlot(plotModel)

	-- Restore committed lawn only (ids, tiles, HP from last victory / wipe).
	BrainrotService.clearPlot(plotModel)
	BrainrotService.restorePlacements(player, saveData.brainrots)

	-- NightFog days cannot hold plants on east fog columns — strip after restore.
	LevelService.applyWeatherRulesForPlayer(player)
end

-- Capture snapshot synchronously, then flush to DataStore. Concurrent saves
-- queue a resave so victory/leave are never dropped while autosave yields.
local function savePlayer(player: Player, reason: string)
	local userId = player.UserId
	if not storage:isWritable(userId) then return end
	local snapshot = collectSnapshot(player)
	latestSnapshots[userId] = snapshot
	loadedProfiles[userId] = snapshot

	if saveInFlight[userId] then
		needsResave[userId] = true
		log:info("queued save", player.Name, reason)
		return
	end

	saveInFlight[userId] = true

	local ok, err = pcall(function()
		repeat
			needsResave[userId] = false
			local toWrite = latestSnapshots[userId]
			if not toWrite then
				break
			end
			if not saveToStore(userId, toWrite) then
				stopUnsafeSession(player, "save failed")
				break
			else
				log:info("saved", player.Name, reason)
			end
		until not needsResave[userId]
	end)

	saveInFlight[userId] = nil
	needsResave[userId] = nil
	if not ok then
		log:warn("save threw", player.Name, reason, err)
	end
end

-- Claim flags and reward are written in the same revision-guarded player record.
function SaveService.isProgressionLocked(player: Player): boolean
	return saveInFlight[player.UserId] == true or leaving[player.UserId] == true or not storage:isWritable(player.UserId)
end

function SaveService.claimRetentionReward(player: Player, kind: string, day: number, id: string): (boolean, string?, number?, any?)
	if kind ~= "Quest" and kind ~= "WeeklyQuest" and kind ~= "Login" and kind ~= "Achievement" and kind ~= "Ticket" then return false, "InvalidRequest", nil end
	local userId = player.UserId
	if saveInFlight[userId] then return false, "Busy", nil end
	if leaving[userId] or not storage:isWritable(userId) then return false, "SaveUnavailable", nil end
	saveInFlight[userId] = true
	local snapshot = collectSnapshot(player)
	snapshot.retention = DailyQuests.sanitize(snapshot.retention)
	local claim = if kind == "Login" then LoginRewards.claim elseif kind == "Achievement" then Achievements.claim else DailyQuests.claim
	local reward, reason, grant
	if kind == "Ticket" then
		if not require(script.Parent.StoreService).canPlayerUseShop(player, require(Shared.Config.StoreConfig).SHOP_BRAINROTS) then
			saveInFlight[userId] = nil
			return false, "InvalidRequest", nil
		end
		reward, reason, grant = RewardGrant.redeem(snapshot, id)
	else reward, reason, grant = claim(snapshot.retention, day, id, os.time(), kind == "WeeklyQuest") end
	if not reward then
		saveInFlight[userId] = nil
		return false, reason, nil
	end
	reward += RewardGrant.prepare(snapshot, grant)
	RewardGrant.apply(snapshot, grant)
	snapshot.brains += reward
	local stat = ProgressConfig.STAT_BRAINS_EARNED
	snapshot.statistics[stat] = (snapshot.statistics[stat] or 0) + reward
	local ok, failure = saveToStore(userId, snapshot, function()
		return kind == "Achievement" or kind == "Ticket" or (if kind == "WeeklyQuest" then RetentionTime.weekKey(os.time()) else RetentionTime.dayKey(os.time())) == day
	end)
	if ok then
		-- Merge with live actions/leave snapshot captured while UpdateAsync yielded.
		if player.Parent and not leaving[userId] then
			ProgressService.addBrains(player, reward)
			if grant then ProgressService.applyDurableReward(player, grant) end
		end
		require(script.Parent.RetentionService).markCommitted(player, day, id, kind, snapshot.retention)
		local queued = latestSnapshots[userId]
		if needsResave[userId] and queued then
			queued.brains += reward
			queued.statistics[stat] = (queued.statistics[stat] or 0) + reward
			queued.retention = DailyQuests.sanitize(queued.retention)
			if grant and grant.kind ~= "Ticket" then RewardGrant.apply(queued, grant) end
			queued.retention.brainrotTickets = snapshot.retention.brainrotTickets
			if kind == "Login" then LoginRewards.markCommitted(queued.retention, snapshot.retention)
			elseif kind == "Achievement" then Achievements.markCommitted(queued.retention, id)
			elseif kind ~= "Ticket" then DailyQuests.markCommitted(queued.retention, day, id, kind == "WeeklyQuest") end
		else
			latestSnapshots[userId] = snapshot
		end
		loadedProfiles[userId] = latestSnapshots[userId]
	elseif failure ~= "Expired" then
		stopUnsafeSession(player, failure)
	end
	-- Flush queued snapshots before releasing the per-player writer.
	while needsResave[userId] and storage:isWritable(userId) do
		needsResave[userId] = false
		local queued = latestSnapshots[userId]
		if queued then
			local saved, err = saveToStore(userId, queued)
			if not saved then stopUnsafeSession(player, err); break end
		end
	end
	saveInFlight[userId] = nil
	return ok, failure, if ok then reward else nil, if ok then grant else nil
end

-- Preserve the existing quest API; both reward kinds share one durable writer.
function SaveService.claimDailyQuest(player: Player, day: number, id: string): (boolean, string?, number?)
	return SaveService.claimRetentionReward(player, "Quest", day, id)
end

-- Snapshot the live plot into the committed lawn (call on victory before saveNow).
function SaveService.commitLawn(player: Player)
	local plotModel = PlotService.getPlotModel(player)
	if not plotModel then
		committedBrainrots[player.UserId] = {}
		return
	end
	committedBrainrots[player.UserId] = deepCopyPlanted(BrainrotService.getSavePlacements(plotModel))
end

-- Empty the committed lawn (day select / reset). Defeat keeps the checkpoint.
function SaveService.clearCommittedLawn(player: Player)
	committedBrainrots[player.UserId] = {}
end

-- Rebuild the live plot from the last victory / wipe checkpoint (defeat rewind).
function SaveService.restoreCommittedLawn(player: Player)
	local plotModel = PlotService.getPlotModel(player)
	if not plotModel then
		return
	end
	BrainrotService.clearPlot(plotModel)
	require(script.Parent.GraveService).clearPlot(plotModel)
	local planted = committedBrainrots[player.UserId] or {}
	BrainrotService.restorePlacements(player, planted)
end

-- Explicit flush for milestones that advance progression (victory, reset).
function SaveService.saveNow(player: Player, reason: string?)
	savePlayer(player, reason or "manual")
end

function SaveService.resetProgress(player: Player)
	if not storage:isWritable(player.UserId) or leaving[player.UserId] then return end
	while saveInFlight[player.UserId] do task.wait() end
	if leaving[player.UserId] or not storage:isWritable(player.UserId) then return end
	-- Full wipe: Day 1, empty lawn checkpoint, starter coins (125), default
	-- unlocks/loadout/stats. Requires two client confirmations before this fires.
	local defaults = defaultSaveData()
	loadedProfiles[player.UserId] = defaults
	latestSnapshots[player.UserId] = defaults
	committedBrainrots[player.UserId] = {}

	ProgressService.reset(player)
	ProgressService.applyDevRoster(player)
	ProgressService.applyDevEvolutions(player)
	ProgressService.applyDevBrains(player)
	LevelService.applySaveProgress(player, 1, 1, LevelConfig.STARTING_PLAYER_HEALTH)
	require(script.Parent.RetentionService).hydrate(player, nil)
	CoinService.resetBalance(player)

	local plotModel = PlotService.getPlotModel(player)
	if plotModel then
		BrainrotService.clearPlot(plotModel)
		local EnemyService = require(script.Parent.EnemyService)
		EnemyService.clearPlot(plotModel)
		require(script.Parent.GraveService).clearPlot(plotModel)
		CoinService.clearPlot(plotModel)
	end
	BrainrotService.clearPlantCooldowns(player)

	savePlayer(player, "reset")
	log:info("progress reset", player.Name)
end

local function onPlayerAdded(player: Player)
	local saveData = loadFromStore(player.UserId)
	if not saveData then stopUnsafeSession(player, "profile unavailable or open elsewhere"); return end
	if not player.Parent then storage:release(player.UserId); return end
	loadedProfiles[player.UserId] = saveData
	committedBrainrots[player.UserId] = deepCopyPlanted(saveData.brainrots)
	latestSnapshots[player.UserId] = saveData

	-- Sync hydrate first (LevelService already created state in its PlayerAdded).
	hydrateProgression(player, saveData)

	task.defer(function()
		if Players:GetPlayerByUserId(player.UserId) then
			restoreLawn(player, saveData)
		end
	end)
end

local function onPlayerRemoving(player: Player)
	local userId = player.UserId
	leaving[userId] = true
	-- Capture synchronously before other services remove live profiles.
	savePlayer(player, "leave")
	while saveInFlight[userId] do task.wait() end
	storage:release(userId)
	loadedProfiles[userId] = nil
	committedBrainrots[userId] = nil
	latestSnapshots[userId] = nil
	needsResave[userId] = nil
	leaving[userId] = nil
	require(script.Parent.RetentionService).cleanup(player)
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
		local players = Players:GetPlayers()
		for _, player in players do
			savePlayer(player, "shutdown")
		end
		-- A save already in flight only queues a resave and returns. Stay
		-- alive until that resave writes, or Studio stop drops the new loadout.
		local deadline = os.clock() + SaveConfig.SHUTDOWN_WAIT
		while os.clock() < deadline do
			local busy = false
			for _, player in players do
				if saveInFlight[player.UserId] then
					busy = true
					break
				end
			end
			if not busy then
				for _, player in players do storage:release(player.UserId) end
				break
			end
			task.wait(0.1)
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
