--!strict
return function(Fusion: any, Farm: any, Config: any): string
	local legacy = Fusion.sanitize(nil, { "Zombie", "Zombie", "Goblin" })
	assert(#legacy == 2 and legacy[1].uid == "legacy:Zombie" and legacy[1].tier == "Medium")
	assert(#Fusion.sanitize({}, { "Zombie" }) == 0, "empty inventories were backfilled")
	local previousScale, previousIncome, previousLevel = 0, 0, 0
	for _, tier in Config.TIERS do
		assert(tier.scale > previousScale and tier.income > previousIncome and tier.level > previousLevel)
		previousScale, previousIncome, previousLevel = tier.scale, tier.income, tier.level
	end
	local function largeChance(weights)
		local total, large = 0, 0
		for index, weight in weights do total += weight; if index >= 4 then large += weight end end
		assert(math.abs(total - 100) < 0.001)
		return large / total
	end
	local chance = largeChance(Config.COMBINE_WEIGHTS)
	for count = 3, 5 do
		local boosted = largeChance(Config.FUSION_WEIGHTS[count])
		assert(boosted > chance and boosted < 1)
		chance = boosted
	end
	local monsters = {}
	for i = 1, 5 do table.insert(monsters, { uid = "z" .. i, monsterId = "Zombie", tier = "Small" }) end
	assert(Fusion.ingredients(monsters, { "z1", "z2", "z3" }) == "Zombie")
	assert(Fusion.ingredients(monsters, { "z1", "z2" }) == nil)
	assert(Fusion.ingredients(monsters, { "z1", "z1", "z3" }) == nil)
	assert(Fusion.ingredients(monsters, { "z1", "z2", "foreign" }) == nil)
	monsters[5].monsterId = "Goblin"
	assert(Fusion.ingredients(monsters, { "z1", "z2", "z5" }) == nil)
	local snapshot = { monsterShards = { Zombie = 100 }, collectedMonsters = {}, farmMonsters = {}, farmReceipts = {} }
	local rng = Random.new(771)
	for i = 1, 3 do
		local _, _, grant = Farm.combine(snapshot, "Zombie", rng, "new-" .. i, "combine-" .. i)
		Fusion.apply(snapshot, grant)
		Fusion.apply(snapshot, grant)
	end
	assert(#snapshot.farmMonsters == 3 and snapshot.monsterShards.Zombie == 55)
	local ids = { "new-1", "new-2", "new-3" }
	local _, _, grant = Farm.fuse(snapshot, ids, rng, "fused-1", "fuse-once")
	Fusion.apply(snapshot, grant)
	assert(#snapshot.farmMonsters == 1 and snapshot.farmMonsters[1].uid == "fused-1")
	local reward, _, receipt = Farm.fuse(snapshot, ids, rng, "fused-2", "fuse-once")
	assert(reward == 0 and receipt.kind == "FarmReceipt")
	Fusion.apply(snapshot, receipt)
	assert(#snapshot.farmMonsters == 1)
	assert(select(2, Farm.combine(snapshot, "Goblin", rng, "bad", "fuse-once")) == "InvalidRequest", "operation id was reused for another recipe")
	local tiny = { uid = "t", monsterId = "Zombie", tier = "Tiny" }
	local titanic = { uid = "h", monsterId = "Zombie", tier = "Titanic" }
	assert(Farm.monsterRate(tiny) < Farm.monsterRate(titanic))
	return "Six tiers, migration, recipe validation, weighted odds, duplicate ownership, atomic grants and retry receipts passed"
end
