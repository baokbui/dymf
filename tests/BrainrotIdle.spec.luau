--!strict
-- Local cosmetic motion with fake quality/frame signals, never live units.
return function(source: string, config: any?, registry: any?): string
	local frame = Instance.new("BindableEvent")
	local added, removed = Instance.new("BindableEvent"), Instance.new("BindableEvent")
	local model = Instance.new("Model")
	model.Name = "BrainrotIdleFixture"
	local root = Instance.new("Part")
	root.Anchored, root.Name, root.Parent = true, "Root", model
	local arm = root:Clone()
	arm.Name, arm.Parent = "Left Arm", model
	local joint = Instance.new("Motor6D")
	joint.Part0, joint.Part1, joint.Parent = root, arm, root
	local base = joint.C0
	model.PrimaryPart = root
	model:PivotTo(workspace.CurrentCamera.CFrame + workspace.CurrentCamera.CFrame.LookVector * 15)
	model.Parent = workspace
	local restingRig = model:GetPivot()
	local restingRoot = root.CFrame
	local brainrots = registry or require(game.ReplicatedStorage.Shared.Brainrots)
	local excluded = {}
	local tagged = { model }
	for id, definition in brainrots.getAll() do
		if not definition.noIdle then continue end
		local oneShot = model:Clone()
		oneShot:SetAttribute("BrainrotId", id)
		oneShot.Parent = workspace
		table.insert(excluded, { model = oneShot, pose = oneShot:GetPivot() })
		table.insert(tagged, oneShot)
	end
	local high = true
	local changed
	local realGame, realRequire = game, require
	local chunk = assert(loadstring(source))
	setfenv(chunk, setmetatable({
		game = { GetService = function(_, name)
			if name == "RunService" then return { PreSimulation = frame.Event } end
			if name == "CollectionService" then return {
				GetTagged = function() return tagged end,
				GetInstanceAddedSignal = function() return added.Event end,
				GetInstanceRemovedSignal = function() return removed.Event end,
			} end
			return realGame:GetService(name)
		end },
		require = function(module)
			if module.Name == "BrainrotConfig" and config then return config end
			if module.Name == "Brainrots" then return brainrots end
			if module.Name == "VfxLoad" then return {
				isHighQuality = function() return high end,
				onChanged = function(callback) changed = callback end,
			} end
			return realRequire(module)
		end,
	}, { __index = getfenv() }))
	local function assertExcluded()
		for _, entry in excluded do
			assert(entry.model:GetPivot() == entry.pose, "noIdle model moved: " .. entry.model:GetAttribute("BrainrotId"))
			assert(entry.model.Root:FindFirstChildWhichIsA("Motor6D").C0 == base, "noIdle joint moved")
		end
	end
	local idle = chunk()
	idle.start()
	frame:Fire(); task.wait()
	assert(root.CFrame ~= restingRoot, "High quality idle did not visibly move anchored rig")
	assertExcluded()
	high = false; changed(); frame:Fire(); task.wait()
	assert(joint.C0 == base, "Low/Off did not restore original pose")
	assert(model:GetPivot():FuzzyEq(restingRig), "Low/Off did not restore body pose")
	high = true; changed()
	model:SetAttribute("IdleBusyUntil", workspace:GetServerTimeNow() + 10)
	frame:Fire(); task.wait()
	assert(joint.C0 == base, "Idle moved during an attack")
	model:SetAttribute("IdleBusyUntil", nil)
	frame:Fire(); task.wait()
	assert(root.CFrame ~= restingRoot, "Idle did not visibly resume after attack")
	assertExcluded()
	removed:Fire(model); task.wait()
	assert(joint.C0 == base, "Removal did not restore original pose")
	local fallback = Instance.new("Model")
	fallback.Name = "BrainrotIdleFixture"
	local body = Instance.new("Part")
	body.Anchored, body.Parent = true, fallback
	fallback.PrimaryPart = body
	fallback:PivotTo(workspace.CurrentCamera.CFrame + workspace.CurrentCamera.CFrame.LookVector * 12)
	fallback.Parent = workspace
	local resting = fallback:GetPivot()
	added:Fire(fallback); task.wait(); frame:Fire(); task.wait()
	assert(fallback:GetPivot() ~= resting, "Unrigged idle did not move")
	high = false; changed(); task.wait()
	assert(fallback:GetPivot():FuzzyEq(resting), "Unrigged idle did not restore on Low/Off")
	removed:Fire(fallback); task.wait()
	assertExcluded()
	for _, entry in excluded do removed:Fire(entry.model) end
	high = true; changed()
	for _, entry in excluded do added:Fire(entry.model) end
	frame:Fire(); task.wait()
	assertExcluded()
	for _, entry in excluded do removed:Fire(entry.model); entry.model:Destroy() end
	fallback:Destroy()
	model:Destroy(); frame:Destroy(); added:Destroy(); removed:Destroy()
	return "High-only motion, quality/attack restore, initial and newly tagged noIdle exclusions, cleanup passed"
end
