--!strict
-- Permanent gardens in the side margins. Geometry never participates in raycasts.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config.PlotDecorConfig)
local PlotConfig = require(game:GetService("ReplicatedStorage").Shared.Config.PlotConfig)
local ModelUtil = require(game:GetService("ReplicatedStorage").Shared.Utilities.ModelUtil)
local Decor = require(script.Parent.ForestDecor)
local PlotDecor = {}

local function part(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material): Part
	local result = Decor.part(parent, name, size, CFrame.new(position), color, material)
	result.CastShadow = false
	return result
end

local function bush(parent: Instance, center: Vector3, template: Model?)
	if template then
		local model = ModelUtil.cloneTemplate(template, {
			targetFootprint = Config.BUSH_FOOTPRINT,
			targetHeight = Config.BUSH_HEIGHT,
			skipBodyAlias = true,
			anchorAllParts = true,
		})
		model.Name = "GardenBush"
		ModelUtil.pivotToTileTop(model, center)
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CastShadow = false
			end
		end
		model.Parent = parent
		return
	end
	local shrub = part(parent, "RoundShrub", Vector3.new(Config.BUSH_FOOTPRINT, Config.BUSH_HEIGHT, Config.BUSH_FOOTPRINT),
		center + Vector3.new(0, Config.BUSH_HEIGHT / 2, 0), Config.LEAF_COLOR, Enum.Material.Grass)
	shrub.Shape = Enum.PartType.Ball
end

local function bed(parent: Instance, center: Vector3, rng: Random)
	local model = Instance.new("Model")
	model.Name = "FlowerBed"
	part(model, "StoneBorder", Vector3.new(Config.BED_LENGTH, 0.6, Config.BED_DEPTH), center + Vector3.new(0, 0.3, 0), Config.EDGE_COLOR, Enum.Material.Slate)
	part(model, "Soil", Vector3.new(Config.BED_LENGTH - 1.2, 0.3, Config.BED_DEPTH - 1.2), center + Vector3.new(0, 0.65, 0), Config.SOIL_COLOR, Enum.Material.Ground)
	for index = 1, Config.FLOWERS_PER_BED do
		local x = (index / (Config.FLOWERS_PER_BED + 1) - 0.5) * Config.BED_LENGTH
		local height = rng:NextNumber(1.8, 3.1)
		local root = center + Vector3.new(x, 0.8, rng:NextNumber(-2, 2))
		part(model, "Stem", Vector3.new(0.35, height, 0.35), root + Vector3.new(0, height / 2, 0), Config.LEAF_COLOR, Enum.Material.SmoothPlastic)
		local color = Config.FLOWER_COLORS[rng:NextInteger(1, #Config.FLOWER_COLORS)]
		local bloom = part(model, "Blossom", Vector3.new(2.4, 1.2, 2.4), root + Vector3.new(0, height, 0), color, Enum.Material.SmoothPlastic)
		bloom.Shape = Enum.PartType.Ball
		part(model, "FlowerCenter", Vector3.new(0.8, 0.35, 0.8), root + Vector3.new(0, height + 0.6, 0), Config.FLOWER_COLORS[1], Enum.Material.SmoothPlastic).Shape = Enum.PartType.Ball
	end
	model.Parent = parent
end

local function bench(parent: Instance, center: Vector3, side: number)
	local model = Instance.new("Model")
	model.Name = "GardenBench"
	for _, x in { -3.5, 3.5 } do
		part(model, "Support", Vector3.new(1, 2.3, 3.5), center + Vector3.new(x, 1.15, 0), Config.EDGE_COLOR, Enum.Material.Slate)
	end
	part(model, "Seat", Vector3.new(10, 0.6, 4), center + Vector3.new(0, 2.5, 0), Config.WOOD_COLOR, Enum.Material.WoodPlanks)
	part(model, "Back", Vector3.new(10, 2.5, 0.6), center + Vector3.new(0, 4, side * 1.7), Config.WOOD_COLOR, Enum.Material.WoodPlanks)
	model.Parent = parent
end

function PlotDecor.build(plot: Model, origin: Vector3, playLeftX: number, index: number)
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery" -- outside Plot.release's per-owner folders
	local paths = Instance.new("Folder")
	paths.Name, paths.Parent = "Paths", scenery
	local rng = Random.new(Config.SEED + index)
	local bushTemplate = ModelUtil.findDecorTemplate(Config.BUSH_MODEL_ID)
	local halfDepth = PlotConfig.GRID_DEPTH / 2
	-- Keep each garden in its own half of the gap between plot centers.
	local gardenZ = math.min(halfDepth + Config.GARDEN_OFFSET, PlotConfig.LANE_PITCH / 2 - 14)
	for _, side in { -1, 1 } do
		local pathZ = side * (halfDepth + Config.PATH_OFFSET)
		part(paths, "GardenWalk", Vector3.new(PlotConfig.GRID_WIDTH, 0.12, Config.PATH_WIDTH),
			origin + Vector3.new(playLeftX + PlotConfig.GRID_WIDTH / 2, 0.08, pathZ), Config.PATH_COLOR, Enum.Material.Pebble)
		for station = 1, Config.BEDS_PER_SIDE do
			local x = playLeftX + PlotConfig.GRID_WIDTH * (station - 0.5) / Config.BEDS_PER_SIDE
			local center = origin + Vector3.new(x, 0, side * gardenZ)
			bed(scenery, center, rng)
			for _, offset in { -1, 1 } do
				bush(scenery, center + Vector3.new(offset * (Config.BED_LENGTH / 2 + 5), 0, 0), bushTemplate)
			end
		end
		bench(scenery, origin + Vector3.new(playLeftX - 18, 0, side * gardenZ), side)
		Decor.tree(scenery, origin + Vector3.new(playLeftX - 40, 0, side * gardenZ), Config.TREE_SCALE, rng, 0)
	end
	scenery.Parent = plot
end

return PlotDecor
