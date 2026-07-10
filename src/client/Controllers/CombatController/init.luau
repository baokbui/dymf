--!strict
--[[
	CombatController
	Client-side combat visuals pushed by the server (CombatVisual remote).
	Gameplay stays server-side; this only renders feedback on the local plot.

	Milestone 11 — projectiles, explosions, hit/death particles.
]]

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CombatConfig = require(Shared.Config.CombatConfig)
local Constants = require(Shared.Constants)
local Remotes = require(Shared.Remotes)
local Logger = require(Shared.Utilities.Logger)

local PlotUtil = require(script.Parent.Parent.Utilities.PlotUtil)
local VfxUtil = require(script.Parent.Parent.Utilities.VfxUtil)

local CombatController = {}
CombatController.Name = "CombatController"

local log = Logger.new(CombatController.Name)

local projectileWatchConnected = false

local function findModelByInstanceId(instanceId: string): Model?
	local plotModel = PlotUtil.getLocalPlotModel()
	if plotModel then
		for _, folderName in { "Monsters", "Brainrots" } do
			local folder = plotModel:FindFirstChild(folderName)
			if folder then
				for _, child in folder:GetChildren() do
					if child:IsA("Model") and child:GetAttribute("InstanceId") == instanceId then
						return child
					end
				end
			end
		end
	end

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

	local center = PlotUtil.getModelBodyCenter(model)
	if center then
		VfxUtil.playHitBurst(center)
	end
end

local function playDeathFade(instanceId: string?)
	if not instanceId then
		return
	end
	local model = findModelByInstanceId(instanceId)
	if not model then
		return
	end

	local center = PlotUtil.getModelBodyCenter(model)
	if center then
		VfxUtil.playDeathBurst(center)
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

local function playExplosion(row: number?, column: number?)
	if type(row) ~= "number" or type(column) ~= "number" then
		return
	end
	local plotModel = PlotUtil.getLocalPlotModel()
	if not plotModel then
		return
	end
	local position = PlotUtil.getTileTopCenter(plotModel, row, column)
	if position then
		VfxUtil.playExplosion(position)
	end
end

local function watchProjectile(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	VfxUtil.decorateProjectile(part)
end

local function ensureProjectileWatcher()
	if projectileWatchConnected then
		return
	end
	local plotModel = PlotUtil.getLocalPlotModel()
	if not plotModel then
		return
	end

	local folder = plotModel:FindFirstChild("Projectiles")
	if not folder then
		folder = plotModel:WaitForChild("Projectiles", 5)
	end
	if not folder then
		return
	end

	projectileWatchConnected = true
	for _, child in folder:GetChildren() do
		watchProjectile(child)
	end
	folder.ChildAdded:Connect(watchProjectile)
end

local function onCombatVisual(payload: unknown)
	ensureProjectileWatcher()

	if type(payload) ~= "table" then
		return
	end
	local data = payload :: { [string]: any }
	local kind = data.kind
	if kind == "Hit" then
		flashHit(data.instanceId)
	elseif kind == "Death" then
		playDeathFade(data.instanceId)
	elseif kind == "Explosion" then
		playExplosion(data.row, data.column)
	end
end

function CombatController.init()
end

function CombatController.start()
	Remotes.getEvent("CombatVisual").OnClientEvent:Connect(onCombatVisual)

	task.spawn(function()
		for _ = 1, 20 do
			ensureProjectileWatcher()
			if projectileWatchConnected then
				break
			end
			task.wait(0.5)
		end
	end)

	log:info("started")
end

return CombatController
