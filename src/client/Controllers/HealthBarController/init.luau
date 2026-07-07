--!strict
--[[
	HealthBarController
	Client-only health bars for Brainrots and Monsters on the local player's plot.
	Reads Health / MaxHealth attributes (server-authoritative); never computes
	gameplay values.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CombatConfig = require(Shared.Config.CombatConfig)
local Constants = require(Shared.Constants)
local Logger = require(Shared.Utilities.Logger)

local HealthBarController = {}
HealthBarController.Name = "HealthBarController"

local log = Logger.new(HealthBarController.Name)

local localPlayer = Players.LocalPlayer
local attached: { [Model]: BillboardGui } = {}

local function getLocalPlotModel(): Model?
	local userId = localPlayer.UserId
	local plotsFolder = workspace:FindFirstChild(Constants.WORKSPACE_FOLDERS.Plots)
	if not plotsFolder then
		return nil
	end
	for _, child in plotsFolder:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("OwnerUserId") == userId then
			return child
		end
	end
	return nil
end

local function isOnLocalPlot(model: Model): boolean
	local plot = getLocalPlotModel()
	if not plot then
		return false
	end
	return model:IsDescendantOf(plot)
end

local function updateFill(model: Model, fill: Frame)
	local health = model:GetAttribute("Health")
	local maxHealth = model:GetAttribute("MaxHealth")
	if type(health) ~= "number" or type(maxHealth) ~= "number" or maxHealth <= 0 then
		return
	end
	local ratio = math.clamp(health / maxHealth, 0, 1)
	fill.Size = UDim2.fromScale(ratio, 1)
	fill.BackgroundColor3 = if ratio <= 0.3 then CombatConfig.HEALTH_BAR_FILL_LOW else CombatConfig.HEALTH_BAR_FILL
end

local function attachHealthBar(model: Model)
	if attached[model] or not isOnLocalPlot(model) then
		return
	end

	local body = model:FindFirstChild("Body")
	if not body or not body:IsA("BasePart") then
		return
	end

	local isBoss = model:GetAttribute("IsBoss") == true
	local width = if isBoss then CombatConfig.HEALTH_BAR_BOSS_WIDTH else CombatConfig.HEALTH_BAR_WIDTH

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthBar"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(width, CombatConfig.HEALTH_BAR_HEIGHT)
	billboard.StudsOffset = Vector3.new(0, body.Size.Y / 2 + CombatConfig.HEALTH_BAR_OFFSET_Y, 0)
	billboard.Parent = body

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = CombatConfig.HEALTH_BAR_BG
	background.BorderSizePixel = 0
	background.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = background

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = CombatConfig.HEALTH_BAR_FILL
	fill.BorderSizePixel = 0
	fill.Parent = background

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 3)
	fillCorner.Parent = fill

	updateFill(model, fill)
	model:GetAttributeChangedSignal("Health"):Connect(function()
		updateFill(model, fill)
	end)
	model:GetAttributeChangedSignal("MaxHealth"):Connect(function()
		updateFill(model, fill)
	end)

	attached[model] = billboard
	model.Destroying:Connect(function()
		attached[model] = nil
	end)
end

local function tryAttach(model: Instance)
	if model:IsA("Model") then
		attachHealthBar(model)
	end
end

function HealthBarController.init()
end

function HealthBarController.start()
	for _, tag in { Constants.TAGS.Brainrot, Constants.TAGS.Monster } do
		for _, instance in CollectionService:GetTagged(tag) do
			tryAttach(instance)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(tryAttach)
	end

	log:info("started")
end

return HealthBarController
