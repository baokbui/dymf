--!strict
--[[
	CameraController
	Owns the player's camera: positioning it over the assigned plot and any
	combat juice (shake, etc.). Purely client-side presentation.

	Milestone 1 (positioning), Milestone 13 (shake). Stub: lifecycle only.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)

local CameraController = {}
CameraController.Name = "CameraController"

local log = Logger.new(CameraController.Name)

function CameraController.init()
end

function CameraController.start()
	log:info("started (stub)")
end

return CameraController
