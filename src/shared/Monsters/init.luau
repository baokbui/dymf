--!strict
--[[
	Monsters Registry
	Central, data-driven catalog of every Monster definition.

	All monsters derive from one base implementation; types are data entries plus
	optional ability handlers. Never branch on monster names in code.
]]

local Types = require(script.Parent.Types)

local Monsters = {}

local definitions: { [string]: Types.MonsterDefinition } = {
	-- Slow, weak opener used only in early campaign levels (see Shared.Levels).
	TutorialZombie = {
		id = "TutorialZombie",
		name = "Zombie",
		health = 150,
		secondsPerGrid = 7,
		damage = 40,
		attackInterval = 2.5,
		isBoss = false,
		color = Color3.fromRGB(110, 160, 110),
	},

	-- Mid-tier zombie for the early campaign bridge (Level 2–3). Tougher than
	-- TutorialZombie but far weaker than the standard Zombie.
	EarlyZombie = {
		id = "EarlyZombie",
		name = "Zombie",
		health = 250,
		secondsPerGrid = 6,
		damage = 55,
		attackInterval = 2.2,
		isBoss = false,
		color = Color3.fromRGB(95, 150, 95),
	},

	Zombie = {
		id = "Zombie",
		name = "Zombie",
		health = 1000,
		secondsPerGrid = 4.7,
		damage = 100,
		attackInterval = 2,
		isBoss = false,
		color = Color3.fromRGB(90, 140, 90),
	},

	Vampire = {
		id = "Vampire",
		name = "Vampire",
		health = 1000,
		secondsPerGrid = 2.5,
		damage = 75,
		attackInterval = 1,
		isBoss = false,
		color = Color3.fromRGB(80, 40, 60),
	},

	Werewolf = {
		id = "Werewolf",
		name = "Werewolf",
		health = 1500,
		secondsPerGrid = 3.5,
		damage = 150,
		attackInterval = 1,
		isBoss = false,
		color = Color3.fromRGB(110, 90, 70),
	},

	Skeleton = {
		id = "Skeleton",
		name = "Skeleton",
		health = 1000,
		secondsPerGrid = 4.7,
		damage = 100,
		attackInterval = 1.5,
		isBoss = false,
		color = Color3.fromRGB(200, 200, 190),
	},

	Goblin = {
		id = "Goblin",
		name = "Goblin",
		health = 1000,
		secondsPerGrid = 3,
		damage = 100,
		attackInterval = 1,
		isBoss = false,
		color = Color3.fromRGB(70, 130, 60),
	},

	Orc = {
		id = "Orc",
		name = "Orc",
		health = 20000,
		secondsPerGrid = 8,
		damage = 10000,
		attackInterval = 4,
		isBoss = true,
		abilities = { "OrcClubOneShot" },
		color = Color3.fromRGB(60, 100, 50),
	},

	Spider = {
		id = "Spider",
		name = "Spider",
		health = 1000,
		secondsPerGrid = 3.5,
		damage = 100,
		attackInterval = 1.5,
		isBoss = false,
		abilities = { "SpiderJump" },
		color = Color3.fromRGB(40, 40, 40),
	},

	Necromancer = {
		id = "Necromancer",
		name = "Necromancer",
		health = 10000,
		secondsPerGrid = 6,
		damage = 0,
		attackInterval = 5,
		isBoss = true,
		abilities = { "NecromancerSummon", "NecromancerLaneChange" },
		abilityParams = { skillInterval = 5 },
		color = Color3.fromRGB(50, 30, 80),
	},

	GoblinKing = {
		id = "GoblinKing",
		name = "Goblin King",
		health = 15000,
		secondsPerGrid = 6.5,
		damage = 150,
		attackInterval = 1.5,
		isBoss = true,
		abilities = { "GoblinKingRegen", "GoblinKingSpeedBuff" },
		abilityParams = { regenAmount = 100, regenInterval = 8, speedBuffPercent = 20 },
		color = Color3.fromRGB(50, 120, 40),
	},

	QueenSpider = {
		id = "QueenSpider",
		name = "Queen Spider",
		health = 15000,
		secondsPerGrid = 7,
		damage = 150,
		attackInterval = 1.5,
		isBoss = true,
		abilities = { "QueenSpiderStun", "QueenSpiderPoison" },
		abilityParams = { stunDuration = 4, poisonPercent = 2, poisonDuration = 5 },
		color = Color3.fromRGB(30, 30, 30),
	},

	DukeVampire = {
		id = "DukeVampire",
		name = "Duke Vampire",
		health = 15000,
		secondsPerGrid = 5.5,
		damage = 150,
		attackInterval = 1.5,
		isBoss = true,
		abilities = { "DukeVampireFreeze", "DukeVampireTerrify" },
		abilityParams = {
			freezeDuration = 2,
			healPercent = 25,
			terrifyDamage = 100,
			terrifyDamageReduction = 10,
			terrifyDuration = 2,
		},
		color = Color3.fromRGB(60, 20, 40),
	},
}

function Monsters.get(id: string): Types.MonsterDefinition?
	return definitions[id]
end

function Monsters.exists(id: string): boolean
	return definitions[id] ~= nil
end

function Monsters.getAll(): { [string]: Types.MonsterDefinition }
	return definitions
end

return Monsters
