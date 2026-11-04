--!strict
-- Physical bounds shared by windows, leaving the planting bar and HUD rails clear.
local HudLayout = {}
local LEFT = { "Coins", "Brains", "Speed", "Hearts", "FirstTimeRewardsEntry" }
local RIGHT = { "DamageMeter", "LevelUI", "QuestTracker" }
local WATCH = { "Shop", "MenuEntry", "MagnetEntry", "MenuDrawer" }
for _, name in LEFT do table.insert(WATCH, name) end
for _, name in RIGHT do table.insert(WATCH, name) end

function HudLayout.bounds(main: ScreenGui): (Vector2, Vector2)
	local screen, origin = main.AbsoluteSize, main.AbsolutePosition
	local left, top, right, bottom = 12, 12, screen.X - 12, screen.Y - 12
	local function visible(name: string): GuiObject?
		local gui = main:FindFirstChild(name)
		return if gui and gui:IsA("GuiObject") and gui.Visible and gui.AbsoluteSize.Magnitude > 0 then gui else nil
	end
	local shop = visible("Shop")
	if shop then top = math.max(top, shop.AbsolutePosition.Y - origin.Y + shop.AbsoluteSize.Y + 12) end
	for _, name in { "MenuEntry", "MagnetEntry", "MenuDrawer" } do
		local gui = visible(name)
		if gui then bottom = math.min(bottom, gui.AbsolutePosition.Y - origin.Y - 12) end
	end
	for _, name in LEFT do
		local gui = visible(name)
		if gui then left = math.max(left, gui.AbsolutePosition.X - origin.X + gui.AbsoluteSize.X + 12) end
	end
	for _, name in RIGHT do
		local gui = visible(name)
		if gui then right = math.min(right, gui.AbsolutePosition.X - origin.X - 12) end
	end
	-- On narrow screens the side rails leave no usable window column. Keep the
	-- planting/navigation bands reserved; individual windows retain their scrolling.
	if right - left < 280 then left, right = 12, screen.X - 12 end
	return Vector2.new(left, top), Vector2.new(math.max(1, right - left), math.max(1, bottom - top))
end

function HudLayout.watch(main: ScreenGui, owner: Instance, refresh: () -> ())
	local connections: { RBXScriptConnection } = {}
	local function bind(gui: Instance)
		if not gui:IsA("GuiObject") or not table.find(WATCH, gui.Name) then return end
		for _, property in { "AbsolutePosition", "AbsoluteSize", "Visible" } do
			table.insert(connections, gui:GetPropertyChangedSignal(property):Connect(refresh))
		end
	end
	for _, gui in main:GetChildren() do bind(gui) end
	table.insert(connections, main.ChildAdded:Connect(function(gui) bind(gui); task.defer(refresh) end))
	table.insert(connections, main:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh))
	owner.Destroying:Once(function() for _, connection in connections do connection:Disconnect() end end)
end

return HudLayout
