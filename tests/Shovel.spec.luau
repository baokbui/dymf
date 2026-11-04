--!strict
-- Inject real PlacementController source; fake input/remotes, no live gameplay.
return function(): number
	local client, shared = game.StarterPlayer.StarterPlayerScripts.Client, game.ReplicatedStorage.Shared
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.Parent = "MainUI", game:GetService("CoreGui")
	local playerGui = { WaitForChild = function() return gui end }
	local player = { WaitForChild = function() return playerGui end }
	local primary, changed, fog = Instance.new("BindableEvent"), Instance.new("BindableEvent"), Instance.new("BindableEvent")
	local input = { MouseIconEnabled = true, InputChanged = changed.Event, GetMouseLocation = function() return Vector2.new(600, 400) end }
	local hit, tile, removed = nil, nil, {}
	local model = Instance.new("Model")
	model:SetAttribute("BrainrotId", "TungTungSahur"); model:SetAttribute("Row", 1); model:SetAttribute("Column", 2)
	local part = Instance.new("Part"); part.Parent = model
	local foreign = model:Clone()
	local ground = Instance.new("Part")
	ground:SetAttribute("Row", 1); ground:SetAttribute("Column", 2); ground:SetAttribute("Occupied", true)
	local realRequire, realGame = require, game
	local mocks = {
		InputController = { primaryAction = primary.Event },
		AudioController = { play = function() end },
		UIEvents = { fireFieldInspect = function() end },
		GridController = { raycastAt = function() return hit end, resolveTileAt = function() return tile end },
		PlotUtil = { getLocalBrainrotAt = function() return model end },
		Remotes = { getEvent = function(name: string) return { OnClientEvent = fog.Event, FireServer = function(_, data) if name == "RemoveBrainrot" then table.insert(removed, data) end end } end },
	}
	local fakeGame = { GetService = function(_, name: string)
		if name == "Players" then return { LocalPlayer = player } end
		if name == "UserInputService" then return input end
		if name == "GuiService" then return { GetGuiInset = function() return Vector2.new(0, 36), Vector2.zero end } end
		return realGame:GetService(name)
	end }
	local count = 0
	local function check(value: any, message: string) count += 1; assert(value, message) end
	local ok, result = xpcall(function()
		local module = client.Controllers.PlacementController
		local chunk = assert(loadstring(module.Source))
		setfenv(chunk, setmetatable({ game = fakeGame, script = module, require = function(m) return mocks[m.Name] or realRequire(m) end }, { __index = getfenv() }))
		local placement = chunk()
		placement.init(); placement.start()
		placement.setShovelMode(true)
		check(not placement.isShovelMode(), "shovel enabled before active day")
		placement.setPlacementAllowed(true); placement.setShovelMode(true); task.wait()
		local cursor = gui.ShovelCursor
		check(cursor:GetAttribute("ScreenSpaceUI") and cursor.Position == UDim2.fromOffset(612, 376), "cursor screen/inset coordinates")
		check(not input.MouseIconEnabled and cursor.Visible, "cursor mode")
		local icon = cursor.ShovelIcon
		check(icon:IsA("ImageLabel") and icon.Image == "rbxassetid://123683019299968" and not icon.Active and icon.ScaleType == Enum.ScaleType.Fit, "shared shovel texture or input passthrough")
		changed:Fire({ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(800, 500, 0) }, false); task.wait()
		check(cursor.Position == UDim2.fromOffset(812, 476), "cursor drifts from raw mouse")
		hit = { Instance = part }; primary:Fire(Vector2.new(800, 500)); task.wait()
		check(#removed == 1 and removed[1].row == 1 and removed[1].column == 2, "click on planted model does not remove")
		hit = { Instance = foreign:FindFirstChildOfClass("Part") }; primary:Fire(Vector2.zero); task.wait()
		check(#removed == 1, "foreign model removal intent")
		hit, tile = nil, ground; primary:Fire(Vector2.zero); task.wait()
		check(#removed == 2, "occupied tile removal")
		ground:SetAttribute("Occupied", false); primary:Fire(Vector2.zero); task.wait()
		check(#removed == 2, "empty tile removal")
		placement.setShovelMode(false); primary:Fire(Vector2.zero); task.wait()
		check(input.MouseIconEnabled and not cursor.Visible and not placement.isShovelMode(), "cancel did not restore cursor")
		return count
	end, debug.traceback)
	gui:Destroy(); primary:Destroy(); changed:Destroy(); fog:Destroy(); model:Destroy(); foreign:Destroy(); ground:Destroy()
	if not ok then error(result) end
	return result
end
