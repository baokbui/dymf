--!strict
--[[
	BrainrotController
	Plays client-side feedback for Brainrot actions pushed by the server
	(BrainrotAction remote). Gameplay logic stays on the server; audio is
	routed through AudioController (Milestone 12).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Logger = require(Shared.Utilities.Logger)

local AudioController = require(script.Parent.AudioController)

local BrainrotController = {}
BrainrotController.Name = "BrainrotController"

local log = Logger.new(BrainrotController.Name)

local function onBrainrotAction(payload: unknown)
	if type(payload) ~= "table" then
		return
	end
	local action = (payload :: any).action
	if type(action) ~= "string" then
		return
	end
	AudioController.play(action)
end

function BrainrotController.init()
end

function BrainrotController.start()
	Remotes.getEvent("BrainrotAction").OnClientEvent:Connect(onBrainrotAction)
	log:info("started")
end

return BrainrotController
