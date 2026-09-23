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
	-- Extra local Euler after the baked upright stand, before +Z cartwheel.
	-- Stand is measured per mesh (thinnest axis across the row so the sharp
	-- rim leads down the lane).
	SHURIKEN_MODEL_ORIENTATION_DEGREES = Vector3.new(0, 0, 0),
	SHURIKEN_BLADE_SIZE = Vector3.new(2.2, 0.14, 2.2), -- procedural fallback span × thickness
	SHURIKEN_HUB_SIZE = Vector3.new(0.55, 0.18, 0.55),
	SHURIKEN_BLADE_COLOR = Color3.fromRGB(210, 215, 225),
	SHURIKEN_HUB_COLOR = Color3.fromRGB(60, 60, 68),
	SHURIKEN_SPIN_RADIANS_PER_SECOND = math.pi * 14, -- 7 turns/sec vertical cartwheel
	SHURIKEN_PROJECTILE_HEIGHT_OFFSET = 3.2,

	-- Tralalero bubble projectile (cyan soap bubble; no trail streaks).
	BUBBLE_PROJECTILE_SIZE = Vector3.new(2.6, 2.6, 2.6),
	BUBBLE_PROJECTILE_SEED_SIZE = Vector3.new(3.5, 3.5, 3.5),
	BUBBLE_PROJECTILE_TRANSPARENCY = 0.22,
	-- Bubble Barrage: one seed flies this far, then splits into 5 lane bubbles.
	BUBBLE_BARRAGE_SPLIT_TILES = 1.15,
	-- Child bubbles ease Z from the split point into each lawn row.
	BUBBLE_BARRAGE_Z_LERP_TILES = 1.7,
	-- Crowd control vs laneSpan. Each extra row past 1 resists 25%
	-- (2 → 25%, 3 → 50%, 4 → 75%, 5+ → immune). Damage is not reduced.
	TRALALERO_CC_RESIST_PER_EXTRA_ROW = 0.25,

	-- Ranged Rampage (Tung Tung Legendary): spinning bat from the left hand.
	-- Prefer Assets.Projectiles[BAT_MODEL_ID]; procedural club is the fallback.
	BAT_MODEL_ID = "Tung Bat",
	BAT_TARGET_EXTENT = 3.8, -- max axis after clone ScaleTo
	-- Local Euler applied each frame before +Z tumble (tune if the mesh faces wrong).
	BAT_MODEL_ORIENTATION_DEGREES = Vector3.new(0, 0, 0),
	BAT_SPIN_RADIANS_PER_SECOND = math.pi * 8, -- 4 turns/sec end-over-end
	BAT_KNOCKBACK_TILES = 0.25, -- east push on a connecting hit (on-plot only)
	BAT_FALLBACK_HANDLE_SIZE = Vector3.new(2.6, 0.22, 0.22),
	BAT_FALLBACK_HEAD_SIZE = Vector3.new(0.9, 0.48, 0.48),
	BAT_FALLBACK_HANDLE_COLOR = Color3.fromRGB(139, 90, 43),
	BAT_FALLBACK_HEAD_COLOR = Color3.fromRGB(90, 55, 28),

	-- Tenfold Guard: small authored shield that orbits Tung.
	SHIELD_MODEL_ID = "Shield",
	SHIELD_ORBIT_ORIENTATION_DEGREES = Vector3.new(0, 0, 0),

	-- Primal Retaliation: small authored mirror that orbits Chimpanzini.
	MIRROR_MODEL_ID = "Mirror",
	MIRROR_ORBIT_ORIENTATION_DEGREES = Vector3.new(0, 0, 0),

	-- Sahur's Wrath (Tung Tung GOD): bat grows vertically above the plant to
	-- the lane length, then the melee swing arcs it onto the row (covers Tung →
	-- east plot edge).
	WRATH_HOVER_OFFSET = 0.6, -- studs above the plant's visual top (pivot)
	WRATH_FRONT_GAP = 0.8, -- studs east of the plant center
	WRATH_WIDTH_SCALE = 12, -- X/Z fatten while upright (club, not a noodle)
	WRATH_EXPAND_DURATION = 0.55,
	WRATH_SLAM_DURATION = 1.2, -- fallback if attackHitDelay is missing
	WRATH_SLAM_HEIGHT = 2.4, -- studs above tile top at impact (pivot)
	WRATH_LINGER = 0.28,
	-- East end of the landed bat, in fractional columns (COLUMNS + this).
	WRATH_EAST_EDGE = 0.5,
	-- Ult only fires if the row has this many combat targets, or a boss.
	WRATH_MIN_ENEMIES = 3,
	-- Adjacent rows (left/right lanes) take this % of current bat damage.
	WRATH_SPLASH_PERCENT = 500,
	WRATH_SPLASH_ROWS = 1,

	-- Shadow Requiem (Cappuccino GOD): one vertical ")" crescent, sized like
	-- the old dual slash. White fill, black outline + black streaks. Width
	-- stays large; height grows with travel. Stop on the last lawn tile,
	-- then explode into a white light pillar that expands to one tile and
	-- fades over ~3s.
	-- Pierce every monster and grave for 2000%, plus 100% more of current
	-- knife damage per tile past the first. Last-tile pillar finisher is a
	-- flat extra 1000% (not ramped). Needs 3+ enemies or a boss; easternmost
	-- ready Cappuccino fires first.
	SWORD_WAVE_MIN_ENEMIES = 3,
	SWORD_WAVE_GROW_COLUMNS = 3, -- tiles of travel to reach full height
	SWORD_WAVE_FADE_COLUMNS = 0, -- 0 = stay solid until the last-tile pillar
	SWORD_WAVE_EAST_EDGE = 0, -- 0 = last lawn tile center (COLUMNS + this)
	SWORD_WAVE_PILLAR_HOLD = 0.08, -- seconds the waves sit on the last tile
	SWORD_WAVE_PILLAR_EXPAND = 0.5, -- seconds to grow to one tile wide
	SWORD_WAVE_PILLAR_FADE = 3, -- seconds the light pillar takes to fade after max size
	SWORD_WAVE_TRANSPARENCY = 0.12,
	SWORD_WAVE_COLUMNS_PER_SECOND = 6.5,
	SWORD_WAVE_PIERCE_COUNT = 64,
	SWORD_WAVE_ANIM_FALLBACK = 1.85, -- seconds if the clip Length is not ready
	SWORD_WAVE_RELEASE_LEAD = 0.04, -- fire this many seconds before clip end
	SWORD_WAVE_SOUND_LEAD = 1, -- crescent whoosh this many seconds before the wave launches
	SWORD_WAVE_FALLBACK_EAST = 1.1,
	SWORD_WAVE_FALLBACK_UP = 0.85,

	-- Piercing Brew (Cappuccino Legendary): window of piercing knives.
	PIERCE_BREW_DURATION = 6,

	-- Jackpot (Ballerina GOD): 3× coin interval for duration; extra spit chance.
	JACKPOT_DURATION = 10,
	JACKPOT_FACTOR = 3,
	JACKPOT_EXTRA_CHANCE = 33,

	-- Primal Retaliation (Chimpanzini GOD): reflect chew HP for duration.
	REFLECT_DURATION = 15,
	REFLECT_PERCENT = 25,

	-- Abyssal Torrent (Tralalero GOD): mouth jet. Each full second in the
	-- stream deals catalog base damage and knocks the monster east by this
	-- many tiles. Needs 3+ enemies or a boss; easternmost ready Tralalero
	-- fires first. Duration and cooldown live on the evolution row.
	TORRENT_MIN_ENEMIES = 3,
	TORRENT_KNOCKBACK_TILES = 0.25,

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

	-- Per-day damage meter HUD (right rail). Server ranks species by HP dealt.
	-- TOP = max rows sent; VISIBLE_ROWS = max expanded viewport (panel shrinks
	-- to fewer ranked rows; scrolls past this).
	DAMAGE_METER_TOP = 20,
	DAMAGE_METER_VISIBLE_ROWS = 5,
	DAMAGE_METER_BROADCAST_INTERVAL = 0.4,

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
