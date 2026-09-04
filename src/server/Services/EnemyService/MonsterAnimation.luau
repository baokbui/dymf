--!strict
--[[
	MonsterAnimation
	Plays walk / attack AnimationTracks on authored monster models that keep a
	Humanoid.Animator or AnimationController + Motor6D rig. IDs come from the
	model (WalkAnimation / AttackAnimation / AnimSaves), the MonsterDefinition,
	or MonsterConfig defaults.

	walkAnimationId = "" explicitly disables walk (catalog R15 walks often look
	wrong on Toolbox rigs that snap along the grid).
	proceduralWalk: skip Toolbox AnimationIds (often permission-locked) and use
	AnimSaves KeyframeSequences or MonsterProceduralGait instead.
]]

local AnimationClipProvider = game:GetService("AnimationClipProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterConfig = require(ReplicatedStorage.Shared.Config.MonsterConfig)
local Types = require(ReplicatedStorage.Shared.Types)
local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)

local MonsterProceduralGait = require(script.Parent.MonsterProceduralGait)

local MonsterAnimation = {}

local log = Logger.new("MonsterAnimation")

type AnimState = {
	animator: Animator,
	walk: AnimationTrack?,
	attack: AnimationTrack?,
	ability: { [string]: AnimationTrack },
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

local function findAnimator(model: Model): Animator?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local underHumanoid = humanoid:FindFirstChildOfClass("Animator")
		if underHumanoid then
			return underHumanoid
		end
	end
	local controller = model:FindFirstChildOfClass("AnimationController")
	if controller then
		return controller:FindFirstChildOfClass("Animator")
	end
	return nil
end

-- Register a KeyframeSequence from AnimSaves as a temporary clip owned by this
-- experience (avoids Toolbox Animation permission errors).
local function registerAnimSavesWalkId(model: Model): string?
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

	-- Prefer a clip whose name suggests walk/move; otherwise first sequence.
	local chosen = sequences[1]
	for _, sequence in sequences do
		local lower = string.lower(sequence.Name)
		if string.find(lower, "walk", 1, true)
			or string.find(lower, "run", 1, true)
			or string.find(lower, "move", 1, true)
			or string.find(lower, "crawl", 1, true)
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

local function resolveAnimationId(
	model: Model,
	definition: Types.MonsterDefinition,
	kind: "Walk" | "Attack"
): string?
	-- Toolbox packs often ship AnimationIds the experience can't play. For
	-- proceduralWalk units, only try local AnimSaves (then gait fallback).
	if kind == "Walk" and definition.proceduralWalk then
		local savesId = registerAnimSavesWalkId(model)
		if savesId then
			return savesId
		end
		if definition.walkAnimationId ~= nil and definition.walkAnimationId ~= "" then
			return definition.walkAnimationId
		end
		return nil
	end

	if kind == "Walk" then
		local embedded = findChildAnimation(model, "WalkAnimation")
		if embedded then
			return embedded.AnimationId
		end
		-- Toolbox packs often ship a single Animation instance named "Animation".
		local packAnim = findChildAnimation(model, "Animation")
		if packAnim then
			return packAnim.AnimationId
		end
		local savesId = registerAnimSavesWalkId(model)
		if savesId then
			return savesId
		end
		-- Explicit field: "" disables walk; nil falls back to default catalog walk.
		if definition.walkAnimationId ~= nil then
			if definition.walkAnimationId == "" then
				return nil
			end
			return definition.walkAnimationId
		end
		return MonsterConfig.DEFAULT_WALK_ANIMATION_ID
	end

	-- Authored attack clips beat Toolbox AttackAnimation children (often
	-- permission-locked). "" disables; nil falls through to embedded / default.
	if definition.attackAnimationId ~= nil then
		if definition.attackAnimationId == "" then
			return nil
		end
		return definition.attackAnimationId
	end
	local embeddedAttack = findChildAnimation(model, "AttackAnimation")
	if embeddedAttack then
		return embeddedAttack.AnimationId
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

	local animator = findAnimator(model)
	local walkId = resolveAnimationId(model, definition, "Walk")
	local attackId = resolveAnimationId(model, definition, "Attack")
	local walkTrack = if animator
		then loadTrack(animator, walkId, true, Enum.AnimationPriority.Movement)
		else nil

	-- Procedural crawl only when the pack/authored walk track is missing.
	if definition.proceduralWalk and not walkTrack then
		MonsterProceduralGait.bind(model)
	end

	if not animator then
		return
	end

	local abilityTracks: { [string]: AnimationTrack } = {}
	local abilityIds = definition.abilityAnimationIds
	if abilityIds then
		for abilityId, animationId in abilityIds do
			local track = loadTrack(animator, animationId, false, Enum.AnimationPriority.Action2)
			if track then
				abilityTracks[abilityId] = track
			end
		end
	end

	local state: AnimState = {
		animator = animator,
		walk = walkTrack,
		-- One-shot club / melee swing; replayed each chew hit.
		attack = loadTrack(animator, attackId, false, Enum.AnimationPriority.Action),
		ability = abilityTracks,
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
	if attacking then
		MonsterProceduralGait.setActive(model, false)
	else
		MonsterProceduralGait.setActive(model, true)
	end
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

-- One-shot ability clip from definition.abilityAnimationIds (summon / steal).
function MonsterAnimation.playAbility(model: Model, abilityId: string)
	local state = states[model]
	if not state then
		return
	end
	local track = state.ability[abilityId]
	if not track then
		return
	end
	if state.walk and state.walk.IsPlaying then
		state.walk:Stop(0.1)
	end
	if state.attack and state.attack.IsPlaying then
		state.attack:Stop(0.05)
	end
	for _, other in state.ability do
		if other.IsPlaying then
			other:Stop(0.05)
		end
	end
	track:Play(0.05)
	state.mode = "Attack"
end

function MonsterAnimation.getAbilityLength(model: Model, abilityId: string): number?
	local state = states[model]
	if not state then
		return nil
	end
	local track = state.ability[abilityId]
	if not track then
		return nil
	end
	local length = track.Length
	if typeof(length) ~= "number" or length <= 0 then
		return nil
	end
	return length
end

function MonsterAnimation.resumeWalk(model: Model)
	local state = states[model]
	if not state then
		return
	end
	for _, track in state.ability do
		if track.IsPlaying then
			track:Stop(0.1)
		end
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

-- Pause locomotion while status-frozen / bubbled; resume walk when cleared.
-- Stops melee and ability tracks so a frozen boss cannot keep casting.
function MonsterAnimation.setLocomotionPaused(model: Model, paused: boolean, keepCombatAnims: boolean?)
	MonsterProceduralGait.setActive(model, not paused)
	local state = states[model]
	if not state then
		return
	end
	if paused then
		if not keepCombatAnims then
			if state.attack and state.attack.IsPlaying then
				state.attack:Stop(0.05)
			end
			for _, track in state.ability do
				if track.IsPlaying then
					track:Stop(0.05)
				end
			end
		end
		if keepCombatAnims and state.mode == "Attack" then
			if state.walk and state.walk.IsPlaying then
				state.walk:AdjustSpeed(0)
			end
			return
		end
		if state.walk then
			state.walk:AdjustSpeed(0)
			if not state.walk.IsPlaying then
				state.walk:Play(0.05)
				state.walk:AdjustSpeed(0)
			end
		end
		if not keepCombatAnims then
			state.mode = "Idle"
		end
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

local function destroyTrack(track: AnimationTrack?)
	if not track then
		return
	end
	pcall(function()
		track:Stop(0)
		track:Destroy()
	end)
end

function MonsterAnimation.unbind(model: Model)
	MonsterProceduralGait.unbind(model)
	local state = states[model]
	if not state then
		return
	end
	destroyTrack(state.walk)
	destroyTrack(state.attack)
	for _, track in state.ability do
		destroyTrack(track)
	end
	states[model] = nil
end

return MonsterAnimation
