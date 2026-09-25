--!strict
--[[
	VfxUtil
	Ephemeral client-only particle and tween effects. No gameplay authority.
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxConfig = require(ReplicatedStorage.Shared.Config.VfxConfig)
local VfxLoad = require(ReplicatedStorage.Shared.Utilities.VfxLoad)

local VfxUtil = {}

-- nil means Off: skip the burst. Low keeps a thinner spark count.
local function scaledBurstCount(full: number): number?
	local quality = VfxLoad.quality()
	if quality == "Minimal" then
		return nil
	end
	if quality == "Reduced" then
		return math.max(1, math.ceil(full * 0.45))
	end
	return full
end

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
	local count = scaledBurstCount(VfxConfig.HIT_BURST_COUNT)
	if not count then
		return
	end
	emitBurst(
		position,
		VfxConfig.HIT_COLOR,
		count,
		VfxConfig.HIT_BURST_SPEED,
		VfxConfig.HIT_BURST_SIZE,
		VfxConfig.HIT_BURST_LIFETIME
	)
end

function VfxUtil.playJackpotBurst(position: Vector3, quality: string?)
	if quality == "Minimal" then
		return
	end
	local count = VfxConfig.JACKPOT_BURST_COUNT
	if quality == "Reduced" then
		count = math.max(6, math.ceil(count * 0.5))
	end
	emitBurst(
		position,
		VfxConfig.JACKPOT_COLOR,
		count,
		VfxConfig.JACKPOT_BURST_SPEED,
		VfxConfig.JACKPOT_BURST_SIZE,
		VfxConfig.JACKPOT_BURST_LIFETIME
	)
end

function VfxUtil.playDeathBurst(position: Vector3)
	local count = scaledBurstCount(VfxConfig.DEATH_BURST_COUNT)
	if not count then
		return
	end
	emitBurst(
		position,
		VfxConfig.DEATH_COLOR,
		count,
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
	local quality = VfxLoad.quality()
	if quality == "Minimal" then
		return
	end
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

	local candidates: { { part: BasePart, volume: number } } = {}
	for _, descendant in model:GetDescendants() do
		if not descendant:IsA("BasePart") then
			continue
		end
		if descendant.Transparency >= 0.95 or descendant.Name == "BubbleShell" then
			continue
		end
		local size = descendant.Size
		table.insert(candidates, {
			part = descendant,
			volume = size.X * size.Y * size.Z,
		})
	end
	table.sort(candidates, function(a, b)
		return a.volume > b.volume
	end)
	local maxParts = VfxConfig.DISINTEGRATE_MAX_PARTS
	local rate = VfxConfig.DISINTEGRATE_RATE
	local burst = VfxConfig.DISINTEGRATE_BURST_PER_PART
	if quality == "Reduced" then
		maxParts = math.max(2, math.ceil(maxParts * 0.5))
		rate = math.max(2, math.ceil(rate * 0.4))
		burst = math.max(2, math.ceil(burst * 0.4))
	end
	local anchors: { BasePart } = {}
	for index, candidate in candidates do
		if index > maxParts then
			break
		end
		local descendant = candidate.part

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
		emitter.Rate = rate
		emitter.Parent = anchor

		emitter:Emit(burst)
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
	local count = scaledBurstCount(VfxConfig.COIN_PICKUP_COUNT)
	if not count then
		return
	end
	emitBurst(
		position,
		VfxConfig.COIN_COLOR,
		count,
		VfxConfig.COIN_PICKUP_SPEED,
		VfxConfig.COIN_PICKUP_SIZE,
		VfxConfig.COIN_PICKUP_LIFETIME
	)
end

function VfxUtil.playExplosion(position: Vector3)
	if VfxLoad.quality() == "Minimal" then
		return
	end
	local count = scaledBurstCount(VfxConfig.EXPLOSION_BURST_COUNT) or VfxConfig.EXPLOSION_BURST_COUNT
	emitBurst(
		position,
		VfxConfig.EXPLOSION_COLOR,
		count,
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
	local quality = VfxLoad.quality()
	if quality == "Minimal" then
		return
	end
	local count = scaledBurstCount(VfxConfig.TILE_EXPLOSION_BURST_COUNT) or VfxConfig.TILE_EXPLOSION_BURST_COUNT
	emitBurst(
		position,
		VfxConfig.EXPLOSION_COLOR,
		count,
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

	-- Secondary shockwave is the High-only second layer. Low keeps the flash and one ring.
	if quality ~= "Full" then
		return
	end
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

local function spikeLengthScale(index: number, count: number): number
	local t = ((index * 7 + 3) % math.max(count, 1)) / math.max(count, 1)
	return 0.62 + t * 0.7
end

local function spikeCFrame(origin: Vector3, yaw: number, radius: number, length: number, upBias: number): CFrame
	local outward = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
	local tip = outward * (1 - upBias) + Vector3.new(0, upBias, 0)
	if tip.Magnitude < 0.05 then
		tip = Vector3.yAxis
	else
		tip = tip.Unit
	end
	local base = origin + outward * radius
	local mid = base + tip * (length * 0.5)
	return CFrame.lookAt(mid, mid + tip)
end

local function makeSpike(color: Color3, width: number, thickness: number, length: number, transparency: number): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Name = "BatSlamSpike"
	wedge.Anchored = true
	wedge.CanCollide = false
	wedge.CanQuery = false
	wedge.CanTouch = false
	wedge.CastShadow = false
	wedge.Material = Enum.Material.Neon
	wedge.Color = color
	wedge.Transparency = transparency
	wedge.Size = Vector3.new(width, thickness, length)
	return wedge
end

type SpikeLayer = {
	count: number,
	yawOffset: number,
	upBias: number,
	startRadius: number,
	endRadius: number,
	length: number,
	width: number,
	color: Color3,
}

local function emitSpikeLayer(
	origin: Vector3,
	layer: SpikeLayer,
	duration: number,
	parts: { BasePart },
	radiusMul: number,
	startTransparency: number
)
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local thickness = VfxConfig.BAT_SLAM_SPIKE_THICKNESS
	for i = 1, layer.count do
		local yaw = ((i - 1) / layer.count) * math.pi * 2 + layer.yawOffset
		local scale = spikeLengthScale(i, layer.count)
		local length = layer.length * scale
		local width = layer.width * (0.75 + scale * 0.35)
		local startRadius = layer.startRadius * radiusMul
		local endRadius = layer.endRadius * radiusMul
		local wedge = makeSpike(layer.color, width, thickness, length, startTransparency)
		wedge.CFrame = spikeCFrame(origin, yaw, startRadius, length, layer.upBias)
		wedge.Parent = effectsFolder()
		table.insert(parts, wedge)
		TweenService:Create(wedge, info, {
			CFrame = spikeCFrame(origin, yaw, endRadius, length, layer.upBias),
			Transparency = 1,
		}):Play()
	end
end

local function emitEnergyBurst(
	origin: Vector3,
	delaySec: number,
	hot: boolean,
	radiusMul: number,
	duration: number,
	startTransparency: number
)
	local function spawn()
		local hotColor = VfxConfig.BAT_SLAM_WAVE_COLOR_HOT
		local bodyColor = VfxConfig.BAT_SLAM_WAVE_COLOR
		local color = if hot then hotColor else bodyColor
		local parts: { BasePart } = {}

		-- Inner crown: mostly vertical spikes (the bowl around the impact).
		emitSpikeLayer(origin, {
			count = VfxConfig.BAT_SLAM_CROWN_INNER_COUNT,
			yawOffset = 0.11,
			upBias = 0.9,
			startRadius = VfxConfig.BAT_SLAM_CROWN_INNER_START_RADIUS,
			endRadius = VfxConfig.BAT_SLAM_CROWN_INNER_END_RADIUS,
			length = VfxConfig.BAT_SLAM_CROWN_INNER_START_LENGTH,
			width = VfxConfig.BAT_SLAM_CROWN_INNER_WIDTH,
			color = hotColor,
		}, duration, parts, radiusMul, startTransparency)

		-- Outer crown: spikes leaning out (height stays fixed).
		emitSpikeLayer(origin, {
			count = VfxConfig.BAT_SLAM_CROWN_COUNT,
			yawOffset = 0,
			upBias = 0.68,
			startRadius = VfxConfig.BAT_SLAM_CROWN_START_RADIUS,
			endRadius = VfxConfig.BAT_SLAM_CROWN_END_RADIUS,
			length = VfxConfig.BAT_SLAM_CROWN_START_LENGTH,
			width = VfxConfig.BAT_SLAM_CROWN_WIDTH,
			color = color,
		}, duration, parts, radiusMul, startTransparency)

		-- Ground ring: jagged halo wrapping the burst.
		emitSpikeLayer(origin, {
			count = VfxConfig.BAT_SLAM_RING_COUNT,
			yawOffset = 0.16,
			upBias = 0.22,
			startRadius = VfxConfig.BAT_SLAM_RING_START_RADIUS,
			endRadius = VfxConfig.BAT_SLAM_RING_END_RADIUS,
			length = VfxConfig.BAT_SLAM_RING_START_LENGTH,
			width = VfxConfig.BAT_SLAM_RING_WIDTH,
			color = bodyColor,
		}, duration, parts, radiusMul, startTransparency)

		task.delay(duration + 0.08, function()
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

function VfxUtil.playBatSlam(position: Vector3, quality: string?)
	local ground = position + Vector3.new(0, 0.2, 0)
	if quality == "Minimal" then
		return
	end
	local waves = VfxConfig.BAT_SLAM_WAVE_COUNT
	if quality == "Reduced" then
		waves = math.max(1, math.ceil(waves / 2))
	end
	for w = 1, waves do
		local pulseSpread = 1 + (w - 1) * VfxConfig.BAT_SLAM_WIDEN_PER_WAVE
		emitEnergyBurst(
			ground,
			(w - 1) * VfxConfig.BAT_SLAM_WAVE_STAGGER,
			w % 2 == 1,
			pulseSpread,
			VfxConfig.BAT_SLAM_WAVE_DURATION,
			VfxConfig.BAT_SLAM_TRANSPARENCY
		)
	end
end

-- Thin neon segment between two world points (used to build curved soundwaves).
local function createWaveSegment(
	a: Vector3,
	b: Vector3,
	color: Color3,
	thickness: number,
	transparency: number?,
	material: Enum.Material?
): BasePart
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
	part.Material = material or Enum.Material.Neon
	part.Color = color
	part.Transparency = if type(transparency) == "number" then transparency else 0.05
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
	local quality = VfxLoad.quality()
	if quality == "Minimal" then
		return
	end
	local flat = if direction then Vector3.new(direction.X, 0, direction.Z) else Vector3.new(-1, 0, 0)
	local dir = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(1, 0, 0)
	-- Perpendicular across the lawn rows (Z when traveling along ±X).
	local right = Vector3.new(-dir.Z, 0, dir.X)
	if right.Magnitude < 1e-3 then
		right = Vector3.zAxis
	else
		right = right.Unit
	end

	local waveCount = VfxConfig.TERRIFY_WAVE_COUNT
	if quality == "Reduced" then
		waveCount = math.max(1, math.ceil(waveCount * 0.5))
	end
	for i = 0, waveCount - 1 do
		local distance = VfxConfig.TERRIFY_WAVE_START_DISTANCE + i * VfxConfig.TERRIFY_WAVE_SPACING
		emitTerrifyArc(origin, dir, right, distance, i * VfxConfig.TERRIFY_WAVE_STAGGER)
	end
end

--[[
	Cartoon dizzy: several ★ stars orbiting in a flat halo above the Brainrot.
	Replaces any prior DizzyVfx on the same model so refreshes don't stack.
]]
function VfxUtil.playDizzy(model: Model, duration: number)
	local quality = VfxLoad.quality()
	if quality == "Minimal" then
		return
	end
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
	if quality == "Reduced" then
		starCount = math.max(2, math.ceil(starCount * 0.5))
	end
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

	local angle = 0
	local spinConnection: RBXScriptConnection
	spinConnection = RunService.Heartbeat:Connect(function(dt)
		if not gui.Parent then
			spinConnection:Disconnect()
			return
		end
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
	gui.Destroying:Connect(function()
		spinConnection:Disconnect()
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

	Per-model queue: if Stun + Poison land together, the first word uses the
	faster lead duration, then the next plays after it finishes — never stacked
	on top of each other.
]]
type StatusFloaterJob = { text: string, color: Color3 }

type StatusFloaterQueue = {
	jobs: { StatusFloaterJob },
	busy: boolean,
	drainScheduled: boolean,
}

local statusFloaterQueues: { [Model]: StatusFloaterQueue } = {}

local function playStatusFloaterNow(model: Model, job: StatusFloaterJob, duration: number, onDone: () -> ())
	local anchor = model.PrimaryPart
		or model:FindFirstChild("Body", true)
		or model:FindFirstChild("HumanoidRootPart", true)
		or model:FindFirstChildWhichIsA("BasePart", true)
	if not (anchor and anchor:IsA("BasePart")) then
		onDone()
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
	label.Text = job.text
	label.TextScaled = true
	label.TextColor3 = job.color
	label.TextStrokeColor3 = Color3.fromRGB(20, 15, 30)
	label.TextStrokeTransparency = 0
	label.Parent = gui

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
		onDone()
	end)
end

local function drainStatusFloaterQueue(model: Model)
	local state = statusFloaterQueues[model]
	if not state or state.busy then
		return
	end
	if not model.Parent then
		statusFloaterQueues[model] = nil
		return
	end

	local job = table.remove(state.jobs, 1)
	if not job then
		statusFloaterQueues[model] = nil
		return
	end

	state.busy = true
	-- Hurry the lead word when another is waiting so the follow-up can start sooner.
	local duration = if #state.jobs > 0
		then VfxConfig.STATUS_FLOAT_DURATION_LEAD
		else VfxConfig.STATUS_FLOAT_DURATION

	playStatusFloaterNow(model, job, duration, function()
		local current = statusFloaterQueues[model]
		if not current then
			return
		end
		current.busy = false
		if #current.jobs > 0 then
			drainStatusFloaterQueue(model)
		else
			statusFloaterQueues[model] = nil
		end
	end)
end

function VfxUtil.playStatusFloater(model: Model, text: string, color: Color3)
	local state = statusFloaterQueues[model]
	if not state then
		state = {
			jobs = {},
			busy = false,
			drainScheduled = false,
		}
		statusFloaterQueues[model] = state
	end

	table.insert(state.jobs, { text = text, color = color })

	-- Defer the first drain so same-frame Stun + Poison both land in the queue
	-- before we pick lead vs. follow-up timing.
	if state.busy or state.drainScheduled then
		return
	end
	state.drainScheduled = true
	task.defer(function()
		local current = statusFloaterQueues[model]
		if not current then
			return
		end
		current.drainScheduled = false
		drainStatusFloaterQueue(model)
	end)
end

function VfxUtil.decorateProjectile(part: BasePart)
	if part:GetAttribute("VfxDecorated") == true then
		return
	end
	part:SetAttribute("VfxDecorated", true)

	if VfxLoad.quality() == "Minimal" then
		for _, descendant in part:GetDescendants() do
			if descendant:IsA("Trail") or descendant:IsA("ParticleEmitter") then
				descendant.Enabled = false
			end
		end
		return
	end

	local kind = part:GetAttribute("ProjectileKind")
	if kind == "SwordWave" then
		return
	end
	local isBubble = kind == "Bubble"
	local isBat = kind == "Bat"
	local isShuriken = kind == "Shuriken"
	local piercing = isShuriken
		and (
			part:GetAttribute("PiercingBrew") == true
			or (part.Parent ~= nil and part.Parent:GetAttribute("PiercingBrew") == true)
		)
	local barrage = isBubble
		and (
			part:GetAttribute("BubbleBarrage") == true
			or (part.Parent ~= nil and part.Parent:GetAttribute("BubbleBarrage") == true)
		)
	local trailColor = if piercing
		then VfxConfig.PIERCE_SHURIKEN_TRAIL_COLOR
		elseif barrage then VfxConfig.BUBBLE_BARRAGE_STREAK_COLOR
		elseif isShuriken then VfxConfig.SHURIKEN_PROJECTILE_TRAIL_COLOR
		else VfxConfig.PROJECTILE_TRAIL_COLOR
	local pierceSequence = ColorSequence.new({
		ColorSequenceKeypoint.new(0, VfxConfig.PIERCE_SHURIKEN_TRAIL_COLOR),
		ColorSequenceKeypoint.new(1, VfxConfig.PIERCE_SHURIKEN_TRAIL_COLOR_TAIL),
	})
	-- Segment must be perpendicular to travel (+X) or the ribbon has no area.
	local halfWidth = if piercing
		then VfxConfig.PIERCE_SHURIKEN_TRAIL_WIDTH * 0.55
		elseif barrage then VfxConfig.BUBBLE_BARRAGE_STREAK_WIDTH * 0.55
		elseif isShuriken then VfxConfig.SHURIKEN_PROJECTILE_TRAIL_WIDTH * 0.55
		else VfxConfig.PROJECTILE_TRAIL_WIDTH * 0.55
	if VfxLoad.quality() == "Reduced" then
		halfWidth *= 0.6
	end

	local function paintGold(root: Instance)
		for _, inst in root:GetDescendants() do
			if inst:IsA("Trail") then
				inst.Color = pierceSequence
				inst.LightEmission = VfxConfig.PIERCE_SHURIKEN_TRAIL_LIGHT_EMISSION
			end
		end
		if root:IsA("Trail") then
			root.Color = pierceSequence
			root.LightEmission = VfxConfig.PIERCE_SHURIKEN_TRAIL_LIGHT_EMISSION
		end
	end

	if piercing then
		paintGold(part)
		if part.Parent then
			paintGold(part.Parent)
		end
	end

	if (not isBubble or barrage) and not isBat and part:FindFirstChildOfClass("Trail") == nil then
	local attachment0 = Instance.new("Attachment")
	attachment0.Name = "TrailStart"
		attachment0.Position = Vector3.new(0, halfWidth, 0)
	attachment0.Parent = part

	local attachment1 = Instance.new("Attachment")
	attachment1.Name = "TrailEnd"
		attachment1.Position = Vector3.new(0, -halfWidth, 0)
	attachment1.Parent = part

	local trail = Instance.new("Trail")
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
		trail.Lifetime = if piercing
			then VfxConfig.PIERCE_SHURIKEN_TRAIL_LIFETIME
			elseif barrage then VfxConfig.BUBBLE_BARRAGE_STREAK_LIFETIME
			elseif isShuriken then VfxConfig.SHURIKEN_PROJECTILE_TRAIL_LIFETIME
			else VfxConfig.PROJECTILE_TRAIL_LIFETIME
	trail.WidthScale = NumberSequence.new(
			if piercing
				then VfxConfig.PIERCE_SHURIKEN_TRAIL_WIDTH
				elseif barrage then VfxConfig.BUBBLE_BARRAGE_STREAK_WIDTH
				elseif isShuriken then VfxConfig.SHURIKEN_PROJECTILE_TRAIL_WIDTH
				else VfxConfig.PROJECTILE_TRAIL_WIDTH
		)
		local barrageSequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, VfxConfig.BUBBLE_BARRAGE_STREAK_COLOR),
			ColorSequenceKeypoint.new(1, VfxConfig.BUBBLE_BARRAGE_STREAK_COLOR_TAIL),
		})
		trail.Color = if piercing
			then pierceSequence
			elseif barrage then barrageSequence
			else ColorSequence.new(trailColor)
		trail.LightEmission = if piercing
			then VfxConfig.PIERCE_SHURIKEN_TRAIL_LIGHT_EMISSION
			elseif barrage then VfxConfig.BUBBLE_BARRAGE_STREAK_LIGHT_EMISSION
			else 1
		trail.FaceCamera = true
		trail.Transparency = NumberSequence.new(0, 1)
	trail.Parent = part
	end

	if not isBat then
	local glow = Instance.new("PointLight")
		glow.Brightness = if piercing
			then VfxConfig.PIERCE_SHURIKEN_GLOW_BRIGHTNESS
			elseif isBubble then VfxConfig.BUBBLE_PROJECTILE_GLOW_BRIGHTNESS
			elseif isShuriken then VfxConfig.SHURIKEN_PROJECTILE_GLOW_BRIGHTNESS
		else VfxConfig.PROJECTILE_GLOW_BRIGHTNESS
		glow.Range = if piercing
			then VfxConfig.PIERCE_SHURIKEN_GLOW_RANGE
			elseif isBubble then VfxConfig.BUBBLE_PROJECTILE_GLOW_RANGE
			elseif isShuriken then VfxConfig.SHURIKEN_PROJECTILE_GLOW_RANGE
		else VfxConfig.PROJECTILE_GLOW_RANGE
		glow.Color = if barrage
			then VfxConfig.BUBBLE_BARRAGE_COLOR
			elseif isBubble then VfxConfig.BUBBLE_PROJECTILE_COLOR
			else trailColor
	glow.Parent = part
	end
end

local function sandSequence(): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, VfxConfig.SAND_COLOR_A),
		ColorSequenceKeypoint.new(0.5, VfxConfig.SAND_COLOR_B),
		ColorSequenceKeypoint.new(1, VfxConfig.SAND_COLOR_C),
	})
end

local function sandEmitter(parent: Instance, size0: number, size1: number, rate: number): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = sandSequence()
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size0),
		NumberSequenceKeypoint.new(1, size1),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.65, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(4, 14)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(120, 360)
	emitter.Rate = rate
	emitter.LightEmission = 0.05
	emitter.LightInfluence = 0.35
	emitter.Acceleration = Vector3.new(0, 18, 0)
	emitter.Drag = 1
	emitter.LockedToPart = true
	emitter.Parent = parent
	return emitter
end

--[[
	Prefer the right (grab) hand for Pharaoh steal; Toolbox names vary.
]]
function VfxUtil.findStealHand(model: Model): BasePart?
	local preferred = {
		"RightHand",
		"Right Hand",
		"RightArm",
		"Right Arm",
		"RightLowerArm",
		"RightUpperArm",
		"RArm",
		"righthand",
		"rightarm",
	}
	for _, name in preferred do
		local child = model:FindFirstChild(name, true)
		if child and child:IsA("BasePart") then
			return child
		end
	end

	local fallback: BasePart? = nil
	for _, descendant in model:GetDescendants() do
		if not descendant:IsA("BasePart") then
			continue
		end
		local n = string.lower(descendant.Name)
		if string.find(n, "hand", 1, true) or string.find(n, "palm", 1, true) or string.find(n, "fist", 1, true) then
			if string.find(n, "right", 1, true) or string.find(n, "r_", 1, true) then
				return descendant
			end
			if fallback == nil then
				fallback = descendant
			end
		elseif fallback == nil and (string.find(n, "rightarm", 1, true) or string.find(n, "rarm", 1, true)) then
			fallback = descendant
		end
	end
	return fallback
end

local function cframeFromUp(position: Vector3, up: Vector3, spin: number): CFrame
	local axis = if up.Magnitude > 1e-3 then up.Unit else Vector3.yAxis
	local right = axis:Cross(Vector3.zAxis)
	if right.Magnitude < 0.15 then
		right = axis:Cross(Vector3.xAxis)
	end
	right = right.Unit
	return CFrame.fromMatrix(position, right, axis) * CFrame.Angles(0, spin, 0)
end

type SandFunnel = {
	root: Model,
	pose: (Vector3, Vector3, number) -> (),
}

-- Same sand funnel Pharaoh's steal uses: narrow at the hub, wide at the far
-- end, with the grit emitters. `pose` aims it along `axis`.
local function createSandFunnel(): SandFunnel
	local height = VfxConfig.SAND_TORNADO_HEIGHT
	local radius = VfxConfig.SAND_TORNADO_RADIUS
	local sandColor = VfxConfig.SAND_COLOR_A

	local root = Instance.new("Model")
	root.Name = "SandTornado"
	root.Parent = effectsFolder()

	local column = Instance.new("Part")
	column.Name = "Hub"
	column.Anchored = true
	column.CanCollide = false
	column.CanQuery = false
	column.CanTouch = false
	column.Transparency = 1
	column.Size = Vector3.new(1, 1, 1)
	column.Parent = root
	root.PrimaryPart = column

	local bands: { BasePart } = {}
	for i = 1, 7 do
		local t = (i - 1) / 6
		local ringRadius = radius * (0.35 + t * 0.85)
		local band = Instance.new("Part")
		band.Name = "Funnel" .. i
		band.Shape = Enum.PartType.Cylinder
		band.Anchored = true
		band.CanCollide = false
		band.CanQuery = false
		band.CanTouch = false
		band.CastShadow = false
		band.Material = Enum.Material.Sand
		band.Color = if i % 2 == 0 then VfxConfig.SAND_COLOR_B else sandColor
		band.Transparency = VfxConfig.SAND_TORNADO_MESH_TRANSPARENCY
		band.Size = Vector3.new(height / 7 + 0.6, ringRadius * 2, ringRadius * 2)
		band.Parent = root
		table.insert(bands, band)
	end

	local function pose(pos: Vector3, axis: Vector3, spinAngle: number)
		local hub = cframeFromUp(pos, axis, spinAngle)
		column.CFrame = hub
		for index, band in bands do
			local along = (index - 1) / math.max(#bands - 1, 1)
			band.CFrame = hub * CFrame.new(0, along * height + height / 14, 0) * CFrame.Angles(0, 0, math.rad(90))
		end
	end

	local columnEmitter = sandEmitter(column, 8, 2.2, 90)
	columnEmitter:Emit(48)
	for i = 1, 4 do
		local attachment = Instance.new("Attachment")
		local angle = (i / 4) * math.pi * 2
		attachment.Position = Vector3.new(math.cos(angle) * radius * 0.45, height * 0.35, math.sin(angle) * radius * 0.45)
		attachment.Parent = column
		local swirl = sandEmitter(attachment, 4.2, 1.1, 40)
		swirl.LockedToPart = true
		swirl.SpreadAngle = Vector2.new(80, 80)
		swirl.Speed = NumberRange.new(8, 18)
		swirl:Emit(16)
	end

	return {
		root = root,
		pose = pose,
	}
end

--[[
	Pharaoh steal: a sand funnel pointing from the boss toward the stolen
	plants, plus grit pulled in from each plant.
]]
function VfxUtil.playSandTornado(destination: Vector3, origins: { Vector3 }?, attachTo: BasePart?)
	if VfxLoad.quality() == "Minimal" then
		return
	end
	local duration = VfxConfig.SAND_TORNADO_DURATION
	local radius = VfxConfig.SAND_TORNADO_RADIUS
	local folder = effectsFolder()
	local funnel = createSandFunnel()
	local root = funnel.root
	if VfxLoad.quality() == "Reduced" then
		for _, descendant in root:GetDescendants() do
			if descendant:IsA("ParticleEmitter") then
				descendant.Rate *= 0.35
			elseif descendant:IsA("BasePart") and descendant.Name ~= "Hub" and descendant.Transparency < 1 then
				descendant.Transparency = math.max(descendant.Transparency, 0.55)
			end
		end
	end

	local function bodyPosition(): Vector3
		if attachTo and attachTo.Parent then
			return attachTo.Position
		end
		return destination
	end

	local function aimAxis(fromPos: Vector3): Vector3
		-- Monsters face the house (−X). Fall back to that if nothing was stolen.
		local horizontal = Vector3.new(-1, 0, 0)
		if origins and #origins > 0 then
			local sum = Vector3.zero
			for _, origin in origins do
				sum += origin
			end
			local toward = (sum / #origins) - fromPos
			local flat = Vector3.new(toward.X, 0, toward.Z)
			if flat.Magnitude > 1 then
				horizontal = flat.Unit
			end
		end
		return horizontal
	end

	local function mouthPosition(fromPos: Vector3, axis: Vector3): Vector3
		return fromPos + Vector3.new(0, radius * 0.45, 0) + axis * VfxConfig.SAND_TORNADO_HAND_OFFSET
	end

	local startBody = bodyPosition()
	funnel.pose(mouthPosition(startBody, aimAxis(startBody)), aimAxis(startBody), 0)

	if origins then
		for _, origin in origins do
			local suck = Instance.new("Part")
			suck.Name = "SandSuck"
			suck.Anchored = true
			suck.CanCollide = false
			suck.CanQuery = false
			suck.CanTouch = false
			suck.Transparency = 1
			suck.Size = Vector3.new(0.2, 0.2, 0.2)
			suck.Position = origin + Vector3.new(0, 2, 0)
			suck.Parent = folder

			local pullTo = if attachTo then attachTo.Position else destination
			local toDest = pullTo - origin
			local accel = Vector3.new(toDest.X, toDest.Y + 6, toDest.Z) * 2.4
			local grit = Instance.new("ParticleEmitter")
			grit.Texture = "rbxasset://textures/particles/smoke_main.dds"
			grit.Color = sandSequence()
			grit.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 2.4),
				NumberSequenceKeypoint.new(1, 0.4),
			})
			grit.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(1, 1),
			})
			grit.Lifetime = NumberRange.new(0.45, 0.9)
			grit.Speed = NumberRange.new(8, 16)
			grit.SpreadAngle = Vector2.new(30, 30)
			grit.Rate = 36
			grit.LightEmission = 0.05
			grit.LightInfluence = 0.35
			grit.Acceleration = accel
			grit.Drag = 0.2
			grit.Parent = suck
			grit:Emit(28)

			task.delay(duration + 0.5, function()
				suck:Destroy()
			end)
		end
	end

	local RunService = game:GetService("RunService")
	local elapsed = 0
	local spinAngle = 0
	local spin = VfxConfig.SAND_TORNADO_SPIN
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		if not root.Parent then
			conn:Disconnect()
			return
		end
		elapsed += dt
		spinAngle += spin * dt
		local body = bodyPosition()
		local axis = aimAxis(body)
		funnel.pose(mouthPosition(body, axis), axis, spinAngle)
		if elapsed >= duration then
			for _, descendant in root:GetDescendants() do
				if descendant:IsA("ParticleEmitter") then
					descendant.Enabled = false
					descendant.Rate = 0
				elseif descendant:IsA("BasePart") and descendant.Name:find("Funnel") == 1 then
					descendant.Transparency = math.min(1, descendant.Transparency + dt * 2)
				end
			end
		end
	end)

	task.delay(duration + 1.1, function()
		if conn.Connected then
			conn:Disconnect()
		end
		root:Destroy()
	end)
end

local function spawnFunnelTransparency(): number
	if VfxLoad.quality() == "Full" then
		return VfxConfig.SPAWN_SANDSTORM_HIGH_TRANSPARENCY
	end
	return VfxConfig.SPAWN_SANDSTORM_LOW_TRANSPARENCY
end

-- High fills the tornado solid. Low thins the shell and hides the opaque core
-- so the boss is only partly visible. Off never builds one.
function VfxUtil.refreshSpawnSandstorm(root: Instance)
	if root:GetAttribute("SandstormFading") == true then
		return
	end
	local dense = VfxLoad.quality() == "Full"
	local shell = spawnFunnelTransparency()
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") and string.sub(descendant.Name, 1, 6) == "Funnel" then
			descendant.Transparency = shell
		elseif descendant:IsA("BasePart") and descendant:GetAttribute("VfxLayer") == "High" then
			descendant.LocalTransparencyModifier = if dense then 0 else 1
		elseif descendant:IsA("ParticleEmitter") then
			local fullRate = descendant:GetAttribute("SandRate")
			if type(fullRate) ~= "number" then
				fullRate = descendant.Rate
			end
			descendant.Enabled = true
			descendant.Rate = if dense then fullRate else math.max(8, math.floor(fullRate * 0.3))
		end
	end
end

--[[
	Pharaoh entrance: the steal sand tornado, stood straight up and large
	enough to cover his whole body. `coverWidth` / `coverHeight` are his
	visual size. Caller stops it when he takes his first step.
]]
function VfxUtil.playSpawnSandstorm(ground: Vector3, coverWidth: number, coverHeight: number): () -> ()
	local fadeTime = VfxConfig.SPAWN_SANDSTORM_FADE
	local width = math.max(coverWidth * VfxConfig.SPAWN_SANDSTORM_WIDTH_PAD, VfxConfig.SPAWN_SANDSTORM_MIN_WIDTH)
	local height = math.max(coverHeight * VfxConfig.SPAWN_SANDSTORM_HEIGHT_PAD, VfxConfig.SPAWN_SANDSTORM_MIN_HEIGHT)
	local radius = width * 0.5
	local sandColor = VfxConfig.SAND_COLOR_A

	local root = Instance.new("Model")
	root.Name = "SpawnSandstorm"
	root.Parent = effectsFolder()

	local column = Instance.new("Part")
	column.Name = "Hub"
	column.Anchored = true
	column.CanCollide = false
	column.CanQuery = false
	column.CanTouch = false
	column.Transparency = 1
	column.Size = Vector3.new(1, 1, 1)
	column.Parent = root
	root.PrimaryPart = column

	local bands: { BasePart } = {}
	local bandCount = 9
	for i = 1, bandCount do
		local t = (i - 1) / (bandCount - 1)
		-- Wide the whole way, a little wider at the top, so his body stays inside.
		local ringRadius = radius * (1 + t * 0.4)
		local band = Instance.new("Part")
		band.Name = "Funnel" .. i
		band.Shape = Enum.PartType.Cylinder
		band.Anchored = true
		band.CanCollide = false
		band.CanQuery = false
		band.CanTouch = false
		band.CastShadow = false
		band.Material = Enum.Material.Sand
		band.Color = if i % 2 == 0 then VfxConfig.SAND_COLOR_B else sandColor
		band.Transparency = spawnFunnelTransparency()
		band.Size = Vector3.new(height / bandCount * 1.45, ringRadius * 2, ringRadius * 2)
		band.Parent = root
		table.insert(bands, band)
	end

	-- Solid core so High hides him completely. Low turns this layer off.
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Cylinder
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.CastShadow = false
	core.Material = Enum.Material.Sand
	core.Color = VfxConfig.SAND_COLOR_B
	core.Transparency = 0
	core.Size = Vector3.new(height, radius * 1.35, radius * 1.35)
	core:SetAttribute("VfxLayer", "High")
	core.Parent = root

	local function pose(spinAngle: number)
		local hub = cframeFromUp(ground, Vector3.yAxis, spinAngle)
		column.CFrame = hub
		local upright = CFrame.Angles(0, 0, math.rad(90))
		for index, band in bands do
			local along = (index - 1) / math.max(#bands - 1, 1)
			band.CFrame = hub * CFrame.new(0, along * height + height / (bandCount * 2), 0) * upright
		end
		core.CFrame = hub * CFrame.new(0, height * 0.5, 0) * upright
	end

	local columnEmitter = sandEmitter(column, radius * 0.55, radius * 0.16, 120)
	columnEmitter:SetAttribute("SandRate", 120)
	columnEmitter:Emit(64)
	for i = 1, 6 do
		local attachment = Instance.new("Attachment")
		local angle = (i / 6) * math.pi * 2
		attachment.Position = Vector3.new(math.cos(angle) * radius * 0.45, height * 0.45, math.sin(angle) * radius * 0.45)
		attachment.Parent = column
		local swirl = sandEmitter(attachment, radius * 0.28, radius * 0.08, 48)
		swirl:SetAttribute("SandRate", 48)
		swirl.SpreadAngle = Vector2.new(80, 80)
		swirl.Speed = NumberRange.new(10, 24)
		swirl:Emit(20)
	end

	VfxUtil.refreshSpawnSandstorm(root)
	pose(0)

	local spinAngle = 0
	local spin = VfxConfig.SAND_TORNADO_SPIN
	local spinning = true
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		if not spinning or not root.Parent then
			conn:Disconnect()
			return
		end
		spinAngle += spin * dt
		pose(spinAngle)
	end)

	local stopped = false
	return function()
		if stopped then
			return
		end
		stopped = true
		spinning = false
		root:SetAttribute("SandstormFading", true)
		if conn.Connected then
			conn:Disconnect()
		end
		local started = os.clock()
		local fadeConn: RBXScriptConnection
		fadeConn = RunService.Heartbeat:Connect(function(dt)
			local alpha = (os.clock() - started) / math.max(fadeTime, 0.05)
			if alpha >= 1 or not root.Parent then
				fadeConn:Disconnect()
				if root.Parent then
					root:Destroy()
				end
				return
			end
			for _, descendant in root:GetDescendants() do
				if descendant:IsA("ParticleEmitter") then
					descendant.Enabled = false
					descendant.Rate = 0
				elseif descendant:IsA("BasePart") and descendant.Transparency < 1 and descendant.Name ~= "Hub" then
					descendant.Transparency = math.min(1, descendant.Transparency + dt * (1 / math.max(fadeTime, 0.05)))
				end
			end
		end)
	end
end

function VfxUtil.playWindGust(plotModel: Model)
	local quality = VfxLoad.quality()
	if quality == "Minimal" then
		return
	end
	local PlotUtil = require(script.Parent.PlotUtil)
	local GridConfig = require(ReplicatedStorage.Shared.Config.GridConfig)
	local PlotConfig = require(ReplicatedStorage.Shared.Config.PlotConfig)

	local westSample = PlotUtil.getTileTopCenter(plotModel, 1, 1)
	local eastSample = PlotUtil.getTileTopCenter(plotModel, 1, GridConfig.COLUMNS)
	if not westSample or not eastSample then
		return
	end

	local eastDir = Vector3.new(eastSample.X - westSample.X, 0, eastSample.Z - westSample.Z)
	if eastDir.Magnitude < 0.01 then
		eastDir = Vector3.new(1, 0, 0)
	else
		eastDir = eastDir.Unit
	end

	-- Emit from the west of each row so streaks travel east across the lawn
	-- (a plot-sized box facing east spawned particles off the forest edge).
	local root = Instance.new("Folder")
	root.Name = "WindGust"
	root.Parent = effectsFolder()

	for row = 1, GridConfig.ROWS do
		if quality == "Reduced" and row % 2 == 0 then
			continue
		end
		local west = PlotUtil.getTileTopCenter(plotModel, row, 1)
		if west then
			local origin = west + Vector3.new(0, 4, 0)
			local anchor = Instance.new("Part")
			anchor.Name = "GustRow"
			anchor.Anchored = true
			anchor.CanCollide = false
			anchor.CanQuery = false
			anchor.CanTouch = false
			anchor.Transparency = 1
			anchor.Size = Vector3.new(2.5, 14, PlotConfig.TILE_SIZE * 1.15)
			anchor.CFrame = CFrame.lookAt(origin, origin + eastDir)
			anchor.Parent = root

			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = "Gust"
			emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
			emitter.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, VfxConfig.WIND_GUST_COLOR_A),
				ColorSequenceKeypoint.new(1, VfxConfig.WIND_GUST_COLOR_B),
			})
			emitter.Size = VfxConfig.WIND_GUST_SIZE
			emitter.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.15),
				NumberSequenceKeypoint.new(0.4, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			})
			emitter.Lifetime = VfxConfig.WIND_GUST_LIFETIME
			emitter.Speed = NumberRange.new(VfxConfig.WIND_GUST_SPEED * 0.75, VfxConfig.WIND_GUST_SPEED)
			emitter.Rate = if quality == "Reduced"
				then math.max(6, math.ceil(VfxConfig.WIND_GUST_RATE * 0.4))
				else VfxConfig.WIND_GUST_RATE
			emitter.SpreadAngle = Vector2.new(12, 28)
			emitter.Acceleration = eastDir * VfxConfig.WIND_GUST_ACCEL_EAST + Vector3.new(0, 8, 0)
			emitter.EmissionDirection = Enum.NormalId.Front
			emitter.RotSpeed = NumberRange.new(-50, 50)
			emitter.LightEmission = 0.55
			emitter.LockedToPart = false
			emitter.Parent = anchor
			emitter:Emit(if quality == "Reduced"
				then math.max(4, math.ceil(VfxConfig.WIND_GUST_BURST * 0.4))
				else VfxConfig.WIND_GUST_BURST)
		end
	end

	task.delay(VfxConfig.WIND_GUST_DURATION, function()
		for _, descendant in root:GetDescendants() do
			if descendant:IsA("ParticleEmitter") then
				descendant.Enabled = false
				descendant.Rate = 0
			end
		end
	end)
	task.delay(VfxConfig.WIND_GUST_DURATION + 1.4, function()
		root:Destroy()
	end)
end

local magnetWaveToken = 0

type MagnetRing = {
	token: number,
	root: BasePart,
	parts: { BasePart },
	born: number,
	startRadius: number,
	endRadius: number,
	speed: number,
	lift: number,
	thickness: number,
	startTrans: number,
}

local magnetRings: { MagnetRing } = {}
local magnetHeartbeat: RBXScriptConnection? = nil

local function destroyMagnetRing(ring: MagnetRing)
	for _, part in ring.parts do
		if part.Parent then
			part:Destroy()
		end
	end
	table.clear(ring.parts)
end

local function stopMagnetHeartbeat()
	if magnetHeartbeat then
		magnetHeartbeat:Disconnect()
		magnetHeartbeat = nil
	end
end

local function ensureMagnetHeartbeat()
	if magnetHeartbeat then
		return
	end
	magnetHeartbeat = RunService.Heartbeat:Connect(function()
		local index = 1
		while index <= #magnetRings do
			local ring = magnetRings[index]
			if magnetWaveToken ~= ring.token or not ring.root.Parent then
				destroyMagnetRing(ring)
				table.remove(magnetRings, index)
				continue
			end
			local radius = ring.startRadius - ring.speed * (os.clock() - ring.born)
			if radius <= ring.endRadius then
				destroyMagnetRing(ring)
				table.remove(magnetRings, index)
				continue
			end
			local count = #ring.parts
			local nowCf = ring.root.CFrame * CFrame.new(0, ring.lift, 0)
			local step = (math.pi * 2) / math.max(count, 1)
			for i, part in ring.parts do
				if not part.Parent then
					continue
				end
				local yaw0 = (i - 1) * step
				local yaw1 = i * step
				local p0 = Vector3.new(math.sin(yaw0) * radius, 0, math.cos(yaw0) * radius)
				local p1 = Vector3.new(math.sin(yaw1) * radius, 0, math.cos(yaw1) * radius)
				local mid = (p0 + p1) * 0.5
				local delta = p1 - p0
				part.Size = Vector3.new(ring.thickness, ring.thickness, math.max(delta.Magnitude, 0.05))
				part.Transparency = ring.startTrans
				local worldMid = nowCf:PointToWorldSpace(mid)
				part.CFrame = CFrame.lookAt(worldMid, worldMid + nowCf:VectorToWorldSpace(delta))
			end
			index += 1
		end
		if #magnetRings == 0 then
			stopMagnetHeartbeat()
		end
	end)
end

local function spawnMagnetCircle(root: BasePart, token: number, startRadius: number)
	if magnetWaveToken ~= token or not root.Parent then
		return
	end

	local count = VfxConfig.MAGNET_WAVE_SEGMENTS
	local thickness = VfxConfig.MAGNET_WAVE_THICKNESS
	local color = VfxConfig.MAGNET_WAVE_COLOR
	local startTrans = VfxConfig.MAGNET_WAVE_TRANSPARENCY
	local endRadius = math.max(0.05, VfxConfig.MAGNET_WAVE_END_RADIUS)
	local speed = VfxConfig.MAGNET_WAVE_SPEED
	local lift = VfxConfig.MAGNET_WAVE_LIFT

	local parts: { BasePart } = {}
	for _ = 1, count do
		local part = Instance.new("Part")
		part.Name = "MagnetWaveSeg"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = color
		part.Transparency = startTrans
		part.Size = Vector3.new(thickness, thickness, 1)
		part.Parent = effectsFolder()
		table.insert(parts, part)
	end

	table.insert(magnetRings, {
		token = token,
		root = root,
		parts = parts,
		born = os.clock(),
		startRadius = startRadius,
		endRadius = endRadius,
		speed = speed,
		lift = lift,
		thickness = thickness,
		startTrans = startTrans,
	})
	ensureMagnetHeartbeat()
end

function VfxUtil.stopMagnetWaves()
	magnetWaveToken += 1
end

--[[
	Translucent purple circular soundwaves around the local character: each
	pulse starts at the outer pull range and collapses inward. High
	frequency. A new call cancels the previous loop.
]]
--[[
	La Vacca: rings collapse into her while grit is sucked from the monster.
	Off skips the effect. Low uses fewer rings and less grit.
]]
-- Blueberrinni: dark blue droplet on an arc. Off skips it. Low keeps the drop and drops the tail.
function VfxUtil.playInkDrop(from: Vector3, to: Vector3, arcHeight: number?)
	local quality = VfxLoad.quality()
	if quality == "Minimal" then
		return
	end

	local flight = VfxConfig.INK_FLIGHT_SECONDS
	local arc = if type(arcHeight) == "number" then arcHeight else VfxConfig.INK_ARC_HEIGHT_MAX
	local ink = VfxConfig.INK_COLOR

	local drop = Instance.new("Part")
	drop.Name = "InkDrop"
	drop.Shape = Enum.PartType.Ball
	drop.Anchored = true
	drop.CanCollide = false
	drop.CanQuery = false
	drop.CanTouch = false
	drop.CastShadow = false
	drop.Material = Enum.Material.SmoothPlastic
	drop.Color = ink
	drop.Size = Vector3.new(1.35, 1.35, 1.35)
	drop.CFrame = CFrame.new(from)
	drop.Parent = effectsFolder()

	if quality == "Full" then
		local left = Instance.new("Attachment")
		left.Name = "InkTailLeft"
		left.Position = Vector3.new(-0.28, 0, 0.45)
		left.Parent = drop
		local right = Instance.new("Attachment")
		right.Name = "InkTailRight"
		right.Position = Vector3.new(0.28, 0, 0.45)
		right.Parent = drop
		local ribbon = Instance.new("Trail")
		ribbon.Name = "InkTail"
		ribbon.Attachment0 = left
		ribbon.Attachment1 = right
		ribbon.Color = ColorSequence.new(ink)
		ribbon.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(1, 1),
		})
		ribbon.Lifetime = 0.95
		ribbon.MinLength = 0.05
		ribbon.FaceCamera = true
		ribbon.LightEmission = 0.05
		ribbon.WidthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.45),
			NumberSequenceKeypoint.new(1, 0),
		})
		ribbon.Parent = drop
	end

	local function pointOnArc(alpha: number): Vector3
		local flat = from:Lerp(to, alpha)
		return flat + Vector3.new(0, math.sin(alpha * math.pi) * arc, 0)
	end

	local started = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local alpha = math.clamp((os.clock() - started) / flight, 0, 1)
		local pos = pointOnArc(alpha)
		local ahead = pointOnArc(math.clamp(alpha + 0.04, 0, 1))
		local dir = ahead - pos
		if dir.Magnitude < 0.05 then
			dir = to - from
		end
		if dir.Magnitude < 0.05 then
			dir = Vector3.new(1, 0, 0)
		end
		drop.CFrame = CFrame.lookAt(pos, pos + dir.Unit)
		if alpha >= 1 then
			conn:Disconnect()
			drop:Destroy()
		end
	end)
end

function VfxUtil.playGravityPull(center: Vector3, origins: { Vector3 }?)
	if VfxLoad.quality() == "Minimal" then
		return
	end
	local dense = VfxLoad.quality() == "Full"
	local duration = VfxConfig.GRAVITY_PULL_DURATION
	local radius = VfxConfig.GRAVITY_PULL_RADIUS
	local folder = effectsFolder()

	local root = Instance.new("Part")
	root.Name = "GravityPull"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Transparency = 1
	root.Size = Vector3.new(1, 1, 1)
	root.CFrame = CFrame.new(center)
	root.Parent = folder

	local ringCount = if dense then 3 else 2
	local rings: { BasePart } = {}
	for i = 1, ringCount do
		local ring = Instance.new("Part")
		ring.Name = "Ring"
		ring.Shape = Enum.PartType.Cylinder
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CastShadow = false
		ring.Material = Enum.Material.Neon
		ring.Color = if i % 2 == 0 then VfxConfig.GRAVITY_PULL_COLOR_DIM else VfxConfig.GRAVITY_PULL_COLOR
		ring.Transparency = 0.35
		ring.Parent = folder
		table.insert(rings, ring)
	end

	for _, origin in origins or {} do
		local suck = Instance.new("Part")
		suck.Name = "GravitySuck"
		suck.Anchored = true
		suck.CanCollide = false
		suck.CanQuery = false
		suck.CanTouch = false
		suck.Transparency = 1
		suck.Size = Vector3.new(0.2, 0.2, 0.2)
		suck.Position = origin + Vector3.new(0, 2, 0)
		suck.Parent = folder
		local toCenter = center - origin
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Color = ColorSequence.new(VfxConfig.GRAVITY_PULL_COLOR, VfxConfig.GRAVITY_PULL_COLOR_DIM)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, if dense then 1.8 else 1.1),
			NumberSequenceKeypoint.new(1, 0.2),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Lifetime = NumberRange.new(0.35, 0.7)
		emitter.Speed = NumberRange.new(6, 14)
		emitter.SpreadAngle = Vector2.new(18, 18)
		emitter.Rate = if dense then 70 else 28
		emitter.LightEmission = 0.4
		emitter.Acceleration = Vector3.new(toCenter.X, toCenter.Y + 4, toCenter.Z) * 3
		emitter.Drag = 0.4
		emitter.Parent = suck
		emitter:Emit(if dense then 24 else 10)
		task.delay(duration + 0.4, function()
			suck:Destroy()
		end)
	end

	local started = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local alpha = (os.clock() - started) / duration
		if alpha >= 1 or not root.Parent then
			conn:Disconnect()
			for _, ring in rings do
				if ring.Parent then
					ring:Destroy()
				end
			end
			if root.Parent then
				root:Destroy()
			end
			return
		end
		local spin = os.clock() * 2.5
		for index, ring in rings do
			local band = (index - 1) / math.max(ringCount - 1, 1)
			local size = radius * (1 - alpha) * (0.45 + band * 0.7)
			ring.Size = Vector3.new(0.18, math.max(size * 2, 0.2), math.max(size * 2, 0.2))
			ring.Transparency = 0.25 + alpha * 0.7
			ring.CFrame = CFrame.new(center + Vector3.new(0, 1.2 + band * 0.4, 0))
				* CFrame.Angles(0, spin + band, math.rad(90))
		end
	end)
end

function VfxUtil.playMagnetWaves(character: Model, duration: number, startRadius: number?)
	if VfxLoad.quality() == "Minimal" then
		return
	end
	magnetWaveToken += 1
	local token = magnetWaveToken
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local radius = startRadius or VfxConfig.MAGNET_WAVE_START_RADIUS
	local interval = VfxConfig.MAGNET_WAVE_INTERVAL
	if VfxLoad.quality() == "Reduced" then
		interval *= 2
	end
	local remaining = math.max(0.1, duration)
	local pulses = math.max(1, math.ceil(remaining / interval))

	task.spawn(function()
		for pulse = 1, pulses do
			if magnetWaveToken ~= token then
				return
			end
			spawnMagnetCircle(root, token, radius)
			if pulse < pulses then
				task.wait(interval)
			end
		end
	end)
end

--[[
	Strip or restore heavy particles/trails on a replicated GOD-ult model.
	Server always authors Full and may rewrite Enabled each frame; Performance
	mode keeps a local guard so particles stay off on this client.
]]
local qualityGuards: { [Instance]: RBXScriptConnection } = {}

local function clearQualityGuard(inst: Instance)
	local conn = qualityGuards[inst]
	if conn then
		conn:Disconnect()
		qualityGuards[inst] = nil
	end
end

function VfxUtil.applyHeavyQuality(root: Instance, highQuality: boolean)
	local showHighLayer = VfxLoad.quality() == "Full"
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("VfxLayer") == "High" then
			descendant.LocalTransparencyModifier = if showHighLayer then 0 else 1
			continue
		end
		if not (descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("Beam")) then
			continue
		end
		clearQualityGuard(descendant)
		if highQuality then
			descendant.Enabled = true
			continue
		end
		descendant.Enabled = false
		if descendant:IsA("ParticleEmitter") then
			descendant:Clear()
		end
		qualityGuards[descendant] = descendant:GetPropertyChangedSignal("Enabled"):Connect(function()
			if VfxLoad.quality() ~= "Minimal" or not descendant.Enabled then
				return
			end
			descendant.Enabled = false
			if descendant:IsA("ParticleEmitter") then
				descendant:Clear()
			end
		end)
	end
end

VfxLoad.onChanged(function(level)
	if level == "Minimal" then
		VfxUtil.stopMagnetWaves()
	end
end)

return VfxUtil
