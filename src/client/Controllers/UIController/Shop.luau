--!strict
--[[
	Shop
	Builds and manages the Shop panel for UIController. Display-only;
	placement lives in PlacementController / the server.

	Look: cartoon thick-outline (Shared.Config.UITheme), with lighter card
	chrome so previews stay readable.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared.Brainrots)
local Evolutions = require(Shared.Evolutions)
local BrainrotConfig = require(Shared.Config.BrainrotConfig)
local EvolutionConfig = require(Shared.Config.EvolutionConfig)
local UITheme = require(Shared.Config.UITheme)
local PanelPattern = require(script.Parent.Parent.Parent.Utilities.PanelPattern)
local Types = require(Shared.Types)

local BrainrotPreview = require(script.Parent.Parent.Parent.Utilities.BrainrotPreview)
local TextShine = require(script.Parent.Parent.Parent.Utilities.TextShine)
local PlotUtil = require(script.Parent.Parent.Parent.Utilities.PlotUtil)
local PlantCost = require(Shared.Utilities.PlantCost)

local ShovelIcon = require(script.Parent.Parent.Parent.Utilities.ShovelIcon)
local UISizing = require(script.Parent.Parent.Parent.Utilities.UISizing)
local Shop = {}
Shop.__index = Shop

local CARD_WIDTH = 80
local CARD_HEIGHT = 102
local CARD_PADDING = 7
local PANEL_PADDING_X = 9
local PANEL_PADDING_Y = 6
local SWATCH_SIZE = 40
local CARD_STROKE = 2
local HEADER_HEIGHT = 17
local PANEL_HEIGHT = HEADER_HEIGHT + CARD_HEIGHT + PANEL_PADDING_Y * 2
local PANEL_CORNER_RADIUS = UITheme.CORNER_PANEL
local NAME_TEXT_SIZE = 12
local NAME_MAX_WIDTH = CARD_WIDTH - 8
local NAME_HEIGHT = 24
local COUNT_HEIGHT = 12
local COUNT_TEXT_SIZE = 11

local TOOL_COLUMN_WIDTH = 44
local CANCEL_SIZE = 56
local TOOL_BUTTON_HEIGHT = 44

type Card = {
	button: TextButton,
	costLabel: TextLabel,
	nameLabel: TextLabel,
	countLabel: TextLabel?,
	cooldownCover: Frame,
	cooldownLabel: TextLabel,
	definition: Types.BrainrotDefinition,
	chromeKey: string,
}

export type ShopCallbacks = {
	onCardClicked: (id: string) -> (),
	onShovelClicked: () -> (),
	onCancelClicked: () -> (),
}

export type Shop = typeof(setmetatable(
	{} :: {
		frame: Frame,
		list: ScrollingFrame,
		resizePanel: (number?) -> (),
		cards: { Card },
		balance: number,
		selectedId: string?,
		equippedIds: { string },
		-- brainrotId → readyAt (Workspace:GetServerTimeNow)
		plantReadyAt: { [string]: number },
		evolutions: { [string]: { string } },
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
		if definition.hidden == true then
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

local function sameIdList(a: { string }, b: { string }): boolean
	if #a ~= #b then
		return false
	end
	for index, id in a do
		if b[index] ~= id then
			return false
		end
	end
	return true
end

local function sameEvolutions(a: { [string]: { string } }, b: { [string]: { string } }): boolean
	local count = 0
	for key, rarities in a do
		count += 1
		local other = b[key]
		if type(other) ~= "table" or not sameIdList(rarities, other) then
			return false
		end
	end
	local otherCount = 0
	for _ in b do
		otherCount += 1
	end
	return count == otherCount
end

local function passthrough(gui: GuiObject)
	gui.Active = false
end

-- Keep card width: if the name doesn't fit, put the rest under the first word.
local function shopDisplayName(name: string): string
	local bounds = TextService:GetTextSize(name, NAME_TEXT_SIZE, Enum.Font.GothamBold, Vector2.new(1000, 32))
	if bounds.X <= NAME_MAX_WIDTH then
		return name
	end
	local first, rest = string.match(name, "^(%S+)%s+(.+)$")
	if first and rest then
		return first .. "\n" .. rest
	end
	return name
end

function Shop.new(frame: Frame, callbacks: ShopCallbacks): Shop
	local screen = frame.Parent :: GuiBase2d
	local cardCount = 0
	local function resizePanel(count: number?)
		if count then cardCount = count end
		local cardsWidth = math.max(0, cardCount * (CARD_WIDTH + CARD_PADDING) - CARD_PADDING)
		local desiredWidth = math.max(160, PANEL_PADDING_X * 2 + TOOL_COLUMN_WIDTH + CARD_PADDING + cardsWidth)
		local available = screen.AbsoluteSize.X / UISizing.desktop(screen.AbsoluteSize)
		local gutter = PANEL_PADDING_X + CANCEL_SIZE
		frame.Size = UDim2.fromOffset(math.min(desiredWidth, math.max(160, available - 2 * gutter)), PANEL_HEIGHT)
	end
	local self = setmetatable({
		resizePanel = resizePanel,
		frame = frame,
		cards = {},
		balance = 0,
		selectedId = nil,
		equippedIds = {},
		plantReadyAt = {},
		evolutions = {},
		callbacks = callbacks,
	}, Shop) :: Shop

	frame.Visible = true
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 0)
	frame.BackgroundTransparency = 1
	frame.ClipsDescendants = false
	resizePanel(nil)
	local resizeConnection = screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() resizePanel(nil) end)
	frame.Destroying:Once(function() resizeConnection:Disconnect() end)

	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.AnchorPoint = Vector2.new(0.5, 0)
	bg.Position = UDim2.new(0.5, 0, 0, -PANEL_CORNER_RADIUS)
	bg.Size = UDim2.new(1, 0, 1, PANEL_CORNER_RADIUS)
	bg.BorderSizePixel = 0
	bg.Parent = frame
	UITheme.applyPanelLook(bg, PANEL_CORNER_RADIUS, UITheme.FIELD_PLANTING)
	UITheme.applySurfaceDepth(bg)
	PanelPattern.mount(bg, "Diagonal", UITheme.FIELD_ACCENT, 0.13, 6)

	local heading = Instance.new("TextLabel")
	heading.Name = "LoadoutTitle"
	heading.BackgroundTransparency = 1
	heading.Position, heading.Size = UDim2.fromOffset(PANEL_PADDING_X, 2), UDim2.new(1, -2 * PANEL_PADDING_X, 0, HEADER_HEIGHT)
	heading.Text, heading.TextSize = "PLANTING LOADOUT", 12
	heading.TextXAlignment = Enum.TextXAlignment.Left
	UITheme.applyOutlinedTitle(heading, UITheme.FIELD_ACCENT)
	heading.Parent = frame

	local tools = Instance.new("Frame")
	tools.Name = "Tools"
	tools.BackgroundColor3 = UITheme.FIELD_INSET
	tools.BorderSizePixel = 0
	UITheme.styleCorner(tools, UITheme.CORNER_CARD)
	tools.Position = UDim2.fromOffset(PANEL_PADDING_X, HEADER_HEIGHT + PANEL_PADDING_Y)
	tools.Size = UDim2.fromOffset(TOOL_COLUMN_WIDTH, TOOL_BUTTON_HEIGHT + 20)
	tools.Parent = frame

	local toolLabel = Instance.new("TextLabel")
	toolLabel.Name = "ToolLabel"
	toolLabel.BackgroundTransparency = 1
	toolLabel.Position, toolLabel.Size = UDim2.fromOffset(0, TOOL_BUTTON_HEIGHT + 2), UDim2.new(1, 0, 0, 16)
	toolLabel.Text, toolLabel.TextSize = "Shovel", 11
	UITheme.applyOutlinedTitle(toolLabel, UITheme.FIELD_TEXT)
	toolLabel.Parent = tools

	local shovelButton = self:buildShovelButton(tools)
	self.shovelButton = shovelButton

	-- Large cancel sits left of the dock so it's easy to hit (not a tiny half-cell).
	local cancelButton = self:buildCancelButton(frame)
	self.cancelButton = cancelButton

	local list = Instance.new("ScrollingFrame")
	list.BorderSizePixel = 0
	list.ScrollingDirection = Enum.ScrollingDirection.X
	list.AutomaticCanvasSize = Enum.AutomaticSize.X
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 4
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(PANEL_PADDING_X + TOOL_COLUMN_WIDTH + CARD_PADDING - CARD_STROKE, HEADER_HEIGHT)
	list.Size = UDim2.new(1, -(PANEL_PADDING_X * 2 + TOOL_COLUMN_WIDTH + CARD_PADDING) + 2 * CARD_STROKE, 1, -HEADER_HEIGHT)
	list.Parent = frame
	self.list = list

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, CARD_STROKE)
	padding.PaddingRight = UDim.new(0, CARD_STROKE)
	padding.Parent = list

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

	ShovelIcon.mount(button)

	button.Activated:Connect(function()
		self.callbacks.onShovelClicked()
	end)

	return button
end

function Shop.buildCancelButton(self: Shop, parent: Instance): TextButton
	local button = Instance.new("TextButton")
	button.Name = "Cancel"
	button.AutoButtonColor = true
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(0, -PANEL_PADDING_X, 0, HEADER_HEIGHT + PANEL_PADDING_Y + (CARD_HEIGHT - CANCEL_SIZE) / 2)
	button.Size = UDim2.fromOffset(CANCEL_SIZE, CANCEL_SIZE)
	button.TextSize = 28
	button.Text = "X"
	button.Visible = false
	button.ZIndex = 20
	button.Parent = parent
	UITheme.applyButtonLook(button, UITheme.CANCEL)
	UITheme.applyOutlinedTitle(button)
	button.TextSize = 28

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

-- Claimed rarity fills the card with the saturated aura (not the dark
-- inspect mix) plus the top-left → bottom-right gleam. No claim stays yellow.
local function applyCardChrome(button: GuiObject, claimed: { string }?, selected: boolean)
	local rarity = Evolutions.highestClaimedRarity(claimed)
	TextShine.clear(button)
	if not rarity then
		button.BackgroundColor3 = if selected then UITheme.CARD_SELECTED_BG else UITheme.CARD_BG
		return
	end
	if EvolutionConfig.isRainbow(rarity) then
		TextShine.applyRainbowPanel(button)
		return
	end
	TextShine.applyPanel(button, EvolutionConfig.worldAura(rarity))
end

local function cardChromeKey(claimed: { string }?, selected: boolean): string
	local rarity = Evolutions.highestClaimedRarity(claimed)
	if rarity then
		return rarity
	end
	return if selected then "selected" else "plain"
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
		UDim2.new(0.5, 0, 0, 4)
	)
	-- Soft inset only — no second black ring inside the card.
	UITheme.styleCorner(preview, 8)
	if preview:IsA("ViewportFrame") then
		preview.BackgroundTransparency = 0.45
	end
	passthrough(preview)

	local cap = definition.maxOnPlot
	local hasCap = type(cap) == "number" and cap > 0
	local nameTop = 4 + SWATCH_SIZE

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.BackgroundTransparency = 1
	nameLabel.AnchorPoint = Vector2.new(0.5, 0)
	nameLabel.Position = UDim2.new(0.5, 0, 0, nameTop)
	nameLabel.Size = UDim2.new(1, -6, 0, NAME_HEIGHT)
	nameLabel.TextSize = NAME_TEXT_SIZE
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextYAlignment = Enum.TextYAlignment.Center
	nameLabel.TextWrapped = true
	nameLabel.TextTruncate = Enum.TextTruncate.None
	nameLabel.Text = shopDisplayName(definition.name)
	nameLabel.Parent = button
	passthrough(nameLabel)
	UITheme.applyOutlinedTitle(nameLabel, UITheme.TITLE)
	local nameSize = Instance.new("UITextSizeConstraint")
	nameSize.MinTextSize, nameSize.MaxTextSize = 8, NAME_TEXT_SIZE
	nameSize.Parent = nameLabel
	nameLabel.TextScaled = true

	local countLabel: TextLabel? = nil
	if hasCap and type(cap) == "number" then
		local count = Instance.new("TextLabel")
		count.Name = "PlotCount"
		count.BackgroundTransparency = 1
		count.AnchorPoint = Vector2.new(0.5, 0)
		count.Position = UDim2.new(0.5, 0, 0, nameTop + NAME_HEIGHT)
		count.Size = UDim2.new(1, -6, 0, COUNT_HEIGHT)
		count.TextSize = COUNT_TEXT_SIZE
		count.TextXAlignment = Enum.TextXAlignment.Center
		count.TextYAlignment = Enum.TextYAlignment.Center
		count.Text = string.format("0/%d", cap)
		count.Parent = button
		passthrough(count)
		UITheme.applyOutlinedTitle(count, UITheme.TITLE)
		count.TextSize = COUNT_TEXT_SIZE
		countLabel = count
	end

	local costLabel = Instance.new("TextLabel")
	costLabel.Name = "Cost"
	costLabel.BackgroundColor3 = UITheme.COIN_PILL
	costLabel.BorderSizePixel = 0
	UITheme.styleCorner(costLabel, 7)
	costLabel.AnchorPoint = Vector2.new(0.5, 1)
	costLabel.Position = UDim2.new(0.5, 0, 1, -4)
	costLabel.Size = UDim2.new(1, -10, 0, 17)
	costLabel.TextSize = 12
	costLabel.TextXAlignment = Enum.TextXAlignment.Center
	costLabel.Text = string.format("%d coins", definition.cost)
	costLabel.Parent = button
	passthrough(costLabel)
	UITheme.applyOutlinedTitle(costLabel, UITheme.GOLD_TEXT)
	costLabel.Font = Enum.Font.GothamBold
	costLabel.TextSize = 12

	local cooldownCover = Instance.new("Frame")
	cooldownCover.Name = "CooldownCover"
	cooldownCover.AnchorPoint = Vector2.new(0, 1)
	cooldownCover.Position = UDim2.fromScale(0, 1)
	cooldownCover.Size = UDim2.fromScale(1, 0)
	cooldownCover.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
	cooldownCover.BackgroundTransparency = 0.35
	cooldownCover.BorderSizePixel = 0
	cooldownCover.ZIndex = 5
	cooldownCover.Visible = false
	cooldownCover.Active = false
	cooldownCover.Parent = button
	UITheme.styleCorner(cooldownCover, UITheme.CORNER_CARD)

	local cooldownLabel = Instance.new("TextLabel")
	cooldownLabel.Name = "CooldownLabel"
	cooldownLabel.BackgroundTransparency = 1
	cooldownLabel.Size = UDim2.fromScale(1, 1)
	cooldownLabel.TextSize = 16
	cooldownLabel.Text = ""
	cooldownLabel.ZIndex = 6
	cooldownLabel.Visible = false
	cooldownLabel.Active = false
	cooldownLabel.Parent = button
	UITheme.applyOutlinedTitle(cooldownLabel, UITheme.TITLE)
	cooldownLabel.TextSize = 16

	button.Activated:Connect(function()
		self.callbacks.onCardClicked(definition.id)
	end)

	table.insert(self.cards, {
		button = button,
		costLabel = costLabel,
		nameLabel = nameLabel,
		countLabel = countLabel,
		cooldownCover = cooldownCover,
		cooldownLabel = cooldownLabel,
		definition = definition,
		chromeKey = "",
	})
end

function Shop.refresh(self: Shop)
	local now = workspace:GetServerTimeNow()
	for _, card in self.cards do
		local readyAt = self.plantReadyAt[card.definition.id]
		local remaining = if type(readyAt) == "number" then readyAt - now else 0
		local onCooldown = remaining > 0
		local plantCost = PlantCost.coins(card.definition.cost, PlotUtil.getLocalPlotModel())
		local affordable = self.balance >= plantCost
		local selected = self.selectedId == card.definition.id
		local claimed = self.evolutions[card.definition.id]
		local showSelected = selected and not onCooldown
		local chromeKey = cardChromeKey(claimed, showSelected)
		if card.chromeKey ~= chromeKey then
			card.chromeKey = chromeKey
			applyCardChrome(card.button, claimed, showSelected)
		end
		UITheme.applyStroke(card.button, if showSelected then UITheme.STROKE_PANEL else CARD_STROKE)
		card.button.BackgroundTransparency = if (affordable and not onCooldown) then 0 else 0.35
		if affordable and not onCooldown then
			UITheme.applyOutlinedTitle(card.costLabel, UITheme.GOLD_TEXT)
		else
			UITheme.applyOutlinedTitle(card.costLabel, UITheme.DANGER)
		end
		card.costLabel.TextSize = 12
		card.costLabel.Text = string.format("%d coins", plantCost)
		local countLabel = card.countLabel
		local cap = card.definition.maxOnPlot
		if countLabel and type(cap) == "number" and cap > 0 then
			local planted = PlotUtil.countOnLocalPlot(card.definition.id)
			countLabel.Text = string.format("%d/%d", planted, cap)
			UITheme.applyOutlinedTitle(
				countLabel,
				if planted >= cap then UITheme.DANGER else UITheme.TITLE
			)
			countLabel.TextSize = COUNT_TEXT_SIZE
		end

		if onCooldown then
			local duration = BrainrotConfig.plantCooldownFor(
				Evolutions.applyStats(card.definition, self.evolutions[card.definition.id])
			)
			local fraction = if duration > 0 then math.clamp(remaining / duration, 0, 1) else 0
			card.cooldownCover.Visible = true
			card.cooldownCover.Size = UDim2.fromScale(1, fraction)
			card.cooldownLabel.Visible = true
			card.cooldownLabel.Text = string.format("%d", math.ceil(remaining))
		else
			card.cooldownCover.Visible = false
			card.cooldownCover.Size = UDim2.fromScale(1, 0)
			card.cooldownLabel.Visible = false
			card.cooldownLabel.Text = ""
			if type(readyAt) == "number" then
				self.plantReadyAt[card.definition.id] = nil
			end
		end
	end
end

function Shop.setEvolutions(self: Shop, evolutions: { [string]: { string } }?)
	local nextEvo: { [string]: { string } } = if type(evolutions) == "table" then evolutions else {}
	if sameEvolutions(self.evolutions, nextEvo) then
		return
	end
	self.evolutions = nextEvo
	self:refresh()
end

function Shop.setPlantCooldowns(self: Shop, readyAtById: { [string]: number }?)
	self.plantReadyAt = {}
	if type(readyAtById) == "table" then
		for id, readyAt in readyAtById do
			if type(id) == "string" and type(readyAt) == "number" then
				self.plantReadyAt[id] = readyAt
			end
		end
	end
	self:refresh()
end

function Shop.isOnCooldown(self: Shop, brainrotId: string): boolean
	local readyAt = self.plantReadyAt[brainrotId]
	return type(readyAt) == "number" and readyAt > workspace:GetServerTimeNow()
end

function Shop.setEquipped(self: Shop, ids: { string })
	-- ProfileUpdated used to remount every card (ViewportFrames included) on
	-- XP / kill ticks. Destroying the TextButton mid-click drops Activated.
	if sameIdList(self.equippedIds, ids) then
		return
	end
	self.equippedIds = table.clone(ids)
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
	self.resizePanel(#definitions)

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
