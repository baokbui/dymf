--!strict
-- Show scrollbar chrome only for real overflow; retain touch/wheel scrolling.
local ScrollPolicy = {}

function ScrollPolicy.start(main: Instance)
	if main:GetAttribute("ScrollPolicyBound") then return end
	main:SetAttribute("ScrollPolicyBound", true)
	local function bind(item: Instance)
		if not item:IsA("ScrollingFrame") or item:GetAttribute("ScrollPolicyItem") then return end
		item:SetAttribute("ScrollPolicyItem", true)
		local preferred = item.ScrollBarThickness
		if preferred == 0 then return end -- explicitly text-only / hidden-scrollbar views
		local applying = false
		local pad = item:FindFirstChildOfClass("UIPadding")
		local originalRight = if pad then pad.PaddingRight else UDim.new()
		local function refresh()
			if applying then return end
			applying = true
			local direction, canvas, window = item.ScrollingDirection, item.AbsoluteCanvasSize, item.AbsoluteSize
			local x = direction ~= Enum.ScrollingDirection.Y and canvas.X > window.X + 3
			local y = direction ~= Enum.ScrollingDirection.X and canvas.Y > window.Y + 3
			local visible = item.ScrollingEnabled and (x or y)
			item.ScrollBarThickness = if visible then preferred else 0
			if pad and direction == Enum.ScrollingDirection.Y then
				local gutter = if originalRight.Scale == 0 and pad.PaddingLeft.Scale == 0
					then UDim.new(0, math.max(originalRight.Offset, pad.PaddingLeft.Offset + preferred + 4)) else originalRight
				pad.PaddingRight = if visible then gutter else pad.PaddingLeft
			end
			applying = false
		end
		item:GetPropertyChangedSignal("ScrollBarThickness"):Connect(function()
			if applying then return end
			if item.ScrollBarThickness > 0 then preferred = item.ScrollBarThickness end
			refresh()
		end)
		for _, property in { "AbsoluteCanvasSize", "AbsoluteSize", "ScrollingEnabled", "ScrollingDirection" } do
			item:GetPropertyChangedSignal(property):Connect(refresh)
		end
		refresh()
	end
	for _, child in main:GetDescendants() do bind(child) end
	main.DescendantAdded:Connect(function(child) if child:IsA("ScrollingFrame") then task.defer(bind, child) end end)
end

return ScrollPolicy
