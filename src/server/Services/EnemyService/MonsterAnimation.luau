--!strict
--[[
	MonsterAnimation
	Plays walk / attack AnimationTracks on authored monster models that keep an
	AnimationController + Motor6D rig. IDs come from the model (Animation
	children), the MonsterDefinition, or MonsterConfig defaults.

	walkAnimationId = "" explicitly disables walk (catalog R15 walks often look
	wrong on Toolbox rigs that snap along the grid).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterConfig = require(ReplicatedStorage.Shared.Config.MonsterConfig)
local Types = require(ReplicatedStorage.Shared.Types)
local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)

local MonsterAnimation = {}

local log = Logger.new("MonsterAnimation")

type AnimState = {
	animator: Animator,
	walk: AnimationTrack?,
	attack: AnimationTrack?,
	mode: "Walk" | "Attack" | "Idle",
}

local states: { [Model]: AnimState } = {}

local function findChildAnimation(model: Model, name: string): Animation?
	local child = model:FindFirstChild(name, true)
	if child and child:IsA("Animation") and child.AnimationId ~= "" then
		return child
	end
	return nil
end

local function resolveAnimationId(
	model: Model,
	definition: Types.MonsterDefinition,
	kind: "Walk" | "Attack"
): string?
	local childName = if kind == "Walk" then "WalkAnimation" else "AttackAnimation"
	local embedded = findChildAnimation(model, childName)
	if embedded then
		return embedded.AnimationId
	end

	if kind == "Walk" then
		-- Explicit field: "" disables walk; nil falls back to default catalog walk.
		if definition.walkAnimationId ~= nil then
			if definition.walkAnimationId == "" then
				return nil
			end
			return definition.walkAnimationId
		end
		return MonsterConfig.DEFAULT_WALK_ANIMATION_ID
	end

	if definition.attackAnimationId ~= nil then
		if definition.attackAnimationId == "" then
			return nil
		end
		return definition.attackAnimationId
	end
	return MonsterConfig.DEFAULT_ATTACK_ANIMATION_ID
end

local function loadTrack(animator: Animator, animationId: string?, looped: boolean, priority: Enum.AnimationPriority): AnimationTrack?
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
		log:warn("failed to load animation", animationId, trackOrErr)
		return nil
	end
	local track = trackOrErr :: AnimationTrack
	track.Looped = looped
	track.Priority = priority
	return track
end

function MonsterAnimation.bind(model: Model, definition: Types.MonsterDefinition)
	MonsterAnimation.unbind(model)

	local controller = model:FindFirstChildOfClass("AnimationController")
	local animator = controller and controller:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end

	local walkId = resolveAnimationId(model, definition, "Walk")
	local attackId = resolveAnimationId(model, definition, "Attack")

	local state: AnimState = {
		animator = animator,
		walk = loadTrack(animator, walkId, true, Enum.AnimationPriority.Movement),
		-- One-shot club / melee swing; replayed each chew hit.
		attack = loadTrack(animator, attackId, false, Enum.AnimationPriority.Action),
		mode = "Idle",
	}
	states[model] = state

	if state.walk then
		state.walk:Play(0.2)
		state.mode = "Walk"
	else
		state.mode = "Idle"
	end
end

function MonsterAnimation.setAttacking(model: Model, attacking: boolean)
	local state = states[model]
	if not state then
		return
	end

	if attacking then
		if state.mode == "Attack" then
			return
		end
		if state.walk and state.walk.IsPlaying then
			state.walk:Stop(0.15)
		end
		state.mode = "Attack"
	else
		if state.mode == "Walk" or state.mode == "Idle" then
			if not state.walk then
				state.mode = "Idle"
			end
			return
		end
		if state.attack and state.attack.IsPlaying then
			state.attack:Stop(0.1)
		end
		if state.walk then
			state.walk:Play(0.15)
			state.walk:AdjustSpeed(1)
			state.mode = "Walk"
		else
			state.mode = "Idle"
		end
	end
end

-- Fire a single melee swing (club / bite). Safe to call every attackInterval tick.
function MonsterAnimation.playMelee(model: Model)
	local state = states[model]
	if not state or not state.attack then
		return
	end
	if state.walk and state.walk.IsPlaying then
		state.walk:Stop(0.1)
	end
	if state.attack.IsPlaying then
		state.attack:Stop(0)
	end
	state.attack:Play(0.05)
	state.mode = "Attack"
end

-- Pause locomotion while status-frozen / bubbled; resume walk when cleared.
function MonsterAnimation.setLocomotionPaused(model: Model, paused: boolean)
	local state = states[model]
	if not state then
		return
	end
	if paused then
		if state.attack and state.attack.IsPlaying then
			state.attack:Stop(0.05)
		end
		if state.walk then
			state.walk:AdjustSpeed(0)
			if not state.walk.IsPlaying then
				state.walk:Play(0.05)
				state.walk:AdjustSpeed(0)
			end
		end
		state.mode = "Idle"
	else
		if state.mode == "Attack" then
			return
		end
		if state.walk then
			state.walk:AdjustSpeed(1)
			if not state.walk.IsPlaying then
				state.walk:Play(0.15)
			end
			state.mode = "Walk"
		else
			state.mode = "Idle"
		end
	end
end

function MonsterAnimation.unbind(model: Model)
	local state = states[model]
	if not state then
		return
	end
	if state.walk then
		state.walk:Stop(0)
		state.walk:Destroy()
	end
	if state.attack then
		state.attack:Stop(0)
		state.attack:Destroy()
	end
	states[model] = nil
end

return MonsterAnimation
