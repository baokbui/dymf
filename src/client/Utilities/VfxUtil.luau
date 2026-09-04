--!strict
--[[
	VfxUtil
	Ephemeral client-only particle and tween effects. No gameplay authority.
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
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

	local kind = part:GetAttribute("ProjectileKind")
	local isBubble = kind == "Bubble"
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

	if (not isBubble or barrage) and part:FindFirstChildOfClass("Trail") == nil then
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
		trail.LightEmission = if piercing then VfxConfig.PIERCE_SHURIKEN_TRAIL_LIGHT_EMISSION else 1
		trail.FaceCamera = true
		trail.Transparency = NumberSequence.new(0, 1)
		trail.Parent = part
	end

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
	glow.Color = if isBubble then VfxConfig.BUBBLE_PROJECTILE_COLOR else trailColor
	glow.Parent = part
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

local function stealTornadoAxis(hand: BasePart, origins: { Vector3 }?): Vector3
	-- Funnel local +Y is out of the palm; flip so the cone opens toward the plants
	-- instead of back into the arm.
	if origins and #origins > 0 then
		local sum = Vector3.zero
		for _, origin in origins do
			sum += origin
		end
		local toward = (sum / #origins) - hand.Position
		if toward.Magnitude > 1.25 then
			return toward.Unit
		end
	end
	local look = -hand.CFrame.LookVector
	if look.Magnitude > 0.2 then
		return look.Unit
	end
	return Vector3.yAxis
end

--[[
	Pharaoh steal: a big spinning sand funnel, rooted on `attachTo` (steal
	hand) when provided, plus grit pulled from each plant origin.
]]
function VfxUtil.playSandTornado(destination: Vector3, origins: { Vector3 }?, attachTo: BasePart?)
	local duration = VfxConfig.SAND_TORNADO_DURATION
	local height = VfxConfig.SAND_TORNADO_HEIGHT
	local radius = VfxConfig.SAND_TORNADO_RADIUS
	local folder = effectsFolder()
	local sandColor = VfxConfig.SAND_COLOR_A
	local handOffset = VfxConfig.SAND_TORNADO_HAND_OFFSET

	local startAxis = Vector3.yAxis
	local startPos = destination + Vector3.new(0, height * 0.08, 0)
	if attachTo then
		startAxis = stealTornadoAxis(attachTo, origins)
		startPos = attachTo.Position + startAxis * handOffset
	end

	local root = Instance.new("Model")
	root.Name = "SandTornado"
	root.Parent = folder

	local column = Instance.new("Part")
	column.Name = "Hub"
	column.Anchored = true
	column.CanCollide = false
	column.CanQuery = false
	column.CanTouch = false
	column.Transparency = 1
	column.Size = Vector3.new(1, 1, 1)
	column.CFrame = cframeFromUp(startPos, startAxis, 0)
	column.Parent = root
	root.PrimaryPart = column

	-- Visible funnel: wide at the base, tapering up.
	for i = 1, 7 do
		local t = (i - 1) / 6
		-- Narrow at the hand, wide toward the steal targets.
		local ringRadius = radius * (0.22 + t * 0.8)
		local band = Instance.new("Part")
		band.Name = "Funnel" .. i
		band.Shape = Enum.PartType.Cylinder
		band.Anchored = true
		band.CanCollide = false
		band.CanQuery = false
		band.CanTouch = false
		band.Material = Enum.Material.Sand
		band.Color = if i % 2 == 0 then VfxConfig.SAND_COLOR_B else sandColor
		band.Transparency = VfxConfig.SAND_TORNADO_MESH_TRANSPARENCY
		-- Cylinder default is X-axis; rotate so it stands on Y.
		band.Size = Vector3.new(height / 7 + 0.4, ringRadius * 2, ringRadius * 2)
		band.CFrame = column.CFrame
			* CFrame.new(0, t * height + height / 14, 0)
			* CFrame.Angles(0, 0, math.rad(90))
		band.Parent = root

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = column
		weld.Part1 = band
		weld.Parent = band
		band.Anchored = false
		band.Massless = true
	end

	sandEmitter(column, 3.2, 0.8, 55)
	for i = 1, 4 do
		local attachment = Instance.new("Attachment")
		local angle = (i / 4) * math.pi * 2
		attachment.Position = Vector3.new(math.cos(angle) * radius * 0.4, height * 0.2, math.sin(angle) * radius * 0.4)
		attachment.Parent = column
		local swirl = sandEmitter(attachment, 2.2, 0.45, 28)
		swirl.LockedToPart = true
		swirl.SpreadAngle = Vector2.new(80, 80)
		swirl.Speed = NumberRange.new(8, 18)
	end

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
		if not column.Parent then
			conn:Disconnect()
			return
		end
		elapsed += dt
		spinAngle += spin * dt
		local pos = destination + Vector3.new(0, height * 0.08, 0)
		local axis = Vector3.yAxis
		if attachTo and attachTo.Parent then
			axis = stealTornadoAxis(attachTo, origins)
			pos = attachTo.Position + axis * handOffset
		end
		column.CFrame = cframeFromUp(pos, axis, spinAngle)
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

function VfxUtil.playWindGust(plotModel: Model)
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
			emitter.Rate = VfxConfig.WIND_GUST_RATE
			emitter.SpreadAngle = Vector2.new(12, 28)
			emitter.Acceleration = eastDir * VfxConfig.WIND_GUST_ACCEL_EAST + Vector3.new(0, 8, 0)
			emitter.EmissionDirection = Enum.NormalId.Front
			emitter.RotSpeed = NumberRange.new(-50, 50)
			emitter.LightEmission = 0.55
			emitter.LockedToPart = false
			emitter.Parent = anchor
			emitter:Emit(48)
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

local function spawnMagnetCircle(root: BasePart, token: number)
	if magnetWaveToken ~= token or not root.Parent then
		return
	end

	local count = VfxConfig.MAGNET_WAVE_SEGMENTS
	local thickness = VfxConfig.MAGNET_WAVE_THICKNESS
	local color = VfxConfig.MAGNET_WAVE_COLOR
	local startTrans = VfxConfig.MAGNET_WAVE_TRANSPARENCY
	local startRadius = VfxConfig.MAGNET_WAVE_START_RADIUS
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

--[[
	Translucent purple circular soundwaves around the local character: each
	pulse starts at the outer pull range and collapses inward. High
	frequency. A new call cancels the previous loop.
]]
function VfxUtil.playMagnetWaves(character: Model, duration: number)
	magnetWaveToken += 1
	local token = magnetWaveToken
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local interval = VfxConfig.MAGNET_WAVE_INTERVAL
	local remaining = math.max(0.1, duration)
	local pulses = math.max(1, math.ceil(remaining / interval))

	task.spawn(function()
		for pulse = 1, pulses do
			if magnetWaveToken ~= token then
				return
			end
			spawnMagnetCircle(root, token)
			if pulse < pulses then
				task.wait(interval)
			end
		end
	end)
end

return VfxUtil
