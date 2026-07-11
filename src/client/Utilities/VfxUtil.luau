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

-- Smaller blast for each tile along a line-bomb row.
function VfxUtil.playTileExplosion(position: Vector3)
	emitBurst(
		position,
		VfxConfig.EXPLOSION_COLOR,
		VfxConfig.TILE_EXPLOSION_BURST_COUNT,
		VfxConfig.TILE_EXPLOSION_BURST_SPEED,
		VfxConfig.TILE_EXPLOSION_BURST_SIZE,
		VfxConfig.TILE_EXPLOSION_BURST_LIFETIME
	)

	local ring = Instance.new("Part")
	ring.Name = "TileExplosionRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = VfxConfig.EXPLOSION_COLOR
	ring.Transparency = 0.4
	ring.Size = VfxConfig.TILE_EXPLOSION_RING_SIZE * 0.4
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
end

function VfxUtil.decorateProjectile(part: BasePart)
	if part:GetAttribute("VfxDecorated") == true then
		return
	end
	part:SetAttribute("VfxDecorated", true)

	local attachment0 = Instance.new("Attachment")
	attachment0.Name = "TrailStart"
	attachment0.Parent = part

	local attachment1 = Instance.new("Attachment")
	attachment1.Name = "TrailEnd"
	attachment1.Position = Vector3.new(-0.6, 0, 0)
	attachment1.Parent = part

	local trail = Instance.new("Trail")
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
	trail.Lifetime = VfxConfig.PROJECTILE_TRAIL_LIFETIME
	trail.WidthScale = NumberSequence.new(VfxConfig.PROJECTILE_TRAIL_WIDTH)
	trail.Color = ColorSequence.new(VfxConfig.PROJECTILE_TRAIL_COLOR)
	trail.LightEmission = 1
	trail.Parent = part

	local glow = Instance.new("PointLight")
	glow.Brightness = VfxConfig.PROJECTILE_GLOW_BRIGHTNESS
	glow.Range = VfxConfig.PROJECTILE_GLOW_RANGE
	glow.Color = VfxConfig.PROJECTILE_TRAIL_COLOR
	glow.Parent = part
end

return VfxUtil
