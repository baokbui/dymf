--!strict
--[[
	HealthBarController
	Client-only health bars (+ Brainrot name tags) for units on the local
	player's plot. Reads Health / MaxHealth / BrainrotId attributes
	(server-authoritative); never computes gameplay values.

	Name + bar live in a single BillboardGui stacked with a UIListLayout so the
	name always sits directly above the bar regardless of camera distance
	(two separate billboards drift apart because StudsOffset and pixel Size
	scale differently with distance).

	Cartoon "for kids" look: thick rounded outline, bold outlined text — shares
	tokens with Shared.Config.UITheme so it matches the rest of the HUD.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CombatConfig = require(Shared.Config.CombatConfig)
local Constants = require(Shared.Constants)
local Brainrots = require(Shared.Brainrots)
local UITheme = require(Shared.Config.UITheme)
local Logger = require(Shared.Utilities.Logger)

local HealthBarController = {}
HealthBarController.Name = "HealthBarController"

local log = Logger.new(HealthBarController.Name)

local localPlayer = Players.LocalPlayer
local attached: { [Model]: true } = {}

local NAME_HEIGHT = 16
local STACK_GAP = 2
local BILLBOARD_WIDTH = 120

-- Ownership is checked via the replicated attribute rather than workspace
-- ancestry: identity attributes (incl. OwnerUserId) are set before the model
-- is parented, so ancestry would race the tag-added signal on live placement.
local function isOnLocalPlot(model: Model): boolean
	return model:GetAttribute("OwnerUserId") == localPlayer.UserId
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

local function attachHealthBar(model: Model): boolean
	if attached[model] then
		return true
	end

	local body = model:FindFirstChild("Body")
	if not body or not body:IsA("BasePart") then
		return false
	end
	if not isOnLocalPlot(model) then
		return false
	end

	attached[model] = true

	local isBoss = model:GetAttribute("IsBoss") == true
	local barWidth = if isBoss then CombatConfig.HEALTH_BAR_BOSS_WIDTH else CombatConfig.HEALTH_BAR_WIDTH
	local barHeight = CombatConfig.HEALTH_BAR_HEIGHT

	local showName = CollectionService:HasTag(model, Constants.TAGS.Brainrot)
	local brainrotName: string? = nil
	if showName then
		local brainrotId = model:GetAttribute("BrainrotId")
		local definition = if type(brainrotId) == "string" then Brainrots.get(brainrotId) else nil
		brainrotName = if definition then definition.name else nil
	end
	showName = brainrotName ~= nil

	local totalHeight = barHeight + if showName then NAME_HEIGHT + STACK_GAP else 0

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "UnitLabel"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(BILLBOARD_WIDTH, totalHeight)
	billboard.StudsOffset = Vector3.new(0, body.Size.Y / 2 + CombatConfig.HEALTH_BAR_OFFSET_Y, 0)
	billboard.Parent = body

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, STACK_GAP)
	layout.Parent = billboard

	if showName and brainrotName then
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "Name"
		nameLabel.LayoutOrder = 1
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size = UDim2.new(1, 0, 0, NAME_HEIGHT)
		nameLabel.Text = brainrotName
		nameLabel.TextScaled = true
		nameLabel.Font = Enum.Font.FredokaOne
		nameLabel.TextColor3 = UITheme.TITLE
		nameLabel.TextStrokeColor3 = UITheme.OUTLINE
		nameLabel.TextStrokeTransparency = 0
		nameLabel.Parent = billboard

		local sizeConstraint = Instance.new("UITextSizeConstraint")
		sizeConstraint.MaxTextSize = 13
		sizeConstraint.Parent = nameLabel
	end

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.LayoutOrder = 2
	background.Size = UDim2.fromOffset(barWidth, barHeight)
	background.BackgroundColor3 = CombatConfig.HEALTH_BAR_BG
	background.BorderSizePixel = 0
	background.Parent = billboard
	UITheme.styleCorner(background, 5)
	UITheme.applyStroke(background, 2)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = CombatConfig.HEALTH_BAR_FILL
	fill.BorderSizePixel = 0
	fill.Parent = background
	UITheme.styleCorner(fill, 4)

	updateFill(model, fill)
	model:GetAttributeChangedSignal("Health"):Connect(function()
		updateFill(model, fill)
	end)
	model:GetAttributeChangedSignal("MaxHealth"):Connect(function()
		updateFill(model, fill)
	end)

	model.Destroying:Connect(function()
		attached[model] = nil
	end)
	return true
end

local function tryAttach(model: Instance)
	if not model:IsA("Model") then
		return
	end
	if attachHealthBar(model) then
		return
	end
	-- The tag can be added before the model finishes building/parenting
	-- (Body child + Parent can land after AddTag) — retry as it settles.
	local ancestryConn: RBXScriptConnection
	local childConn: RBXScriptConnection
	local function retry()
		if attached[model] or attachHealthBar(model) then
			ancestryConn:Disconnect()
			childConn:Disconnect()
		end
	end
	ancestryConn = model.AncestryChanged:Connect(retry)
	childConn = model.ChildAdded:Connect(retry)
	model.Destroying:Connect(function()
		ancestryConn:Disconnect()
		childConn:Disconnect()
	end)
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
