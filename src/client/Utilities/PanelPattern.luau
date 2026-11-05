--!strict
-- Static decoration mounted behind interactive content. Uses native GUI objects.
local PanelPattern = {}
export type Kind = "Checkers" | "Dots" | "Diagonal"

function PanelPattern.mount(parent: GuiObject, kind: Kind, tint: Color3, opacity: number, inset: number): Frame
	local pattern = Instance.new("Frame")
	pattern.Name = kind .. "Pattern"
	pattern.Position = UDim2.fromOffset(inset, inset)
	pattern.Size = UDim2.new(1, -2 * inset, 1, -2 * inset)
	pattern.BackgroundTransparency = 1
	pattern.Active = false
	pattern.Parent = parent

	if kind == "Diagonal" then
		pattern.BackgroundColor3 = tint
		pattern.BackgroundTransparency = 0
		pattern.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = pattern
		local stops = { NumberSequenceKeypoint.new(0, 1) }
		for index = 0, 3 do
			local start = 0.08 + index * 0.23
			table.insert(stops, NumberSequenceKeypoint.new(start, 1))
			table.insert(stops, NumberSequenceKeypoint.new(start + 0.006, 1 - opacity))
			table.insert(stops, NumberSequenceKeypoint.new(start + 0.055, 1 - opacity))
			table.insert(stops, NumberSequenceKeypoint.new(start + 0.061, 1))
		end
		table.insert(stops, NumberSequenceKeypoint.new(1, 1))
		local bands = Instance.new("UIGradient")
		bands.Rotation = 45
		bands.Transparency = NumberSequence.new(stops)
		bands.Parent = pattern
		return pattern
	end

	local columns, rows = 8, 6
	for row = 0, rows - 1 do
		for column = 0, columns - 1 do
			if kind == "Checkers" and (row + column) % 2 ~= 0 then continue end
			local tile = Instance.new("Frame")
			tile.BackgroundColor3, tile.BackgroundTransparency = tint, 1 - opacity
			tile.BorderSizePixel = 0
			if kind == "Dots" then
				tile.AnchorPoint = Vector2.new(0.5, 0.5)
				tile.Position = UDim2.fromScale((column + 0.5) / columns, (row + 0.5) / rows)
				tile.Size = UDim2.fromOffset(5, 5)
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(1, 0)
				corner.Parent = tile
			else
				tile.Position = UDim2.fromScale(column / columns, row / rows)
				tile.Size = UDim2.fromScale(1 / columns, 1 / rows)
			end
			tile.Parent = pattern
		end
	end
	return pattern
end

return PanelPattern
