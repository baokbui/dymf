--!strict
--[[
	PlotBuilder
	Procedurally constructs a single plot (a full-width lane) from PlotConfig.
	Kept separate from PlotService so the service stays focused on lifecycle.

	The whole world floor is one grass baseplate; plots are open lanes (no
	collision barriers) so players can walk between plots to spectate. Gameplay
	isolation stays server-side (plant / coin / shovel only on your own plot).
	Within a lane, left (-X) -> right (+X) is: house zone, play area (grid).
	Enemy staging lives in the east map column (see EnemySpawnBuilder).

	A plot contains:

		Base           - INVISIBLE, non-colliding region marker (origin + future
		                 placement raycast target)
		SpawnLocation  - left edge of the play area, facing the enemy (+X)
		HouseAnchor    - attachment marking the house spot behind the player
		House          - walkable cottage + Brainrot shop stall (M18)
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
local HouseBuilder = require(script.Parent.HouseBuilder)
local StoreService = require(script.Parent.Parent.StoreService)

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

	local halfW = width / 2

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

	local houseZoneWestX = leftEdge + PlotConfig.MARGIN_X
	local house = HouseBuilder.build(originPosition, houseZoneWestX, playLeftX)
	house.Parent = model
	StoreService.attachToHouse(model, house)

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
