--!strict
--[[
	Zombies Registry
	Central, data-driven catalog of every Zombie definition.

	All zombies derive from one base implementation; special zombies are just
	different data entries plus optional abilities. Avoid duplicated AI.

	Seeded with the Milestone 6 starter (Basic). Additional zombie types
	(Fast, Tank, Shield, Flying, Carrier, Boss) are added here as data.
]]

local Types = require(script.Parent.Types)

local Zombies = {}

local definitions: { [string]: Types.ZombieDefinition } = {
	Basic = {
		id = "Basic",
		name = "Basic Zombie",
		health = 100,
		speed = 6,
		damage = 10,
		attackSpeed = 1,
		abilities = nil,
	},
}

-- Returns the definition for a Zombie id, or nil if unknown.
function Zombies.get(id: string): Types.ZombieDefinition?
	return definitions[id]
end

-- Returns true if a Zombie id exists in the registry.
function Zombies.exists(id: string): boolean
	return definitions[id] ~= nil
end

-- Returns the full definition table (read-only intent; do not mutate).
function Zombies.getAll(): { [string]: Types.ZombieDefinition }
	return definitions
end

return Zombies
