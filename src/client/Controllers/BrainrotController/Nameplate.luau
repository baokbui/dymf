--!strict
--[[
	Nameplate
	Compact BillboardGui above each planted Brainrot:
	full name / claimed rarity (shine on Epic+) / current Brainrot level.
	Display-only; rarity and level replicate as model attributes.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared.Brainrots)
local EvolutionConfig = require(Shared.Config.EvolutionConfig)
local UITheme = require(Shared.Config.UITheme)
local Constants = require(Shared.Constants)

local TextShine = require(script.Parent.Parent.Parent.Utilities.TextShine)

local Nameplate = {}

local HOST_NAME = "BrainrotNameplates"
local GUI_NAME = "Nameplate"
local MIN_WIDTH = 132
local HEIGHT = 56
local MAX_DISTANCE = 40
local NAME_SIZE = 14
local RARITY_SIZE = 12
local LEVEL_SIZE = 11
local HEADROOM = 1.05
local NAME_PAD_X = 14

type Plate = {
	gui: BillboardGui,
	nameLabel: TextLabel,
	rarityLabel: TextLabel,
	levelLabel: TextLabel,
	connections: { RBXScriptConnection },
}

local plates: { [Model]: Plate } = {}
local host: ScreenGui? = nil

local function getHost(): ScreenGui
	if host and host.Parent then
		return host
	end
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild(HOST_NAME)
	if existing and existing:IsA("ScreenGui") then
		host = existing
		return host
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = HOST_NAME
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui
	host = gui
	return gui
end

local function makeLine(parent: Instance, order: number, size: number, truncate: boolean): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, size + 2)
	label.LayoutOrder = order
	label.TextSize = size
	label.TextWrapped = false
	label.TextTruncate = if truncate then Enum.TextTruncate.AtEnd else Enum.TextTruncate.None
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	UITheme.applyOutlinedTitle(label)
	label.TextSize = size
	return label
end

local function studsOffset(model: Model, adornee: BasePart): Vector3
	local cf, size = model:GetBoundingBox()
	local topY = cf.Position.Y + size.Y * 0.5
	local y = math.clamp((topY - adornee.Position.Y) + HEADROOM, 2.0, 7.0)
	return Vector3.new(0, y, 0)
end

local function refresh(model: Model, plate: Plate)
	local brainrotId = model:GetAttribute("BrainrotId")
	local definition = if type(brainrotId) == "string" then Brainrots.get(brainrotId) else nil
	plate.nameLabel.Text = if definition then definition.name else "Brainrot"

	local rarity = model:GetAttribute("EvolutionRarity")
	if type(rarity) ~= "string" or rarity == "" then
		rarity = "Common"
	end
	plate.rarityLabel.Text = rarity
	TextShine.clear(plate.rarityLabel)
	if rarity == "Common" then
		UITheme.applyOutlinedTitle(plate.rarityLabel, UITheme.TITLE)
		plate.rarityLabel.TextSize = RARITY_SIZE
	else
		local dark = EvolutionConfig.darkText(rarity)
		UITheme.applyOutlinedTitle(plate.rarityLabel, dark)
		plate.rarityLabel.TextSize = RARITY_SIZE
		TextShine.apply(plate.rarityLabel, dark)
	end

	local level = model:GetAttribute("BrainrotLevel")
	if type(level) ~= "number" then
		level = 1
	end
	plate.levelLabel.Text = string.format("Lv. %d", math.max(1, math.floor(level)))
	local bounds = TextService:GetTextSize(
		plate.nameLabel.Text,
		NAME_SIZE,
		Enum.Font.GothamBold,
		Vector2.new(400, NAME_SIZE + 8)
	)
	plate.gui.Size = UDim2.fromOffset(math.max(MIN_WIDTH, math.ceil(bounds.X) + NAME_PAD_X), HEIGHT)
	local adornee = plate.gui.Adornee
	if adornee and adornee:IsA("BasePart") then
		plate.gui.StudsOffset = studsOffset(model, adornee)
	end
end

local function unbind(model: Model)
	local plate = plates[model]
	if not plate then
		return
	end
	for _, connection in plate.connections do
		connection:Disconnect()
	end
	TextShine.clear(plate.rarityLabel)
	if plate.gui.Parent then
		plate.gui:Destroy()
	end
	plates[model] = nil
end

local function bind(model: Model)
	if plates[model] then
		refresh(model, plates[model])
		return
	end
	if not model:IsA("Model") then
		return
	end

	local adornee = model.PrimaryPart
		or model:FindFirstChild("Body", true)
		or model:FindFirstChild("HumanoidRootPart", true)
		or model:FindFirstChildWhichIsA("BasePart", true)
	if not (adornee and adornee:IsA("BasePart")) then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = GUI_NAME
	gui.Adornee = adornee
	gui.Size = UDim2.fromOffset(MIN_WIDTH, HEIGHT)
	gui.StudsOffset = studsOffset(model, adornee)
	gui.AlwaysOnTop = true
	gui.MaxDistance = MAX_DISTANCE
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Parent = getHost()

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 0)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui

	local nameLabel = makeLine(gui, 1, NAME_SIZE, false)
	local rarityLabel = makeLine(gui, 2, RARITY_SIZE, true)
	local levelLabel = makeLine(gui, 3, LEVEL_SIZE, true)
	UITheme.applyOutlinedTitle(levelLabel, UITheme.TITLE)
	levelLabel.TextSize = LEVEL_SIZE

	local connections: { RBXScriptConnection } = {}
	table.insert(connections, model:GetAttributeChangedSignal("EvolutionRarity"):Connect(function()
		local plate = plates[model]
		if plate then
			refresh(model, plate)
		end
	end))
	table.insert(connections, model:GetAttributeChangedSignal("BrainrotLevel"):Connect(function()
		local plate = plates[model]
		if plate then
			refresh(model, plate)
		end
	end))
	table.insert(connections, model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			unbind(model)
		end
	end))

	local plate: Plate = {
		gui = gui,
		nameLabel = nameLabel,
		rarityLabel = rarityLabel,
		levelLabel = levelLabel,
		connections = connections,
	}
	plates[model] = plate
	refresh(model, plate)
end

function Nameplate.start()
	getHost()
	local tag = Constants.TAGS.Brainrot
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("Model") then
			bind(instance)
		end
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		if instance:IsA("Model") then
			task.defer(bind, instance)
		end
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		if instance:IsA("Model") then
			unbind(instance)
		end
	end)
end

return Nameplate
