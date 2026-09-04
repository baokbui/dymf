--!strict
--[[
	MagnetConfig
	Player magnet ability: pull nearby ground coins, then cooldown.
	Level 1–5 shortens cooldown; duration stays fixed. Tune here, never inline.
]]

local MagnetConfig = {
	ID = "Magnet",
	MAX_LEVEL = 5,
	DEFAULT_LEVEL = 1,

	-- Active window before cooldown starts.
	DURATION = 5,

	-- Cooldown after the active window (level 1 → max level, linear).
	COOLDOWN_LEVEL_1 = 45,
	COOLDOWN_LEVEL_MAX = 10,

	-- Chebyshev distance 1: one tile left / right / up / down / diagonal.
	RANGE_TILES = 1,

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

function MagnetConfig.formatSeconds(seconds: number): string
	local rounded = math.floor(seconds * 10 + 0.5) / 10
	if rounded == math.floor(rounded) then
		return string.format("%ds", rounded)
	end
	return string.format("%.1fs", rounded)
end

table.freeze(MagnetConfig)

return MagnetConfig
