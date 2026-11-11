--!strict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.FarmProgressionConfig)
local Farm = require(Shared.Utilities.FarmProgression)
local Monsters = require(Shared.Monsters)
local Remotes = require(Shared.Remotes)
local SkyShard = require(script.SkyShard)
local Service = { Name = "FarmProgressionService" }
type Attempt = { day: number, started: number, breaches: number, nextRoll: number, drops: number, cleanup: { () -> () } }
local attempts: { [Player]: Attempt } = {}
local requests: { [Player]: number } = {}
local rng = Random.new()

function Service.finish(player: Player)
	local attempt = attempts[player]
	if attempt then for _, cleanup in attempt.cleanup do cleanup() end end
	attempts[player] = nil
end

function Service.begin(player: Player, day: number)
	Service.finish(player)
	attempts[player] = { day = day, started = os.clock(), breaches = 0,
		nextRoll = os.clock() + Config.SKY_ROLL_INTERVAL, drops = 0, cleanup = {} }
end

function Service.breach(player: Player)
	local attempt = attempts[player]
	if attempt then attempt.breaches += 1 end
end

function Service.resolve(player: Player, day: number, hearts: number): (number, { [string]: number })
	local attempt = attempts[player]
	if not attempt or attempt.day ~= day then return 1, {} end
	local stars = Farm.stars(day, hearts, attempt.breaches, os.clock() - attempt.started)
	local shards = Farm.rewards(day, stars, rng)
	Service.finish(player)
	return stars, shards
end

local function rollSky(player: Player, attempt: Attempt)
	local roll = rng:NextNumber()
	local major = roll < Config.SKY_MAJOR_CHANCE
	if not major and roll >= Config.SKY_MAJOR_CHANCE + Config.SKY_BOSS_CHANCE then return end
	local pool = {}
	local candidates = if major then { "PharaohMummy" } else Farm.pool(attempt.day)
	for _, id in candidates do
		if Monsters.get(id).isBoss and (Config.MONSTERS[id].major == true) == major then table.insert(pool, id) end
	end
	if #pool == 0 then return end
	local plot = require(script.Parent.PlotService).getPlotModel(player)
	if not plot then return end
	attempt.drops += 1
	local id = pool[rng:NextInteger(1, #pool)]
	table.insert(attempt.cleanup, SkyShard.spawn(player, plot, id, function()
		if attempts[player] ~= attempt or not require(script.Parent.LevelService).isLevelActive(player) then return end
		require(script.Parent.ProgressService).addMonsterShards(player, { [id] = 1 })
	end))
end

function Service.start()
	Players.PlayerRemoving:Connect(function(player) Service.finish(player); requests[player] = nil end)
	local function request(player: Player, kind: string, id: any, ids: any, operation: any)
		if type(operation) ~= "string" or #operation < 8 or #operation > 80 then return end
		if kind == "Monster" and (type(id) ~= "string" or not Config.MONSTERS[id]) then return end
		if os.clock() < (requests[player] or 0) then return end
		requests[player] = os.clock() + 1
		local success, reason, _, grant = require(script.Parent.SaveService).claimRetentionReward(player, kind, 0,
			if kind == "Monster" then id else "Fusion", ids, operation)
		if player.Parent then
			Remotes.getEvent(if kind == "Monster" then "MonsterCombineResult" else "MonsterFusionResult"):FireClient(player,
				{ success = success, reason = reason, monsterId = id, monster = if grant then grant.monster else nil, operation = operation })
		end
	end
	Remotes.getEvent("CombineMonsterShards").OnServerEvent:Connect(function(player, id, operation)
		request(player, "Monster", id, nil, operation)
	end)
	Remotes.getEvent("FuseFarmMonsters").OnServerEvent:Connect(function(player, ids, operation)
		request(player, "MonsterFusion", nil, ids, operation)
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for player, attempt in attempts do
				if not require(script.Parent.LevelService).isLevelActive(player) then Service.finish(player); continue end
				if os.clock() >= attempt.nextRoll and attempt.drops < Config.SKY_DROP_LIMIT then
					attempt.nextRoll = os.clock() + Config.SKY_ROLL_INTERVAL
					rollSky(player, attempt)
				end
			end
		end
	end)
end

return Service
