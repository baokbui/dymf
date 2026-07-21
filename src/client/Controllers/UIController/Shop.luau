--!strict
--[[
	Shop
	Builds and manages the Shop panel for UIController. Display-only;
	placement lives in PlacementController / the server.

	Look: cartoon thick-outline (Shared.Config.UITheme), with lighter card
	chrome so previews stay readable.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared.Brainrots)
local UITheme = require(Shared.Config.UITheme)
local Types = require(Shared.Types)

local BrainrotPreview = require(script.Parent.Parent.Parent.Utilities.BrainrotPreview)

local Shop = {}
Shop.__index = Shop

local CARD_WIDTH = 64
local CARD_HEIGHT = 78
local CARD_PADDING = 10
local PANEL_PADDING_X = 12
local PANEL_PADDING_Y = 8
local SWATCH_SIZE = 42
local CARD_STROKE = 2
local PANEL_HEIGHT = CARD_HEIGHT + PANEL_PADDING_Y * 2
local PANEL_CORNER_RADIUS = UITheme.CORNER_PANEL

local TOOL_COLUMN_WIDTH = 40
local TOOL_GAP = 6
local TOOL_BUTTON_HEIGHT = math.floor((CARD_HEIGHT - TOOL_GAP) / 2)

type Card = {
	button: TextButton,
	costLabel: TextLabel,
	nameLabel: TextLabel,
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
		cancelButton: TextButton,
		callbacks: ShopCallbacks,
	},
	Shop
))

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
	frame.ClipsDescendants = false
	resizePanel(frame, 0)

	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.AnchorPoint = Vector2.new(0.5, 0)
	bg.Position = UDim2.new(0.5, 0, 0, -PANEL_CORNER_RADIUS)
	bg.Size = UDim2.new(1, 0, 1, PANEL_CORNER_RADIUS)
	bg.BorderSizePixel = 0
	bg.Parent = frame
	UITheme.applyPanelLook(bg, PANEL_CORNER_RADIUS)

	local tools = Instance.new("Frame")
	tools.Name = "Tools"
	tools.BackgroundTransparency = 1
	tools.Position = UDim2.fromOffset(PANEL_PADDING_X, PANEL_PADDING_Y)
	tools.Size = UDim2.fromOffset(TOOL_COLUMN_WIDTH, CARD_HEIGHT)
	tools.Parent = frame

	local shovelButton = self:buildShovelButton(tools)
	self.shovelButton = shovelButton

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

function Shop.buildShovelButton(self: Shop, parent: Instance): TextButton
	local button = Instance.new("TextButton")
	button.Name = "Shovel"
	button.AutoButtonColor = false
	button.Size = UDim2.new(1, 0, 0, TOOL_BUTTON_HEIGHT)
	button.Text = ""
	button.Parent = parent
	UITheme.applyButtonLook(button, UITheme.CARD_BG)

	local handle = Instance.new("Frame")
	handle.AnchorPoint = Vector2.new(0.5, 0)
	handle.Position = UDim2.new(0.5, 0, 0, 8)
	handle.Size = UDim2.fromOffset(5, 12)
	handle.BackgroundColor3 = Color3.fromRGB(120, 80, 40)
	handle.BorderSizePixel = 0
	handle.Parent = button
	UITheme.styleCorner(handle, 2)
	UITheme.applyStroke(handle, 2)

	local blade = Instance.new("Frame")
	blade.AnchorPoint = Vector2.new(0.5, 1)
	blade.Position = UDim2.new(0.5, 0, 1, -8)
	blade.Size = UDim2.fromOffset(16, 8)
	blade.BackgroundColor3 = Color3.fromRGB(220, 225, 235)
	blade.BorderSizePixel = 0
	blade.Parent = button
	UITheme.styleCorner(blade, 2)
	UITheme.applyStroke(blade, 2)

	button.Activated:Connect(function()
		self.callbacks.onShovelClicked()
	end)

	return button
end

function Shop.buildCancelButton(self: Shop, parent: Instance): TextButton
	local button = Instance.new("TextButton")
	button.Name = "Cancel"
	button.AutoButtonColor = false
	button.AnchorPoint = Vector2.new(0, 1)
	button.Position = UDim2.new(0, 0, 1, 0)
	button.Size = UDim2.new(1, 0, 0, TOOL_BUTTON_HEIGHT)
	button.TextSize = 18
	button.Text = "X"
	button.Visible = false
	button.Parent = parent
	UITheme.applyButtonLook(button, UITheme.CANCEL)
	UITheme.applyOutlinedTitle(button)

	button.Activated:Connect(function()
		self.callbacks.onCancelClicked()
	end)

	return button
end

function Shop.styleCard(button: GuiObject, selected: boolean?)
	UITheme.applyCardLook(button, selected)
	-- Thinner stroke than default cards so the row doesn't read as one yellow slab.
	UITheme.applyStroke(button, CARD_STROKE)
end

function Shop.buildCard(self: Shop, parent: Instance, order: number, definition: Types.BrainrotDefinition)
	local button = Instance.new("TextButton")
	button.Name = definition.id
	button.LayoutOrder = order
	button.AutoButtonColor = false
	button.Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT)
	button.Text = ""
	button.Parent = parent
	Shop.styleCard(button, false)

	local preview = BrainrotPreview.mount(
		button,
		definition,
		UDim2.fromOffset(SWATCH_SIZE, SWATCH_SIZE),
		UDim2.new(0.5, 0, 0, 5)
	)
	-- Soft inset only — no second black ring inside the card.
	UITheme.styleCorner(preview, 8)
	if preview:IsA("ViewportFrame") or preview:IsA("Frame") then
		preview.BackgroundTransparency = 0.45
	end

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.BackgroundTransparency = 1
	nameLabel.AnchorPoint = Vector2.new(0.5, 0)
	nameLabel.Position = UDim2.new(0.5, 0, 0, 5 + SWATCH_SIZE + 2)
	nameLabel.Size = UDim2.new(1, -8, 0, 12)
	nameLabel.TextSize = 9
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Text = definition.name
	nameLabel.Parent = button
	UITheme.applyBodyText(nameLabel, UITheme.SUBTEXT)

	local costLabel = Instance.new("TextLabel")
	costLabel.Name = "Cost"
	costLabel.BackgroundTransparency = 1
	costLabel.AnchorPoint = Vector2.new(0.5, 1)
	costLabel.Position = UDim2.new(0.5, 0, 1, -5)
	costLabel.Size = UDim2.new(1, -6, 0, 12)
	costLabel.TextSize = 12
	costLabel.TextXAlignment = Enum.TextXAlignment.Center
	costLabel.Text = tostring(definition.cost)
	costLabel.Parent = button
	UITheme.applyOutlinedTitle(costLabel, UITheme.GOLD_TEXT)
	costLabel.Font = Enum.Font.GothamBold
	costLabel.TextSize = 12

	button.Activated:Connect(function()
		self.callbacks.onCardClicked(definition.id)
	end)

	table.insert(self.cards, {
		button = button,
		costLabel = costLabel,
		nameLabel = nameLabel,
		definition = definition,
	})
end

function Shop.refresh(self: Shop)
	for _, card in self.cards do
		local affordable = self.balance >= card.definition.cost
		local selected = self.selectedId == card.definition.id

		Shop.styleCard(card.button, selected)
		card.button.BackgroundTransparency = if affordable then 0 else 0.35
		if affordable then
			UITheme.applyOutlinedTitle(card.costLabel, UITheme.GOLD_TEXT)
		else
			UITheme.applyOutlinedTitle(card.costLabel, UITheme.DANGER)
		end
		card.costLabel.TextSize = 12
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
	UITheme.applyButtonLook(self.shovelButton, if active then UITheme.SHOVEL else UITheme.CARD_BG)
end

function Shop.setCancelVisible(self: Shop, visible: boolean)
	self.cancelButton.Visible = visible
end

return Shop
