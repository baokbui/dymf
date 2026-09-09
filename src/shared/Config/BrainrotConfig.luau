--!strict
--[[
	BrainrotConfig
	Global Brainrot tuning constants. Per-unit stats live in the Shared.Brainrots
	registry; ability-specific defaults that are not per-unit belong here.
]]

local DevConfig = require(script.Parent.DevConfig)

local BrainrotConfig = {
	-- rangeTiles value that means "entire row toward the enemy" (+X).
	FULL_LINE_RANGE = -1,

	-- Default bat-melee tile reach when a definition omits / zeroes rangeTiles.
	-- Tung Tung uses rangeTiles = 1 (own tile + one ahead) via MeleeBat.
	MELEE_BAT_REACH_TILES = 1,

	-- Legacy fractional reach (unused by MeleeBat; kept for older queries).
	MELEE_BAT_REACH = 1.35,

	-- Plant recharge after placing a unit (PvZ-style seed packet). Lower cost →
	-- shorter cooldown. Linear map from COST_MIN→COOLDOWN_MIN to COST_MAX→COOLDOWN_MAX.
	-- Optional definition.plantCooldown overrides the formula.
	PLANT_COOLDOWN_MIN = 7.5, -- Ballerina (50 coins)
	PLANT_COOLDOWN_MAX = 30, -- Bombardino (325 coins / plantCooldown override)
	PLANT_COOLDOWN_COST_MIN = 50,
	PLANT_COOLDOWN_COST_MAX = 325,

	-- Server behavior tick rate (seconds). Cooldowns count down on this step.
	BEHAVIOR_TICK = 0.1,

	-- Visual attack pulse (server tween, replicated on the model body).
	ATTACK_PULSE_SCALE = 1.18,
	ATTACK_PULSE_DURATION = 0.12,

	-- Authored models face this world direction when placed (toward the enemy).
	MODEL_FACE_DIRECTION = Vector3.new(1, 0, 0),

	-- Damage flash on hit (replicated body color; mirrors MonsterConfig).
	HIT_FLASH_COLOR = Color3.fromRGB(255, 90, 90),
	HIT_FLASH_DURATION = 0.14,

	-- Slight purple wash while Poison is active (server-replicated part Color).
	POISON_TINT_COLOR = Color3.fromRGB(175, 70, 255),
	POISON_TINT_BLEND = 0.65, -- 0 = original, 1 = full purple

	-- Stoneheart: rock wash while invulnerable (server-replicated Color + Material).
	STONE_TINT_COLOR = Color3.fromRGB(132, 124, 112),
	STONE_TINT_BLEND = 0.78,
	STONE_MATERIAL = Enum.Material.Slate,

	-- Bombardino: fly the plant across the row while dropping one Bomb per tile.
	-- Fly time is derived from DROP_STAGGER so the croc stays synced with drops.
	LINE_BOMB_MODEL_ID = "Bomb",
	LINE_BOMB_TARGET_EXTENT = 5, -- max size after clone ScaleTo
	LINE_BOMB_FLY_HEIGHT = 20, -- studs above tile for the croc pass
	LINE_BOMB_DROP_HEIGHT = 18, -- studs above tile when a bomb appears
	LINE_BOMB_FALL_DURATION = 0.4, -- seconds for a bomb to hit the tile
	LINE_BOMB_DROP_STAGGER = 0.12, -- seconds between tiles (also drives fly speed)
	-- Nose toward −Y so the bomb points down while falling.
	LINE_BOMB_DROP_ORIENTATION_DEGREES = Vector3.new(0, 0, -90),

	-- Multiplier on PlotConfig.BRAINROT_FOOTPRINT_RATIO when a definition sets
	-- modelScale (Tralalero / Bombardino omit it and stay at full size).
	COMPACT_MODEL_SCALE = 0.7,
}

-- Seconds before the same Brainrot id can be planted again (cost-scaled).
function BrainrotConfig.plantCooldownFor(definition: { cost: number, plantCooldown: number? }): number
	if DevConfig.isActive() and DevConfig.ZERO_PLANT_COOLDOWNS then
		return 0
	end
	local override = definition.plantCooldown
	if type(override) == "number" and override >= 0 then
		return override
	end
	local span = BrainrotConfig.PLANT_COOLDOWN_COST_MAX - BrainrotConfig.PLANT_COOLDOWN_COST_MIN
	local t = if span > 0
		then math.clamp((definition.cost - BrainrotConfig.PLANT_COOLDOWN_COST_MIN) / span, 0, 1)
		else 0
	return BrainrotConfig.PLANT_COOLDOWN_MIN
		+ t * (BrainrotConfig.PLANT_COOLDOWN_MAX - BrainrotConfig.PLANT_COOLDOWN_MIN)
end

table.freeze(BrainrotConfig)

return BrainrotConfig
