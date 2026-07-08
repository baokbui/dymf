--!strict
--[[
	Levels Registry
	Central, data-driven catalog of authored campaign levels (PvZ-style).

	Each level is a fixed, hand-authored sequence of monster spawn groups
	(internal "waves") that ends in a big final wave. LevelService plays levels
	in `number` order; clearing one unlocks the next. Add a level by adding one
	data entry here — never branch on level numbers in code.

	Campaign introduction cadence (authored in data):
		- Levels 1–4: standard Zombie only (same hp profile across levels).
		- Every 5 levels: introduce exactly one new non-boss monster (Level 5 = Goblin).
		- Every 10 levels: introduce one boss as the big final wave (Level 10 = Orc).
		- Repeat for Level 15 / 20, etc. when those levels are authored.

	Adjacent levels ramp slowly — sometimes the same pressure as the level before.
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
			{ monsterId = "Zombie", count = 1, startDelay = 25, spawnInterval = 6 },
			{ monsterId = "Zombie", count = 2, startDelay = 30, spawnInterval = 5 },
			{ monsterId = "Zombie", count = 2, startDelay = 25, spawnInterval = 4, isBigWave = true },
		},
	},

	Level2 = {
		id = "Level2",
		number = 2,
		name = "Rising Tide",
		groups = {
			-- Same monster profile as Level 1, slightly tighter pacing.
			{ monsterId = "Zombie", count = 2, startDelay = 20, spawnInterval = 5.5 },
			{ monsterId = "Zombie", count = 2, startDelay = 28, spawnInterval = 4.5 },
			{ monsterId = "Zombie", count = 2, startDelay = 25, spawnInterval = 4, isBigWave = true },
		},
	},

	Level3 = {
		id = "Level3",
		number = 3,
		name = "Greenhorns",
		groups = {
			-- Same Zombie profile as previous levels; small count bump only.
			{ monsterId = "Zombie", count = 2, startDelay = 18, spawnInterval = 4.5 },
			{ monsterId = "Zombie", count = 3, startDelay = 22, spawnInterval = 4 },
			{ monsterId = "Zombie", count = 3, startDelay = 25, spawnInterval = 2.5, isBigWave = true },
		},
	},

	Level4 = {
		id = "Level4",
		number = 4,
		name = "Pressing Forward",
		groups = {
			-- Same total pressure as Level 3; more standard Zombies in the mix.
			{ monsterId = "Zombie", count = 2, startDelay = 18, spawnInterval = 4.5 },
			{ monsterId = "Zombie", count = 3, startDelay = 22, spawnInterval = 4 },
			{ monsterId = "Zombie", count = 3, startDelay = 24, spawnInterval = 2.5, isBigWave = true },
		},
	},

	-- Level 5: first new roster monster (Goblin only — faster grunt, same HP as Zombie).
	Level5 = {
		id = "Level5",
		number = 5,
		name = "Goblin Scout",
		groups = {
			{ monsterId = "Zombie", count = 3, startDelay = 16, spawnInterval = 4 },
			{ monsterId = "Goblin", count = 1, startDelay = 22, spawnInterval = 5 },
			{ monsterId = "Zombie", count = 2, startDelay = 20, spawnInterval = 3.5 },
			{ monsterId = "Goblin", count = 2, startDelay = 22, spawnInterval = 3.5, isBigWave = true },
		},
	},

	Level6 = {
		id = "Level6",
		number = 6,
		name = "Quick Feet",
		groups = {
			{ monsterId = "Zombie", count = 3, startDelay = 15, spawnInterval = 3.8 },
			{ monsterId = "Goblin", count = 2, startDelay = 18, spawnInterval = 3.5 },
			{ monsterId = "Zombie", count = 2, startDelay = 18, spawnInterval = 3.2 },
			{ monsterId = "Goblin", count = 3, startDelay = 20, spawnInterval = 3, isBigWave = true },
		},
	},

	Level7 = {
		id = "Level7",
		number = 7,
		name = "Crooked Charge",
		groups = {
			-- Small step up from Level 6.
			{ monsterId = "Goblin", count = 3, startDelay = 14, spawnInterval = 3.5 },
			{ monsterId = "Zombie", count = 3, startDelay = 16, spawnInterval = 3.5 },
			{ monsterId = "Goblin", count = 2, startDelay = 18, spawnInterval = 3.2 },
			{ monsterId = "Zombie", count = 2, startDelay = 18, spawnInterval = 3, isBigWave = true },
		},
	},

	Level8 = {
		id = "Level8",
		number = 8,
		name = "Hold the Line",
		groups = {
			-- Plateau: same enemy counts as Level 7, slightly tighter pacing.
			{ monsterId = "Zombie", count = 3, startDelay = 14, spawnInterval = 3.5 },
			{ monsterId = "Goblin", count = 3, startDelay = 15, spawnInterval = 3.2 },
			{ monsterId = "Zombie", count = 2, startDelay = 16, spawnInterval = 3.2 },
			{ monsterId = "Goblin", count = 3, startDelay = 17, spawnInterval = 3, isBigWave = true },
		},
	},

	Level9 = {
		id = "Level9",
		number = 9,
		name = "Before the Banner",
		groups = {
			-- Gentle ramp into the boss level.
			{ monsterId = "Goblin", count = 4, startDelay = 13, spawnInterval = 3.2 },
			{ monsterId = "Zombie", count = 3, startDelay = 14, spawnInterval = 3.2 },
			{ monsterId = "Goblin", count = 3, startDelay = 15, spawnInterval = 3 },
			{ monsterId = "Zombie", count = 3, startDelay = 16, spawnInterval = 2.8, isBigWave = true },
		},
	},

	-- Level 10: first boss (Orc — heavy melee counterpart to the Goblin line).
	Level10 = {
		id = "Level10",
		number = 10,
		name = "Orc Warlord",
		groups = {
			{ monsterId = "Zombie", count = 4, startDelay = 12, spawnInterval = 3.2 },
			{ monsterId = "Goblin", count = 4, startDelay = 14, spawnInterval = 3 },
			{ monsterId = "Zombie", count = 3, startDelay = 15, spawnInterval = 2.8 },
			{ monsterId = "Orc", count = 1, startDelay = 18, spawnInterval = 2, isBigWave = true },
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
