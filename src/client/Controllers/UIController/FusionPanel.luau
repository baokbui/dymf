--!strict
-- Dedicated fusion page; the existing collection component owns selection/intent.
local Theme = require(game:GetService("ReplicatedStorage").Shared.Config.UITheme)
local UIEvents = require(script.Parent.Parent.Parent.UIEvents)
local Collection = require(script.Parent.MonsterCollection)
local FusionPanel = {}

function FusionPanel.new(main: ScreenGui): any
	local frame = Instance.new("Frame")
	frame.Name, frame.Visible = "Fusion", false
	frame.AnchorPoint, frame.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(620, 440)
	Theme.applyPanelLook(frame, nil, Theme.PANEL_BG_INVENTORY)
	frame.Parent = main
	local title = Instance.new("TextLabel")
	title.Name, title.Text, title.BackgroundTransparency = "Title", "Monster Fusion", 1
	title.Position, title.Size = UDim2.fromOffset(16, 8), UDim2.new(1, -32, 0, 38)
	title.TextSize, title.Font = 25, Enum.Font.GothamBold
	Theme.applyOutlinedTitle(title)
	title.Parent = frame
	local list = Instance.new("ScrollingFrame")
	list.Name, list.BackgroundTransparency, list.BorderSizePixel = "Monsters", 1, 0
	list.Position, list.Size = UDim2.fromOffset(12, 54), UDim2.new(1, -24, 1, -66)
	list.AutomaticCanvasSize, list.CanvasSize = Enum.AutomaticSize.Y, UDim2.new()
	list.ScrollingDirection, list.ScrollBarThickness = Enum.ScrollingDirection.Y, 6
	list.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	list.Parent = frame
	local padding = Instance.new("UIPadding")
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 5), UDim.new(0, 5)
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 5), UDim.new(0, 5)
	padding.Parent = list
	local layout = Instance.new("UIListLayout")
	layout.SortOrder, layout.Padding, layout.Parent = Enum.SortOrder.LayoutOrder, UDim.new(0, 8), list
	local empty = Instance.new("TextLabel")
	empty.Name, empty.Text, empty.BackgroundTransparency = "Empty", "No farm monsters yet. Combine shards in Inventory → Items first.", 1
	empty.Size, empty.TextSize, empty.TextWrapped = UDim2.new(1, 0, 0, 80), 15, true
	Theme.applyBodyText(empty, Theme.INVENTORY_INK)
	empty.Parent = list
	local refreshCollection = Collection.new(list)
	local function refresh(profile: any) empty.Visible = not refreshCollection(profile) end
	local connection = UIEvents.profileUpdated:Connect(refresh)
	frame.Destroying:Once(function() connection:Disconnect() end)
	refresh(UIEvents.getProfileState())
	return { frame = frame, setOpen = function(_, opened: boolean)
		frame.Visible = opened
		if opened then refresh(UIEvents.getProfileState()) end
	end }
end

return FusionPanel
