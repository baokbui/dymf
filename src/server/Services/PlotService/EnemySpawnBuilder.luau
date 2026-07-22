--!strict
--[[
	EnemySpawnBuilder
	Procedurally constructs one enemy-spawn lane in the east map column. Each lane
	aligns with a player plot row; monsters stage here and enter the matching
	player plot from +X.

	No collision barriers — players may walk through to spectate. Monster
	movement is grid-based (not physics), so walls are unnecessary.

	Contains:

		Base        - invisible region marker
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

	local halfW = width / 2

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
