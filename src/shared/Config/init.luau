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
	Progress = require(script.ProgressConfig),
	Dev = require(script.DevConfig),
	Evolution = require(script.EvolutionConfig),
	Vfx = require(script.VfxConfig),
	Audio = require(script.AudioConfig),
	UI = require(script.UITheme),
	Weather = require(script.WeatherConfig),
	Grave = require(script.GraveConfig),
	House = require(script.HouseConfig),
	Store = require(script.StoreConfig),
	Magnet = require(script.MagnetConfig),
	Retention = require(script.RetentionConfig),
	Save = require(script.SaveConfig),
}

table.freeze(Config)

return Config
