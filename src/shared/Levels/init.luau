--!strict
--[[
	Levels Registry
	Central, data-driven catalog of authored campaign levels (PvZ-style).

	Difficulty ramps via spawn counts, pacing (startDelay / spawnInterval), and
	monster species — not duplicate stat tiers of the same enemy.
]]

local Types = require(script.Parent.Types)

local Levels = {}

local definitions: { [string]: Types.LevelDefinition } = {
	Level1 = {
		id = "Level1",
		number = 1,
		name = "First Contact",
		groups = {
			{ monsterId = "Zombie", count = 1, startDelay = 26, spawnInterval = 7 },
			{ monsterId = "Zombie", count = 2, startDelay = 32, spawnInterval = 6 },
			{ monsterId = "Zombie", count = 2, startDelay = 28, spawnInterval = 5, isBigWave = true },
		},
	},

	Level2 = {
		id = "Level2",
		number = 2,
		name = "Rising Tide",
		groups = {
			{ monsterId = "Zombie", count = 2, startDelay = 22, spawnInterval = 6 },
			{ monsterId = "Zombie", count = 2, startDelay = 30, spawnInterval = 5.5 },
			{ monsterId = "Zombie", count = 2, startDelay = 26, spawnInterval = 4.5, isBigWave = true },
		},
	},

	Level3 = {
		id = "Level3",
		number = 3,
		name = "Greenhorns",
		groups = {
			{ monsterId = "Zombie", count = 2, startDelay = 20, spawnInterval = 5.5 },
			{ monsterId = "Zombie", count = 3, startDelay = 24, spawnInterval = 4.5 },
			{ monsterId = "Zombie", count = 3, startDelay = 26, spawnInterval = 3.5, isBigWave = true },
		},
	},

	Level4 = {
		id = "Level4",
		number = 4,
		name = "Pressing Forward",
		groups = {
			{ monsterId = "Zombie", count = 2, startDelay = 19, spawnInterval = 5 },
			{ monsterId = "Zombie", count = 3, startDelay = 23, spawnInterval = 4.2 },
			{ monsterId = "Zombie", count = 3, startDelay = 25, spawnInterval = 3.2, isBigWave = true },
		},
	},

	Level5 = {
		id = "Level5",
		number = 5,
		name = "Goblin Scout",
		groups = {
			{ monsterId = "Zombie", count = 3, startDelay = 18, spawnInterval = 4.5 },
			{ monsterId = "Goblin", count = 1, startDelay = 24, spawnInterval = 5.5 },
			{ monsterId = "Zombie", count = 2, startDelay = 22, spawnInterval = 4 },
			{ monsterId = "Goblin", count = 2, startDelay = 24, spawnInterval = 3.8, isBigWave = true },
		},
	},

	Level6 = {
		id = "Level6",
		number = 6,
		name = "Quick Feet",
		groups = {
			{ monsterId = "Zombie", count = 3, startDelay = 16, spawnInterval = 4.2 },
			{ monsterId = "Goblin", count = 2, startDelay = 20, spawnInterval = 3.8 },
			{ monsterId = "Zombie", count = 2, startDelay = 20, spawnInterval = 3.5 },
			{ monsterId = "Goblin", count = 3, startDelay = 22, spawnInterval = 3.2, isBigWave = true },
		},
	},

	Level7 = {
		id = "Level7",
		number = 7,
		name = "Crooked Charge",
		groups = {
			{ monsterId = "Goblin", count = 3, startDelay = 15, spawnInterval = 3.8 },
			{ monsterId = "Zombie", count = 3, startDelay = 17, spawnInterval = 3.8 },
			{ monsterId = "Goblin", count = 2, startDelay = 19, spawnInterval = 3.5 },
			{ monsterId = "Zombie", count = 2, startDelay = 19, spawnInterval = 3.2, isBigWave = true },
		},
	},

	Level8 = {
		id = "Level8",
		number = 8,
		name = "Hold the Line",
		groups = {
			{ monsterId = "Zombie", count = 3, startDelay = 15, spawnInterval = 3.8 },
			{ monsterId = "Goblin", count = 3, startDelay = 16, spawnInterval = 3.5 },
			{ monsterId = "Zombie", count = 2, startDelay = 17, spawnInterval = 3.5 },
			{ monsterId = "Goblin", count = 3, startDelay = 18, spawnInterval = 3.2, isBigWave = true },
		},
	},

	Level9 = {
		id = "Level9",
		number = 9,
		name = "Before the Banner",
		groups = {
			{ monsterId = "Goblin", count = 4, startDelay = 14, spawnInterval = 3.5 },
			{ monsterId = "Zombie", count = 3, startDelay = 15, spawnInterval = 3.5 },
			{ monsterId = "Goblin", count = 3, startDelay = 16, spawnInterval = 3.2 },
			{ monsterId = "Zombie", count = 3, startDelay = 17, spawnInterval = 3, isBigWave = true },
		},
	},

	Level10 = {
		id = "Level10",
		number = 10,
		name = "Orc Warlord",
		groups = {
			{ monsterId = "Zombie", count = 4, startDelay = 13, spawnInterval = 3.5 },
			{ monsterId = "Goblin", count = 4, startDelay = 15, spawnInterval = 3.2 },
			{ monsterId = "Zombie", count = 3, startDelay = 16, spawnInterval = 3 },
			{ monsterId = "Orc", count = 1, startDelay = 22, spawnInterval = 2, isBigWave = true },
		},
	},
}

local ordered: { Types.LevelDefinition } = {}
for _, definition in definitions do
	table.insert(ordered, definition)
end
table.sort(ordered, function(a, b)
	return a.number < b.number
end)

function Levels.get(id: string): Types.LevelDefinition?
	return definitions[id]
end

function Levels.exists(id: string): boolean
	return definitions[id] ~= nil
end

function Levels.getAll(): { [string]: Types.LevelDefinition }
	return definitions
end

function Levels.getOrdered(): { Types.LevelDefinition }
	return ordered
end

function Levels.getByNumber(number: number): Types.LevelDefinition?
	for _, definition in ordered do
		if definition.number == number then
			return definition
		end
	end
	return nil
end

function Levels.count(): number
	return #ordered
end

return Levels
