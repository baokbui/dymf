--!strict
--[[
	MonsterDeath
	Server-replicated death pose: slow tip onto the ground (3 randomized styles),
	linger, then fade. EnemyService destroys the model after totalLifetime().

	Ground contact uses ModelUtil visual AABB (same as foot snap) so invisible
	HumanoidRootPart / hitboxes do not leave corpses floating.

	Before tipping, freezeCorpse anchors every part and clears Motor6D / Animator
	so walk/attack rigs do not fight the PivotTo tween. Arms are then tucked
	along the torso so they lie flat instead of sticking out in a T-pose.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local ModelUtil = require(ReplicatedStorage.Shared.Utilities.ModelUtil)

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

local function findPart(model: Model, names: { string }): BasePart?
	for _, name in names do
		local child = model:FindFirstChild(name, true)
		if child and child:IsA("BasePart") then
			return child
		end
	end
	return nil
end

local function findTorso(model: Model): BasePart?
	return findPart(model, { "Torso", "UpperTorso", "Body" })
end

-- Align `arm` so its longest axis follows `along`, centered at `center`.
local function setPartAlong(arm: BasePart, center: Vector3, along: Vector3, hintRight: Vector3)
	local dir = if along.Magnitude > 1e-4 then along.Unit else Vector3.yAxis
	local sx, sy, sz = arm.Size.X, arm.Size.Y, arm.Size.Z

	local right = hintRight
	if right:Cross(dir).Magnitude < 1e-4 then
		right = if math.abs(dir:Dot(Vector3.zAxis)) < 0.9 then Vector3.zAxis else Vector3.xAxis
	end

	if sy >= sx and sy >= sz then
		local up = dir
		local look = right:Cross(up)
		if look.Magnitude < 1e-4 then
			look = Vector3.zAxis
		else
			look = look.Unit
		end
		right = up:Cross(look).Unit
		arm.CFrame = CFrame.fromMatrix(center, right, up)
	elseif sx >= sz then
		local r = dir
		local up = hintRight:Cross(dir)
		if up.Magnitude < 1e-4 then
			up = Vector3.yAxis
		else
			up = up.Unit
		end
		local look = r:Cross(up).Unit
		up = look:Cross(r).Unit
		arm.CFrame = CFrame.fromMatrix(center, r, up)
	else
		arm.CFrame = CFrame.lookAt(center, center + dir, hintRight)
	end
end

--[[
	Tuck arms down along the torso (A-pose hang). Model:PivotTo later keeps this
	relative pose, so faceplants no longer leave a floating T-pose.
]]
local function foldArmsToSides(model: Model)
	local torso = findTorso(model)
	if not torso then
		return
	end

	local hang = -torso.CFrame.UpVector
	local torsoRight = torso.CFrame.RightVector

	local function tuck(arm: BasePart?, isLeft: boolean)
		if not arm then
			return
		end
		local length = math.max(arm.Size.X, arm.Size.Y, arm.Size.Z)
		local thickness = math.min(arm.Size.X, arm.Size.Y, arm.Size.Z)
		local side = if isLeft then -1 else 1
		local shoulder = torso.CFrame:PointToWorldSpace(Vector3.new(
			side * (torso.Size.X * 0.5 + thickness * 0.25),
			torso.Size.Y * 0.5 - math.min(0.2, torso.Size.Y * 0.15),
			0
		))
		local center = shoulder + hang * (length * 0.48)
		setPartAlong(arm, center, hang, torsoRight * side)
	end

	tuck(findPart(model, { "Left Arm", "LeftArm", "LeftUpperArm" }), true)
	tuck(findPart(model, { "Right Arm", "RightArm", "RightUpperArm" }), false)

	local function tuckChain(upperName: string, lowerName: string, handName: string, isLeft: boolean)
		local upper = findPart(model, { upperName })
		local lower = findPart(model, { lowerName })
		local hand = findPart(model, { handName })
		if not upper then
			return
		end
		local side = if isLeft then -1 else 1
		if lower then
			local upperLen = math.max(upper.Size.X, upper.Size.Y, upper.Size.Z)
			local lowerLen = math.max(lower.Size.X, lower.Size.Y, lower.Size.Z)
			local joint = upper.Position + hang * (upperLen * 0.5)
			local center = joint + hang * (lowerLen * 0.5)
			setPartAlong(lower, center, hang, torsoRight * side)
			if hand then
				local handLen = math.max(hand.Size.X, hand.Size.Y, hand.Size.Z)
				local wrist = center + hang * (lowerLen * 0.5)
				setPartAlong(hand, wrist + hang * (handLen * 0.5), hang, torsoRight * side)
			end
		end
	end

	tuckChain("LeftUpperArm", "LeftLowerArm", "LeftHand", true)
	tuckChain("RightUpperArm", "RightLowerArm", "RightHand", false)
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

--[[
	Lock the current pose into a rigid corpse before tipping. Authored monsters
	keep Motor6D limbs free for walk/attack; leaving them unanchored makes
	PivotTo fight the Animator and look like a standing glitch.
]]
local function freezeCorpse(model: Model)
	local controller = model:FindFirstChildOfClass("AnimationController")
	if controller then
		local animator = controller:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in animator:GetPlayingAnimationTracks() do
				track:Stop(0)
				track:Destroy()
			end
		end
		controller:Destroy()
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end

	-- Drop joints after anchoring so foldArms / PivotTo own every part.
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") or descendant:IsA("Weld") or descendant:IsA("WeldConstraint") then
			descendant:Destroy()
		end
	end
end

function MonsterDeath.play(model: Model)
	if not model.Parent then
		return
	end

	model:SetAttribute("Dying", true)

	-- Rigged Toolbox monsters keep Motor6D + Animator; freeze the pose so the
	-- tip tween isn't fighting unanchored limbs / residual animation tracks.
	freezeCorpse(model)

	-- Tuck T-pose arms before tipping so they stay flush with the body on landing.
	foldArmsToSides(model)

	local start = model:GetPivot()
	local groundY = visualMinY(model)
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

	local goal = snapVisualToGround(model, drifted, groundY)
	model:PivotTo(start)

	tweenPivot(model, start, goal, CombatConfig.DEATH_FALL_DURATION, function()
		if not model.Parent then
			return
		end
		local settled = snapVisualToGround(model, model:GetPivot(), groundY)
		model:PivotTo(settled)

		task.delay(CombatConfig.DEATH_CORPSE_LINGER, function()
			if not model.Parent then
				return
			end
			fadeOut(model, CombatConfig.DEATH_FADE_OUT_DURATION)
		end)
	end)
end

--[[
	Temporary "downed" pose reusing the death tip-over animation, but the rig
	is left intact (no freezeCorpse / arm tuck / fade) so the monster can
	stand back up and keep walking/attacking afterward. Returns the pre-fall
	CFrame so the caller can restore it later via `riseUp`.
]]
function MonsterDeath.playDowned(model: Model, fallDuration: number, onLanded: (() -> ())?): CFrame
	local start = model:GetPivot()
	if not model.Parent then
		return start
	end

	local groundY = visualMinY(model)
	local drift = math.max(visualHeight(model) * 0.2, 0.35)
	local rotated = start * CFrame.Angles(math.rad(90), 0, 0)
	local drifted = rotated + start.LookVector * drift
	local goal = snapVisualToGround(model, drifted, groundY)
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

return MonsterDeath
