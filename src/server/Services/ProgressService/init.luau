--!strict
--[[
	ProgressService
	Owns brains, unlocks, equipped loadout, and statistics. SaveService persists
	the slice; UI only displays ProfileUpdated pushes. Physical Brainrots Store
	purchases are deferred (Milestone 22).

	Statistics update live via ProfileUpdated. Time played includes the current
	session in client payloads; it is committed into the saved total on flush
	(save / leave).

	Milestone 13.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Brainrots = require(Shared.Brainrots)
local ProgressConfig = require(Shared.Config.ProgressConfig)
local Remotes = require(Shared.Remotes)
local Logger = require(Shared.Utilities.Logger)

local ProgressService = {}
ProgressService.Name = "ProgressService"

local log = Logger.new(ProgressService.Name)

type Profile = {
	brains: number,
	unlocks: { string },
	equipped: { string },
	statistics: { [string]: number },
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

local function defaultUnlocks(): { string }
	return copyList(ProgressConfig.DEFAULT_UNLOCKS)
end

local function defaultEquipped(): { string }
	return copyList(ProgressConfig.DEFAULT_EQUIPPED)
end

local function sanitizeIdList(raw: { string }, requireUnlocked: { [string]: boolean }?): { string }
	local seen: { [string]: boolean } = {}
	local result: { string } = {}
	for _, id in raw do
		if type(id) ~= "string" or seen[id] or not Brainrots.exists(id) then
			continue
		end
		if requireUnlocked and not requireUnlocked[id] then
			continue
		end
		seen[id] = true
		table.insert(result, id)
		if #result >= ProgressConfig.MAX_EQUIPPED then
			break
		end
	end
	return result
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
		statistics = {},
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
			statistics = {},
		}
	end
	return buildPayload(profile)
end

function ProgressService.getSaveSlice(player: Player): {
	brains: number,
	unlocks: { string },
	equipped: { string },
	statistics: { [string]: number },
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
		statistics = copyStats(profile.statistics),
	}
end

function ProgressService.applySaveSlice(player: Player, slice: {
	brains: number?,
	unlocks: { string }?,
	equipped: { string }?,
	statistics: { [string]: number }?,
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
		profile.equipped = sanitizeIdList(slice.equipped :: { string }, unlocked)
	else
		profile.equipped = sanitizeIdList(defaultEquipped(), unlocked)
	end
	if #profile.equipped == 0 then
		profile.equipped = sanitizeIdList(defaultEquipped(), unlocked)
	end
	if type(slice.statistics) == "table" then
		profile.statistics = copyStats(slice.statistics :: { [string]: number })
	else
		profile.statistics = {}
	end
	profile.sessionStartedAt = os.clock()
	profile.hydrated = true
	broadcast(player)
end

function ProgressService.reset(player: Player)
	profiles[player.UserId] = {
		brains = ProgressConfig.STARTING_BRAINS,
		unlocks = defaultUnlocks(),
		equipped = defaultEquipped(),
		statistics = {},
		sessionStartedAt = os.clock(),
		hydrated = true,
	}
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
	return ProgressService.isUnlocked(player, brainrotId) and ProgressService.isEquipped(player, brainrotId)
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
	local unlocked = unlockSet(profile.unlocks)
	local requested: { string } = {}
	for _, value in raw :: { any } do
		if type(value) == "string" then
			table.insert(requested, value)
		end
	end
	local nextEquipped = sanitizeIdList(requested, unlocked)
	if #nextEquipped == 0 then
		return -- keep at least one equipped; ignore empty loadouts
	end
	profile.equipped = nextEquipped
	broadcast(player)
end

function ProgressService.init()
	Remotes.getEvent("SetEquipped").OnServerEvent:Connect(onSetEquipped)
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
