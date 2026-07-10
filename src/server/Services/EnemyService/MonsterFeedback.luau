--!strict
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterConfig = require(ReplicatedStorage.Shared.Config.MonsterConfig)

local MonsterFeedback = {}

local activePulseTweens: { [Model]: Tween } = {}
local activeHitFlashTweens: { [Model]: Tween } = {}
local hitFlashBaseColor: { [Model]: Color3 } = {}

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

	local existing = activeHitFlashTweens[model]
	if existing then
		existing:Cancel()
		activeHitFlashTweens[model] = nil
	end

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

function MonsterFeedback.cleanup(model: Model)
	local pulse = activePulseTweens[model]
	if pulse then
		pulse:Cancel()
		activePulseTweens[model] = nil
	end

	local flash = activeHitFlashTweens[model]
	if flash then
		flash:Cancel()
		activeHitFlashTweens[model] = nil
	end
	hitFlashBaseColor[model] = nil
end

return MonsterFeedback
