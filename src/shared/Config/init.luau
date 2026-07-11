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
	Level = require(script.LevelConfig),
	Plot = require(script.PlotConfig),
	Brainrot = require(script.BrainrotConfig),
	Monster = require(script.MonsterConfig),
	Combat = require(script.CombatConfig),
	Player = require(script.PlayerConfig),
	Vfx = require(script.VfxConfig),
	Audio = require(script.AudioConfig),
}

table.freeze(Config)

return Config
