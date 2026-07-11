--!strict
--[[
	MonsterFeedback
	Server-side visual feedback on monster models (replicates to clients).
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterConfig = require(ReplicatedStorage.Shared.Config.MonsterConfig)

local MonsterFeedback = {}

local activePulseTweens: { [Model]: Tween } = {}
local activeHitFlashTweens: { [Model]: Tween } = {}
local hitFlashBaseColor: { [Model]: Color3 } = {}

type FrozenLook = {
	color: Color3,
	material: Enum.Material,
}

local frozenLooks: { [Model]: FrozenLook } = {}
local bubbledModels: { [Model]: boolean } = {}
local poppingBubbles: { [Model]: boolean } = {}

local function cancelHitFlash(model: Model)
	local existing = activeHitFlashTweens[model]
	if existing then
		existing:Cancel()
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
	local body = model:FindFirstChild("Body")
	if not body or not body:IsA("BasePart") then
		return
	end

	local existing = activePulseTweens[model]
	if existing then
		existing:Cancel()
	end

	local baseSize = body.Size
	local scaled = baseSize * MonsterConfig.ATTACK_PULSE_SCALE
	local up = TweenService:Create(
		body,
		TweenInfo.new(MonsterConfig.ATTACK_PULSE_DURATION / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = scaled }
	)
	local down = TweenService:Create(
		body,
		TweenInfo.new(MonsterConfig.ATTACK_PULSE_DURATION / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Size = baseSize }
	)

	activePulseTweens[model] = up
	up:Play()
	up.Completed:Connect(function()
		if activePulseTweens[model] == up then
			activePulseTweens[model] = down
			down:Play()
		end
	end)
	down.Completed:Connect(function()
		if activePulseTweens[model] == down then
			activePulseTweens[model] = nil
		end
	end)
end

function MonsterFeedback.flashHit(model: Model, isFatal: boolean?)
	local body = model:FindFirstChild("Body")
	if not body or not body:IsA("BasePart") then
		return
	end

	cancelHitFlash(model)

	local baseColor = hitFlashBaseColor[model] or body.Color
	hitFlashBaseColor[model] = baseColor
	body.Color = MonsterConfig.HIT_FLASH_COLOR

	if isFatal then
		return
	end

	local tween = TweenService:Create(
		body,
		TweenInfo.new(MonsterConfig.HIT_FLASH_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Color = baseColor }
	)
	activeHitFlashTweens[model] = tween
	tween:Play()
	tween.Completed:Connect(function()
		if activeHitFlashTweens[model] == tween then
			activeHitFlashTweens[model] = nil
		end
	end)
end

-- Icy tint + flakes while Freeze/Stun is active (replicates to clients).
function MonsterFeedback.setFrozen(model: Model, frozen: boolean)
	local body = model:FindFirstChild("Body")
	if not body or not body:IsA("BasePart") then
		return
	end

	if frozen then
		cancelHitFlash(model)
		if not frozenLooks[model] then
			frozenLooks[model] = {
				color = hitFlashBaseColor[model] or body.Color,
				material = body.Material,
			}
		end
		local ice = MonsterConfig.FREEZE_COLOR
		hitFlashBaseColor[model] = ice
		body.Color = ice
		body.Material = MonsterConfig.FREEZE_MATERIAL
		model:SetAttribute("Frozen", true)
		ensureFreezeVfx(body)
		return
	end

	local look = frozenLooks[model]
	if not look then
		return
	end
	cancelHitFlash(model)
	body.Color = look.color
	body.Material = look.material
	hitFlashBaseColor[model] = look.color
	frozenLooks[model] = nil
	model:SetAttribute("Frozen", false)
	clearFreezeVfx(body)
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
		shell.Color = MonsterConfig.BUBBLE_COLOR
		shell.Transparency = MonsterConfig.BUBBLE_TRANSPARENCY
		shell.CanCollide = false
		shell.CanQuery = false
		shell.CanTouch = false
		shell.Massless = true
		shell.CastShadow = false
		shell.Anchored = body.Anchored
		shell.Parent = model
	end

	local pad = MonsterConfig.BUBBLE_SIZE_PADDING
	local diameter = math.max(body.Size.X, body.Size.Y, body.Size.Z) + pad
	shell.Size = Vector3.new(diameter, diameter, diameter)
	shell.CFrame = body.CFrame
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

-- Translucent bubble shell around the monster while BubbleTrap freeze is active.
function MonsterFeedback.setBubbled(model: Model, bubbled: boolean)
	local body = model:FindFirstChild("Body")
	if not body or not body:IsA("BasePart") then
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
	local pulse = activePulseTweens[model]
	if pulse then
		pulse:Cancel()
		activePulseTweens[model] = nil
	end

	cancelHitFlash(model)
	hitFlashBaseColor[model] = nil
	frozenLooks[model] = nil
	bubbledModels[model] = nil
	poppingBubbles[model] = nil

	local body = model:FindFirstChild("Body")
	if body and body:IsA("BasePart") then
		clearFreezeVfx(body)
	end

	local shell = getBubbleShell(model)
	if shell then
		shell:Destroy()
	end
end

return MonsterFeedback
