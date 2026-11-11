--!strict
return function(Farm: any, Config: any, Levels: any): string
	assert(Farm.rate("Goblin") > Farm.rate("Zombie"))
	assert(Farm.rate("GoblinElite") > Farm.rate("Goblin"))
	assert(Farm.rate("PharaohMummy") > Farm.rate("GoblinElite"))
	assert(Farm.stars(1, 5, 0, 200) == 3)
	assert(Farm.stars(1, 3, 1, 200) == 2)
	assert(Farm.stars(1, 2, 3, 200) == 1)
	assert(Farm.stars(2, 5, 0, Farm.parTime(2) + 1) == 2)
	assert(Farm.stars(2, 5, 0, Farm.parTime(2)) == 3)
	assert(Farm.stars(4, 3, 1, Farm.parTime(4)) == 3)
	assert(Farm.stars(4, 1, 1, 50) == 3)
	assert(Farm.stars(1, 2, 0, 200) == 3, "inherited heart loss blocked a perfect attempt")
	local invalid = Farm.sanitizeMap({ Zombie = 0/0, Goblin = math.huge, Bad = 100, Vampire = 2.9 })
	assert(invalid.Zombie == nil and invalid.Goblin == nil and invalid.Bad == nil and invalid.Vampire == 2)
	assert(Farm.sanitizeMap({ Level1 = 99, Bad = 3 }, true).Level1 == 3)
	local rng = Random.new(742)
	for day = 1, Levels.count() do
		assert(Farm.brains(day, 1) < Farm.brains(day, 2) and Farm.brains(day, 2) < Farm.brains(day, 3))
		local pool = Farm.pool(day)
		assert(#pool > 0 and #Farm.goals(day) == 2 and Farm.parTime(day) > 0)
		for stars = 1, 3 do
			local shards = Farm.rewards(day, stars, rng)
			local count = 0
			for id, amount in shards do assert(table.find(pool, id)); count += amount end
			assert(count == Config.STAR_SHARD_ROLLS[stars])
		end
	end
	local daytime, desert = Farm.pool(1), Farm.pool(50)
	assert(table.find(daytime, "Zombie") and not table.find(daytime, "PharaohMummy"))
	assert(table.find(desert, "PharaohMummy") and not table.find(desert, "Zombie"))
	local snapshot = { monsterShards = { Zombie = 15 }, collectedMonsters = {} }
	local reward, _, grant = Farm.combine(snapshot, "Zombie")
	assert(reward == 0 and grant.shardCost == 15 and snapshot.monsterShards.Zombie == 15)
	snapshot.monsterShards.Zombie = 14
	assert(select(2, Farm.combine(snapshot, "Zombie")) == "NotReady")
	return "Farm rates, varied stars, all 50 regional rewards, sanitization and combine validation passed"
end
