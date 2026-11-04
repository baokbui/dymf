--!strict
-- Four transparent regions, never an overlapping full-screen dismissal button.
local OutsideDismiss = {}
function OutsideDismiss.mount(layer: Frame, window: Frame, close: () -> ())
	local dismiss = Instance.new("Frame")
	dismiss.Name, dismiss.Size = "Dismiss", UDim2.fromScale(1, 1)
	dismiss.BackgroundTransparency, dismiss.BorderSizePixel = 1, 0
	dismiss.ZIndex, dismiss.Parent = layer.ZIndex, layer
	local outside: { TextButton } = {}
	for _, name in { "Top", "Bottom", "Left", "Right" } do
		local region = Instance.new("TextButton")
		region.Name, region.Text = name, ""
		region.BackgroundTransparency, region.BorderSizePixel = 1, 0
		region.ZIndex, region.Parent = layer.ZIndex, dismiss
		region.Activated:Connect(close)
		table.insert(outside, region)
	end
	local function fitDismissRegions()
		local origin = window.AbsolutePosition - layer.AbsolutePosition
		local size, screen = window.AbsoluteSize, layer.AbsoluteSize
		local left, top = math.max(0, origin.X), math.max(0, origin.Y)
		local right, bottom = math.min(screen.X, origin.X + size.X), math.min(screen.Y, origin.Y + size.Y)
		outside[1].Position, outside[1].Size = UDim2.new(), UDim2.fromOffset(screen.X, top)
		outside[2].Position, outside[2].Size = UDim2.fromOffset(0, bottom), UDim2.fromOffset(screen.X, math.max(0, screen.Y - bottom))
		outside[3].Position, outside[3].Size = UDim2.fromOffset(0, top), UDim2.fromOffset(left, math.max(0, bottom - top))
		outside[4].Position, outside[4].Size = UDim2.fromOffset(right, top), UDim2.fromOffset(math.max(0, screen.X - right), math.max(0, bottom - top))
	end
	window:GetPropertyChangedSignal("AbsolutePosition"):Connect(fitDismissRegions)
	window:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitDismissRegions)
	layer:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitDismissRegions)
	fitDismissRegions()
end
return OutsideDismiss
