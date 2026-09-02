--!strict
--[[
	BrainrotFeedback
	Lightweight server-side visual feedback for Brainrot actions (replicated on
	the model). Sound playback is routed to the owning client via BrainrotAction.

	Attack pulse uses Model:ScaleTo so authored MeshParts are not Size-warped.
	Hit flash tints visible BaseParts (replicated Color), matching MonsterFeedback.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotConfig = require(ReplicatedStorage.Shared.Config.BrainrotConfig)
local VfxConfig = require(ReplicatedStorage.Shared.Config.VfxConfig)
local ModelUtil = require(ReplicatedStorage.Shared.Utilities.ModelUtil)

local BrainrotFeedback = {}

local baseScales: { [Model]: number } = {}
local pulseTokens: { [Model]: number } = {}

local activeHitFlashTweens: { [Model]: { Tween } } = {}
local hitFlashBaseColors: { [Model]: { [BasePart]: Color3 } } = {}
local poisonLooks: { [Model]: { [BasePart]: Color3 } } = {}

local function visibleParts(model: Model): { BasePart }
	local parts: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Transparency < 0.95 then
			if descendant.Name == "ShieldVfx" or descendant.Name == "AuraVfx" then
				continue
			end
			table.insert(parts, descendant)
		end
	end
	if #parts == 0 then
		local body = model.PrimaryPart or model:FindFirstChild("Body")
		if body and body:IsA("BasePart") then
			table.insert(parts, body)
		end
	end
	return parts
end

local function cancelHitFlash(model: Model)
	local tweens = activeHitFlashTweens[model]
	if tweens then
		for _, tween in tweens do
			tween:Cancel()
		end
		activeHitFlashTweens[model] = nil
	end
end

function BrainrotFeedback.pulseAttack(model: Model)
	local token = (pulseTokens[model] or 0) + 1
	pulseTokens[model] = token

	local base = baseScales[model]
	if not base then
		base = model:GetScale()
		baseScales[model] = base
	else
		model:ScaleTo(base)
	end

	model:ScaleTo(base * BrainrotConfig.ATTACK_PULSE_SCALE)
	local half = BrainrotConfig.ATTACK_PULSE_DURATION / 2
	task.delay(half, function()
		if pulseTokens[model] ~= token or not model.Parent then
			return
		end
		model:ScaleTo(base)
		task.delay(half, function()
			if pulseTokens[model] == token then
				pulseTokens[model] = nil
			end
		end)
	end)
end

-- Red tint on damage. Fatal keeps the tint until the model is destroyed.
function BrainrotFeedback.flashHit(model: Model, isFatal: boolean?)
	local parts = visibleParts(model)
	if #parts == 0 then
		return
	end

	cancelHitFlash(model)

	local bases = hitFlashBaseColors[model]
	if not bases then
		bases = {}
		hitFlashBaseColors[model] = bases
		for _, part in parts do
			bases[part] = part.Color
		end
	end

	for _, part in parts do
		if not bases[part] then
			bases[part] = part.Color
		end
		part.Color = BrainrotConfig.HIT_FLASH_COLOR
	end

	if isFatal then
		return
	end

	local tweens: { Tween } = {}
	local remaining = 0
	for _, part in parts do
		local baseColor = bases[part]
		if baseColor then
			remaining += 1
			local tween = TweenService:Create(
				part,
				TweenInfo.new(BrainrotConfig.HIT_FLASH_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Color = baseColor }
			)
			table.insert(tweens, tween)
			tween.Completed:Connect(function()
				remaining -= 1
				if remaining <= 0 and activeHitFlashTweens[model] == tweens then
					activeHitFlashTweens[model] = nil
				end
			end)
			tween:Play()
		end
	end
	activeHitFlashTweens[model] = tweens
end

-- Soft purple wash for the Poison status. Stores original colors on first
-- apply and restores them when cleared. Hit-flash bases follow the tint so
-- damage flashes return to purple while poisoned, not the pre-poison look.
function BrainrotFeedback.setPoisoned(model: Model, poisoned: boolean)
	local parts = visibleParts(model)
	if #parts == 0 then
		return
	end

	if poisoned then
		cancelHitFlash(model)
			if not poisonLooks[model] then
			local colors: { [BasePart]: Color3 } = {}
			local flashBases = hitFlashBaseColors[model]
			for _, part in parts do
				-- Prefer the pre-flash natural color if we have it.
				colors[part] = (flashBases and flashBases[part]) or part.Color
			end
			poisonLooks[model] = colors
		end

		local originals = poisonLooks[model]
		local tint = BrainrotConfig.POISON_TINT_COLOR
		local blend = BrainrotConfig.POISON_TINT_BLEND
		local tinted: { [BasePart]: Color3 } = {}
		for _, part in parts do
			local base = originals[part] or part.Color
			local washed = base:Lerp(tint, blend)
			part.Color = washed
			tinted[part] = washed
		end
		hitFlashBaseColors[model] = tinted
		model:SetAttribute("Poisoned", true)
	else
		local originals = poisonLooks[model]
		if originals then
			for part, color in originals do
				if part.Parent then
					part.Color = color
				end
			end
			hitFlashBaseColors[model] = originals
			poisonLooks[model] = nil
		end
		model:SetAttribute("Poisoned", false)
	end
end

local function resolveBody(model: Model): BasePart?
	local body = model:FindFirstChild("Body", true)
	if body and body:IsA("BasePart") then
		return body
	end
	local primary = model.PrimaryPart
	if primary then
		return primary
	end
	local hrp = model:FindFirstChild("HumanoidRootPart", true)
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

function BrainrotFeedback.clearAura(model: Model)
	while true do
		local existing = model:FindFirstChild("AuraVfx", true)
		if not existing then
			break
		end
		existing:Destroy()
	end
	local highlight = model:FindFirstChild("AuraHighlight")
	if highlight then
		highlight:Destroy()
	end
end

function BrainrotFeedback.clearShield(model: Model)
	local bubble = model:FindFirstChild("ShieldVfx")
	if bubble then
		bubble:Destroy()
	end
end

function BrainrotFeedback.setShield(model: Model, active: boolean)
	if not active then
		BrainrotFeedback.clearShield(model)
		return
	end
	if model:FindFirstChild("ShieldVfx") then
		return
	end

	local body = resolveBody(model)
	if not body then
		return
	end

	local visualSize, center = ModelUtil.getVisualSizeAndCenter(model)
	local diameter = math.max(visualSize.X, visualSize.Y, visualSize.Z, 2) * VfxConfig.SHIELD_BUBBLE_PADDING
	local bubble = Instance.new("Part")
	bubble.Name = "ShieldVfx"
	bubble.Shape = Enum.PartType.Ball
	bubble.Size = Vector3.new(diameter, diameter, diameter)
	bubble.CFrame = CFrame.new(center)
	bubble.Material = Enum.Material.ForceField
	bubble.Color = VfxConfig.SHIELD_BUBBLE_COLOR
	bubble.Transparency = VfxConfig.SHIELD_BUBBLE_TRANSPARENCY
	bubble.Anchored = false
	bubble.CanCollide = false
	bubble.CanQuery = false
	bubble.CanTouch = false
	bubble.Massless = true
	bubble.CastShadow = false
	bubble.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = bubble
	weld.Parent = bubble
end

local function discEmitter(parent: BasePart, name: string): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.LightInfluence = 0
	emitter.LockedToPart = false
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Shape = Enum.ParticleEmitterShape.Disc
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	emitter.Parent = parent
	return emitter
end

-- Super Saiyan column: stretched flame spikes, dark speed lines, sparkles,
-- thin rarity-colored silhouette. No mesh fill, no orbiting trails.
function BrainrotFeedback.applyAura(model: Model, auraColor: Color3?, auraScale: number?)
	BrainrotFeedback.clearAura(model)
	if not auraColor then
		return
	end

	local body = resolveBody(model)
	if not body then
		return
	end

	local scale = auraScale or 1
	local visualSize, center = ModelUtil.getVisualSizeAndCenter(model)
	local width = math.max(visualSize.X, visualSize.Z, 1.8)
	local feetY = center.Y - visualSize.Y * 0.48

	local disc = Instance.new("Part")
	disc.Name = "AuraVfx"
	disc.Size = Vector3.new(width * 1.55, 0.3, width * 1.55)
	disc.CFrame = CFrame.new(center.X, feetY, center.Z)
	disc.Transparency = 1
	disc.Anchored = false
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.Massless = true
	disc.CastShadow = false
	disc.Parent = model

	local discWeld = Instance.new("WeldConstraint")
	discWeld.Part0 = body
	discWeld.Part1 = disc
	discWeld.Parent = disc

	local hot = auraColor:Lerp(Color3.fromRGB(255, 255, 255), 0.38)
	local spikeColor = ColorSequence.new({
		ColorSequenceKeypoint.new(0, hot),
		ColorSequenceKeypoint.new(0.4, auraColor),
		ColorSequenceKeypoint.new(1, auraColor:Lerp(Color3.fromRGB(20, 10, 5), 0.28)),
	})

	local spikes = discEmitter(disc, "AuraSpikes")
	spikes.Color = spikeColor
	spikes.Texture = "rbxasset://textures/particles/fire_main.dds"
	spikes.LightEmission = 0.85
	spikes.Brightness = 3.2
	spikes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.95 * scale),
		NumberSequenceKeypoint.new(0.45, 1.55 * scale),
		NumberSequenceKeypoint.new(1, 0.4 * scale),
	})
	spikes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(0.55, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	spikes.Lifetime = NumberRange.new(0.35, 0.7)
	spikes.Speed = NumberRange.new(7 * scale, 13 * scale)
	spikes.SpreadAngle = Vector2.new(40, 52)
	spikes.Rate = 110
	spikes.Acceleration = Vector3.new(0, 26 * scale, 0)
	spikes.Drag = 0.5
	spikes.Squash = NumberSequence.new(-1.35)
	spikes.ZOffset = 2

	local outer = discEmitter(disc, "AuraOuter")
	outer.Color = spikeColor
	outer.Texture = "rbxasset://textures/particles/fire_main.dds"
	outer.LightEmission = 0.7
	outer.Brightness = 2.2
	outer.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2 * scale),
		NumberSequenceKeypoint.new(0.5, 2.15 * scale),
		NumberSequenceKeypoint.new(1, 0.75 * scale),
	})
	outer.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.28),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	outer.Lifetime = NumberRange.new(0.4, 0.85)
	outer.Speed = NumberRange.new(8 * scale, 14 * scale)
	outer.SpreadAngle = Vector2.new(62, 80)
	outer.Rate = 65
	outer.Acceleration = Vector3.new(0, 20 * scale, 0)
	outer.Drag = 0.7
	outer.Squash = NumberSequence.new(-1.15)
	outer.ZOffset = 1.5

	local mid = discEmitter(disc, "AuraMid")
	mid.Color = spikeColor
	mid.Texture = "rbxasset://textures/particles/fire_main.dds"
	mid.LightEmission = 0.8
	mid.Brightness = 2.8
	mid.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.05 * scale),
		NumberSequenceKeypoint.new(0.4, 1.75 * scale),
		NumberSequenceKeypoint.new(1, 0.5 * scale),
	})
	mid.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	mid.Lifetime = NumberRange.new(0.4, 0.8)
	mid.Speed = NumberRange.new(6 * scale, 12 * scale)
	mid.SpreadAngle = Vector2.new(50, 64)
	mid.Rate = 65
	mid.Acceleration = Vector3.new(0, 22 * scale, 0)
	mid.Drag = 0.55
	mid.Squash = NumberSequence.new(-1.25)
	mid.ZOffset = 1.8

	local lines = discEmitter(disc, "AuraLines")
	lines.Color = ColorSequence.new(auraColor:Lerp(Color3.fromRGB(18, 8, 6), 0.72))
	lines.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	lines.LightEmission = 0.15
	lines.Brightness = 0.4
	lines.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05 * scale),
		NumberSequenceKeypoint.new(1, 0.02 * scale),
	})
	lines.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	lines.Lifetime = NumberRange.new(0.25, 0.5)
	lines.Speed = NumberRange.new(12 * scale, 20 * scale)
	lines.SpreadAngle = Vector2.new(6, 10)
	lines.Rate = 22
	lines.Acceleration = Vector3.new(0, 32 * scale, 0)
	lines.Drag = 0.3
	lines.Squash = NumberSequence.new(-2)
	lines.ZOffset = 3

	local sparkles = discEmitter(disc, "AuraSparkles")
	sparkles.Color = ColorSequence.new(hot:Lerp(Color3.fromRGB(255, 255, 255), 0.45))
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.LightEmission = 1
	sparkles.Brightness = 2.8
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18 * scale),
		NumberSequenceKeypoint.new(0.5, 0.28 * scale),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.65, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparkles.Lifetime = NumberRange.new(0.35, 0.8)
	sparkles.Speed = NumberRange.new(2 * scale, 6 * scale)
	sparkles.SpreadAngle = Vector2.new(40, 50)
	sparkles.Rate = 28
	sparkles.Acceleration = Vector3.new(0, 8 * scale, 0)
	sparkles.Drag = 1.2
	sparkles.Squash = NumberSequence.new(0)
	sparkles.Orientation = Enum.ParticleOrientation.FacingCamera
	sparkles.ZOffset = 4

	local highlight = Instance.new("Highlight")
	highlight.Name = "AuraHighlight"
	highlight.Adornee = model
	highlight.FillColor = auraColor
	highlight.FillTransparency = 1
	highlight.OutlineColor = auraColor:Lerp(Color3.fromRGB(255, 255, 255), 0.2)
	highlight.OutlineTransparency = 0.15
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
end

function BrainrotFeedback.cleanup(model: Model)
	cancelHitFlash(model)
	if poisonLooks[model] then
		BrainrotFeedback.setPoisoned(model, false)
	end
	hitFlashBaseColors[model] = nil
	poisonLooks[model] = nil
	BrainrotFeedback.clearAura(model)
	BrainrotFeedback.clearShield(model)

	local base = baseScales[model]
	if base and model.Parent then
		model:ScaleTo(base)
	end
	baseScales[model] = nil
	pulseTokens[model] = nil
end

return BrainrotFeedback
