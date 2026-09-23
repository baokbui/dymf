--!strict
--[[
	MonsterNameplate
	Compact BillboardGui above each monster: species name and campaign level.
	Display-only; level replicates as MonsterLevel (the current day).
	The level line shows on VFX High only. Low and Off keep the name.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monsters = require(Shared.Monsters)
local UITheme = require(Shared.Config.UITheme)
local Constants = require(Shared.Constants)
local VfxLoad = require(Shared.Utilities.VfxLoad)

local MonsterNameplate = {}

local HOST_NAME = "MonsterNameplates"
local GUI_NAME = "Nameplate"
local MIN_WIDTH = 120
local MAX_DISTANCE = 48
local NAME_SIZE = 14
local LEVEL_SIZE = 11
local NAME_LINE = NAME_SIZE + 2
local LEVEL_LINE = LEVEL_SIZE + 2
local FULL_HEIGHT = NAME_LINE + LEVEL_LINE
local NAME_HEIGHT = NAME_LINE + 4
local HEADROOM = 1.05
local NAME_PAD_X = 14

type Plate = {
	gui: BillboardGui,
	nameLabel: TextLabel,
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

local function makeLine(parent: Instance, order: number, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, size + 2)
	label.LayoutOrder = order
	label.TextSize = size
	label.TextWrapped = false
	label.TextTruncate = Enum.TextTruncate.None
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
	local y = math.clamp((topY - adornee.Position.Y) + HEADROOM, 2.0, 18.0)
	return Vector3.new(0, y, 0)
end

local function refresh(model: Model, plate: Plate)
	local monsterId = model:GetAttribute("MonsterId")
	local definition = if type(monsterId) == "string" then Monsters.get(monsterId) else nil
	plate.nameLabel.Text = if definition then definition.name else "Monster"

	local level = model:GetAttribute("MonsterLevel")
	if type(level) ~= "number" then
		level = 1
	end
	plate.levelLabel.Text = string.format("Lv. %d", math.max(1, math.floor(level)))
	local showLevel = VfxLoad.isHighQuality()
	plate.levelLabel.Visible = showLevel
	plate.levelLabel.Size = UDim2.new(1, 0, 0, if showLevel then LEVEL_LINE else 0)
	local bounds = TextService:GetTextSize(
		plate.nameLabel.Text,
		NAME_SIZE,
		Enum.Font.GothamBold,
		Vector2.new(400, NAME_SIZE + 8)
	)
	local height = if showLevel then FULL_HEIGHT else NAME_HEIGHT
	plate.gui.Size = UDim2.fromOffset(math.max(MIN_WIDTH, math.ceil(bounds.X) + NAME_PAD_X), height)
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
	gui.Size = UDim2.fromOffset(MIN_WIDTH, FULL_HEIGHT)
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

	local nameLabel = makeLine(gui, 1, NAME_SIZE)
	local levelLabel = makeLine(gui, 2, LEVEL_SIZE)

	local connections: { RBXScriptConnection } = {}
	table.insert(connections, model:GetAttributeChangedSignal("MonsterLevel"):Connect(function()
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
		levelLabel = levelLabel,
		connections = connections,
	}
	plates[model] = plate
	refresh(model, plate)
end

function MonsterNameplate.start()
	getHost()
	local tag = Constants.TAGS.Monster
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
	VfxLoad.onChanged(function()
		for model, plate in plates do
			refresh(model, plate)
		end
	end)
end

return MonsterNameplate
