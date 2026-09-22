--!strict
--[[
	MonsterInspect
	Field stats card for clicking a monster on the local plot. Same dock as
	BrainrotInspect (right side): portrait, live HP, stats, ability blurb.
	No evolutions, XP, or Equip — monsters are not player-owned units.
	Display only.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UITheme = require(Shared.Config.UITheme)
local Types = require(Shared.Types)

local MonsterPreview = require(script.Parent.Parent.Parent.Utilities.MonsterPreview)
local MonsterInfo = require(script.Parent.Parent.Parent.Utilities.MonsterInfo)

local MonsterInspect = {}
MonsterInspect.__index = MonsterInspect

MonsterInspect.CARD_WIDTH = 380
MonsterInspect.CARD_HEIGHT = 360

local PORTRAIT = 100
local PORTRAIT_INSET = 8
local STROKE_GUTTER = 4
local BAR_H = 18
local BAR_CORNER = 9
local STATS_FILL = Color3.fromRGB(255, 255, 255)
local HP_TRACK = Color3.fromRGB(55, 50, 48)
local HP_FILL = Color3.fromRGB(90, 210, 90)
local HEADER_BG = Color3.fromRGB(235, 245, 255)

export type ShowOptions = {
	definition: Types.MonsterDefinition,
	healthModel: Model?,
}

export type InspectCard = typeof(setmetatable(
	{} :: {
		frame: Frame,
		body: ScrollingFrame,
		monsterId: string?,
		healthConn: RBXScriptConnection?,
		maxHealthConn: RBXScriptConnection?,
		destroyConn: RBXScriptConnection?,
		hpFill: Frame?,
		hpBarLabel: TextLabel?,
	},
	MonsterInspect
))

local function clearBody(body: ScrollingFrame)
	for _, child in body:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function addLabel(parent: Instance, order: number, text: string, size: number, color: Color3?, wrapped: boolean?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.LayoutOrder = order
	label.Text = text
	label.TextSize = size
	label.TextWrapped = wrapped ~= false
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	UITheme.applyOutlinedTitle(label, color or UITheme.TITLE)
	label.TextSize = size
	return label
end

local function addStatRow(parent: Instance, order: number, name: string, value: string)
	local row = Instance.new("Frame")
	row.Name = name
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 18)
	row.LayoutOrder = order
	row.Parent = parent

	local key = Instance.new("TextLabel")
	key.BackgroundTransparency = 1
	key.Size = UDim2.new(0.46, 0, 1, 0)
	key.Text = name
	key.TextSize = 13
	key.TextXAlignment = Enum.TextXAlignment.Left
	key.TextYAlignment = Enum.TextYAlignment.Center
	key.TextTruncate = Enum.TextTruncate.AtEnd
	key.Parent = row
	UITheme.applyOutlinedTitle(key, UITheme.TITLE)
	key.TextSize = 13

	local val = Instance.new("TextLabel")
	val.BackgroundTransparency = 1
	val.Position = UDim2.new(0.46, 0, 0, 0)
	val.Size = UDim2.new(0.54, 0, 1, 0)
	val.Text = value
	val.TextSize = 13
	val.TextXAlignment = Enum.TextXAlignment.Right
	val.TextYAlignment = Enum.TextYAlignment.Center
	val.TextTruncate = Enum.TextTruncate.AtEnd
	val.Parent = row
	UITheme.applyOutlinedTitle(val, UITheme.GOLD_TEXT)
	val.TextSize = 13
end

local function hpValues(definition: Types.MonsterDefinition, model: Model?): (number, number)
	local maxHp = definition.health
	local current = maxHp
	if model then
		local live = model:GetAttribute("Health")
		local liveMax = model:GetAttribute("MaxHealth")
		if type(liveMax) == "number" and liveMax > 0 then
			maxHp = liveMax
		end
		if type(live) == "number" then
			current = live
		end
	end
	return current, maxHp
end

local function applyHpBar(fill: Frame?, label: TextLabel?, current: number, maxHp: number)
	local ratio = if maxHp > 0 then math.clamp(current / maxHp, 0, 1) else 0
	if fill then
		fill.Size = UDim2.new(ratio, 0, 1, 0)
	end
	if label then
		label.Text = string.format("%d / %d", current, maxHp)
	end
end

local function makeBar(parent: Instance, order: number): (Frame, Frame, TextLabel)
	local track = Instance.new("Frame")
	track.LayoutOrder = order
	track.Size = UDim2.new(1, 0, 0, BAR_H)
	track.BackgroundColor3 = HP_TRACK
	track.BorderSizePixel = 0
	track.ClipsDescendants = false
	track.Parent = parent
	UITheme.styleCorner(track, BAR_CORNER)
	UITheme.applyStroke(track, 2)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = HP_FILL
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = 56
	fill.Parent = track
	UITheme.styleCorner(fill, BAR_CORNER)

	local barLabel = Instance.new("TextLabel")
	barLabel.Name = "Amount"
	barLabel.BackgroundTransparency = 1
	barLabel.Size = UDim2.fromScale(1, 1)
	barLabel.ZIndex = 58
	barLabel.TextSize = 12
	barLabel.TextXAlignment = Enum.TextXAlignment.Center
	barLabel.TextYAlignment = Enum.TextYAlignment.Center
	barLabel.Parent = track
	UITheme.applyOutlinedTitle(barLabel)
	barLabel.TextSize = 12

	return track, fill, barLabel
end

local function mountHeader(
	self: InspectCard,
	parent: Instance,
	definition: Types.MonsterDefinition,
	healthModel: Model?
)
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, PORTRAIT + STROKE_GUTTER)
	header.LayoutOrder = 1
	header.Parent = parent

	local portrait = Instance.new("Frame")
	portrait.Name = "Portrait"
	portrait.BackgroundColor3 = HEADER_BG
	portrait.BackgroundTransparency = 0
	portrait.BorderSizePixel = 0
	portrait.ClipsDescendants = false
	portrait.Position = UDim2.fromOffset(STROKE_GUTTER, STROKE_GUTTER)
	portrait.Size = UDim2.fromOffset(PORTRAIT, PORTRAIT)
	portrait.Parent = header
	UITheme.styleCorner(portrait, 8)
	UITheme.applyStroke(portrait, 2)

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.BackgroundColor3 = HEADER_BG
	window.BackgroundTransparency = 0
	window.BorderSizePixel = 0
	window.ClipsDescendants = true
	window.Size = UDim2.new(1, -PORTRAIT_INSET, 1, -PORTRAIT_INSET)
	window.Position = UDim2.fromOffset(math.floor(PORTRAIT_INSET / 2), math.floor(PORTRAIT_INSET / 2))
	window.Parent = portrait
	UITheme.styleCorner(window, 6)

	local preview = MonsterPreview.mount(
		window,
		definition,
		UDim2.fromScale(1, 1),
		UDim2.new(0.5, 0, 0, 0),
		true
	)
	if preview:IsA("ViewportFrame") then
		preview.BackgroundTransparency = 1
		preview.BorderSizePixel = 0
	end

	local meta = Instance.new("Frame")
	meta.Name = "Meta"
	meta.BackgroundTransparency = 1
	meta.Position = UDim2.fromOffset(PORTRAIT + 10 + STROKE_GUTTER, STROKE_GUTTER)
	meta.Size = UDim2.new(1, -(PORTRAIT + 10 + STROKE_GUTTER * 2), 1, -STROKE_GUTTER)
	meta.Parent = header

	local metaLayout = Instance.new("UIListLayout")
	metaLayout.SortOrder = Enum.SortOrder.LayoutOrder
	metaLayout.Padding = UDim.new(0, 4)
	metaLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	metaLayout.Parent = meta

	addLabel(meta, 1, definition.name, 16, nil, false)

	local hpTrack, hpFill, hpLabel = makeBar(meta, 2)
	hpTrack.Name = "HpBar"
	self.hpFill = hpFill
	self.hpBarLabel = hpLabel

	local current, maxHp = hpValues(definition, healthModel)
	applyHpBar(hpFill, hpLabel, current, maxHp)
end

function MonsterInspect.new(parent: Instance): InspectCard
	local frame = Instance.new("Frame")
	frame.Name = "MonsterInspect"
	frame.Visible = false
	frame.Size = UDim2.fromOffset(MonsterInspect.CARD_WIDTH, MonsterInspect.CARD_HEIGHT)
	frame.ZIndex = 55
	frame.Parent = parent
	UITheme.applyPanelLook(frame, UITheme.CORNER_CARD, STATS_FILL)

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(12, 12)
	body.Size = UDim2.new(1, -24, 1, -24)
	body.ScrollBarThickness = 6
	body.ScrollBarImageColor3 = UITheme.OUTLINE
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	body.CanvasSize = UDim2.new(0, 0, 0, 0)
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ZIndex = 56
	body.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = body

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, STROKE_GUTTER)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, STROKE_GUTTER)
	pad.PaddingRight = UDim.new(0, STROKE_GUTTER)
	pad.Parent = body

	return setmetatable({
		frame = frame,
		body = body,
		monsterId = nil,
		healthConn = nil,
		maxHealthConn = nil,
		destroyConn = nil,
		hpFill = nil,
		hpBarLabel = nil,
	}, MonsterInspect)
end

function MonsterInspect.dockField(self: InspectCard)
	self.frame.AnchorPoint = Vector2.new(1, 0.5)
	self.frame.Position = UDim2.new(1, -20, 0.5, 0)
end

function MonsterInspect.hide(self: InspectCard)
	self.frame.Visible = false
	self.monsterId = nil
	self.hpFill = nil
	self.hpBarLabel = nil
	if self.healthConn then
		self.healthConn:Disconnect()
		self.healthConn = nil
	end
	if self.maxHealthConn then
		self.maxHealthConn:Disconnect()
		self.maxHealthConn = nil
	end
	if self.destroyConn then
		self.destroyConn:Disconnect()
		self.destroyConn = nil
	end
end

function MonsterInspect.isOpen(self: InspectCard): boolean
	return self.frame.Visible
end

function MonsterInspect.show(self: InspectCard, opts: ShowOptions)
	self:hide()

	local definition = opts.definition
	self.monsterId = definition.id
	clearBody(self.body)
	mountHeader(self, self.body, definition, opts.healthModel)

	local order = 2
	addLabel(self.body, order, "Stats", 15)
	order += 1
	for _, row in MonsterInfo.statRows(definition) do
		if row.label ~= "Health" then
			addStatRow(self.body, order, row.label, row.value)
			order += 1
		end
	end

	addLabel(self.body, order, "Ability", 15)
	order += 1
	addLabel(self.body, order, MonsterInfo.abilitySummary(definition), 13, UITheme.TITLE, true)

	local healthModel = opts.healthModel
	if healthModel then
		local function refreshHp()
			local current, maxHp = hpValues(definition, healthModel)
			applyHpBar(self.hpFill, self.hpBarLabel, current, maxHp)
		end
		self.healthConn = healthModel:GetAttributeChangedSignal("Health"):Connect(refreshHp)
		self.maxHealthConn = healthModel:GetAttributeChangedSignal("MaxHealth"):Connect(refreshHp)
		self.destroyConn = healthModel.Destroying:Connect(function()
			self:hide()
		end)
	end

	self.frame.Visible = true
end

return MonsterInspect
