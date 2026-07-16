--!strict
--[[
	Shop
	Builds and manages the Shop panel for UIController. It only *displays* state
	(the Brainrot roster read from the shared registry, current affordability,
	and which card is selected) and reports card clicks back via a callback —
	all placement logic lives in PlacementController / the server.

	Layout: a PvZ-style horizontal bar pinned to the top-center of the screen.
	Each Brainrot is a portrait card (swatch icon on top, name below, cost at
	the bottom) laid out left-to-right in cost order. Cards dim and show a red
	cost when unaffordable; the selected card gets a highlighted border.

	UIController owns the lifecycle: it creates the shop, feeds it the balance
	and the selected id, and routes clicks to PlacementController.

	Milestone 4.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared.Brainrots)
local Types = require(Shared.Types)

local Shop = {}
Shop.__index = Shop

-- ===== Layout constants =====
-- Card dimensions (portrait tile, PvZ-style).
local CARD_WIDTH = 60
local CARD_HEIGHT = 74
local CARD_PADDING = 5 -- gap between cards
local PANEL_PADDING_X = 10 -- left/right inset inside the bar
local PANEL_PADDING_Y = 6 -- top/bottom inset inside the bar
local SWATCH_SIZE = 36 -- square icon at the top of each card
local PANEL_HEIGHT = CARD_HEIGHT + PANEL_PADDING_Y * 2
local PANEL_CORNER_RADIUS = 10 -- rounded bottom corners; top is squared by clip
local PANEL_TRANSPARENCY = 0.15
local CARD_CORNER_RADIUS = 8
local SWATCH_CORNER_RADIUS = 6
local BORDER_CORNER_RADIUS = 10

local TOOL_COLUMN_WIDTH = 40
local TOOL_GAP = 4
local TOOL_BUTTON_HEIGHT = math.floor((CARD_HEIGHT - TOOL_GAP) / 2)

-- ===== Colour constants =====
local PANEL_BG = Color3.fromRGB(18, 20, 30)
local CARD_BG = Color3.fromRGB(36, 40, 54)
local CARD_SELECTED_BG = Color3.fromRGB(48, 78, 110)
local CARD_SELECTED_BORDER = Color3.fromRGB(120, 200, 255)
local TEXT_COLOR = Color3.fromRGB(235, 238, 245)
local COST_AFFORD = Color3.fromRGB(255, 215, 0)
local COST_BLOCKED = Color3.fromRGB(220, 110, 110)
local DEFAULT_SWATCH = Color3.fromRGB(180, 140, 220)
local SHOVEL_ACTIVE_BG = Color3.fromRGB(72, 92, 58)
local SHOVEL_ACTIVE_BORDER = Color3.fromRGB(160, 210, 110)
local CANCEL_BG = Color3.fromRGB(150, 45, 45)

type Card = {
	button: TextButton,
	costLabel: TextLabel,
	selectionBorder: Frame,
	definition: Types.BrainrotDefinition,
}

export type ShopCallbacks = {
	onCardClicked: (id: string) -> (),
	onShovelClicked: () -> (),
	onCancelClicked: () -> (),
}

export type Shop = typeof(setmetatable(
	{} :: {
		frame: Frame,
		list: Frame,
		cards: { Card },
		balance: number,
		selectedId: string?,
		equippedIds: { string },
		shovelButton: TextButton,
		shovelBorder: Frame,
		cancelButton: TextButton,
		callbacks: ShopCallbacks,
	},
	Shop
))

local function styleCorner(instance: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

-- Stable display order (by cost, then name) so the roster never jumps.
local function sortedDefinitions(filterIds: { string }?): { Types.BrainrotDefinition }
	local allowed: { [string]: boolean }? = nil
	if filterIds then
		allowed = {}
		for _, id in filterIds do
			allowed[id] = true
		end
	end

	local list: { Types.BrainrotDefinition } = {}
	for _, definition in Brainrots.getAll() do
		if allowed and not allowed[definition.id] then
			continue
		end
		table.insert(list, definition)
	end
	table.sort(list, function(a, b)
		if a.cost ~= b.cost then
			return a.cost < b.cost
		end
		return a.name < b.name
	end)
	return list
end

local function resizePanel(frame: Frame, cardCount: number)
	local cardsWidth = math.max(0, cardCount * (CARD_WIDTH + CARD_PADDING) - CARD_PADDING)
	local panelWidth = PANEL_PADDING_X * 2 + TOOL_COLUMN_WIDTH + CARD_PADDING + cardsWidth
	frame.Size = UDim2.fromOffset(math.max(panelWidth, 160), PANEL_HEIGHT)
end

function Shop.new(frame: Frame, callbacks: ShopCallbacks): Shop
	local self = setmetatable({
		frame = frame,
		cards = {},
		balance = 0,
		selectedId = nil,
		equippedIds = {},
		callbacks = callbacks,
	}, Shop) :: Shop

	frame.Visible = true
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 0)
	frame.BackgroundTransparency = 1
	frame.ClipsDescendants = true
	resizePanel(frame, 0)

	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.AnchorPoint = Vector2.new(0.5, 0)
	bg.Position = UDim2.new(0.5, 0, 0, -PANEL_CORNER_RADIUS)
	bg.Size = UDim2.new(1, 0, 1, PANEL_CORNER_RADIUS)
	bg.BackgroundColor3 = PANEL_BG
	bg.BackgroundTransparency = PANEL_TRANSPARENCY
	bg.BorderSizePixel = 0
	bg.Parent = frame
	styleCorner(bg, PANEL_CORNER_RADIUS)

	local tools = Instance.new("Frame")
	tools.Name = "Tools"
	tools.BackgroundTransparency = 1
	tools.Position = UDim2.fromOffset(PANEL_PADDING_X, PANEL_PADDING_Y)
	tools.Size = UDim2.fromOffset(TOOL_COLUMN_WIDTH, CARD_HEIGHT)
	tools.Parent = frame

	local shovelButton, shovelBorder = self:buildShovelButton(tools)
	self.shovelButton = shovelButton
	self.shovelBorder = shovelBorder

	local cancelButton = self:buildCancelButton(tools)
	self.cancelButton = cancelButton

	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(PANEL_PADDING_X + TOOL_COLUMN_WIDTH + CARD_PADDING, PANEL_PADDING_Y)
	list.Size = UDim2.new(1, -(PANEL_PADDING_X * 2 + TOOL_COLUMN_WIDTH + CARD_PADDING), 1, -PANEL_PADDING_Y * 2)
	list.Parent = frame
	self.list = list

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, CARD_PADDING)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	self:refresh()
	return self
end

function Shop.buildShovelButton(self: Shop, parent: Instance): (TextButton, Frame)
	local button = Instance.new("TextButton")
	button.Name = "Shovel"
	button.AutoButtonColor = false
	button.Size = UDim2.new(1, 0, 0, TOOL_BUTTON_HEIGHT)
	button.BackgroundColor3 = CARD_BG
	button.Text = ""
	button.Parent = parent
	styleCorner(button, CARD_CORNER_RADIUS)

	local border = Instance.new("Frame")
	border.Name = "ActiveBorder"
	border.AnchorPoint = Vector2.new(0.5, 0.5)
	border.Position = UDim2.new(0.5, 0, 0.5, 0)
	border.Size = UDim2.new(1, 4, 1, 4)
	border.BackgroundColor3 = SHOVEL_ACTIVE_BORDER
	border.BackgroundTransparency = 1
	border.ZIndex = button.ZIndex - 1
	styleCorner(border, BORDER_CORNER_RADIUS)
	border.Parent = button

	local handle = Instance.new("Frame")
	handle.AnchorPoint = Vector2.new(0.5, 0)
	handle.Position = UDim2.new(0.5, 0, 0, 10)
	handle.Size = UDim2.fromOffset(5, 12)
	handle.BackgroundColor3 = Color3.fromRGB(120, 80, 40)
	handle.BorderSizePixel = 0
	handle.Parent = button
	local handleCorner = Instance.new("UICorner")
	handleCorner.CornerRadius = UDim.new(0, 2)
	handleCorner.Parent = handle

	local blade = Instance.new("Frame")
	blade.AnchorPoint = Vector2.new(0.5, 1)
	blade.Position = UDim2.new(0.5, 0, 1, -10)
	blade.Size = UDim2.fromOffset(16, 8)
	blade.BackgroundColor3 = Color3.fromRGB(190, 195, 205)
	blade.BorderSizePixel = 0
	blade.Parent = button
	local bladeCorner = Instance.new("UICorner")
	bladeCorner.CornerRadius = UDim.new(0, 2)
	bladeCorner.Parent = blade

	button.Activated:Connect(function()
		self.callbacks.onShovelClicked()
	end)

	return button, border
end

function Shop.buildCancelButton(self: Shop, parent: Instance): TextButton
	local button = Instance.new("TextButton")
	button.Name = "Cancel"
	button.AutoButtonColor = false
	button.AnchorPoint = Vector2.new(0, 1)
	button.Position = UDim2.new(0, 0, 1, 0)
	button.Size = UDim2.new(1, 0, 0, TOOL_BUTTON_HEIGHT)
	button.BackgroundColor3 = CANCEL_BG
	button.Font = Enum.Font.GothamBold
	button.TextSize = 18
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = "X"
	button.Visible = false
	button.Parent = parent
	styleCorner(button, CARD_CORNER_RADIUS)

	button.Activated:Connect(function()
		self.callbacks.onCancelClicked()
	end)

	return button
end

-- Builds one portrait card: swatch icon → name → cost (stacked top-to-bottom).
function Shop.buildCard(self: Shop, parent: Instance, order: number, definition: Types.BrainrotDefinition)
	local button = Instance.new("TextButton")
	button.Name = definition.id
	button.LayoutOrder = order
	button.AutoButtonColor = false -- manual state via refresh()
	button.Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT)
	button.BackgroundColor3 = CARD_BG
	button.Text = ""
	button.Parent = parent
	styleCorner(button, CARD_CORNER_RADIUS)

	-- Selection border: slightly larger than the card, rendered behind it so it
	-- shows as a coloured outline when the card is selected.
	local border = Instance.new("Frame")
	border.Name = "SelectionBorder"
	border.AnchorPoint = Vector2.new(0.5, 0.5)
	border.Position = UDim2.new(0.5, 0, 0.5, 0)
	border.Size = UDim2.new(1, 4, 1, 4)
	border.BackgroundColor3 = CARD_SELECTED_BORDER
	border.BackgroundTransparency = 1 -- hidden until selected
	border.ZIndex = button.ZIndex - 1
	styleCorner(border, BORDER_CORNER_RADIUS)
	border.Parent = button

	-- Swatch: coloured square at the top of the card.
	local swatch = Instance.new("Frame")
	swatch.Name = "Swatch"
	swatch.AnchorPoint = Vector2.new(0.5, 0)
	swatch.Position = UDim2.new(0.5, 0, 0, 6)
	swatch.Size = UDim2.fromOffset(SWATCH_SIZE, SWATCH_SIZE)
	swatch.BackgroundColor3 = definition.color or DEFAULT_SWATCH
	swatch.Parent = button
	styleCorner(swatch, SWATCH_CORNER_RADIUS)

	-- Name label: below the swatch.
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.BackgroundTransparency = 1
	nameLabel.AnchorPoint = Vector2.new(0.5, 0)
	nameLabel.Position = UDim2.new(0.5, 0, 0, 6 + SWATCH_SIZE + 2)
	nameLabel.Size = UDim2.new(1, -4, 0, 14)
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextSize = 10
	nameLabel.TextColor3 = TEXT_COLOR
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Text = definition.name
	nameLabel.Parent = button

	-- Cost label: pinned to the bottom of the card.
	local costLabel = Instance.new("TextLabel")
	costLabel.Name = "Cost"
	costLabel.BackgroundTransparency = 1
	costLabel.AnchorPoint = Vector2.new(0.5, 1)
	costLabel.Position = UDim2.new(0.5, 0, 1, -4)
	costLabel.Size = UDim2.new(1, -4, 0, 12)
	costLabel.Font = Enum.Font.GothamBold
	costLabel.TextSize = 11
	costLabel.TextColor3 = COST_AFFORD
	costLabel.TextXAlignment = Enum.TextXAlignment.Center
	costLabel.Text = tostring(definition.cost)
	costLabel.Parent = button

	button.Activated:Connect(function()
		self.callbacks.onCardClicked(definition.id)
	end)

	table.insert(self.cards, {
		button = button,
		costLabel = costLabel,
		selectionBorder = border,
		definition = definition,
	})
end

-- Repaints every card from the current balance + selection state.
function Shop.refresh(self: Shop)
	for _, card in self.cards do
		local affordable = self.balance >= card.definition.cost
		local selected = self.selectedId == card.definition.id

		card.button.BackgroundColor3 = if selected then CARD_SELECTED_BG else CARD_BG
		card.button.BackgroundTransparency = if affordable then 0 else 0.45
		card.costLabel.TextColor3 = if affordable then COST_AFFORD else COST_BLOCKED
		card.selectionBorder.BackgroundTransparency = if selected then 0 else 1
	end
end

function Shop.setEquipped(self: Shop, ids: { string })
	self.equippedIds = ids
	for _, child in self.list:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	self.cards = {}

	local definitions = sortedDefinitions(ids)
	for index, definition in definitions do
		self:buildCard(self.list, index, definition)
	end
	resizePanel(self.frame, #definitions)

	if self.selectedId then
		local stillThere = false
		for _, definition in definitions do
			if definition.id == self.selectedId then
				stillThere = true
				break
			end
		end
		if not stillThere then
			self.selectedId = nil
		end
	end
	self:refresh()
end

function Shop.setBalance(self: Shop, amount: number)
	self.balance = amount
	self:refresh()
end

function Shop.setSelected(self: Shop, id: string?)
	self.selectedId = id
	self:refresh()
end

function Shop.setShovelActive(self: Shop, active: boolean)
	self.shovelButton.BackgroundColor3 = if active then SHOVEL_ACTIVE_BG else CARD_BG
	self.shovelBorder.BackgroundTransparency = if active then 0 else 1
end

function Shop.setCancelVisible(self: Shop, visible: boolean)
	self.cancelButton.Visible = visible
end

return Shop
