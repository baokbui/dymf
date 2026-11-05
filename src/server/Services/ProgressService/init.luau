--!strict
--[[
	ProgressService
	Owns brains, unlocks, equipped loadout, player upgrades, statistics,
	per-species Brainrot XP, and claimed evolution tiers (brains spend after
	the level gate). Brainrot XP from an unfinished / failed day is held as a
	Start Day snapshot and is not committed until victory (defeat / rewind /
	leave persist the snapshot). The Brainrot shop stall and HUD Upgrades spend brains
	here (Milestone 18).

	Statistics update live via ProfileUpdated. Time played includes the current
	session in client payloads; it is committed into the saved total on flush
	(save / leave).

	Milestone 13.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Brainrots = require(Shared.Brainrots)
local Evolutions = require(Shared.Evolutions)
local Monsters = require(Shared.Monsters)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local ProgressConfig = require(Shared.Config.ProgressConfig)
local EvolutionConfig = require(Shared.Config.EvolutionConfig)
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
	brainrotXp: { [string]: number },
	evolutions: { [string]: { string } },
	introducedMonsters: { string },
	introducedBrainrots: { string },
	introducedMechanics: { string },
	sessionStartedAt: number,
	hydrated: boolean, -- false until SaveService.applySaveSlice (or reset)
}

local profiles: { [number]: Profile } = {}
local xpBroadcastThreads: { [number]: thread } = {}
-- Day-start XP snapshot. Live grants during Countdown/Active are not
-- committed until victory; defeat / autosave / leave restore or persist this.
local dayStartXp: { [number]: { [string]: number } } = {}

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

local function copyXp(source: { [string]: number }): { [string]: number }
	return copyStats(source)
end

local function copyEvolutions(source: { [string]: { string } }): { [string]: { string } }
	local result: { [string]: { string } } = {}
	for brainrotId, rarities in source do
		result[brainrotId] = copyList(rarities)
	end
	return result
end

local function sanitizeEvolutions(raw: { [string]: { string } }?): { [string]: { string } }
	local result: { [string]: { string } } = {}
	if type(raw) ~= "table" then
		return result
	end
	for brainrotId, rarities in raw do
		if type(brainrotId) ~= "string" or not Brainrots.exists(brainrotId) then
			continue
		end
		if type(rarities) ~= "table" then
			continue
		end
		local cleaned = Evolutions.sanitizeClaimed(brainrotId, rarities :: { string })
		if #cleaned > 0 then
			result[brainrotId] = cleaned
		end
	end
	return result
end

local function sanitizeBrainrotXp(raw: { [string]: number }?): { [string]: number }
	local result: { [string]: number } = {}
	if type(raw) ~= "table" then
		return result
	end
	local cap = EvolutionConfig.maxTotalXp()
	for key, value in raw do
		if type(key) ~= "string" or type(value) ~= "number" then
			continue
		end
		if not Brainrots.exists(key) then
			continue
		end
		result[key] = math.clamp(math.floor(value), 0, cap)
	end
	return result
end

local function addXp(profile: Profile, brainrotId: string, amount: number)
	if amount <= 0 or not Brainrots.exists(brainrotId) then
		return
	end
	local cap = EvolutionConfig.maxTotalXp()
	local current = profile.brainrotXp[brainrotId] or 0
	profile.brainrotXp[brainrotId] = math.clamp(current + math.floor(amount), 0, cap)
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
	return ProgressConfig.upgradeById(upgradeId)
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

local function sanitizeMechanicIntroList(raw: { string }): { string }
	local seen: { [string]: boolean } = {}
	local result: { string } = {}
	for _, id in raw do
		if type(id) ~= "string" or seen[id] or not ProgressConfig.isMechanicIntroId(id) then
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
		brainrotXp = {},
		evolutions = {},
		introducedMonsters = {},
		introducedBrainrots = {},
		introducedMechanics = {},
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
		brainrotXp = copyXp(profile.brainrotXp),
		evolutions = copyEvolutions(profile.evolutions),
		introducedMonsters = copyList(profile.introducedMonsters),
		introducedBrainrots = copyList(profile.introducedBrainrots),
	}
end

local function cancelXpBroadcast(userId: number)
	local pending = xpBroadcastThreads[userId]
	if pending then
		task.cancel(pending)
		xpBroadcastThreads[userId] = nil
	end
end

local function broadcast(player: Player)
	local profile = profiles[player.UserId]
	if not profile or not profile.hydrated then
		return
	end
	cancelXpBroadcast(player.UserId)
	local payload = buildPayload(profile)
	Remotes.getEvent("ProfileUpdated"):FireClient(player, payload)
	require(script.Parent.RetentionService).profileChanged(player, payload)
end

-- Coin / soak / freeze ticks are frequent (Encore Ballerina especially).
-- Coalesce so the client is not rebuilt dozens of times per second.
local function scheduleXpBroadcast(player: Player)
	local profile = profiles[player.UserId]
	if not profile or not profile.hydrated then
		return
	end
	local userId = player.UserId
	if xpBroadcastThreads[userId] then
		return
	end
	xpBroadcastThreads[userId] = task.delay(ProgressConfig.XP_BROADCAST_INTERVAL, function()
		xpBroadcastThreads[userId] = nil
		if player.Parent then
			broadcast(player)
		end
	end)
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
			brainrotXp = {},
			evolutions = {},
			introducedMonsters = {},
			introducedBrainrots = {},
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
	brainrotXp: { [string]: number },
	evolutions: { [string]: { string } },
	introducedMonsters: { string },
	introducedBrainrots: { string },
	introducedMechanics: { string },
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
		brainrotXp = copyXp(dayStartXp[player.UserId] or profile.brainrotXp),
		evolutions = copyEvolutions(profile.evolutions),
		introducedMonsters = copyList(profile.introducedMonsters),
		introducedBrainrots = copyList(profile.introducedBrainrots),
		introducedMechanics = copyList(profile.introducedMechanics),
	}
end

function ProgressService.applySaveSlice(player: Player, slice: {
	brains: number?,
	unlocks: { string }?,
	equipped: { string }?,
	upgrades: { [string]: number }?,
	statistics: { [string]: number }?,
	brainrotXp: { [string]: number }?,
	evolutions: { [string]: { string } }?,
	introducedMonsters: { string }?,
	introducedBrainrots: { string }?,
	introducedMechanics: { string }?,
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
	profile.brainrotXp = sanitizeBrainrotXp(slice.brainrotXp)
	profile.evolutions = sanitizeEvolutions(slice.evolutions)
	if type(slice.introducedMonsters) == "table" then
		profile.introducedMonsters = sanitizeMonsterIdList(slice.introducedMonsters :: { string })
	else
		profile.introducedMonsters = {}
	end
	if type(slice.introducedBrainrots) == "table" then
		-- Unlock-schedule, reach-intro, and store-grant ids — any playable Brainrot.
		profile.introducedBrainrots = sanitizeIdList(slice.introducedBrainrots :: { string })
	else
		profile.introducedBrainrots = {}
	end
	if type(slice.introducedMechanics) == "table" then
		profile.introducedMechanics = sanitizeMechanicIntroList(slice.introducedMechanics :: { string })
	else
		profile.introducedMechanics = {}
	end
	profile.sessionStartedAt = os.clock()
	profile.hydrated = true
	dayStartXp[player.UserId] = nil
	broadcast(player)
	ProgressService.applyMovement(player)
end

function ProgressService.reset(player: Player, retainedUpgrades: { [string]: number }?)
	dayStartXp[player.UserId] = nil
	profiles[player.UserId] = {
		brains = ProgressConfig.STARTING_BRAINS,
		unlocks = defaultUnlocks(),
		equipped = defaultEquipped(),
		upgrades = sanitizeUpgrades(retainedUpgrades),
		statistics = {},
		brainrotXp = {},
		evolutions = {},
		introducedMonsters = {},
		introducedBrainrots = {},
		introducedMechanics = {},
		sessionStartedAt = os.clock(),
		hydrated = true,
	}
	broadcast(player)
	ProgressService.applyMovement(player)
end

function ProgressService.checkpointBrainrotXp(player: Player)
	local profile = profiles[player.UserId]
	if not profile or not profile.hydrated then
		return
	end
	dayStartXp[player.UserId] = copyXp(profile.brainrotXp)
end

function ProgressService.commitBrainrotXp(player: Player)
	dayStartXp[player.UserId] = nil
end

function ProgressService.restoreBrainrotXpCheckpoint(player: Player)
	local profile = profiles[player.UserId]
	local snapshot = dayStartXp[player.UserId]
	if not profile or not profile.hydrated or not snapshot then
		return
	end
	profile.brainrotXp = copyXp(snapshot)
	local BrainrotService = require(script.Parent.BrainrotService)
	BrainrotService.syncNameplates(player)
	broadcast(player)
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

-- TEMP Studio cheat: unlock every registry Brainrot (see DevConfig).
-- The shop loadout stays whatever the player saved. A default is only filled
-- when the profile has no equipped units.
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
	local unlocked = unlockSet(profile.unlocks)
	local kept = sanitizeIdList(profile.equipped, unlocked, ProgressConfig.MAX_EQUIPPED)
	if #kept == 0 then
		kept = sanitizeIdList(defaultEquipped(), unlocked, ProgressConfig.MAX_EQUIPPED)
	end
	profile.equipped = kept
	broadcast(player)
end

local function claimedThroughRarity(brainrotId: string, stopRarity: string, existing: { string }?): { string }
	local raw: { string } = {}
	for _, row in Evolutions.rowsFor(brainrotId) do
		table.insert(raw, row.rarity)
		if row.rarity == stopRarity then
			break
		end
	end
	if Evolutions.claimedSet(existing)["God"] and stopRarity ~= "God" then
		table.insert(raw, "God")
	end
	return Evolutions.sanitizeClaimed(brainrotId, raw)
end

-- TEMP Studio cheat: floor XP + claim Epic→tier at FORCE_BRAINROT_LEVEL (see DevConfig).
function ProgressService.applyDevEvolutions(player: Player)
	if not DevConfig.isActive() then
		return
	end
	local targetLevel = DevConfig.FORCE_BRAINROT_LEVEL
	if type(targetLevel) ~= "number" or targetLevel < 1 then
		return
	end
	local profile = ensureProfile(player)
	if not profile.hydrated then
		return
	end
	local clampedLevel = math.clamp(math.floor(targetLevel), 1, EvolutionConfig.MAX_LEVEL)
	local targetXp = EvolutionConfig.xpForLevel(clampedLevel)
	local tier = EvolutionConfig.tierForLevel(clampedLevel)
	local stopRarity = if tier and tier.id ~= "Common" then tier.id else nil
	for id in pairs(Brainrots.getAll()) do
		if not Brainrots.isPlayable(id) then
			continue
		end
		profile.brainrotXp[id] = math.max(profile.brainrotXp[id] or 0, targetXp)
		if stopRarity then
			profile.evolutions[id] = claimedThroughRarity(id, stopRarity, profile.evolutions[id])
		end
	end
	local BrainrotService = require(script.Parent.BrainrotService)
	for id in pairs(profile.evolutions) do
		BrainrotService.applyEvolutionStats(player, id)
		BrainrotService.syncNameplates(player, id)
	end
	broadcast(player)
end

-- TEMP Studio cheat: force playtest brains (see DevConfig).
function ProgressService.applyDevBrains(player: Player)
	if not DevConfig.isActive() then
		return
	end
	local profile = ensureProfile(player)
	if not profile.hydrated then
		return
	end
	profile.brains = math.max(0, math.floor(DevConfig.BRAINS))
	broadcast(player)
end

function ProgressService.addBrains(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	local profile = profiles[player.UserId]
	if not profile or not profile.hydrated then
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

-- Reach-day Brainrot intros (reach-unlocks). Catch-up: every BRAINROT_INTRO_SCHEDULE
-- entry with day <= dayNumber not yet persisted. Unlock-schedule units are
-- marked introduced in grantUnlockForLevel instead. Day 1 starters are not scheduled.
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

-- One-off intro (Hidden Day Goblin King). Returns true the first time.
function ProgressService.introduceMonster(player: Player, monsterId: string): boolean
	local profile = ensureProfile(player)
	if not profile.hydrated or not Monsters.exists(monsterId) then
		return false
	end
	if listContains(profile.introducedMonsters, monsterId) then
		return false
	end
	markIntroduced(profile.introducedMonsters, monsterId)
	return true
end

-- Mechanic / hazard intros (graves). Catch-up: every MECHANIC_INTRO_SCHEDULE
-- entry with day <= dayNumber not yet in SaveData.introducedMechanics.
function ProgressService.consumeMechanicIntrosForDay(player: Player, dayNumber: number): { string }
	local profile = ensureProfile(player)
	if not profile.hydrated then
		return {}
	end
	local granted: { string } = {}
	for _, entry in ProgressConfig.MECHANIC_INTRO_SCHEDULE do
		if entry.day > dayNumber or not ProgressConfig.isMechanicIntroId(entry.id) then
			continue
		end
		if listContains(profile.introducedMechanics, entry.id) then
			continue
		end
		markIntroduced(profile.introducedMechanics, entry.id)
		table.insert(granted, entry.id)
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

function ProgressService.getMagnetLevel(player: Player): number
	local def = findUpgrade("Magnet")
	if not def then
		return 1
	end
	local profile = profiles[player.UserId]
	local stored = if profile then profile.upgrades["Magnet"] else nil
	return ProgressConfig.upgradeLevel(def, stored)
end

function ProgressService.applyMovement(player: Player)
	applyWalkSpeedToCharacter(player, ProgressService.getWalkSpeed(player))
end

-- Called only after SaveService durably commits the matching reward snapshot.
function ProgressService.applyDurableReward(player: Player, grant: any)
	local profile = profiles[player.UserId]
	if not profile or not profile.hydrated then return end
	if grant.kind == "Upgrade" then
		profile.upgrades[grant.upgradeId] = math.max(profile.upgrades[grant.upgradeId] or 0, grant.level)
		ProgressService.applyMovement(player)
	elseif grant.kind == "Brainrot" then
		if not table.find(profile.unlocks, grant.brainrotId) then table.insert(profile.unlocks, grant.brainrotId) end
		if #profile.equipped < ProgressConfig.MAX_EQUIPPED and not table.find(profile.equipped, grant.brainrotId) then table.insert(profile.equipped, grant.brainrotId) end
		markIntroduced(profile.introducedBrainrots, grant.brainrotId)
	end
	broadcast(player)
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
		failPurchase(player, "Not enough Brains.")
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
	local stored = profile.upgrades[upgradeId] or 0
	local current = ProgressConfig.upgradeLevel(def, stored)
	if current >= def.maxLevel then
		failPurchase(player, "Already at max level")
		return
	end
	local cost = ProgressConfig.nextUpgradeCost(def, current)
	if not cost then
		failPurchase(player, "That upgrade is not for sale")
		return
	end
	if profile.brains < cost then
		failPurchase(player, "Not enough Brains.")
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
	local SaveService = require(script.Parent.SaveService)
	if SaveService.isProgressionLocked(player) then failPurchase(player, "Saving progress. Try again shortly."); return end
	if shop == StoreConfig.SHOP_BRAINROTS and data.useTicket == true then
		local ok, reason = SaveService.claimRetentionReward(player, "Ticket", 0, id)
		if ok then Remotes.getEvent("StorePurchaseSucceeded"):FireClient(player, 0)
		else failPurchase(player, if reason == "NotReady" then "No free Brainrot tickets available." else "Unable to redeem ticket. Try again shortly.") end
	elseif shop == StoreConfig.SHOP_BRAINROTS then
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

-- Silent: mutates XP without broadcasting. Callers that also increment a
-- statistic (monster death) rely on that increment's ProfileUpdated.
function ProgressService.grantKillXp(player: Player, lastHitBrainrotId: string?, isBoss: boolean)
	local profile = ensureProfile(player)
	if not profile.hydrated then
		return
	end
	if isBoss then
		local PlotService = require(script.Parent.PlotService)
		local BrainrotService = require(script.Parent.BrainrotService)
		local plotModel = PlotService.getPlotModel(player)
		if not plotModel then
			return
		end
		local living: { { instanceId: string, brainrotId: string } } = {}
		for _, placement in BrainrotService.getPlacements(plotModel) do
			if placement.health > 0 then
				table.insert(living, {
					instanceId = placement.instanceId,
					brainrotId = placement.definition.id,
				})
			end
		end
		table.sort(living, function(a, b)
			return a.instanceId < b.instanceId
		end)
		local count = #living
		if count == 0 then
			return
		end
		local total = EvolutionConfig.BOSS_XP
		local base = math.floor(total / count)
		local remainder = total % count
		for index, entry in living do
			addXp(profile, entry.brainrotId, base + (if index <= remainder then 1 else 0))
		end
		BrainrotService.syncNameplates(player)
		return
	end
	if type(lastHitBrainrotId) ~= "string" then
		return
	end
	local definition = Brainrots.get(lastHitBrainrotId)
	if definition and EvolutionConfig.skipsLastHit(definition.ability) then
		return
	end
	addXp(profile, lastHitBrainrotId, EvolutionConfig.KILL_XP)
	local BrainrotService = require(script.Parent.BrainrotService)
	BrainrotService.syncNameplates(player, lastHitBrainrotId)
end

-- Broadcasts so inspect XP bars update (coin / soak / freeze / landed-hit
-- jobs are not paired with a statistic increment).
function ProgressService.grantBrainrotXp(player: Player, brainrotId: string, amount: number)
	local profile = ensureProfile(player)
	if not profile.hydrated then
		return
	end
	local before = EvolutionConfig.parseXp(profile.brainrotXp[brainrotId] or 0).level
	addXp(profile, brainrotId, amount)
	local after = EvolutionConfig.parseXp(profile.brainrotXp[brainrotId] or 0).level
	if after ~= before then
		local BrainrotService = require(script.Parent.BrainrotService)
		BrainrotService.syncNameplates(player, brainrotId)
	end
	scheduleXpBroadcast(player)
end

function ProgressService.grantBrainrotXpForUser(userId: number, brainrotId: string, amount: number)
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return
	end
	ProgressService.grantBrainrotXp(player, brainrotId, amount)
end

function ProgressService.getClaimedEvolutions(player: Player, brainrotId: string): { string }
	local profile = profiles[player.UserId]
	if not profile or not profile.hydrated then
		return {}
	end
	return Evolutions.sanitizeClaimed(brainrotId, profile.evolutions[brainrotId])
end

function ProgressService.getBrainrotLevel(player: Player, brainrotId: string): number
	local profile = profiles[player.UserId]
	if not profile or not profile.hydrated then
		return 1
	end
	return EvolutionConfig.parseXp(profile.brainrotXp[brainrotId] or 0).level
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
			"You can't change your lineup once the day has started."
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
	-- Flush now. Studio stop often kills the process before the leave save
	-- lands, which put the previous shop lineup back on the next Play.
	local SaveService = require(script.Parent.SaveService)
	SaveService.saveNow(player, "loadout")
end

local function onEvolveBrainrot(player: Player, rawId: unknown, rawRarity: unknown)
	if type(rawId) ~= "string" or type(rawRarity) ~= "string" then
		return
	end
	local brainrotId = rawId
	local rarity = rawRarity
	if rarity == "Common" then
		return
	end
	local profile = ensureProfile(player)
	if not profile.hydrated then
		return
	end
	if not ProgressService.isUnlocked(player, brainrotId) then
		failPurchase(player, "You don't own this Brainrot.")
		return
	end
	local row = Evolutions.rowFor(brainrotId, rarity)
	if not row then
		failPurchase(player, "That evolution isn't available.")
		return
	end
	local level = EvolutionConfig.parseXp(profile.brainrotXp[brainrotId] or 0).level
	if not Evolutions.tierUnlocked(row, level) then
		failPurchase(player, "Level this Brainrot more first.")
		return
	end
	local claimed = Evolutions.sanitizeClaimed(brainrotId, profile.evolutions[brainrotId])
	local claimedSet = Evolutions.claimedSet(claimed)
	if claimedSet[rarity] then
		failPurchase(player, "Already evolved")
		return
	end
	local previous = Evolutions.previousRarity(rarity)
	if previous and previous ~= "Common" and not claimedSet[previous] then
		failPurchase(player, "Unlock the earlier evolution first.")
		return
	end
	local cost = EvolutionConfig.brainsCost(rarity)
	if cost <= 0 then
		failPurchase(player, "That evolution isn't available.")
		return
	end
	if profile.brains < cost then
		failPurchase(player, "Not enough Brains.")
		return
	end
	profile.brains -= cost
	table.insert(claimed, rarity)
	profile.evolutions[brainrotId] = claimed
	local BrainrotService = require(script.Parent.BrainrotService)
	BrainrotService.applyEvolutionStats(player, brainrotId)
	broadcast(player)
	Remotes.getEvent("StorePurchaseSucceeded"):FireClient(player, cost)
end

function ProgressService.init()
	Remotes.getEvent("SetEquipped").OnServerEvent:Connect(onSetEquipped)
	Remotes.getEvent("BuyStoreItem").OnServerEvent:Connect(onBuyStoreItem)
	Remotes.getEvent("EvolveBrainrot").OnServerEvent:Connect(onEvolveBrainrot)
end

function ProgressService.start()
	-- Profiles are created on demand / by SaveService.applySaveSlice. Do not
	-- broadcast join defaults — that races restore and shows empty statistics.
	Players.PlayerRemoving:Connect(function(player)
		cancelXpBroadcast(player.UserId)
		local profile = profiles[player.UserId]
		if profile and profile.hydrated then
			flushSessionTime(profile)
		end
		profiles[player.UserId] = nil
	end)
	log:info("started")
end

return ProgressService
