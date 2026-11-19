--!strict
-- Seeded, static woodland. Gameplay still owns the east-column march; all
-- scenery is non-colliding/non-queryable and hides with DesertVisuals.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlotConfig = require(ReplicatedStorage.Shared.Config.PlotConfig)
local Decor = require(script.Parent.ForestDecor)
local WorldStyle = require(ReplicatedStorage.Shared.Utilities.WorldStyle)
local ForestBuilder = {}

function ForestBuilder.build(enemyColumnCenterX: number, startZ: number): Folder
	local folder = Instance.new("Folder")
	folder.Name = "DarkForest"
	local halfW = PlotConfig.BASE_WIDTH / 2
	local minX = enemyColumnCenterX - halfW + PlotConfig.FOREST_CLEAR_WEST
	local maxX = enemyColumnCenterX + halfW - PlotConfig.FOREST_MARGIN_EAST
	local minZ = startZ - PlotConfig.LANE_PITCH / 2 + PlotConfig.FOREST_MARGIN_Z
	local maxZ = startZ + (PlotConfig.LANE_ROWS - 1) * PlotConfig.LANE_PITCH
		+ PlotConfig.LANE_PITCH / 2 - PlotConfig.FOREST_MARGIN_Z
	if maxX <= minX or maxZ <= minZ then
		return folder
	end

	-- Retain this direct child and exact footprint: DesertVisuals uses it to
	-- place its replacement pyramids. It is only an invisible bounds marker;
	-- the shared grass receives actual canopy shadows.
	local floor = Decor.part(folder, "ForestFloor", Vector3.new(maxX - minX, 0.2, maxZ - minZ),
		CFrame.new((minX + maxX) / 2, 0.02, (minZ + maxZ) / 2),
		PlotConfig.FOREST_GROUND_COLOR, Enum.Material.Ground)
	floor.Transparency = 1
	floor.CastShadow = false
	local rng = Random.new(PlotConfig.FOREST_SEED)
	local spacing = PlotConfig.FOREST_SPACING
	local inset = PlotConfig.FOREST_CANOPY_INSET
	local row = 0
	for x = minX + inset, maxX - inset, spacing do
		row += 1
		local depth = (x - minX) / (maxX - minX)
		local stagger = if row % 2 == 0 then spacing / 2 else 0
		for z = minZ + inset + stagger, maxZ - inset, spacing do
			if rng:NextNumber() < PlotConfig.FOREST_CLEARING_CHANCE then
				continue
			end
			local px = math.clamp(x + rng:NextNumber(-PlotConfig.FOREST_JITTER, PlotConfig.FOREST_JITTER), minX + inset, maxX - inset)
			local pz = math.clamp(z + rng:NextNumber(-PlotConfig.FOREST_JITTER, PlotConfig.FOREST_JITTER), minZ + inset, maxZ - inset)
			local scale = rng:NextNumber(PlotConfig.FOREST_MIN_SCALE, PlotConfig.FOREST_MAX_SCALE)
				+ depth * PlotConfig.FOREST_REAR_HEIGHT_BONUS
			Decor.tree(folder, Vector3.new(px, 0, pz), scale, rng, depth)
		end
	end

	-- Low shrubs and rocks soften the edge without painting over the grass.
	for z = minZ + inset, maxZ - inset, PlotConfig.FOREST_EDGE_SPACING do
		local x = minX + rng:NextNumber(4, 14)
		Decor.undergrowth(folder, Vector3.new(x, 0, z), rng)
	end
	WorldStyle.apply(folder, "Scenery")
	return folder
end

return ForestBuilder
