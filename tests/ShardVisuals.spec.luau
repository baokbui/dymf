--!strict
-- Actual geometry/UI and falling-pickup lifecycle; no live players or saves.
return function(Model: any, Icon: any, SkyShard: any): string
	local Shared = game.ReplicatedStorage.Shared
	local Config = require(Shared.Config.ShardVisualConfig)
	local holder = Instance.new("Folder")
	holder.Name, holder.Parent = "ShardVisualFixture", workspace
	local gui = Instance.new("ScreenGui")
	local colors = {}
	for _, id in { "Zombie", "GoblinElite", "PharaohMummy" } do
		local model = Model.create(id)
		model.Parent = holder
		local root = model.PrimaryPart
		assert(root and root.Transparency == 1 and model:GetAttribute("MonsterId") == id)
		local facets = 0
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				assert(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery)
				if part:IsA("WedgePart") then facets += 1 end
			end
		end
		assert(facets == 16, "Crystal must have eight complete faces")
		local _, bounds = model:GetBoundingBox()
		assert(math.abs(bounds.Y - Config.HEIGHT) < 0.1, "Shard height disagrees with visual config")
		local origin = model:GetPivot()
		local facet = model:FindFirstChild("CrystalFacet") :: WedgePart
		local relative = origin:ToObjectSpace(facet.CFrame)
		model:PivotTo(CFrame.new(17, 33, 9))
		assert(model:GetPivot():ToObjectSpace(facet.CFrame):FuzzyEq(relative), "Facets did not move with pickup")
		local icon = Icon.new(gui, id)
		Icon.mountPortrait(icon)
		assert(icon:FindFirstChild("MonsterPortrait"), "Missing embedded portrait")
		if model:FindFirstChild("SealedMonster") then
			local _, portraitSize = model.SealedMonster:GetBoundingBox()
			assert(portraitSize.Y < Config.HEIGHT, "Portrait exceeds crystal height")
		end
		local rarity = require(Shared.Utilities.ShardAppearance).rarity(id)
		assert((model:FindFirstChild("ShardSparkles", true) ~= nil) == (rarity > 0))
		assert((icon:FindFirstChild("ShardSparkle") ~= nil) == (rarity > 0))
		assert((model:FindFirstChild("MajorHalo") ~= nil) == (rarity == 2))
		assert(icon:GetAttribute("MonsterId") == id and icon:FindFirstChildWhichIsA("UIAspectRatioConstraint"))
		local face = icon.CrystalOutline.Crystal
		assert(root.PointLight.Color == face.BackgroundColor3, "World and inventory palettes differ")
		colors[id] = face.BackgroundColor3
	end
	assert(colors.GoblinElite ~= colors.PharaohMummy and colors.Zombie ~= colors.GoblinElite)
	local plot = Instance.new("Model")
	plot.Parent = holder
	local grid = Instance.new("Folder")
	grid.Name, grid.Parent = "Grid", plot
	local tile = Instance.new("Part")
	tile.Anchored, tile.Size, tile.Position, tile.Parent = true, Vector3.new(8, 1, 8), Vector3.new(0, 140, 0), grid
	local cleanup = SkyShard.spawn({} :: any, plot, "GoblinElite", function() error("Preview must never award currency") end)
	local pickup = plot:FindFirstChild("MonsterShard_GoblinElite") :: Model
	assert(pickup and pickup:IsA("Model"))
	local prompt = pickup:FindFirstChildWhichIsA("ProximityPrompt", true)
	assert(prompt and not prompt.Enabled, "Pickup was collectible before landing")
	local initialY = pickup:GetPivot().Position.Y
	task.wait(1.8)
	assert(prompt.Enabled and pickup:GetPivot().Position.Y < initialY - 39, "Crystal did not land with its prompt")
	assert(math.abs(pickup:GetPivot().Position.Y - (tile.Position.Y + 0.5 + Config.HEIGHT / 2 + Config.GROUND_CLEARANCE)) < 0.01)
	cleanup(); cleanup()
	assert(pickup.Parent == nil, "Pickup cleanup leaked model")
	holder:Destroy(); gui:Destroy()
	return "Faceted geometry, matching flat palettes, model motion, landing gate and idempotent cleanup passed"
end
