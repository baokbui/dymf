--!strict
--[[
	ProgressionStore
	Brainrot shop overlay (Talk at the plot stall) and HUD Upgrades overlay.
	List rows open a stats card (description + buy). Display + BuyStoreItem intent only.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared.Brainrots)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local ProgressConfig = require(Shared.Config.ProgressConfig)
local MagnetConfig = require(Shared.Config.MagnetConfig)
local StoreConfig = require(Shared.Config.StoreConfig)
local UITheme = require(Shared.Config.UITheme)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local BrainrotPreview = require(script.Parent.Parent.Parent.Utilities.BrainrotPreview)
local BrainrotInfo = require(script.Parent.Parent.Parent.Utilities.BrainrotInfo)
local AudioController = require(script.Parent.Parent.AudioController)

local UIEvents = require(script.Parent.Parent.Parent.UIEvents)
local UpgradeCards = require(script.Parent.UpgradeCards)
local ProgressionStore = {}
ProgressionStore.__index = ProgressionStore

local ROW_HEIGHT = 72
local PORTRAIT_SIZE = 56
local STATS_PORTRAIT = 88
local SOLD_FILL = Color3.fromRGB(145, 148, 155)
local STATS_FILL = Color3.fromRGB(255, 248, 220)
local STATS_GAP = 14
local STATS_WIDTH = 360
local SHOP_WIDTH = 460
local STATS_LAYOUT_SHIFT = -math.floor((SHOP_WIDTH + STATS_GAP + STATS_WIDTH) / 2 - SHOP_WIDTH / 2)
local BANNER_DURATION = 1.15
local FAIL_HOLD = 1.5
local FAIL_FADE = 1.0
local FAIL_REPLACE_FADE = 0.28
local FAIL_STACK_RISE = -62
local BANNER_RISE = -48
local SUCCESS_COPY = "Bought!"
local FAIL_COPY = "Not enough Brains."

export type ProgressionStoreHud = typeof(setmetatable(
	{} :: {
		frame: Frame,
		titleLabel: TextLabel,
		balanceLabel: TextLabel,
		list: ScrollingFrame,
		statsCard: Frame,
		statsBody: Frame,
		shopKind: string?,
		selectedId: string?,
		brains: number,
		unlocks: { [string]: boolean },
		upgrades: { [string]: number },
		banners: { Frame },
		anchorPosition: Vector3?,
		rangeConnection: RBXScriptConnection?,
	},
	ProgressionStore
))

local localPlayer = Players.LocalPlayer

local function characterPosition(): Vector3?
	local character = localPlayer.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return character:GetPivot().Position
end

local function horizontalDistance(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function sameBoolMap(a: { [string]: boolean }, b: { [string]: boolean }): boolean
	local count = 0
	for key, value in a do
		count += 1
		if b[key] ~= value then
			return false
		end
	end
	local otherCount = 0
	for _ in b do
		otherCount += 1
	end
	return count == otherCount
end

local function sameNumberMap(a: { [string]: number }, b: { [string]: number }): boolean
	local count = 0
	for key, value in a do
		count += 1
		if b[key] ~= value then
			return false
		end
	end
	local otherCount = 0
	for _ in b do
		otherCount += 1
	end
	return count == otherCount
end

local function styleRow(row: GuiObject, owned: boolean?, selected: boolean?)
	if owned then
		row.BackgroundColor3 = SOLD_FILL
	elseif selected then
		row.BackgroundColor3 = UITheme.CARD_SELECTED_BG
	else
		row.BackgroundColor3 = UITheme.CARD_BG
	end
	row.BorderSizePixel = 0
	UITheme.styleCorner(row, UITheme.CORNER_CARD)
	UITheme.applyStroke(row, UITheme.STROKE_PANEL)
end

local function stampSold(row: Instance)
	local sold = Instance.new("TextLabel")
	sold.Name = "Sold"
	sold.BackgroundTransparency = 1
	sold.AnchorPoint = Vector2.new(1, 0.5)
	sold.Position = UDim2.new(1, -16, 0.5, 0)
	sold.Size = UDim2.fromOffset(120, 40)
	sold.ZIndex = 4
	sold.Text = "SOLD"
	sold.TextSize = 26
	sold.TextXAlignment = Enum.TextXAlignment.Right
	sold.Font = Enum.Font.GothamBold
	sold.TextColor3 = UITheme.DANGER
	sold.TextStrokeColor3 = UITheme.OUTLINE
	sold.TextStrokeTransparency = 0
	sold.Active = false
	sold.Parent = row
end

local function dimPortrait(portrait: Frame)
	local veil = Instance.new("Frame")
	veil.Name = "SoldVeil"
	veil.BackgroundColor3 = Color3.fromRGB(40, 42, 48)
	veil.BackgroundTransparency = 0.35
	veil.BorderSizePixel = 0
	veil.Size = UDim2.fromScale(1, 1)
	veil.ZIndex = 3
	veil.Active = false
	veil.Parent = portrait
	UITheme.styleCorner(veil, 8)
end

local function findUpgrade(upgradeId: string): any?
	return ProgressConfig.upgradeById(upgradeId)
end

local function nextUpgradeCost(def: any, level: number): number?
	return ProgressConfig.nextUpgradeCost(def, level)
end

function ProgressionStore.new(parent: Frame): ProgressionStoreHud
	parent.Visible = false
	parent.AnchorPoint = Vector2.new(0.5, 0.5)
	parent.Position = UDim2.fromScale(0.5, 0.5)
	parent.Size = UDim2.fromOffset(SHOP_WIDTH, 560)
	parent.ZIndex = 45
	parent.ClipsDescendants = false
	UITheme.applyPanelLook(parent, nil, UITheme.PANEL_BG_STORE)
	UITheme.applySurfaceDepth(parent)

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

	local balance = Instance.new("TextLabel")
	balance.Name = "BrainsBalance"
	balance.Position, balance.Size = UDim2.new(1, -154, 0, 12), UDim2.fromOffset(138, 28)
	balance.TextSize = 13
	balance.Visible = false
	UITheme.applyButtonLook(balance, UITheme.FIELD_INSET, 8)
	UITheme.applyOutlinedTitle(balance, UITheme.FIELD_ACCENT)
	balance.Parent = parent

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
	list.Size = UDim2.new(1, -32, 1, -64)
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = parent

	local listPad = Instance.new("UIPadding")
	listPad.PaddingTop = UDim.new(0, 6)
	listPad.PaddingBottom = UDim.new(0, 6)
	listPad.PaddingLeft = UDim.new(0, 6)
	listPad.PaddingRight = UDim.new(0, 6)
	listPad.Parent = list

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = list

	local statsCard = Instance.new("Frame")
	statsCard.Name = "StatsCard"
	statsCard.Visible = false
	statsCard.AnchorPoint = Vector2.new(0, 0.5)
	statsCard.Position = UDim2.new(1, STATS_GAP, 0.5, 0)
	statsCard.Size = UDim2.fromOffset(STATS_WIDTH, 420)
	statsCard.ZIndex = 55
	statsCard.Parent = parent
	UITheme.applyPanelLook(statsCard, UITheme.CORNER_CARD, STATS_FILL)

	local statsClose = Instance.new("TextButton")
	statsClose.Name = "Close"
	statsClose.AnchorPoint = Vector2.new(1, 0)
	statsClose.Position = UDim2.new(1, -10, 0, 10)
	statsClose.Size = UDim2.fromOffset(32, 32)
	statsClose.ZIndex = 56
	statsClose.Text = "X"
	statsClose.TextSize = 16
	statsClose.Parent = statsCard
	UITheme.applyButtonLook(statsClose, UITheme.DANGER)
	UITheme.applyOutlinedTitle(statsClose)

	local statsBody = Instance.new("Frame")
	statsBody.Name = "Body"
	statsBody.BackgroundTransparency = 1
	statsBody.Position = UDim2.fromOffset(16, 48)
	statsBody.Size = UDim2.new(1, -32, 1, -64)
	statsBody.ZIndex = 56
	statsBody.ClipsDescendants = false
	statsBody.Parent = statsCard

	local self = setmetatable({
		frame = parent,
		titleLabel = title,
		balanceLabel = balance,
		list = list,
		statsCard = statsCard,
		statsBody = statsBody,
		shopKind = nil,
		selectedId = nil,
		brains = 0,
		unlocks = {},
		upgrades = {},
		banners = {},
		anchorPosition = nil,
		rangeConnection = nil,
	}, ProgressionStore)

	close.MouseButton1Click:Connect(function()
		AudioController.play("UiClick")
		self:close()
	end)
	statsClose.MouseButton1Click:Connect(function()
		AudioController.play("UiClick")
		self:hideStats()
	end)

	UIEvents.retentionUpdated:Connect(function()
		if self.frame.Visible and self.selectedId then self:showStats(self.selectedId) end
	end)
	return self
end

local function layoutShop(self: ProgressionStoreHud, statsOpen: boolean)
	if statsOpen then
		self.frame.Position = UDim2.new(0.5, STATS_LAYOUT_SHIFT, 0.5, 0)
	else
		self.frame.Position = UDim2.fromScale(0.5, 0.5)
	end
end

function ProgressionStore.hideStats(self: ProgressionStoreHud)
	self.selectedId = nil
	self.statsCard.Visible = false
	layoutShop(self, false)
	self:clearBanners()
	if self.shopKind then
		self:rebuildList()
	end
end

function ProgressionStore.stopRangeWatch(self: ProgressionStoreHud)
	if self.rangeConnection then
		self.rangeConnection:Disconnect()
		self.rangeConnection = nil
	end
	self.anchorPosition = nil
end

function ProgressionStore.startRangeWatch(self: ProgressionStoreHud, anchor: Vector3)
	self:stopRangeWatch()
	self.anchorPosition = anchor
	self.rangeConnection = RunService.Heartbeat:Connect(function()
		if not self.frame.Visible then
			self:stopRangeWatch()
			return
		end
		local pos = characterPosition()
		if not pos then
			self:close()
			return
		end
		local origin = self.anchorPosition
		if not origin then
			self:stopRangeWatch()
			return
		end
		if horizontalDistance(pos, origin) >= StoreConfig.CLOSE_DISTANCE then
			self:close()
		end
	end)
end

function ProgressionStore.close(self: ProgressionStoreHud)
	self:stopRangeWatch()
	self.shopKind = nil
	self.frame.Visible = false
	self:hideStats()
	self:clearBanners()
end

function ProgressionStore.isOpen(self: ProgressionStoreHud): boolean
	return self.frame.Visible
end

function ProgressionStore.setProfile(self: ProgressionStoreHud, profile: { [string]: any })
	local brains = self.brains
	if type(profile.brains) == "number" then
		brains = profile.brains
	end
	local unlocks: { [string]: boolean } = {}
	if type(profile.unlocks) == "table" then
		for _, id in profile.unlocks :: { any } do
			if type(id) == "string" then
				unlocks[id] = true
			end
		end
	end
	local upgrades: { [string]: number } = {}
	if type(profile.upgrades) == "table" then
		for key, value in profile.upgrades :: { [string]: any } do
			if type(key) == "string" and type(value) == "number" then
				upgrades[key] = value
			end
		end
	end

	local catalogChanged = self.brains ~= brains
		or not sameBoolMap(self.unlocks, unlocks)
		or not sameNumberMap(self.upgrades, upgrades)
	self.brains = brains
	self.unlocks = unlocks
	self.upgrades = upgrades
	-- XP ticks also send ProfileUpdated. Remounting shop ViewportFrames on
	-- every coin would hitch while the overlay is open.
	if self.shopKind and catalogChanged then
		self:rebuild()
	end
end

function ProgressionStore.clearBanners(self: ProgressionStoreHud)
	for _, banner in self.banners do
		if banner.Parent then
			banner:Destroy()
		end
	end
	table.clear(self.banners)
end

local function dropBanner(list: { Frame }, banner: Frame)
	for index, item in list do
		if item == banner then
			table.remove(list, index)
			return
		end
	end
end

local function fadeOutBanner(self: ProgressionStoreHud, banner: Frame, duration: number, rise: number)
	if not banner.Parent then
		dropBanner(self.banners, banner)
		return
	end
	if banner:GetAttribute("Replaced") == true then
		TweenService:Create(
			banner,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = banner.Position + UDim2.fromOffset(0, rise) }
		):Play()
		return
	end
	banner:SetAttribute("Replaced", true)

	local stroke = banner:FindFirstChildOfClass("UIStroke")
	local message = banner:FindFirstChild("Message")
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(banner, info, {
		Position = banner.Position + UDim2.fromOffset(0, rise),
		BackgroundTransparency = 1,
	}):Play()
	if stroke then
		TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	end

	local fade: Tween
	if message and message:IsA("TextLabel") then
		fade = TweenService:Create(message, info, {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
	else
		fade = TweenService:Create(banner, info, { BackgroundTransparency = 1 })
	end
	fade:Play()
	fade.Completed:Connect(function()
		dropBanner(self.banners, banner)
		if banner.Parent then
			banner:Destroy()
		end
	end)
end

function ProgressionStore.showPurchaseFeedback(self: ProgressionStoreHud, success: boolean)
	AudioController.play(if success then "PurchaseKaching" else "PurchaseError")

	local stackRise = if success then BANNER_RISE else FAIL_STACK_RISE
	for _, old in self.banners do
		fadeOutBanner(self, old, FAIL_REPLACE_FADE, stackRise)
	end

	local host: Frame = self.frame
	local startPos = UDim2.new(0.5, 0, 0.58, 0)
	local bannerSize = UDim2.fromOffset(if success then 280 else 400, if success then 46 else 58)
	if not success and self.statsCard.Visible then
		host = self.statsBody
		-- Sit just above the buy button (anchor 0.5,1 at 1,-4, height 42).
		startPos = UDim2.new(0.5, 0, 1, -52)
		bannerSize = UDim2.new(1, 0, 0, 58)
	end

	local layer = 70 + #self.banners * 2
	local banner = Instance.new("Frame")
	banner.Name = "PurchaseBanner"
	banner.AnchorPoint = Vector2.new(0.5, if success then 0.5 else 1)
	banner.Position = startPos
	banner.Size = bannerSize
	banner.BackgroundColor3 = if success then UITheme.SUCCESS else UITheme.DANGER
	banner.BorderSizePixel = 0
	banner.ZIndex = layer
	banner.Parent = host
	UITheme.styleCorner(banner, UITheme.CORNER_BUTTON)
	local stroke = UITheme.applyStroke(banner, UITheme.STROKE_PANEL)

	local label = Instance.new("TextLabel")
	label.Name = "Message"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -16, 1, 0)
	label.Position = UDim2.fromOffset(8, 0)
	label.Text = if success then SUCCESS_COPY else FAIL_COPY
	label.TextWrapped = true
	label.TextSize = if success then 16 else 14
	label.ZIndex = layer + 1
	label.Parent = banner
	UITheme.applyOutlinedTitle(label)
	label.TextSize = if success then 16 else 14

	table.insert(self.banners, banner)

	local info = if success
		then TweenInfo.new(BANNER_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		else TweenInfo.new(FAIL_FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, FAIL_HOLD)
	TweenService:Create(banner, info, {
		Position = startPos + UDim2.fromOffset(0, BANNER_RISE),
		BackgroundTransparency = 1,
	}):Play()
	TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	local fade = TweenService:Create(label, info, {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	fade:Play()
	fade.Completed:Connect(function()
		if banner:GetAttribute("Replaced") == true then
			return
		end
		dropBanner(self.banners, banner)
		if banner.Parent then
			banner:Destroy()
		end
	end)
end

local function clearBody(body: Frame)
	for _, child in body:GetChildren() do
		child:Destroy()
	end
end

local function placeBuyButton(
	parent: Frame,
	text: string,
	clickable: boolean,
	canAfford: boolean,
	onClick: () -> ()
)
	local button = Instance.new("TextButton")
	button.Name = "Buy"
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -4)
	button.Size = UDim2.fromOffset(220, 42)
	button.ZIndex = 57
	button.Text = text
	button.TextSize = 16
	button.AutoButtonColor = clickable
	button.Parent = parent
	UITheme.applyButtonLook(button, if canAfford then UITheme.SUCCESS else UITheme.CHIP_BG)
	UITheme.applyOutlinedTitle(button)
	button.TextSize = 16
	if clickable then
		button.MouseButton1Click:Connect(onClick)
	end
	return button
end

function ProgressionStore.tryBuy(self: ProgressionStoreHud, shop: string, id: string, cost: number)
	if self.brains < cost then
		self:showPurchaseFeedback(false)
		return
	end
	Remotes.getEvent("BuyStoreItem"):FireServer({
		shop = shop,
		id = id,
	})
end

function ProgressionStore.showStats(self: ProgressionStoreHud, id: string)
	self.selectedId = id
	self.statsCard.Size = UDim2.fromOffset(STATS_WIDTH, 420)
	self:clearBanners()
	clearBody(self.statsBody)

	local kind = self.shopKind
	self.statsCard.BackgroundColor3 = if kind == StoreConfig.SHOP_UPGRADES then UITheme.UPGRADE_PANEL else STATS_FILL
	if kind == StoreConfig.SHOP_BRAINROTS then
		local definition: Types.BrainrotDefinition? = Brainrots.get(id)
		local cost: number? = nil
		for _, entry in ProgressConfig.STORE_CATALOG do
			if entry.brainrotId == id then
				cost = entry.brainsCost
				break
			end
		end
		if not definition or cost == nil then
			self:hideStats()
			return
		end

		local owned = self.unlocks[id] == true

		local portrait = Instance.new("Frame")
		portrait.Name = "Portrait"
		portrait.AnchorPoint = Vector2.new(0.5, 0)
		portrait.Position = UDim2.new(0.5, 0, 0, 0)
		portrait.Size = UDim2.fromOffset(STATS_PORTRAIT, STATS_PORTRAIT)
		portrait.BackgroundColor3 = Color3.fromRGB(235, 245, 255)
		portrait.BorderSizePixel = 0
		portrait.Parent = self.statsBody
		UITheme.styleCorner(portrait, 12)
		UITheme.applyStroke(portrait, UITheme.STROKE_CARD)
		BrainrotPreview.mount(
			portrait,
			definition,
			UDim2.fromScale(1, 1),
			UDim2.new(0.5, 0, 0, 0)
		)

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(0, STATS_PORTRAIT + 8)
		name.Size = UDim2.new(1, 0, 0, 26)
		name.Text = definition.name
		name.TextSize = 18
		name.Parent = self.statsBody
		UITheme.applyOutlinedTitle(name)
		name.TextSize = 18

		local body = Instance.new("TextLabel")
		body.BackgroundTransparency = 1
		body.Position = UDim2.fromOffset(0, STATS_PORTRAIT + 38)
		body.Size = UDim2.new(1, 0, 0, 72)
		body.TextWrapped = true
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.TextSize = 14
		body.Text = BrainrotInfo.abilityDescription(definition.ability)
		body.Parent = self.statsBody
		UITheme.applyOutlinedTitle(body)
		body.TextSize = 14

		local stats = Instance.new("TextLabel")
		stats.BackgroundTransparency = 1
		stats.Position = UDim2.fromOffset(0, STATS_PORTRAIT + 112)
		stats.Size = UDim2.new(1, 0, 0, 72)
		stats.TextWrapped = true
		stats.TextXAlignment = Enum.TextXAlignment.Left
		stats.TextYAlignment = Enum.TextYAlignment.Top
		stats.TextSize = 13
		local pieces: { string } = {}
		for _, row in BrainrotInfo.statRows(definition) do
			if row.label ~= "Ability" then
				table.insert(pieces, string.format("%s: %s", row.label, row.value))
			end
		end
		table.insert(pieces, string.format("Ability: %s", BrainrotInfo.abilityLabel(definition.ability)))
		stats.Text = table.concat(pieces, "\n")
		stats.Parent = self.statsBody
		UITheme.applyOutlinedTitle(stats, UITheme.TITLE)
		stats.TextSize = 13

		if owned then
			placeBuyButton(self.statsBody, "SOLD", false, false, function() end)
		else
			local price = cost
			local retention = UIEvents.getRetentionState()
			local tickets = if retention then retention.brainrotTickets or 0 else 0
			if tickets > 0 then
				self.statsCard.Size = UDim2.fromOffset(STATS_WIDTH, 470)
				local ticket = placeBuyButton(self.statsBody, string.format("Use ticket (%d left)", tickets), true, true, function()
					Remotes.getEvent("BuyStoreItem"):FireServer({ shop = StoreConfig.SHOP_BRAINROTS, id = id, useTicket = true })
				end)
				ticket.Name, ticket.Position = "UseTicket", UDim2.new(0.5, 0, 1, -54)
			end
			placeBuyButton(
				self.statsBody,
				string.format("Buy for %d brains", price),
				true,
				self.brains >= price,
				function()
					self:tryBuy(StoreConfig.SHOP_BRAINROTS, id, price)
				end
			)
		end
	elseif kind == StoreConfig.SHOP_UPGRADES then
		local def = findUpgrade(id)
		if not def then
			self:hideStats()
			return
		end
		local level = ProgressConfig.upgradeLevel(def, self.upgrades[id])
		local atMax = level >= def.maxLevel
		local nextCost = nextUpgradeCost(def, level)
		local nextLevel = math.min(level + 1, def.maxLevel)
		local isMagnet = def.id == MagnetConfig.ID
		local stats
		if isMagnet then
			stats = {
				{ label = "Duration", current = MagnetConfig.formatSeconds(MagnetConfig.DURATION) },
				{ label = "Range", current = MagnetConfig.formatTiles(MagnetConfig.rangeTilesFor(level)),
					nextValue = if atMax then nil else MagnetConfig.formatTiles(MagnetConfig.rangeTilesFor(nextLevel)) },
				{ label = "Cooldown", current = MagnetConfig.formatSeconds(MagnetConfig.cooldownFor(level)),
					nextValue = if atMax then nil else MagnetConfig.formatSeconds(MagnetConfig.cooldownFor(nextLevel)) },
			}
		else
			local bonus = def.walkSpeedBonusPerLevel or 0
			stats = { { label = "Walk speed", current = tostring(PlayerConfig.WALK_SPEED + level * bonus),
				nextValue = if atMax then nil else tostring(PlayerConfig.WALK_SPEED + nextLevel * bonus) } }
		end
		UpgradeCards.details(self.statsBody, def.name, isMagnet, level, def.maxLevel, def.description, stats)

		if atMax then
			placeBuyButton(self.statsBody, "Max Level", false, false, function() end)
		elseif nextCost then
			local price = nextCost
			placeBuyButton(
				self.statsBody,
				string.format("Buy for %d brains", price),
				true,
				self.brains >= price,
				function()
					self:tryBuy(StoreConfig.SHOP_UPGRADES, id, price)
				end
			)
		end
	else
		self:hideStats()
		return
	end

	self.statsCard.Visible = true
	layoutShop(self, true)
end

function ProgressionStore.selectItem(self: ProgressionStoreHud, id: string)
	AudioController.play("UiSelect")
	if self.selectedId == id and self.statsCard.Visible then
		self:showStats(id)
		return
	end
	self:showStats(id)
	self:rebuildList()
end

function ProgressionStore.rebuildList(self: ProgressionStoreHud)
	for _, child in self.list:GetChildren() do
		if child:IsA("UIListLayout") or child:IsA("UIPadding") then
			continue
		end
		child:Destroy()
	end

	local kind = self.shopKind
	self.balanceLabel.Visible = kind == StoreConfig.SHOP_UPGRADES
	self.balanceLabel.Text = string.format("%d BRAINS", self.brains)
	if kind == StoreConfig.SHOP_BRAINROTS then
		self.titleLabel.Text = "Brainrot Shop"
		for index, entry in ProgressConfig.STORE_CATALOG do
			local definition: Types.BrainrotDefinition? = Brainrots.get(entry.brainrotId)
			if not definition then
				continue
			end
			local owned = self.unlocks[entry.brainrotId] == true
			local selected = self.selectedId == entry.brainrotId

			local row = Instance.new("TextButton")
			row.Name = entry.brainrotId
			row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
			row.LayoutOrder = index
			row.AutoButtonColor = true
			row.Text = ""
			row.Parent = self.list
			styleRow(row, owned, selected)

			local portrait = Instance.new("Frame")
			portrait.Name = "Portrait"
			portrait.Position = UDim2.fromOffset(8, 8)
			portrait.Size = UDim2.fromOffset(PORTRAIT_SIZE, PORTRAIT_SIZE)
			portrait.BackgroundColor3 = if owned then Color3.fromRGB(170, 172, 178) else Color3.fromRGB(235, 245, 255)
			portrait.BorderSizePixel = 0
			portrait.Active = false
			portrait.Parent = row
			UITheme.styleCorner(portrait, 8)
			BrainrotPreview.mount(
				portrait,
				definition,
				UDim2.fromScale(1, 1),
				UDim2.new(0.5, 0, 0, 0)
			)
			if owned then
				dimPortrait(portrait)
			end

			local name = Instance.new("TextLabel")
			name.BackgroundTransparency = 1
			name.Position = UDim2.fromOffset(74, 0)
			name.Size = UDim2.new(1, -170, 1, 0)
			name.TextWrapped = true
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextSize = 16
			name.Text = definition.name
			name.Active = false
			name.Parent = row
			UITheme.applyOutlinedTitle(name, if owned then Color3.fromRGB(210, 212, 218) else nil)
			name.TextSize = 16

			if owned then
				stampSold(row)
			else
				local price = Instance.new("TextLabel")
				price.Name = "Price"
				price.AnchorPoint = Vector2.new(1, 0.5)
				price.Position, price.Size = UDim2.new(1, -10, 0.5, 0), UDim2.fromOffset(80, 28)
				price.BackgroundColor3, price.BorderSizePixel = UITheme.FIELD_PANEL, 0
				price.Text, price.TextSize = string.format("%d brains", entry.brainsCost), 12
				UITheme.styleCorner(price, 8)
				UITheme.applyOutlinedTitle(price, UITheme.FIELD_TEXT)
				price.Parent = row
			end

			local id = entry.brainrotId
			row.MouseButton1Click:Connect(function()
				self:selectItem(id)
			end)
		end
	elseif kind == StoreConfig.SHOP_UPGRADES then
		self.titleLabel.Text = "Upgrade Shop"
		for index, def in ProgressConfig.UPGRADE_CATALOG do
			local id = def.id
			local level = ProgressConfig.upgradeLevel(def, self.upgrades[id])
			local price = nextUpgradeCost(def, level)
			local row = UpgradeCards.card(self.list, id, def.name, id == MagnetConfig.ID, level, def.maxLevel,
				price, price ~= nil and self.brains >= price, self.selectedId == id, index)
			row.Activated:Connect(function() self:selectItem(id) end)
		end
	end
end

function ProgressionStore.rebuild(self: ProgressionStoreHud)
	self:rebuildList()
	if self.selectedId then
		self:showStats(self.selectedId)
	end
end

function ProgressionStore.getShopKind(self: ProgressionStoreHud): string?
	return self.shopKind
end

function ProgressionStore.open(self: ProgressionStoreHud, shopKind: string, anchor: Vector3?)
	self.shopKind = shopKind
	self.selectedId = nil
	self.statsCard.Visible = false
	layoutShop(self, false)
	self.frame.Visible = true
	self:rebuild()
	if anchor then
		self:startRangeWatch(anchor)
	else
		self:stopRangeWatch()
	end
	AudioController.play("UiSelect")
end

return ProgressionStore
