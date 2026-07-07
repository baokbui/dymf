--!strict
--[[
	CombatController
	Client-side combat visuals pushed by the server (CombatVisual remote).
	Gameplay stays server-side; this only renders feedback on the local plot.
]]

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CombatConfig = require(Shared.Config.CombatConfig)
local Constants = require(Shared.Constants)
local Remotes = require(Shared.Remotes)
local Logger = require(Shared.Utilities.Logger)

local CombatController = {}
CombatController.Name = "CombatController"

local log = Logger.new(CombatController.Name)

local function findModelByInstanceId(instanceId: string): Model?
	for _, tag in { Constants.TAGS.Brainrot, Constants.TAGS.Monster } do
		for _, model in CollectionService:GetTagged(tag) do
			if model:IsA("Model") and model:GetAttribute("InstanceId") == instanceId then
				return model
			end
		end
	end
	return nil
end

local function flashHit(instanceId: string?)
	if not instanceId then
		return
	end
	local model = findModelByInstanceId(instanceId)
	if not model then
		return
	end
	local body = model:FindFirstChild("Body")
	if not body or not body:IsA("BasePart") then
		return
	end
	local original = body.Color
	body.Color = Color3.fromRGB(255, 120, 120)
	task.delay(0.08, function()
		if body.Parent then
			body.Color = original
		end
	end)
end

local function playDeathFade(instanceId: string?)
	if not instanceId then
		return
	end
	local model = findModelByInstanceId(instanceId)
	if not model then
		return
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			TweenService:Create(
				descendant,
				TweenInfo.new(CombatConfig.DEATH_FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Transparency = 1, Size = descendant.Size * 0.2 }
			):Play()
		end
	end
end

local function onCombatVisual(payload: unknown)
	if type(payload) ~= "table" then
		return
	end
	local data = payload :: { [string]: any }
	local kind = data.kind
	if kind == "Hit" then
		flashHit(data.instanceId)
	elseif kind == "Death" then
		playDeathFade(data.instanceId)
	end
end

function CombatController.init()
end

function CombatController.start()
	Remotes.getEvent("CombatVisual").OnClientEvent:Connect(onCombatVisual)
	log:info("started")
end

return CombatController
