--!strict
-- Pure inventory/recipe rules. Random outcomes and ids are supplied by the server.
local Shared = script.Parent.Parent
local Config = require(Shared.Config.MonsterFusionConfig)
local Species = require(Shared.Config.FarmProgressionConfig).MONSTERS
local Fusion = {}
export type Monster = { uid: string, monsterId: string, tier: string, onFarm: boolean? }

function Fusion.tier(id: string): any?
	for _, tier in Config.TIERS do if tier.id == id then return tier end end
	return nil
end

function Fusion.sanitize(raw: any, legacy: { string }?): { Monster }
	local result, seen = {}, {}
	if type(raw) ~= "table" then
		for _, id in legacy or {} do
			if Species[id] and not seen[id] then
				seen[id] = true
				table.insert(result, { uid = "legacy:" .. id, monsterId = id, tier = "Medium" })
			end
		end
		return result
	end
	for _, monster in raw do
		if type(monster) ~= "table" or type(monster.uid) ~= "string" or #monster.uid > 80
			or #monster.uid == 0 or seen[monster.uid] or not Species[monster.monsterId] or not Fusion.tier(monster.tier) then continue end
		seen[monster.uid] = true
		table.insert(result, { uid = monster.uid, monsterId = monster.monsterId, tier = monster.tier,
			onFarm = if type(monster.onFarm) == "boolean" then monster.onFarm else nil })
	end
	return result
end

function Fusion.roll(species: string, weights: { number }, rng: Random, uid: string): Monster
	local total = 0
	for _, weight in weights do total += weight end
	local roll = rng:NextNumber(0, total)
	for index, weight in weights do
		roll -= weight
		if roll <= 0 then return { uid = uid, monsterId = species, tier = Config.TIERS[index].id, onFarm = false } end
	end
	return { uid = uid, monsterId = species, tier = Config.TIERS[#Config.TIERS].id, onFarm = false }
end

function Fusion.ingredients(monsters: { Monster }, ids: any): (string?, string?)
	if type(ids) ~= "table" or #ids < 3 or #ids > 5 then return nil, "InvalidRequest" end
	local count = 0
	for key in ids do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > #ids then return nil, "InvalidRequest" end
		count += 1
	end
	if count ~= #ids then return nil, "InvalidRequest" end
	local owned = {}
	for _, monster in monsters do owned[monster.uid] = monster end
	local species, seen = nil, {}
	for _, uid in ids do
		if type(uid) ~= "string" or seen[uid] or not owned[uid] then return nil, "NotReady" end
		seen[uid] = true
		if species and species ~= owned[uid].monsterId then return nil, "InvalidRequest" end
		species = owned[uid].monsterId
	end
	return species, nil
end

function Fusion.signature(kind: string, value: any): string
	if kind == "Monster" then return kind .. ":" .. tostring(value) end
	local ids = table.clone(value)
	table.sort(ids)
	return kind .. ":" .. table.concat(ids, ",")
end

function Fusion.receipts(raw: any): { any }
	local result = {}
	if type(raw) ~= "table" then return result end
	local seen = {}
	for _, receipt in raw do
		if type(receipt) ~= "table" or type(receipt.id) ~= "string" or #receipt.id > 80
			or type(receipt.signature) ~= "string" or #receipt.signature > 500 or seen[receipt.id] then continue end
		local monsters = Fusion.sanitize({ receipt.monster })
		if #monsters ~= 1 then continue end
		seen[receipt.id] = true
		table.insert(result, { id = receipt.id, signature = receipt.signature, monster = monsters[1] })
	end
	while #result > Config.RECEIPT_LIMIT do table.remove(result, 1) end
	return result
end

function Fusion.retry(snapshot: any, operation: string, signature: string): (boolean, string?, any?)
	for _, receipt in snapshot.farmReceipts or {} do
		if receipt.id ~= operation then continue end
		if receipt.signature ~= signature then return true, "InvalidRequest", nil end
		return true, nil, { kind = "FarmReceipt", monster = receipt.monster }
	end
	return false, nil, nil
end

function Fusion.apply(snapshot: any, grant: any)
	if grant.kind == "FarmReceipt" then return end
	for _, receipt in snapshot.farmReceipts or {} do
		if receipt.id == grant.operation then return end
	end
	for _, monster in snapshot.farmMonsters or {} do
		if monster.uid == grant.monster.uid then return end
	end
	if grant.kind == "FarmMonster" then
		snapshot.monsterShards[grant.monsterId] -= grant.shardCost
	elseif grant.kind == "FarmFusion" then
		local consumed = {}
		for _, uid in grant.consumed do consumed[uid] = true end
		local kept = {}
		for _, monster in snapshot.farmMonsters do
			if not consumed[monster.uid] then table.insert(kept, monster) end
		end
		snapshot.farmMonsters = kept
	end
	snapshot.farmMonsters = snapshot.farmMonsters or {}
	for _, monster in snapshot.farmMonsters do if monster.uid == grant.monster.uid then return end end
	table.insert(snapshot.farmMonsters, table.clone(grant.monster))
	snapshot.collectedMonsters = snapshot.collectedMonsters or {}
	if not table.find(snapshot.collectedMonsters, grant.monster.monsterId) then table.insert(snapshot.collectedMonsters, grant.monster.monsterId) end
	snapshot.farmReceipts = snapshot.farmReceipts or {}
	table.insert(snapshot.farmReceipts, { id = grant.operation, signature = grant.signature, monster = table.clone(grant.monster) })
	while #snapshot.farmReceipts > Config.RECEIPT_LIMIT do table.remove(snapshot.farmReceipts, 1) end
end

return Fusion
