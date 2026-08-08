--!strict
--[[
	Utilities
	Aggregates shared, reusable helper modules. Require this for convenient
	access, e.g. require(ReplicatedStorage.Shared.Utilities).Logger.new("Foo").
]]

local Utilities = {
	Logger = require(script.Logger),
	GridUtil = require(script.GridUtil),
	ModelUtil = require(script.ModelUtil),
	WeatherUtil = require(script.WeatherUtil),
	CollisionUtil = require(script.CollisionUtil),
}

table.freeze(Utilities)

return Utilities
