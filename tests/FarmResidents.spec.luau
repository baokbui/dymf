--!strict
return function(Fusion: any, Residents: any): string
	local monsters = {}
	for index = 1, 7 do table.insert(monsters, { uid = tostring(index), monsterId = "Zombie", tier = "Medium" }) end
	local legacy = Residents.selected(monsters, 5)
	assert(#legacy == 5 and legacy[1].uid == "3" and legacy[5].uid == "7", "Legacy residents changed")
	local removed = assert(Residents.toggle(monsters, 5, "4", false))
	assert(#Residents.selected(removed, 5) == 4, "Removing refilled a slot automatically")
	local placed = assert(Residents.toggle(removed, 5, "1", true))
	assert(#Residents.selected(placed, 5) == 5)
	local invalid, reason = Residents.toggle(placed, 5, "2", true)
	assert(invalid == nil and reason == "FarmFull", "Capacity bypassed")
	invalid, reason = Residents.toggle(placed, 10, "someone-elses-pet", true)
	assert(invalid == nil and reason == "NotOwned", "Ownership bypassed")
	local rejoined = Fusion.sanitize(placed)
	assert(#Residents.selected(rejoined, 5) == 5 and rejoined[4].onFarm == false and rejoined[1].onFarm == true,
		"Save hydration lost equipment")
	for _, monster in table.clone(rejoined) do rejoined = assert(Residents.toggle(rejoined, 5, monster.uid, false)) end
	assert(#Residents.selected(rejoined, 5) == 0, "Unable to empty the farm")
	local rolled = Fusion.roll("Zombie", { 1, 0, 0, 0, 0, 0 }, Random.new(1), "new")
	assert(rolled.onFarm == false, "New output automatically displaced a resident")
	local snapshot = { farmMonsters = placed, farmReceipts = {}, collectedMonsters = { "Zombie" } }
	Fusion.apply(snapshot, { kind = "FarmFusion", consumed = { "1", "3", "5" }, monster = rolled, operation = "test", signature = "Fusion:test" })
	local after = Residents.selected(snapshot.farmMonsters, 5)
	assert(#after == 2, "Fusion retained consumed residents or auto-equipped its output")
	return "Legacy selection, equip/remove, capacity, ownership, rejoin and fusion selection passed"
end
