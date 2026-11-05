--!strict
-- Real GUI instances; no gameplay remotes or player saves are accessed.
return function(Wheel: any, Panel: any): number
	local checks = 0
	local function check(value: any, message: string)
		checks += 1
		assert(value, message)
	end
	local host = Instance.new("Frame")
	local wheel = Wheel.build(host)
	local rewards = {
		{ id = "Small", brains = 1, odds = 0.6 },
		{ id = "Medium", brains = 2, odds = 0.3 },
		{ id = "Large", brains = 5, odds = 0.1 },
	}
	wheel.configure(rewards)
	local colors: { [string]: number } = {}
	for _, child in wheel.rotor:GetChildren() do
		if child:IsA("Frame") then
			-- Resolve the actual center and rotated bottom endpoint. All strips
			-- must meet the wheel hub even though GUI rotation ignores anchors.
			local size = Vector2.new(child.Size.X.Offset, child.Size.Y.Offset)
			local diameter = wheel.rotor.Parent.Size.X.Offset
			local position = Vector2.new((child.Position.X.Scale - 0.5) * diameter + child.Position.X.Offset,
				(child.Position.Y.Scale - 0.5) * diameter + child.Position.Y.Offset)
			local center = position + Vector2.new((0.5 - child.AnchorPoint.X) * size.X, (0.5 - child.AnchorPoint.Y) * size.Y)
			local angle = math.rad(child.Rotation)
			local innerEnd = center + Vector2.new(-math.sin(angle), math.cos(angle)) * size.Y / 2
			check(innerEnd.Magnitude < 0.001, "each colored strip must meet the wheel center")
			local key = tostring(child.BackgroundColor3)
			colors[key] = (colors[key] or 0) + 1
		end
	end
	local counts = {}
	for _, count in colors do table.insert(counts, count) end
	table.sort(counts)
	check(#counts == 3 and counts[1] == 18 and counts[2] == 54 and counts[3] == 108, "sector areas must match reward odds")
	for index, expected in { 252, 90, 18 } do
		check(math.abs(wheel.angleFor(rewards[index].id) - expected) < 0.001, "pointer must land on reward center")
	end
	local before = #wheel.rotor:GetDescendants()
	wheel.configure(rewards)
	check(#wheel.rotor:GetDescendants() == before, "state pushes must not duplicate wheel geometry")
	local view = Panel.build(host, function() error("fixture must not send spin requests") end)
	local function state(day: number, spent: boolean, eligible: boolean): any
		return { dayKey = day, spent = spent, eligible = eligible, minimumDay = 3, rewards = rewards,
			outcome = if spent then { rewardId = "Large", brains = 5 } else nil }
	end
	view.refresh(state(20000, false, false))
	check(not view.frame.SpinButton.Active, "locked spin must be disabled")
	view.refresh(state(20000, false, true))
	check(view.frame.SpinButton.Active, "eligible spin must be enabled")
	view.refresh(state(20000, true, true))
	check(not view.frame.SpinButton.Active, "claimed spin must be disabled")
	check(math.abs(view.frame.Wheel.Rotor.Rotation - 18) < 0.001, "reconnect must show committed outcome")
	view.refresh(state(19999, false, true))
	check(not view.frame.SpinButton.Active, "stale state cannot reopen a spent spin")
	view.refresh(state(20001, false, true))
	check(view.frame.SpinButton.Active, "next UTC date must unlock a new spin")
	host:Destroy()
	return checks
end
