--!strict
-- Pure rules shared by server rewards and client presentation.
local Shared = script.Parent.Parent
local Config = require(Shared.Config.FarmProgressionConfig)
local Levels = require(Shared.Levels)
local Fusion = require(script.Parent.MonsterFusion)
local FusionConfig = require(Shared.Config.MonsterFusionConfig)
local Farm = {}

function Farm.rate(id: string): number
	local entry = Config.MONSTERS[id]
	return if entry then entry.rate else 0
end

function Farm.formatRate(rate: number): string
	return string.format("%.6f brains/s", rate)
end

function Farm.sanitizeMap(raw: any, stars: boolean?): { [string]: number }
	local result = {}
	if type(raw) ~= "table" then return result end
	for id, value in raw do
		local valid = type(id) == "string" and (if stars then Levels.get(id) ~= nil else Config.MONSTERS[id] ~= nil)
		if valid and type(value) == "number" and value == value and value >= 0 and value < math.huge then
			result[id] = math.clamp(math.floor(value), 0, if stars then 3 else 1000000)
		end
	end
	return result
end

function Farm.parTime(day: number): number
	local definition = Levels.getByNumber(day)
	local scheduled = 0
	if definition then
		for _, group in definition.groups do
			scheduled += group.startDelay + math.max(0, group.count - 1) * group.spawnInterval
		end
	end
	return math.ceil(math.max(Config.TIME_BASE + day * Config.TIME_PER_DAY, scheduled + Config.TIME_GRACE))
end

function Farm.goals(day: number): { string }
	local par = Farm.parTime(day)
	local variant = (day - 1) % 4
	if variant == 0 then return { "Finish with at least 3 hearts", "Clear without a house breach" } end
	if variant == 1 then return { "Allow at most 2 house breaches", string.format("No breaches and clear within %ds", par) } end
	if variant == 2 then return { "Allow at most 1 house breach", "Clear without a house breach" } end
	return { "Finish with at least 2 hearts", string.format("At most 1 breach and clear within %ds", par) }
end

function Farm.stars(day: number, hearts: number, breaches: number, elapsed: number): number
	local variant = (day - 1) % 4
	local par = Farm.parTime(day)
	local second, third
	if variant == 0 then second, third = hearts >= 3, breaches == 0
	elseif variant == 1 then second, third = breaches <= 2, breaches == 0 and elapsed <= par
	elseif variant == 2 then second, third = breaches <= 1, breaches == 0
	else second, third = hearts >= 2, breaches <= 1 and elapsed <= par end
	if third then return 3 end
	return if second then 2 else 1
end

function Farm.pool(day: number): { string }
	local region = Config.REGIONS[1]
	for _, entry in Config.REGIONS do
		if day >= entry.first and day <= entry.last then region = entry; break end
	end
	local seen, result = {}, {}
	for number = region.first, region.last do
		local definition = Levels.getByNumber(number)
		if not definition then continue end
		for _, group in definition.groups do
			if Config.MONSTERS[group.monsterId] and not seen[group.monsterId] then
				seen[group.monsterId] = true
				table.insert(result, group.monsterId)
			end
		end
	end
	if region.first == 21 and not seen.GoblinKing then table.insert(result, "GoblinKing") end
	return result
end

function Farm.roll(pool: { string }, rng: Random): string?
	local total = 0
	for _, id in pool do total += Config.MONSTERS[id].weight end
	if total <= 0 then return nil end
	local roll = rng:NextNumber(0, total)
	for _, id in pool do
		roll -= Config.MONSTERS[id].weight
		if roll <= 0 then return id end
	end
	return pool[#pool]
end

function Farm.brains(base: number, stars: number): number
	return math.max(base + stars - 1, math.floor(base * Config.STAR_BRAINS_MULTIPLIER[stars]))
end

function Farm.rewards(day: number, stars: number, rng: Random): { [string]: number }
	local result = {}
	local pool = Farm.pool(day)
	for _ = 1, Config.STAR_SHARD_ROLLS[stars] do
		local id = Farm.roll(pool, rng)
		if id then result[id] = (result[id] or 0) + 1 end
	end
	return result
end

function Farm.monsterRate(monster: Fusion.Monster): number
	local tier = Fusion.tier(monster.tier)
	return Farm.rate(monster.monsterId) * (if tier then tier.income else 1)
end

function Farm.combine(snapshot: any, id: string, rng: Random?, uid: string?, operation: string?): (number?, string?, any?)
	local definition = Config.MONSTERS[id]
	if not definition then return nil, "InvalidRequest", nil end
	local signature = Fusion.signature("Monster", id)
	if operation then
		local found, reason, receipt = Fusion.retry(snapshot, operation, signature)
		if found then return if receipt then 0 else nil, reason, receipt end
	end
	if (snapshot.monsterShards[id] or 0) < definition.shards then return nil, "NotReady", nil end
	local identity = uid or game:GetService("HttpService"):GenerateGUID(false)
	return 0, nil, { kind = "FarmMonster", monsterId = id, shardCost = definition.shards,
		monster = Fusion.roll(id, FusionConfig.COMBINE_WEIGHTS, rng or Random.new(), identity),
		operation = operation or identity, signature = signature }
end

function Farm.fuse(snapshot: any, ids: any, rng: Random, uid: string, operation: string): (number?, string?, any?)
	-- Validate structure before sorting untrusted ids or checking retry receipts.
	if type(ids) ~= "table" or #ids < 3 or #ids > 5 then return nil, "InvalidRequest", nil end
	local count = 0
	for key, value in ids do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > #ids or type(value) ~= "string" or #value > 80 then return nil, "InvalidRequest", nil end
		count += 1
	end
	if count ~= #ids then return nil, "InvalidRequest", nil end
	local signature = Fusion.signature("MonsterFusion", ids)
	local found, reason, receipt = Fusion.retry(snapshot, operation, signature)
	if found then return if receipt then 0 else nil, reason, receipt end
	local species, failure = Fusion.ingredients(snapshot.farmMonsters, ids)
	if not species then return nil, failure, nil end
	return 0, nil, { kind = "FarmFusion", monster = Fusion.roll(species, FusionConfig.FUSION_WEIGHTS[#ids], rng, uid),
		consumed = table.clone(ids), operation = operation, signature = signature }
end

return Farm
