--!strict
-- Shared viewport scaling. No polling; nested Menu pages are scaled by their host.
local Theme = require(game:GetService("ReplicatedStorage").Shared.Config.UITheme)
local HudLayout = require(script.Parent.HudLayout)
local UISizing = {}
local COUNTER_OFFSETS: { [string]: number } = { Coins = 0, Brains = 83, Speed = 166 }
local REWARD_GAP = 8

function UISizing.desktop(viewport: Vector2): number
	local compact = math.min(viewport.X / 760, viewport.Y / 600)
	if compact < 1 then return math.max(0.55, compact) end
	return math.max(1, math.min(viewport.X / Theme.DESKTOP_REFERENCE.X, viewport.Y / Theme.DESKTOP_REFERENCE.Y))
end

-- Scale content inside a full-screen layer while leaving its screen coordinates intact.
function UISizing.scaleContent(gui: GuiObject, viewport: GuiBase2d)
	local zoom = Instance.new("UIScale")
	zoom.Parent = gui
	local function resize()
		local screen = viewport.AbsoluteSize
		local width = gui.Size.X.Scale * screen.X + gui.Size.X.Offset
		local height = gui.Size.Y.Scale * screen.Y + gui.Size.Y.Offset
		zoom.Scale = math.max(0.1, math.min(UISizing.desktop(screen),
			(screen.X - 32) / math.max(1, width), (screen.Y - 32) / math.max(1, height)))
	end
	local connection = viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	local sizeConnection = gui:GetPropertyChangedSignal("Size"):Connect(resize)
	gui.Destroying:Once(function()
		connection:Disconnect()
		sizeConnection:Disconnect()
	end)
	resize()
end

function UISizing.start(main: GuiBase2d)
	if main:GetAttribute("UISizingBound") then return end
	main:SetAttribute("UISizingBound", true)
	local function bind(gui: Instance)
		if not gui:IsA("GuiObject") or gui:FindFirstChild("DesktopScale") or gui:GetAttribute("ScreenSpaceUI") == true then return end
		-- Full-screen overlays keep screen coordinates; their windows fit separately.
		if gui.Size.X.Scale >= 0.9 and gui.Size.Y.Scale >= 0.9 then return end
		local zoom = Instance.new("UIScale")
		zoom.Name, zoom.Parent = "DesktopScale", gui
		local base, expected = gui.Position, gui.Position
		local followsShop = gui.Name == "DamageMeter" or gui.Name == "Hearts"
		local counterOffset = COUNTER_OFFSETS[gui.Name]
		local isSpinner = gui.Name == "DailySpinEntry"
		local isReward = isSpinner or gui.Name == "FirstTimeRewardsEntry"
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
			if counterOffset then
				local hearts = main:FindFirstChild("Hearts")
				if hearts and hearts:IsA("GuiObject") then
					local start = hearts.AbsolutePosition - main.AbsolutePosition
					expected = UDim2.fromOffset(start.X + counterOffset * zoom.Scale, start.Y + hearts.AbsoluteSize.Y + 8 * zoom.Scale)
				end
			elseif isReward then
				local menu = main:FindFirstChild("MenuEntry")
				local speed = main:FindFirstChild("Speed")
				local gift = main:FindFirstChild("FirstTimeRewardsEntry")
				local spinner = main:FindFirstChild("DailySpinEntry")
				local giftVisible = gift and gift:IsA("GuiObject") and gift.Visible
				local spinnerVisible = spinner and spinner:IsA("GuiObject") and spinner.Visible
				local count = if giftVisible and spinnerVisible then 2 else 1
				if menu and menu:IsA("GuiObject") then
					local bottom = menu.AbsolutePosition.Y - main.AbsolutePosition.Y - REWARD_GAP
					if speed and speed:IsA("GuiObject") then
						local top = speed.AbsolutePosition.Y - main.AbsolutePosition.Y + speed.AbsoluteSize.Y + REWARD_GAP
						zoom.Scale = math.max(0.1, math.min(zoom.Scale, (bottom - top) / (count * (height + REWARD_GAP))))
					end
					if isSpinner and giftVisible then bottom -= (height + REWARD_GAP) * zoom.Scale end
					local x = menu.AbsolutePosition.X - main.AbsolutePosition.X + (menu.AbsoluteSize.X - width * zoom.Scale) / 2
					expected = UDim2.fromOffset(x, bottom)
				end
			end
			if gui.Name == "MagnetEntry" then
				local day = main:FindFirstChild("LevelUI")
				if day and day:IsA("GuiObject") and day.Visible then
					local dayLeft = day.AbsolutePosition.X - main.AbsolutePosition.X
					local desired = screen.X * expected.X.Scale + expected.X.Offset
					local halfWidth = width * zoom.Scale / 2
					local x = math.max(halfWidth + 12, dayLeft - halfWidth - 12)
					if x < desired then expected = UDim2.new(0, x, expected.Y.Scale, expected.Y.Offset) end
				end
			end
			if followsShop then
				local shop = main:FindFirstChild("Shop")
				if shop and shop:IsA("GuiObject") and shop.Visible then
					local shopPosition = shop.AbsolutePosition - main.AbsolutePosition
					local left = screen.X * expected.X.Scale + expected.X.Offset - width * zoom.Scale * gui.AnchorPoint.X
					if left < shopPosition.X + shop.AbsoluteSize.X + 12
						and left + width * zoom.Scale > shopPosition.X - 12 then
						local y = screen.Y * expected.Y.Scale + expected.Y.Offset
						local belowShop = shopPosition.Y + shop.AbsoluteSize.Y + 12
						expected = UDim2.new(expected.X.Scale, expected.X.Offset, 0, math.max(y, belowShop))
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
		if followsShop then
			HudLayout.watch(main, gui, resize, { "Shop" })
		elseif counterOffset then
			HudLayout.watch(main, gui, resize, { "Hearts" })
		elseif isReward then
			HudLayout.watch(main, gui, resize, { "MenuEntry", "Speed" })
			local function watchPeer(peer: Instance)
				if peer:IsA("GuiObject") and (peer.Name == "FirstTimeRewardsEntry" or peer.Name == "DailySpinEntry") then
					local connection = peer:GetPropertyChangedSignal("Visible"):Connect(resize)
					gui.Destroying:Once(function() connection:Disconnect() end)
				end
			end
			for _, child in main:GetChildren() do watchPeer(child) end
			local added = main.ChildAdded:Connect(function(child) watchPeer(child); task.defer(resize) end)
			gui.Destroying:Once(function() added:Disconnect() end)
		elseif gui.Name == "MagnetEntry" then
			HudLayout.watch(main, gui, resize, { "LevelUI" })
		end
		if panel then
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
