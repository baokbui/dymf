--!strict
return function(Aura: any, Config: any): string
	for _, rarity in {"Epic", "Legendary", "Mythic", "Immortal", "God"} do
		local model = Instance.new("Model")
		local body = Instance.new("Part"); body.Name, body.Size, body.Anchored, body.Parent = "Body", Vector3.new(4, 6, 4), true, model
		model.PrimaryPart = body
		local joint = Instance.new("Motor6D"); joint.C0 = CFrame.new(0, 1, 0); joint.Parent = body
		local c0 = joint.C0
		Aura.create(model, body, Color3.fromRGB(155, 55, 230), 1.15, rarity == "God", rarity)
		local root = model:FindFirstChild("AuraVfx") :: BasePart
		assert(root and root.Transparency == 1 and not root.CanCollide and not root.CanQuery and root.Massless)
		assert(root.Size.Y >= body.Size.Y and math.abs(root.Position.Y - body.Position.Y) < 0.001, "Aura volume does not span the body")
		for _, flames in {root.FlameVolume.CoreFlames, root.FlameVolume.OuterFlames} do
			assert(flames.Shape == Enum.ParticleEmitterShape.Box and flames.ShapeStyle == Enum.ParticleEmitterShapeStyle.Volume, "Flames omit lower-body volume")
		end
		assert(root.WeldConstraint.Part0 == body and root.WeldConstraint.Part1 == root)
		local emitters, total = 0, 0
		for _, item in root:GetDescendants() do
			if item:IsA("ParticleEmitter") then
				emitters += 1; total += item.Rate
				assert(item:GetAttribute("AuraHighRate") >= item:GetAttribute("AuraMediumRate"))
				assert(item:GetAttribute("AuraMediumRate") >= item:GetAttribute("AuraLowRate"))
				assert(item.LightEmission < 1 and item.Brightness <= math.max(Config.BRIGHTNESS, Config.OUTER_BRIGHTNESS, Config.SPARK_BRIGHTNESS) + 0.0001)
			end
			assert(not item:IsA("Light") and not item:IsA("Beam"), "Aura added expensive continuous lighting/geometry")
		end
		assert(emitters == 5 and total < 290, "Aura particle budget exceeded")
		assert(model.AuraHighlight.FillTransparency >= 0.9 and model.AuraHighlight.FillTransparency < 1 and model.AuraHighlight.OutlineTransparency <= 0.25)
		assert(root.FlameVolume.CoreFlames:GetAttribute("AuraLowRate") >= 14, "Low graphics lost the flame column")
		for _, sparks in {root:FindFirstChild("Motes", true), root:FindFirstChild("Glints", true)} do
			assert(sparks.Parent == root.FlameVolume and sparks.ShapeStyle == Enum.ParticleEmitterShapeStyle.Volume, "Sparkles must share the flame volume")
			assert(sparks.Speed.Min * sparks.Lifetime.Min > body.Size.Y * 0.45, "Sparkles do not rise far enough")
			assert(math.abs(sparks.Brightness - Config.SPARK_BRIGHTNESS) < 0.0001 and math.abs(sparks.LightEmission - Config.SPARK_LIGHT_EMISSION) < 0.0001)
			assert(sparks.SpreadAngle.X > 0 and sparks.SpreadAngle.X < 45 and sparks.SpreadAngle.Y < 45 and sparks.Acceleration.Y > 0 and sparks.EmissionDirection == Enum.NormalId.Top and sparks.Speed.Min > 0 and not sparks.LockedToPart, "Sparkles must rise with gentle sideways scatter")
			if rarity ~= "God" then
				for _, point in sparks.Color.Keypoints do assert(point.Value == Color3.fromRGB(155, 55, 230), "Spark color lost evolution tint") end
			end
		end
		for _, kind in {"Motes", "Glints"} do
			local sum = 0
			for _, p in root:GetDescendants() do if p:IsA("ParticleEmitter") and p.Name == kind then sum += p:GetAttribute("AuraHighRate") end end
			local tier = Config.TIERS[rarity]
			local expected = Config.RATES[kind].High * (if kind == "Glints" then tier.glint else tier.density)
			assert(math.abs(sum - expected) < 0.0001, "Spark emission exceeds configured budget")
		end
		local core = root.FlameVolume.CoreFlames
		local rise = core.Speed.Max * core.Lifetime.Max + 0.5 * core.Acceleration.Y * core.Lifetime.Max ^ 2
		assert(rise < body.Size.Y * Config.FLAME_MAX_TRAVEL_RATIO, "Flame travel escapes the body envelope")
		local volume = root.FlameVolume
		local bottom = volume.Position.Y - volume.Size.Y / 2
		assert(math.abs(bottom - (root.Position.Y - root.Size.Y / 2)) < 0.001, "Flame source no longer reaches the feet")
		local radius = core.Size.Keypoints[2].Value * 1.3 * math.exp(-core.Squash.Keypoints[1].Value) / 2
		local ceiling = volume.Position.Y + volume.Size.Y / 2 + rise + radius
		assert(ceiling <= root.Position.Y + root.Size.Y / 2 + math.max(Config.FLAME_MIN_HEADROOM, root.Size.Y * Config.FLAME_HEADROOM_RATIO) + 0.001, "Flame envelope exceeds headroom")
		assert(body.Size == Vector3.new(4, 6, 4) and joint.C0 == c0)
		model:Destroy()
	end
	assert(Config.band("Full", 10) == "High" and Config.band("Full", 5) == "Medium" and Config.band("Full", 2) == "Low")
	assert(Config.band("Full", 0) == "Medium" and Config.band("Reduced", 10) == "Low" and Config.band("Minimal", 10) == "Off")
	return "Five aura tiers, layer budgets, quality bands, physics/rig and outline preservation passed"
end
