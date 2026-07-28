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
		secondsPerGrid = 3.5,
		damage = 100,
		attackInterval = 1.5,
		isBoss = false,
		color = Color3.fromRGB(90, 140, 90),
	},

	Vampire = {
		id = "Vampire",
		name = "Vampire",
		health = 900,
		secondsPerGrid = 2.5,
		damage = 70,
		attackInterval = 1.1,
		isBoss = false,
		color = Color3.fromRGB(80, 40, 60),
	},

	Werewolf = {
		id = "Werewolf",
		name = "Werewolf",
		health = 1400,
		secondsPerGrid = 2.9,
		damage = 130,
		attackInterval = 1.1,
		isBoss = false,
		color = Color3.fromRGB(110, 90, 70),
	},

	Skeleton = {
		id = "Skeleton",
		name = "Skeleton",
		health = 950,
		secondsPerGrid = 4.0,
		damage = 95,
		attackInterval = 1.5,
		isBoss = false,
		color = Color3.fromRGB(200, 200, 190),
	},

	Goblin = {
		id = "Goblin",
		name = "Goblin",
		health = 350,
		secondsPerGrid = 2.7,
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
		health = 6000,
		secondsPerGrid = 9.2,
		damage = 8000,
		attackInterval = 3.5,
		isBoss = true,
		abilities = { "GoblinEliteClubOneShot" },
		-- Spans 2 rows: Brainrots on adjacent lanes can attack it. Model scales to match.
		-- (Kept < 3 so more of the lawn's rows are valid random spawn anchors.)
		laneSpan = 2,
		color = Color3.fromRGB(60, 100, 50),
		walkAnimationId = "",
		attackAnimationId = MonsterConfig.DEFAULT_ATTACK_ANIMATION_ID,
	},

	Spider = {
		id = "Spider",
		name = "Spider",
		health = 900,
		secondsPerGrid = 2.9,
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
		secondsPerGrid = 5.5,
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
		secondsPerGrid = 6.0,
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
		secondsPerGrid = 6.3,
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
		-- Nerfed vs. the other Milestone-10 bosses (Goblin King / Queen Spider):
		-- Level 20 is the very next boss after Goblin Elite, so it needs to be
		-- beatable off a still-growing board, not a straight stat-tier jump.
		health = 10000,
		secondsPerGrid = 6.0,
		-- Regular chew = a Vampire's cadence (1.1s) with a bit more bite (Vampire = 70).
		damage = 100,
		attackInterval = 1.1,
		isBoss = true,
		-- laneSpan stays 1 (default) — he only ever walks/occupies one lane.
		-- `isBoss` alone already scales him up a bit vs. regular Vampires
		-- (see `MonsterModel.bodyHeightFor` / `footprintFor`).
		abilities = { "DukeVampireFreeze", "DukeVampireTerrify" },
		abilityParams = {
			-- Last stand (DukeVampireFreeze): once, at ≤20% HP, falls over
			-- (like a regular death-tip, rig intact) for lastStandFallDuration,
			-- invulnerable the whole time, then rises already healed to
			-- lastStandHealPercent max HP.
			lastStandTriggerPercent = 20,
			lastStandHealPercent = 50,
			lastStandFallDuration = 1.4,
			lastStandRiseDuration = 0.7,
			-- Terrify (DukeVampireTerrify): no damage — row ±1 Weaken + Stun,
			-- 10s cooldown.
			terrifyCooldown = 10,
			terrifyDamageReduction = 15,
			terrifyFreezeDuration = 2,
		},
		color = Color3.fromRGB(60, 20, 40),
		-- Dark aura to stand out from a duplicated-Vampire model — see
		-- `MonsterFeedback.applyAura`.
		auraColor = Color3.fromRGB(90, 15, 40),
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
