--!strict
--[[
	BrainrotController
	Client feedback for BrainrotAction: ability SFX and local attack pulse.
	Gameplay stays on the server.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local BrainrotConfig = require(Shared.Config.BrainrotConfig)
local Brainrots = require(Shared.Brainrots)
local Constants = require(Shared.Constants)
local Remotes = require(Shared.Remotes)
local Logger = require(Shared.Utilities.Logger)

local AudioController = require(script.Parent.AudioController)

local BrainrotController = {}
BrainrotController.Name = "BrainrotController"

local log = Logger.new(BrainrotController.Name)

local baseScales: { [Model]: number } = {}
local pulseTokens: { [Model]: number } = {}

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
	local token = (pulseTokens[model] or 0) + 1
	pulseTokens[model] = token

	local base = baseScales[model]
	if not base then
		base = model:GetScale()
		baseScales[model] = base
	else
		model:ScaleTo(base)
	end

	model:ScaleTo(base * BrainrotConfig.ATTACK_PULSE_SCALE)
	local half = BrainrotConfig.ATTACK_PULSE_DURATION / 2
	task.delay(half, function()
		if pulseTokens[model] ~= token or not model.Parent then
			return
		end
		model:ScaleTo(base)
		task.delay(half, function()
			if pulseTokens[model] == token then
				pulseTokens[model] = nil
			end
		end)
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
		-- Animated units (Tung Tung) use their swing clip; skip the ScaleTo pulse.
		local brainrotId = data.brainrotId
		if type(brainrotId) == "string" then
			local definition = Brainrots.get(brainrotId)
			if definition and definition.animated then
				return
			end
		end
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
	require(script.Nameplate).start()
	log:info("started")
end

return BrainrotController
