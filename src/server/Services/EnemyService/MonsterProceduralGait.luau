--!strict
--[[
	MonsterProceduralGait
	Server-side crawl gait for Toolbox spider-style rigs that have Motor6D /
	Bone / Weld legs but no matching uploaded Animation. 	Discovers leg joints by name, then any Motor6D / Weld / WeldConstraint,
	then synthesizes Motor6Ds onto unnamed `Part` meshes (Toolbox Scorpion).

	Used when MonsterDefinition.proceduralWalk is true (Spider, Scorpion). Does not
	require catalog animation IDs — works on whatever joints the Assets model has.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterConfig = require(ReplicatedStorage.Shared.Config.MonsterConfig)
local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)

local MonsterProceduralGait = {}

local log = Logger.new("MonsterProceduralGait")

type JointKind = "Motor6D" | "Bone" | "Weld"

type LegJoint = {
	kind: JointKind,
	motor: Motor6D?,
	bone: Bone?,
	weld: Weld?,
	rest: CFrame,
	phase: number,
}

type GaitState = {
	joints: { LegJoint },
	conn: RBXScriptConnection?,
	elapsed: number,
	active: boolean,
	modelName: string,
}

local states: { [Model]: GaitState } = {}
local loggedEmpty: { [string]: boolean } = {}

local SKIP_NAME_FRAGMENT = {
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
	"abdomen",
	"cephalothorax",
	"body",
	"thorax",
	"pelvis",
}

local function lower(name: string): string
	return string.lower(name)
end

local function nameLooksLikeSkip(name: string): boolean
	local n = lower(name)
	for _, fragment in SKIP_NAME_FRAGMENT do
		if string.find(n, fragment, 1, true) then
			return true
		end
	end
	return false
end

local function nameLooksLikeLeg(name: string): boolean
	local n = lower(name)
	-- QueenSpider / Spider Assets: leftfronttop, rightbackbottom, …
	if string.match(n, "^(left|right)(front|middle|back)(top|middle|bottom)$") then
		return true
	end
	return string.find(n, "leg", 1, true) ~= nil
		or string.find(n, "limb", 1, true) ~= nil
		or string.find(n, "femur", 1, true) ~= nil
		or string.find(n, "tibia", 1, true) ~= nil
		or string.find(n, "foot", 1, true) ~= nil
		or string.find(n, "claw", 1, true) ~= nil
		or string.find(n, "pincer", 1, true) ~= nil
		or string.find(n, "chela", 1, true) ~= nil
		or string.find(n, "pedipalp", 1, true) ~= nil
		or string.find(n, "tail", 1, true) ~= nil
		or string.find(n, "stinger", 1, true) ~= nil
		or string.find(n, "arm", 1, true) ~= nil -- some spider kits label limbs as Arms
end

local function sidePhase(name: string, index: number, part1: BasePart?, part0: BasePart?): number
	local n = lower(name)
	if string.find(n, "left", 1, true) or string.find(n, "l_", 1, true) or string.find(n, "_l", 1, true) then
		return 0
	end
	if string.find(n, "right", 1, true) or string.find(n, "r_", 1, true) or string.find(n, "_r", 1, true) then
		return math.pi
	end
	if part1 and part0 then
		local localOffset = part0.CFrame:PointToObjectSpace(part1.Position)
		return if localOffset.Z >= 0 then 0 else math.pi
	end
	return if index % 2 == 0 then 0 else math.pi
end

-- Toolbox kits often use WeldConstraint (no C0). Convert so the gait can drive Transform.
local function convertWeldConstraints(model: Model)
	local constraints: { WeldConstraint } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("WeldConstraint") then
			table.insert(constraints, descendant)
		end
	end
	for _, constraint in constraints do
		local p0 = constraint.Part0
		local p1 = constraint.Part1
		if p0 and p1 then
			local motor = Instance.new("Motor6D")
			motor.Name = "GaitJoint"
			motor.Part0 = p0
			motor.Part1 = p1
			motor.C0 = p0.CFrame:ToObjectSpace(p1.CFrame)
			motor.C1 = CFrame.new()
			motor.Parent = p0
			p1.Anchored = false
			p1.Massless = true
			p1.CanCollide = false
		end
		constraint:Destroy()
	end
end

-- Unnamed MeshPart piles (every child called "Part"): Motor6D from the root to each other part.
local function ensureSyntheticMotors(model: Model)
	local root = model.PrimaryPart
	if not root then
		return
	end

	local alreadyDriven: { [BasePart]: boolean } = { [root] = true }
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			local part1 = (descendant :: Motor6D).Part1
			if part1 then
				alreadyDriven[part1] = true
			end
		end
	end

	for _, descendant in model:GetDescendants() do
		if not descendant:IsA("BasePart") then
			continue
		end
		local part = descendant :: BasePart
		if alreadyDriven[part] or part.Transparency >= 0.95 then
			continue
		end
		if nameLooksLikeSkip(part.Name) and lower(part.Name) ~= "part" then
			continue
		end

		local motor = Instance.new("Motor6D")
		motor.Name = "GaitJoint"
		motor.Part0 = root
		motor.Part1 = part
		motor.C0 = root.CFrame:ToObjectSpace(part.CFrame)
		motor.C1 = CFrame.new()
		motor.Parent = root
		part.Anchored = false
		part.Massless = true
		part.CanCollide = false
		alreadyDriven[part] = true
	end
end

local function collectJoints(model: Model): { LegJoint }
	local named: { LegJoint } = {}
	local fallback: { LegJoint } = {}
	local index = 0

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			local motor = descendant :: Motor6D
			if nameLooksLikeSkip(motor.Name) then
				continue
			end
			index += 1
			local joint: LegJoint = {
				kind = "Motor6D",
				motor = motor,
				rest = motor.Transform,
				phase = sidePhase(motor.Name, index, motor.Part1, motor.Part0)
					+ (index % 4) * (math.pi * 0.25),
			}
			local label = if motor.Part1 then motor.Part1.Name else motor.Name
			if nameLooksLikeLeg(motor.Name) or nameLooksLikeLeg(label) then
				table.insert(named, joint)
			else
				table.insert(fallback, joint)
			end
		elseif descendant:IsA("Bone") then
			local bone = descendant :: Bone
			if nameLooksLikeSkip(bone.Name) or not nameLooksLikeLeg(bone.Name) then
				continue
			end
			index += 1
			table.insert(named, {
				kind = "Bone",
				bone = bone,
				rest = bone.Transform,
				phase = sidePhase(bone.Name, index) + (index % 4) * (math.pi * 0.25),
			})
		elseif descendant:IsA("Weld") then
			local weld = descendant :: Weld
			local part1 = weld.Part1
			local label = if part1 then part1.Name else weld.Name
			if nameLooksLikeSkip(label) then
				continue
			end
			index += 1
			local joint: LegJoint = {
				kind = "Weld",
				weld = weld,
				rest = weld.C0,
				phase = sidePhase(label, index, part1, weld.Part0) + (index % 4) * (math.pi * 0.25),
			}
			if nameLooksLikeLeg(label) then
				table.insert(named, joint)
			else
				table.insert(fallback, joint)
			end
		end
	end

	if #named > 0 then
		return named
	end
	return fallback
end

local function applyDelta(joint: LegJoint, delta: CFrame)
	if joint.kind == "Motor6D" and joint.motor then
		joint.motor.Transform = joint.rest * delta
	elseif joint.kind == "Bone" and joint.bone then
		joint.bone.Transform = joint.rest * delta
	elseif joint.kind == "Weld" and joint.weld then
		joint.weld.C0 = joint.rest * delta
	end
end

local function resetJoints(state: GaitState)
	for _, joint in state.joints do
		if joint.kind == "Motor6D" and joint.motor then
			joint.motor.Transform = joint.rest
		elseif joint.kind == "Bone" and joint.bone then
			joint.bone.Transform = joint.rest
		elseif joint.kind == "Weld" and joint.weld then
			joint.weld.C0 = joint.rest
		end
	end
end

local function stopConn(state: GaitState)
	if state.conn then
		state.conn:Disconnect()
		state.conn = nil
	end
end

local function ensureHeartbeat(model: Model, state: GaitState)
	if state.conn then
		return
	end
	state.conn = RunService.Heartbeat:Connect(function(dt)
		if not model.Parent then
			MonsterProceduralGait.unbind(model)
			return
		end
		if not state.active or #state.joints == 0 then
			return
		end

		state.elapsed += dt
		local hz = MonsterConfig.PROCEDURAL_WALK_HZ
		local pitch = MonsterConfig.PROCEDURAL_WALK_PITCH
		local roll = MonsterConfig.PROCEDURAL_WALK_ROLL
		local t = state.elapsed * hz * math.pi * 2

		for _, joint in state.joints do
			local wave = math.sin(t + joint.phase)
			local lift = math.cos(t + joint.phase)
			local delta = CFrame.Angles(wave * pitch, 0, lift * roll)
			applyDelta(joint, delta)
		end
	end)
end

function MonsterProceduralGait.bind(model: Model)
	MonsterProceduralGait.unbind(model)

	convertWeldConstraints(model)
	ensureSyntheticMotors(model)
	local joints = collectJoints(model)
	if #joints == 0 then
		local key = model.Name
		if not loggedEmpty[key] then
			loggedEmpty[key] = true
			log:warn(
				"proceduralWalk: no movable parts on",
				key,
				"— model needs BaseParts besides PrimaryPart"
			)
		end
		return
	end

	local state: GaitState = {
		joints = joints,
		conn = nil,
		elapsed = 0,
		active = true,
		modelName = model.Name,
	}
	states[model] = state
	ensureHeartbeat(model, state)
	log:info(string.format("procedural walk bound (%d joints) on %s", #joints, model.Name))
end

function MonsterProceduralGait.setActive(model: Model, active: boolean)
	local state = states[model]
	if not state then
		return
	end
	state.active = active
	if not active then
		resetJoints(state)
	else
		ensureHeartbeat(model, state)
	end
end

function MonsterProceduralGait.unbind(model: Model)
	local state = states[model]
	if not state then
		return
	end
	stopConn(state)
	resetJoints(state)
	states[model] = nil
end

return MonsterProceduralGait
