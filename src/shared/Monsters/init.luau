--!strict
--[[
	Monsters Registry
	Central, data-driven catalog of every Monster definition.

	All monsters derive from one base implementation; types are data entries plus
	optional ability handlers. Never branch on monster names in code.

	Milestone 14+ balance — see docs/BALANCE.md.
]]

local MonsterConfig = require(script.Parent.Config.MonsterConfig)
local Types = require(script.Parent.Types)

local Monsters = {}

local definitions: { [string]: Types.MonsterDefinition } = {
	Zombie = {
		id = "Zombie",
		name = "Zombie",
		health = 250,
		secondsPerGrid = 3.0,
		damage = 100,
		attackInterval = 1.5,
		isBoss = false,
		color = Color3.fromRGB(90, 140, 90),
	},

	Vampire = {
		id = "Vampire",
		name = "Vampire",
		health = 900,
		secondsPerGrid = 2.2,
		damage = 70,
		attackInterval = 1.1,
		isBoss = false,
		color = Color3.fromRGB(80, 40, 60),
	},

	Werewolf = {
		id = "Werewolf",
		name = "Werewolf",
		health = 1400,
		secondsPerGrid = 2.5,
		damage = 130,
		attackInterval = 1.1,
		isBoss = false,
		color = Color3.fromRGB(110, 90, 70),
	},

	Skeleton = {
		id = "Skeleton",
		name = "Skeleton",
		health = 950,
		secondsPerGrid = 3.5,
		damage = 95,
		attackInterval = 1.5,
		isBoss = false,
		color = Color3.fromRGB(200, 200, 190),
	},

	Goblin = {
		id = "Goblin",
		name = "Goblin",
		health = 200,
		secondsPerGrid = 2.3,
		damage = 110,
		attackInterval = 1.0,
		isBoss = false,
		color = Color3.fromRGB(70, 130, 60),
		-- Catalog R15 walk fights grid snap on this Toolbox rig — club swing only.
		walkAnimationId = "",
		attackAnimationId = MonsterConfig.DEFAULT_ATTACK_ANIMATION_ID,
	},

	GoblinElite = {
		id = "GoblinElite",
		name = "Goblin Elite",
		health = 14000,
		secondsPerGrid = 8,
		damage = 8000,
		attackInterval = 3.5,
		isBoss = true,
		abilities = { "GoblinEliteClubOneShot" },
		-- Spans 3 rows: Brainrots on adjacent lanes can attack it. Model scales to match.
		laneSpan = 3,
		color = Color3.fromRGB(60, 100, 50),
		walkAnimationId = "",
		attackAnimationId = MonsterConfig.DEFAULT_ATTACK_ANIMATION_ID,
	},

	Spider = {
		id = "Spider",
		name = "Spider",
		health = 900,
		secondsPerGrid = 2.5,
		damage = 90,
		attackInterval = 1.4,
		isBoss = false,
		abilities = { "SpiderJump" },
		color = Color3.fromRGB(40, 40, 40),
	},

	Necromancer = {
		id = "Necromancer",
		name = "Necromancer",
		health = 9000,
		secondsPerGrid = 4.8,
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
		health = 13000,
		secondsPerGrid = 5.2,
		damage = 140,
		attackInterval = 1.5,
		isBoss = true,
		abilities = { "GoblinKingRegen", "GoblinKingSpeedBuff" },
		abilityParams = { regenAmount = 90, regenInterval = 8, speedBuffPercent = 18 },
		color = Color3.fromRGB(50, 120, 40),
	},

	QueenSpider = {
		id = "QueenSpider",
		name = "Queen Spider",
		health = 13000,
		secondsPerGrid = 5.5,
		damage = 140,
		attackInterval = 1.5,
		isBoss = true,
		abilities = { "QueenSpiderStun", "QueenSpiderPoison" },
		abilityParams = { stunDuration = 3.5, poisonPercent = 2, poisonDuration = 5 },
		color = Color3.fromRGB(30, 30, 30),
	},

	DukeVampire = {
		id = "DukeVampire",
		name = "Duke Vampire",
		health = 13000,
		secondsPerGrid = 4.4,
		damage = 140,
		attackInterval = 1.5,
		isBoss = true,
		abilities = { "DukeVampireFreeze", "DukeVampireTerrify" },
		abilityParams = {
			freezeDuration = 2,
			healPercent = 22,
			terrifyDamage = 90,
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
