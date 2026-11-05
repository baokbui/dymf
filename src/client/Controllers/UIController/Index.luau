--!strict
--[[
	Index
	Catalog of every Brainrot and Monster. Encountered units show a portrait;
	the rest are black silhouettes with a question mark. Display-only.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared.Brainrots)
local Monsters = require(Shared.Monsters)
local Levels = require(Shared.Levels)
local UITheme = require(Shared.Config.UITheme)
local Types = require(Shared.Types)

local BrainrotPreview = require(script.Parent.Parent.Parent.Utilities.BrainrotPreview)
local MonsterPreview = require(script.Parent.Parent.Parent.Utilities.MonsterPreview)
local AudioController = require(script.Parent.Parent.AudioController)

local Index = {}
Index.__index = Index

local CELL_WIDTH = 108
local CELL_HEIGHT = 132
local CELL_PAD = 12
local PREVIEW_SIZE = 78
local INDEX_WIDTH = 560
local INDEX_HEIGHT = 520
local SILHOUETTE = Color3.fromRGB(10, 10, 14)
local TAB_BRAINROTS = "brainrots"
local TAB_MONSTERS = "monsters"

export type IndexPanel = typeof(setmetatable(
	{} :: {
		frame: Frame,
		list: ScrollingFrame,
		brainrotTab: TextButton,
		monsterTab: TextButton,
		tab: string,
		seenBrainrots: { [string]: boolean },
		seenMonsters: { [string]: boolean },
	},
	Index
))

local function sameBoolMap(a: { [string]: boolean }, b: { [string]: boolean }): boolean
	local count = 0
	for key, value in a do
		count += 1
		if b[key] ~= value then
			return false
		end
	end
	local other = 0
	for _ in b do
		other += 1
	end
	return count == other
end

local function idSet(list: { string }): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for _, id in list do
		set[id] = true
	end
	return set
end

local function paintSilhouette(root: Instance)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("SurfaceAppearance") or descendant:IsA("Texture") or descendant:IsA("Decal") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Color = SILHOUETTE
			descendant.Material = Enum.Material.SmoothPlastic
		elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Fire") or descendant:IsA("Smoke") or descendant:IsA("Highlight") then
			descendant.Enabled = false
		end
	end
end

local function applySilhouette(preview: GuiObject)
	preview:SetAttribute("PreviewSilhouette", true)
	if preview:IsA("ViewportFrame") then
		preview.Ambient = Color3.new(0, 0, 0)
		preview.LightColor = Color3.fromRGB(28, 28, 32)
		preview.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
		preview.BackgroundTransparency = 0.1
		local model = preview:FindFirstChild("PreviewModel", true)
		if model then
			paintSilhouette(model)
		end
	else
		preview.BackgroundColor3 = SILHOUETTE
		if preview:IsA("GuiObject") then
			preview.BackgroundTransparency = 0
		end
	end
end

local function sortedBrainrots(): { Types.BrainrotDefinition }
	local list: { Types.BrainrotDefinition } = {}
	for _, def in Brainrots.getAll() do
		if def.hidden ~= true then
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

local function sortedMonsters(): { Types.MonsterDefinition }
	local list: { Types.MonsterDefinition } = {}
	for _, def in Monsters.getAll() do
		table.insert(list, def)
	end
	table.sort(list, function(a, b)
		local dayA = Levels.firstDayForMonster(a.id) or 999
		local dayB = Levels.firstDayForMonster(b.id) or 999
		if dayA ~= dayB then
			return dayA < dayB
		end
		return a.name < b.name
	end)
	return list
end

local function styleTab(button: TextButton, selected: boolean)
	UITheme.applyButtonLook(button, if selected then UITheme.PANEL_BG_INDEX else UITheme.BUTTON_BG)
	UITheme.applyOutlinedTitle(button)
	button.TextSize = 14
end

function Index.new(parent: Frame): IndexPanel
	parent.Visible = false
	parent.AnchorPoint = Vector2.new(0.5, 0.5)
	parent.Position = UDim2.fromScale(0.5, 0.5)
	parent.Size = UDim2.fromOffset(INDEX_WIDTH, INDEX_HEIGHT)
	parent.ZIndex = 30
	parent.ClipsDescendants = false
	UITheme.applyPanelLook(parent, nil, UITheme.PANEL_BG_INDEX)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -80, 0, 32)
	title.Position = UDim2.fromOffset(16, 12)
	title.TextSize = 22
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Discovery Index"
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

	local brainrotTab = Instance.new("TextButton")
	brainrotTab.Name = "BrainrotsTab"
	brainrotTab.Position = UDim2.fromOffset(16, 50)
	brainrotTab.Size = UDim2.fromOffset(140, 32)
	brainrotTab.Text = "Brainrots"
	brainrotTab.Parent = parent

	local monsterTab = Instance.new("TextButton")
	monsterTab.Name = "MonstersTab"
	monsterTab.Position = UDim2.fromOffset(164, 50)
	monsterTab.Size = UDim2.fromOffset(140, 32)
	monsterTab.Text = "Monsters"
	monsterTab.Parent = parent

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0 -- the default border draws a dark line beside the thumb
	list.ClipsDescendants = true
	list.Position = UDim2.fromOffset(12, 92)
	list.Size = UDim2.new(1, -60, 1, -104)
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 6
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	list.Parent = parent

	local listPad = Instance.new("UIPadding")
	listPad.PaddingTop = UDim.new(0, 6)
	listPad.PaddingLeft = UDim.new(0, 6)
	listPad.PaddingRight = UDim.new(0, 6)
	listPad.PaddingBottom = UDim.new(0, 6)
	listPad.Parent = list

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(CELL_WIDTH, CELL_HEIGHT)
	layout.CellPadding = UDim2.fromOffset(CELL_PAD, CELL_PAD)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local self = setmetatable({
		frame = parent,
		list = list,
		brainrotTab = brainrotTab,
		monsterTab = monsterTab,
		tab = TAB_BRAINROTS,
		seenBrainrots = {},
		seenMonsters = {},
	}, Index)

	styleTab(brainrotTab, true)
	styleTab(monsterTab, false)

	close.MouseButton1Click:Connect(function()
		AudioController.play("UiClick")
		self:setOpen(false)
	end)
	brainrotTab.MouseButton1Click:Connect(function()
		AudioController.play("UiClick")
		self:setTab(TAB_BRAINROTS)
	end)
	monsterTab.MouseButton1Click:Connect(function()
		AudioController.play("UiClick")
		self:setTab(TAB_MONSTERS)
	end)

	return self
end

function Index.isOpen(self: IndexPanel): boolean
	return self.frame.Visible
end

function Index.setOpen(self: IndexPanel, open: boolean)
	self.frame.Visible = open
	if open then
		self:rebuild()
	end
end

function Index.setTab(self: IndexPanel, tab: string)
	if tab ~= TAB_BRAINROTS and tab ~= TAB_MONSTERS then
		return
	end
	if self.tab == tab then
		return
	end
	self.tab = tab
	styleTab(self.brainrotTab, tab == TAB_BRAINROTS)
	styleTab(self.monsterTab, tab == TAB_MONSTERS)
	self:rebuild()
end

function Index.applyProfile(self: IndexPanel, profile: { [string]: any })
	local unlocks: { string } = {}
	if type(profile.unlocks) == "table" then
		unlocks = profile.unlocks :: { string }
	end
	local introducedBrainrots: { string } = {}
	if type(profile.introducedBrainrots) == "table" then
		introducedBrainrots = profile.introducedBrainrots :: { string }
	end
	local introducedMonsters: { string } = {}
	if type(profile.introducedMonsters) == "table" then
		introducedMonsters = profile.introducedMonsters :: { string }
	end

	local seenBrainrots = idSet(unlocks)
	for _, id in introducedBrainrots do
		seenBrainrots[id] = true
	end

	local seenMonsters = idSet(introducedMonsters)
	-- Day 1 grunts have no intro popup (Zombie). Everything else stays
	-- silhouetted until ProgressService records the intro.
	for id in Monsters.getAll() do
		if not seenMonsters[id] and Levels.firstDayForMonster(id) == 1 then
			seenMonsters[id] = true
		end
	end

	if sameBoolMap(self.seenBrainrots, seenBrainrots) and sameBoolMap(self.seenMonsters, seenMonsters) then
		return
	end
	self.seenBrainrots = seenBrainrots
	self.seenMonsters = seenMonsters
	if self.frame.Visible then
		self:rebuild()
	end
end

local function mountCell(
	parent: Instance,
	order: number,
	name: string,
	seen: boolean,
	mountPreview: (holder: Frame) -> GuiObject
)
	local cell = Instance.new("Frame")
	cell.Name = "Cell" .. order
	cell.BorderSizePixel = 0
	cell.LayoutOrder = order
	cell.ZIndex = 31
	cell.Parent = parent
	UITheme.applyButtonLook(cell, if seen then UITheme.INDEX_DISCOVERED else UITheme.INDEX_UNKNOWN)
	UITheme.applySurfaceDepth(cell)

	local holder = Instance.new("Frame")
	holder.Name = "Portrait"
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 8)
	holder.Size = UDim2.fromOffset(PREVIEW_SIZE, PREVIEW_SIZE)
	holder.BackgroundColor3 = UITheme.INDEX_INSET
	holder.BorderSizePixel = 0
	UITheme.styleCorner(holder, 9)
	holder.ClipsDescendants = true
	holder.ZIndex = 32
	holder.Parent = cell

	-- Faint specimen guides sit behind the portrait.
	for lineIndex = 1, 3 do
		local guide = Instance.new("Frame")
		guide.Name = "SpecimenGuide"
		guide.Position, guide.Size = UDim2.new(0, 5, lineIndex / 4, 0), UDim2.new(1, -10, 0, 1)
		guide.BackgroundColor3, guide.BackgroundTransparency = UITheme.TITLE, 0.7
		guide.BorderSizePixel, guide.ZIndex = 0, 32
		guide.Parent = holder
	end

	local preview = mountPreview(holder)
	if preview:IsA("GuiObject") then
		preview.ZIndex = 32
	end
	if not seen then
		applySilhouette(preview)
		local mark = Instance.new("TextLabel")
		mark.Name = "Unknown"
		mark.BackgroundTransparency = 1
		mark.Size = UDim2.fromScale(1, 1)
		mark.Text = "?"
		mark.TextSize = 42
		mark.ZIndex = 33
		mark.Parent = holder
		UITheme.applyOutlinedTitle(mark)
		mark.TextSize = 42
	end

	local number = Instance.new("TextLabel")
	number.Name = "CatalogNumber"
	number.Position, number.Size = UDim2.fromOffset(5, 5), UDim2.fromOffset(30, 17)
	number.Text, number.TextSize, number.ZIndex = string.format("%02d", order), 10, 34
	UITheme.applyButtonLook(number, UITheme.PANEL_BG_INDEX, 6)
	UITheme.applyStroke(number, 1)
	UITheme.applyOutlinedTitle(number)
	number.Parent = cell

	local caption = Instance.new("TextLabel")
	caption.Name = "Name"
	caption.BackgroundTransparency = 1
	caption.AnchorPoint = Vector2.new(0.5, 1)
	caption.Position = UDim2.new(0.5, 0, 1, -6)
	caption.Size = UDim2.new(1, -8, 0, 28)
	caption.Text = if seen then name else "???"
	caption.TextSize = 12
	caption.TextWrapped = true
	caption.ZIndex = 32
	caption.Parent = cell
	UITheme.applyBodyText(caption)
	caption.Font = Enum.Font.GothamBold
	caption.TextSize = 12
end

function Index.rebuild(self: IndexPanel)
	for _, child in self.list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	if self.tab == TAB_BRAINROTS then
		for index, def in sortedBrainrots() do
			local seen = self.seenBrainrots[def.id] == true
			mountCell(self.list, index, def.name, seen, function(holder)
				return BrainrotPreview.mount(holder, def, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0))
			end)
		end
		return
	end

	for index, def in sortedMonsters() do
		local seen = self.seenMonsters[def.id] == true
		mountCell(self.list, index, def.name, seen, function(holder)
			return MonsterPreview.mount(holder, def, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0))
		end)
	end
end

return Index
