--!strict
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterConfig = require(ReplicatedStorage.Shared.Config.MonsterConfig)

local MonsterFeedback = {}

local activeTweens: { [Model]: Tween } = {}

function MonsterFeedback.pulseAttack(model: Model)
	local body = model:FindFirstChild("Body")
	if not body or not body:IsA("BasePart") then
		return
	end

	local existing = activeTweens[model]
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

	activeTweens[model] = up
	up:Play()
	up.Completed:Connect(function()
		if activeTweens[model] == up then
			activeTweens[model] = down
			down:Play()
		end
	end)
	down.Completed:Connect(function()
		if activeTweens[model] == down then
			activeTweens[model] = nil
		end
	end)
end

function MonsterFeedback.cleanup(model: Model)
	local tween = activeTweens[model]
	if tween then
		tween:Cancel()
		activeTweens[model] = nil
	end
end

return MonsterFeedback
