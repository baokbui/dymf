--!strict
--[[
	Shop
	Builds and manages the Shop panel for UIController. It only *displays* state
	(the Brainrot roster read from the shared registry, current affordability,
	and which card is selected) and reports card clicks back via a callback —
	all placement logic lives in PlacementController / the server.

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

local PANEL_WIDTH = 220
local CARD_HEIGHT = 64
local CARD_PADDING = 8
local ACCENT = Color3.fromRGB(120, 200, 255)
local PANEL_BG = Color3.fromRGB(22, 24, 34)
local CARD_BG = Color3.fromRGB(36, 40, 54)
local CARD_SELECTED_BG = Color3.fromRGB(48, 78, 110)
local TEXT_COLOR = Color3.fromRGB(235, 238, 245)
local COST_AFFORD = Color3.fromRGB(255, 215, 0)
local COST_BLOCKED = Color3.fromRGB(220, 110, 110)

type Card = {
	button: TextButton,
	costLabel: TextLabel,
	definition: Types.BrainrotDefinition,
}

export type Shop = typeof(setmetatable(
	{} :: {
		frame: Frame,
		cards: { Card },
		balance: number,
		selectedId: string?,
		onCardClicked: (id: string) -> (),
	},
	Shop
))

local function styleCorner(instance: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

-- Stable display order so the roster doesn't jump around between sessions.
local function sortedDefinitions(): { Types.BrainrotDefinition }
	local list: { Types.BrainrotDefinition } = {}
	for _, definition in Brainrots.getAll() do
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

function Shop.new(frame: Frame, onCardClicked: (id: string) -> ()): Shop
	local self = setmetatable({
		frame = frame,
		cards = {},
		balance = 0,
		selectedId = nil,
		onCardClicked = onCardClicked,
	}, Shop)

	local definitions = sortedDefinitions()

	frame.Visible = true
	frame.AnchorPoint = Vector2.new(1, 0.5)
	frame.Position = UDim2.new(1, -16, 0.5, 0)
	frame.Size = UDim2.fromOffset(PANEL_WIDTH, #definitions * (CARD_HEIGHT + CARD_PADDING) + CARD_PADDING + 36)
	frame.BackgroundColor3 = PANEL_BG
	frame.BackgroundTransparency = 0.1
	styleCorner(frame, 14)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 6)
	title.Size = UDim2.new(1, -24, 0, 26)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextColor3 = ACCENT
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Brainrots"
	title.Parent = frame

	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(0, 36)
	list.Size = UDim2.new(1, 0, 1, -36)
	list.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, CARD_PADDING)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for index, definition in definitions do
		self:buildCard(list, index, definition)
	end

	self:refresh()
	return self
end

function Shop.buildCard(self: Shop, parent: Instance, order: number, definition: Types.BrainrotDefinition)
	local button = Instance.new("TextButton")
	button.Name = definition.id
	button.LayoutOrder = order
	button.AutoButtonColor = true
	button.Size = UDim2.new(1, -16, 0, CARD_HEIGHT)
	button.BackgroundColor3 = CARD_BG
	button.Text = ""
	button.Parent = parent
	styleCorner(button, 10)

	local swatch = Instance.new("Frame")
	swatch.Name = "Swatch"
	swatch.AnchorPoint = Vector2.new(0, 0.5)
	swatch.Position = UDim2.new(0, 10, 0.5, 0)
	swatch.Size = UDim2.fromOffset(36, 36)
	swatch.BackgroundColor3 = definition.color or Color3.fromRGB(180, 140, 220)
	swatch.Parent = button
	styleCorner(swatch, 8)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.new(0, 56, 0, 8)
	nameLabel.Size = UDim2.new(1, -66, 0, 24)
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextSize = 16
	nameLabel.TextColor3 = TEXT_COLOR
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = definition.name
	nameLabel.Parent = button

	local costLabel = Instance.new("TextLabel")
	costLabel.Name = "Cost"
	costLabel.BackgroundTransparency = 1
	costLabel.Position = UDim2.new(0, 56, 0, 32)
	costLabel.Size = UDim2.new(1, -66, 0, 22)
	costLabel.Font = Enum.Font.GothamBold
	costLabel.TextSize = 15
	costLabel.TextColor3 = COST_AFFORD
	costLabel.TextXAlignment = Enum.TextXAlignment.Left
	costLabel.Text = string.format("%d coins", definition.cost)
	costLabel.Parent = button

	button.Activated:Connect(function()
		self.onCardClicked(definition.id)
	end)

	table.insert(self.cards, {
		button = button,
		costLabel = costLabel,
		definition = definition,
	})
end

-- Repaints every card from the current balance + selection.
function Shop.refresh(self: Shop)
	for _, card in self.cards do
		local affordable = self.balance >= card.definition.cost
		local selected = self.selectedId == card.definition.id
		card.button.BackgroundColor3 = if selected then CARD_SELECTED_BG else CARD_BG
		card.costLabel.TextColor3 = if affordable then COST_AFFORD else COST_BLOCKED
		card.button.BackgroundTransparency = if affordable then 0 else 0.4
	end
end

function Shop.setBalance(self: Shop, amount: number)
	self.balance = amount
	self:refresh()
end

function Shop.setSelected(self: Shop, id: string?)
	self.selectedId = id
	self:refresh()
end

return Shop
