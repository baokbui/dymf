--!strict
-- Shared viewport scaling. No polling; nested Menu pages are scaled by their host.
local Theme = require(game:GetService("ReplicatedStorage").Shared.Config.UITheme)
local HudLayout = require(script.Parent.HudLayout)
local UISizing = {}

function UISizing.desktop(viewport: Vector2): number
	return math.clamp(math.min(viewport.X / Theme.DESKTOP_REFERENCE.X, viewport.Y / Theme.DESKTOP_REFERENCE.Y), 1, Theme.DESKTOP_MAX_SCALE)
end

function UISizing.start(main: ScreenGui)
	if main:GetAttribute("UISizingBound") then return end
	main:SetAttribute("UISizingBound", true)
	local function bind(gui: Instance)
		if not gui:IsA("GuiObject") or gui:FindFirstChild("DesktopScale") or gui:GetAttribute("ScreenSpaceUI") == true then return end
		-- Full-screen overlays keep screen coordinates; their windows fit separately.
		if gui.Size.X.Scale >= 0.9 and gui.Size.Y.Scale >= 0.9 then return end
		local zoom = Instance.new("UIScale")
		zoom.Name, zoom.Parent = "DesktopScale", gui
		local base, expected = gui.Position, gui.Position
		local panel = gui.AnchorPoint.X > 0 and gui.AnchorPoint.Y == 0.5
		local function resize()
			if gui.Parent ~= main then zoom.Scale = 1; return end
			local screen = main.AbsoluteSize
			local width = gui.Size.X.Scale * screen.X + gui.Size.X.Offset
			local height = gui.Size.Y.Scale * screen.Y + gui.Size.Y.Offset
			local origin, bounds = Vector2.new(16, 16), screen - Vector2.new(32, 32)
			if panel then origin, bounds = HudLayout.bounds(main) end
			local extra = 0
			if panel then
				for _, child in gui:GetChildren() do
					if child:IsA("GuiObject") and child.Visible and child.Position.X.Scale >= 1 then
						extra = math.max(extra, child.Position.X.Offset + child.Size.X.Offset)
					end
				end
			end
			local factor = math.min(UISizing.desktop(screen), bounds.X / math.max(1, width + extra), bounds.Y / math.max(1, height))
			zoom.Scale = math.max(0.1, factor)
			expected = UDim2.new(base.X.Scale, base.X.Offset * zoom.Scale, base.Y.Scale, base.Y.Offset * zoom.Scale)
			if gui.Name == "DamageMeter" then
				local shop = main:FindFirstChild("Shop") :: GuiObject?
				if shop and shop.Visible then
					local shopRight = shop.AbsolutePosition.X - main.AbsolutePosition.X + shop.AbsoluteSize.X
					local x = screen.X * base.X.Scale + base.X.Offset * zoom.Scale - width * zoom.Scale
					if x < shopRight + 12 then
						local shopBottom = shop.AbsolutePosition.Y - main.AbsolutePosition.Y + shop.AbsoluteSize.Y
						expected = UDim2.new(expected.X.Scale, expected.X.Offset, 0, math.max(screen.Y * base.Y.Scale + base.Y.Offset * zoom.Scale, shopBottom + 12))
					end
				end
			end
			if panel then
				local desired = Vector2.new(screen.X * base.X.Scale + base.X.Offset * zoom.Scale, screen.Y * base.Y.Scale + base.Y.Offset * zoom.Scale)
				local min = origin + Vector2.new(width * gui.AnchorPoint.X, height * gui.AnchorPoint.Y) * zoom.Scale
				local max = origin + bounds - Vector2.new(width * (1 - gui.AnchorPoint.X) + extra, height * (1 - gui.AnchorPoint.Y)) * zoom.Scale
				expected = UDim2.fromOffset(math.clamp(desired.X, min.X, math.max(min.X, max.X)), math.clamp(desired.Y, min.Y, math.max(min.Y, max.Y)))
			end
			gui.Position = expected
		end
		gui:GetPropertyChangedSignal("Position"):Connect(function()
			if gui.Parent ~= main or gui.Position == expected then return end
			base = gui.Position
			resize()
		end)
		gui:GetPropertyChangedSignal("Size"):Connect(resize)
		gui:GetPropertyChangedSignal("Parent"):Connect(resize)
		if panel or gui.Name == "DamageMeter" then
			HudLayout.watch(main, gui, resize)
			for _, child in gui:GetChildren() do
				if child:IsA("GuiObject") then child:GetPropertyChangedSignal("Visible"):Connect(resize) end
			end
		end
		local connection = main:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
		gui.Destroying:Once(function() connection:Disconnect() end)
		resize()
	end
	for _, child in main:GetChildren() do bind(child) end
	main.ChildAdded:Connect(function(child) task.defer(bind, child) end)
end

return UISizing
