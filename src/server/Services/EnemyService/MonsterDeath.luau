--!strict
--[[
	MonsterDeath
	Server-replicated death pose, then linger + fade. EnemyService destroys the
	model after totalLifetime().

	Styles (MonsterDefinition.deathStyle):
	- TipOver (default): slow tip onto the ground (3 randomized styles).

	Ground contact uses ModelUtil visual AABB (same as foot snap) so invisible
	HumanoidRootPart / hitboxes do not leave corpses floating.

	freezeCorpse bakes the live Motor6D pose into WeldConstraints, then
	stops Humanoid + AnimationController animators. Overlay welds stay so
	Toolbox meshes (goblin club / extra body chunks) do not detach. Do not
	teleport named arm parts — that stacked duplicate limbs on compact R6s.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local MonsterConfig = require(ReplicatedStorage.Shared.Config.MonsterConfig)
local ModelUtil = require(ReplicatedStorage.Shared.Utilities.ModelUtil)

local MonsterProceduralGait = require(script.Parent.MonsterProceduralGait)

local MonsterDeath = {}

-- Nestle slightly into the lawn so meshes don't leave a visible gap.
local GROUND_SINK = 0.08

local function totalLifetime(): number
	return CombatConfig.DEATH_FALL_DURATION
		+ CombatConfig.DEATH_CORPSE_LINGER
		+ CombatConfig.DEATH_FADE_OUT_DURATION
end

function MonsterDeath.totalLifetime(): number
	return totalLifetime()
end

local function visualMinY(model: Model): number
	local size, center = ModelUtil.getVisualSizeAndCenter(model)
	return center.Y - size.Y * 0.5
end

local function visualHeight(model: Model): number
	local size = ModelUtil.getVisualSizeAndCenter(model)
	return size.Y
end

local function tweenPivot(model: Model, start: CFrame, goal: CFrame, duration: number, onDone: (() -> ())?)
	local alpha = Instance.new("NumberValue")
	alpha.Value = 0
	local conn: RBXScriptConnection
	conn = alpha.Changed:Connect(function(value)
		if not model.Parent then
			return
		end
		model:PivotTo(start:Lerp(goal, value))
	end)

	local tween = TweenService:Create(
		alpha,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Value = 1 }
	)
	tween.Completed:Connect(function()
		conn:Disconnect()
		alpha:Destroy()
		if model.Parent then
			model:PivotTo(goal)
		end
		if onDone then
			onDone()
		end
	end)
	tween:Play()
end

local function fadeOut(model: Model, duration: number)
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			TweenService:Create(descendant, info, { Transparency = 1 }):Play()
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			TweenService:Create(descendant, info, { Transparency = 1 }):Play()
		end
	end
end

local function snapVisualToGround(model: Model, pivot: CFrame, groundY: number): CFrame
	model:PivotTo(pivot)
	local minY = visualMinY(model)
	return pivot + Vector3.new(0, groundY - GROUND_SINK - minY, 0)
end

-- Shared "tip over" pose picker (3 randomized styles: face-plant, left/right
-- side, back-flop) used by both the real death fall and the temporary
-- last-stand downed pose, so the latter looks like a normal fall.
local function randomTipGoal(model: Model, start: CFrame, groundY: number): CFrame
	local drift = math.max(visualHeight(model) * 0.2, 0.35)
	local style = math.random(1, 3)
	local rotated: CFrame
	local drifted: CFrame

	if style == 1 then
		rotated = start * CFrame.Angles(math.rad(90), 0, 0)
		drifted = rotated + start.LookVector * drift
	elseif style == 2 then
		local sideDeg = if math.random(1, 2) == 1 then 90 else -90
		rotated = start * CFrame.Angles(0, 0, math.rad(sideDeg))
		drifted = rotated + start.RightVector * (drift * 0.75 * math.sign(sideDeg))
	else
		rotated = start * CFrame.Angles(math.rad(-90), 0, 0)
		drifted = rotated - start.LookVector * drift
	end

	return snapVisualToGround(model, drifted, groundY)
end

local function stopAnimator(animator: Animator)
	for _, track in animator:GetPlayingAnimationTracks() do
		track:Stop(0)
		track:Destroy()
	end
end

--[[
	Lock the current pose into a rigid corpse before tipping. Bake Motor6Ds
	into WeldConstraints while the animator still holds the walk/attack pose,
	then tear down animators. Keep existing Welds so overlay meshes stay glued.
]]
local function freezeCorpse(model: Model)
	-- Stop crawl Heartbeat without snapping joints back to rest.
	MonsterProceduralGait.unbind(model, true)

	local motors: { Motor6D } = {}
	local boneTransforms: { [Bone]: CFrame } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			local motor = descendant :: Motor6D
			if motor.Part0 and motor.Part1 then
				table.insert(motors, motor)
			end
		elseif descendant:IsA("Bone") then
			local bone = descendant :: Bone
			boneTransforms[bone] = bone.Transform
		end
	end

	for _, motor in motors do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = motor.Part0
		weld.Part1 = motor.Part1
		weld.Parent = motor.Part1
	end

	-- Drop Motor6Ds before stopping tracks so Transform reset cannot T-pose
	-- the rig out from under the new welds.
	for _, motor in motors do
		if motor.Parent then
			motor:Destroy()
		end
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			stopAnimator(animator)
			animator:Destroy()
		end
	end

	local controller = model:FindFirstChildOfClass("AnimationController")
	if controller then
		local animator = controller:FindFirstChildOfClass("Animator")
		if animator then
			stopAnimator(animator)
		end
		controller:Destroy()
	end

	for bone, transform in boneTransforms do
		if bone.Parent then
			bone.Transform = transform
		end
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function scheduleLingerAndFade(model: Model)
	task.delay(CombatConfig.DEATH_CORPSE_LINGER, function()
		if not model.Parent then
			return
		end
		fadeOut(model, CombatConfig.DEATH_FADE_OUT_DURATION)
	end)
end

local function playTipOver(model: Model)
	freezeCorpse(model)

	local start = model:GetPivot()
	local groundY = visualMinY(model)
	local goal = randomTipGoal(model, start, groundY)
	model:PivotTo(start)

	tweenPivot(model, start, goal, CombatConfig.DEATH_FALL_DURATION, function()
		if not model.Parent then
			return
		end
		local settled = snapVisualToGround(model, model:GetPivot(), groundY)
		model:PivotTo(settled)
		scheduleLingerAndFade(model)
	end)
end

-- Fade in place (no tip-over). Graves reuse this so they dust away like a corpse.
function MonsterDeath.playFadeInPlace(model: Model)
	if not model.Parent then
		return
	end
	model:SetAttribute("Dying", true)
	freezeCorpse(model)
	scheduleLingerAndFade(model)
end

function MonsterDeath.play(model: Model, _deathStyle: string?)
	if not model.Parent then
		return
	end

	model:SetAttribute("Dying", true)

	playTipOver(model)
end

--[[
	Temporary "downed" pose reusing the same randomized tip-over fall as a
	regular death, but the rig is left intact (no freezeCorpse / fade) so
	the monster can stand back up and keep walking/attacking
	afterward. Returns the pre-fall CFrame so the caller can restore it later
	via `riseUp`.
]]
function MonsterDeath.playDowned(model: Model, fallDuration: number, onLanded: (() -> ())?): CFrame
	local start = model:GetPivot()
	if not model.Parent then
		return start
	end

	local groundY = visualMinY(model)
	local goal = randomTipGoal(model, start, groundY)
	model:PivotTo(start)

	tweenPivot(model, start, goal, fallDuration, onLanded)
	return start
end

-- Tween back up to `standCFrame` (the pre-fall pivot returned by `playDowned`).
function MonsterDeath.riseUp(model: Model, standCFrame: CFrame, riseDuration: number, onRisen: (() -> ())?)
	if not model.Parent then
		return
	end
	local current = model:GetPivot()
	tweenPivot(model, current, standCFrame, riseDuration, onRisen)
end

--[[
	Spawn entrance: bury the model below the visual AABB, then tween up to
	the current (standing) pivot. Caller must pause locomotion / grid snap
	for `duration` so the tween is not overwritten.
]]
function MonsterDeath.playRiseFromGround(model: Model, duration: number, onRisen: (() -> ())?, lead: number?)
	if not model.Parent then
		return
	end
	local stand = model:GetPivot()
	local bury = math.max(visualHeight(model) * MonsterConfig.SPAWN_RISE_BURY_RATIO, 2)
	local buried = stand - Vector3.new(0, bury, 0)
	model:PivotTo(buried)

	local function beginRise()
		if not model.Parent then
			if onRisen then
				onRisen()
			end
			return
		end
		tweenPivot(model, buried, stand, duration, onRisen)
	end

	local waitFor = if type(lead) == "number" then math.max(0, lead) else 0
	if waitFor > 0 then
		task.delay(waitFor, beginRise)
	else
		beginRise()
	end
end

return MonsterDeath
