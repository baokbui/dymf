--!strict
-- Material policy and physical/animation/art preservation, with real Instances.
return function(Style: any): string
	local root = Instance.new("Model")
	local function part(class: string?): BasePart
		local p = Instance.new(class or "Part") :: BasePart
		p.Material, p.Color, p.Anchored = Enum.Material.Wood, Color3.fromRGB(93, 150, 71), true
		p.Parent = root
		return p
	end
	local plain = part()
	local old = plain.CurrentPhysicalProperties
	local color, size, anchored = plain.Color, plain.Size, plain.Anchored
	local decal = Instance.new("Decal"); decal.Texture = "rbxassetid://123"; decal.Parent = plain
	assert(Style.applyPart(plain, "Ground"))
	assert(plain.MaterialVariant == "BvmStudsGround" and plain.Material == Enum.Material.Plastic)
	assert(plain.Color == color and plain.Size == size and plain.Anchored == anchored and decal.Parent == plain)
	assert(plain.CurrentPhysicalProperties.Density == old.Density and plain.CurrentPhysicalProperties.Friction == old.Friction,
		"Art style altered physical behavior")
	local count = #root:GetDescendants()
	Style.applyPart(plain, "Ground"); assert(#root:GetDescendants() == count, "Repeated styling created geometry")
	local invisible, neon, textured, pbr = part(), part(), part("MeshPart"), part("MeshPart")
	invisible.Transparency, neon.Material = 1, Enum.Material.Neon
	textured.TextureID = "rbxassetid://123"
	Instance.new("SurfaceAppearance").Parent = pbr
	for _, p in { invisible, neon, textured, pbr } do assert(not Style.applyPart(p, "Unit"), "Authored/effect material replaced") end
	local special = part(); local mesh = Instance.new("SpecialMesh"); mesh.TextureId = "rbxassetid://123"; mesh.Parent = special
	assert(not Style.applyPart(special, "Unit"))
	local optedOut = Instance.new("Model"); optedOut:SetAttribute("KeepAuthoredMaterial", true); optedOut.Parent = root
	local nested = part(); nested.Parent = optedOut
	Style.apply(root, "Scenery"); assert(nested.Material == Enum.Material.Wood, "Nested opt-out lost")
	local broken = part(); broken.MaterialVariant = "MissingStudVariant"
	assert(Style.applyPart(broken, "Unit") and broken.MaterialVariant == "BvmStudsUnits", "Missing variant prevented styling")
	local service = game:GetService("MaterialService")
	local variant = Instance.new("MaterialVariant"); variant.Name = "WorldStyleFixtureAuthored"; variant.BaseMaterial = Enum.Material.Wood; variant.Parent = service
	local authored = part(); authored.MaterialVariant = variant.Name
	assert(not Style.applyPart(authored, "Unit"), "Valid authored variant replaced")
	variant:Destroy(); root:Destroy()
	return "Stud policy, idempotency, physics/art/effect preservation, nested opt-outs and missing-variant fallback passed"
end
