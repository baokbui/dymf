--!strict
-- Regression: mesh boxes above the feet must not leave skinned legs without aura.
return function(Bounds: any, Aura: any): string
	local model = Instance.new("Model")
	local mesh = Instance.new("MeshPart")
	mesh.Size, mesh.CFrame, mesh.Parent = Vector3.new(5, 5, 4), CFrame.new(0, 8, 0), model
	local rig = Instance.new("Part")
	rig.Name, rig.Transparency, rig.CFrame, rig.Parent = "RootPart", 1, CFrame.new(0, 4, 0), model
	model.PrimaryPart = rig
	local foot = Instance.new("Bone"); foot.Name, foot.CFrame, foot.Parent = "Foot", CFrame.new(0, -4, 0), rig
	local left = Instance.new("Bone"); left.Name, left.CFrame, left.Parent = "WideLimb", CFrame.new(-12, 1, 0), rig
	local size, center = Bounds.measure(model)
	assert(center.Y - size.Y / 2 < foot.WorldPosition.Y, "Aura bounds ignored feet below mesh bounds")
	assert(center.X - size.X / 2 < left.WorldPosition.X, "Aura bounds ignored a wide limb")
	Aura.create(model, rig, Color3.fromRGB(155, 55, 230), 1, false, "Epic")
	local source = model.AuraVfx
	assert(source.Position.Y - source.Size.Y / 2 < foot.WorldPosition.Y)
	assert(source.Position.Y + source.Size.Y / 2 >= mesh.Position.Y + mesh.Size.Y / 2)
	assert(source.Position.X - source.Size.X / 2 < left.WorldPosition.X, "Wide model source was artificially clipped")
	local newSize = Bounds.measure(model)
	assert((size - newSize).Magnitude < 0.001, "Aura helper contaminated visual bounds")
	model:Destroy()
	return "Skinned feet, full-height/wide-body emission and helper-exclusion regression passed"
end
