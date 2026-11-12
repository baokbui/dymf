--!strict
--[[
	Inventory
	Equip / unequip unlocked Brainrots for the placement shop loadout.

	PvZ-style **seed packet** grid: click a packet to inspect it. Stats and
	ability copy open on a shared `BrainrotInspect` card to the **right** of
  the modal (portrait + HP / level / XP bar, stats + evolutions,
	Equip / Equipped at the bottom). Cartoon thick-outline look via UITheme.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared.Brainrots)
local ProgressConfig = require(Shared.Config.ProgressConfig)
local UITheme = require(Shared.Config.UITheme)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local BrainrotPreview = require(script.Parent.Parent.Parent.Utilities.BrainrotPreview)
local AudioController = require(script.Parent.Parent.AudioController)
local UIEvents = require(script.Parent.Parent.Parent.UIEvents)
local BrainrotInspect = require(script.Parent.BrainrotInspect)
local InventoryItems = require(script.Parent.InventoryItems)
local InventoryPets = require(script.Parent.InventoryPets)

local Inventory = {}
Inventory.__index = Inventory

local PACKET_WIDTH = 116
local PACKET_HEIGHT = 156
local PACKET_PADDING = 14
local PREVIEW_SIZE = 78
local PLATE_HEIGHT = 30
local RIBBON_HEIGHT = 18

local GRID_WIDTH = PACKET_WIDTH * 3 + PACKET_PADDING * 2
local SCROLLBAR = 6
local SCROLL_GAP = 14
local INV_WIDTH = 12 + 6 + GRID_WIDTH + SCROLL_GAP + SCROLLBAR + 12
local INV_HEIGHT = 472
local STATS_WIDTH = BrainrotInspect.CARD_WIDTH
local STATS_GAP = 14
local STATS_LAYOUT_SHIFT = -math.floor((INV_WIDTH + STATS_GAP + STATS_WIDTH) / 2 - INV_WIDTH / 2)

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
		loadoutCount: TextLabel,
		title: TextLabel,
		itemsList: ScrollingFrame,
		petsList: ScrollingFrame,
		petsTab: TextButton,
		loadoutTab: TextButton,
		itemsTab: TextButton,
		inspect: BrainrotInspect.InspectCard,
		selectedId: string?,
		brainrotXp: { [string]: number },
		evolutions: { [string]: { string } },
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

local function sameStringList(a: { string }, b: { string }): boolean
	if #a ~= #b then
		return false
	end
	for index, value in a do
		if b[index] ~= value then
			return false
		end
	end
	return true
end

local function layoutInventory(self: InventoryPanel, statsOpen: boolean)
	if statsOpen then
		self.frame.Position = UDim2.new(0.5, STATS_LAYOUT_SHIFT, 0.5, 0)
	else
		self.frame.Position = UDim2.fromScale(0.5, 0.5)
	end
end

local function stylePacket(packet: Packet, equipped: boolean, locked: boolean, selected: boolean)
	UITheme.applyCardLook(packet.button, equipped or selected)
	packet.button.BackgroundColor3 = if equipped then UITheme.INVENTORY_INSET else UITheme.INVENTORY_PACKET
	if selected then
		packet.button.BackgroundTransparency = 0
	elseif locked then
		packet.button.BackgroundTransparency = 0.45
	elseif equipped then
		packet.button.BackgroundTransparency = 0
	else
		packet.button.BackgroundTransparency = 0.3
	end

	if locked then
		packet.ribbon.Visible = true
		packet.ribbon.BackgroundColor3 = UITheme.SUBTEXT
		packet.ribbonLabel.Text = if equipped then "EQUIPPED" else "LOCKED"
	elseif equipped then
		packet.ribbon.Visible = true
		packet.ribbon.BackgroundColor3 = UITheme.SUCCESS
		packet.ribbonLabel.Text = "EQUIPPED"
	else
		packet.ribbon.Visible = false
	end
	UITheme.applyOutlinedTitle(packet.ribbonLabel, UITheme.TITLE)
	packet.ribbonLabel.TextSize = if equipped and not locked then 11 else 10
end

function Inventory.new(parent: Frame): InventoryPanel
	parent.Visible = false
	parent.AnchorPoint = Vector2.new(0.5, 0.5)
	parent.Position = UDim2.fromScale(0.5, 0.5)
	parent.Size = UDim2.fromOffset(INV_WIDTH, INV_HEIGHT)
	parent.ZIndex = 30
	parent.ClipsDescendants = false
	UITheme.applyPanelLook(parent, nil, UITheme.PANEL_BG_INVENTORY)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -80, 0, 32)
	title.Position = UDim2.fromOffset(16, 12)
	title.TextSize = 22
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Brainrot Loadout"
	title.Parent = parent
	UITheme.applyOutlinedTitle(title)

	local loadoutCount = Instance.new("TextLabel")
	loadoutCount.Name = "LoadoutCount"
	loadoutCount.Position, loadoutCount.Size = UDim2.new(1, -177, 0, 14), UDim2.fromOffset(118, 28)
	loadoutCount.Text = string.format("0 / %d EQUIPPED", ProgressConfig.MAX_EQUIPPED)
	loadoutCount.TextSize = 12
	UITheme.applyButtonLook(loadoutCount, UITheme.INVENTORY_INK, 8)
	UITheme.applyOutlinedTitle(loadoutCount)
	loadoutCount.Parent = parent

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
	hint.Position = UDim2.fromOffset(16, 82)
	hint.TextSize = 13
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Text = string.format("Pick up to %d for your shop. Tap one for details.", ProgressConfig.MAX_EQUIPPED)
	hint.Parent = parent
	UITheme.applyBodyText(hint, UITheme.SUBTEXT)

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(12, 106)
	list.Size = UDim2.new(1, -24, 1, -118)
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = SCROLLBAR
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.Parent = parent

	local listPad = Instance.new("UIPadding")
	listPad.PaddingTop = UDim.new(0, 6)
	listPad.PaddingLeft = UDim.new(0, 6)
	listPad.PaddingRight = UDim.new(0, SCROLL_GAP + SCROLLBAR)
	listPad.PaddingBottom = UDim.new(0, 6)
	listPad.Parent = list

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(PACKET_WIDTH, PACKET_HEIGHT)
	layout.CellPadding = UDim2.fromOffset(PACKET_PADDING, PACKET_PADDING)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.Parent = list

	local function tab(name: string, x: number): TextButton
		local button = Instance.new("TextButton")
		button.Name, button.Text, button.TextSize = name .. "Tab", name, 14
		button.Position, button.Size = UDim2.fromOffset(x, 47), UDim2.fromOffset(108, 29)
		UITheme.applyButtonLook(button, UITheme.INVENTORY_INSET, 8)
		UITheme.applyOutlinedTitle(button)
		button.Parent = parent
		return button
	end
	local loadoutTab, itemsTab, petsTab = tab("Loadout", 16), tab("Items", 132), tab("Pets", 248)
	local petsList = InventoryPets.new(parent)
	local itemsList, updateItems = InventoryItems.new(parent)
	local connection = UIEvents.retentionUpdated:Connect(updateItems)
	parent.Destroying:Once(function() connection:Disconnect() end)
	updateItems(UIEvents.getRetentionState())

	local inspect = BrainrotInspect.new(parent)
	inspect:dockInventory(STATS_GAP)

	local self = setmetatable({
		frame = parent,
		list = list,
		unlocks = {},
		equipped = {},
		loadoutLocked = false,
		packets = {},
		hint = hint,
		loadoutCount = loadoutCount,
		title = title,
		itemsList = itemsList,
		petsList = petsList,
		petsTab = petsTab,
		loadoutTab = loadoutTab,
		itemsTab = itemsTab,
		inspect = inspect,
		selectedId = nil,
		brainrotXp = {},
		evolutions = {},
	}, Inventory) :: InventoryPanel

	inspect:setEquipHandler(function()
		self:onEquipClicked()
	end)
	inspect.onHide = function()
		self.selectedId = nil
		layoutInventory(self, false)
		for id, packet in self.packets do
			stylePacket(packet, isEquipped(self.equipped, id), self.loadoutLocked, false)
		end
	end

	loadoutTab.Activated:Connect(function()
		AudioController.play("UiClick")
		self:showItems(false)
	end)
	itemsTab.Activated:Connect(function()
		AudioController.play("UiClick")
		self:showItems(true)
	end)
	petsTab.Activated:Connect(function()
		AudioController.play("UiClick")
		self:showPets()
	end)
	self:showItems(false)

	close.Activated:Connect(function()
		AudioController.play("UiClick")
		self:setOpen(false)
	end)


	return self
end

local HINT_OPEN = string.format("Pick up to %d for your shop. Tap one for details.", ProgressConfig.MAX_EQUIPPED)
local HINT_LOCKED = "You can't change your lineup while the day is going."

function Inventory.hideStats(self: InventoryPanel)
	if self.inspect:isOpen() then
		self.inspect:hide()
		return
	end
	self.selectedId = nil
	layoutInventory(self, false)
	for id, packet in self.packets do
		stylePacket(packet, isEquipped(self.equipped, id), self.loadoutLocked, false)
	end
end

function Inventory.syncEquipButton(self: InventoryPanel)
	local id = self.selectedId
	if not id or not self.inspect:isOpen() then
		return
	end
	local equipped = isEquipped(self.equipped, id)
	self.inspect:applyEquipState({
		equipped = equipped,
		loadoutLocked = self.loadoutLocked,
		loadoutFull = not equipped and #self.equipped >= ProgressConfig.MAX_EQUIPPED,
		lastEquipped = equipped and #self.equipped <= 1,
	})
end

function Inventory.showItems(self: InventoryPanel, show: boolean)
	self.petsList.Visible = false
	UITheme.applyButtonLook(self.petsTab, UITheme.INVENTORY_INSET, 8)
	if show and not self.itemsList.Visible then self:hideStats() end
	self.itemsList.Visible = show
	self.list.Visible = not show
	self.hint.Visible = not show
	self.loadoutCount.Visible = not show
	self.title.Text = if show then "Inventory Items" else "Brainrot Loadout"
	UITheme.applyButtonLook(self.itemsTab, if show then UITheme.INVENTORY_INK else UITheme.INVENTORY_INSET, 8)
	UITheme.applyButtonLook(self.loadoutTab, if show then UITheme.INVENTORY_INSET else UITheme.INVENTORY_INK, 8)
end

function Inventory.showPets(self: InventoryPanel)
	self:hideStats()
	self:showItems(false)
	self.list.Visible, self.hint.Visible, self.loadoutCount.Visible = false, false, false
	self.petsList.Visible = true
	self.title.Text = "Farm Pets"
	UITheme.applyButtonLook(self.loadoutTab, UITheme.INVENTORY_INSET, 8)
	UITheme.applyButtonLook(self.petsTab, UITheme.INVENTORY_INK, 8)
end

function Inventory.showStats(self: InventoryPanel, definition: Types.BrainrotDefinition)
	if self.itemsList.Visible or self.petsList.Visible then self:showItems(false) end
	self.selectedId = definition.id
	layoutInventory(self, true)
	local equipped = isEquipped(self.equipped, definition.id)
	self.inspect:show({
		definition = definition,
		mode = "inventory",
		equipped = equipped,
		loadoutLocked = self.loadoutLocked,
		loadoutFull = not equipped and #self.equipped >= ProgressConfig.MAX_EQUIPPED,
		lastEquipped = equipped and #self.equipped <= 1,
		totalXp = self.brainrotXp[definition.id] or 0,
		claimedRarities = self.evolutions[definition.id] or {},
	})
	for id, packet in self.packets do
		stylePacket(packet, isEquipped(self.equipped, id), self.loadoutLocked, id == definition.id)
	end
end

function Inventory.onEquipClicked(self: InventoryPanel)
	local id = self.selectedId
	if not id then
		return
	end
	if self.loadoutLocked then
		UIEvents.firePlantFailed("You can't change your lineup once the day has started.")
		return
	end
	if not self.inspect.equipButton.Active then
		return
	end

	local nextEquipped = table.clone(self.equipped)
	if isEquipped(nextEquipped, id) then
		if #nextEquipped <= 1 then
			return
		end
		local filtered: { string } = {}
		for _, equippedId in nextEquipped do
			if equippedId ~= id then
				table.insert(filtered, equippedId)
			end
		end
		nextEquipped = filtered
	else
		if #nextEquipped >= ProgressConfig.MAX_EQUIPPED then
			return
		end
		table.insert(nextEquipped, id)
	end
	Remotes.getEvent("SetEquipped"):FireServer(nextEquipped)
end

function Inventory.buildPacket(self: InventoryPanel, order: number, definition: Types.BrainrotDefinition): Packet
	local button = Instance.new("TextButton")
	button.Name = definition.id
	button.LayoutOrder = order
	button.AutoButtonColor = false
	button.Text = ""
	button.ClipsDescendants = false
	button.Parent = self.list

	UITheme.applySurfaceDepth(button)

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0)
	window.Position = UDim2.new(0.5, 0, 0, 10)
	window.Size = UDim2.fromOffset(PREVIEW_SIZE, PREVIEW_SIZE)
	window.BackgroundColor3 = UITheme.INVENTORY_INSET
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
	if preview:IsA("ViewportFrame") then
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
	UITheme.applyBodyText(nameLabel, UITheme.INVENTORY_INK)
	nameLabel.Font = Enum.Font.GothamBold
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

	button.Activated:Connect(function()
		AudioController.play("UiClick")
		self:showStats(definition)
	end)

	return packet
end

function Inventory.refresh(self: InventoryPanel)
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
		stylePacket(
			packet,
			isEquipped(self.equipped, definition.id),
			self.loadoutLocked,
			definition.id == self.selectedId
		)
		self.packets[definition.id] = packet
	end

	local selectedId = self.selectedId
	if selectedId then
		local packet = self.packets[selectedId]
		if packet then
			self:showStats(packet.definition)
		else
			self:hideStats()
		end
	end
end

function Inventory.applyProfile(self: InventoryPanel, profile: { [string]: any })
	local nextUnlocks = self.unlocks
	if type(profile.unlocks) == "table" then
		nextUnlocks = profile.unlocks :: { string }
	end
	local nextEquipped = self.equipped
	if type(profile.equipped) == "table" then
		nextEquipped = profile.equipped :: { string }
	end
	local xp: { [string]: number } = {}
	if type(profile.brainrotXp) == "table" then
		for key, value in (profile.brainrotXp :: { [string]: any }) do
			if type(key) == "string" and type(value) == "number" then
				xp[key] = value
			end
		end
	end
	local evolutions: { [string]: { string } } = {}
	if type(profile.evolutions) == "table" then
		for key, value in (profile.evolutions :: { [string]: any }) do
			if type(key) ~= "string" or type(value) ~= "table" then
				continue
			end
			local rarities: { string } = {}
			for _, rarity in value do
				if type(rarity) == "string" then
					table.insert(rarities, rarity)
				end
			end
			evolutions[key] = rarities
		end
	end

	-- ProfileUpdated also fires on every coin / soak XP tick. Remounting
	-- ViewportFrame packets each time is what made long sessions hitch.
	local unlocksChanged = not sameStringList(self.unlocks, nextUnlocks)
	local equippedChanged = not sameStringList(self.equipped, nextEquipped)
	self.unlocks = nextUnlocks
	self.equipped = nextEquipped
	self.loadoutCount.Text = string.format("%d / %d EQUIPPED", #nextEquipped, ProgressConfig.MAX_EQUIPPED)
	self.brainrotXp = xp
	self.evolutions = evolutions

	if unlocksChanged then
		self:refresh()
		return
	end
	if equippedChanged then
		for id, packet in self.packets do
			stylePacket(packet, isEquipped(self.equipped, id), self.loadoutLocked, id == self.selectedId)
		end
		self:syncEquipButton()
	end
	if self.inspect:isOpen() then
		local id = self.inspect:getBrainrotId()
		if id then
			self.inspect:setTotalXp(xp[id] or 0)
			self.inspect:setClaimedRarities(evolutions[id] or {})
			self:syncEquipButton()
		end
	end
end

function Inventory.setLoadoutLocked(self: InventoryPanel, locked: boolean)
	self.loadoutLocked = locked == true
	self.hint.Text = if self.loadoutLocked then HINT_LOCKED else HINT_OPEN
	for id, packet in self.packets do
		stylePacket(packet, isEquipped(self.equipped, id), self.loadoutLocked, id == self.selectedId)
	end
	self:syncEquipButton()
end

function Inventory.setOpen(self: InventoryPanel, open: boolean)
	self.frame.Visible = open
	if not open then
		self:hideStats()
	end
end

function Inventory.isOpen(self: InventoryPanel): boolean
	return self.frame.Visible
end

return Inventory
