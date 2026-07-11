--!strict
--[[
	BrainrotController
	Client feedback for BrainrotAction: ability SFX and local attack pulse.
	Gameplay stays on the server.
]]

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local BrainrotConfig = require(Shared.Config.BrainrotConfig)
local Constants = require(Shared.Constants)
local Remotes = require(Shared.Remotes)
local Logger = require(Shared.Utilities.Logger)

local AudioController = require(script.Parent.AudioController)

local BrainrotController = {}
BrainrotController.Name = "BrainrotController"

local log = Logger.new(BrainrotController.Name)

local activePulseTweens: { [Model]: Tween } = {}

-- Actions that should pulse the Brainrot body on the client (keeps SFX in sync).
local PULSE_ACTIONS: { [string]: boolean } = {
	MeleeBat = true,
}

local function findBrainrotModel(instanceId: string): Model?
	for _, model in CollectionService:GetTagged(Constants.TAGS.Brainrot) do
		if model:IsA("Model") and model:GetAttribute("InstanceId") == instanceId then
			return model
		end
	end
	return nil
end

local function pulseAttack(model: Model)
	local body = model:FindFirstChild("Body")
	if not body or not body:IsA("BasePart") then
		return
	end

	local existing = activePulseTweens[model]
	if existing then
		existing:Cancel()
		activePulseTweens[model] = nil
	end

	local baseSize = body.Size
	local scaled = baseSize * BrainrotConfig.ATTACK_PULSE_SCALE
	local up = TweenService:Create(
		body,
		TweenInfo.new(BrainrotConfig.ATTACK_PULSE_DURATION / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = scaled }
	)
	local down = TweenService:Create(
		body,
		TweenInfo.new(BrainrotConfig.ATTACK_PULSE_DURATION / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Size = baseSize }
	)

	activePulseTweens[model] = up
	up:Play()
	up.Completed:Connect(function()
		if activePulseTweens[model] == up then
			activePulseTweens[model] = down
			down:Play()
		end
	end)
	down.Completed:Connect(function()
		if activePulseTweens[model] == down then
			activePulseTweens[model] = nil
		end
	end)
end

local function onBrainrotAction(payload: unknown)
	if type(payload) ~= "table" then
		return
	end
	local data = payload :: { [string]: any }
	local action = data.action
	if type(action) ~= "string" then
		return
	end

	AudioController.play(action)

	if PULSE_ACTIONS[action] and type(data.instanceId) == "string" then
		local model = findBrainrotModel(data.instanceId)
		if model then
			pulseAttack(model)
		end
	end
end

function BrainrotController.init()
end

function BrainrotController.start()
	Remotes.getEvent("BrainrotAction").OnClientEvent:Connect(onBrainrotAction)
	log:info("started")
end

return BrainrotController
