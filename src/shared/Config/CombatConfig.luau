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

	-- Cappuccino spinning shuriken (procedural Model; flat disc spun face-on toward enemy).
	SHURIKEN_BLADE_SIZE = Vector3.new(2.2, 0.14, 2.2), -- span (X/Z) x thickness (Y)
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
}

table.freeze(CombatConfig)

return CombatConfig
