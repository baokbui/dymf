--!strict
-- Isolated weather scene, never changes the player's real map or Lighting.
return function(source: string): string
	local shared = game.ReplicatedStorage.Shared
	local style = require(shared.Utilities.WorldStyle)
	local weather = require(shared.Config.WeatherConfig)
	local gridConfig = require(shared.Config.GridConfig)
	local scene = Instance.new("Folder")
	local plots = Instance.new("Folder"); plots.Name, plots.Parent = "Plots", scene
	local plot = Instance.new("Model"); plot.Name, plot.Parent = "Plot1", plots
	local base = Instance.new("Part"); base.Name, base.Transparency, base.Parent = "Base", 1, plot; plot.PrimaryPart = base
	local grid = Instance.new("Folder"); grid.Name, grid.Parent = "Grid", plot
	local tile = Instance.new("Part"); tile.Name, tile.Parent = "Tile_1_1", grid
	tile:SetAttribute("Row", 1); tile:SetAttribute("Column", 1)
	tile.Material, tile.Color = gridConfig.TILE_MATERIAL, gridConfig.TILE_COLOR_A; style.applyPart(tile, "Ground")
	local ground = Instance.new("Part"); ground.Name, ground.Parent = "Baseplate", scene
	ground.Size, ground.Color = Vector3.new(700, 20, 700), Color3.fromRGB(103, 199, 48)
	style.applyPart(ground, "Ground")
	local originalColor, originalFriction = ground.Color, ground.CurrentPhysicalProperties.Friction
	local realGame, realRequire = game, require
	local chunk = assert(loadstring(source))
	setfenv(chunk, setmetatable({
		game = { GetService = function(_, service)
			if service == "Workspace" then return scene end
			if service == "CollectionService" then return { GetTagged = function() return { tile } end } end
			return realGame:GetService(service)
		end },
		require = function(module)
			if module.Name == "ModelUtil" then return { findDecorTemplate = function() return nil end } end
			return realRequire(module)
		end,
	}, { __index = getfenv() }))
	local visuals = chunk()
	local ok, failure = xpcall(function()
		visuals.apply(plot)
		assert(ground.Color == weather.DESERT_BASEPLATE_COLOR and ground.MaterialVariant == "BvmStudsGround")
		assert(tile.Color == weather.DESERT_TILE_COLOR_A and tile.MaterialVariant == "BvmStudsGround")
		assert(grid.ClientDesertSandBed.MaterialVariant == "BvmStudsGround")
		for _, item in plot.ClientDesertDecor:GetChildren() do
			if item:IsA("BasePart") then assert(item.MaterialVariant == "BvmStudsScenery") end
		end
		visuals.clear()
		assert(ground.Color == originalColor and ground.MaterialVariant == "BvmStudsGround")
		assert(tile.Color == gridConfig.TILE_COLOR_A and tile.MaterialVariant == "BvmStudsGround")
		assert(not grid:FindFirstChild("ClientDesertSandBed") and not plot:FindFirstChild("ClientDesertDecor"))
		assert(ground.CurrentPhysicalProperties.Friction == originalFriction)
	end, debug.traceback)
	visuals.clear(); scene:Destroy()
	assert(ok, failure)
	return "Desert/day stud materials, sand colors, pyramid styling, physics and cleanup passed"
end
