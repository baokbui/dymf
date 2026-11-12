--!strict
-- Pure selection rules shared by the server and display-only inventory state.
local Fusion = require(script.Parent.MonsterFusion)
local Residents = {}

function Residents.selected(monsters: { Fusion.Monster }, capacity: number): { Fusion.Monster }
	local selected = {}
	for _, monster in monsters do
		if monster.onFarm == true and #selected < capacity then table.insert(selected, monster) end
	end
	-- Older saves have no selection. Preserve their newest residents until edited.
	local legacy = {}
	for index = #monsters, 1, -1 do
		local monster = monsters[index]
		if monster.onFarm == nil and #selected + #legacy < capacity then table.insert(legacy, 1, monster) end
	end
	for _, monster in legacy do table.insert(selected, monster) end
	return selected
end

function Residents.toggle(monsters: { Fusion.Monster }, capacity: number, uid: string, equipped: boolean): ({ Fusion.Monster }?, string?)
	local owned = false
	for _, monster in monsters do if monster.uid == uid then owned = true; break end end
	if not owned then return nil, "NotOwned" end
	local selected = Residents.selected(monsters, capacity)
	local active = {}
	for _, monster in selected do active[monster.uid] = true end
	if equipped and not active[uid] and #selected >= capacity then return nil, "FarmFull" end
	active[uid] = equipped
	local result = {}
	for _, monster in monsters do
		local copy = table.clone(monster)
		copy.onFarm = active[monster.uid] == true
		table.insert(result, copy)
	end
	return result, nil
end

return Residents
