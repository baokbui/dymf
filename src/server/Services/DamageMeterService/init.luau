--!strict
--[[
	DamageMeterService
	Server-owned per-day damage ranks for the plot owner HUD. Brainrot rows
	are HP dealt to monsters (every CombatService hit that passes
	sourceBrainrotId); monster rows are HP-equivalent dealt to Brainrots.
	UI is display-only — this service never trusts the client.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)

local DamageMeterService = {}
DamageMeterService.Name = "DamageMeterService"

local log = Logger.new(DamageMeterService.Name)

export type RankEntry = { id: string, damage: number }

type Totals = {
	brainrots: { [string]: number },
	monsters: { [string]: number },
}

local totals: { [number]: Totals } = {}
local dirty: { [number]: boolean } = {}

local function getTotals(userId: number): Totals
	local bucket = totals[userId]
	if bucket then
		return bucket
	end
	bucket = {
		brainrots = {},
		monsters = {},
	}
	totals[userId] = bucket
	return bucket
end

local function rankMap(map: { [string]: number }): { RankEntry }
	local entries: { RankEntry } = {}
	for id, damage in map do
		if damage > 0 then
			table.insert(entries, { id = id, damage = damage })
		end
	end
	table.sort(entries, function(a, b)
		if a.damage == b.damage then
			return a.id < b.id
		end
		return a.damage > b.damage
	end)
	local top = CombatConfig.DAMAGE_METER_TOP
	if #entries > top then
		local trimmed: { RankEntry } = {}
		for i = 1, top do
			trimmed[i] = entries[i]
		end
		return trimmed
	end
	return entries
end

local function payloadFor(userId: number): { [string]: any }
	local bucket = getTotals(userId)
	return {
		brainrots = rankMap(bucket.brainrots),
		monsters = rankMap(bucket.monsters),
	}
end

local function broadcast(player: Player)
	dirty[player.UserId] = false
	Remotes.getEvent("DamageMeterUpdated"):FireClient(player, payloadFor(player.UserId))
end

function DamageMeterService.getClientState(player: Player): { [string]: any }
	return payloadFor(player.UserId)
end

function DamageMeterService.recordBrainrot(userId: number, brainrotId: string, amount: number)
	if amount <= 0 then
		return
	end
	local bucket = getTotals(userId)
	bucket.brainrots[brainrotId] = (bucket.brainrots[brainrotId] or 0) + amount
	dirty[userId] = true
end

function DamageMeterService.recordMonster(userId: number, monsterId: string, amount: number)
	if amount <= 0 then
		return
	end
	local bucket = getTotals(userId)
	bucket.monsters[monsterId] = (bucket.monsters[monsterId] or 0) + amount
	dirty[userId] = true
end

function DamageMeterService.reset(player: Player)
	totals[player.UserId] = {
		brainrots = {},
		monsters = {},
	}
	broadcast(player)
end

function DamageMeterService.init()
end

function DamageMeterService.start()
	Players.PlayerRemoving:Connect(function(player)
		totals[player.UserId] = nil
		dirty[player.UserId] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(CombatConfig.DAMAGE_METER_BROADCAST_INTERVAL)
			for _, player in Players:GetPlayers() do
				if dirty[player.UserId] then
					broadcast(player)
				end
			end
		end
	end)

	log:info("started")
end

return DamageMeterService
