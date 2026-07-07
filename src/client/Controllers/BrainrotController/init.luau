--!strict
--[[
	BrainrotController
	Plays client-side feedback for Brainrot actions pushed by the server
	(BrainrotAction remote). Gameplay logic stays on the server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage.Shared
local BrainrotConfig = require(Shared.Config.BrainrotConfig)
local Remotes = require(Shared.Remotes)
local Logger = require(Shared.Utilities.Logger)

local BrainrotController = {}
BrainrotController.Name = "BrainrotController"

local log = Logger.new(BrainrotController.Name)

local function playActionSound(action: string)
	local soundId = BrainrotConfig.SOUNDS[action]
	if type(soundId) ~= "number" or soundId <= 0 then
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundId = string.format("rbxassetid://%d", soundId)
	sound.Volume = 0.6
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

local function onBrainrotAction(payload: unknown)
	if type(payload) ~= "table" then
		return
	end
	local action = (payload :: any).action
	if type(action) ~= "string" then
		return
	end
	playActionSound(action)
end

function BrainrotController.init()
end

function BrainrotController.start()
	Remotes.getEvent("BrainrotAction").OnClientEvent:Connect(onBrainrotAction)
	log:info("started")
end

return BrainrotController
