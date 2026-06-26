--!strict
--[[
	BrainrotService
	Owns Brainrot placement, instance lifecycle, and per-instance state on a
	plot. Reads definitions from the data-driven Shared.Brainrots registry;
	never branches on Brainrot names directly.

	Milestones 4-5. Stub: lifecycle only, no behavior yet.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)

local BrainrotService = {}
BrainrotService.Name = "BrainrotService"

local log = Logger.new(BrainrotService.Name)

function BrainrotService.init()
end

function BrainrotService.start()
	log:info("started (stub)")
end

return BrainrotService
