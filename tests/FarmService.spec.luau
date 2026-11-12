--!strict
return function(source: string, Farm: any, Config: any): string
	local player = { UserId = 1001 }
	local clock, drops, credits, cleanups, writes = 0, 0, 0, 0, 0
	local callbacks = {}
	local paused = false
	local pickup
	local dependencies = {
		BattleClock = { now = function() return clock end, isPaused = function() return paused end },
		FarmProgressionConfig = Config, FarmProgression = Farm,
		Monsters = require(game.ReplicatedStorage.Shared.Monsters),
		PlotService = { getPlotModel = function() return {} end },
		LevelService = { isLevelActive = function() return true end },
		ProgressService = { addMonsterShards = function(_, shards) credits += shards.PharaohMummy or 0 end },
		SaveService = { claimRetentionReward = function() writes += 1; return true end },
		SkyShard = { spawn = function(_, _, id, collect)
			assert(id == "PharaohMummy")
			drops += 1
			pickup = collect
			return function() cleanups += 1 end
		end },
		Remotes = { getEvent = function(name)
			return { OnServerEvent = { Connect = function(_, callback) callbacks[name] = callback end }, FireClient = function() end }
		end },
	}
	local realRequire, realGame = require, game
	local chunk = assert(loadstring(source))
	setfenv(chunk, setmetatable({
		require = function(module)
			local name = if typeof(module) == "Instance" then module.Name else module
			return dependencies[name] or realRequire(module)
		end,
		script = { Parent = setmetatable({}, { __index = function(_, key) return key end }), SkyShard = "SkyShard" },
		game = { GetService = function(_, name)
			if name == "Players" then return { PlayerRemoving = { Connect = function(_, callback) callbacks.remove = callback end } } end
			return realGame:GetService(name)
		end },
		os = { clock = function() return clock end },
		Random = { new = function() return { NextNumber = function() return 0 end, NextInteger = function() return 1 end } end },
		task = { spawn = function(callback) callbacks.loop = callback end, wait = function()
			clock += 61
			if clock > 610 then error("FixtureComplete") end
		end },
	}, { __index = getfenv() }))
	local service = chunk()
	service.start()
	service.begin(player, 1)
	local ok, err = pcall(callbacks.loop)
	assert(not ok and string.find(tostring(err), "FixtureComplete"), tostring(err))
	assert(drops == 1, "sky drop limit was exceeded")
	pickup()
	assert(credits == 1)
	local oldPickup = pickup
	service.begin(player, 2)
	oldPickup()
	assert(credits == 1 and cleanups == 1, "expired attempt pickup was granted")
	service.breach(player)
	local stars, shards = service.resolve(player, 2, 4)
	assert(stars == 2)
	local total = 0
	for _, amount in shards do total += amount end
	assert(total == Config.STAR_SHARD_ROLLS[2])
	local handler = callbacks.CombineMonsterShards
	paused = true
	handler(player, "Zombie", "test-operation-paused")
	callbacks.FuseFarmMonsters(player, { "a", "b", "c" }, "test-paused-fusion")
	assert(writes == 0, "Paused requests reached the durable writer")
	paused = false
	handler(player, "NotAMonster", "test-operation-1")
	assert(writes == 0)
	handler(player, "Zombie", "test-operation-1")
	handler(player, "Zombie", "test-operation-1")
	assert(writes == 1, "combine request limiter failed")
	callbacks.remove(player)
	return "Farm attempt stars, rare major sky drop, drop cap, stale pickup rejection and combine validation passed"
end
