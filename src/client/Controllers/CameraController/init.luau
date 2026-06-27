--!strict
--[[
	CameraController
	The game intentionally uses Roblox's default third-person camera (mouse
	scroll zooms all the way into first person), so this controller does not
	override the camera.

	It is the designated home for client-side camera juice added later
	(e.g. combat shake in Milestone 13), layered on top of the default camera.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.Utilities.Logger)

local CameraController = {}
CameraController.Name = "CameraController"

local log = Logger.new(CameraController.Name)

function CameraController.init()
end

function CameraController.start()
	log:info("started (default camera)")
end

return CameraController
