--!strict
--[[
	HeadJoint
	Some authored walk clips yaw the neck a quarter-turn off the mesh rest
	pose (Werewolf). The body still plays. Head and neck joints stay on the
	rest pose the model was saved with.
]]

local HeadJoint = {}

export type Joints = {
	motors: { Motor6D },
	bones: { Bone },
}

local REST = CFrame.identity

local function isHeadJoint(name: string): boolean
	local lowerName = string.lower(name)
	return string.find(lowerName, "neck", 1, true) ~= nil
		or string.find(lowerName, "head", 1, true) ~= nil
end

function HeadJoint.collect(model: Model): Joints
	local motors: { Motor6D } = {}
	local bones: { Bone } = {}
	local seen: { [Motor6D]: boolean } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			local motor = descendant :: Motor6D
			local part1 = motor.Part1
			local partName = if part1 then part1.Name else ""
			if (isHeadJoint(motor.Name) or isHeadJoint(partName)) and not seen[motor] then
				seen[motor] = true
				table.insert(motors, motor)
			end
		elseif descendant:IsA("Bone") and isHeadJoint(descendant.Name) then
			table.insert(bones, descendant :: Bone)
		end
	end
	return {
		motors = motors,
		bones = bones,
	}
end

function HeadJoint.retainRest(joints: Joints)
	for _, motor in joints.motors do
		if motor.Parent then
			motor.Transform = REST
		end
	end
	for _, bone in joints.bones do
		if bone.Parent then
			bone.Transform = REST
		end
	end
end

return HeadJoint
