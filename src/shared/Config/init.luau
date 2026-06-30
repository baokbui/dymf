--!strict
--[[
	Config
	Aggregates all balancing/configuration sub-modules into a single entry
	point. Require this for convenient access, e.g.:

		local Config = require(ReplicatedStorage.Shared.Config)
		print(Config.Grid.ROWS)

	Brainrot and Monster stat definitions live in their own registries
	(Shared.Brainrots / Shared.Monsters) since they are data collections.
]]

local Config = {
	Grid = require(script.GridConfig),
	Economy = require(script.EconomyConfig),
	Wave = require(script.WaveConfig),
	Plot = require(script.PlotConfig),
}

table.freeze(Config)

return Config
