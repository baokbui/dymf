--!strict
--[[
	VfxUtil
	Ephemeral client-only particle and tween effects. No gameplay authority.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxConfig = require(ReplicatedStorage.Shared.Config.VfxConfig)

local VfxUtil = {}

local function effectsFolder(): Folder
	local folder = workspace:FindFirstChild("ClientVfx")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ClientVfx"
		folder.Parent = workspace
	end
	return folder :: Folder
end

local function emitBurst(
	position: Vector3,
	color: Color3,
	count: number,
	speed: number,
	size: number,
	lifetime: number
)
	local anchor = Instance.new("Part")
	anchor.Name = "Burst"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position = position
	anchor.Parent = effectsFolder()

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new(size)
	emitter.Speed = NumberRange.new(speed * 0.6, speed)
	emitter.Lifetime = NumberRange.new(lifetime * 0.5, lifetime)
	emitter.Rate = 0
	emitter.LightEmission = 1
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = anchor

	emitter:Emit(count)

	task.delay(lifetime + 0.6, function()
		anchor:Destroy()
	end)
end

function VfxUtil.playHitBurst(position: Vector3)
	emitBurst(
		position,
		VfxConfig.HIT_COLOR,
		VfxConfig.HIT_BURST_COUNT,
		VfxConfig.HIT_BURST_SPEED,
		VfxConfig.HIT_BURST_SIZE,
		VfxConfig.HIT_BURST_LIFETIME
	)
end

function VfxUtil.playDeathBurst(position: Vector3)
	emitBurst(
		position,
		VfxConfig.DEATH_COLOR,
		VfxConfig.DEATH_BURST_COUNT,
		VfxConfig.DEATH_BURST_SPEED,
		VfxConfig.DEATH_BURST_SIZE,
		VfxConfig.DEATH_BURST_LIFETIME
	)
end

--[[
	Thanos-snap ash: particles peel off the corpse and drift upward as it fades.
	Uses world anchors so the cloud outlives the server destroying the model.
]]
function VfxUtil.playDeathDisintegrate(model: Model)
	local emitDuration = VfxConfig.DISINTEGRATE_EMIT_DURATION
	local particleLife = VfxConfig.DISINTEGRATE_PARTICLE_LIFETIME
	local color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, VfxConfig.DISINTEGRATE_COLOR_C),
		ColorSequenceKeypoint.new(0.45, VfxConfig.DISINTEGRATE_COLOR_B),
		ColorSequenceKeypoint.new(1, VfxConfig.DISINTEGRATE_COLOR_A),
	})
	local sizeSeq = NumberSequence.new({
		NumberSequenceKeypoint.new(0, VfxConfig.DISINTEGRATE_SIZE),
		NumberSequenceKeypoint.new(0.55, VfxConfig.DISINTEGRATE_SIZE * 0.65),
		NumberSequenceKeypoint.new(1, 0.02),
	})
	local transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.35, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})

	local anchors: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if not descendant:IsA("BasePart") then
			continue
		end
		if descendant.Transparency >= 0.95 or descendant.Name == "BubbleShell" then
			continue
		end

		local anchor = Instance.new("Part")
		anchor.Name = "DisintegrateAsh"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = descendant.Size
		anchor.CFrame = descendant.CFrame
		anchor.Parent = effectsFolder()
		table.insert(anchors, anchor)

		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Color = color
		emitter.Size = sizeSeq
		emitter.Transparency = transparency
		emitter.Lifetime = NumberRange.new(particleLife * 0.55, particleLife)
		emitter.Speed = NumberRange.new(VfxConfig.DISINTEGRATE_SPEED * 0.35, VfxConfig.DISINTEGRATE_SPEED)
		emitter.SpreadAngle = Vector2.new(70, 70)
		emitter.Acceleration = VfxConfig.DISINTEGRATE_ACCELERATION
		emitter.Drag = 3.5
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-60, 60)
		emitter.LightEmission = 0.15
		emitter.LightInfluence = 0.35
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Rate = VfxConfig.DISINTEGRATE_RATE
		emitter.Parent = anchor

		emitter:Emit(VfxConfig.DISINTEGRATE_BURST_PER_PART)
	end

	if #anchors == 0 then
		return
	end

	task.delay(emitDuration, function()
		for _, anchor in anchors do
			local emitter = anchor:FindFirstChildOfClass("ParticleEmitter")
			if emitter then
				emitter.Rate = 0
			end
		end
	end)

	task.delay(emitDuration + particleLife + 0.3, function()
		for _, anchor in anchors do
			anchor:Destroy()
		end
	end)
end

function VfxUtil.playCoinPickup(position: Vector3)
	emitBurst(
		position,
		VfxConfig.COIN_COLOR,
		VfxConfig.COIN_PICKUP_COUNT,
		VfxConfig.COIN_PICKUP_SPEED,
		VfxConfig.COIN_PICKUP_SIZE,
		VfxConfig.COIN_PICKUP_LIFETIME
	)
end

function VfxUtil.playExplosion(position: Vector3)
	emitBurst(
		position,
		VfxConfig.EXPLOSION_COLOR,
		VfxConfig.EXPLOSION_BURST_COUNT,
		VfxConfig.EXPLOSION_BURST_SPEED,
		VfxConfig.EXPLOSION_BURST_SIZE,
		VfxConfig.EXPLOSION_BURST_LIFETIME
	)

	local ring = Instance.new("Part")
	ring.Name = "ExplosionRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = VfxConfig.EXPLOSION_COLOR
	ring.Transparency = 0.35
	ring.Size = VfxConfig.EXPLOSION_RING_SIZE * 0.35
	ring.CFrame = CFrame.new(position)
	ring.Parent = effectsFolder()

	TweenService:Create(
		ring,
		TweenInfo.new(VfxConfig.EXPLOSION_RING_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = VfxConfig.EXPLOSION_RING_SIZE,
			Transparency = 1,
		}
	):Play()

	task.delay(VfxConfig.EXPLOSION_RING_DURATION + 0.1, function()
		ring:Destroy()
	end)
end

-- Big, exaggerated blast for each tile along a Bombardino line-bomb row:
-- a bright flash pop, a heavy expanding ring, a second slower shockwave
-- ring, and a large spark burst.
function VfxUtil.playTileExplosion(position: Vector3)
	emitBurst(
		position,
		VfxConfig.EXPLOSION_COLOR,
		VfxConfig.TILE_EXPLOSION_BURST_COUNT,
		VfxConfig.TILE_EXPLOSION_BURST_SPEED,
		VfxConfig.TILE_EXPLOSION_BURST_SIZE,
		VfxConfig.TILE_EXPLOSION_BURST_LIFETIME
	)

	-- Instant bright flash at the core for a punchier first frame.
	local flash = Instance.new("Part")
	flash.Name = "TileExplosionFlash"
	flash.Shape = Enum.PartType.Ball
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 240, 200)
	flash.Transparency = 0.05
	flash.Size = VfxConfig.TILE_EXPLOSION_FLASH_SIZE * 0.3
	flash.CFrame = CFrame.new(position)
	flash.Parent = effectsFolder()

	TweenService:Create(
		flash,
		TweenInfo.new(VfxConfig.TILE_EXPLOSION_FLASH_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = VfxConfig.TILE_EXPLOSION_FLASH_SIZE, Transparency = 1 }
	):Play()
	task.delay(VfxConfig.TILE_EXPLOSION_FLASH_DURATION + 0.1, function()
		flash:Destroy()
	end)

	local ring = Instance.new("Part")
	ring.Name = "TileExplosionRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = VfxConfig.EXPLOSION_COLOR
	ring.Transparency = 0.25
	ring.Size = VfxConfig.TILE_EXPLOSION_RING_SIZE * 0.3
	ring.CFrame = CFrame.new(position)
	ring.Parent = effectsFolder()

	TweenService:Create(
		ring,
		TweenInfo.new(VfxConfig.TILE_EXPLOSION_RING_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = VfxConfig.TILE_EXPLOSION_RING_SIZE,
			Transparency = 1,
		}
	):Play()

	task.delay(VfxConfig.TILE_EXPLOSION_RING_DURATION + 0.1, function()
		ring:Destroy()
	end)

	-- Secondary shockwave ring: starts where the main ring started, expands
	-- further and lingers a touch longer for a two-layer "boom" read.
	local shockwave = Instance.new("Part")
	shockwave.Name = "TileExplosionShockwave"
	shockwave.Anchored = true
	shockwave.CanCollide = false
	shockwave.CanQuery = false
	shockwave.CanTouch = false
	shockwave.Material = Enum.Material.Neon
	shockwave.Color = Color3.fromRGB(255, 210, 120)
	shockwave.Transparency = 0.45
	shockwave.Size = VfxConfig.TILE_EXPLOSION_RING_SIZE * 0.3
	shockwave.CFrame = CFrame.new(position)
	shockwave.Parent = effectsFolder()

	TweenService:Create(
		shockwave,
		TweenInfo.new(VfxConfig.TILE_EXPLOSION_SHOCKWAVE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = VfxConfig.TILE_EXPLOSION_SHOCKWAVE_SIZE,
			Transparency = 1,
		}
	):Play()

	task.delay(VfxConfig.TILE_EXPLOSION_SHOCKWAVE_DURATION + 0.1, function()
		shockwave:Destroy()
	end)
end

-- Thin neon segment between two world points (used to build curved soundwaves).
local function createWaveSegment(a: Vector3, b: Vector3, color: Color3, thickness: number): BasePart
	local mid = (a + b) * 0.5
	local delta = b - a
	local length = math.max(delta.Magnitude, 0.05)
	local part = Instance.new("Part")
	part.Name = "TerrifyWaveSeg"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.05
	part.Size = Vector3.new(thickness, thickness, length)
	part.CFrame = CFrame.lookAt(mid, b)
	part.Parent = effectsFolder()
	return part
end

--[[
	One comic-book ")" soundwave arc: a vertical crescent spanning `height`
	studs across the lawn rows, bowed `bow` studs outward along `dir`. Built
	from thin neon segments so it reads as a red curved line like the sketch.
]]
local function emitTerrifyArc(
	origin: Vector3,
	dir: Vector3,
	right: Vector3,
	distance: number,
	delaySec: number
)
	local function spawn()
		local height = VfxConfig.TERRIFY_WAVE_HEIGHT
		local bow = VfxConfig.TERRIFY_WAVE_BOW
		local segments = VfxConfig.TERRIFY_WAVE_SEGMENTS
		local thickness = VfxConfig.TERRIFY_WAVE_THICKNESS
		local color = VfxConfig.TERRIFY_WAVE_COLOR
		local lifetime = VfxConfig.TERRIFY_WAVE_LIFETIME
		local lift = Vector3.new(0, 4, 0)

		local function pointAt(t: number): Vector3
			-- Parabola: max bow at the center (t = 0), flat at the tips (±1).
			local bowOffset = bow * (1 - t * t)
			return origin + lift + dir * (distance + bowOffset) + right * (t * height * 0.5)
		end

		local parts: { BasePart } = {}
		for s = 0, segments - 1 do
			local t0 = -1 + (2 * s) / segments
			local t1 = -1 + (2 * (s + 1)) / segments
			table.insert(parts, createWaveSegment(pointAt(t0), pointAt(t1), color, thickness))
		end

		-- Drift farther along the scream and fade out.
		local drift = dir * (VfxConfig.TERRIFY_WAVE_SPACING * 0.55)
		for _, part in parts do
			TweenService:Create(
				part,
				TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					CFrame = part.CFrame + drift,
					Transparency = 1,
					Size = part.Size + Vector3.new(0.15, 0.15, 0),
				}
			):Play()
		end

		task.delay(lifetime + 0.1, function()
			for _, part in parts do
				part:Destroy()
			end
		end)
	end

	if delaySec <= 0 then
		spawn()
	else
		task.delay(delaySec, spawn)
	end
end

--[[
	Duke Vampire's Terrify scream: a row of red curved soundwave lines
	(comic-book "))) ") fanning out from him along `direction` (defaults to
	world −X / toward the house — matching the terrify forward AoE cone).
]]
function VfxUtil.playTerrifySoundwave(origin: Vector3, direction: Vector3?)
	local flat = if direction then Vector3.new(direction.X, 0, direction.Z) else Vector3.new(-1, 0, 0)
	local dir = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(1, 0, 0)
	-- Perpendicular across the lawn rows (Z when traveling along ±X).
	local right = Vector3.new(-dir.Z, 0, dir.X)
	if right.Magnitude < 1e-3 then
		right = Vector3.zAxis
	else
		right = right.Unit
	end

	for i = 0, VfxConfig.TERRIFY_WAVE_COUNT - 1 do
		local distance = VfxConfig.TERRIFY_WAVE_START_DISTANCE + i * VfxConfig.TERRIFY_WAVE_SPACING
		emitTerrifyArc(origin, dir, right, distance, i * VfxConfig.TERRIFY_WAVE_STAGGER)
	end
end

--[[
	Cartoon dizzy: several ★ stars orbiting in a flat halo above the Brainrot.
	Replaces any prior DizzyVfx on the same model so refreshes don't stack.
]]
function VfxUtil.playDizzy(model: Model, duration: number)
	local anchor = model.PrimaryPart
		or model:FindFirstChild("Body", true)
		or model:FindFirstChild("HumanoidRootPart", true)
		or model:FindFirstChildWhichIsA("BasePart", true)
	if not (anchor and anchor:IsA("BasePart")) then
		return
	end

	local existing = anchor:FindFirstChild("DizzyVfx")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "DizzyVfx"
	gui.Adornee = anchor
	gui.Size = VfxConfig.DIZZY_SIZE
	gui.StudsOffset = VfxConfig.DIZZY_OFFSET
	gui.AlwaysOnTop = true
	gui.Parent = anchor

	local stars: { TextLabel } = {}
	local starCount = VfxConfig.DIZZY_STAR_COUNT
	for i = 1, starCount do
		local star = Instance.new("TextLabel")
		star.Name = "Star" .. i
		star.BackgroundTransparency = 1
		star.Size = VfxConfig.DIZZY_STAR_SIZE
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Font = Enum.Font.FredokaOne
		star.Text = "★"
		star.TextScaled = true
		star.TextColor3 = VfxConfig.DIZZY_COLOR
		star.TextStrokeColor3 = Color3.fromRGB(80, 40, 0)
		star.TextStrokeTransparency = 0.25
		star.Parent = gui
		table.insert(stars, star)
	end

	local RunService = game:GetService("RunService")
	local angle = 0
	local spinConnection = RunService.Heartbeat:Connect(function(dt)
		angle += dt * (math.pi * 2 / VfxConfig.DIZZY_SPIN_SECONDS)
		local radius = VfxConfig.DIZZY_ORBIT_RADIUS
		local flatten = VfxConfig.DIZZY_ORBIT_FLATTEN
		for i, star in stars do
			local a = angle + (i - 1) * (math.pi * 2 / starCount)
			local x = math.cos(a) * radius
			local y = math.sin(a) * radius * flatten
			star.Position = UDim2.new(0.5, x, 0.5, y)
			-- Tip each star as it orbits so they feel like spinning, not sliding.
			star.Rotation = math.deg(a)
		end
	end)

	task.delay(duration, function()
		spinConnection:Disconnect()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

--[[
	Cartoon status word that pops above a Brainrot, rises, and fades out
	(e.g. purple "Poisoned", yellow "Stunned").
]]
function VfxUtil.playStatusFloater(model: Model, text: string, color: Color3)
	local anchor = model.PrimaryPart
		or model:FindFirstChild("Body", true)
		or model:FindFirstChild("HumanoidRootPart", true)
		or model:FindFirstChildWhichIsA("BasePart", true)
	if not (anchor and anchor:IsA("BasePart")) then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "StatusFloater"
	gui.Adornee = anchor
	gui.Size = VfxConfig.STATUS_FLOAT_SIZE
	gui.StudsOffset = VfxConfig.STATUS_FLOAT_START_OFFSET
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	gui.Parent = effectsFolder()

	local label = Instance.new("TextLabel")
	label.Name = "Word"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(20, 15, 30)
	label.TextStrokeTransparency = 0
	label.Parent = gui

	local duration = VfxConfig.STATUS_FLOAT_DURATION
	local rise = VfxConfig.STATUS_FLOAT_RISE_STUDS
	local startOffset = VfxConfig.STATUS_FLOAT_START_OFFSET
	local goalOffset = startOffset + Vector3.new(0, rise, 0)

	local offsetValue = Instance.new("Vector3Value")
	offsetValue.Value = startOffset
	offsetValue.Parent = gui
	offsetValue.Changed:Connect(function(value)
		if gui.Parent then
			gui.StudsOffset = value
		end
	end)

	TweenService:Create(
		offsetValue,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = goalOffset }
	):Play()
	TweenService:Create(
		label,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	):Play()

	task.delay(duration, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

--[[
	Purple poison aura clinging to a Brainrot for `duration` seconds. Replaces
	any prior PoisonVfx so refreshes don't stack emitters. Uses a Highlight +
	dense mist so it reads clearly even on busy NightFog lawns.
]]
function VfxUtil.playPoisonAura(model: Model, duration: number)
	local existing = model:FindFirstChild("PoisonVfx")
	if existing then
		existing:Destroy()
	end

	local anchor = model.PrimaryPart
		or model:FindFirstChild("Body", true)
		or model:FindFirstChild("HumanoidRootPart", true)
		or model:FindFirstChildWhichIsA("BasePart", true)
	if not (anchor and anchor:IsA("BasePart")) then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "PoisonVfx"
	folder.Parent = model

	-- Strong silhouette read — particles alone are easy to miss in fog.
	local highlight = Instance.new("Highlight")
	highlight.Name = "PoisonHighlight"
	highlight.FillColor = VfxConfig.POISON_AURA_COLOR
	highlight.FillTransparency = 0.55
	highlight.OutlineColor = Color3.fromRGB(220, 140, 255)
	highlight.OutlineTransparency = 0.15
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = folder

	local attachment = Instance.new("Attachment")
	attachment.Name = "PoisonEmit"
	-- Lift off the root so mist wraps the body, not the feet / HRP.
	attachment.Position = Vector3.new(0, 1.6, 0)
	attachment.Parent = anchor

	local mist = Instance.new("ParticleEmitter")
	mist.Name = "PoisonMist"
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(210, 120, 255)),
		ColorSequenceKeypoint.new(1, VfxConfig.POISON_AURA_COLOR),
	})
	mist.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(0.45, 2.8),
		NumberSequenceKeypoint.new(1, 0.4),
	})
	mist.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.55, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	mist.Lifetime = NumberRange.new(0.9, 1.5)
	mist.Speed = NumberRange.new(0.8, 2.2)
	mist.SpreadAngle = Vector2.new(180, 180)
	mist.Rate = VfxConfig.POISON_AURA_RATE
	mist.LightEmission = 0.7
	mist.LightInfluence = 0
	mist.LockedToPart = false
	mist.Enabled = true
	mist.Parent = attachment

	local wisps = Instance.new("ParticleEmitter")
	wisps.Name = "PoisonWisps"
	wisps.Texture = "rbxasset://textures/particles/smoke_main.dds"
	wisps.Color = ColorSequence.new(Color3.fromRGB(180, 80, 255))
	wisps.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.5, 0.9),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	wisps.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.7, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	wisps.Lifetime = NumberRange.new(0.5, 0.9)
	wisps.Speed = NumberRange.new(1.5, 3.5)
	wisps.Acceleration = Vector3.new(0, 2.5, 0)
	wisps.SpreadAngle = Vector2.new(60, 60)
	wisps.Rate = math.max(10, math.floor(VfxConfig.POISON_AURA_RATE * 0.75))
	wisps.LightEmission = 0.85
	wisps.LightInfluence = 0
	wisps.LockedToPart = false
	wisps.Parent = attachment

	local glow = Instance.new("PointLight")
	glow.Name = "PoisonGlow"
	glow.Color = VfxConfig.POISON_AURA_COLOR
	glow.Brightness = VfxConfig.POISON_AURA_LIGHT_BRIGHTNESS
	glow.Range = VfxConfig.POISON_AURA_LIGHT_RANGE
	glow.Shadows = false
	glow.Parent = attachment

	-- Immediate pop so the aura is obvious on the first frame (Rate alone
	-- takes a beat to fill the volume).
	mist:Emit(18)
	wisps:Emit(12)

	task.delay(duration, function()
		if folder.Parent then
			folder:Destroy()
		end
		if attachment.Parent then
			attachment:Destroy()
		end
	end)
end

function VfxUtil.decorateProjectile(part: BasePart)
	if part:GetAttribute("VfxDecorated") == true then
		return
	end
	part:SetAttribute("VfxDecorated", true)

	local kind = part:GetAttribute("ProjectileKind")
	local isBubble = kind == "Bubble"
	local isShuriken = kind == "Shuriken"
	local trailColor = if isBubble
		then VfxConfig.BUBBLE_PROJECTILE_TRAIL_COLOR
		elseif isShuriken then VfxConfig.SHURIKEN_PROJECTILE_TRAIL_COLOR
		else VfxConfig.PROJECTILE_TRAIL_COLOR
	local trailOffset = if isBubble
		then Vector3.new(-0.9, 0, 0)
		elseif isShuriken then Vector3.new(-1.1, 0, 0)
		else Vector3.new(-0.6, 0, 0)

	local attachment0 = Instance.new("Attachment")
	attachment0.Name = "TrailStart"
	attachment0.Parent = part

	local attachment1 = Instance.new("Attachment")
	attachment1.Name = "TrailEnd"
	attachment1.Position = trailOffset
	attachment1.Parent = part

	local trail = Instance.new("Trail")
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
	trail.Lifetime = if isShuriken
		then VfxConfig.SHURIKEN_PROJECTILE_TRAIL_LIFETIME
		else VfxConfig.PROJECTILE_TRAIL_LIFETIME
	trail.WidthScale = NumberSequence.new(
		if isBubble
			then 0.55
			elseif isShuriken then VfxConfig.SHURIKEN_PROJECTILE_TRAIL_WIDTH
			else VfxConfig.PROJECTILE_TRAIL_WIDTH
	)
	trail.Color = ColorSequence.new(trailColor)
	trail.LightEmission = 1
	trail.Transparency = if isBubble then NumberSequence.new(0.35, 1) else NumberSequence.new(0, 1)
	trail.Parent = part

	local glow = Instance.new("PointLight")
	glow.Brightness = if isBubble
		then VfxConfig.BUBBLE_PROJECTILE_GLOW_BRIGHTNESS
		elseif isShuriken then VfxConfig.SHURIKEN_PROJECTILE_GLOW_BRIGHTNESS
		else VfxConfig.PROJECTILE_GLOW_BRIGHTNESS
	glow.Range = if isBubble
		then VfxConfig.BUBBLE_PROJECTILE_GLOW_RANGE
		elseif isShuriken then VfxConfig.SHURIKEN_PROJECTILE_GLOW_RANGE
		else VfxConfig.PROJECTILE_GLOW_RANGE
	glow.Color = trailColor
	glow.Parent = part
end

return VfxUtil
