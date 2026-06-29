--!strict
--[[
	Types
	Shared Luau type definitions used across client and server.

	These types describe the data-driven shapes for Brainrots, Zombies,
	grid state, and save data. Keep gameplay behavior out of this module;
	it should only declare contracts.
]]

export type GridPosition = {
	row: number,
	column: number,
}

-- Status effects applied through CombatService.
export type StatusEffectKind = "Slow" | "Freeze" | "Poison" | "Burn" | "Knockback"

export type StatusEffect = {
	kind: StatusEffectKind,
	duration: number,
	magnitude: number,
}

-- Data-driven definition for a Brainrot type. Behavior is resolved from data,
-- never from hardcoded if/elseif chains.
export type BrainrotDefinition = {
	id: string,
	name: string,
	cost: number,
	health: number,
	damage: number,
	attackSpeed: number, -- attacks per second
	range: number, -- in studs
	ability: string?,
	coinGeneration: number?, -- coins per cycle for money producers
}

-- Data-driven definition for a Zombie type.
export type ZombieDefinition = {
	id: string,
	name: string,
	health: number,
	speed: number, -- studs per second
	damage: number,
	attackSpeed: number, -- attacks per second
	abilities: { string }?,
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
	currentWave: number,
	coins: number,
	playerHealth: number,
	brainrots: { PlantedBrainrot },
	unlocks: { string },
	upgrades: { [string]: number },
	statistics: { [string]: number },
}

return {}
