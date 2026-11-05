--!strict
--[[
	DamageMeter
	Right-rail board: Brainrots vs Monsters tabs ranked by damage this day.
	Collapsed = title + tabs; click a tab to expand. Click the active tab again
	to collapse. The list scrolls. Bars scale vs the current tab leader.
	Display only — ranks come from DamageMeterUpdated.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared.Brainrots)
local Monsters = require(Shared.Monsters)
local CombatConfig = require(Shared.Config.CombatConfig)
local UITheme = require(Shared.Config.UITheme)

local AudioController = require(script.Parent.Parent.AudioController)

local DamageMeter = {}
DamageMeter.__index = DamageMeter

local WIDTH = 240
local TITLE_H = 18
local TAB_H = 28
local ROW_H = 36
local PAD = 7
local HEADER_TOP = 4
local TITLE_TAB_GAP = 2
local TAB_BOTTOM_PAD = 4
local LIST_BOTTOM_PAD = 4
local BAR_H = 8
local BAR_CORNER = 4
local BAR_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

export type RankEntry = { id: string, damage: number }

type Row = {
	frame: Frame,
	nameLabel: TextLabel,
	damageLabel: TextLabel,
	barFill: Frame,
}

export type DamageMeterHud = typeof(setmetatable(
	{} :: {
		frame: Frame,
		brainrotTab: TextButton,
		monsterTab: TextButton,
		scroll: ScrollingFrame,
		emptyLabel: TextLabel,
		rows: { Row },
		tab: string,
		expanded: boolean,
		brainrots: { RankEntry },
		monsters: { RankEntry },
	},
	DamageMeter
))

local function headerHeight(): number
	return HEADER_TOP + TITLE_H + TITLE_TAB_GAP + TAB_H + TAB_BOTTOM_PAD
end

local function collapsedHeight(): number
	return headerHeight()
end

local function listHeight(entryCount: number): number
	local shown = math.clamp(entryCount, 1, CombatConfig.DAMAGE_METER_VISIBLE_ROWS)
	return shown * ROW_H
end

local function expandedHeight(entryCount: number): number
	return headerHeight() + listHeight(entryCount) + LIST_BOTTOM_PAD
end

local function formatDamage(amount: number): string
	local n = math.max(0, math.floor(amount + 0.5))
	if n >= 10000 then
		return string.format("%.1fk", n / 1000)
	end
	return tostring(n)
end

local function displayName(kind: string, id: string): string
	if kind == "brainrots" then
		local def = Brainrots.get(id)
		return if def then def.name else id
	end
	local def = Monsters.get(id)
	return if def then def.name else id
end

local function makeRow(parent: Instance, index: number): Row
	local frame = Instance.new("Frame")
	frame.Name = "Row" .. index
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.new(1, 0, 0, ROW_H - 4)
	frame.LayoutOrder = index
	frame.ZIndex = 14
	frame.Visible = false
	frame.Parent = parent

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromOffset(0, 0)
	nameLabel.Size = UDim2.new(1, -57, 0, 20)
	nameLabel.Text = ""
	nameLabel.TextSize = 13
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.ZIndex = 15
	nameLabel.Parent = frame
	UITheme.applyOutlinedTitle(nameLabel)
	nameLabel.TextSize = 13

	local damageLabel = Instance.new("TextLabel")
	damageLabel.Name = "Damage"
	damageLabel.BackgroundTransparency = 1
	damageLabel.AnchorPoint = Vector2.new(1, 0)
	damageLabel.Position = UDim2.new(1, 0, 0, 0)
	damageLabel.Size = UDim2.fromOffset(53, 20)
	damageLabel.Text = "0"
	damageLabel.TextSize = 13
	damageLabel.TextXAlignment = Enum.TextXAlignment.Right
	damageLabel.ZIndex = 15
	damageLabel.Parent = frame
	UITheme.applyOutlinedTitle(damageLabel, UITheme.GOLD_TEXT)
	damageLabel.TextSize = 13

	local barTrack = Instance.new("Frame")
	barTrack.Name = "BarTrack"
	barTrack.AnchorPoint = Vector2.new(0, 1)
	barTrack.Position = UDim2.new(0, 0, 1, 0)
	barTrack.Size = UDim2.new(1, 0, 0, BAR_H)
	barTrack.BackgroundColor3 = Color3.fromRGB(20, 28, 48)
	barTrack.BackgroundTransparency = 0.25
	barTrack.BorderSizePixel = 0
	barTrack.ZIndex = 15
	barTrack.ClipsDescendants = false
	barTrack.Parent = frame
	UITheme.styleCorner(barTrack, BAR_CORNER)
	UITheme.applyStroke(barTrack, 2)

	-- Fill is its own pill (same radius as the track). ClipsDescendants does not
	-- honor UICorner, so a clip mask would leave a rectangle inside the capsule.
	local barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.BackgroundColor3 = UITheme.GOLD
	barFill.BorderSizePixel = 0
	barFill.ZIndex = 16
	barFill.Parent = barTrack
	UITheme.styleCorner(barFill, BAR_CORNER)

	return {
		frame = frame,
		nameLabel = nameLabel,
		damageLabel = damageLabel,
		barFill = barFill,
	}
end

function DamageMeter.new(parent: Frame): DamageMeterHud
	local top = CombatConfig.DAMAGE_METER_TOP
	parent.Visible = true
	parent.AnchorPoint = Vector2.new(1, 0)
	parent.Position = UDim2.new(1, -16, 0.16, 0)
	parent.Size = UDim2.fromOffset(WIDTH, collapsedHeight())
	parent.ZIndex = 12
	parent.ClipsDescendants = true
	UITheme.applyPanelLook(parent, nil, UITheme.FIELD_PANEL)
	UITheme.applySurfaceDepth(parent)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(PAD, HEADER_TOP)
	title.Size = UDim2.new(1, -PAD * 2, 0, TITLE_H)
	title.Text = "DAMAGE REPORT"
	title.TextSize = 14
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.ZIndex = 13
	title.Parent = parent
	UITheme.applyOutlinedTitle(title, UITheme.FIELD_ACCENT)
	title.TextSize = 14

	local tabY = HEADER_TOP + TITLE_H + TITLE_TAB_GAP

	local brainrotTab = Instance.new("TextButton")
	brainrotTab.Name = "BrainrotsTab"
	brainrotTab.Position = UDim2.fromOffset(PAD, tabY)
	brainrotTab.Size = UDim2.new(0.5, -PAD - 4, 0, TAB_H)
	brainrotTab.Text = "Brainrots"
	brainrotTab.TextSize = 13
	brainrotTab.ZIndex = 13
	brainrotTab.Parent = parent
	UITheme.applyButtonLook(brainrotTab, UITheme.CARD_SELECTED_BG)
	UITheme.applySurfaceDepth(brainrotTab)
	UITheme.applyOutlinedTitle(brainrotTab)
	brainrotTab.TextSize = 13

	local monsterTab = Instance.new("TextButton")
	monsterTab.Name = "MonstersTab"
	monsterTab.AnchorPoint = Vector2.new(1, 0)
	monsterTab.Position = UDim2.new(1, -PAD, 0, tabY)
	monsterTab.Size = UDim2.new(0.5, -PAD - 4, 0, TAB_H)
	monsterTab.Text = "Monsters"
	monsterTab.TextSize = 13
	monsterTab.ZIndex = 13
	monsterTab.Parent = parent
	UITheme.applyButtonLook(monsterTab, UITheme.FIELD_INSET)
	UITheme.applySurfaceDepth(monsterTab)
	UITheme.applyOutlinedTitle(monsterTab)
	monsterTab.TextSize = 13

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "List"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(PAD, headerHeight())
	scroll.Size = UDim2.new(1, -PAD * 2, 0, listHeight(1))
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.fromScale(0, 0)
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = UITheme.TITLE
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	scroll.ZIndex = 13
	scroll.Visible = false
	scroll.Parent = parent

	local listPad = Instance.new("UIPadding")
	listPad.PaddingLeft = UDim.new(0, 4)
	listPad.PaddingRight = UDim.new(0, 4)
	listPad.PaddingTop = UDim.new(0, 3)
	listPad.PaddingBottom = UDim.new(0, 3)
	listPad.Parent = scroll

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = scroll

	local emptyLabel = Instance.new("TextLabel")
	emptyLabel.Name = "Empty"
	emptyLabel.BackgroundTransparency = 1
	emptyLabel.Position = UDim2.fromOffset(PAD, headerHeight())
	emptyLabel.Size = UDim2.new(1, -PAD * 2, 0, 24)
	emptyLabel.Text = "Damage will appear here"
	emptyLabel.TextSize = 14
	emptyLabel.ZIndex = 14
	emptyLabel.Visible = false
	emptyLabel.Parent = parent
	UITheme.applyOutlinedTitle(emptyLabel, UITheme.TITLE)
	emptyLabel.TextSize = 14

	local rows: { Row } = {}
	for i = 1, top do
		table.insert(rows, makeRow(scroll, i))
	end

	local self = setmetatable({
		frame = parent,
		brainrotTab = brainrotTab,
		monsterTab = monsterTab,
		scroll = scroll,
		emptyLabel = emptyLabel,
		rows = rows,
		tab = "brainrots",
		expanded = false,
		brainrots = {},
		monsters = {},
	}, DamageMeter)

	brainrotTab.Activated:Connect(function()
		self:onTabClicked("brainrots")
	end)
	monsterTab.Activated:Connect(function()
		self:onTabClicked("monsters")
	end)

	return self
end

function DamageMeter.layout(self: DamageMeterHud)
	if not self.expanded then
		self.scroll.Size = UDim2.new(1, -PAD * 2, 0, listHeight(1))
		self.frame.Size = UDim2.fromOffset(WIDTH, collapsedHeight())
		return
	end
	local list = if self.tab == "monsters" then self.monsters else self.brainrots
	local height = listHeight(#list)
	self.scroll.Size = UDim2.new(1, -PAD * 2, 0, height)
	self.frame.Size = UDim2.fromOffset(WIDTH, expandedHeight(#list))
end

function DamageMeter.setExpanded(self: DamageMeterHud, expanded: boolean)
	self.expanded = expanded
	self:refresh()
end

function DamageMeter.onTabClicked(self: DamageMeterHud, tab: string)
	AudioController.play("UiClick")
	if not self.expanded then
		self:setTab(tab)
		self:setExpanded(true)
		return
	end
	if self.tab == tab then
		self:setExpanded(false)
		return
	end
	self:setTab(tab)
end

function DamageMeter.setTab(self: DamageMeterHud, tab: string)
	self.tab = if tab == "monsters" then "monsters" else "brainrots"
	if self.tab == "brainrots" then
		UITheme.applyButtonLook(self.brainrotTab, UITheme.CARD_SELECTED_BG)
		UITheme.applyButtonLook(self.monsterTab, UITheme.FIELD_INSET)
	else
		UITheme.applyButtonLook(self.brainrotTab, UITheme.FIELD_INSET)
		UITheme.applyButtonLook(self.monsterTab, UITheme.CARD_SELECTED_BG)
	end
	self:refresh()
end

function DamageMeter.apply(self: DamageMeterHud, state: { [string]: any }?)
	if type(state) ~= "table" then
		return
	end
	local brainrots: { RankEntry } = {}
	if type(state.brainrots) == "table" then
		for _, entry in state.brainrots do
			if type(entry) == "table" and type(entry.id) == "string" and type(entry.damage) == "number" then
				table.insert(brainrots, { id = entry.id, damage = entry.damage })
			end
		end
	end
	local monsters: { RankEntry } = {}
	if type(state.monsters) == "table" then
		for _, entry in state.monsters do
			if type(entry) == "table" and type(entry.id) == "string" and type(entry.damage) == "number" then
				table.insert(monsters, { id = entry.id, damage = entry.damage })
			end
		end
	end
	self.brainrots = brainrots
	self.monsters = monsters
	self:refresh()
end

function DamageMeter.refresh(self: DamageMeterHud)
	local list = if self.tab == "monsters" then self.monsters else self.brainrots
	local showList = self.expanded
	self.emptyLabel.Visible = showList and #list == 0
	self.scroll.Visible = showList and #list > 0
	self:layout()
	if not showList then
		return
	end
	local leader = 0
	if list[1] then
		leader = list[1].damage
	end
	local fillColor = if self.tab == "monsters" then UITheme.DANGER else UITheme.GOLD
	for i, row in self.rows do
		local entry = list[i]
		if not entry then
			row.frame.Visible = false
			row.barFill.Size = UDim2.fromScale(0, 1)
			continue
		end
		row.frame.Visible = true
		row.nameLabel.Text = string.format("%d.  %s", i, displayName(self.tab, entry.id))
		row.damageLabel.Text = formatDamage(entry.damage)
		row.barFill.BackgroundColor3 = fillColor
		local alpha = 0
		if leader > 0 then
			alpha = math.clamp(entry.damage / leader, 0, 1)
		end
		TweenService:Create(row.barFill, BAR_TWEEN, {
			Size = UDim2.fromScale(alpha, 1),
		}):Play()
	end
end

return DamageMeter
