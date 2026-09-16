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

-- Status effects applied through CombatService. "Weaken" is Brainrot-only:
-- reduces the Brainrot's own outgoing damage by `magnitude` percent for
-- `duration` (see BrainrotBehavior effective-definition damage override).
export type StatusEffectKind = "Slow" | "Freeze" | "Poison" | "Burn" | "Knockback" | "Stun" | "Weaken"

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
	-- When true, monsters phase through and never deal chew damage (Lirili, Patapim).
	ignoreMonsterChew: boolean?,
	-- May plant on NightFog columns even before the row is cleared (Giraffa).
	plantsOnFog: boolean?,
	-- Must be planted on a grave tile (Patapim); other plants still cannot.
	plantOnGrave: boolean?,
	-- Omit from shop, inventory, unlock-all, lawn restore.
	hidden: boolean?,
	-- Anchor every part on place/preview (Toolbox humanoids that fall through).
	anchorAllParts: boolean?,
	plantCooldown: number?, -- seconds before re-plant; nil = BrainrotConfig.plantCooldownFor(cost)
	-- Cap of living plants of this id on one plot. Nil = unlimited.
	maxOnPlot: number?,
	color: Color3?, -- shop preview fallback swatch + placeholder/ghost tint
	modelId: string?, -- Assets.Brainrots child name; defaults to `id`
	-- Local Euler degrees (X=pitch, Y=yaw, Z=roll) applied after clearing Assets rotation.
	modelOrientationDegrees: Vector3?,
	-- Multiplier on tile footprint when cloning Assets templates (default 1).
	modelScale: number?,
	-- Extra studs up (+) / down (−) after feet-snap to the tile top.
	modelYOffset: number?,
	-- Shop/inventory ViewportFrame look-at nudge (studs in world space after center).
	previewFocusOffset: Vector3?,
	-- Keep Motor6D + Animator and play idle/attack tracks (Tung Tung, …).
	animated: boolean?,
	idleAnimationId: string?, -- rbxassetid://… idle loop; nil → IdleAnimation child / AnimSaves
	attackAnimationId: string?, -- rbxassetid://… action clip (swing / spit); nil → AttackAnimation child only
	hitAnimationId: string?, -- rbxassetid://… flinch when damaged; nil → HitAnimation child only
	-- Seconds after action anim starts before melee damage / coin spit.
	attackHitDelay: number?,
	-- One-shot clips keyed by extra ability id (e.g. ShadowRequiem).
	abilityAnimationIds: { [string]: string }?,
}

-- Data-driven definition for a Monster type (zombie, vampire, boss, ...).
export type MonsterDefinition = {
	id: string,
	name: string,
	health: number,
	secondsPerGrid: number, -- seconds to move one tile toward the house (higher = slower)
	damage: number, -- damage per attack (0 when abilities handle all damage)
	attackInterval: number, -- seconds between attacks while chewing a tile
	-- Seconds after melee anim starts before chew damage / onAttack hooks.
	-- Nil / 0 = hit on the same tick as the swing (legacy).
	attackHitDelay: number?,
	isBoss: boolean?,
	abilities: { string }?, -- ability handler ids (EnemyService/Abilities)
	abilityParams: { [string]: number }?,
	color: Color3?,
	modelId: string?, -- Assets.Monsters child name; defaults to `id`
	modelOrientationDegrees: Vector3?, -- local Euler after facing house (−X)
	-- Multiplier on BODY_HEIGHT / footprint when cloning Assets templates (default 1).
	modelScale: number?,
	walkAnimationId: string?, -- rbxassetid://… walk loop; "" disables walk
	attackAnimationId: string?, -- rbxassetid://… melee swing; "" disables
	-- One-shot clips keyed by ability handler id (e.g. PharaohSummon).
	abilityAnimationIds: { [string]: string }?,
	-- When true, EnemyService drives a procedural crawl gait on Motor6D/Bone/Weld
	-- leg joints (Toolbox spiders / scorpions without a matching uploaded Animation).
	proceduralWalk: boolean?,
	-- Death pose style for MonsterDeath.play. Nil / "TipOver" = randomized tip.
	deathStyle: string?,
	-- Spawn entrance. Nil = appear in place. "RiseFromGround" = buried then
	-- tween up (mummies). Duration: spawnRiseDuration or MonsterConfig.SPAWN_RISE_DURATION.
	spawnStyle: string?,
	spawnRiseDuration: number?,
	-- How many grid rows this unit occupies for targeting (1 = normal; 3 = hit from ±1 row).
	laneSpan: number?,
	-- When set, stop this many tiles east of a Brainrot and shoot instead of chewing.
	rangedTiles: number?,
	-- Persistent tinted particle + glow around the model (e.g. Duke Vampire's
	-- dark aura) — omit for no aura. See `MonsterFeedback.applyAura`.
	auraColor: Color3?,
	-- Scales the aura's particle size / glow range; nil = 1 (default size).
	auraScale: number?,
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
	-- Optional fixed anchor row (lowest occupied row for multi-lane units).
	-- When omitted, LevelService picks `GridUtil.randomRowForSpan(laneSpan)`.
	row: number?,
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
	-- Optional weather id (e.g. WeatherConfig.NIGHT / NIGHT_FOG). Nil = clear day.
	weather: string?,
	-- Fog-tile graves for this day (NightFog / NightFogReceded). Nil = none.
	graves: boolean?,
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

-- Future (Milestone 21): bosses displayed in the plot house that generate brains.
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
	-- Shared XP pool per Brainrot registry id (all planted copies of that unit).
	brainrotXp: { [string]: number },
	-- Claimed evolution rarities per Brainrot id (Epic→God). Level gate
	-- is separate; claiming spends brains.
	evolutions: { [string]: { string } }?,
	-- Monster / boss intro popups already shown (ProgressConfig.MONSTER_INTRO_SCHEDULE).
	introducedMonsters: { string }?,
	-- Brainrot intro popups already shown (BRAINROT_INTRO_SCHEDULE + UNLOCK_SCHEDULE).
	introducedBrainrots: { string }?,
	-- Mechanic / hazard intros already shown (MECHANIC_INTRO_SCHEDULE, e.g. Grave).
	introducedMechanics: { string }?,
	-- 🔜 Milestone 21 — collected boss trophies displayed in the house
	collectedBosses: { CollectedBoss }?,
}

return {}
