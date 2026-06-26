--!strict
--[[
	PlotService
	Owns player battlefields (plots): assignment, ownership, cleanup, barriers,
	spawn locations, and camera anchor points.

	Milestone 1. Stub: lifecycle only, no behavior yet.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)

local PlotService = {}
PlotService.Name = "PlotService"

local log = Logger.new(PlotService.Name)

-- One-time setup. Runs before any service is started. Do not depend on other
-- services being started here.
function PlotService.init()
end

-- Begin runtime behavior (connect events, etc.). All services are init'd first.
function PlotService.start()
	log:info("started (stub)")
end

return PlotService
