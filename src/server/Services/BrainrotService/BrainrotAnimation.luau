--!strict
--[[
	BrainrotAnimation
	Plays idle / attack / hit AnimationTracks on authored Brainrot models that
	keep an AnimationController (or Humanoid) + Animator. IDs come from model
	children (IdleAnimation / AttackAnimation / HitAnimation), the
	BrainrotDefinition, or AnimSaves KeyframeSequences registered via
	AnimationClipProvider.
]]

local AnimationClipProvider = game:GetService("AnimationClipProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)

local BrainrotAnimation = {}

local log = Logger.new("BrainrotAnimation")

type AnimState = {
	animator: Animator,
	idle: AnimationTrack?,
	attack: AnimationTrack?,
	hit: AnimationTrack?,
}

local states: { [Model]: AnimState } = {}

local function findChildAnimation(model: Model, name: string): Animation?
	local child = model:FindFirstChild(name, true)
	if child and child:IsA("Animation") and child.AnimationId ~= "" then
		return child
	end
	return nil
end

local function findAnimator(model: Model): Animator?
	local controller = model:FindFirstChildOfClass("AnimationController")
	if controller then
		local animator = controller:FindFirstChildOfClass("Animator")
		if animator then
			return animator
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return humanoid:FindFirstChildOfClass("Animator")
	end
	return nil
end

local function registerAnimSavesId(model: Model): string?
	local animSaves = model:FindFirstChild("AnimSaves")
	if not animSaves then
		return nil
	end

	local sequences: { KeyframeSequence } = {}
	for _, descendant in animSaves:GetDescendants() do
		if descendant:IsA("KeyframeSequence") then
			table.insert(sequences, descendant)
		end
	end
	if #sequences == 0 then
		return nil
	end

	local chosen = sequences[1]
	for _, sequence in sequences do
		local lower = string.lower(sequence.Name)
		if string.find(lower, "idle", 1, true)
			or string.find(lower, "walk", 1, true)
			or string.find(lower, "stand", 1, true)
		then
			chosen = sequence
			break
		end
	end

	local ok, idOrErr = pcall(function()
		return AnimationClipProvider:RegisterAnimationClip(chosen)
	end)
	if not ok or type(idOrErr) ~= "string" or idOrErr == "" then
		log:warn("AnimSaves register failed on", model.Name, idOrErr)
		return nil
	end
	return idOrErr
end

local function resolveIdleId(model: Model, definition: Types.BrainrotDefinition): string?
	local embedded = findChildAnimation(model, "IdleAnimation")
		or findChildAnimation(model, "WalkAnimation")
		or findChildAnimation(model, "Animation")
	if embedded then
		return embedded.AnimationId
	end
	if definition.idleAnimationId ~= nil then
		if definition.idleAnimationId == "" then
			return nil
		end
		return definition.idleAnimationId
	end
	return registerAnimSavesId(model)
end

local function resolveAttackId(model: Model, definition: Types.BrainrotDefinition): string?
	local embedded = findChildAnimation(model, "AttackAnimation")
	if embedded then
		return embedded.AnimationId
	end
	if definition.attackAnimationId ~= nil then
		if definition.attackAnimationId == "" then
			return nil
		end
		return definition.attackAnimationId
	end
	return nil
end

local function resolveHitId(model: Model, definition: Types.BrainrotDefinition): string?
	local embedded = findChildAnimation(model, "HitAnimation")
	if embedded then
		return embedded.AnimationId
	end
	if definition.hitAnimationId ~= nil then
		if definition.hitAnimationId == "" then
			return nil
		end
		return definition.hitAnimationId
	end
	return nil
end

local function loadTrack(
	animator: Animator,
	animationId: string?,
	looped: boolean,
	priority: Enum.AnimationPriority
): AnimationTrack?
	if not animationId or animationId == "" then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	local ok, trackOrErr = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	animation:Destroy()
	if not ok or typeof(trackOrErr) ~= "Instance" then
		log:warn("failed to load brainrot animation", animationId, trackOrErr)
		return nil
	end
	local track = trackOrErr :: AnimationTrack
	track.Looped = looped
	track.Priority = priority
	return track
end

function BrainrotAnimation.bind(model: Model, definition: Types.BrainrotDefinition)
	BrainrotAnimation.unbind(model)

	if not definition.animated then
		return
	end

	local animator = findAnimator(model)
	if not animator then
		log:warn("animated brainrot missing Animator on", model.Name)
		return
	end

	local idle = loadTrack(
		animator,
		resolveIdleId(model, definition),
		true,
		Enum.AnimationPriority.Idle
	)
	local attack = loadTrack(
		animator,
		resolveAttackId(model, definition),
		false,
		Enum.AnimationPriority.Action
	)
	local hit = loadTrack(
		animator,
		resolveHitId(model, definition),
		false,
		Enum.AnimationPriority.Action2
	)

	states[model] = {
		animator = animator,
		idle = idle,
		attack = attack,
		hit = hit,
	}

	if idle then
		idle:Play(0.15)
	end
end

function BrainrotAnimation.playAttack(model: Model)
	local state = states[model]
	if not state or not state.attack then
		return
	end
	if state.attack.IsPlaying then
		state.attack:Stop(0)
	end
	state.attack:Play(0.05)
end

-- Length of the loaded attack clip in seconds (nil if missing / not ready).
function BrainrotAnimation.getAttackLength(model: Model): number?
	local state = states[model]
	if not state or not state.attack then
		return nil
	end
	local length = state.attack.Length
	if typeof(length) ~= "number" or length <= 0 then
		return nil
	end
	return length
end

function BrainrotAnimation.playHit(model: Model)
	local state = states[model]
	if not state or not state.hit then
		return
	end
	if state.hit.IsPlaying then
		state.hit:Stop(0)
	end
	state.hit:Play(0.05)
end

function BrainrotAnimation.unbind(model: Model)
	local state = states[model]
	if not state then
		return
	end
	if state.idle then
		state.idle:Stop(0)
		state.idle:Destroy()
	end
	if state.attack then
		state.attack:Stop(0)
		state.attack:Destroy()
	end
	if state.hit then
		state.hit:Stop(0)
		state.hit:Destroy()
	end
	states[model] = nil
end

return BrainrotAnimation
