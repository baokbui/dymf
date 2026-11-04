--!strict
-- Layout-only desktop fixtures. No gameplay scripts, player data or remotes.
return function(Layout: any, Sizing: any): number
	local screen = Instance.new("ScreenGui")
	screen.Parent = game:GetService("CoreGui")
	local checks = 0
	local function check(value: boolean, message: string) checks += 1; assert(value, message) end
	local ok, result = xpcall(function()
		local host = Instance.new("Frame")
		host.Parent = screen
		local function widget(name: string, size: Vector2, position: UDim2, anchor: Vector2): Frame
			local frame = Instance.new("Frame")
			frame.Name, frame.Size, frame.Position, frame.AnchorPoint = name, UDim2.fromOffset(size.X, size.Y), position, anchor
			frame.Parent = host
			return frame
		end
		local shop = widget("Shop", Vector2.new(750, 140), UDim2.new(0.5, 0, 0, 0), Vector2.new(0.5, 0))
		local damage = widget("DamageMeter", Vector2.new(270, 72), UDim2.new(1, -16, 0.16, 0), Vector2.new(1, 0))
		widget("LevelUI", Vector2.new(360, 80), UDim2.new(1, -16, 1, -16), Vector2.one)
		widget("Coins", Vector2.new(160, 64), UDim2.new(0, 16, 0.4, 0), Vector2.zero)
		widget("MenuEntry", Vector2.new(96, 94), UDim2.new(0, 16, 1, -16), Vector2.new(0, 1))
		local panel = widget("Inspect", Vector2.new(500, 620), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
		local detail = Instance.new("Frame")
		detail.Position, detail.Size, detail.Visible, detail.Parent = UDim2.new(1, 12, 0, 0), UDim2.fromOffset(250, 400), false, panel
		host.Size = UDim2.fromOffset(1366, 768)
		Sizing.start(host)
		for _, size in { Vector2.new(1366, 768), Vector2.new(1920, 1080), Vector2.new(2560, 1440) } do
			host.Size = UDim2.fromOffset(size.X, size.Y)
			for _, showDetail in { false, true } do
				detail.Visible = showDetail
				task.wait(0.1)
				local origin, bounds = Layout.bounds(host)
				local start = panel.AbsolutePosition - host.AbsolutePosition
				local finish = start + panel.AbsoluteSize
				if showDetail then finish = Vector2.new(detail.AbsolutePosition.X - host.AbsolutePosition.X + detail.AbsoluteSize.X, finish.Y) end
				check(start.X >= origin.X - 1 and finish.X <= origin.X + bounds.X + 1, "panel/detail covers side rail")
				check(start.Y >= origin.Y - 1 and finish.Y <= origin.Y + bounds.Y + 1, "panel covers planting/navigation band")
			end
		end
		host.Size = UDim2.fromOffset(1000, 768); task.wait(0.1)
		check(damage.AbsolutePosition.Y >= shop.AbsolutePosition.Y + shop.AbsoluteSize.Y + 11, "Damage overlaps wide planting bar")
		local before = panel.AbsolutePosition.Y
		shop.Size = UDim2.fromOffset(750, 220); task.wait(0.1)
		local origin = Layout.bounds(host)
		check(panel.AbsolutePosition.Y - host.AbsolutePosition.Y >= origin.Y - 1, "shop resize leaves panel overlap")
		check(panel.AbsolutePosition.Y ~= before, "window ignores changed shop bounds")
		return checks
	end, debug.traceback)
	screen:Destroy()
	if not ok then error(result) end
	return result
end
