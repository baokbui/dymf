--!strict
--[[
	MagnetConfig
	Player magnet ability: pull nearby ground coins, then cooldown.
	Level 1–5 shortens cooldown and grows pull range; duration stays fixed.
	Tune here, never inline.
]]

local MagnetConfig = {
	ID = "Magnet",
	MAX_LEVEL = 5,
	DEFAULT_LEVEL = 1,

	-- Active window before cooldown starts.
	DURATION = 5,

	-- Cooldown after the active window (level 1 → max level, linear).
	COOLDOWN_LEVEL_1 = 90,
	COOLDOWN_LEVEL_MAX = 20,

	-- World Chebyshev pull, in tiles from the player. Level 1 starts at
	-- RANGE_TILES + RANGE_PER_LEVEL; each extra level adds RANGE_PER_LEVEL
	-- so max level reaches RANGE_TILES_MAX (2 tiles from the user).
	RANGE_TILES = 1,
	RANGE_PER_LEVEL = 1 / 5,
	RANGE_TILES_MAX = 2,

	PULL_DURATION = 0.35,
	TICK = 0.1,

	HOTKEY_LABEL = "1",
}

function MagnetConfig.cooldownFor(level: number): number
	local maxLevel = MagnetConfig.MAX_LEVEL
	local clamped = math.clamp(math.floor(level), MagnetConfig.DEFAULT_LEVEL, maxLevel)
	if maxLevel <= MagnetConfig.DEFAULT_LEVEL then
		return MagnetConfig.COOLDOWN_LEVEL_1
	end
	local alpha = (clamped - MagnetConfig.DEFAULT_LEVEL) / (maxLevel - MagnetConfig.DEFAULT_LEVEL)
	return MagnetConfig.COOLDOWN_LEVEL_1
		+ (MagnetConfig.COOLDOWN_LEVEL_MAX - MagnetConfig.COOLDOWN_LEVEL_1) * alpha
end

function MagnetConfig.rangeTilesFor(level: number): number
	local clamped = math.clamp(math.floor(level), MagnetConfig.DEFAULT_LEVEL, MagnetConfig.MAX_LEVEL)
	return math.min(
		MagnetConfig.RANGE_TILES_MAX,
		MagnetConfig.RANGE_TILES + clamped * MagnetConfig.RANGE_PER_LEVEL
	)
end

function MagnetConfig.formatSeconds(seconds: number): string
	local rounded = math.floor(seconds * 10 + 0.5) / 10
	if rounded == math.floor(rounded) then
		return string.format("%ds", rounded)
	end
	return string.format("%.1fs", rounded)
end

function MagnetConfig.formatTiles(tiles: number): string
	local rounded = math.floor(tiles * 10 + 0.5) / 10
	if rounded == math.floor(rounded) then
		return string.format("%g tiles", rounded)
	end
	return string.format("%.1f tiles", rounded)
end

table.freeze(MagnetConfig)

return MagnetConfig
