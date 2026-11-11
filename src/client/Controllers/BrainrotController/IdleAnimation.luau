--!strict
-- Viewer-local idle motion, gated by High quality. Combat clips stay server-owned.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.BrainrotConfig)
local Brainrots = require(Shared.Brainrots)
local Constants = require(Shared.Constants)
local Quality = require(Shared.Utilities.VfxLoad)
local Idle = {}

type Joint = { motor: Motor6D, base: CFrame, written: CFrame?, arm: boolean }
type State = {
	model: Model, joints: { Joint }, phase: number, base: CFrame, written: CFrame?,
	animator: Animator?, track: AnimationTrack?, attemptedId: string?, connections: { RBXScriptConnection },
}
local states: { [Model]: State } = {}
local connection: RBXScriptConnection? = nil
local started = false

local function restorePose(state: State)
	for _, joint in state.joints do
		if joint.motor.Parent and joint.written and joint.motor.C0 == joint.written then joint.motor.C0 = joint.base end
		joint.written = nil
	end
	if state.written and state.model.Parent and state.model:GetPivot() == state.written then state.model:PivotTo(state.base) end
	state.written = nil
end

local function restore(state: State)
	restorePose(state)
	if state.track and state.track.IsPlaying then state.track:Stop(0) end
end

local function updateTrack(state: State)
	local id = state.model:GetAttribute("IdleAnimationId")
	if type(id) ~= "string" or id == "" then
		if state.track then state.track:Stop(0); state.track:Destroy(); state.track = nil end
		state.attemptedId = nil
		return
	end
	if state.attemptedId == id then return end
	if not state.animator then state.animator = state.model:FindFirstChildWhichIsA("Animator", true) end
	if not state.animator then return end
	restore(state)
	state.attemptedId = id
	if state.track then state.track:Stop(0); state.track:Destroy(); state.track = nil end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, track = pcall(function() return (state.animator :: Animator):LoadAnimation(animation) end)
	animation:Destroy()
	if ok then
		state.track = track
		track.Priority, track.Looped = Enum.AnimationPriority.Idle, true
	end
end

local function busy(state: State, now: number): boolean
	local untilTime = state.model:GetAttribute("IdleBusyUntil")
	if type(untilTime) == "number" and untilTime > now then return true end
	if state.animator then
		for _, track in state.animator:GetPlayingAnimationTracks() do
			if track.Priority.Value >= Enum.AnimationPriority.Action.Value and track.IsPlaying then return true end
		end
	end
	return false
end

local function step()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local now = workspace:GetServerTimeNow()
	for model, state in states do
		if not model.Parent then continue end
		local pivot = model:GetPivot()
		if (pivot.Position - camera.CFrame.Position).Magnitude > Config.IDLE_MAX_DISTANCE or busy(state, now) then
			restore(state)
			continue
		end
		updateTrack(state)
		if state.track then
			if not state.track.IsPlaying then state.track:Play(0.15) end
			-- A returned track may still be loading or unavailable.
			if state.track.Length > 0 then
				restorePose(state)
				continue
			end
		end
		local cycle = now * math.pi * 2 / Config.IDLE_PERIOD + state.phase
		local sway = math.sin(cycle)
		for _, joint in state.joints do
			local motor = joint.motor
			if not motor.Parent or not motor.Part0 or not motor.Part1 or motor.Part1.Anchored then continue end
			if not joint.written or motor.C0 ~= joint.written then joint.base = motor.C0 end
			local angle = math.rad(if joint.arm then Config.IDLE_ARM_DEGREES else Config.IDLE_SWAY_DEGREES)
			joint.written = joint.base * CFrame.Angles(sway * angle * 0.5, 0, sway * angle)
			motor.C0 = joint.written
		end
		-- Keep gentle body motion visible on anchored and custom rigs too.
		if not state.written or pivot ~= state.written then state.base = pivot end
		model:PivotTo(state.base * CFrame.new(0, (1 - math.cos(cycle)) * Config.IDLE_BOB_STUDS / 2, 0)
			* CFrame.Angles(0, 0, sway * math.rad(Config.IDLE_SWAY_DEGREES)))
		-- Read back the pivot so rounding is not mistaken for an external move.
		state.written = model:GetPivot()
	end
end

local function refreshQuality()
	if connection then connection:Disconnect(); connection = nil end
	for _, state in states do restore(state) end
	if Quality.isHighQuality() and next(states) then connection = RunService.PreSimulation:Connect(step) end
end

local function remove(model: Instance)
	if not model:IsA("Model") then return end
	local state = states[model]
	if not state then return end
	restore(state)
	for _, signal in state.connections do signal:Disconnect() end
	if state.track then state.track:Destroy() end
	states[model] = nil
	if not next(states) and connection then connection:Disconnect(); connection = nil end
end

local function add(instance: Instance)
	if not instance:IsA("Model") or states[instance] then return end
	-- One-shot units (line bomb, freeze cast, …) act once and despawn; no idle.
	local brainrotId = instance:GetAttribute("BrainrotId")
	local definition = if type(brainrotId) == "string" then Brainrots.get(brainrotId) else nil
	if definition and definition.noIdle then return end
	local state: State = { model = instance, joints = {}, phase = Random.new():NextNumber(0, math.pi * 2),
		base = instance:GetPivot(), animator = instance:FindFirstChildWhichIsA("Animator", true), connections = {} }
	local function scanJoint(item: Instance)
		if item:IsA("Animator") then state.animator = item end
		if not item:IsA("Motor6D") then return end
		local name = string.lower(if item.Part1 then item.Part1.Name else item.Name)
		table.insert(state.joints, { motor = item, base = item.C0,
			arm = string.find(name, "arm", 1, true) ~= nil or string.find(name, "hand", 1, true) ~= nil })
	end
	for _, item in instance:GetDescendants() do scanJoint(item) end
	table.insert(state.connections, instance.DescendantAdded:Connect(scanJoint))
	table.insert(state.connections, instance.Destroying:Connect(function() remove(instance) end))
	states[instance] = state
	if Quality.isHighQuality() and not connection then connection = RunService.PreSimulation:Connect(step) end
end

function Idle.start()
	if started then return end
	started = true
	CollectionService:GetInstanceAddedSignal(Constants.TAGS.Brainrot):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Constants.TAGS.Brainrot):Connect(remove)
	for _, model in CollectionService:GetTagged(Constants.TAGS.Brainrot) do add(model) end
	Quality.onChanged(refreshQuality)
end

return Idle
