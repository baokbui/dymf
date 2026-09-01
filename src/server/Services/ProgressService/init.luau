--!strict
--[[
	ProgressService
	Owns brains, unlocks, equipped loadout, player upgrades, and statistics.
	The physical Progression Store spends brains here (Milestone 18).

	Statistics update live via ProfileUpdated. Time played includes the current
	session in client payloads; it is committed into the saved total on flush
	(save / leave).

	Milestone 13.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Brainrots = require(Shared.Brainrots)
local Monsters = require(Shared.Monsters)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local ProgressConfig = require(Shared.Config.ProgressConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local StoreConfig = require(Shared.Config.StoreConfig)
local DevConfig = require(Shared.Config.DevConfig)
local Remotes = require(Shared.Remotes)
local Logger = require(Shared.Utilities.Logger)

local ProgressService = {}
ProgressService.Name = "ProgressService"

local log = Logger.new(ProgressService.Name)

type Profile = {
	brains: number,
	unlocks: { string },
	equipped: { string },
	upgrades: { [string]: number },
	statistics: { [string]: number },
	introducedMonsters: { string },
	introducedBrainrots: { string },
	sessionStartedAt: number,
	hydrated: boolean, -- false until SaveService.applySaveSlice (or reset)
}

local profiles: { [number]: Profile } = {}

local function copyList(source: { string }): { string }
	local result: { string } = {}
	for _, value in source do
		table.insert(result, value)
	end
	return result
end

local function copyStats(source: { [string]: number }): { [string]: number }
	local result: { [string]: number } = {}
	for key, value in source do
		result[key] = value
	end
	return result
end

local function copyUpgrades(source: { [string]: number }): { [string]: number }
	return copyStats(source)
end

local function findStoreBrainrot(brainrotId: string): { brainrotId: string, brainsCost: number }?
	for _, entry in ProgressConfig.STORE_CATALOG do
		if entry.brainrotId == brainrotId then
			return entry
		end
	end
	return nil
end

local function findUpgrade(upgradeId: string): any?
	for _, entry in ProgressConfig.UPGRADE_CATALOG do
		if entry.id == upgradeId then
			return entry
		end
	end
	return nil
end

local function sanitizeUpgrades(raw: { [string]: number }?): { [string]: number }
	local result: { [string]: number } = {}
	if type(raw) ~= "table" then
		return result
	end
	for key, value in raw do
		if type(key) ~= "string" or type(value) ~= "number" then
			continue
		end
		local def = findUpgrade(key)
		if not def then
			continue
		end
		result[key] = math.clamp(math.floor(value), 0, def.maxLevel)
	end
	return result
end

local function upgradeCost(def: any, nextLevel: number): number?
	local costs = def.brainsCosts
	if type(costs) ~= "table" or nextLevel < 1 then
		return nil
	end
	local cost = costs[nextLevel]
	if type(cost) ~= "number" then
		cost = costs[#costs]
	end
	if type(cost) ~= "number" then
		return nil
	end
	return math.max(0, math.floor(cost))
end

local function applyWalkSpeedToCharacter(player: Player, speed: number)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

local function defaultUnlocks(): { string }
	return copyList(ProgressConfig.DEFAULT_UNLOCKS)
end

local function defaultEquipped(): { string }
	return copyList(ProgressConfig.DEFAULT_EQUIPPED)
end

local function sanitizeIdList(raw: { string }, requireUnlocked: { [string]: boolean }?, maxCount: number?): { string }
	local seen: { [string]: boolean } = {}
	local result: { string } = {}
	for _, id in raw do
		if type(id) ~= "string" or seen[id] or not Brainrots.isPlayable(id) then
			continue
		end
		if requireUnlocked and not requireUnlocked[id] then
			continue
		end
		seen[id] = true
		table.insert(result, id)
		if maxCount and #result >= maxCount then
			break
		end
	end
	return result
end

local function sanitizeMonsterIdList(raw: { string }): { string }
	local seen: { [string]: boolean } = {}
	local result: { string } = {}
	for _, id in raw do
		if type(id) ~= "string" or seen[id] or not Monsters.exists(id) then
			continue
		end
		seen[id] = true
		table.insert(result, id)
	end
	return result
end

local function sanitizeBrainrotIntroList(raw: { string }): { string }
	local seen: { [string]: boolean } = {}
	local result: { string } = {}
	for _, id in raw do
		if type(id) ~= "string" or seen[id] or not Brainrots.isPlayable(id) then
			continue
		end
		seen[id] = true
		table.insert(result, id)
	end
	return result
end

local function listContains(list: { string }, id: string): boolean
	for _, value in list do
		if value == id then
			return true
		end
	end
	return false
end

local function markIntroduced(list: { string }, id: string)
	if not listContains(list, id) then
		table.insert(list, id)
	end
end

local function unlockSet(unlocks: { string }): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for _, id in unlocks do
		set[id] = true
	end
	return set
end

local function ensureProfile(player: Player): Profile
	local existing = profiles[player.UserId]
	if existing then
		return existing
	end
	local profile: Profile = {
		brains = ProgressConfig.STARTING_BRAINS,
		unlocks = defaultUnlocks(),
		equipped = defaultEquipped(),
		upgrades = {},
		statistics = {},
		introducedMonsters = {},
		introducedBrainrots = {},
		sessionStartedAt = os.clock(),
		hydrated = false,
	}
	profiles[player.UserId] = profile
	return profile
end

-- Client-facing stats include uncommitted session time (does not mutate storage).
local function statsForClient(profile: Profile): { [string]: number }
	local stats = copyStats(profile.statistics)
	local elapsed = math.max(0, math.floor(os.clock() - profile.sessionStartedAt))
	local key = ProgressConfig.STAT_TIME_PLAYED
	stats[key] = (stats[key] or 0) + elapsed
	return stats
end

local function buildPayload(profile: Profile): { [string]: any }
	return {
		brains = profile.brains,
		unlocks = copyList(profile.unlocks),
		equipped = copyList(profile.equipped),
		upgrades = copyUpgrades(profile.upgrades),
		statistics = statsForClient(profile),
	}
end

local function broadcast(player: Player)
	local profile = profiles[player.UserId]
	if not profile or not profile.hydrated then
		return
	end
	Remotes.getEvent("ProfileUpdated"):FireClient(player, buildPayload(profile))
end

local function flushSessionTime(profile: Profile)
	local elapsed = math.max(0, math.floor(os.clock() - profile.sessionStartedAt))
	if elapsed <= 0 then
		return
	end
	local key = ProgressConfig.STAT_TIME_PLAYED
	profile.statistics[key] = (profile.statistics[key] or 0) + elapsed
	profile.sessionStartedAt = os.clock()
end

function ProgressService.isHydrated(player: Player): boolean
	local profile = profiles[player.UserId]
	return profile ~= nil and profile.hydrated
end

function ProgressService.getClientState(player: Player): { [string]: any }
	local profile = ensureProfile(player)
	if not profile.hydrated then
		return {
			brains = profile.brains,
			unlocks = copyList(profile.unlocks),
			equipped = copyList(profile.equipped),
			upgrades = {},
			statistics = {},
		}
	end
	return buildPayload(profile)
end

function ProgressService.getSaveSlice(player: Player): {
	brains: number,
	unlocks: { string },
	equipped: { string },
	upgrades: { [string]: number },
	statistics: { [string]: number },
	introducedMonsters: { string },
	introducedBrainrots: { string },
}?
	local profile = profiles[player.UserId]
	if not profile or not profile.hydrated then
		-- Avoid wiping DataStore with join defaults before SaveService restores.
		return nil
	end
	flushSessionTime(profile)
	return {
		brains = profile.brains,
		unlocks = copyList(profile.unlocks),
		equipped = copyList(profile.equipped),
		upgrades = copyUpgrades(profile.upgrades),
		statistics = copyStats(profile.statistics),
		introducedMonsters = copyList(profile.introducedMonsters),
		introducedBrainrots = copyList(profile.introducedBrainrots),
	}
end

function ProgressService.applySaveSlice(player: Player, slice: {
	brains: number?,
	unlocks: { string }?,
	equipped: { string }?,
	upgrades: { [string]: number }?,
	statistics: { [string]: number }?,
	introducedMonsters: { string }?,
	introducedBrainrots: { string }?,
})
	local profile = ensureProfile(player)
	if type(slice.brains) == "number" then
		profile.brains = math.max(0, math.floor(slice.brains))
	end
	if type(slice.unlocks) == "table" and #(slice.unlocks :: { string }) > 0 then
		profile.unlocks = sanitizeIdList(slice.unlocks :: { string })
	else
		profile.unlocks = defaultUnlocks()
	end
	local unlocked = unlockSet(profile.unlocks)
	if type(slice.equipped) == "table" and #(slice.equipped :: { string }) > 0 then
		profile.equipped = sanitizeIdList(slice.equipped :: { string }, unlocked, ProgressConfig.MAX_EQUIPPED)
	else
		profile.equipped = sanitizeIdList(defaultEquipped(), unlocked, ProgressConfig.MAX_EQUIPPED)
	end
	if #profile.equipped == 0 then
		profile.equipped = sanitizeIdList(defaultEquipped(), unlocked, ProgressConfig.MAX_EQUIPPED)
	end
	profile.upgrades = sanitizeUpgrades(slice.upgrades)
	if type(slice.statistics) == "table" then
		profile.statistics = copyStats(slice.statistics :: { [string]: number })
	else
		profile.statistics = {}
	end
	if type(slice.introducedMonsters) == "table" then
		profile.introducedMonsters = sanitizeMonsterIdList(slice.introducedMonsters :: { string })
	else
		profile.introducedMonsters = {}
	end
	if type(slice.introducedBrainrots) == "table" then
		profile.introducedBrainrots = sanitizeBrainrotIntroList(slice.introducedBrainrots :: { string })
	else
		profile.introducedBrainrots = {}
	end
	profile.sessionStartedAt = os.clock()
	profile.hydrated = true
	broadcast(player)
	ProgressService.applyMovement(player)
end

function ProgressService.reset(player: Player)
	profiles[player.UserId] = {
		brains = ProgressConfig.STARTING_BRAINS,
		unlocks = defaultUnlocks(),
		equipped = defaultEquipped(),
		upgrades = {},
		statistics = {},
		introducedMonsters = {},
		introducedBrainrots = {},
		sessionStartedAt = os.clock(),
		hydrated = true,
	}
	broadcast(player)
	ProgressService.applyMovement(player)
end

function ProgressService.isUnlocked(player: Player, brainrotId: string): boolean
	local profile = profiles[player.UserId]
	if not profile then
		return false
	end
	for _, id in profile.unlocks do
		if id == brainrotId then
			return true
		end
	end
	return false
end

function ProgressService.isEquipped(player: Player, brainrotId: string): boolean
	local profile = profiles[player.UserId]
	if not profile then
		return false
	end
	for _, id in profile.equipped do
		if id == brainrotId then
			return true
		end
	end
	return false
end

function ProgressService.canPlace(player: Player, brainrotId: string): boolean
	if not Brainrots.isPlayable(brainrotId) then
		return false
	end
	return ProgressService.isUnlocked(player, brainrotId) and ProgressService.isEquipped(player, brainrotId)
end

-- TEMP Studio cheat: unlock + equip every registry Brainrot (see DevConfig).
function ProgressService.applyDevRoster(player: Player)
	if not DevConfig.isActive() or not DevConfig.UNLOCK_ALL_BRAINROTS then
		return
	end
	local profile = ensureProfile(player)
	if not profile.hydrated then
		return
	end
	local allIds: { string } = {}
	for id in pairs(Brainrots.getAll()) do
		if not Brainrots.isPlayable(id) then
			continue
		end
		table.insert(allIds, id)
	end
	table.sort(allIds)
	profile.unlocks = sanitizeIdList(allIds)
	profile.equipped = sanitizeIdList(allIds, unlockSet(profile.unlocks), ProgressConfig.MAX_EQUIPPED)
	broadcast(player)
end

function ProgressService.addBrains(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	local profile = ensureProfile(player)
	if not profile.hydrated then
		return
	end
	local grant = math.floor(amount)
	profile.brains += grant
	local key = ProgressConfig.STAT_BRAINS_EARNED
	profile.statistics[key] = (profile.statistics[key] or 0) + grant
	broadcast(player)
end

function ProgressService.brainsForLevel(levelNumber: number): number
	return math.max(0, math.floor(levelNumber * ProgressConfig.BRAINS_PER_LEVEL_NUMBER))
end

function ProgressService.brainsFromLeftoverCoins(coins: number): number
	if coins <= 0 then
		return 0
	end
	local per = EconomyConfig.COINS_PER_LEFTOVER_BRAIN
	if per <= 0 then
		return 0
	end
	local raw = math.floor(coins / per)
	return math.max(0, raw)
end

-- Starter-roster unlock cadence (ProgressConfig.UNLOCK_SCHEDULE). Idempotent:
-- returns the newly unlocked Brainrot id the first time `clearedLevelNumber`
-- is reached, nil on replay (Day Select) or if nothing is scheduled for it.
-- Auto-equips the unlock when there's an open loadout slot.
function ProgressService.grantUnlockForLevel(player: Player, clearedLevelNumber: number): string?
	local scheduled: string? = nil
	for _, entry in ProgressConfig.UNLOCK_SCHEDULE do
		if entry.day == clearedLevelNumber then
			scheduled = entry.brainrotId
			break
		end
	end
	if not scheduled or not Brainrots.isPlayable(scheduled) then
		return nil
	end

	local profile = ensureProfile(player)
	if not profile.hydrated or ProgressService.isUnlocked(player, scheduled) then
		return nil
	end

	table.insert(profile.unlocks, scheduled)
	if #profile.equipped < ProgressConfig.MAX_EQUIPPED then
		table.insert(profile.equipped, scheduled)
	end
	markIntroduced(profile.introducedBrainrots, scheduled)
	return scheduled
end

-- Grant REACH_UNLOCK_SCHEDULE units the first time the player reaches `day`
-- (catch-up for day <= dayNumber). Does not mark intros; BRAINROT_INTRO_SCHEDULE
-- still shows UnlockPopup.
function ProgressService.consumeReachUnlocksForDay(player: Player, dayNumber: number)
	local profile = ensureProfile(player)
	if not profile.hydrated then
		return
	end
	local granted = false
	for _, entry in ProgressConfig.REACH_UNLOCK_SCHEDULE do
		if entry.day > dayNumber or not Brainrots.isPlayable(entry.brainrotId) then
			continue
		end
		if ProgressService.isUnlocked(player, entry.brainrotId) then
			continue
		end
		table.insert(profile.unlocks, entry.brainrotId)
		if #profile.equipped < ProgressConfig.MAX_EQUIPPED then
			table.insert(profile.equipped, entry.brainrotId)
		end
		granted = true
	end
	if granted then
		broadcast(player)
	end
end

-- Reach-day Brainrot intros (starters + reach-unlocks). Catch-up: every BRAINROT_INTRO_SCHEDULE
-- entry with day <= dayNumber not yet persisted. Unlock-schedule units are
-- marked introduced in grantUnlockForLevel instead.
function ProgressService.consumeBrainrotIntrosForDay(player: Player, dayNumber: number): { string }
	local profile = ensureProfile(player)
	if not profile.hydrated then
		return {}
	end
	local granted: { string } = {}
	for _, entry in ProgressConfig.BRAINROT_INTRO_SCHEDULE do
		if entry.day > dayNumber or not Brainrots.isPlayable(entry.brainrotId) then
			continue
		end
		if listContains(profile.introducedBrainrots, entry.brainrotId) then
			continue
		end
		markIntroduced(profile.introducedBrainrots, entry.brainrotId)
		table.insert(granted, entry.brainrotId)
	end
	return granted
end

-- Monster / boss intro cadence. Catch-up: every MONSTER_INTRO_SCHEDULE entry
-- with day <= dayNumber not yet in SaveData.introducedMonsters.
function ProgressService.consumeMonsterIntrosForDay(player: Player, dayNumber: number): { string }
	local profile = ensureProfile(player)
	if not profile.hydrated then
		return {}
	end
	local granted: { string } = {}
	for _, entry in ProgressConfig.MONSTER_INTRO_SCHEDULE do
		if entry.day > dayNumber or not Monsters.exists(entry.monsterId) then
			continue
		end
		if listContains(profile.introducedMonsters, entry.monsterId) then
			continue
		end
		markIntroduced(profile.introducedMonsters, entry.monsterId)
		table.insert(granted, entry.monsterId)
	end
	return granted
end

function ProgressService.getWalkSpeed(player: Player): number
	local speed = PlayerConfig.WALK_SPEED
	local profile = profiles[player.UserId]
	if not profile then
		return speed
	end
	local def = findUpgrade("WalkSpeed")
	if not def then
		return speed
	end
	local level = profile.upgrades["WalkSpeed"] or 0
	local bonus = def.walkSpeedBonusPerLevel
	if type(bonus) ~= "number" then
		bonus = 0
	end
	return speed + level * bonus
end

function ProgressService.applyMovement(player: Player)
	applyWalkSpeedToCharacter(player, ProgressService.getWalkSpeed(player))
end

local function failPurchase(player: Player, reason: string)
	Remotes.getEvent("StorePurchaseFailed"):FireClient(player, reason)
end

local function tryBuyBrainrot(player: Player, brainrotId: string)
	local profile = ensureProfile(player)
	if not profile.hydrated then
		return
	end
	local entry = findStoreBrainrot(brainrotId)
	if not entry or not Brainrots.isPlayable(brainrotId) then
		failPurchase(player, "That Brainrot is not for sale")
		return
	end
	if ProgressService.isUnlocked(player, brainrotId) then
		failPurchase(player, "You already own this Brainrot")
		return
	end
	if profile.brains < entry.brainsCost then
		failPurchase(player, "Not enough brains")
		return
	end
	profile.brains -= entry.brainsCost
	table.insert(profile.unlocks, brainrotId)
	if #profile.equipped < ProgressConfig.MAX_EQUIPPED then
		table.insert(profile.equipped, brainrotId)
	end
	markIntroduced(profile.introducedBrainrots, brainrotId)
	broadcast(player)
	Remotes.getEvent("StorePurchaseSucceeded"):FireClient(player, entry.brainsCost)
end

local function tryBuyUpgrade(player: Player, upgradeId: string)
	local profile = ensureProfile(player)
	if not profile.hydrated then
		return
	end
	local def = findUpgrade(upgradeId)
	if not def then
		failPurchase(player, "That upgrade is not for sale")
		return
	end
	local current = profile.upgrades[upgradeId] or 0
	if current >= def.maxLevel then
		failPurchase(player, "Already at max level")
		return
	end
	local cost = upgradeCost(def, current + 1)
	if not cost then
		failPurchase(player, "That upgrade is not for sale")
		return
	end
	if profile.brains < cost then
		failPurchase(player, "Not enough brains")
		return
	end
	profile.brains -= cost
	profile.upgrades[upgradeId] = current + 1
	broadcast(player)
	Remotes.getEvent("StorePurchaseSucceeded"):FireClient(player, cost)
	if upgradeId == "WalkSpeed" then
		ProgressService.applyMovement(player)
	end
end

local function onBuyStoreItem(player: Player, raw: unknown)
	if type(raw) ~= "table" then
		return
	end
	local data = raw :: { [string]: any }
	local shop = data.shop
	local id = data.id
	if type(shop) ~= "string" or type(id) ~= "string" then
		return
	end
	local StoreService = require(script.Parent.StoreService)
	if not StoreService.canPlayerUseShop(player, shop) then
		return
	end
	if shop == StoreConfig.SHOP_BRAINROTS then
		tryBuyBrainrot(player, id)
	elseif shop == StoreConfig.SHOP_UPGRADES then
		tryBuyUpgrade(player, id)
	end
end

function ProgressService.incrementStat(player: Player, key: string, amount: number?)
	local profile = ensureProfile(player)
	if not profile.hydrated then
		return
	end
	local delta = amount or 1
	if delta == 0 then
		return
	end
	profile.statistics[key] = (profile.statistics[key] or 0) + delta
	broadcast(player)
end

local function onSetEquipped(player: Player, raw: unknown)
	if type(raw) ~= "table" then
		return
	end
	local profile = ensureProfile(player)
	if not profile.hydrated then
		return
	end
	local LevelService = require(script.Parent.LevelService)
	if LevelService.isLevelActive(player) then
		Remotes.getEvent("PlaceBrainrotFailed"):FireClient(
			player,
			"Unable to change loadout — the day has already started"
		)
		return
	end
	local unlocked = unlockSet(profile.unlocks)
	local requested: { string } = {}
	for _, value in raw :: { any } do
		if type(value) == "string" then
			table.insert(requested, value)
		end
	end
	local nextEquipped = sanitizeIdList(requested, unlocked, ProgressConfig.MAX_EQUIPPED)
	if #nextEquipped == 0 then
		return -- keep at least one equipped; ignore empty loadouts
	end
	profile.equipped = nextEquipped
	broadcast(player)
end

function ProgressService.init()
	Remotes.getEvent("SetEquipped").OnServerEvent:Connect(onSetEquipped)
	Remotes.getEvent("BuyStoreItem").OnServerEvent:Connect(onBuyStoreItem)
end

function ProgressService.start()
	-- Profiles are created on demand / by SaveService.applySaveSlice. Do not
	-- broadcast join defaults — that races restore and shows empty statistics.
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player.UserId]
		if profile and profile.hydrated then
			flushSessionTime(profile)
		end
		profiles[player.UserId] = nil
	end)
	log:info("started")
end

return ProgressService
