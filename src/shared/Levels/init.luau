--!strict
--[[
	Levels Registry
	Central, data-driven catalog of authored campaign levels (PvZ-style).

	Each level is a fixed, hand-authored sequence of monster spawn groups
	(internal "waves") that ends in a big final wave. LevelService plays levels
	in `number` order; clearing one unlocks the next. Add a level by adding one
	data entry here — never branch on level numbers in code.

	Seeded with the opening campaign levels using the Milestone 6 starter monster
	(BasicMonster). More monsters/levels are added here as plain data; richer
	rosters arrive with Milestone 10.
]]

local Types = require(script.Parent.Types)

local Levels = {}

local definitions: { [string]: Types.LevelDefinition } = {
	Level1 = {
		id = "Level1",
		number = 1,
		name = "First Contact",
		groups = {
			{ monsterId = "BasicMonster", count = 3, startDelay = 0, spawnInterval = 2 },
			{ monsterId = "BasicMonster", count = 5, startDelay = 8, spawnInterval = 1.5 },
			{ monsterId = "BasicMonster", count = 8, startDelay = 10, spawnInterval = 1, isBigWave = true },
		},
	},

	Level2 = {
		id = "Level2",
		number = 2,
		name = "Rising Tide",
		groups = {
			{ monsterId = "BasicMonster", count = 5, startDelay = 0, spawnInterval = 1.5 },
			{ monsterId = "BasicMonster", count = 7, startDelay = 8, spawnInterval = 1.2 },
			{ monsterId = "BasicMonster", count = 6, startDelay = 8, spawnInterval = 1 },
			{ monsterId = "BasicMonster", count = 12, startDelay = 12, spawnInterval = 0.8, isBigWave = true },
		},
	},
}

-- Campaign order cached once (sorted by `number`); shared read-only.
local ordered: { Types.LevelDefinition } = {}
for _, definition in definitions do
	table.insert(ordered, definition)
end
table.sort(ordered, function(a, b)
	return a.number < b.number
end)

-- Returns the definition for a level id, or nil if unknown.
function Levels.get(id: string): Types.LevelDefinition?
	return definitions[id]
end

-- Returns true if a level id exists in the registry.
function Levels.exists(id: string): boolean
	return definitions[id] ~= nil
end

-- Returns the full definition table (read-only intent; do not mutate).
function Levels.getAll(): { [string]: Types.LevelDefinition }
	return definitions
end

-- Levels in campaign order (by `number`); read-only.
function Levels.getOrdered(): { Types.LevelDefinition }
	return ordered
end

-- The level at a given 1-based campaign number, or nil past the last level.
function Levels.getByNumber(number: number): Types.LevelDefinition?
	for _, definition in ordered do
		if definition.number == number then
			return definition
		end
	end
	return nil
end

-- Total number of authored levels in the campaign.
function Levels.count(): number
	return #ordered
end

return Levels
