--!strict
--[[
	Monsters Registry
	Central, data-driven catalog of every Monster definition.

	All monsters derive from one base implementation; special monster types
	(zombies, vampires, slimes, frankensteins, bosses, ...) are just different
	data entries plus optional abilities. Avoid duplicated AI.

	Seeded with the Milestone 6 starter (Basic Monster). Additional monster types
	(Fast, Tank, Shield, Flying, Carrier, Boss, themed monsters) are added here as
	data.
]]

local Types = require(script.Parent.Types)

local Monsters = {}

local definitions: { [string]: Types.MonsterDefinition } = {
	BasicMonster = {
		id = "BasicMonster",
		name = "Basic Monster",
		health = 100,
		speed = 6,
		damage = 10,
		attackSpeed = 1,
		abilities = nil,
	},
}

-- Returns the definition for a Monster id, or nil if unknown.
function Monsters.get(id: string): Types.MonsterDefinition?
	return definitions[id]
end

-- Returns true if a Monster id exists in the registry.
function Monsters.exists(id: string): boolean
	return definitions[id] ~= nil
end

-- Returns the full definition table (read-only intent; do not mutate).
function Monsters.getAll(): { [string]: Types.MonsterDefinition }
	return definitions
end

return Monsters
