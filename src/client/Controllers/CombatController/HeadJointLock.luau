--!strict
--[[
	HeadJointLock
	Client Animator replays server walk tracks locally, so the neck correction
	has to run here too or the replicated clip turns the head back.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Monsters = require(Shared.Monsters)
local HeadJoint = require(Shared.Utilities.HeadJoint)

local HeadJointLock = {}

local locked: { [Model]: HeadJoint.Joints } = {}
local heartbeat: RBXScriptConnection? = nil

local function stopHeartbeat()
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

local function ensureHeartbeat()
	if heartbeat then
		return
	end
	-- Client Animator replays the walk clip after Heartbeat. PreRender is the
	-- last write before the frame draws, so the neck stays on the rest pose.
	heartbeat = RunService.PreRender:Connect(function()
		local dead: { Model } = {}
		for model, joints in locked do
			if not model.Parent then
				table.insert(dead, model)
				continue
			end
			HeadJoint.retainRest(joints)
		end
		for _, model in dead do
			locked[model] = nil
		end
		if next(locked) == nil then
			stopHeartbeat()
		end
	end)
end

local function jointCount(joints: HeadJoint.Joints): number
	return #joints.motors + #joints.bones
end

-- True when this model is settled (locked, or it does not use a head lock).
local function tryTrack(model: Model): boolean
	local existing = locked[model]
	if existing and jointCount(existing) > 0 then
		return true
	end
	local monsterId = model:GetAttribute("MonsterId")
	if type(monsterId) ~= "string" then
		return false
	end
	local definition = Monsters.get(monsterId)
	if not definition or definition.lockHeadJoint ~= true then
		return true
	end
	local joints = HeadJoint.collect(model)
	if jointCount(joints) == 0 then
		return false
	end
	locked[model] = joints
	ensureHeartbeat()
	return true
end

function HeadJointLock.start()
	local tag = Constants.TAGS.Monster
	local function onAdded(instance: Instance)
		if not instance:IsA("Model") then
			return
		end
		local model = instance :: Model
		local attrConn: RBXScriptConnection? = nil
		local descConn: RBXScriptConnection? = nil
		local function stopWatching()
			if attrConn then
				attrConn:Disconnect()
				attrConn = nil
			end
			if descConn then
				descConn:Disconnect()
				descConn = nil
			end
		end
		local function attempt()
			if tryTrack(model) then
				stopWatching()
			end
		end
		attempt()
		if tryTrack(model) then
			return
		end
		attrConn = model:GetAttributeChangedSignal("MonsterId"):Connect(attempt)
		descConn = model.DescendantAdded:Connect(attempt)
		model.Destroying:Connect(stopWatching)
	end

	for _, instance in CollectionService:GetTagged(tag) do
		onAdded(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(onAdded)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		if instance:IsA("Model") then
			locked[instance] = nil
		end
	end)
end

return HeadJointLock
