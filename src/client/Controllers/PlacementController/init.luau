--!strict
--[[
	PlacementController
	Owns the client-side placement experience: selection, ghost/preview, tile
	highlighting, and sending placement requests. The server (BrainrotService)
	validates and is the source of truth — the preview is purely cosmetic.

	Milestone 4. Stub: lifecycle only, no behavior yet.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)

local PlacementController = {}
PlacementController.Name = "PlacementController"

local log = Logger.new(PlacementController.Name)

function PlacementController.init()
end

function PlacementController.start()
	log:info("started (stub)")
end

return PlacementController
