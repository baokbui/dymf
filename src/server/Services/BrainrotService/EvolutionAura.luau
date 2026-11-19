--!strict
-- Classic rising flame columns with a brighter core and saturated outer flames. No per-unit tweens, lights or animation loops.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.EvolutionVfxConfig)
local Evolution = require(Shared.Config.EvolutionConfig)
local Bounds = require(script.Parent.AuraBounds)
local Aura = {}

local function fade(): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.32),
		NumberSequenceKeypoint.new(0.65, 0.5), NumberSequenceKeypoint.new(1, 1) })
end

function Aura.create(model: Model, body: BasePart, color: Color3, scale: number, rainbow: boolean?, rarity: string?)
	local size, center = Bounds.measure(model)
	local tier = Config.TIERS[rarity or "Epic"] or Config.TIERS.Epic
	local height = math.clamp(size.Y, 3, 12)
	local disc = Instance.new("Part")
	disc.Name, disc.Size = "AuraVfx", Vector3.new(math.max(size.X * Config.FOOTPRINT_RATIO, Config.MIN_WIDTH), math.max(size.Y, 0.1), math.max(size.Z * Config.FOOTPRINT_RATIO, Config.MIN_WIDTH))
	disc.CFrame = CFrame.new(center.X, center.Y, center.Z)
	disc.Transparency, disc.Massless, disc.CastShadow = 1, true, false
	disc.CanCollide, disc.CanQuery, disc.CanTouch = false, false, false
	disc:SetAttribute("AuraRarity", rarity or "Epic")
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1, weld.Parent = body, disc, disc
	-- Keep large flame sprites, but lower their spawn ceiling by their visual
	-- radius and maximum travel. The source still begins at the model's feet.
	local travel = height * Config.FLAME_RISE_MAX * Config.FLAME_LIFETIME_MAX
		+ 0.5 * height * Config.FLAME_ACCELERATION * Config.FLAME_LIFETIME_MAX ^ 2
	local spriteRadius = Config.FLAME_SIZE * scale * 1.3 * math.exp(-Config.FLAME_SQUASH) / 2
	local headroom = math.max(Config.FLAME_MIN_HEADROOM, size.Y * Config.FLAME_HEADROOM_RATIO)
	local inset = math.clamp(spriteRadius + travel - headroom, 0, size.Y * (1 - Config.FLAME_MIN_SOURCE_HEIGHT_RATIO))
	local flameVolume = disc:Clone()
	flameVolume:ClearAllChildren()
	flameVolume.Name = "FlameVolume"
	flameVolume.Size = Vector3.new(disc.Size.X, disc.Size.Y - inset, disc.Size.Z)
	flameVolume.CFrame = disc.CFrame * CFrame.new(0, -inset / 2, 0)
	local flameWeld = Instance.new("WeldConstraint")
	flameWeld.Part0, flameWeld.Part1, flameWeld.Parent = body, flameVolume, flameVolume
	flameVolume.Parent = disc
	local hot = color:Lerp(Color3.new(1, 1, 1), 0.25)
	local palette = if rainbow then Evolution.rainbowSequence() else ColorSequence.new(color, hot)
	local function emitter(name: string, texture: string): ParticleEmitter
		local p = Instance.new("ParticleEmitter")
		p.Name, p.Texture, p.Color = name, texture, palette
		p.LightEmission, p.LightInfluence, p.Brightness = Config.LIGHT_EMISSION, 0, Config.BRIGHTNESS
		p.EmissionDirection, p.Shape, p.ShapeStyle = Enum.NormalId.Top, Enum.ParticleEmitterShape.Box, Enum.ParticleEmitterShapeStyle.Volume
		p.Transparency, p.LockedToPart, p.ZOffset = fade(), true, 0
		local multiplier = if name == "Glints" then tier.glint else tier.density
		for band, rate in Config.RATES[name] do p:SetAttribute("Aura" .. band .. "Rate", rate * multiplier) end
		p:SetAttribute("AuraFullRate", Config.RATES[name].High * multiplier)
		p.Rate = Config.RATES[name].High * multiplier
		return p
	end
	local function flame(name: string, outer: boolean): ParticleEmitter
		local p = emitter(name, Config.FLAME_TEXTURE)
		p.Orientation, p.LockedToPart = Enum.ParticleOrientation.VelocityParallel, false
		-- Full-volume emission keeps the feet, legs and torso active as well as the head.
		p.Shape, p.ShapeStyle = Enum.ParticleEmitterShape.Box, Enum.ParticleEmitterShapeStyle.Volume
		p.Color = if rainbow then Evolution.rainbowSequence() else ColorSequence.new({
			ColorSequenceKeypoint.new(0, if outer then color else color:Lerp(Color3.new(1, 1, 1), 0.5)),
			ColorSequenceKeypoint.new(0.4, color),
			ColorSequenceKeypoint.new(1, color:Lerp(Color3.new(0, 0, 0), 0.25)),
		})
		p.Lifetime = NumberRange.new(Config.FLAME_LIFETIME_MIN, Config.FLAME_LIFETIME_MAX)
		p.Speed = NumberRange.new(height * Config.FLAME_RISE_MIN, height * Config.FLAME_RISE_MAX)
		p.Acceleration, p.SpreadAngle = Vector3.new(0, height * Config.FLAME_ACCELERATION, 0), Vector2.new(18, 22)
		p.Drag, p.Squash = 0.4, NumberSequence.new(Config.FLAME_SQUASH)
		local thickness = if outer then 1.3 else 1
		p.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.85 * scale * thickness),NumberSequenceKeypoint.new(0.4, Config.FLAME_SIZE * scale * thickness),NumberSequenceKeypoint.new(1, 0.25 * scale)})
		p.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, if outer then 0.12 else 0.04),NumberSequenceKeypoint.new(0.55, if outer then 0.35 else 0.15),NumberSequenceKeypoint.new(1, 1)})
		if outer then p.Brightness, p.LightEmission = Config.OUTER_BRIGHTNESS, Config.OUTER_LIGHT_EMISSION end
		p.Parent = flameVolume
		return p
	end
	flame("CoreFlames", false)
	flame("OuterFlames", true)
	local burst = flame("BurstFlames", false)
	burst.Lifetime, burst.Speed = NumberRange.new(0.3), NumberRange.new(height * Config.FLAME_RISE_MAX)
	burst.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.2 * scale),NumberSequenceKeypoint.new(0.4, 2.5 * scale),NumberSequenceKeypoint.new(1, 0)})
	local function brightenSparks(p: ParticleEmitter)
		p.Color = if rainbow then Evolution.rainbowSequence() else ColorSequence.new(color)
		p.Brightness, p.LightEmission = Config.SPARK_BRIGHTNESS, Config.SPARK_LIGHT_EMISSION
		p.ZOffset = Config.SPARK_Z_OFFSET
		p.LockedToPart = false
		-- Share the flames' Box/Volume: no concentrated leg or torso point sources.
		p.Shape, p.ShapeStyle = Enum.ParticleEmitterShape.Box, Enum.ParticleEmitterShapeStyle.Volume
		p.Speed, p.Drag = NumberRange.new(height * Config.SPARK_DRIFT_MIN, height * Config.SPARK_DRIFT_MAX), Config.SPARK_DRAG
		p.SpreadAngle, p.Acceleration = Vector2.new(Config.SPARK_SPREAD, Config.SPARK_SPREAD), Vector3.new(0, height * Config.SPARK_ACCELERATION, 0)
		p.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1),NumberSequenceKeypoint.new(0.12, 0.08),NumberSequenceKeypoint.new(0.55, 0.15),NumberSequenceKeypoint.new(1, 1)})
	end
	local motes = emitter("Motes", Config.GLINT_TEXTURE)
	brightenSparks(motes)
	motes.Lifetime = NumberRange.new(Config.MOTE_LIFETIME_MIN, Config.MOTE_LIFETIME_MAX)
	motes.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0),NumberSequenceKeypoint.new(0.2, Config.MOTE_SIZE * scale),NumberSequenceKeypoint.new(1, 0)})
	motes.RotSpeed, motes.Parent = NumberRange.new(-45, 45), flameVolume
	local glints = emitter("Glints", Config.GLINT_TEXTURE)
	brightenSparks(glints)
	glints.Lifetime = NumberRange.new(Config.GLINT_LIFETIME_MIN, Config.GLINT_LIFETIME_MAX)
	glints.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0),NumberSequenceKeypoint.new(0.25, Config.GLINT_SIZE * scale),NumberSequenceKeypoint.new(1, 0)})
	glints.Rotation, glints.RotSpeed, glints.Parent = NumberRange.new(-30, 30), NumberRange.new(-30, 30), flameVolume
	local outline = Instance.new("Highlight")
	outline.Name, outline.Adornee = "AuraHighlight", model
	outline.FillColor = color
	outline.FillTransparency, outline.OutlineTransparency = Config.FILL_TRANSPARENCY, Config.OUTLINE_TRANSPARENCY
	outline.OutlineColor, outline.DepthMode = hot, Enum.HighlightDepthMode.Occluded
	outline.Parent, disc.Parent = model, model
end

return Aura
