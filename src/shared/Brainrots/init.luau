--!strict
--[[
	Brainrots Registry
	Central, data-driven catalog of every Brainrot definition.

	Brainrot behavior is resolved from this data at runtime. Never branch on
	specific Brainrot names with if/elseif chains; read the definition instead.

	Seeded with the two Milestone 5 starters (Shooter, Money Generator).
	Additional Brainrots are added here as plain data entries.
]]

local Types = require(script.Parent.Types)

local Brainrots = {}

local definitions: { [string]: Types.BrainrotDefinition } = {
	Shooter = {
		id = "Shooter",
		name = "Shooter",
		cost = 50,
		health = 100,
		damage = 10,
		attackSpeed = 1,
		range = 24,
		ability = nil,
	},

	MoneyGenerator = {
		id = "MoneyGenerator",
		name = "Money Generator",
		cost = 75,
		health = 80,
		damage = 0,
		attackSpeed = 0,
		range = 0,
		ability = "GenerateCoins",
		coinGeneration = 25,
	},
}

-- Returns the definition for a Brainrot id, or nil if unknown.
function Brainrots.get(id: string): Types.BrainrotDefinition?
	return definitions[id]
end

-- Returns true if a Brainrot id exists in the registry.
function Brainrots.exists(id: string): boolean
	return definitions[id] ~= nil
end

-- Returns the full definition table (read-only intent; do not mutate).
function Brainrots.getAll(): { [string]: Types.BrainrotDefinition }
	return definitions
end

return Brainrots
