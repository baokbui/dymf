--!strict
return function(source: string, models: { Model }): string
	local added, removed = Instance.new("BindableEvent"), Instance.new("BindableEvent")
	local quality = "Full"
	local change
	local realGame, realRequire = game, require
	local chunk = assert(loadstring(source))
	setfenv(chunk, setmetatable({
		game = { ReplicatedStorage = game.ReplicatedStorage, GetService = function(_, name)
			if name == "CollectionService" then return {
				GetTagged = function() return models end,
				GetInstanceAddedSignal = function() return added.Event end,
				GetInstanceRemovedSignal = function() return removed.Event end,
			} end
			return realGame:GetService(name)
		end },
		require = function(module)
			if module.Name == "VfxLoad" then return {
				quality = function() return quality end,
				onChanged = function(callback) change = callback end,
			} end
			return realRequire(module)
		end,
	}, { __index = getfenv() }))
	chunk().start()
	for _, level in { "Full", "Reduced", "Minimal" } do
		quality = level; change()
		for _, model in models do
			local emitter = model:FindFirstChild("ShardSparkles", true) :: ParticleEmitter
			assert(emitter)
			local full = emitter:GetAttribute("FullRate") :: number
			local expected = if level == "Full" then full elseif level == "Reduced" then full * 0.4 else 0
			assert(math.abs(emitter.Rate - expected) < 0.001, "Shard effects ignored graphics quality")
		end
	end
	for _, model in models do removed:Fire(model) end
	added:Destroy(); removed:Destroy()
	return "Boss/major particles follow High, Low and Off and release their watchers"
end
