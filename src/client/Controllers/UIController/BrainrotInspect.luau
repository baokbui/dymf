--!strict
--[[
	BrainrotInspect
	Shared stats / evolution card used by Inventory (with Equip) and by clicking a
	planted Brainrot on the lawn. Header: inset portrait with name, HP bar,
	level, and XP bar. Body: Stats (cost, damage, atk. speed, range, …) + Current Evolution (white
	Common base ability, then Epic→God: gray until the level gate, then
	light rarity fill + shiny rarity title; lock until brains claim).
	Card chrome: white until a rarity is claimed, then that rarity’s title
	color with a diagonal gleam.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UITheme = require(Shared.Config.UITheme)
local EvolutionConfig = require(Shared.Config.EvolutionConfig)
local VfxConfig = require(Shared.Config.VfxConfig)
local Evolutions = require(Shared.Evolutions)
local Types = require(Shared.Types)

local BrainrotPreview = require(script.Parent.Parent.Parent.Utilities.BrainrotPreview)
local BrainrotInfo = require(script.Parent.Parent.Parent.Utilities.BrainrotInfo)
local TextShine = require(script.Parent.Parent.Parent.Utilities.TextShine)
local AudioController = require(script.Parent.Parent.AudioController)

local BrainrotInspect = {}
BrainrotInspect.__index = BrainrotInspect

BrainrotInspect.CARD_WIDTH = 380
BrainrotInspect.CARD_HEIGHT = 472

local PORTRAIT = 100
local PORTRAIT_INSET = 8
-- UIStroke sits outside the rect; clippers (ScrollingFrame, ClipsDescendants)
-- shear it unless content is inset by at least this much.
local STROKE_GUTTER = 4
local STATS_FILL = Color3.fromRGB(255, 255, 255)
local XP_TRACK = Color3.fromRGB(55, 50, 48)
local XP_FILL = Color3.fromRGB(255, 200, 55)
local HP_FILL = Color3.fromRGB(90, 210, 90)
local LOCKED_TEXT = Color3.fromRGB(155, 155, 162)
local LOCKED_FILL = Color3.fromRGB(210, 210, 216)
local COMMON_FILL = Color3.fromRGB(255, 255, 255)
local HEADER_BG = Color3.fromRGB(235, 245, 255)
-- Image asset 5944134858; ImageLabel uses the texture id.
local LOCK_ICON_TEXTURE_ID = "rbxassetid://5944134853"
local LOCK_ICON_SIZE = 40

export type InspectMode = "inventory" | "field"

export type ShowOptions = {
	definition: Types.BrainrotDefinition,
	mode: InspectMode,
	equipped: boolean?,
	loadoutLocked: boolean?,
	loadoutFull: boolean?,
	lastEquipped: boolean?,
	healthModel: Model?,
	totalXp: number?,
	claimedRarities: { string }?,
}

type EvoEntry = {
	frame: Frame,
	rarityLine: TextLabel,
	title: TextLabel,
	kindLabel: TextLabel,
	body: TextLabel,
	row: Evolutions.EvolutionRow,
	lockOverlay: Frame,
}

export type InspectCard = typeof(setmetatable(
	{} :: {
		frame: Frame,
		body: ScrollingFrame,
		equipButton: TextButton,
		onEquip: ((brainrotId: string) -> ())?,
		onHide: (() -> ())?,
		brainrotId: string?,
		healthConn: RBXScriptConnection?,
		shieldConn: RBXScriptConnection?,
		destroyConn: RBXScriptConnection?,
		hpFill: Frame?,
		hpShieldFill: Frame?,
		hpBarLabel: TextLabel?,
		levelLabel: TextLabel?,
		xpFill: Frame?,
		xpBarLabel: TextLabel?,
		evoEntries: { EvoEntry },
		claimedRarities: { string },
		brainrotLevel: number,
		onEvolve: ((brainrotId: string, rarity: string) -> ())?,
		confirmFrame: TextButton,
		confirmTitle: TextLabel,
		confirmBody: TextLabel,
		pendingRow: Evolutions.EvolutionRow?,
	},
	BrainrotInspect
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

local function hpValues(definition: Types.BrainrotDefinition, model: Model?): (number, number, boolean, number)
	if definition.ignoreMonsterChew or definition.health <= 0 or definition.maxHealth <= 0 then
		return 0, 0, true, 0
	end
	local maxHp = definition.maxHealth
	local current = maxHp
	local shield = 0
	if model then
		local live = model:GetAttribute("Health")
		local liveMax = model:GetAttribute("MaxHealth")
		local liveShield = model:GetAttribute("ShieldHp")
		if type(live) == "number" then
			current = live
		end
		if type(liveMax) == "number" and liveMax > 0 then
			maxHp = liveMax
		end
		if type(liveShield) == "number" then
			shield = math.max(0, math.floor(liveShield))
		end
	end
	return current, maxHp, false, shield
end

local function applyHpBar(
	fill: Frame?,
	shieldFill: Frame?,
	label: TextLabel?,
	current: number,
	maxHp: number,
	empty: boolean,
	shield: number
)
	if empty then
		if fill then
			fill.Size = UDim2.fromScale(0, 1)
		end
		if shieldFill then
			shieldFill.Size = UDim2.fromScale(0, 1)
			shieldFill.Visible = false
		end
		if label then
			label.Text = "—"
		end
		return
	end
	local ratio = if maxHp > 0 then math.clamp(current / maxHp, 0, 1) else 0
	local overlay = if maxHp > 0 then math.clamp(math.min(shield, current) / maxHp, 0, 1) else 0
	if fill then
		fill.Size = UDim2.new(ratio, 0, 1, 0)
	end
	if shieldFill then
		shieldFill.Position = UDim2.new(math.max(0, ratio - overlay), 0, 0, 0)
		shieldFill.Size = UDim2.new(overlay, 0, 1, 0)
		shieldFill.Visible = overlay > 0
	end
	if label then
		label.Text = string.format("%d / %d", current, maxHp)
	end
end

local function makeBar(parent: Instance, order: number, fillColor: Color3): (Frame, Frame, TextLabel)
	local track = Instance.new("Frame")
	track.LayoutOrder = order
	track.Size = UDim2.new(1, 0, 0, 18)
	track.BackgroundColor3 = XP_TRACK
	track.BorderSizePixel = 0
	track.ClipsDescendants = false
	track.Parent = parent
	UITheme.styleCorner(track, 6)
	UITheme.applyStroke(track, 2)

	-- Clip the fill to the pill without clipping the stroke on `track`.
	local clip = Instance.new("Frame")
	clip.Name = "Clip"
	clip.BackgroundTransparency = 1
	clip.BorderSizePixel = 0
	clip.ClipsDescendants = true
	clip.Size = UDim2.fromScale(1, 1)
	clip.ZIndex = 56
	clip.Parent = track
	UITheme.styleCorner(clip, 6)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = 56
	fill.Parent = clip
	UITheme.styleCorner(fill, 6)

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

local function applyXpBar(fill: Frame?, label: TextLabel?, totalXp: number)
	local breakdown = EvolutionConfig.parseXp(totalXp)
	local ratio = 1
	local text = "MAX"
	if breakdown.xpToNext > 0 then
		ratio = math.clamp(breakdown.xpIntoLevel / breakdown.xpToNext, 0, 1)
		text = string.format("%d / %d", breakdown.xpIntoLevel, breakdown.xpToNext)
	end
	if fill then
		fill.Size = UDim2.new(ratio, 0, 1, 0)
	end
	if label then
		label.Text = text
	end
end

local function clearShine(entry: EvoEntry)
	TextShine.clear(entry.frame)
	TextShine.clear(entry.rarityLine)
	TextShine.clear(entry.title)
	TextShine.clear(entry.kindLabel)
	TextShine.clear(entry.body)
end

local function applyShine(label: TextLabel, _entry: EvoEntry, dark: Color3, rainbow: boolean)
	-- Gradient is mapped to the label rect; size to the glyphs so the pass
	-- actually hits the words instead of empty space to the right.
	label.TextWrapped = false
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)
	if rainbow then
		TextShine.applyRainbow(label)
	else
		TextShine.apply(label, dark)
	end
end

local function applyCardChrome(self: InspectCard)
	local rarity = Evolutions.highestClaimedRarity(self.claimedRarities)
	TextShine.clear(self.frame)
	if not rarity then
		self.frame.BackgroundColor3 = STATS_FILL
		return
	end
	if EvolutionConfig.isRainbow(rarity) then
		TextShine.applyRainbowPanel(self.frame)
		return
	end
	TextShine.applyPanel(self.frame, EvolutionConfig.darkText(rarity))
end

local function styleEvolutionEntry(entry: EvoEntry, brainrotLevel: number, claimed: { [string]: boolean })
	local isCommon = entry.row.rarity == "Common"
	local levelReached = isCommon or Evolutions.tierUnlocked(entry.row, brainrotLevel)
	local isClaimed = isCommon or claimed[entry.row.rarity] == true
	local dark = EvolutionConfig.darkText(entry.row.rarity)
	local bodyColor = EvolutionConfig.lightText(entry.row.rarity)
	local light = EvolutionConfig.lightFill(entry.row.rarity)

	clearShine(entry)

	if isCommon then
		entry.frame.BackgroundColor3 = COMMON_FILL
		for _, label in { entry.rarityLine, entry.title, entry.kindLabel, entry.body } do
			UITheme.applyOutlinedTitle(label, UITheme.TITLE)
		end
	elseif not levelReached then
		entry.frame.BackgroundColor3 = LOCKED_FILL
		for _, label in { entry.rarityLine, entry.title, entry.kindLabel, entry.body } do
			UITheme.applyOutlinedTitle(label, LOCKED_TEXT)
		end
	else
		local rainbow = EvolutionConfig.isRainbow(entry.row.rarity)
		if rainbow then
			TextShine.applyRainbowPanel(entry.frame)
		else
			entry.frame.BackgroundColor3 = light
		end
		UITheme.applyOutlinedTitle(entry.rarityLine, dark)
		applyShine(entry.rarityLine, entry, dark, rainbow)
		for _, label in { entry.title, entry.kindLabel, entry.body } do
			UITheme.applyOutlinedTitle(label, if rainbow then Color3.new(1, 1, 1) else bodyColor)
		end
	end
	entry.rarityLine.TextSize = 12
	entry.title.TextSize = 14
	entry.kindLabel.TextSize = 12
	entry.body.TextSize = 13

	local showLock = (not isCommon) and levelReached and not isClaimed
	entry.lockOverlay.Visible = showLock
end

function BrainrotInspect.new(parent: Instance): InspectCard
	local frame = Instance.new("Frame")
	frame.Name = "BrainrotInspect"
	frame.Visible = false
	frame.Size = UDim2.fromOffset(BrainrotInspect.CARD_WIDTH, BrainrotInspect.CARD_HEIGHT)
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

	local equipButton = Instance.new("TextButton")
	equipButton.Name = "Equip"
	equipButton.AnchorPoint = Vector2.new(0.5, 1)
	equipButton.Position = UDim2.new(0.5, 0, 1, -12)
	equipButton.Size = UDim2.new(1, -28, 0, 40)
	equipButton.ZIndex = 56
	equipButton.Text = "Equip"
	equipButton.TextSize = 16
	equipButton.Visible = false
	equipButton.Parent = frame
	UITheme.applyButtonLook(equipButton, UITheme.SUCCESS)
	UITheme.applyOutlinedTitle(equipButton)

	local confirm = Instance.new("TextButton")
	confirm.Name = "EvolveConfirm"
	confirm.Visible = false
	confirm.AutoButtonColor = false
	confirm.Text = ""
	confirm.BackgroundColor3 = UITheme.MODAL_SCRIM
	confirm.BackgroundTransparency = 0.35
	confirm.BorderSizePixel = 0
	confirm.Size = UDim2.fromScale(1, 1)
	confirm.ZIndex = 80
	confirm.Parent = frame

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(300, 196)
	panel.ZIndex = 81
	panel.Parent = confirm
	UITheme.applyPanelLook(panel, UITheme.CORNER_CARD, UITheme.PANEL_BG_UNLOCK)

	local confirmTitle = Instance.new("TextLabel")
	confirmTitle.Name = "Title"
	confirmTitle.BackgroundTransparency = 1
	confirmTitle.Position = UDim2.fromOffset(14, 12)
	confirmTitle.Size = UDim2.new(1, -28, 0, 28)
	confirmTitle.ZIndex = 82
	confirmTitle.Text = "Evolve?"
	confirmTitle.TextSize = 20
	confirmTitle.Parent = panel
	UITheme.applyOutlinedTitle(confirmTitle)

	local confirmBody = Instance.new("TextLabel")
	confirmBody.Name = "Body"
	confirmBody.BackgroundTransparency = 1
	confirmBody.Position = UDim2.fromOffset(14, 44)
	confirmBody.Size = UDim2.new(1, -28, 0, 72)
	confirmBody.ZIndex = 82
	confirmBody.Text = ""
	confirmBody.TextSize = 15
	confirmBody.TextWrapped = true
	confirmBody.TextXAlignment = Enum.TextXAlignment.Left
	confirmBody.TextYAlignment = Enum.TextYAlignment.Top
	confirmBody.Parent = panel
	UITheme.applyOutlinedTitle(confirmBody)

	local cancelButton = Instance.new("TextButton")
	cancelButton.Name = "Cancel"
	cancelButton.Position = UDim2.fromOffset(14, 140)
	cancelButton.Size = UDim2.new(0.5, -20, 0, 40)
	cancelButton.ZIndex = 82
	cancelButton.Text = "Cancel"
	cancelButton.TextSize = 16
	cancelButton.Parent = panel
	UITheme.applyButtonLook(cancelButton, UITheme.SUBTEXT)
	UITheme.applyOutlinedTitle(cancelButton)

	local evolveButton = Instance.new("TextButton")
	evolveButton.Name = "Evolve"
	evolveButton.AnchorPoint = Vector2.new(1, 0)
	evolveButton.Position = UDim2.new(1, -14, 0, 140)
	evolveButton.Size = UDim2.new(0.5, -20, 0, 40)
	evolveButton.ZIndex = 82
	evolveButton.Text = "Evolve"
	evolveButton.TextSize = 16
	evolveButton.Parent = panel
	UITheme.applyButtonLook(evolveButton, UITheme.SUCCESS)
	UITheme.applyOutlinedTitle(evolveButton)

	local self = setmetatable({
		frame = frame,
		body = body,
		equipButton = equipButton,
		onEquip = nil,
		onHide = nil,
		brainrotId = nil,
		healthConn = nil,
		shieldConn = nil,
		destroyConn = nil,
		hpFill = nil,
		hpShieldFill = nil,
		hpBarLabel = nil,
		levelLabel = nil,
		xpFill = nil,
		xpBarLabel = nil,
		evoEntries = {},
		claimedRarities = {},
		brainrotLevel = 1,
		onEvolve = nil,
		confirmFrame = confirm,
		confirmTitle = confirmTitle,
		confirmBody = confirmBody,
		pendingRow = nil,
	}, BrainrotInspect)

	equipButton.MouseButton1Click:Connect(function()
		local id = self.brainrotId
		if not id or not self.onEquip then
			return
		end
		if not self.equipButton.Active then
			return
		end
		AudioController.play("UiClick")
		self.onEquip(id)
	end)

	cancelButton.MouseButton1Click:Connect(function()
		AudioController.play("UiClick")
		self:hideEvolveConfirm()
	end)

	confirm.MouseButton1Click:Connect(function()
		self:hideEvolveConfirm()
	end)

	evolveButton.MouseButton1Click:Connect(function()
		local id = self.brainrotId
		local row = self.pendingRow
		if not id or not row or not self.onEvolve then
			self:hideEvolveConfirm()
			return
		end
		AudioController.play("UiClick")
		self.onEvolve(id, row.rarity)
		self:hideEvolveConfirm()
	end)

	return self
end

function BrainrotInspect.setEquipHandler(self: InspectCard, handler: ((brainrotId: string) -> ())?)
	self.onEquip = handler
end

function BrainrotInspect.setEvolveHandler(self: InspectCard, handler: ((brainrotId: string, rarity: string) -> ())?)
	self.onEvolve = handler
end

function BrainrotInspect.hideEvolveConfirm(self: InspectCard)
	self.pendingRow = nil
	self.confirmFrame.Visible = false
end

function BrainrotInspect.showEvolveConfirm(self: InspectCard, row: Evolutions.EvolutionRow)
	local cost = EvolutionConfig.brainsCost(row.rarity)
	self.pendingRow = row
	self.confirmTitle.Text = string.format("Evolve to %s?", EvolutionConfig.displayName(row.rarity))
	self.confirmBody.Text = string.format(
		"Spend %d brains to unlock %s?",
		cost,
		row.name
	)
	self.confirmFrame.Visible = true
end

function BrainrotInspect.hide(self: InspectCard)
	self.frame.Visible = false
	self.brainrotId = nil
	self.hpFill = nil
	self.hpShieldFill = nil
	self.hpBarLabel = nil
	self.levelLabel = nil
	self.xpFill = nil
	self.xpBarLabel = nil
	for _, entry in self.evoEntries do
		clearShine(entry)
	end
	self.evoEntries = {}
	self.claimedRarities = {}
	self.brainrotLevel = 1
	TextShine.clear(self.frame)
	self.frame.BackgroundColor3 = STATS_FILL
	self:hideEvolveConfirm()
	if self.healthConn then
		self.healthConn:Disconnect()
		self.healthConn = nil
	end
	if self.shieldConn then
		self.shieldConn:Disconnect()
		self.shieldConn = nil
	end
	if self.destroyConn then
		self.destroyConn:Disconnect()
		self.destroyConn = nil
	end
	if self.onHide then
		self.onHide()
	end
end

function BrainrotInspect.isOpen(self: InspectCard): boolean
	return self.frame.Visible
end

function BrainrotInspect.getBrainrotId(self: InspectCard): string?
	return self.brainrotId
end

function BrainrotInspect.setTotalXp(self: InspectCard, totalXp: number)
	local breakdown = EvolutionConfig.parseXp(totalXp)
	self.brainrotLevel = breakdown.level
	if self.levelLabel then
		self.levelLabel.Text = string.format("Level %d", breakdown.level)
	end
	applyXpBar(self.xpFill, self.xpBarLabel, totalXp)
	local claimed = Evolutions.claimedSet(self.claimedRarities)
	for _, entry in self.evoEntries do
		styleEvolutionEntry(entry, breakdown.level, claimed)
	end
end

function BrainrotInspect.setClaimedRarities(self: InspectCard, rarities: { string })
	self.claimedRarities = rarities
	applyCardChrome(self)
	local claimed = Evolutions.claimedSet(rarities)
	for _, entry in self.evoEntries do
		styleEvolutionEntry(entry, self.brainrotLevel, claimed)
	end
end

function BrainrotInspect.dockField(self: InspectCard)
	self.frame.AnchorPoint = Vector2.new(1, 0.5)
	self.frame.Position = UDim2.new(1, -20, 0.5, 0)
end

function BrainrotInspect.dockInventory(self: InspectCard, gap: number)
	self.frame.AnchorPoint = Vector2.new(0, 0.5)
	self.frame.Position = UDim2.new(1, gap, 0.5, 0)
end

function BrainrotInspect.applyEquipState(
	self: InspectCard,
	opts: {
		equipped: boolean,
		loadoutLocked: boolean,
		loadoutFull: boolean,
		lastEquipped: boolean,
	}
)
	local button = self.equipButton
	button.Visible = true
	if opts.loadoutLocked then
		button.Text = "LOCKED"
		button.Active = false
		UITheme.applyButtonLook(button, UITheme.SUBTEXT)
	elseif opts.equipped then
		button.Text = "Equipped"
		button.Active = not opts.lastEquipped
		UITheme.applyButtonLook(button, if opts.lastEquipped then UITheme.SUBTEXT else UITheme.SUCCESS)
	elseif opts.loadoutFull then
		button.Text = "Loadout full"
		button.Active = false
		UITheme.applyButtonLook(button, UITheme.SUBTEXT)
	else
		button.Text = "Equip"
		button.Active = true
		UITheme.applyButtonLook(button, UITheme.SUCCESS)
	end
	UITheme.applyOutlinedTitle(button)
	button.TextSize = 16
end

local function mountHeader(
	self: InspectCard,
	parent: Instance,
	definition: Types.BrainrotDefinition,
	healthModel: Model?,
	totalXp: number
)
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, PORTRAIT + STROKE_GUTTER)
	header.LayoutOrder = 1
	header.Parent = parent

	-- Stroke lives on this frame; an inner clip window holds the viewport so
	-- ClipsDescendants cannot shear the outline.
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

	local preview = BrainrotPreview.mount(
		window,
		definition,
		UDim2.fromScale(1, 1),
		UDim2.new(0.5, 0, 0, 0)
	)
	if preview:IsA("ViewportFrame") or preview:IsA("Frame") then
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

	local hpTrack, hpFill, hpLabel = makeBar(meta, 2, HP_FILL)
	hpTrack.Name = "HpBar"
	self.hpFill = hpFill
	self.hpBarLabel = hpLabel

	local shieldFill = Instance.new("Frame")
	shieldFill.Name = "ShieldFill"
	shieldFill.BackgroundColor3 = VfxConfig.SHIELD_HP_FILL
	shieldFill.BorderSizePixel = 0
	shieldFill.Size = UDim2.fromScale(0, 1)
	shieldFill.ZIndex = 57
	shieldFill.Visible = false
	local clip = hpTrack:FindFirstChild("Clip")
	if clip and clip:IsA("Frame") then
		shieldFill.Parent = clip
	end
	self.hpShieldFill = shieldFill

	local current, maxHp, empty, shield = hpValues(definition, healthModel)
	applyHpBar(hpFill, shieldFill, hpLabel, current, maxHp, empty, shield)

	local gap = Instance.new("Frame")
	gap.Name = "LevelGap"
	gap.LayoutOrder = 3
	gap.BackgroundTransparency = 1
	gap.BorderSizePixel = 0
	gap.Size = UDim2.new(1, 0, 0, 8)
	gap.Parent = meta

	local breakdown = EvolutionConfig.parseXp(totalXp)
	self.levelLabel = addLabel(meta, 4, string.format("Level %d", breakdown.level), 13, nil, false)

	local xpTrack, xpFill, xpLabel = makeBar(meta, 5, XP_FILL)
	xpTrack.Name = "XpBar"
	self.xpFill = xpFill
	self.xpBarLabel = xpLabel
	applyXpBar(xpFill, xpLabel, totalXp)
end

local function addEvolutionRow(
	self: InspectCard,
	parent: Instance,
	row: Evolutions.EvolutionRow,
	brainrotLevel: number,
	order: number
)
	local frame = Instance.new("Frame")
	frame.Name = row.rarity
	frame.LayoutOrder = order
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Size = UDim2.new(1, 0, 0, 52)
	frame.BackgroundColor3 = LOCKED_FILL
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = false
	frame.Parent = parent
	UITheme.styleCorner(frame, 8)
	UITheme.applyStroke(frame, 2)

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = frame

	local col = Instance.new("Frame")
	col.BackgroundTransparency = 1
	col.AutomaticSize = Enum.AutomaticSize.Y
	col.Size = UDim2.new(1, 0, 0, 0)
	col.Parent = frame

	local colLayout = Instance.new("UIListLayout")
	colLayout.SortOrder = Enum.SortOrder.LayoutOrder
	colLayout.Padding = UDim.new(0, 2)
	colLayout.Parent = col

	local rarityLine = addLabel(col, 1, string.format("%s - level %d", EvolutionConfig.displayName(row.rarity), row.level), 12, nil, false)
	rarityLine.AutomaticSize = Enum.AutomaticSize.XY
	rarityLine.Size = UDim2.fromOffset(0, 0)
	local title = addLabel(col, 2, row.name, 14)
	local kindLabel = addLabel(col, 3, Evolutions.kindFor(row.rarity), 12)
	local body = addLabel(col, 4, row.description, 13)

	local overlay = Instance.new("Frame")
	overlay.Name = "LockOverlay"
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	-- Offset height matching the text column — a Y scale of 1 on an
	-- AutomaticSize row stretches the tab to the ScrollingFrame viewport.
	overlay.Size = UDim2.new(1, 0, 0, 0)
	overlay.ZIndex = 58
	overlay.Visible = false
	overlay.Parent = frame

	local function fitLockOverlay()
		overlay.Size = UDim2.new(1, 0, 0, col.AbsoluteSize.Y)
	end
	col:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitLockOverlay)
	fitLockOverlay()

	local lock = Instance.new("ImageLabel")
	lock.Name = "Lock"
	lock.BackgroundTransparency = 1
	lock.AnchorPoint = Vector2.new(0.5, 0.5)
	lock.Position = UDim2.fromScale(0.5, 0.5)
	lock.Size = UDim2.fromOffset(LOCK_ICON_SIZE, LOCK_ICON_SIZE)
	lock.Image = LOCK_ICON_TEXTURE_ID
	lock.ScaleType = Enum.ScaleType.Fit
	lock.ZIndex = 59
	lock.Parent = overlay

	local hit = Instance.new("TextButton")
	hit.Name = "Claim"
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 61
	hit.Parent = overlay

	local entry: EvoEntry = {
		frame = frame,
		rarityLine = rarityLine,
		title = title,
		kindLabel = kindLabel,
		body = body,
		row = row,
		lockOverlay = overlay,
	}

	hit.MouseButton1Click:Connect(function()
		if not overlay.Visible then
			return
		end
		AudioController.play("UiClick")
		self:showEvolveConfirm(row)
	end)

	table.insert(self.evoEntries, entry)
	styleEvolutionEntry(entry, brainrotLevel, Evolutions.claimedSet(self.claimedRarities))
end

local function mountEvolutions(
	self: InspectCard,
	parent: Instance,
	definition: Types.BrainrotDefinition,
	brainrotLevel: number,
	order: number
): number
	addLabel(parent, order, "Current Evolution", 15)
	order += 1

	local common: Evolutions.EvolutionRow = {
		rarity = "Common",
		level = 1,
		name = BrainrotInfo.abilityLabel(definition.ability),
		description = BrainrotInfo.abilityDescription(definition.ability),
	}
	addEvolutionRow(self, parent, common, brainrotLevel, order)
	order += 1

	local rows = Evolutions.rowsFor(definition.id)
	if #rows == 0 then
		addLabel(parent, order, "Further evolutions for this Brainrot are coming later.", 13, LOCKED_TEXT)
		return order + 1
	end

	for _, row in rows do
		addEvolutionRow(self, parent, row, brainrotLevel, order)
		order += 1
	end

	return order
end

function BrainrotInspect.show(self: InspectCard, opts: ShowOptions)
	if self.healthConn then
		self.healthConn:Disconnect()
		self.healthConn = nil
	end
	if self.shieldConn then
		self.shieldConn:Disconnect()
		self.shieldConn = nil
	end
	if self.destroyConn then
		self.destroyConn:Disconnect()
		self.destroyConn = nil
	end
	self.hpFill = nil
	self.hpShieldFill = nil
	self.hpBarLabel = nil
	self.levelLabel = nil
	self.xpFill = nil
	self.xpBarLabel = nil
	for _, entry in self.evoEntries do
		clearShine(entry)
	end
	self.evoEntries = {}
	self.claimedRarities = opts.claimedRarities or {}
	applyCardChrome(self)
	self:hideEvolveConfirm()

	local definition = Evolutions.applyStats(opts.definition, self.claimedRarities)
	local totalXp = opts.totalXp or 0
	self.brainrotId = definition.id
	self.brainrotLevel = EvolutionConfig.parseXp(totalXp).level
	clearBody(self.body)

	mountHeader(self, self.body, definition, opts.healthModel, totalXp)

	local order = 2
	addLabel(self.body, order, "Stats", 15)
	order += 1
	for _, row in BrainrotInfo.statRows(definition) do
		-- HP is already in the header bar.
		if row.label ~= "Health" then
			addStatRow(self.body, order, row.label, row.value)
			order += 1
		end
	end

	local level = EvolutionConfig.parseXp(totalXp).level
	mountEvolutions(self, self.body, definition, level, order)

	if opts.mode == "inventory" then
		self:applyEquipState({
			equipped = opts.equipped == true,
			loadoutLocked = opts.loadoutLocked == true,
			loadoutFull = opts.loadoutFull == true,
			lastEquipped = opts.lastEquipped == true,
		})
		self.body.Size = UDim2.new(1, -24, 1, -64)
	else
		self.equipButton.Visible = false
		self.body.Size = UDim2.new(1, -24, 1, -24)
	end

	local healthModel = opts.healthModel
	if opts.mode == "field" and healthModel then
		local function refreshHp()
			local current, maxHp, empty, shield = hpValues(definition, healthModel)
			applyHpBar(self.hpFill, self.hpShieldFill, self.hpBarLabel, current, maxHp, empty, shield)
		end
		self.healthConn = healthModel:GetAttributeChangedSignal("Health"):Connect(refreshHp)
		self.shieldConn = healthModel:GetAttributeChangedSignal("ShieldHp"):Connect(refreshHp)
		self.destroyConn = healthModel.Destroying:Connect(function()
			self:hide()
		end)
	end

	self.frame.Visible = true
end

return BrainrotInspect
