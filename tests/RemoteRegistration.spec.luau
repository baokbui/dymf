--!strict
-- Exercises the production bootstrap registry against an isolated container.
return function(source: string): string
	local container = Instance.new("Folder")
	container.Parent = game.ServerStorage
	local realGame = game
	local chunk = assert(loadstring(source))
	setfenv(chunk, setmetatable({ game = { GetService = function(_, name)
		if name == "ReplicatedStorage" then return container end
		if name == "RunService" then return { IsServer = function() return true end } end
		return realGame:GetService(name)
	end } }, { __index = getfenv() }))
	local remotes = chunk()
	remotes.initServer()
	for _, name in { "CombineMonsterShards", "MonsterCombineResult", "FuseFarmMonsters", "MonsterFusionResult" } do
		local remote = remotes.getEvent(name)
		assert(remote:IsA("RemoteEvent"), name .. " must be a RemoteEvent")
		assert(remote.OnServerEvent and remote.OnClientEvent)
	end
	assert(remotes.getFunction("RequestState"):IsA("RemoteFunction"))
	container:Destroy()
	return "Bootstrap registers shard events and state function with correct classes"
end
