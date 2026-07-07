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
	color: Color3?, -- placement visual tint (preview ghost + placed body)
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

-- Versioned player save data. Only player-owned progression is persisted.
export type SaveData = {
	version: number,
	currentLevel: number, -- campaign level the player is on / resumes
	highestLevel: number, -- furthest level unlocked (drives Level Select)
	coins: number,
	playerHealth: number,
	brainrots: { PlantedBrainrot },
	unlocks: { string },
	upgrades: { [string]: number },
	statistics: { [string]: number },
}

return {}
