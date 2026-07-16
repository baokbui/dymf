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
	PROJECTILE_SIZE = Vector3.new(0.35, 0.35, 1.4),
	PROJECTILE_COLOR = Color3.fromRGB(220, 220, 230),

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

	-- Client health bar (BillboardGui on Body).
	HEALTH_BAR_WIDTH = 52,
	HEALTH_BAR_HEIGHT = 7,
	HEALTH_BAR_OFFSET_Y = 1.2,
	HEALTH_BAR_BG = Color3.fromRGB(30, 30, 36),
	HEALTH_BAR_FILL = Color3.fromRGB(90, 210, 90),
	HEALTH_BAR_FILL_LOW = Color3.fromRGB(220, 80, 80),
	HEALTH_BAR_BOSS_WIDTH = 72,

	-- Client death feedback (scale/fade tween duration).
	DEATH_FADE_DURATION = 0.2,

	-- Height above the lane surface for projectile travel.
	PROJECTILE_HEIGHT_OFFSET = 3.5,
}

table.freeze(CombatConfig)

return CombatConfig
