--!strict
--[[
	MonsterFeedback
	Server-side visual feedback on monster models (replicates to clients).

	Attack pulse uses Model:ScaleTo so authored MeshParts are not Size-warped.
	Hit flash tints visible BaseParts (same pattern as BrainrotFeedback).
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterConfig = require(ReplicatedStorage.Shared.Config.MonsterConfig)
local ModelUtil = require(ReplicatedStorage.Shared.Utilities.ModelUtil)

local MonsterFeedback = {}

local baseScales: { [Model]: number } = {}
local pulseTokens: { [Model]: number } = {}

local activeHitFlashTweens: { [Model]: { Tween } } = {}
local hitFlashBaseColors: { [Model]: { [BasePart]: Color3 } } = {}

type FrozenLook = {
	colors: { [BasePart]: Color3 },
	materials: { [BasePart]: Enum.Material },
}

local frozenLooks: { [Model]: FrozenLook } = {}
local bubbledModels: { [Model]: boolean } = {}
local poppingBubbles: { [Model]: boolean } = {}

local function visibleParts(model: Model): { BasePart }
	local parts: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Transparency < 0.95 and descendant.Name ~= "BubbleShell" then
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
	return nil
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

local function ensureFreezeVfx(body: BasePart)
	local existing = body:FindFirstChild("FreezeVfx")
	if existing then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "FreezeVfx"
	attachment.Parent = body

	local flakes = Instance.new("ParticleEmitter")
	flakes.Name = "IceFlakes"
	flakes.Color = ColorSequence.new(MonsterConfig.FREEZE_COLOR)
	flakes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	flakes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	flakes.Lifetime = NumberRange.new(0.4, 0.8)
	flakes.Speed = NumberRange.new(0.5, 2)
	flakes.SpreadAngle = Vector2.new(180, 180)
	flakes.Rate = 12
	flakes.LightEmission = 0.4
	flakes.Parent = attachment
end

local function clearFreezeVfx(body: BasePart)
	local existing = body:FindFirstChild("FreezeVfx")
	if existing then
		existing:Destroy()
	end
end

function MonsterFeedback.pulseAttack(model: Model)
	local token = (pulseTokens[model] or 0) + 1
	pulseTokens[model] = token

	local base = baseScales[model]
	if not base then
		base = model:GetScale()
		baseScales[model] = base
	else
		model:ScaleTo(base)
	end

	model:ScaleTo(base * MonsterConfig.ATTACK_PULSE_SCALE)
	local half = MonsterConfig.ATTACK_PULSE_DURATION / 2
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

function MonsterFeedback.flashHit(model: Model, _isFatal: boolean?)
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
		part.Color = MonsterConfig.HIT_FLASH_COLOR
	end

	local tweens: { Tween } = {}
	local remaining = 0
	for _, part in parts do
		local baseColor = bases[part]
		if baseColor then
			remaining += 1
			local tween = TweenService:Create(
				part,
				TweenInfo.new(MonsterConfig.HIT_FLASH_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
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

function MonsterFeedback.setFrozen(model: Model, frozen: boolean)
	local parts = visibleParts(model)
	local body = resolveBody(model)
	if #parts == 0 or not body then
		return
	end

	if frozen then
		cancelHitFlash(model)
		if not frozenLooks[model] then
			local colors: { [BasePart]: Color3 } = {}
			local materials: { [BasePart]: Enum.Material } = {}
			for _, part in parts do
				colors[part] = part.Color
				materials[part] = part.Material
			end
			frozenLooks[model] = { colors = colors, materials = materials }
		end
		local ice = MonsterConfig.FREEZE_COLOR
		for _, part in parts do
			part.Color = ice
			part.Material = MonsterConfig.FREEZE_MATERIAL
		end
		local bases = hitFlashBaseColors[model]
		if not bases then
			bases = {}
			hitFlashBaseColors[model] = bases
		end
		for _, part in parts do
			bases[part] = ice
		end
		model:SetAttribute("Frozen", true)
		ensureFreezeVfx(body)
	else
		local look = frozenLooks[model]
		if look then
			for part, color in look.colors do
				if part.Parent then
					part.Color = color
					part.Material = look.materials[part] or Enum.Material.SmoothPlastic
				end
			end
			hitFlashBaseColors[model] = look.colors
			frozenLooks[model] = nil
		end
		model:SetAttribute("Frozen", false)
		clearFreezeVfx(body)
	end
end

local function getBubbleShell(model: Model): BasePart?
	local shell = model:FindFirstChild("BubbleShell")
	if shell and shell:IsA("BasePart") then
		return shell
	end
	return nil
end

local function syncBubbleShell(model: Model, body: BasePart)
	local shell = getBubbleShell(model)
	if not shell then
		shell = Instance.new("Part")
		shell.Name = "BubbleShell"
		shell.Shape = Enum.PartType.Ball
		shell.Material = Enum.Material.ForceField
		shell.Anchored = true
		shell.CanCollide = false
		shell.CanTouch = false
		shell.CanQuery = false
		shell.CastShadow = false
		shell.Parent = model
	end

	-- Character bounds only (GetExtentsSize includes this shell and grows every tick).
	local size, center = ModelUtil.getVisualSizeAndCenter(model)
	if size.Magnitude < 1e-3 then
		size = body.Size
		center = body.Position
	end
	local pad = MonsterConfig.BUBBLE_SIZE_PADDING
	local diameter = math.max(size.X, size.Y, size.Z) + pad
	shell.Size = Vector3.new(diameter, diameter, diameter)
	shell.CFrame = CFrame.new(center)
	shell.Transparency = MonsterConfig.BUBBLE_TRANSPARENCY
	shell.Color = MonsterConfig.BUBBLE_COLOR
end

local function popBubbleShell(model: Model)
	local shell = getBubbleShell(model)
	if not shell then
		bubbledModels[model] = nil
		poppingBubbles[model] = nil
		return
	end

	if poppingBubbles[model] then
		return
	end
	poppingBubbles[model] = true
	bubbledModels[model] = nil

	local popSize = shell.Size * 1.45
	local tween = TweenService:Create(
		shell,
		TweenInfo.new(MonsterConfig.BUBBLE_POP_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{
			Size = popSize,
			Transparency = 1,
		}
	)
	tween:Play()
	tween.Completed:Connect(function()
		poppingBubbles[model] = nil
		if shell.Parent then
			shell:Destroy()
		end
	end)
end

function MonsterFeedback.setBubbled(model: Model, bubbled: boolean)
	local body = resolveBody(model)
	if not body then
		return
	end

	if bubbled then
		if poppingBubbles[model] then
			return
		end
		bubbledModels[model] = true
		model:SetAttribute("Bubbled", true)
		syncBubbleShell(model, body)
		return
	end

	if not bubbledModels[model] and not getBubbleShell(model) then
		model:SetAttribute("Bubbled", false)
		return
	end

	model:SetAttribute("Bubbled", false)
	popBubbleShell(model)
end

function MonsterFeedback.cleanup(model: Model)
	local base = baseScales[model]
	if base and model.Parent then
		model:ScaleTo(base)
	end
	baseScales[model] = nil
	pulseTokens[model] = nil

	cancelHitFlash(model)
	local bases = hitFlashBaseColors[model]
	if bases then
		for part, color in bases do
			if part.Parent then
				part.Color = color
			end
		end
	end
	hitFlashBaseColors[model] = nil
	frozenLooks[model] = nil
	bubbledModels[model] = nil
	poppingBubbles[model] = nil

	local body = resolveBody(model)
	if body then
		clearFreezeVfx(body)
	end

	local shell = getBubbleShell(model)
	if shell then
		shell:Destroy()
	end
end

return MonsterFeedback
