--!strict
--[[
	BrainrotFeedback
	Lightweight server-side visual feedback for Brainrot actions (replicated on
	the model). Sound playback is routed to the owning client via BrainrotAction.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotConfig = require(ReplicatedStorage.Shared.Config.BrainrotConfig)

local BrainrotFeedback = {}

local activeTweens: { [Model]: Tween } = {}

function BrainrotFeedback.pulseAttack(model: Model)
	local body = model:FindFirstChild("Body")
	if not body or not body:IsA("BasePart") then
		return
	end

	local existing = activeTweens[model]
	if existing then
		existing:Cancel()
		activeTweens[model] = nil
	end

	local baseSize = body.Size
	local scaled = baseSize * BrainrotConfig.ATTACK_PULSE_SCALE
	local up = TweenService:Create(
		body,
		TweenInfo.new(BrainrotConfig.ATTACK_PULSE_DURATION / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = scaled }
	)
	local down = TweenService:Create(
		body,
		TweenInfo.new(BrainrotConfig.ATTACK_PULSE_DURATION / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
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

function BrainrotFeedback.cleanup(model: Model)
	local tween = activeTweens[model]
	if tween then
		tween:Cancel()
		activeTweens[model] = nil
	end
end

return BrainrotFeedback
