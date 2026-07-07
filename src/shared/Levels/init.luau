--!strict
--[[
	Levels Registry
	Central, data-driven catalog of authored campaign levels (PvZ-style).

	Each level is a fixed, hand-authored sequence of monster spawn groups
	(internal "waves") that ends in a big final wave. LevelService plays levels
	in `number` order; clearing one unlocks the next. Add a level by adding one
	data entry here — never branch on level numbers in code.

	Seeded with a gradual opening campaign: TutorialZombie (Level 1) → mixed
	TutorialZombie / EarlyZombie (Level 2) → EarlyZombie with a small full-Zombie
	finale (Level 3). Tune each level as data here — never branch on level numbers.
]]

local Types = require(script.Parent.Types)

local Levels = {}

local definitions: { [string]: Types.LevelDefinition } = {
	Level1 = {
		id = "Level1",
		number = 1,
		name = "First Contact",
		groups = {
			-- Long grace + one slow enemy at a time so the player can plant and learn.
			{ monsterId = "TutorialZombie", count = 1, startDelay = 25, spawnInterval = 6 },
			{ monsterId = "TutorialZombie", count = 2, startDelay = 30, spawnInterval = 5 },
			{ monsterId = "TutorialZombie", count = 2, startDelay = 25, spawnInterval = 4, isBigWave = true },
		},
	},

	Level2 = {
		id = "Level2",
		number = 2,
		name = "Rising Tide",
		groups = {
			-- Same enemy type as Level 1, slightly more pressure — no full Zombie yet.
			{ monsterId = "TutorialZombie", count = 2, startDelay = 20, spawnInterval = 5.5 },
			{ monsterId = "TutorialZombie", count = 2, startDelay = 28, spawnInterval = 4.5 },
			{ monsterId = "EarlyZombie", count = 2, startDelay = 25, spawnInterval = 4, isBigWave = true },
		},
	},

	Level3 = {
		id = "Level3",
		number = 3,
		name = "Greenhorns",
		groups = {
			-- EarlyZombie carries most of the level; a short full-Zombie big wave at the end.
			{ monsterId = "EarlyZombie", count = 2, startDelay = 18, spawnInterval = 4.5 },
			{ monsterId = "EarlyZombie", count = 3, startDelay = 22, spawnInterval = 4 },
			{ monsterId = "Zombie", count = 3, startDelay = 25, spawnInterval = 2.5, isBigWave = true },
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
