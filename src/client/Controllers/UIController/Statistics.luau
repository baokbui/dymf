--!strict
-- Read-only profile totals; no extra persistence or remote calls.
local Shared = game:GetService("ReplicatedStorage").Shared
local Theme = require(Shared.Config.UITheme)
local Config = require(Shared.Config.ProgressConfig)
local BrainAmount = require(script.Parent.Parent.Parent.Utilities.BrainAmount)
local Statistics = {}
Statistics.__index = Statistics

function Statistics.new(main: ScreenGui): any
	local frame = Instance.new("Frame")
	frame.Name, frame.Size, frame.Visible = "Statistics", UDim2.fromOffset(460, 560), false
	frame.Parent = main
	Theme.applyPanelLook(frame, nil, Theme.PANEL_BG_INDEX)
	local title = Instance.new("TextLabel")
	title.Text, title.TextSize, title.BackgroundTransparency = "Statistics", 24, 1
	title.Position, title.Size = UDim2.fromOffset(16, 12), UDim2.new(1, -32, 0, 34)
	title.Parent = frame
	Theme.applyOutlinedTitle(title)
	local list = Instance.new("ScrollingFrame")
	list.Name, list.BackgroundTransparency, list.BorderSizePixel = "Totals", 1, 0
	list.Position, list.Size = UDim2.fromOffset(16, 56), UDim2.new(1, -32, 1, -68)
	list.AutomaticCanvasSize, list.CanvasSize = Enum.AutomaticSize.Y, UDim2.new()
	list.ScrollBarThickness, list.VerticalScrollBarInset = 5, Enum.ScrollBarInset.ScrollBar
	list.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 5), UDim.new(0, 15), UDim.new(0, 5), UDim.new(0, 5)
	pad.Parent = list
	local layout = Instance.new("UIListLayout")
	layout.Padding, layout.SortOrder, layout.Parent = UDim.new(0, 10), Enum.SortOrder.LayoutOrder, list
	local rows = {}
	for index, name in { "Days cleared", "Brainrots placed", "Monsters defeated", "Total earned", "Time played", "Brainrots owned", "Equipped types", "Speed upgrade", "Magnet upgrade" } do
		local row = Instance.new("Frame")
		row.Name, row.Size, row.LayoutOrder = name, UDim2.new(1, 0, 0, 44), index
		row.Parent = list
		Theme.applyCardLook(row)
		local caption = Instance.new("TextLabel")
		caption.Text, caption.TextSize, caption.BackgroundTransparency = name, 16, 1
		caption.TextXAlignment = Enum.TextXAlignment.Left
		caption.Position, caption.Size, caption.Parent = UDim2.fromOffset(10, 0), UDim2.new(0.6, -10, 1, 0), row
		Theme.applyBodyText(caption)
		local value = caption:Clone()
		value.Name, value.Text, value.TextXAlignment = "Value", "0", Enum.TextXAlignment.Center
		value.Position, value.Size, value.Parent = UDim2.fromScale(0.6, 0), UDim2.fromScale(0.4, 1), row
		rows[index] = value
	end
	return setmetatable({ frame = frame, rows = rows }, Statistics)
end

function Statistics.applyProfile(self: any, profile: any)
	local stats, upgrades = profile.statistics or {}, profile.upgrades or {}
	local values = { stats[Config.STAT_LEVELS_CLEARED] or 0, stats[Config.STAT_BRAINROTS_PLACED] or 0,
		stats[Config.STAT_MONSTERS_DEFEATED] or 0, stats[Config.STAT_BRAINS_EARNED] or 0,
		string.format("%d min", math.floor((stats[Config.STAT_TIME_PLAYED] or 0) / 60)),
		#(profile.unlocks or {}), #(profile.equipped or {}), upgrades.WalkSpeed or 0, upgrades.Magnet or 1 }
	for index, value in values do
		if index == 4 then BrainAmount.set(self.rows[index], tostring(value), true)
		else self.rows[index].Text = tostring(value) end
	end
end

return Statistics
