--!strict
--[[
	CombatConfig
	Global combat tuning. Per-unit stats live in Shared.Brainrots / Shared.Monsters.
]]

local CombatConfig = {
	-- Server combat tick (projectiles + DoT). Matches behavior ticks by default.
	TICK = 0.1,

	-- Projectile travel speed in grid columns per second (+X toward the enemy).
	PROJECTILE_COLUMNS_PER_SECOND = 6,

	-- Replicated projectile body (server-spawned, visible to all).
	-- Legacy bolt size kept for non-shuriken kinds; Cappuccino uses shuriken dims below.
	PROJECTILE_SIZE = Vector3.new(0.35, 0.35, 1.4),
	PROJECTILE_COLOR = Color3.fromRGB(220, 220, 230),

	-- Cappuccino spinning shuriken. Prefer Assets.Projectiles[SHURIKEN_MODEL_ID];
	-- procedural star is the fallback if the template is missing.
	SHURIKEN_MODEL_ID = "Shuriken",
	SHURIKEN_TARGET_EXTENT = 2.2, -- max horizontal size after clone ScaleTo
	-- Local Euler applied each frame before +Y spin (tune if the mesh faces wrong).
	SHURIKEN_MODEL_ORIENTATION_DEGREES = Vector3.new(0, 0, 0),
	SHURIKEN_BLADE_SIZE = Vector3.new(2.2, 0.14, 2.2), -- procedural fallback span × thickness
	SHURIKEN_HUB_SIZE = Vector3.new(0.55, 0.18, 0.55),
	SHURIKEN_BLADE_COLOR = Color3.fromRGB(210, 215, 225),
	SHURIKEN_HUB_COLOR = Color3.fromRGB(60, 60, 68),
	SHURIKEN_SPIN_RADIANS_PER_SECOND = math.pi * 14, -- 7 turns/sec
	-- Flat disc needs less clearance than the old cartwheeling sword.
	SHURIKEN_PROJECTILE_HEIGHT_OFFSET = 3.2,

	-- Tralalero bubble projectile (Ball + ForceField; color from MonsterConfig.BUBBLE_COLOR).
	BUBBLE_PROJECTILE_SIZE = Vector3.new(1.6, 1.6, 1.6),
	BUBBLE_PROJECTILE_TRANSPARENCY = 0.35,

	-- Status effect defaults when magnitude is omitted.
	POISON_TICK_INTERVAL = 1,
	POISON_DAMAGE_PER_TICK = 25,
	BURN_TICK_INTERVAL = 0.75,
	BURN_DAMAGE_PER_TICK = 40,
	SLOW_SPEED_FACTOR = 0.5, -- movement multiplier while slowed
	KNOCKBACK_TILES = 0.75,

	-- Monster death: slow tip-over (server-replicated), linger on ground, then fade.
	DEATH_FALL_DURATION = 1.0,
	DEATH_CORPSE_LINGER = 2.0,
	DEATH_FADE_OUT_DURATION = 0.4,

	-- Height above the lane surface for projectile travel.
	PROJECTILE_HEIGHT_OFFSET = 3.5,

	-- Skeleton westbound arrow. Prefer Assets.Projectiles[ARROW_MODEL_ID].
	ARROW_MODEL_ID = "Arrow",
	ARROW_MODEL_ORIENTATION_DEGREES = Vector3.new(0, 0, 0),
	ARROW_PROJECTILE_HEIGHT_OFFSET = 3.2,
	ARROW_FALLBACK_SIZE = Vector3.new(0.18, 0.18, 1.6),
	ARROW_FALLBACK_COLOR = Color3.fromRGB(210, 190, 140),
}

table.freeze(CombatConfig)

return CombatConfig
