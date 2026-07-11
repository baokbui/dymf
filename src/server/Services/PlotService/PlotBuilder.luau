--!strict
--[[
	PlotBuilder
	Procedurally constructs a single plot (a full-width lane) from PlotConfig.
	Kept separate from PlotService so the service stays focused on lifecycle.

	The whole world floor is one grass baseplate; plots are lanes of it divided
	by clear glass barriers. Within a lane, left (-X) -> right (+X) is:
	house zone, play area (grid). Enemy staging lives in the east map column
	(see EnemySpawnBuilder). A plot contains:

		Base           - INVISIBLE, non-colliding region marker (origin + future
		                 placement raycast target)
		Barriers       - clear glass containment walls (North/South divide lanes,
		                 West is the field's left edge; East is open toward the
		                 adjacent enemy-spawn lane)
		SpawnLocation  - left edge of the play area, facing the enemy (+X)
		HouseAnchor    - attachment marking the house spot behind the player (M-later)
		CoinSpawner    - attachment at the lane center (M3)
		GridCenter     - attachment at the play-area center; GridService lays the
		                 tile grid out from here (M2)
		Grid           - folder GridService fills with static tiles (M2)
		Path/Decorations/Projectiles/Monsters/Brainrots/Coins - content folders
		                 (Projectiles is always present so client combat SFX never
		                 blocks waiting for a lazily created folder)

	build() returns the model, its base part, and the spawn location.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotConfig = require(ReplicatedStorage.Shared.Config.PlotConfig)

local PlotBuilder = {}

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
	-- Parent BEFORE setting WorldPosition: while unparented, WorldPosition is
	-- treated as a local offset and would be doubled once parented to the base.
	attachment.Parent = parent
	attachment.WorldPosition = worldPosition
end

local function addFolder(name: string, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
end

-- Builds a lane plot centered (in X) on originPosition, at grass level (Y).
function PlotBuilder.build(index: number, originPosition: Vector3): (Model, BasePart, SpawnLocation)
	local width = PlotConfig.BASE_WIDTH
	local depth = PlotConfig.BASE_DEPTH
	local thickness = PlotConfig.BASE_THICKNESS
	local barrierHeight = PlotConfig.BARRIER_HEIGHT
	local barrierThickness = PlotConfig.BARRIER_THICKNESS

	local model = Instance.new("Model")
	model.Name = string.format("Plot%d", index)

	-- Invisible, non-colliding region marker. The visible grass is the shared
	-- baseplate; this defines the plot origin and placement raycast target.
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

	-- Clear glass containment walls.
	local barriers = Instance.new("Folder")
	barriers.Name = "Barriers"
	barriers.Parent = model

	local halfW = width / 2
	local halfD = depth / 2
	local wallY = originPosition.Y + barrierHeight / 2
	local groundXZ = Vector3.new(originPosition.X, 0, originPosition.Z)
	-- North/South run along X and divide neighbouring lanes.
	local longSize = Vector3.new(width + barrierThickness * 2, barrierHeight, barrierThickness)
	-- West/East run along Z and form the field's left/right edges.
	local sideSize = Vector3.new(barrierThickness, barrierHeight, depth)

	addBarrier("North", longSize, groundXZ + Vector3.new(0, wallY, halfD + barrierThickness / 2), barriers)
	addBarrier("South", longSize, groundXZ + Vector3.new(0, wallY, -(halfD + barrierThickness / 2)), barriers)
	addBarrier("West", sideSize, groundXZ + Vector3.new(-(halfW + barrierThickness / 2), wallY, 0), barriers)
	-- East is open toward the adjacent enemy-spawn lane (monsters enter from +X).

	-- Zone X offsets relative to the lane center.
	local leftEdge = -halfW
	local playLeftX = leftEdge + PlotConfig.MARGIN_X + PlotConfig.HOUSE_ZONE
	local playRightX = playLeftX + PlotConfig.GRID_WIDTH
	local houseCenterX = leftEdge + PlotConfig.MARGIN_X + PlotConfig.HOUSE_ZONE / 2
	local playCenterX = (playLeftX + playRightX) / 2

	-- Spawn at the left edge of the play area, facing the enemy (+X). A real
	-- SpawnLocation (directed per-player via RespawnLocation) avoids teleport-
	-- on-spawn override races.
	local spawnPosition = originPosition
		+ Vector3.new(playLeftX + PlotConfig.SPAWN_EDGE_INSET, PlotConfig.SPAWN_HEIGHT, 0)

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "SpawnLocation"
	spawnLocation.Size = Vector3.new(6, 1, 6)
	spawnLocation.Anchored = true
	spawnLocation.Locked = true
	spawnLocation.CanCollide = false
	spawnLocation.Transparency = 1
	spawnLocation.Neutral = true
	spawnLocation.Enabled = true
	spawnLocation.Duration = 0
	local padCenter = Vector3.new(spawnPosition.X, originPosition.Y + 0.5, spawnPosition.Z)
	spawnLocation.CFrame = CFrame.lookAt(padCenter, padCenter + Vector3.new(1, 0, 0))
	spawnLocation.Parent = model

	-- Markers for later milestones.
	addMarker("HouseAnchor", originPosition + Vector3.new(houseCenterX, PlotConfig.SPAWN_HEIGHT, 0), base)
	addMarker("CoinSpawner", originPosition + Vector3.new(0, PlotConfig.SPAWN_HEIGHT, 0), base)
	-- Grid anchor at the play-area center (grass level); GridService builds from here.
	addMarker("GridCenter", originPosition + Vector3.new(playCenterX, 0, 0), base)

	-- Empty folders for content added by later milestones.
	addFolder("Grid", model)
	addFolder("Path", model)
	addFolder("Decorations", model)
	addFolder("Projectiles", model)
	addFolder("Monsters", model)
	addFolder("Brainrots", model)
	addFolder("Coins", model)

	return model, base, spawnLocation
end

return PlotBuilder
