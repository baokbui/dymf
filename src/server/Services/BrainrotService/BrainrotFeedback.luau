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

function BrainrotFeedback.cleanup(model: Model)
	cancelHitFlash(model)
	if poisonLooks[model] then
		BrainrotFeedback.setPoisoned(model, false)
	end
	hitFlashBaseColors[model] = nil
	poisonLooks[model] = nil

	local base = baseScales[model]
	if base and model.Parent then
		model:ScaleTo(base)
	end
	baseScales[model] = nil
	pulseTokens[model] = nil
end

return BrainrotFeedback
