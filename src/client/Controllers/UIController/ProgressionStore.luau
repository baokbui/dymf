--!strict
--[[
	ProgressionStore
	Talk-to-mascot overlay for brains purchases. Display + BuyStoreItem intent.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared.Brainrots)
local ProgressConfig = require(Shared.Config.ProgressConfig)
local StoreConfig = require(Shared.Config.StoreConfig)
local UITheme = require(Shared.Config.UITheme)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local BrainrotPreview = require(script.Parent.Parent.Parent.Utilities.BrainrotPreview)
local AudioController = require(script.Parent.Parent.AudioController)

local ProgressionStore = {}
ProgressionStore.__index = ProgressionStore

local ROW_HEIGHT = 72

export type ProgressionStoreHud = typeof(setmetatable(
	{} :: {
		frame: Frame,
		titleLabel: TextLabel,
		list: ScrollingFrame,
		statusLabel: TextLabel,
		shopKind: string?,
		brains: number,
		unlocks: { [string]: boolean },
		upgrades: { [string]: number },
	},
	ProgressionStore
))

local function styleRow(row: Frame)
	row.BackgroundColor3 = UITheme.CARD_BG
	row.BorderSizePixel = 0
	UITheme.styleCorner(row, UITheme.CORNER_CARD)
	UITheme.applyStroke(row, UITheme.STROKE_CARD)
end

function ProgressionStore.new(parent: Frame): ProgressionStoreHud
	parent.Visible = false
	parent.AnchorPoint = Vector2.new(0.5, 0.5)
	parent.Position = UDim2.fromScale(0.5, 0.5)
	parent.Size = UDim2.fromOffset(460, 420)
	parent.ZIndex = 45
	UITheme.applyPanelLook(parent, nil, UITheme.PANEL_BG_UNLOCK)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -72, 0, 28)
	title.Position = UDim2.fromOffset(16, 12)
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Shop"
	title.Parent = parent
	UITheme.applyOutlinedTitle(title)

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 10)
	close.Size = UDim2.fromOffset(36, 32)
	close.Text = "X"
	close.TextSize = 18
	close.Parent = parent
	UITheme.applyButtonLook(close, UITheme.DANGER)
	UITheme.applyOutlinedTitle(close)

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(16, 48)
	list.Size = UDim2.new(1, -32, 1, -92)
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = list

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.AnchorPoint = Vector2.new(0, 1)
	status.Position = UDim2.new(0, 16, 1, -12)
	status.Size = UDim2.new(1, -32, 0, 22)
	status.TextSize = 14
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Text = ""
	status.Parent = parent
	UITheme.applyOutlinedTitle(status, UITheme.GOLD_TEXT)
	status.TextSize = 14

	local self = setmetatable({
		frame = parent,
		titleLabel = title,
		list = list,
		statusLabel = status,
		shopKind = nil,
		brains = 0,
		unlocks = {},
		upgrades = {},
	}, ProgressionStore)

	close.MouseButton1Click:Connect(function()
		AudioController.play("UiClick")
		self:close()
	end)

	return self
end

function ProgressionStore.close(self: ProgressionStoreHud)
	self.shopKind = nil
	self.frame.Visible = false
end

function ProgressionStore.isOpen(self: ProgressionStoreHud): boolean
	return self.frame.Visible
end

function ProgressionStore.setProfile(self: ProgressionStoreHud, profile: { [string]: any })
	if type(profile.brains) == "number" then
		self.brains = profile.brains
	end
	self.unlocks = {}
	if type(profile.unlocks) == "table" then
		for _, id in profile.unlocks :: { any } do
			if type(id) == "string" then
				self.unlocks[id] = true
			end
		end
	end
	self.upgrades = {}
	if type(profile.upgrades) == "table" then
		for key, value in profile.upgrades :: { [string]: any } do
			if type(key) == "string" and type(value) == "number" then
				self.upgrades[key] = value
			end
		end
	end
	if self.shopKind then
		self:rebuild()
	end
end

function ProgressionStore.setStatus(self: ProgressionStoreHud, text: string)
	self.statusLabel.Text = text
end

local function buyButton(parent: Instance, text: string, enabled: boolean, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Name = "Buy"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10, 0.5, 0)
	button.Size = UDim2.fromOffset(110, 36)
	button.Text = text
	button.TextSize = 14
	button.AutoButtonColor = enabled
	button.Parent = parent
	UITheme.applyButtonLook(button, if enabled then UITheme.SUCCESS else UITheme.CHIP_BG)
	UITheme.applyOutlinedTitle(button)
	button.TextSize = 14
	if enabled then
		button.MouseButton1Click:Connect(onClick)
	end
	return button
end

function ProgressionStore.rebuild(self: ProgressionStoreHud)
	for _, child in self.list:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local kind = self.shopKind
	if kind == StoreConfig.SHOP_BRAINROTS then
		self.titleLabel.Text = "Brainrot Shop"
		for index, entry in ProgressConfig.STORE_CATALOG do
			local definition: Types.BrainrotDefinition? = Brainrots.get(entry.brainrotId)
			if not definition then
				continue
			end
			local row = Instance.new("Frame")
			row.Name = entry.brainrotId
			row.Size = UDim2.new(1, -4, 0, ROW_HEIGHT)
			row.LayoutOrder = index
			row.Parent = self.list
			styleRow(row)

			local portrait = Instance.new("Frame")
			portrait.Name = "Portrait"
			portrait.Position = UDim2.fromOffset(8, 8)
			portrait.Size = UDim2.fromOffset(56, 56)
			portrait.BackgroundColor3 = Color3.fromRGB(235, 245, 255)
			portrait.BorderSizePixel = 0
			portrait.Parent = row
			UITheme.styleCorner(portrait, 8)
			BrainrotPreview.mount(portrait, definition)

			local name = Instance.new("TextLabel")
			name.BackgroundTransparency = 1
			name.Position = UDim2.fromOffset(74, 10)
			name.Size = UDim2.new(1, -200, 0, 24)
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextSize = 16
			name.Text = definition.name
			name.Parent = row
			UITheme.applyOutlinedTitle(name)
			name.TextSize = 16

			local owned = self.unlocks[entry.brainrotId] == true
			local canBuy = not owned and self.brains >= entry.brainsCost
			local label = if owned then "Owned" else string.format("%d brains", entry.brainsCost)
			buyButton(row, label, canBuy, function()
				AudioController.play("UiSelect")
				Remotes.getEvent("BuyStoreItem"):FireServer({
					shop = StoreConfig.SHOP_BRAINROTS,
					id = entry.brainrotId,
				})
			end)
		end
	elseif kind == StoreConfig.SHOP_UPGRADES then
		self.titleLabel.Text = "Upgrade Shop"
		for index, def in ProgressConfig.UPGRADE_CATALOG do
			local row = Instance.new("Frame")
			row.Name = def.id
			row.Size = UDim2.new(1, -4, 0, ROW_HEIGHT)
			row.LayoutOrder = index
			row.Parent = self.list
			styleRow(row)

			local level = self.upgrades[def.id] or 0
			local name = Instance.new("TextLabel")
			name.BackgroundTransparency = 1
			name.Position = UDim2.fromOffset(14, 10)
			name.Size = UDim2.new(1, -140, 0, 24)
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextSize = 16
			name.Text = string.format("%s  %d / %d", def.name, level, def.maxLevel)
			name.Parent = row
			UITheme.applyOutlinedTitle(name)
			name.TextSize = 16

			local desc = Instance.new("TextLabel")
			desc.BackgroundTransparency = 1
			desc.Position = UDim2.fromOffset(14, 36)
			desc.Size = UDim2.new(1, -140, 0, 24)
			desc.TextXAlignment = Enum.TextXAlignment.Left
			desc.TextSize = 13
			desc.Text = def.description
			desc.Parent = row
			UITheme.applyOutlinedTitle(desc, UITheme.SUBTEXT)
			desc.TextSize = 13

			local atMax = level >= def.maxLevel
			local nextCost = def.brainsCosts[level + 1] or def.brainsCosts[#def.brainsCosts]
			local canBuy = not atMax and type(nextCost) == "number" and self.brains >= nextCost
			local label = if atMax then "Max" else string.format("%d brains", nextCost)
			buyButton(row, label, canBuy, function()
				AudioController.play("UiSelect")
				Remotes.getEvent("BuyStoreItem"):FireServer({
					shop = StoreConfig.SHOP_UPGRADES,
					id = def.id,
				})
			end)
		end
	end
end

function ProgressionStore.open(self: ProgressionStoreHud, shopKind: string)
	self.shopKind = shopKind
	self.statusLabel.Text = string.format("%d brains", self.brains)
	self:rebuild()
	self.frame.Visible = true
	AudioController.play("UiSelect")
end

return ProgressionStore
