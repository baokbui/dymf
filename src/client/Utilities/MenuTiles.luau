--!strict
-- Presentation only: seven bare icon/name destinations in a compact horizontal drawer.
local Theme = require(game:GetService("ReplicatedStorage").Shared.Config.UITheme)
local MenuTiles = {}
local images = {
	Inventory = "rbxassetid://18224282235", Index = "rbxassetid://110444066627259",
	Upgrades = "rbxassetid://90725732857650", Settings = "rbxassetid://18801194936",
}

local function shape(parent: Instance, color: Color3, x: number, y: number, w: number, h: number): Frame
	local part = Instance.new("Frame")
	part.BackgroundColor3, part.BorderSizePixel = color, 0
	part.Position, part.Size = UDim2.fromScale(x, y), UDim2.fromScale(w, h)
	part.Parent = parent
	Theme.styleCorner(part, 3)
	return part
end

function MenuTiles.illustrate(parent: Instance, name: string)
	local ink, white, gold = Theme.OUTLINE, Theme.TITLE, Theme.GOLD
	if name == "Quests" then
		local paper = shape(parent, white, 0.2, 0.12, 0.6, 0.8)
		Theme.applyStroke(paper, 3)
		shape(parent, gold, 0.35, 0.06, 0.3, 0.16)
		for row = 0, 2 do
			shape(parent, Theme.SUCCESS_DARK, 0.28, 0.33 + row * 0.18, 0.1, 0.09)
			shape(parent, ink, 0.45, 0.35 + row * 0.18, 0.27, 0.04)
		end
	elseif name == "First-time Rewards" then
		local box = shape(parent, Theme.DANGER, 0.15, 0.38, 0.7, 0.52)
		Theme.applyStroke(box, 3)
		shape(parent, gold, 0.43, 0.36, 0.14, 0.54)
		local lid = shape(parent, Theme.DANGER, 0.1, 0.28, 0.8, 0.15)
		Theme.applyStroke(lid, 3)
		shape(parent, gold, 0.43, 0.28, 0.14, 0.15)
		local left = shape(parent, gold, 0.26, 0.07, 0.22, 0.2)
		local right = shape(parent, gold, 0.52, 0.07, 0.22, 0.2)
		left.Rotation, right.Rotation = -25, 25
	elseif name == "Statistics" then
		for index, height in { 0.35, 0.55, 0.8 } do
			local bar = shape(parent, Theme.SUCCESS, 0.12 + (index - 1) * 0.27, 0.9 - height, 0.2, height)
			Theme.applyStroke(bar, 3)
		end
	else
		local handles = shape(parent, gold, 0.08, 0.18, 0.84, 0.36)
		Theme.applyStroke(handles, 3)
		shape(parent, Theme.PANEL_BG_UNLOCK, 0.18, 0.24, 0.64, 0.19)
		local cup = shape(parent, gold, 0.25, 0.1, 0.5, 0.51)
		Theme.applyStroke(cup, 3)
		shape(parent, gold, 0.44, 0.6, 0.12, 0.2)
		local base = shape(parent, gold, 0.23, 0.8, 0.54, 0.12)
		Theme.applyStroke(base, 3)
	end
end

function MenuTiles.build(window: Frame, sections: { string }, onSelect: (string) -> ()): ({ [string]: any }, Frame)
	local grid = Instance.new("Frame")
	grid.Name, grid.BackgroundTransparency = "Sections", 1
	grid.Position, grid.Size = UDim2.new(), UDim2.fromOffset(#sections * 96 - 8, 94)
	grid.Parent = window
	local layout = Instance.new("UIListLayout")
	layout.FillDirection, layout.Padding = Enum.FillDirection.Horizontal, UDim.new(0, 8)
	layout.SortOrder, layout.Parent = Enum.SortOrder.LayoutOrder, grid
	local buttons = {}
	for index, name in sections do
		local button = Instance.new("TextButton")
		button.Name, button.Text, button.LayoutOrder, button.Active = name, "", index, false
		button.Parent = grid
		button.BackgroundTransparency, button.BorderSizePixel, button.Size = 1, 0, UDim2.fromOffset(88, 94)
		local icon = Instance.new("ImageLabel")
		icon.Name, icon.BackgroundTransparency = "Icon", 1
		icon.AnchorPoint, icon.Position = Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.07)
		icon.Size, icon.ScaleType = UDim2.fromScale(0.65, 0.62), Enum.ScaleType.Fit
		icon.Parent = button
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.AspectRatio, aspect.DominantAxis = 1, Enum.DominantAxis.Height
		aspect.Parent = icon
		if images[name] then icon.Image = images[name] else MenuTiles.illustrate(icon, name) end
		local caption = Instance.new("TextLabel")
		caption.Name, caption.Text, caption.BackgroundTransparency = "Caption", name, 1
		caption.Position, caption.Size = UDim2.fromScale(0.04, 0.72), UDim2.fromScale(0.92, 0.24)
		caption.TextScaled, caption.TextWrapped = true, true
		caption.Parent = button
		Theme.applyOutlinedTitle(caption)
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize, limit.MinTextSize, limit.Parent = 14, 10, caption
		local count = caption:Clone()
		count.Name, count.Text, count.Visible = "Available", "!", false
		count.AnchorPoint, count.Position, count.Size = Vector2.new(1, 0), UDim2.new(1, -4, 0, 4), UDim2.fromOffset(24, 24)
		count.BackgroundTransparency, count.BackgroundColor3, count.Parent = 0, Theme.DANGER, button
		Theme.styleCorner(count, 12)
		buttons[name] = { button = button, caption = caption, badge = count, count = 0 }
		button.Activated:Connect(function() onSelect(name) end)
	end
	return buttons, grid
end

return MenuTiles
