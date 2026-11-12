--!strict
return function(source: string): string
	local played, characterAdded = Instance.new("BindableEvent"), Instance.new("BindableEvent")
	local speed, heldSpeed, extraSpeed = 1.5, 0, 0.75
	local function track(get, set) return { IsPlaying = true, AdjustSpeed = function(_, v) set(v) end, Speed = get() } end
	local moving = track(function() return speed end, function(v) speed = v end)
	local held = track(function() return heldSpeed end, function(v) heldSpeed = v end)
	local extra = track(function() return extraSpeed end, function(v) extraSpeed = v end)
	local attributes = { OwnerUserId = 1, IdleBusyUntil = 10 }
	local unit = {
		IsA = function() return true end,
		GetAttribute = function(_, key) return attributes[key] end,
		SetAttribute = function(_, key, value) attributes[key] = value end,
		FindFirstChildWhichIsA = function() return { GetPlayingAnimationTracks = function() return { moving, held } end, AnimationPlayed = played.Event } end,
	}
	local realGame = game
	local chunk = assert(loadstring(source))
	setfenv(chunk, setmetatable({ game = { GetService = function(_, name)
		if name == "CollectionService" then return { GetTagged = function(_, tag) return if tag == "Brainrot" then { unit } else {} end } end
		return realGame:GetService(name)
	end } }, { __index = getfenv() }))
	local scene = chunk()
	local character = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name, root.Anchored, root.Parent = "HumanoidRootPart", false, character
	local player = { UserId = 1, Character = character, CharacterAdded = characterAdded.Event }
	scene.pause(player)
	assert(speed == 0 and heldSpeed == 0 and root.Anchored and attributes.DayPaused)
	played:Fire(extra); task.wait()
	assert(extraSpeed == 0, "New animation escaped pause")
	scene.resume(player, 20)
	assert(speed == 1.5 and heldSpeed == 0 and extraSpeed == 0.75, "Original or held animation speed was lost")
	assert(not root.Anchored and attributes.DayPaused == nil and attributes.IdleBusyUntil == 30)
	character:Destroy(); played:Destroy(); characterAdded:Destroy()
	return "Unit pose/held-speed capture, new tracks, character freeze and resume cleanup passed"
end
