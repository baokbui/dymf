--!strict
--[[
	Config
	Aggregates all balancing/configuration sub-modules into a single entry
	point. Require this for convenient access, e.g.:

		local Config = require(ReplicatedStorage.Shared.Config)
		print(Config.Grid.ROWS)

	Brainrot and Zombie stat definitions live in their own registries
	(Shared.Brainrots / Shared.Zombies) since they are data collections.
]]

local Config = {
	Grid = require(script.GridConfig),
	Economy = require(script.EconomyConfig),
	Wave = require(script.WaveConfig),
}

table.freeze(Config)

return Config
