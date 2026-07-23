--!strict
--[[
	Types
	Shared Luau type definitions used across client and server.

	These types describe the data-driven shapes for Brainrots, Monsters,
	grid state, and save data. Keep gameplay behavior out of this module;
	it should only declare contracts.
]]

export type GridPosition = {
	row: number,
	column: number,
}

-- Status effects applied through CombatService.
export type StatusEffectKind = "Slow" | "Freeze" | "Poison" | "Burn" | "Knockback" | "Stun"

export type StatusEffect = {
	kind: StatusEffectKind,
	duration: number,
	magnitude: number,
}

-- Combat: `maxHealth` is the HP pool for UI; `health` is hits the unit can take.
export type BrainrotDefinition = {
	id: string,
	name: string,
	cost: number,
	maxHealth: number, -- HP pool (display / future health bar)
	health: number, -- hits the Brainrot can take before destruction
	damage: number, -- damage per attack (0 for non-attackers)
	attackInterval: number, -- seconds between attacks/actions (0 = passive wall)
	rangeTiles: number, -- tiles ahead toward +X; BrainrotConfig.FULL_LINE_RANGE = full row
	ability: string?, -- ability handler id (resolved by BrainrotService/Abilities)
	coinGeneration: number?, -- coins per cycle for producers
	abilityParams: { [string]: number }?, -- per-ability tuning (trap/freeze duration, …)
	triggersOnPlace: boolean?, -- true = ability fires once on placement (e.g. line bomb)
	color: Color3?, -- shop preview fallback swatch + placeholder/ghost tint
	modelId: string?, -- Assets.Brainrots child name; defaults to `id`
	-- Local Euler degrees (X=pitch, Y=yaw, Z=roll) applied after clearing Assets rotation.
	modelOrientationDegrees: Vector3?,
	-- Multiplier on tile footprint when cloning Assets templates (default 1).
	modelScale: number?,
}

-- Data-driven definition for a Monster type (zombie, vampire, boss, ...).
export type MonsterDefinition = {
	id: string,
	name: string,
	health: number,
	secondsPerGrid: number, -- seconds to move one tile toward the house (higher = slower)
	damage: number, -- damage per attack (0 when abilities handle all damage)
	attackInterval: number, -- seconds between attacks while chewing a tile
	isBoss: boolean?,
	abilities: { string }?, -- ability handler ids (EnemyService/Abilities)
	abilityParams: { [string]: number }?,
	color: Color3?,
	modelId: string?, -- Assets.Monsters child name; defaults to `id`
	modelOrientationDegrees: Vector3?, -- local Euler after facing house (−X)
	walkAnimationId: string?, -- rbxassetid://… walk loop; "" disables walk
	attackAnimationId: string?, -- rbxassetid://… melee swing; "" disables
	-- How many grid rows this unit occupies for targeting (1 = normal; 3 = hit from ±1 row).
	laneSpan: number?,
}

-- One ordered burst of monsters within a level (an internal "wave"). A level is
-- authored as a sequence of these; the last group is usually the "big wave"
-- (the PvZ flag). Timing fields fall back to LevelConfig defaults when omitted.
export type SpawnGroup = {
	monsterId: string,
	count: number,
	startDelay: number?, -- seconds before this group begins (after the previous one)
	spawnInterval: number?, -- seconds between each monster within this group
	isBigWave: boolean?, -- marks the big final wave on the level progress bar
}

-- A single authored campaign level. Levels are data-driven entries in the
-- Shared.Levels registry; LevelService plays them in `number` order and beating
-- one unlocks the next. Never branch on level numbers — read the definition.
export type LevelDefinition = {
	id: string,
	number: number, -- 1-based campaign position (ordering + display)
	name: string,
	groups: { SpawnGroup },
	reward: number?, -- coins on completion (defaults to EconomyConfig base)
}

-- Runtime tile state tracked by the grid (server-authoritative).
export type Tile = {
	position: GridPosition,
	occupied: boolean,
	brainrotInstanceId: string?,
}

-- A planted Brainrot instance on a player's battlefield.
export type PlantedBrainrot = {
	instanceId: string,
	brainrotId: string,
	position: GridPosition,
	health: number,
}

-- Future (Milestone 25): bosses displayed in the plot house that generate brains.
export type CollectedBoss = {
	monsterId: string, -- Shared.Monsters id (must be isBoss)
	slotIndex: number, -- 1-based BossSlot_* pedestal
	collectedAtLevel: number?, -- campaign level when first collected
}

-- Versioned player save data. Only player-owned progression is persisted.
export type SaveData = {
	version: number,
	currentLevel: number, -- campaign level the player is on / resumes
	highestLevel: number, -- furthest level unlocked (drives Level Select)
	coins: number,
	brains: number, -- soft currency for Brainrots Store / evolve / house income
	playerHealth: number, -- hearts remaining (max ProgressConfig.MAX_PLAYER_HEALTH)
	brainrots: { PlantedBrainrot },
	unlocks: { string }, -- owned Brainrot ids
	equipped: { string }, -- ordered loadout shown in the placement shop
	upgrades: { [string]: number },
	statistics: { [string]: number },
	-- 🔜 Milestone 25 — collected boss trophies displayed in the house
	collectedBosses: { CollectedBoss }?,
}

return {}
