--!strict
-- A closed eight-face crystal made of native wedges; no external mesh dependency.
local Shared = script.Parent.Parent
local Config = require(Shared.Config.ShardVisualConfig)
local Appearance = require(script.Parent.ShardAppearance)
local ModelUtil = require(script.Parent.ModelUtil)
local Monsters = require(Shared.Monsters)
local Constants = require(Shared.Constants)
local CollectionService = game:GetService("CollectionService")
local ShardModel = {}

local function triangle(parent: Model, a: Vector3, b: Vector3, c: Vector3, color: Color3)
	-- Use the longest edge as the base so the perpendicular lands inside it.
	local ab, ac, bc = b - a, c - a, c - b
	if ab.Magnitude > ac.Magnitude and ab.Magnitude > bc.Magnitude then
		a, c = c, a
	elseif ac.Magnitude > bc.Magnitude then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local back = bc.Unit
	local up = back:Cross(right).Unit
	local height = math.abs(ab:Dot(up))
	local function wedge(center: Vector3, x: Vector3, z: Vector3, length: number)
		local part = Instance.new("WedgePart")
		part.Name = "CrystalFacet"
		part.Size = Vector3.new(Config.FACE_THICKNESS, height, length)
		part.CFrame = CFrame.fromMatrix(center, x, up, z)
		part.Color, part.Material = color, Enum.Material.SmoothPlastic
		part.Transparency = Config.CRYSTAL_TRANSPARENCY
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
		part.CastShadow = false
		part.Parent = parent
	end
	wedge((a + b) / 2, right, back, math.abs(ab:Dot(back)))
	wedge((a + c) / 2, -right, -back, math.abs(ac:Dot(back)))
end

function ShardModel.create(monsterId: string): Model
	local color = Appearance.color(monsterId)
	local model = Instance.new("Model")
	model.Name = "MonsterShard_" .. monsterId
	model:SetAttribute("MonsterId", monsterId)
	local root = Instance.new("Part")
	root.Name = "PickupRoot"
	root.Size = Vector3.new(Config.WIDTH, Config.HEIGHT, Config.DEPTH)
	root.Transparency = 1
	root.Anchored, root.CanCollide, root.CanTouch, root.CanQuery = true, false, false, false
	root.CastShadow = false
	root.Parent = model
	model.PrimaryPart = root
	local top, bottom = Vector3.new(0, Config.HEIGHT / 2, 0), Vector3.new(0, -Config.HEIGHT / 2, 0)
	local ring = { Vector3.new(-Config.WIDTH / 2, 0, 0), Vector3.new(0, 0, -Config.DEPTH / 2),
		Vector3.new(Config.WIDTH / 2, 0, 0), Vector3.new(0, 0, Config.DEPTH / 2) }
	for index, vertex in ring do
		local nextVertex = ring[index % #ring + 1]
		triangle(model, top, vertex, nextVertex, color:Lerp(Color3.new(1, 1, 1), (index - 1) * 0.12))
		triangle(model, bottom, nextVertex, vertex, color:Lerp(Config.OUTLINE_COLOR, 0.12 + (index - 1) * 0.1))
	end
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness = color, Config.LIGHT_RANGE, Config.LIGHT_BRIGHTNESS
	glow.Shadows = false
	glow.Parent = root
	local outline = Instance.new("Highlight")
	outline.FillTransparency, outline.OutlineTransparency = 1, 0.3
	outline.OutlineColor = color:Lerp(Color3.new(1, 1, 1), 0.5)
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = model
	local definition = Monsters.get(monsterId)
	local template = if definition then ModelUtil.findMonsterTemplate(definition.modelId or monsterId) else nil
	if template then
		local portrait = ModelUtil.cloneTemplate(template, {
			targetHeight = Config.HEIGHT * 0.5, targetFootprint = math.min(Config.WIDTH, Config.DEPTH) * 0.68,
			anchorAllParts = true, skipBodyAlias = true, faceDirection = Vector3.zAxis,
			orientationDegrees = definition.modelOrientationDegrees,
		})
		portrait.Name = "SealedMonster"
		-- This sealed miniature is static art, not a character simulation.
		for _, item in portrait:GetDescendants() do
			if item:IsA("Humanoid") or item:IsA("AnimationController") then item:Destroy() end
		end
		local center = portrait:GetBoundingBox()
		portrait:PivotTo(portrait:GetPivot() - center.Position)
		for _, part in portrait:GetDescendants() do
			if part:IsA("BasePart") then
				part.Transparency = math.max(part.Transparency, Config.INNER_MONSTER_TRANSPARENCY)
				part.CastShadow = false
				part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
			elseif part:IsA("Decal") or part:IsA("Texture") then
				part.Transparency = math.max(part.Transparency, Config.INNER_MONSTER_TRANSPARENCY)
			end
		end
		portrait.Parent = model
	end
	local rarity = Appearance.rarity(monsterId)
	model:SetAttribute("ShardRarity", rarity)
	if rarity > 0 then
		local attachment = Instance.new("Attachment")
		attachment.Name = "ShardAura"
		attachment.Parent = root
		local sparks = Instance.new("ParticleEmitter")
		sparks.Name, sparks.Texture = "ShardSparkles", Config.PARTICLE_TEXTURE
		sparks.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.5))
		sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, if rarity == 2 then 0.28 else 0.18), NumberSequenceKeypoint.new(1, 0) })
		sparks.Lifetime, sparks.Speed = NumberRange.new(0.7, 1.3), NumberRange.new(0.5, 1.5)
		sparks.SpreadAngle, sparks.LightEmission = Vector2.new(180, 180), 1
		sparks.Rate = if rarity == 2 then Config.MAJOR_PARTICLE_RATE else Config.BOSS_PARTICLE_RATE
		sparks:SetAttribute("FullRate", sparks.Rate)
		sparks.Parent = attachment
		if rarity == 2 then
			local halo = Instance.new("Folder")
			halo.Name, halo.Parent = "MajorHalo", model
			for index = 1, 12 do
				local angle = index * math.pi / 6
				local rune = Instance.new("Part")
				rune.Name, rune.Material, rune.Color = "HaloRune", Enum.Material.Neon, Config.MAJOR_COLOR
				rune.Size = Vector3.new(0.07, 0.07, 0.26)
				rune.CFrame = CFrame.new(math.cos(angle) * 1.15, -1.3, math.sin(angle) * 1.15) * CFrame.Angles(0, -angle, 0)
				rune.Anchored, rune.CanCollide, rune.CanTouch, rune.CanQuery = true, false, false, false
				rune.CastShadow, rune.Parent = false, halo
			end
		end
	end
	CollectionService:AddTag(model, Constants.TAGS.MonsterShard)
	return model
end

return ShardModel
