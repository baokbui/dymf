--!strict
--[[
	MonsterDeath
	Server-replicated death pose, then linger + fade. EnemyService destroys the
	model after totalLifetime().

	Styles (MonsterDefinition.deathStyle):
	- TipOver (default): slow tip onto the ground (3 randomized styles).
	- SpiderFlat: leg parts splay horizontal and the body drops flat (no tip).

	Ground contact uses ModelUtil visual AABB (same as foot snap) so invisible
	HumanoidRootPart / hitboxes do not leave corpses floating.

	Before animating, freezeCorpse anchors every part and clears Motor6D /
	Animator so walk/attack rigs do not fight the tween. TipOver also tucks
	arms along the torso so they lie flat instead of sticking out in a T-pose.
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

-- Align a part so its longest axis follows `along`, centered at `center`.
local function cframeAlong(center: Vector3, along: Vector3, hintRight: Vector3, size: Vector3): CFrame
	local dir = if along.Magnitude > 1e-4 then along.Unit else Vector3.yAxis
	local sx, sy, sz = size.X, size.Y, size.Z

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
		return CFrame.fromMatrix(center, right, up)
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
		return CFrame.fromMatrix(center, r, up)
	end

	return CFrame.lookAt(center, center + dir, hintRight)
end

local function setPartAlong(arm: BasePart, center: Vector3, along: Vector3, hintRight: Vector3)
	arm.CFrame = cframeAlong(center, along, hintRight, arm.Size)
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

	-- Drop joints after anchoring so foldArms / PivotTo / part tweens own every part.
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") or descendant:IsA("Weld") or descendant:IsA("WeldConstraint") then
			descendant:Destroy()
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

local LEG_NAME_FRAGMENTS = { "leg", "limb", "femur", "tibia", "foot", "claw", "pedipalp", "arm" }
local BODY_SKIP_FRAGMENTS = {
	"root",
	"humanoidrootpart",
	"hrp",
	"torso",
	"upper torso",
	"lower torso",
	"waist",
	"spine",
	"neck",
	"head",
	"jaw",
	"eye",
	"fang",
	"abdomen",
	"cephalothorax",
	"body",
	"thorax",
	"pelvis",
}

-- Segment order from body → tip for Toolbox spiders (leftfronttop, …).
local SEGMENT_NAMES = { "top", "middle", "bottom" }

local function nameHasFragment(name: string, fragments: { string }): boolean
	local n = string.lower(name)
	for _, fragment in fragments do
		if string.find(n, fragment, 1, true) then
			return true
		end
	end
	return false
end

--[[
	QueenSpider / Spider Assets parts are named like `leftfrontmiddle` /
	`rightbackbottom` (no "leg" substring). Returns side, slot, segment.
]]
local function parseSpiderLegName(name: string): (string?, string?, string?)
	local side, slot, segment = string.match(
		string.lower(name),
		"^(left|right)(front|middle|back)(top|middle|bottom)$"
	)
	return side, slot, segment
end

local function isSpiderLegPart(part: BasePart, body: BasePart?, root: BasePart?): boolean
	if part == body or part == root then
		return false
	end
	if nameHasFragment(part.Name, BODY_SKIP_FRAGMENTS) then
		return false
	end
	local side = parseSpiderLegName(part.Name)
	if side ~= nil then
		return true
	end
	return nameHasFragment(part.Name, LEG_NAME_FRAGMENTS)
end

type LegChain = {
	key: string,
	parts: { BasePart }, -- body → tip (top, middle, bottom)
	outward: Vector3,
}

local function buildLegChains(legParts: { BasePart }, body: BasePart): { LegChain }
	local groups: { [string]: { [string]: BasePart } } = {}
	local orderKeys: { string } = {}

	for _, part in legParts do
		local side, slot, segment = parseSpiderLegName(part.Name)
		if side and slot and segment then
			local key = side .. slot
			if groups[key] == nil then
				groups[key] = {}
				table.insert(orderKeys, key)
			end
			groups[key][segment] = part
		end
	end

	local chains: { LegChain } = {}
	for _, key in orderKeys do
		local bySeg = groups[key]
		local parts: { BasePart } = {}
		for _, segName in SEGMENT_NAMES do
			local part = bySeg[segName]
			if part then
				table.insert(parts, part)
			end
		end
		if #parts == 0 then
			continue
		end

		-- Average standing offset in XZ for a stable outward ray.
		local sum = Vector3.zero
		for _, part in parts do
			local o = part.Position - body.Position
			sum += Vector3.new(o.X, 0, o.Z)
		end
		local outward: Vector3
		if sum.Magnitude > 0.08 then
			outward = sum.Unit
		elseif string.sub(key, 1, 4) == "left" then
			outward = -body.CFrame.RightVector
		else
			outward = body.CFrame.RightVector
		end

		table.insert(chains, {
			key = key,
			parts = parts,
			outward = outward,
		})
	end

	return chains
end

--[[
	Lay each leg chain flat on the lawn plane: segments stay in a line from the
	body outward (top → middle → bottom).
]]
local function flatPosesForChains(chains: { LegChain }, body: BasePart): { [BasePart]: CFrame }
	local poses: { [BasePart]: CFrame } = {}
	local bodyPos = body.Position
	local y = bodyPos.Y - body.Size.Y * 0.12

	for _, chain in chains do
		local cursor = Vector3.new(bodyPos.X, y, bodyPos.Z)
			+ chain.outward * math.max(body.Size.X, body.Size.Z) * 0.35
		for _, part in chain.parts do
			local length = math.max(part.Size.X, part.Size.Y, part.Size.Z)
			local center = cursor + chain.outward * (length * 0.5)
			poses[part] = cframeAlong(center, chain.outward, Vector3.yAxis, part.Size)
			cursor = center + chain.outward * (length * 0.5)
		end
	end

	return poses
end

--[[
	Fallback for non-Toolbox names: longest axis on the lawn plane, pointing
	outward from the body.
]]
local function flatLegCFrame(leg: BasePart, body: BasePart): CFrame
	local bodyPos = body.Position
	local offset = leg.Position - bodyPos
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude < 0.08 then
		flat = Vector3.new(leg.CFrame.LookVector.X, 0, leg.CFrame.LookVector.Z)
	end
	if flat.Magnitude < 0.08 then
		flat = body.CFrame.RightVector
	end
	flat = flat.Unit

	local length = math.max(leg.Size.X, leg.Size.Y, leg.Size.Z)
	local reach = math.max(Vector3.new(offset.X, 0, offset.Z).Magnitude, length * 0.45)
	local center = Vector3.new(
		bodyPos.X + flat.X * reach,
		bodyPos.Y - body.Size.Y * 0.12,
		bodyPos.Z + flat.Z * reach
	)
	return cframeAlong(center, flat, Vector3.yAxis, leg.Size)
end

--[[
	Skinned Toolbox spiders: fold Bone transforms toward the ground when there
	are few separate leg Parts to splay.
]]
local function collapseLegBones(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Bone") and (
			nameHasFragment(descendant.Name, LEG_NAME_FRAGMENTS)
			or parseSpiderLegName(descendant.Name) ~= nil
		) then
			if not nameHasFragment(descendant.Name, BODY_SKIP_FRAGMENTS) then
				descendant.Transform = CFrame.Angles(math.rad(75), 0, 0)
			end
		end
	end
end

local function tweenPartCFrames(
	parts: { BasePart },
	starts: { CFrame },
	goals: { CFrame },
	duration: number,
	onDone: (() -> ())?
)
	local alpha = Instance.new("NumberValue")
	alpha.Value = 0
	local conn: RBXScriptConnection
	conn = alpha.Changed:Connect(function(value)
		for index, part in parts do
			if part.Parent then
				part.CFrame = starts[index]:Lerp(goals[index], value)
			end
		end
	end)

	local tween = TweenService:Create(
		alpha,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Value = 1 }
	)
	tween.Completed:Connect(function()
		conn:Disconnect()
		alpha:Destroy()
		for index, part in parts do
			if part.Parent then
				part.CFrame = goals[index]
			end
		end
		if onDone then
			onDone()
		end
	end)
	tween:Play()
end

local function playTipOver(model: Model)
	freezeCorpse(model)
	foldArmsToSides(model)

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

--[[
	Queen-style collapse: legs fall flat outward, body stays upright and sinks
	onto the lawn (no randomized tip). Bone-only meshes get an upright settle;
	missing body falls back to tip-over.
]]
local function playSpiderFlat(model: Model)
	local groundY = visualMinY(model)
	local body = findPart(model, { "Torso", "UpperTorso", "Body", "Abdomen", "Cephalothorax", "Thorax" })
		or model.PrimaryPart
	local root = model.PrimaryPart

	local legParts: { BasePart } = {}
	if body then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") and isSpiderLegPart(descendant, body, root) then
				table.insert(legParts, descendant)
			end
		end
	end

	if not body then
		playTipOver(model)
		return
	end

	freezeCorpse(model)

	if #legParts == 0 then
		collapseLegBones(model)
		-- Soft upright settle when the mesh is bone-skinned with no leg Parts.
		local start = model:GetPivot()
		local drop = math.max(visualHeight(model) * 0.35, 0.6)
		local lowered = start - Vector3.new(0, drop, 0)
		local goal = snapVisualToGround(model, lowered, groundY)
		model:PivotTo(start)
		tweenPivot(model, start, goal, CombatConfig.DEATH_FALL_DURATION, function()
			if not model.Parent then
				return
			end
			local settled = snapVisualToGround(model, model:GetPivot(), groundY)
			model:PivotTo(settled)
			scheduleLingerAndFade(model)
		end)
		return
	end

	collapseLegBones(model)

	local chains = buildLegChains(legParts, body)
	local flatPoses = flatPosesForChains(chains, body)
	-- Any leftover leg parts (non-Toolbox names) get the simple outward flatten.
	for _, leg in legParts do
		if flatPoses[leg] == nil then
			flatPoses[leg] = flatLegCFrame(leg, body)
		end
	end

	local starts: { CFrame } = {}
	local allParts: { BasePart } = {}

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(allParts, descendant)
			table.insert(starts, descendant.CFrame)
		end
	end

	-- Apply flat legs temporarily to measure how far to sink onto the lawn.
	for part, cf in flatPoses do
		part.CFrame = cf
	end
	local minYAfter = visualMinY(model)
	local dropY = minYAfter - groundY + GROUND_SINK
	local drop = Vector3.new(0, -dropY, 0)

	local goals: { CFrame } = {}
	for index, part in allParts do
		local target = flatPoses[part] or starts[index]
		table.insert(goals, target + drop)
	end

	for index, part in allParts do
		part.CFrame = starts[index]
	end

	tweenPartCFrames(allParts, starts, goals, CombatConfig.DEATH_FALL_DURATION, function()
		if not model.Parent then
			return
		end
		local settled = snapVisualToGround(model, model:GetPivot(), groundY)
		model:PivotTo(settled)
		scheduleLingerAndFade(model)
	end)
end

function MonsterDeath.play(model: Model, deathStyle: string?)
	if not model.Parent then
		return
	end

	model:SetAttribute("Dying", true)

	if deathStyle == "SpiderFlat" then
		playSpiderFlat(model)
		return
	end

	playTipOver(model)
end

--[[
	Temporary "downed" pose reusing the same randomized tip-over fall as a
	regular death, but the rig is left intact (no freezeCorpse / arm tuck /
	fade) so the monster can stand back up and keep walking/attacking
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

return MonsterDeath
