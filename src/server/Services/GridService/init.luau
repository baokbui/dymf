--!strict
--[[
	GridService
	Server-authoritative battlefield grid. At startup it builds a static tile
	grid into every plot's "Grid" folder (centered on the plot's GridCenter
	marker) and tracks per-tile occupancy. Tiles are physical, replicated parts
	tagged GridTile with Row/Column/Occupied attributes so clients can render
	and highlight them without extra remotes.

	Occupancy is the source of truth for placement (Milestone 4): other services
	ask GridService whether a tile is free and reserve it. Tiles are reused
	across plot owners — resetPlot() clears occupancy rather than rebuilding.

	Milestone 2.
]]

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local GridConfig = require(Shared.Config.GridConfig)
local PlotConfig = require(Shared.Config.PlotConfig)
local GridUtil = require(Shared.Utilities.GridUtil)
local WorldStyle = require(Shared.Utilities.WorldStyle)
local Logger = require(Shared.Utilities.Logger)
local Types = require(Shared.Types)

local GridService = {}
GridService.Name = "GridService"

local log = Logger.new(GridService.Name)

type TileRecord = {
	position: Types.GridPosition,
	occupied: boolean,
	brainrotInstanceId: string?,
	part: BasePart,
}

-- plotModel -> (tileKey -> record). Keyed by the plot Model (stable; reused).
local grids: { [Model]: { [string]: TileRecord } } = {}

local function paintGrass(part: BasePart, position: Types.GridPosition)
	local isLight = (position.row + position.column) % 2 == 0
	part.Material = GridConfig.TILE_MATERIAL
	part.Color = if isLight then GridConfig.TILE_COLOR_A else GridConfig.TILE_COLOR_B
	WorldStyle.applyPart(part, "Ground")
end

local function createTile(position: Types.GridPosition, center: Vector3, parent: Instance): BasePart
	local inset = PlotConfig.TILE_SIZE - GridConfig.TILE_GAP
	local tile = Instance.new("Part")
	tile.Name = string.format("Tile_%d_%d", position.row, position.column)
	tile.Size = Vector3.new(inset, GridConfig.TILE_HEIGHT, inset)
	tile.Position = center
	tile.Anchored = true
	tile.Locked = true
	tile.CanCollide = false
	tile.CastShadow = false
	tile.TopSurface = Enum.SurfaceType.Smooth
	tile.BottomSurface = Enum.SurfaceType.Smooth
	tile.Material = GridConfig.TILE_MATERIAL
	tile.Transparency = GridConfig.TILE_TRANSPARENCY
	paintGrass(tile, position)

	tile:SetAttribute("Row", position.row)
	tile:SetAttribute("Column", position.column)
	tile:SetAttribute("Occupied", false)
	CollectionService:AddTag(tile, Constants.TAGS.GridTile)

	tile.Parent = parent
	return tile
end

local function buildGrid(plotModel: Model)
	if grids[plotModel] then
		return -- already built
	end

	local gridFolder = plotModel:FindFirstChild("Grid")
	if not gridFolder then
		log:warn("plot has no Grid folder:", plotModel.Name)
		return
	end

	local base = plotModel.PrimaryPart
	local anchor = base and base:FindFirstChild("GridCenter")
	if not anchor or not anchor:IsA("Attachment") then
		log:warn("plot has no GridCenter marker:", plotModel.Name)
		return
	end

	-- Lay tiles out from the grid's near corner so the grid centers on the
	-- play area. Tiles sit just above the grass surface.
	local dims = GridUtil.dimensions()
	local centerWorld = anchor.WorldPosition
	local cornerX = centerWorld.X - dims.X / 2
	local cornerZ = centerWorld.Z - dims.Z / 2
	local tileY = centerWorld.Y + GridConfig.TILE_Y_OFFSET + GridConfig.TILE_HEIGHT / 2

	local tiles: { [string]: TileRecord } = {}
	for _, position in GridUtil.positions() do
		local offset = GridUtil.toLocalOffset(position)
		local tileCenter = Vector3.new(cornerX + offset.X, tileY, cornerZ + offset.Z)
		local part = createTile(position, tileCenter, gridFolder)
		tiles[GridUtil.toKey(position)] = {
			position = position,
			occupied = false,
			brainrotInstanceId = nil,
			part = part,
		}
	end

	grids[plotModel] = tiles
end

local function getRecord(plotModel: Model, position: Types.GridPosition): TileRecord?
	local tiles = grids[plotModel]
	if not tiles then
		return nil
	end
	return tiles[GridUtil.toKey(position)]
end

function GridService.init()
end

function GridService.start()
	-- Plots are built during PlotService.init, which runs before any start(),
	-- so the pool exists here regardless of service discovery order.
	local plotsFolder = Workspace:FindFirstChild(Constants.WORKSPACE_FOLDERS.Plots)
	local built = 0
	if plotsFolder then
		for _, child in plotsFolder:GetChildren() do
			if child:IsA("Model") then
				buildGrid(child)
				local gridFolder = child:FindFirstChild("Grid")
				local leftover = gridFolder and gridFolder:FindFirstChild("DesertSandBed")
				if leftover then
					leftover:Destroy()
				end
				built += 1
			end
		end
	end
	log:info(string.format("built grids for %d plot(s)", built))
end

-- Read-only snapshot of a tile's state (nil if out of bounds / unknown plot).
function GridService.getTile(plotModel: Model, position: Types.GridPosition): Types.Tile?
	local record = getRecord(plotModel, position)
	if not record then
		return nil
	end
	return {
		position = record.position,
		occupied = record.occupied,
		brainrotInstanceId = record.brainrotInstanceId,
	}
end

function GridService.isOccupied(plotModel: Model, position: Types.GridPosition): boolean
	local record = getRecord(plotModel, position)
	return record ~= nil and record.occupied
end

-- World position at the top-center of a tile (where a Brainrot would sit).
function GridService.getWorldPosition(plotModel: Model, position: Types.GridPosition): Vector3?
	local record = getRecord(plotModel, position)
	if not record then
		return nil
	end
	return record.part.Position + Vector3.new(0, record.part.Size.Y / 2, 0)
end

-- World position at a fractional column on a row (for monster movement).
function GridService.getWorldPositionAtColumn(plotModel: Model, row: number, column: number): Vector3?
	local tiles = grids[plotModel]
	if not tiles then
		return nil
	end

	local base = plotModel.PrimaryPart
	local anchor = base and base:FindFirstChild("GridCenter")
	if not anchor or not anchor:IsA("Attachment") then
		return nil
	end

	local dims = GridUtil.dimensions()
	local centerWorld = anchor.WorldPosition
	local cornerX = centerWorld.X - dims.X / 2
	local cornerZ = centerWorld.Z - dims.Z / 2
	local tileY = centerWorld.Y + GridConfig.TILE_Y_OFFSET + GridConfig.TILE_HEIGHT / 2
	local size = PlotConfig.TILE_SIZE

	local x = cornerX + (column - 0.5) * size
	local z = cornerZ + (row - 0.5) * size
	return Vector3.new(x, tileY, z)
end

-- Inverse of getWorldPositionAtColumn's X mapping (fractional column).
function GridService.worldXToColumn(plotModel: Model, worldX: number): number?
	local base = plotModel.PrimaryPart
	local anchor = base and base:FindFirstChild("GridCenter")
	if not anchor or not anchor:IsA("Attachment") then
		return nil
	end
	local dims = GridUtil.dimensions()
	local cornerX = anchor.WorldPosition.X - dims.X / 2
	local size = PlotConfig.TILE_SIZE
	if size <= 0 then
		return nil
	end
	return (worldX - cornerX) / size + 0.5
end

-- Tile under a world point, or nil if off the lawn.
function GridService.worldToGrid(plotModel: Model, worldPos: Vector3): Types.GridPosition?
	local base = plotModel.PrimaryPart
	local anchor = base and base:FindFirstChild("GridCenter")
	if not anchor or not anchor:IsA("Attachment") then
		return nil
	end
	local dims = GridUtil.dimensions()
	local cornerX = anchor.WorldPosition.X - dims.X / 2
	local cornerZ = anchor.WorldPosition.Z - dims.Z / 2
	local position = GridUtil.fromLocalOffset(Vector3.new(worldPos.X - cornerX, 0, worldPos.Z - cornerZ))
	if not GridUtil.isInBounds(position) then
		return nil
	end
	return position
end

-- Top-center of a random grid tile on the plot (for passive coin drops).
function GridService.getRandomWorldPosition(plotModel: Model): Vector3?
	local position = GridUtil.randomPosition()
	return GridService.getWorldPosition(plotModel, position)
end

-- Reserves a tile. Returns false if the tile is unknown, out of bounds, or
-- already occupied. Server-authoritative gate used by placement (Milestone 4).
-- Reserves a tile. `brainrotInstanceId` nil = blocking prop (grave): plants
-- cannot place, but monsters do not chew (nearestBrainrotWest requires an id).
function GridService.tryOccupy(plotModel: Model, position: Types.GridPosition, brainrotInstanceId: string?): boolean
	if not GridUtil.isInBounds(position) then
		return false
	end
	local record = getRecord(plotModel, position)
	if not record or record.occupied then
		return false
	end
	record.occupied = true
	record.brainrotInstanceId = brainrotInstanceId
	record.part:SetAttribute("Occupied", true)
	return true
end

function GridService.setGraveFlag(plotModel: Model, position: Types.GridPosition, isGrave: boolean)
	local record = getRecord(plotModel, position)
	if not record then
		return
	end
	record.part:SetAttribute("Grave", isGrave)
end

function GridService.isGraveTile(plotModel: Model, position: Types.GridPosition): boolean
	local record = getRecord(plotModel, position)
	return record ~= nil and record.part:GetAttribute("Grave") == true
end

-- Grave tiles are occupied with a nil Brainrot id. Grave-busters claim the
-- same tile without treating it as a normal plant conflict.
function GridService.tryOccupyOverGrave(
	plotModel: Model,
	position: Types.GridPosition,
	brainrotInstanceId: string
): boolean
	if not GridUtil.isInBounds(position) then
		return false
	end
	local record = getRecord(plotModel, position)
	if not record or not record.occupied or record.brainrotInstanceId ~= nil then
		return false
	end
	record.brainrotInstanceId = brainrotInstanceId
	record.part:SetAttribute("Occupied", true)
	return true
end

-- After a grave-buster dies mid-channel: tile stays a grave (no Brainrot id).
function GridService.revertToGrave(plotModel: Model, position: Types.GridPosition): boolean
	local record = getRecord(plotModel, position)
	if not record then
		return false
	end
	record.occupied = true
	record.brainrotInstanceId = nil
	record.part:SetAttribute("Occupied", true)
	record.part:SetAttribute("Grave", true)
	return true
end

-- Frees a single tile.
function GridService.release(plotModel: Model, position: Types.GridPosition)
	local record = getRecord(plotModel, position)
	if not record then
		return
	end
	record.occupied = false
	record.brainrotInstanceId = nil
	record.part:SetAttribute("Occupied", false)
	record.part:SetAttribute("Grave", false)
end

-- Clears all occupancy on a plot (called when a plot is released for reuse).
function GridService.resetPlot(plotModel: Model)
	local tiles = grids[plotModel]
	if not tiles then
		return
	end
	for _, record in tiles do
		record.occupied = false
		record.brainrotInstanceId = nil
		record.part:SetAttribute("Occupied", false)
		record.part:SetAttribute("Grave", false)
		paintGrass(record.part, record.position)
	end
	local leftover = plotModel:FindFirstChild("Grid")
	local bed = leftover and leftover:FindFirstChild("DesertSandBed")
	if bed then
		bed:Destroy()
	end
end

return GridService
