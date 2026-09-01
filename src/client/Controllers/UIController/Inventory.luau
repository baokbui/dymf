--!strict
--[[
	Inventory
	Equip / unequip unlocked Brainrots for the placement shop loadout.

	PvZ-style **seed packet** grid: each unlocked Brainrot renders as a packet
	card (portrait + name plate + status ribbon) using the same
	Assets.Brainrots preview as the Shop bar. Equipped packets sit bright /
	selected (like a seed already in the tray); unequipped packets sit dimmed
	with a "Tap to equip" hint. Hovering a packet opens an info tooltip with
	the full stat block. Cartoon thick-outline look via UITheme.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared.Brainrots)
local ProgressConfig = require(Shared.Config.ProgressConfig)
local UITheme = require(Shared.Config.UITheme)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local BrainrotPreview = require(script.Parent.Parent.Parent.Utilities.BrainrotPreview)
local BrainrotInfo = require(script.Parent.Parent.Parent.Utilities.BrainrotInfo)
local AudioController = require(script.Parent.Parent.AudioController)
local UIEvents = require(script.Parent.Parent.Parent.UIEvents)

local Inventory = {}
Inventory.__index = Inventory

local PACKET_WIDTH = 116
local PACKET_HEIGHT = 156
local PACKET_PADDING = 14
local PREVIEW_SIZE = 78
local PLATE_HEIGHT = 30
local RIBBON_HEIGHT = 18

local TOOLTIP_WIDTH = 240
local TOOLTIP_PORTRAIT = 96

type Packet = {
	button: TextButton,
	ribbon: Frame,
	ribbonLabel: TextLabel,
	definition: Types.BrainrotDefinition,
}

export type InventoryPanel = typeof(setmetatable(
	{} :: {
		frame: Frame,
		list: ScrollingFrame,
		unlocks: { string },
		equipped: { string },
		loadoutLocked: boolean,
		packets: { [string]: Packet },
		hint: TextLabel,
		tooltip: Frame,
		tooltipPortraitHolder: Frame,
		tooltipName: TextLabel,
		tooltipStats: Frame,
	},
	Inventory
))

local function sortedUnlocks(unlocks: { string }): { Types.BrainrotDefinition }
	local list: { Types.BrainrotDefinition } = {}
	for _, id in unlocks do
		local def = Brainrots.get(id)
		if def and def.hidden ~= true then
			table.insert(list, def)
		end
	end
	table.sort(list, function(a, b)
		if a.cost ~= b.cost then
			return a.cost < b.cost
		end
		return a.name < b.name
	end)
	return list
end

local function isEquipped(equipped: { string }, id: string): boolean
	for _, value in equipped do
		if value == id then
			return true
		end
	end
	return false
end

-- Builds the floating info tooltip (hidden until a packet is hovered).
-- Parented to the same ScreenGui as the modal so it can float outside the
-- panel bounds and render above it.
local function buildTooltip(screenGui: Instance): (Frame, Frame, TextLabel, Frame)
	local tooltip = Instance.new("Frame")
	tooltip.Name = "BrainrotTooltip"
	tooltip.Size = UDim2.fromOffset(TOOLTIP_WIDTH, 10)
	tooltip.AutomaticSize = Enum.AutomaticSize.Y
	tooltip.BackgroundTransparency = 0
	tooltip.Visible = false
	tooltip.ZIndex = 60
	tooltip.Parent = screenGui
	UITheme.applyPanelLook(tooltip, 12)

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = tooltip

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = tooltip

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, TOOLTIP_PORTRAIT)
	header.LayoutOrder = 1
	header.Parent = tooltip

	local portraitHolder = Instance.new("Frame")
	portraitHolder.Name = "PortraitHolder"
	portraitHolder.AnchorPoint = Vector2.new(0, 0.5)
	portraitHolder.Position = UDim2.new(0, 0, 0.5, 0)
	portraitHolder.Size = UDim2.fromOffset(TOOLTIP_PORTRAIT, TOOLTIP_PORTRAIT)
	portraitHolder.BackgroundColor3 = Color3.fromRGB(235, 245, 255)
	portraitHolder.BackgroundTransparency = 0.15
	portraitHolder.BorderSizePixel = 0
	portraitHolder.Parent = header
	UITheme.styleCorner(portraitHolder, 10)
	UITheme.applyStroke(portraitHolder, 2)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.BackgroundTransparency = 1
	nameLabel.AnchorPoint = Vector2.new(0, 0.5)
	nameLabel.Position = UDim2.new(0, TOOLTIP_PORTRAIT + 10, 0.5, 0)
	nameLabel.Size = UDim2.new(1, -(TOOLTIP_PORTRAIT + 10), 1, 0)
	nameLabel.TextSize = 17
	nameLabel.TextWrapped = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextYAlignment = Enum.TextYAlignment.Center
	nameLabel.Parent = header
	UITheme.applyOutlinedTitle(nameLabel)

	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.BackgroundColor3 = UITheme.OUTLINE
	divider.BorderSizePixel = 0
	divider.Size = UDim2.new(1, 0, 0, 2)
	divider.LayoutOrder = 2
	divider.Parent = tooltip

	local stats = Instance.new("Frame")
	stats.Name = "Stats"
	stats.BackgroundTransparency = 1
	stats.AutomaticSize = Enum.AutomaticSize.Y
	stats.Size = UDim2.new(1, 0, 0, 0)
	stats.LayoutOrder = 3
	stats.Parent = tooltip

	local statsLayout = Instance.new("UIListLayout")
	statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	statsLayout.Padding = UDim.new(0, 3)
	statsLayout.Parent = stats

	return tooltip, portraitHolder, nameLabel, stats
end

function Inventory.new(parent: Frame): InventoryPanel
	parent.Visible = false
	parent.AnchorPoint = Vector2.new(0.5, 0.5)
	parent.Position = UDim2.fromScale(0.5, 0.5)
	parent.Size = UDim2.fromOffset(524, 472)
	parent.ZIndex = 30
	UITheme.applyPanelLook(parent, nil, UITheme.PANEL_BG_INVENTORY)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -80, 0, 32)
	title.Position = UDim2.fromOffset(16, 12)
	title.TextSize = 22
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Brainrots"
	title.Parent = parent
	UITheme.applyOutlinedTitle(title)

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 10)
	close.Size = UDim2.fromOffset(36, 36)
	close.TextSize = 20
	close.Text = "X"
	close.Parent = parent
	UITheme.applyButtonLook(close, UITheme.DANGER)
	UITheme.applyOutlinedTitle(close)

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.BackgroundTransparency = 1
	hint.Size = UDim2.new(1, -32, 0, 18)
	hint.Position = UDim2.fromOffset(16, 48)
	hint.TextSize = 13
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Text = string.format("Equip up to %d for the shop bar — hover a packet for details", ProgressConfig.MAX_EQUIPPED)
	hint.Parent = parent
	UITheme.applyBodyText(hint, UITheme.SUBTEXT)

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(12, 74)
	list.Size = UDim2.new(1, -24, 1, -86)
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.ScrollBarThickness = 6
	list.Parent = parent

	-- ScrollingFrame clips its contents — without inset padding, packets
	-- flush against an edge have their rounded UIStroke corner (drawn half
	-- outside the packet's bounds) chopped off flat.
	local listPad = Instance.new("UIPadding")
	listPad.PaddingTop = UDim.new(0, 6)
	listPad.PaddingLeft = UDim.new(0, 6)
	listPad.PaddingRight = UDim.new(0, 6)
	listPad.PaddingBottom = UDim.new(0, 6)
	listPad.Parent = list

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(PACKET_WIDTH, PACKET_HEIGHT)
	layout.CellPadding = UDim2.fromOffset(PACKET_PADDING, PACKET_PADDING)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.Parent = list

	local screenGui = parent:FindFirstAncestorOfClass("ScreenGui") or parent
	local tooltip, portraitHolder, tooltipName, tooltipStats = buildTooltip(screenGui)

	local self = setmetatable({
		frame = parent,
		list = list,
		unlocks = {},
		equipped = {},
		loadoutLocked = false,
		packets = {},
		hint = hint,
		tooltip = tooltip,
		tooltipPortraitHolder = portraitHolder,
		tooltipName = tooltipName,
		tooltipStats = tooltipStats,
	}, Inventory) :: InventoryPanel

	close.Activated:Connect(function()
		AudioController.play("UiClick")
		self:setOpen(false)
	end)

	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 12)
	end)

	return self
end

local HINT_OPEN = string.format("Equip up to %d for the shop bar — hover a packet for details", ProgressConfig.MAX_EQUIPPED)
local HINT_LOCKED = "Loadout is locked while the day is underway"

local function stylePacket(packet: Packet, equipped: boolean, locked: boolean)
	UITheme.applyCardLook(packet.button, equipped)
	packet.button.BackgroundTransparency = if locked then 0.45 elseif equipped then 0 else 0.3

	if locked then
		packet.ribbon.BackgroundColor3 = UITheme.SUBTEXT
		packet.ribbonLabel.Text = if equipped then "EQUIPPED" else "LOCKED"
	else
		packet.ribbon.BackgroundColor3 = if equipped then UITheme.SUCCESS else UITheme.SUBTEXT
		packet.ribbonLabel.Text = if equipped then "EQUIPPED" else "TAP TO EQUIP"
	end
	UITheme.applyOutlinedTitle(packet.ribbonLabel, UITheme.TITLE)
	packet.ribbonLabel.TextSize = if equipped and not locked then 11 else 10
end

function Inventory.showTooltip(self: InventoryPanel, packet: Packet)
	local definition = packet.definition

	for _, child in self.tooltipPortraitHolder:GetChildren() do
		child:Destroy()
	end
	BrainrotPreview.mount(
		self.tooltipPortraitHolder,
		definition,
		UDim2.fromOffset(TOOLTIP_PORTRAIT - 8, TOOLTIP_PORTRAIT - 8),
		UDim2.new(0.5, 0, 0, 4)
	)

	self.tooltipName.Text = definition.name

	for _, child in self.tooltipStats:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	local order = 0
	for _, row in BrainrotInfo.statRows(definition) do
		order += 1
		local rowLabel = Instance.new("TextLabel")
		rowLabel.Name = row.label
		rowLabel.LayoutOrder = order
		rowLabel.BackgroundTransparency = 1
		rowLabel.Size = UDim2.new(1, 0, 0, 16)
		rowLabel.TextXAlignment = Enum.TextXAlignment.Left
		rowLabel.RichText = true
		rowLabel.TextSize = 13
		rowLabel.Text = string.format(
			'<font color="rgb(200,225,255)">%s:</font> <b>%s</b>',
			row.label,
			row.value
		)
		rowLabel.Parent = self.tooltipStats
		UITheme.applyOutlinedTitle(rowLabel)
		rowLabel.TextSize = 13
	end

	order += 1
	local abilityDesc = Instance.new("TextLabel")
	abilityDesc.Name = "AbilityDescription"
	abilityDesc.LayoutOrder = order
	abilityDesc.BackgroundTransparency = 1
	abilityDesc.Size = UDim2.new(1, 0, 0, 0)
	abilityDesc.AutomaticSize = Enum.AutomaticSize.Y
	abilityDesc.TextWrapped = true
	abilityDesc.TextXAlignment = Enum.TextXAlignment.Left
	abilityDesc.TextSize = 12
	abilityDesc.Text = BrainrotInfo.abilityDescription(definition.ability)
	abilityDesc.Parent = self.tooltipStats
	UITheme.applyOutlinedTitle(abilityDesc)
	abilityDesc.TextSize = 13

	local button = packet.button
	local absPos = button.AbsolutePosition
	local absSize = button.AbsoluteSize
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)

	local x = absPos.X + absSize.X + 10
	if x + TOOLTIP_WIDTH > viewport.X then
		x = absPos.X - TOOLTIP_WIDTH - 10
	end
	x = math.clamp(x, 8, math.max(8, viewport.X - TOOLTIP_WIDTH - 8))
	local y = math.clamp(absPos.Y, 8, math.max(8, viewport.Y - 220))

	self.tooltip.Position = UDim2.fromOffset(x, y)
	self.tooltip.Visible = true
end

function Inventory.hideTooltip(self: InventoryPanel)
	self.tooltip.Visible = false
end

function Inventory.buildPacket(self: InventoryPanel, order: number, definition: Types.BrainrotDefinition): Packet
	local button = Instance.new("TextButton")
	button.Name = definition.id
	button.LayoutOrder = order
	button.AutoButtonColor = false
	button.Text = ""
	button.ClipsDescendants = false
	button.Parent = self.list

	-- Seed-packet frame: portrait window on top, a light name plate for
	-- contrast against either card color, then a status ribbon inset from
	-- the edges so it never covers the card's rounded outline.
	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0)
	window.Position = UDim2.new(0.5, 0, 0, 10)
	window.Size = UDim2.fromOffset(PREVIEW_SIZE, PREVIEW_SIZE)
	window.BackgroundColor3 = Color3.fromRGB(235, 245, 255)
	window.BackgroundTransparency = 0.15
	window.BorderSizePixel = 0
	window.Parent = button
	UITheme.styleCorner(window, 8)
	UITheme.applyStroke(window, 2)

	local preview = BrainrotPreview.mount(
		window,
		definition,
		UDim2.fromOffset(PREVIEW_SIZE - 8, PREVIEW_SIZE - 8),
		UDim2.new(0.5, 0, 0, 4)
	)
	if preview:IsA("ViewportFrame") or preview:IsA("Frame") then
		preview.BackgroundTransparency = 1
	end

	local namePlate = Instance.new("Frame")
	namePlate.Name = "NamePlate"
	namePlate.AnchorPoint = Vector2.new(0.5, 0)
	namePlate.Position = UDim2.new(0.5, 0, 0, 10 + PREVIEW_SIZE + 6)
	namePlate.Size = UDim2.new(1, -12, 0, PLATE_HEIGHT)
	namePlate.BackgroundColor3 = Color3.fromRGB(255, 250, 235)
	namePlate.BorderSizePixel = 0
	namePlate.Parent = button
	UITheme.styleCorner(namePlate, 6)
	UITheme.applyStroke(namePlate, 2)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, -6, 1, -2)
	nameLabel.Position = UDim2.fromOffset(3, 1)
	nameLabel.TextSize = 12
	nameLabel.TextWrapped = true
	nameLabel.TextScaled = false
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextYAlignment = Enum.TextYAlignment.Center
	nameLabel.Text = definition.name
	nameLabel.Parent = namePlate
	UITheme.applyOutlinedTitle(nameLabel)
	nameLabel.TextSize = 12

	local sizeConstraint = Instance.new("UITextSizeConstraint")
	sizeConstraint.MaxTextSize = 12
	sizeConstraint.MinTextSize = 8
	sizeConstraint.Parent = nameLabel

	local ribbon = Instance.new("Frame")
	ribbon.Name = "Ribbon"
	ribbon.AnchorPoint = Vector2.new(0.5, 1)
	ribbon.Position = UDim2.new(0.5, 0, 1, -6)
	ribbon.Size = UDim2.new(1, -12, 0, RIBBON_HEIGHT)
	ribbon.BorderSizePixel = 0
	ribbon.Parent = button
	UITheme.styleCorner(ribbon, 6)
	UITheme.applyStroke(ribbon, 2)

	local ribbonLabel = Instance.new("TextLabel")
	ribbonLabel.Name = "Label"
	ribbonLabel.BackgroundTransparency = 1
	ribbonLabel.Size = UDim2.fromScale(1, 1)
	ribbonLabel.TextXAlignment = Enum.TextXAlignment.Center
	ribbonLabel.Parent = ribbon

	local packet: Packet = {
		button = button,
		ribbon = ribbon,
		ribbonLabel = ribbonLabel,
		definition = definition,
	}

	button.MouseEnter:Connect(function()
		self:showTooltip(packet)
	end)
	button.MouseLeave:Connect(function()
		self:hideTooltip()
	end)

	button.Activated:Connect(function()
		AudioController.play("UiClick")
		if self.loadoutLocked then
			UIEvents.firePlantFailed("Unable to change loadout — the day has already started")
			return
		end
		local nextEquipped = table.clone(self.equipped)
		if isEquipped(nextEquipped, definition.id) then
			if #nextEquipped <= 1 then
				return
			end
			local filtered: { string } = {}
			for _, id in nextEquipped do
				if id ~= definition.id then
					table.insert(filtered, id)
				end
			end
			nextEquipped = filtered
		else
			if #nextEquipped >= ProgressConfig.MAX_EQUIPPED then
				return
			end
			table.insert(nextEquipped, definition.id)
		end
		Remotes.getEvent("SetEquipped"):FireServer(nextEquipped)
	end)

	return packet
end

function Inventory.refresh(self: InventoryPanel)
	self:hideTooltip()
	for _, child in self.list:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	self.packets = {}

	local order = 0
	for _, definition in sortedUnlocks(self.unlocks) do
		order += 1
		local packet = self:buildPacket(order, definition)
		stylePacket(packet, isEquipped(self.equipped, definition.id), self.loadoutLocked)
		self.packets[definition.id] = packet
	end
end

function Inventory.applyProfile(self: InventoryPanel, profile: { [string]: any })
	if type(profile.unlocks) == "table" then
		self.unlocks = profile.unlocks :: { string }
	end
	if type(profile.equipped) == "table" then
		self.equipped = profile.equipped :: { string }
	end
	self:refresh()
end

function Inventory.setLoadoutLocked(self: InventoryPanel, locked: boolean)
	self.loadoutLocked = locked == true
	self.hint.Text = if self.loadoutLocked then HINT_LOCKED else HINT_OPEN
	for id, packet in self.packets do
		stylePacket(packet, isEquipped(self.equipped, id), self.loadoutLocked)
	end
end

function Inventory.setOpen(self: InventoryPanel, open: boolean)
	self.frame.Visible = open
	if not open then
		self:hideTooltip()
	end
end

function Inventory.isOpen(self: InventoryPanel): boolean
	return self.frame.Visible
end

return Inventory
