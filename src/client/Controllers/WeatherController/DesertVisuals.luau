--!strict
--[[
	DesertVisuals
	Client-only desert décor: hide the entire DarkForest locally, sand the
	Baseplate, and place pyramid ranks in the east column (near + behind).
]]

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local GridConfig = require(Shared.Config.GridConfig)
local PlotConfig = require(Shared.Config.PlotConfig)
local WeatherConfig = require(Shared.Config.WeatherConfig)
local ModelUtil = require(Shared.Utilities.ModelUtil)

local DesertVisuals = {}

local DECOR_FOLDER = "ClientDesertDecor"
local SAND_BED_NAME = "ClientDesertSandBed"
local PYRAMID_LAYOUT = 5
local decorFolder: Folder? = nil
local builtPyramidLayout = 0
local sandBeds: { BasePart } = {}
local forestHiddenConn: RBXScriptConnection? = nil
local paintedBaseplate: BasePart? = nil
local savedBaseplateColor: Color3? = nil
local savedBaseplateMaterial: Enum.Material? = nil

local function harden(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
end

local function darkForest(): Instance?
	local maps = Workspace:FindFirstChild(Constants.WORKSPACE_FOLDERS.Maps)
	return maps and maps:FindFirstChild("DarkForest")
end

local function hideForestPart(instance: Instance, hidden: boolean)
	if instance:IsA("BasePart") then
		instance.LocalTransparencyModifier = if hidden then 1 else 0
	elseif instance:IsA("Decal") or instance:IsA("Texture") then
		instance.Transparency = if hidden then 1 else 0
	elseif instance:IsA("ParticleEmitter") or instance:IsA("Beam") or instance:IsA("Trail") then
		instance.Enabled = not hidden
	end
end

local function setForestHidden(hidden: boolean)
	if forestHiddenConn then
		forestHiddenConn:Disconnect()
		forestHiddenConn = nil
	end
	local forest = darkForest()
	if not forest then
		return
	end
	for _, descendant in forest:GetDescendants() do
		hideForestPart(descendant, hidden)
	end
	if hidden then
		forestHiddenConn = forest.DescendantAdded:Connect(function(instance)
			hideForestPart(instance, true)
		end)
	end
end

local function paintBaseplate(desert: boolean)
	local ground = Workspace:FindFirstChild("Baseplate")
	if not (ground and ground:IsA("BasePart")) then
		paintedBaseplate = nil
		return
	end
	if desert then
		if paintedBaseplate ~= ground then
			savedBaseplateColor = ground.Color
			savedBaseplateMaterial = ground.Material
			paintedBaseplate = ground
		end
		ground.Color = WeatherConfig.DESERT_BASEPLATE_COLOR
		ground.Material = WeatherConfig.DESERT_TILE_MATERIAL
	else
		if paintedBaseplate == ground then
			if savedBaseplateColor then
				ground.Color = savedBaseplateColor
			end
			if savedBaseplateMaterial then
				ground.Material = savedBaseplateMaterial
			end
		end
		paintedBaseplate = nil
		savedBaseplateColor = nil
		savedBaseplateMaterial = nil
	end
end

local function paintLawnPlots(desert: boolean)
	for _, tile in CollectionService:GetTagged(Constants.TAGS.GridTile) do
		if not tile:IsA("BasePart") then
			continue
		end
		local row = tile:GetAttribute("Row")
		local column = tile:GetAttribute("Column")
		if type(row) ~= "number" or type(column) ~= "number" then
			continue
		end
		local isLight = (row + column) % 2 == 0
		if desert then
			tile.Material = WeatherConfig.DESERT_TILE_MATERIAL
			tile.Color = if isLight then WeatherConfig.DESERT_TILE_COLOR_A else WeatherConfig.DESERT_TILE_COLOR_B
		else
			tile.Material = GridConfig.TILE_MATERIAL
			tile.Color = if isLight then GridConfig.TILE_COLOR_A else GridConfig.TILE_COLOR_B
		end
	end
end

local function clearSandBeds()
	for _, bed in sandBeds do
		if bed.Parent then
			bed:Destroy()
		end
	end
	table.clear(sandBeds)
end

local function addSandBed(plotModel: Model)
	local gridFolder = plotModel:FindFirstChild("Grid")
	if not gridFolder then
		return
	end
	local existing = gridFolder:FindFirstChild(SAND_BED_NAME)
	if existing and existing:IsA("BasePart") then
		table.insert(sandBeds, existing)
		return
	end
	local base = plotModel.PrimaryPart
	if not base then
		return
	end
	local bed = Instance.new("Part")
	bed.Name = SAND_BED_NAME
	bed.Anchored = true
	bed.CanCollide = false
	bed.CanQuery = false
	bed.CanTouch = false
	bed.CastShadow = false
	bed.Material = WeatherConfig.DESERT_TILE_MATERIAL
	bed.Color = WeatherConfig.DESERT_SAND_BED_COLOR
	bed.Size = Vector3.new(
		PlotConfig.BASE_WIDTH,
		WeatherConfig.DESERT_SAND_BED_THICKNESS,
		PlotConfig.BASE_DEPTH
	)
	local thickness = WeatherConfig.DESERT_SAND_BED_THICKNESS
	bed.Position = Vector3.new(base.Position.X, thickness / 2 + 0.02, base.Position.Z)
	bed.Parent = gridFolder
	table.insert(sandBeds, bed)
end

local function paintPlotSandBeds(desert: boolean)
	clearSandBeds()
	if not desert then
		return
	end
	local plotsFolder = Workspace:FindFirstChild(Constants.WORKSPACE_FOLDERS.Plots)
	if not plotsFolder then
		return
	end
	for _, child in plotsFolder:GetChildren() do
		if child:IsA("Model") then
			addSandBed(child)
		end
	end
end

local function clearDecor()
	if decorFolder then
		decorFolder:Destroy()
		decorFolder = nil
	end
end

local function addProceduralPyramid(parent: Instance, position: Vector3, baseSize: number, height: number)
	local layers = 5
	for index = 1, layers do
		local t = (index - 1) / layers
		local size = math.max(4, baseSize * (1 - t * 0.82))
		local layerHeight = height / layers
		local part = Instance.new("Part")
		part.Name = "PyramidLayer"
		part.Size = Vector3.new(size, layerHeight, size)
		part.CFrame = CFrame.new(position + Vector3.new(0, layerHeight * (index - 0.5), 0))
		part.Material = WeatherConfig.DESERT_PYRAMID_MATERIAL
		part.Color = WeatherConfig.DESERT_PYRAMID_COLOR
		harden(part)
		part.Parent = parent
	end
end

local function forestBounds(plotModel: Model): (Vector3, Vector3)
	local forest = darkForest()
	local floor = forest and forest:FindFirstChild("ForestFloor")
	if floor and floor:IsA("BasePart") then
		local size = floor.Size
		local pos = floor.Position
		return pos - size / 2, pos + size / 2
	end

	local base = plotModel.PrimaryPart
	local origin = if base then base.Position else plotModel:GetPivot().Position
	local enemyCenterX = origin.X + PlotConfig.BASE_WIDTH
	local halfW = PlotConfig.BASE_WIDTH / 2
	local minX = enemyCenterX - halfW + PlotConfig.FOREST_CLEAR_WEST
	local maxX = enemyCenterX + halfW - PlotConfig.FOREST_MARGIN_EAST
	local minZ = origin.Z - PlotConfig.LANE_PITCH / 2
	local maxZ = origin.Z
		+ (PlotConfig.LANE_ROWS - 1) * PlotConfig.LANE_PITCH
		+ PlotConfig.LANE_PITCH / 2
	return Vector3.new(minX, 0, minZ), Vector3.new(maxX, 0, maxZ)
end

local function placeTemplatePyramid(parent: Instance, position: Vector3, targetWidth: number)
	local template = ModelUtil.findDecorTemplate(WeatherConfig.DESERT_PYRAMID_MODEL_ID)
	if not template then
		addProceduralPyramid(parent, position, targetWidth, targetWidth * 0.72)
		return
	end
	local ok, model = pcall(function()
		return ModelUtil.cloneTemplate(template, { skipBodyAlias = true })
	end)
	if not ok or typeof(model) ~= "Instance" then
		addProceduralPyramid(parent, position, targetWidth, targetWidth * 0.72)
		return
	end
	local clone = model :: Model
	clone.Name = "Pyramid"
	clone.Parent = parent
	local size = clone:GetExtentsSize()
	local scale = if size.X > 0.1 then targetWidth / size.X else 1
	clone:ScaleTo(math.clamp(scale, 0.2, 8))
	ModelUtil.snapFeetToTileTop(clone, Vector3.new(position.X, 0, position.Z))
end

local function mapLimits(): (number, number, number, number)
	local inset = PlotConfig.POOL_MARGIN + 12
	local ground = Workspace:FindFirstChild("Baseplate")
	if ground and ground:IsA("BasePart") then
		local half = ground.Size * 0.5
		local pos = ground.Position
		return pos.X - half.X + inset, pos.X + half.X - inset, pos.Z - half.Z + inset, pos.Z + half.Z - inset
	end
	local half = PlotConfig.BASEPLATE_SIZE * 0.5
	return -half + inset, half - inset, -half + inset, half - inset
end

local function onMap(x: number, z: number, halfWidth: number): (number, number, boolean)
	local minX, maxX, minZ, maxZ = mapLimits()
	local pad = math.max(8, halfWidth * 0.45)
	local cx = math.clamp(x, minX + pad, maxX - pad)
	local cz = math.clamp(z, minZ + pad, maxZ - pad)
	local inside = x >= minX and x <= maxX and z >= minZ and z <= maxZ
	return cx, cz, inside
end

local function pyramidWidth(index: number, preferLarge: boolean): number
	-- Repeating mix: small, large, medium, large (half large, rest split).
	local slot = (index - 1) % 4
	if preferLarge then
		if slot == 0 then
			return WeatherConfig.DESERT_PYRAMID_MEDIUM
		elseif slot == 2 then
			return WeatherConfig.DESERT_PYRAMID_SMALL
		end
		return WeatherConfig.DESERT_PYRAMID_LARGE
	end
	if slot == 1 then
		return WeatherConfig.DESERT_PYRAMID_LARGE
	elseif slot == 3 then
		return WeatherConfig.DESERT_PYRAMID_MEDIUM
	end
	return WeatherConfig.DESERT_PYRAMID_SMALL
end

local function placeBand(
	folder: Folder,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	spacing: number,
	limit: number,
	preferLarge: boolean
)
	local placed = 0
	local index = 0
	local row = 0
	for x = minX, maxX, spacing do
		row += 1
		local stagger = if row % 2 == 0 then 0 else spacing * 0.5
		for z = minZ + stagger, maxZ, spacing do
			index += 1
			placed += 1
			if placed > limit then
				return
			end
			local jx = ((index * 19) % 21) - 10
			local jz = ((index * 29) % 21) - 10
			local width = pyramidWidth(index, preferLarge)
			local px, pz, onPlate = onMap(x + jx, z + jz, width * 0.5)
			if not onPlate then
				continue
			end
			placeTemplatePyramid(folder, Vector3.new(px, 0, pz), width)
		end
	end
end

local function buildPyramids(plotModel: Model)
	clearDecor()
	local folder = Instance.new("Folder")
	folder.Name = DECOR_FOLDER
	folder.Parent = plotModel
	decorFolder = folder

	local minV, maxV = forestBounds(plotModel)
	if maxV.X <= minV.X or maxV.Z <= minV.Z then
		return
	end

	local mapMinX, mapMaxX, mapMinZ, mapMaxZ = mapLimits()
	local splitX = minV.X + (maxV.X - minV.X) * 0.42
	local nearSpacing = WeatherConfig.DESERT_PYRAMID_SPACING
	local backSpacing = WeatherConfig.DESERT_PYRAMID_BACK_SPACING
	local zPad = nearSpacing * 0.35
	local bandMinZ = math.max(minV.Z + zPad, mapMinZ)
	local bandMaxZ = math.min(maxV.Z - zPad, mapMaxZ)

	-- Front rank: closer to the plots (west side of the old forest).
	placeBand(
		folder,
		math.max(minV.X + nearSpacing * 0.35, mapMinX),
		math.min(splitX, mapMaxX),
		bandMinZ,
		bandMaxZ,
		nearSpacing,
		WeatherConfig.DESERT_PYRAMID_COUNT,
		false
	)

	-- Back rank: east of the front pyramids, still on the Baseplate.
	local backMaxX = math.min(maxV.X + WeatherConfig.DESERT_PYRAMID_EAST_EXTRA, mapMaxX)
	placeBand(
		folder,
		math.max(splitX + backSpacing * 0.4, mapMinX),
		backMaxX,
		bandMinZ,
		bandMaxZ,
		backSpacing,
		WeatherConfig.DESERT_PYRAMID_BACK_COUNT,
		true
	)

	local midZ = math.clamp((minV.Z + maxV.Z) * 0.5, mapMinZ, mapMaxZ)
	local function placeLandmark(x: number, z: number, width: number)
		local px, pz, onPlate = onMap(x, z, width * 0.5)
		if onPlate then
			placeTemplatePyramid(folder, Vector3.new(px, 0, pz), width)
		end
	end
	placeLandmark(backMaxX - 18, midZ - 120, WeatherConfig.DESERT_PYRAMID_LARGE + 20)
	placeLandmark(backMaxX - 40, midZ + 130, WeatherConfig.DESERT_PYRAMID_LARGE)
end

function DesertVisuals.clear()
	clearDecor()
	builtPyramidLayout = 0
	clearSandBeds()
	paintLawnPlots(false)
	setForestHidden(false)
	paintBaseplate(false)
end

function DesertVisuals.apply(plotModel: Model)
	setForestHidden(true)
	paintBaseplate(true)
	paintLawnPlots(true)
	paintPlotSandBeds(true)
	if decorFolder and decorFolder.Parent == plotModel and builtPyramidLayout == PYRAMID_LAYOUT then
		return
	end
	builtPyramidLayout = PYRAMID_LAYOUT
	buildPyramids(plotModel)
end

return DesertVisuals
