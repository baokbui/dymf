--!strict
--[[
	Monsters Registry
	Central, data-driven catalog of every Monster definition.

	All monsters derive from one base implementation; types are data entries plus
	optional ability handlers. Never branch on monster names in code.

	Milestone 14+ balance — see docs/BALANCE.md.
	Spawned HP ages with the campaign day (scaledForDay, non-boss only); this catalog stays base.
]]

local MonsterConfig = require(script.Parent.Config.MonsterConfig)
local ProgressConfig = require(script.Parent.Config.ProgressConfig)
local Types = require(script.Parent.Types)

local Monsters = {}

local definitions: { [string]: Types.MonsterDefinition } = {
	Zombie = {
		id = "Zombie",
		name = "Zombie",
		health = 250,
		secondsPerGrid = 3.5,
		damage = 80,
		attackInterval = 1.5,
		isBoss = false,
		color = Color3.fromRGB(90, 140, 90),
		walkAnimationId = "rbxassetid://101706062723839",
		attackAnimationId = "rbxassetid://116092305201046",
		-- Seconds after attack anim starts before chew damage lands.
		attackHitDelay = 0.4,
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
		secondsPerGrid = 2.0,
		damage = 60,
		attackInterval = 1.5,
		isBoss = false,
		abilities = { "WerewolfLifesteal" },
		abilityParams = {
			-- Heal this % of max HP on every chew hit against a Brainrot.
			lifestealPercent = 5,
		},
		color = Color3.fromRGB(110, 90, 70),
		-- Template currently lives under Assets.Brainrots (Studio); ModelUtil
		-- falls back there when Assets.Monsters has no match.
		modelId = "Werewolf",
		modelScale = 1.45,
		walkAnimationId = "rbxassetid://98391463724574",
		attackAnimationId = "rbxassetid://124598361208208",
	},

	Skeleton = {
		id = "Skeleton",
		name = "Skeleton",
		health = 200,
		secondsPerGrid = 4.0,
		damage = 90,
		attackInterval = 1.5,
		isBoss = false,
		abilities = { "SkeletonArrow" },
		rangedTiles = 3,
		color = Color3.fromRGB(200, 200, 190),
		modelId = "Skeleton",
		walkAnimationId = "rbxassetid://121181303544612",
		attackAnimationId = "rbxassetid://125064505468611",
		-- Seconds after attack anim starts before the arrow launches.
		attackHitDelay = 0.4,
	},

	Goblin = {
		id = "Goblin",
		name = "Goblin",
		health = 350,
		secondsPerGrid = 2.7,
		damage = 100,
		attackInterval = 1.0,
		isBoss = false,
		color = Color3.fromRGB(70, 130, 60),
		walkAnimationId = "rbxassetid://88413250285755",
		attackAnimationId = "rbxassetid://117829288192683",
		attackHitDelay = 0.7,
	},

	GoblinElite = {
		id = "GoblinElite",
		name = "Goblin Elite",
		health = 6000,
		secondsPerGrid = 6.2,
		damage = 8000,
		attackInterval = 3.5,
		isBoss = true,
		abilities = { "GoblinEliteClubOneShot" },
		-- Three lawn rows (anchor + 2). Model scales to match.
		laneSpan = 3,
		color = Color3.fromRGB(60, 100, 50),
		walkAnimationId = "rbxassetid://135233369169455",
		attackAnimationId = "rbxassetid://117829288192683",
		attackHitDelay = 0.7,
	},

	Spider = {
		id = "Spider",
		name = "Spider",
		health = 550,
		secondsPerGrid = 1.8,
		damage = 90,
		attackInterval = 1.4,
		isBoss = false,
		abilities = { "SpiderJump" },
		abilityParams = {
			-- Leap over the first Brainrot (visual arc; plant is not damaged).
			jumpDuration = 0.55,
			jumpPeakHeight = 5.5,
			jumpLandOffset = 0.8,
			jumpTriggerReach = 0.95,
		},
		color = Color3.fromRGB(40, 40, 40),
		-- Toolbox mesh faces +X; yaw 180 so eyes look house-ward (−X).
		modelOrientationDegrees = Vector3.new(0, 90, 0),
		-- Toolbox AnimationId is often permission-locked; use AnimSaves (local)
		-- or MonsterProceduralGait — never request the pack rbxassetid.
		walkAnimationId = "",
		attackAnimationId = "",
		proceduralWalk = true,
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
		secondsPerGrid = 4.0,
		damage = 130,
		attackInterval = 1.5,
		isBoss = true,
		abilities = { "GoblinKingRegen", "GoblinKingAttackBuff" },
		abilityParams = { regenPercent = 5, regenInterval = 10, attackBuffPercent = 10 },
		-- Two lawn rows (anchor + 1). Width and chew both follow laneSpan.
		-- Height-only trim so the 2-lane scale does not leave him as tall.
		laneSpan = 2,
		modelHeightScale = 0.9,
		-- Accessories are WeldConstraints on the rig. Anchoring those parts
		-- would freeze the welds.
		keepWeldConstraints = true,
		color = Color3.fromRGB(50, 120, 40),
		walkAnimationId = "rbxassetid://134618618846294",
		attackAnimationId = "rbxassetid://92113851689341",
		-- Club impact, same beat as Goblin / Goblin Elite.
		attackHitDelay = 0.7,
	},

	QueenSpider = {
		id = "QueenSpider",
		name = "Queen Spider",
		health = 13000,
		secondsPerGrid = 6.3,
		damage = 120,
		attackInterval = 1.5,
		isBoss = true,
		-- Occupies three lawn rows (anchor + 2). On a 5-row lawn that means
		-- valid anchors 1–3 (covers 1–3, 2–4, or 3–5) — LevelService uses
		-- `randomRowForSpan`, never edge-only single-lane placement. Does NOT
		-- jump — stun on every bite, poison on every other bite.
		laneSpan = 3,
		abilities = { "QueenSpiderStun", "QueenSpiderPoison" },
		abilityParams = {
			stunDuration = 2,
			-- % of Brainrot maxHealth per poison tick (1s interval).
			poisonPercent = 3,
			poisonDuration = 4,
			poisonEvery = 2,
		},
		color = Color3.fromRGB(30, 30, 30),
		-- Duplicated Spider Toolbox model — same procedural crawl gait.
		modelOrientationDegrees = Vector3.new(0, 90, 0),
		walkAnimationId = "",
		attackAnimationId = "",
		proceduralWalk = true,
	},

	DukeVampire = {
		id = "DukeVampire",
		name = "Duke Vampire",
		-- Nerfed vs. the other Milestone-10 bosses (Goblin King / Queen Spider):
		-- Level 20 is the very next boss after Goblin Elite, so it needs to be
		-- beatable off a still-growing board, not a straight stat-tier jump.
		health = 8000,
		secondsPerGrid = 4.8,
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
			-- exactly like a regular monster death (randomized tip, rig
			-- intact) for lastStandFallDuration, lies on the ground for
			-- lastStandGroundDuration, invulnerable the whole time, then
			-- rises already healed to lastStandHealPercent max HP.
			lastStandTriggerPercent = 20,
			lastStandHealPercent = 25,
			lastStandFallDuration = 1.0,
			lastStandGroundDuration = 3,
			lastStandRiseDuration = 0.7,
			-- Terrify (DukeVampireTerrify): no damage — row ±1, his column plus
			-- 2 tiles ahead toward the house (west), Weaken + Stun, 10s cooldown.
			terrifyCooldown = 10,
			terrifyDamageReduction = 15,
			terrifyFreezeDuration = 4,
			terrifyColumnsBehind = 2,
		},
		color = Color3.fromRGB(60, 20, 40),
		-- Dark aura to stand out from a duplicated-Vampire model — see
		-- `MonsterFeedback.applyAura`. Scaled up so it reads clearly as his
		-- signature boss "tell" from a distance.
		auraColor = Color3.fromRGB(90, 15, 40),
		auraScale = 1.6,
	},

	SmallMummy = {
		id = "SmallMummy",
		name = "Small Mummy",
		health = 1000,
		secondsPerGrid = 2.0,
		damage = 100,
		attackInterval = 1.5,
		isBoss = false,
		color = Color3.fromRGB(210, 190, 140),
		modelId = "SmallMummy",
		walkAnimationId = "rbxassetid://136444900181135",
		attackAnimationId = "rbxassetid://133284998118919",
		spawnStyle = "RiseFromGround",
	},

	PharaohMummy = {
		id = "PharaohMummy",
		name = "Pharaoh Mummy",
		health = 15000,
		secondsPerGrid = 5.0,
		damage = 200,
		attackInterval = 1.0,
		isBoss = true,
		abilities = { "PharaohSummon", "PharaohSteal" },
		abilityParams = {
			summonCooldown = 20,
			stealCooldown = 15,
			stealLaneCount = 3,
			-- Seconds after ability anim starts before minions / steal land.
			summonHitDelay = 0.9,
			stealHitDelay = 0.85,
		},
		color = Color3.fromRGB(220, 170, 70),
		modelId = "PharaohMummy",
		-- Two lawn rows (anchor + 1). Width comes from laneSpan; height is pulled
		-- down so the wide scale does not leave him towering.
		laneSpan = 2,
		modelHeightScale = 0.82,
		walkAnimationId = "rbxassetid://72737313323934",
		attackAnimationId = "rbxassetid://133284998118919",
		abilityAnimationIds = {
			PharaohSummon = "rbxassetid://114030281000299",
			PharaohSteal = "rbxassetid://93082363577263",
		},
		spawnStyle = "RiseFromGround",
		spawnVfx = "Sandstorm",
		auraColor = Color3.fromRGB(230, 190, 80),
		auraScale = 1.5,
	},

	Scorpion = {
		id = "Scorpion",
		name = "Scorpion",
		health = 500,
		secondsPerGrid = 1.8,
		damage = 100,
		attackInterval = 1.2,
		isBoss = false,
		abilities = { "ScorpionBurrow", "ScorpionVenom" },
		abilityParams = {
			burrowDuration = 1.55,
			burrowDepth = 5.5,
			emergeOffset = 0.45,
			-- % of Brainrot maxHealth per venom tick (1s interval).
			venomPercent = 3,
			venomDuration = 4,
			venomEvery = 3,
		},
		color = Color3.fromRGB(196, 92, 36),
		modelId = "Scorpion",
		-- Toolbox mesh faces the opposite way from Spider; yaw 270 looks house-ward.
		modelOrientationDegrees = Vector3.new(0, 270, 0),
		walkAnimationId = "",
		attackAnimationId = "rbxassetid://134435243507976",
		-- Seconds after sting anim starts before chew damage lands.
		attackHitDelay = 0.4,
		proceduralWalk = true,
		spawnStyle = "RiseFromGround",
	},
}

function Monsters.get(id: string): Types.MonsterDefinition?
	return definitions[id]
end

-- Shallow copy with HP scaled for the day. Bosses keep authored stats.
-- Damage, speed, and cadence stay at intro-day bases.
function Monsters.scaledForDay(id: string, currentDay: number): Types.MonsterDefinition?
	local definition = definitions[id]
	if not definition then
		return nil
	end
	if definition.isBoss == true then
		return definition
	end
	local multiplier = MonsterConfig.statMultiplier(currentDay, ProgressConfig.monsterIntroDay(id))
	if multiplier <= 1 then
		return definition
	end
	local scaled = table.clone(definition)
	scaled.health = MonsterConfig.scaleStat(definition.health, multiplier)
	return scaled
end

-- The campaign day is the monster's level. A species first appears on its
-- intro day, so that day is its starting level (Zombie 1, Goblin Elite 10,
-- Queen Spider 30). Later days use the player's current day.
function Monsters.levelForDay(currentDay: number): number
	if type(currentDay) ~= "number" then
		return 1
	end
	return math.max(1, math.floor(currentDay))
end

function Monsters.exists(id: string): boolean
	return definitions[id] ~= nil
end

function Monsters.getAll(): { [string]: Types.MonsterDefinition }
	return definitions
end

return Monsters
