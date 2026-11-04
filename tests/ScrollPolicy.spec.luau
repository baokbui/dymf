--!strict
return function(Policy: any): number
	local screen = Instance.new("ScreenGui")
	screen.Parent = game:GetService("CoreGui")
	local checks = 0
	local function check(value: any, message: string) checks += 1; assert(value, message) end
	local ok, result = xpcall(function()
		local list = Instance.new("ScrollingFrame")
		list.Size, list.CanvasSize = UDim2.fromOffset(200, 200), UDim2.fromOffset(0, 150)
		list.ScrollingDirection, list.ScrollBarThickness, list.Parent = Enum.ScrollingDirection.Y, 6, screen
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight, pad.Parent = UDim.new(0, 6), UDim.new(0, 16), list
		task.wait(0.1); Policy.start(screen); task.wait(0.1)
		check(list.ScrollBarThickness == 0 and pad.PaddingRight == pad.PaddingLeft, "fitting content has a scrollbar or uneven padding")
		list.CanvasSize = UDim2.fromOffset(0, 400); task.wait(0.1)
		check(list.ScrollBarThickness == 6 and pad.PaddingRight.Offset == 16, "overflow lost scrollbar/gutter")
		list.ScrollingEnabled = false; task.wait(0.1)
		check(list.ScrollBarThickness == 0, "disabled wrapper has scrollbar")
		list.ScrollingEnabled = true; task.wait(0.1)
		check(list.ScrollBarThickness == 6, "real scrolling not restored")
		list.CanvasSize = UDim2.fromOffset(0, 150); task.wait(0.1)
		check(list.ScrollBarThickness == 0, "scrollbar stayed after content shrank")
		local hidden = Instance.new("ScrollingFrame")
		hidden.Size, hidden.CanvasSize, hidden.ScrollBarThickness = UDim2.fromOffset(100, 100), UDim2.fromOffset(0, 300), 0
		hidden.Parent = screen; task.wait(0.1)
		check(hidden.ScrollBarThickness == 0, "text-only scrollbar was made visible")
		list.ScrollingDirection, list.CanvasSize = Enum.ScrollingDirection.X, UDim2.fromOffset(400, 0); task.wait(0.1)
		check(list.ScrollBarThickness == 6, "horizontal overflow lost scrollbar")
		return checks
	end, debug.traceback)
	screen:Destroy()
	if not ok then error(result) end
	return result
end
