--!strict
--[[
	ForestBuilder
	Fills the east (enemy-spawn) map column with a dense dark forest. Visual
	only — all parts are non-colliding so spectating and grid monster movement
	are unaffected. Built once at PlotService init.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotConfig = require(ReplicatedStorage.Shared.Config.PlotConfig)

local ForestBuilder = {}

local function hardenDecor(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.Locked = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function addTree(parent: Folder, position: Vector3, scale: number, seed: number)
	local trunkHeight = 14 * scale
	local trunkRadius = 1.4 * scale
	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size = Vector3.new(trunkHeight, trunkRadius * 2, trunkRadius * 2)
	trunk.CFrame = CFrame.new(position + Vector3.new(0, trunkHeight / 2, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	trunk.Material = Enum.Material.Wood
	trunk.Color = PlotConfig.FOREST_TRUNK_COLOR
	hardenDecor(trunk)
	trunk.Parent = parent

	local foliageCount = if seed % 3 == 0 then 3 else 2
	local baseY = trunkHeight * 0.55
	for i = 1, foliageCount do
		local ball = Instance.new("Part")
		ball.Name = "Foliage"
		ball.Shape = Enum.PartType.Ball
		local size = (10 + i * 3.5) * scale * (0.85 + (seed % 5) * 0.04)
		ball.Size = Vector3.new(size, size * 0.85, size)
		local y = position.Y + baseY + (i - 1) * (4.5 * scale)
		local wobble = ((seed + i * 17) % 7) - 3
		ball.Position = position + Vector3.new(wobble * 0.35, y - position.Y, wobble * -0.25)
		ball.Material = Enum.Material.Grass
		ball.Color = if i % 2 == 0 then PlotConfig.FOREST_FOLIAGE_A else PlotConfig.FOREST_FOLIAGE_B
		hardenDecor(ball)
		ball.Parent = parent
	end
end

--[[
	Builds a dark forest covering the enemy-spawn column (and its Z extent).
	`enemyColumnCenterX` / `startZ` match PlotService lane tiling.
]]
function ForestBuilder.build(enemyColumnCenterX: number, startZ: number): Folder
	local folder = Instance.new("Folder")
	folder.Name = "DarkForest"

	local halfW = PlotConfig.BASE_WIDTH / 2
	local minX = enemyColumnCenterX - halfW + PlotConfig.FOREST_CLEAR_WEST
	local maxX = enemyColumnCenterX + halfW - PlotConfig.FOREST_MARGIN_EAST
	local minZ = startZ - PlotConfig.BASE_DEPTH / 2 + PlotConfig.FOREST_MARGIN_Z
	local maxZ = startZ
		+ (PlotConfig.LANE_ROWS - 1) * PlotConfig.BASE_DEPTH
		+ PlotConfig.BASE_DEPTH / 2
		- PlotConfig.FOREST_MARGIN_Z

	if maxX <= minX or maxZ <= minZ then
		return folder
	end

	-- Dark undergrowth carpet so the empty grass reads as forest floor.
	local ground = Instance.new("Part")
	ground.Name = "ForestFloor"
	ground.Size = Vector3.new(maxX - minX, 0.4, maxZ - minZ)
	ground.Position = Vector3.new((minX + maxX) / 2, 0.15, (minZ + maxZ) / 2)
	ground.Material = Enum.Material.Grass
	ground.Color = PlotConfig.FOREST_GROUND_COLOR
	ground.Transparency = 0.15
	hardenDecor(ground)
	ground.CastShadow = false
	ground.Parent = folder

	local spacing = PlotConfig.FOREST_SPACING
	local jitter = PlotConfig.FOREST_JITTER
	local treeIndex = 0

	for x = minX, maxX, spacing do
		for z = minZ, maxZ, spacing do
			treeIndex += 1
			-- Skip a light checker so the canopy isn't a perfect grid.
			if treeIndex % 7 == 0 then
				continue
			end
			local jx = ((treeIndex * 13) % (jitter * 2 + 1)) - jitter
			local jz = ((treeIndex * 29) % (jitter * 2 + 1)) - jitter
			local px = math.clamp(x + jx, minX, maxX)
			local pz = math.clamp(z + jz, minZ, maxZ)
			local scale = 0.75 + ((treeIndex * 11) % 10) * 0.08
			addTree(folder, Vector3.new(px, 0, pz), scale, treeIndex)
		end
	end

	return folder
end

return ForestBuilder
