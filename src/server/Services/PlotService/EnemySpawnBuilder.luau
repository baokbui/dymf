--!strict
--[[
	EnemySpawnBuilder
	Procedurally constructs one enemy-spawn lane in the east map column. Each lane
	aligns with a player plot row; monsters stage here and enter the matching
	player plot from +X.

	Contains:

		Base        - invisible region marker
		Barriers    - north/south dividers + east map edge (west is open toward
		              the adjacent player plot)
		EnemySpawn  - attachment at the west edge, facing the player grid (-X)
		Path        - empty folder for EnemyService path nodes (M6)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotConfig = require(ReplicatedStorage.Shared.Config.PlotConfig)

local EnemySpawnBuilder = {}

local function newPart(name: string, size: Vector3, position: Vector3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.Locked = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addBarrier(name: string, size: Vector3, position: Vector3, parent: Instance)
	local wall = newPart(name, size, position, parent)
	wall.Transparency = PlotConfig.BARRIER_TRANSPARENCY
	wall.Color = PlotConfig.BARRIER_COLOR
	wall.Material = PlotConfig.BARRIER_MATERIAL
	wall.CanCollide = true
	wall.CastShadow = false
end

local function addMarker(name: string, worldPosition: Vector3, parent: BasePart)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = parent
	attachment.WorldPosition = worldPosition
end

-- Builds an enemy lane centered on originPosition, at grass level (Y).
function EnemySpawnBuilder.build(rowIndex: number, originPosition: Vector3): Model
	local width = PlotConfig.BASE_WIDTH
	local depth = PlotConfig.BASE_DEPTH
	local thickness = PlotConfig.BASE_THICKNESS
	local barrierHeight = PlotConfig.BARRIER_HEIGHT
	local barrierThickness = PlotConfig.BARRIER_THICKNESS

	local model = Instance.new("Model")
	model.Name = string.format("EnemyLane%d", rowIndex)
	model:SetAttribute("RowIndex", rowIndex)

	local base = newPart(
		"Base",
		Vector3.new(width, thickness, depth),
		originPosition - Vector3.new(0, thickness / 2, 0),
		model
	)
	base.Transparency = 1
	base.CanCollide = false
	base.CastShadow = false
	model.PrimaryPart = base

	local barriers = Instance.new("Folder")
	barriers.Name = "Barriers"
	barriers.Parent = model

	local halfW = width / 2
	local halfD = depth / 2
	local wallY = originPosition.Y + barrierHeight / 2
	local groundXZ = Vector3.new(originPosition.X, 0, originPosition.Z)
	local longSize = Vector3.new(width + barrierThickness * 2, barrierHeight, barrierThickness)
	local sideSize = Vector3.new(barrierThickness, barrierHeight, depth)

	addBarrier("North", longSize, groundXZ + Vector3.new(0, wallY, halfD + barrierThickness / 2), barriers)
	addBarrier("South", longSize, groundXZ + Vector3.new(0, wallY, -(halfD + barrierThickness / 2)), barriers)
	-- West is open so monsters can walk into the adjacent player plot.
	addBarrier("East", sideSize, groundXZ + Vector3.new(halfW + barrierThickness / 2, wallY, 0), barriers)

	-- Spawn at the west edge, facing the player grid.
	local spawnX = -halfW + PlotConfig.SPAWN_EDGE_INSET
	addMarker(
		"EnemySpawn",
		originPosition + Vector3.new(spawnX, PlotConfig.SPAWN_HEIGHT, 0),
		base
	)

	local pathFolder = Instance.new("Folder")
	pathFolder.Name = "Path"
	pathFolder.Parent = model

	return model
end

return EnemySpawnBuilder
