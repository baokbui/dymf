--!strict
-- Presentation for upgrade cards and comparisons. ProgressionStore owns purchases.
local Theme = require(game:GetService("ReplicatedStorage").Shared.Config.UITheme)
local UpgradeCards = {}

local function text(parent: Instance, name: string, value: string, size: number, color: Color3, bold: boolean): TextLabel
	local label = Instance.new("TextLabel")
	label.Name, label.Text, label.TextSize = name, value, size
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = color
	label.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	label.Parent = parent
	return label
end

local function surface(parent: Instance, name: string, color: Color3): Frame
	local frame = Instance.new("Frame")
	frame.Name, frame.BackgroundColor3, frame.BorderSizePixel = name, color, 0
	Theme.styleCorner(frame, 10)
	frame.Parent = parent
	return frame
end

local function identity(parent: GuiObject, name: string, isMagnet: boolean, level: number, maximum: number)
	local accent = if isMagnet then Theme.UPGRADE_MAGNET else Theme.UPGRADE_SPEED
	local tile = surface(parent, "IconTile", Theme.FIELD_INSET)
	tile.Position, tile.Size = UDim2.fromOffset(12, 12), UDim2.fromOffset(58, 58)
	Theme.applyStroke(tile, 2, accent)
	if name == "Farm Capacity" then
		local glyph = text(tile, "Icon", "🌾", 30, Theme.TITLE, true)
		glyph.Size = UDim2.fromScale(1, 1)
		glyph.TextXAlignment = Enum.TextXAlignment.Center
	else
		local icon = Instance.new("ImageLabel")
		icon.Name, icon.Image = "Icon", if isMagnet then Theme.MAGNET_ICON else Theme.SPEED_ICON
		icon.BackgroundTransparency, icon.ScaleType = 1, Enum.ScaleType.Fit
		icon.Position, icon.Size = UDim2.fromOffset(7, 7), UDim2.fromOffset(44, 44)
		icon.Parent = tile
	end

	local heading = text(parent, "UpgradeName", name, 21, Theme.TITLE, true)
	heading.Position, heading.Size = UDim2.fromOffset(84, 12), UDim2.new(1, -96, 0, 26)
	local rank = text(parent, "Level", string.format("LEVEL %d / %d", level, maximum), 12, accent, true)
	rank.Position, rank.Size = UDim2.fromOffset(84, 39), UDim2.new(1, -96, 0, 16)
	local track = surface(parent, "LevelTrack", Theme.FIELD_INSET)
	track.Position, track.Size = UDim2.fromOffset(84, 61), UDim2.new(1, -96, 0, 7)
	local fill = surface(track, "Fill", accent)
	fill.Size = UDim2.fromScale(level / maximum, 1)
	fill.Visible = level > 0
end

function UpgradeCards.card(parent: Instance, id: string, name: string, isMagnet: boolean, level: number, maximum: number,
	price: number?, affordable: boolean, selected: boolean, order: number): TextButton
	local button = Instance.new("TextButton")
	button.Name, button.Text, button.LayoutOrder = id, "", order
	button.Size = UDim2.new(1, 0, 0, 110)
	button.Parent = parent
	local accent = if isMagnet then Theme.UPGRADE_MAGNET else Theme.UPGRADE_SPEED
	Theme.applyButtonLook(button, Theme.FIELD_PANEL, 14)
	Theme.applyStroke(button, if selected then 3 else 2, if selected then accent else Theme.OUTLINE)
	Theme.applySurfaceDepth(button)
	identity(button, name, isMagnet, level, maximum)

	local summary = text(button, "Benefit", if id == "FarmCapacity" then "House more monsters" elseif isMagnet then "Pull in nearby coins" else "Move faster on your plot", 13, Theme.FIELD_TEXT, false)
	summary.Position, summary.Size = UDim2.fromOffset(12, 78), UDim2.new(1, -155, 0, 24)
	local badge = surface(button, "PriceBadge", Theme.FIELD_INSET)
	badge.AnchorPoint, badge.Position = Vector2.new(1, 0), UDim2.new(1, -12, 0, 77)
	badge.Size = UDim2.fromOffset(120, 25)
	local value = text(badge, "Price", if price then string.format("%d brains  ›", price) else "MAX LEVEL",
		13, if price and affordable then Theme.FIELD_ACCENT else Theme.FIELD_TEXT, true)
	value.TextXAlignment, value.Size = Enum.TextXAlignment.Center, UDim2.fromScale(1, 1)
	return button
end

function UpgradeCards.details(parent: Frame, name: string, isMagnet: boolean, level: number, maximum: number,
	description: string, stats: { { label: string, current: string, nextValue: string? } })
	local header = surface(parent, "UpgradeHeader", Theme.FIELD_PANEL)
	header.Size = UDim2.new(1, 0, 0, 82)
	identity(header, name, isMagnet, level, maximum)
	local about = text(parent, "Description", description, 14, Theme.FIELD_TEXT, false)
	about.Position, about.Size = UDim2.fromOffset(8, 88), UDim2.new(1, -16, 0, 65)
	about.TextWrapped = true
	for index, stat in stats do
		local row = surface(parent, "Stat" .. index, Theme.FIELD_INSET)
		row.Position, row.Size = UDim2.fromOffset(0, 163 + (index - 1) * 38), UDim2.new(1, 0, 0, 32)
		local label = text(row, "Label", stat.label, 13, Theme.FIELD_TEXT, true)
		label.Position, label.Size = UDim2.fromOffset(10, 0), UDim2.new(0.4, -10, 1, 0)
		local copy = if stat.nextValue then stat.current .. "  →  " .. stat.nextValue else stat.current
		local value = text(row, "Value", copy, 13, if stat.nextValue then Theme.FIELD_ACCENT else Theme.TITLE, true)
		value.Position, value.Size = UDim2.fromScale(0.4, 0), UDim2.new(0.6, -10, 1, 0)
		value.TextXAlignment = Enum.TextXAlignment.Right
	end
end

return UpgradeCards
