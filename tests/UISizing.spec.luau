--!strict
-- Isolated viewport geometry; never starts gameplay or reads player data.
return function(Sizing: any): number
	local checks = 0
	local function check(value: any, message: string) checks += 1; assert(value, message) end
	check(Sizing.desktop(Vector2.new(1366, 768)) == 1, "baseline scale")
	check(Sizing.desktop(Vector2.new(1920, 1080)) >= 1.2 and Sizing.desktop(Vector2.new(1920, 1080)) <= 1.3, "1080p text remains small")
	check(math.abs(Sizing.desktop(Vector2.new(2560, 1440)) - 5 / 3) < 0.001, "1440p scale")
	check(Sizing.desktop(Vector2.new(3840, 2160)) == 2.5, "4K scale")
	check(Sizing.desktop(Vector2.new(7680, 4320)) == 5, "8K scale")
	check(Sizing.desktop(Vector2.new(5120, 1440)) == Sizing.desktop(Vector2.new(2560, 1440)), "ultrawide scale ignores height")
	check(Sizing.desktop(Vector2.new(390, 844)) < 1, "portrait HUD did not shrink")
	local screen = Instance.new("ScreenGui")
	screen.Parent = game:GetService("CoreGui")
	local ok, result = xpcall(function()
		local host = Instance.new("Frame")
		host.Size, host.Parent = UDim2.fromOffset(1366, 768), screen
		local hud = Instance.new("Frame")
		hud.Name, hud.Size = "Hud", UDim2.fromOffset(270, 72)
		hud.AnchorPoint, hud.Position = Vector2.new(1, 1), UDim2.new(1, -16, 1, -16)
		hud.Parent = host
		Sizing.start(host)
		for _, viewport in { Vector2.new(390, 844), Vector2.new(844, 390), Vector2.new(768, 1024), Vector2.new(1366, 768), Vector2.new(1920, 1080), Vector2.new(2260, 1163), Vector2.new(2560, 1440), Vector2.new(3840, 2160), Vector2.new(7680, 4320) } do
			host.Size = UDim2.fromOffset(viewport.X, viewport.Y)
			task.wait(0.1)
			check(math.abs(hud.DesktopScale.Scale - Sizing.desktop(viewport)) < 0.001, "viewport scaling")
			local edge = hud.AbsolutePosition + hud.AbsoluteSize
			check(edge.X < host.AbsolutePosition.X + viewport.X and edge.Y < host.AbsolutePosition.Y + viewport.Y, "HUD extends past screen edge")
		end
		local cursor = Instance.new("Frame")
		cursor.Name, cursor.Size, cursor.Position = "ShovelCursor", UDim2.fromOffset(32, 38), UDim2.fromOffset(800, 500)
		cursor:SetAttribute("ScreenSpaceUI", true)
		cursor.Parent = host; task.wait(0.1)
		check(not cursor:FindFirstChild("DesktopScale") and cursor.Position == UDim2.fromOffset(800, 500), "screen cursor auto-scaled")
		Sizing.scaleContent(cursor, host)
		check(cursor:FindFirstChildOfClass("UIScale").Scale == 5 and cursor.Position == UDim2.fromOffset(800, 500),
			"cursor visual scale changed pointer coordinates")
		local expected = hud.Position
		Sizing.start(host); task.wait(0.1)
		check(hud.Position == expected, "scale applied twice")
		hud.Size = UDim2.fromOffset(4000, 72); task.wait(0.1)
		check(hud.AbsoluteSize.X <= host.AbsoluteSize.X - 31, "wide widget not fitted")
		local nested = Instance.new("Frame")
		nested.Parent = host
		hud.Parent = nested; task.wait(0.1)
		check(hud.DesktopScale.Scale == 1, "nested Menu page receives double desktop scaling")
		return checks
	end, debug.traceback)
	screen:Destroy()
	if not ok then error(result) end
	return result
end
