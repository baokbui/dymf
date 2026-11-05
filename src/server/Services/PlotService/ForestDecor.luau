--!strict
-- Static forest primitives shared by trees and the woodland edge.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.PlotConfig)
local ForestDecor = {}

function ForestDecor.part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material
	part.CastShadow = true
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Locked = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function ForestDecor.tree(parent: Instance, position: Vector3, scale: number, rng: Random, depth: number)
	local model = Instance.new("Model")
	local conifer = rng:NextNumber() < Config.FOREST_CONIFER_CHANCE
	model.Name = if conifer then "Cypress" else "Oak"
	local turn = CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local height = (if conifer then 26 else 21) * scale
	local trunk = ForestDecor.part(model, "Trunk", Vector3.new(height, 2.6 * scale, 2.6 * scale),
		turn * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Config.FOREST_TRUNK_COLOR, Enum.Material.Wood)
	trunk.Shape = Enum.PartType.Cylinder
	local tint = Config.FOREST_FOLIAGE_A:Lerp(Config.FOREST_FOLIAGE_B, rng:NextNumber())
		:Lerp(Config.FOREST_DEEP_COLOR, depth * 0.5)
	if conifer then
		-- Narrow, rising crowns contrast with the spreading oak silhouette.
		for tier = 1, 3 do
			local width = (20 - tier * 4) * scale
			local crown = ForestDecor.part(model, "CypressCrown", Vector3.new(width, 17 * scale, width),
				turn * CFrame.new(0, height * 0.4 + tier * 6 * scale, 0),
				tint:Lerp(Config.FOREST_HIGHLIGHT_COLOR, tier * 0.08), Enum.Material.Grass)
			crown.Shape = Enum.PartType.Ball
		end
	else
		for cluster = 1, 4 do
			local angle = cluster * math.pi * 2 / 3
			local offset = if cluster == 4 then Vector3.new(0, height + 5 * scale, 0)
				else Vector3.new(math.cos(angle) * 5 * scale, height, math.sin(angle) * 5 * scale)
			local crown = ForestDecor.part(model, "OakCrown", Vector3.new(17, 12, 16) * scale,
				turn * CFrame.new(offset), tint:Lerp(Config.FOREST_HIGHLIGHT_COLOR, cluster * 0.06), Enum.Material.Grass)
			crown.Shape = Enum.PartType.Ball
		end
	end
	model.Parent = parent
end

function ForestDecor.undergrowth(parent: Instance, position: Vector3, rng: Random)
	local scale = rng:NextNumber(0.7, 1.4)
	local turn = CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local rock = ForestDecor.part(parent, "MossyBoulder", Vector3.new(6, 3.5, 4) * scale,
		turn * CFrame.new(0, 1.2 * scale, 0) * CFrame.Angles(0.15, 0, 0.2),
		Config.FOREST_ROCK_COLOR, Enum.Material.Slate)
	rock.Shape = Enum.PartType.Ball
	for i = 1, 2 do
		local shrub = ForestDecor.part(parent, "FernShrub", Vector3.new(5, 3, 4) * scale,
			turn * CFrame.new(i * 2.5, 1.3 * scale, -2),
			Config.FOREST_FOLIAGE_A:Lerp(Config.FOREST_HIGHLIGHT_COLOR, i * 0.25), Enum.Material.Grass)
		shrub.Shape = Enum.PartType.Ball
	end
end

return ForestDecor
