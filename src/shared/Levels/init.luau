--!strict
--[[
	Levels Registry
	Central, data-driven catalog of authored campaign levels (PvZ-style).

	Difficulty ramps via spawn counts, pacing (startDelay / spawnInterval), and
	monster species — not duplicate stat tiers of the same enemy.
	First-group startDelay is short; plant time is the forest march
	(MonsterConfig.SPAWN_COLUMN_OFFSET).

	Days assume lawn carry-over after victory (plants stay, coins reset). Day 1
	is empty-board gentle; later days are authored against a growing defense.
]]

local Types = require(script.Parent.Types)

local Levels = {}

local definitions: { [string]: Types.LevelDefinition } = {
	Level1 = {
		id = "Level1",
		number = 1,
		name = "First Contact",
		groups = {
			-- Empty lawn: keep gentle. Plant time = forest march.
			{ monsterId = "Zombie", count = 1, startDelay = 1.5, spawnInterval = 7 },
			{ monsterId = "Zombie", count = 2, startDelay = 32, spawnInterval = 6 },
			{ monsterId = "Zombie", count = 2, startDelay = 28, spawnInterval = 5, isBigWave = true },
		},
	},

	Level2 = {
		id = "Level2",
		number = 2,
		name = "Rising Tide",
		groups = {
			-- Carry-over board expected; bump count vs old Day 2.
			{ monsterId = "Zombie", count = 2, startDelay = 1.5, spawnInterval = 5.5 },
			{ monsterId = "Zombie", count = 3, startDelay = 26, spawnInterval = 4.8 },
			{ monsterId = "Zombie", count = 3, startDelay = 24, spawnInterval = 4, isBigWave = true },
		},
	},

	Level3 = {
		id = "Level3",
		number = 3,
		name = "Greenhorns",
		groups = {
			{ monsterId = "Zombie", count = 3, startDelay = 1.5, spawnInterval = 5 },
			{ monsterId = "Zombie", count = 3, startDelay = 22, spawnInterval = 4 },
			{ monsterId = "Zombie", count = 4, startDelay = 22, spawnInterval = 3.2, isBigWave = true },
		},
	},

	Level4 = {
		id = "Level4",
		number = 4,
		name = "Pressing Forward",
		groups = {
			{ monsterId = "Zombie", count = 3, startDelay = 1.5, spawnInterval = 4.5 },
			{ monsterId = "Zombie", count = 4, startDelay = 20, spawnInterval = 3.6 },
			{ monsterId = "Zombie", count = 5, startDelay = 20, spawnInterval = 2.8, isBigWave = true },
		},
	},

	Level5 = {
		id = "Level5",
		number = 5,
		name = "Goblin Scout",
		groups = {
			{ monsterId = "Zombie", count = 4, startDelay = 1.5, spawnInterval = 4 },
			{ monsterId = "Goblin", count = 2, startDelay = 18, spawnInterval = 4 },
			{ monsterId = "Zombie", count = 3, startDelay = 18, spawnInterval = 3.5 },
			{ monsterId = "Goblin", count = 3, startDelay = 18, spawnInterval = 3.2, isBigWave = true },
		},
	},

	Level6 = {
		id = "Level6",
		number = 6,
		name = "Quick Feet",
		groups = {
			{ monsterId = "Zombie", count = 4, startDelay = 1.5, spawnInterval = 3.8 },
			{ monsterId = "Goblin", count = 3, startDelay = 16, spawnInterval = 3.4 },
			{ monsterId = "Zombie", count = 3, startDelay = 16, spawnInterval = 3.2 },
			{ monsterId = "Goblin", count = 4, startDelay = 16, spawnInterval = 2.8, isBigWave = true },
		},
	},

	Level7 = {
		id = "Level7",
		number = 7,
		name = "Crooked Charge",
		groups = {
			{ monsterId = "Goblin", count = 4, startDelay = 1.5, spawnInterval = 3.4 },
			{ monsterId = "Zombie", count = 4, startDelay = 14, spawnInterval = 3.4 },
			{ monsterId = "Goblin", count = 3, startDelay = 15, spawnInterval = 3 },
			{ monsterId = "Zombie", count = 3, startDelay = 15, spawnInterval = 2.8, isBigWave = true },
		},
	},

	Level8 = {
		id = "Level8",
		number = 8,
		name = "Hold the Line",
		groups = {
			{ monsterId = "Zombie", count = 4, startDelay = 1.5, spawnInterval = 3.4 },
			{ monsterId = "Goblin", count = 4, startDelay = 13, spawnInterval = 3 },
			{ monsterId = "Zombie", count = 3, startDelay = 14, spawnInterval = 3 },
			{ monsterId = "Goblin", count = 5, startDelay = 14, spawnInterval = 2.6, isBigWave = true },
		},
	},

	Level9 = {
		id = "Level9",
		number = 9,
		name = "Before the Banner",
		groups = {
			{ monsterId = "Goblin", count = 5, startDelay = 1.5, spawnInterval = 3 },
			{ monsterId = "Zombie", count = 4, startDelay = 12, spawnInterval = 3 },
			{ monsterId = "Goblin", count = 4, startDelay = 13, spawnInterval = 2.8 },
			{ monsterId = "Zombie", count = 5, startDelay = 13, spawnInterval = 2.5, isBigWave = true },
		},
	},

	Level10 = {
		id = "Level10",
		number = 10,
		name = "Goblin Elite",
		groups = {
			{ monsterId = "Zombie", count = 5, startDelay = 1.5, spawnInterval = 3 },
			{ monsterId = "Goblin", count = 5, startDelay = 12, spawnInterval = 2.8 },
			{ monsterId = "Zombie", count = 4, startDelay = 13, spawnInterval = 2.6 },
			{ monsterId = "GoblinElite", count = 1, startDelay = 18, spawnInterval = 2, isBigWave = true },
		},
	},

	-- Levels 11-14: no new species yet — count/pacing keep ramping on the
	-- Zombie + Goblin mix the player already knows, easing back up after the
	-- Level 10 boss dip before Goblin Elites start recurring.
	Level11 = {
		id = "Level11",
		number = 11,
		name = "Advancing Ranks",
		groups = {
			{ monsterId = "Zombie", count = 5, startDelay = 1.5, spawnInterval = 2.8 },
			{ monsterId = "Goblin", count = 5, startDelay = 11, spawnInterval = 2.6 },
			{ monsterId = "Zombie", count = 4, startDelay = 12, spawnInterval = 2.4 },
			{ monsterId = "Goblin", count = 5, startDelay = 12, spawnInterval = 2.2, isBigWave = true },
		},
	},

	Level12 = {
		id = "Level12",
		number = 12,
		name = "Iron Ranks",
		groups = {
			{ monsterId = "Goblin", count = 5, startDelay = 1.5, spawnInterval = 2.6 },
			{ monsterId = "Zombie", count = 5, startDelay = 10, spawnInterval = 2.4 },
			{ monsterId = "Goblin", count = 5, startDelay = 11, spawnInterval = 2.2 },
			{ monsterId = "Zombie", count = 6, startDelay = 11, spawnInterval = 2.0, isBigWave = true },
		},
	},

	-- Goblin Elite starts recurring as a mixed-in miniboss (not always the
	-- finale) so it stays a recognizable threat rather than a one-off boss.
	Level13 = {
		id = "Level13",
		number = 13,
		name = "Elite Vanguard",
		groups = {
			{ monsterId = "Zombie", count = 5, startDelay = 1.5, spawnInterval = 2.6 },
			{ monsterId = "Goblin", count = 5, startDelay = 10, spawnInterval = 2.4 },
			{ monsterId = "Zombie", count = 4, startDelay = 11, spawnInterval = 2.2 },
			{ monsterId = "GoblinElite", count = 1, startDelay = 14, spawnInterval = 2, isBigWave = true },
		},
	},

	Level14 = {
		id = "Level14",
		number = 14,
		name = "Elite Pressure",
		groups = {
			{ monsterId = "Zombie", count = 5, startDelay = 1.5, spawnInterval = 2.4 },
			{ monsterId = "GoblinElite", count = 1, startDelay = 10, spawnInterval = 2 },
			{ monsterId = "Goblin", count = 6, startDelay = 14, spawnInterval = 2.2 },
			{ monsterId = "Zombie", count = 5, startDelay = 11, spawnInterval = 2.0, isBigWave = true },
		},
	},

	-- Level 15: next roster entry (`Vampire`) — gentle counts/pacing on the new
	-- species, same as Goblin's Level 5 debut, before ramping through 16-19.
	Level15 = {
		id = "Level15",
		number = 15,
		name = "Night Falls",
		groups = {
			{ monsterId = "Zombie", count = 5, startDelay = 1.5, spawnInterval = 2.4 },
			{ monsterId = "Goblin", count = 5, startDelay = 10, spawnInterval = 2.2 },
			{ monsterId = "Vampire", count = 2, startDelay = 12, spawnInterval = 3.5 },
			{ monsterId = "Vampire", count = 3, startDelay = 12, spawnInterval = 3.0, isBigWave = true },
		},
	},

	Level16 = {
		id = "Level16",
		number = 16,
		name = "Bloodlust Rising",
		groups = {
			{ monsterId = "Zombie", count = 5, startDelay = 1.5, spawnInterval = 2.4 },
			{ monsterId = "Goblin", count = 5, startDelay = 10, spawnInterval = 2.2 },
			{ monsterId = "Vampire", count = 4, startDelay = 11, spawnInterval = 2.6 },
			{ monsterId = "Vampire", count = 4, startDelay = 11, spawnInterval = 2.4, isBigWave = true },
		},
	},

	Level17 = {
		id = "Level17",
		number = 17,
		name = "Crimson Vanguard",
		groups = {
			{ monsterId = "Zombie", count = 5, startDelay = 1.5, spawnInterval = 2.2 },
			{ monsterId = "Vampire", count = 4, startDelay = 10, spawnInterval = 2.4 },
			{ monsterId = "Goblin", count = 5, startDelay = 11, spawnInterval = 2.0 },
			{ monsterId = "GoblinElite", count = 1, startDelay = 14, spawnInterval = 2, isBigWave = true },
		},
	},

	Level18 = {
		id = "Level18",
		number = 18,
		name = "Twin Terror",
		groups = {
			{ monsterId = "Zombie", count = 5, startDelay = 1.5, spawnInterval = 2.2 },
			{ monsterId = "Vampire", count = 5, startDelay = 10, spawnInterval = 2.2 },
			{ monsterId = "GoblinElite", count = 1, startDelay = 12, spawnInterval = 2 },
			{ monsterId = "Vampire", count = 5, startDelay = 11, spawnInterval = 2.0, isBigWave = true },
		},
	},

	Level19 = {
		id = "Level19",
		number = 19,
		name = "Final Bloodline",
		groups = {
			{ monsterId = "Zombie", count = 5, startDelay = 1.5, spawnInterval = 2.0 },
			{ monsterId = "Vampire", count = 5, startDelay = 9, spawnInterval = 2.0 },
			{ monsterId = "GoblinElite", count = 1, startDelay = 11, spawnInterval = 2 },
			{ monsterId = "Vampire", count = 6, startDelay = 11, spawnInterval = 1.8, isBigWave = true },
		},
	},

	-- Level 20: next boss (`DukeVampire`), same cadence as Level 10's
	-- Goblin Elite intro — long `startDelay` lead-in, big-wave warning, and a
	-- total dip vs. Level 19 since the boss itself is the real check.
	Level20 = {
		id = "Level20",
		number = 20,
		name = "Duke Vampire",
		groups = {
			{ monsterId = "Zombie", count = 5, startDelay = 1.5, spawnInterval = 2.2 },
			{ monsterId = "Vampire", count = 5, startDelay = 10, spawnInterval = 2.2 },
			{ monsterId = "Goblin", count = 5, startDelay = 10, spawnInterval = 2.0 },
			{ monsterId = "DukeVampire", count = 1, startDelay = 18, spawnInterval = 2, isBigWave = true },
		},
	},

	-- Days 21–24: Night only. Days 25–30: NightFog (forest/east-lawn fog;
	-- easternmost 3 columns unplantable; monsters hidden until they exit).
	-- Day 25 intro Spider, Day 30 Queen Spider.
	Level21 = {
		id = "Level21",
		number = 21,
		name = "Fogbound",
		weather = "Night",
		groups = {
			{ monsterId = "Zombie", count = 4, startDelay = 1.5, spawnInterval = 2.6 },
			{ monsterId = "Goblin", count = 4, startDelay = 12, spawnInterval = 2.4 },
			{ monsterId = "Vampire", count = 2, startDelay = 14, spawnInterval = 3.2 },
			{ monsterId = "Zombie", count = 5, startDelay = 12, spawnInterval = 2.2, isBigWave = true },
		},
	},

	Level22 = {
		id = "Level22",
		number = 22,
		name = "Mist March",
		weather = "Night",
		groups = {
			{ monsterId = "Zombie", count = 5, startDelay = 1.5, spawnInterval = 2.4 },
			{ monsterId = "Goblin", count = 5, startDelay = 11, spawnInterval = 2.2 },
			{ monsterId = "Vampire", count = 3, startDelay = 12, spawnInterval = 2.8 },
			{ monsterId = "GoblinElite", count = 1, startDelay = 16, spawnInterval = 2, isBigWave = true },
		},
	},

	Level23 = {
		id = "Level23",
		number = 23,
		name = "Quiet Night",
		weather = "Night",
		groups = {
			{ monsterId = "Zombie", count = 4, startDelay = 1.5, spawnInterval = 2.8 },
			{ monsterId = "Goblin", count = 3, startDelay = 14, spawnInterval = 2.6 },
			{ monsterId = "Vampire", count = 2, startDelay = 14, spawnInterval = 3.4 },
			{ monsterId = "Goblin", count = 4, startDelay = 12, spawnInterval = 2.4, isBigWave = true },
		},
	},

	Level24 = {
		id = "Level24",
		number = 24,
		name = "Blood Fog",
		weather = "Night",
		groups = {
			{ monsterId = "Zombie", count = 5, startDelay = 1.5, spawnInterval = 2.2 },
			{ monsterId = "Vampire", count = 4, startDelay = 10, spawnInterval = 2.4 },
			{ monsterId = "Goblin", count = 5, startDelay = 11, spawnInterval = 2.0 },
			{ monsterId = "DukeVampire", count = 1, startDelay = 16, spawnInterval = 2, isBigWave = true },
		},
	},

	-- Level 25: Spider intro — jump-over first Brainrot; gentle counts.
	Level25 = {
		id = "Level25",
		number = 25,
		name = "Webbed Path",
		weather = "NightFog",
		groups = {
			{ monsterId = "Zombie", count = 4, startDelay = 1.5, spawnInterval = 2.6 },
			{ monsterId = "Goblin", count = 4, startDelay = 12, spawnInterval = 2.4 },
			{ monsterId = "Spider", count = 2, startDelay = 14, spawnInterval = 3.5 },
			{ monsterId = "Spider", count = 3, startDelay = 12, spawnInterval = 3.0, isBigWave = true },
		},
	},

	Level26 = {
		id = "Level26",
		number = 26,
		name = "Silk and Steel",
		weather = "NightFog",
		groups = {
			{ monsterId = "Zombie", count = 5, startDelay = 1.5, spawnInterval = 2.4 },
			{ monsterId = "Spider", count = 3, startDelay = 11, spawnInterval = 2.8 },
			{ monsterId = "Vampire", count = 3, startDelay = 12, spawnInterval = 2.6 },
			{ monsterId = "GoblinElite", count = 1, startDelay = 14, spawnInterval = 2, isBigWave = true },
		},
	},

	Level27 = {
		id = "Level27",
		number = 27,
		name = "Lull in the Mist",
		weather = "NightFog",
		groups = {
			{ monsterId = "Zombie", count = 4, startDelay = 1.5, spawnInterval = 2.8 },
			{ monsterId = "Spider", count = 2, startDelay = 13, spawnInterval = 3.2 },
			{ monsterId = "Goblin", count = 4, startDelay = 12, spawnInterval = 2.4 },
			{ monsterId = "Vampire", count = 3, startDelay = 12, spawnInterval = 2.8, isBigWave = true },
		},
	},

	Level28 = {
		id = "Level28",
		number = 28,
		name = "Duke's Night",
		weather = "NightFog",
		groups = {
			{ monsterId = "Zombie", count = 5, startDelay = 1.5, spawnInterval = 2.2 },
			{ monsterId = "Spider", count = 3, startDelay = 10, spawnInterval = 2.6 },
			{ monsterId = "Vampire", count = 4, startDelay = 11, spawnInterval = 2.4 },
			{ monsterId = "DukeVampire", count = 1, startDelay = 15, spawnInterval = 2, isBigWave = true },
		},
	},

	Level29 = {
		id = "Level29",
		number = 29,
		name = "Closing Webs",
		weather = "NightFog",
		groups = {
			{ monsterId = "Goblin", count = 5, startDelay = 1.5, spawnInterval = 2.2 },
			{ monsterId = "Spider", count = 4, startDelay = 10, spawnInterval = 2.4 },
			{ monsterId = "Vampire", count = 4, startDelay = 11, spawnInterval = 2.2 },
			{ monsterId = "GoblinElite", count = 1, startDelay = 13, spawnInterval = 2, isBigWave = true },
		},
	},

	-- Level 30: Queen Spider boss intro.
	Level30 = {
		id = "Level30",
		number = 30,
		name = "Queen Spider",
		weather = "NightFog",
		groups = {
			{ monsterId = "Zombie", count = 5, startDelay = 1.5, spawnInterval = 2.4 },
			{ monsterId = "Spider", count = 4, startDelay = 11, spawnInterval = 2.6 },
			{ monsterId = "Vampire", count = 3, startDelay = 12, spawnInterval = 2.4 },
			{ monsterId = "QueenSpider", count = 1, startDelay = 18, spawnInterval = 2, isBigWave = true },
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
