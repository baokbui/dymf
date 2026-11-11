--!strict
-- Isolated service fixture. No players, DataStores, or real profile mutations.
return function(source: string, progressConfig: any?, farmRules: any?, fusionRules: any?): string
	local realGame, realRequire = game, require
	local player = { UserId = 90001 }
	local house = Instance.new("Model")
	house.Name = "House"
	local residents = Instance.new("Folder")
	residents.Name, residents.Parent = "Residents", house
	local plot = Instance.new("Model")
	house.Parent = plot
	local count, credited, clears = 0, 0, 0
	local collection = { "Zombie" }
	local snapshot = { statistics = {}, upgrades = {} }
	local ready, locked = true, false
	local elapsed = 0
	local callbacks = {}
	local progress = {
		isHydrated = function() return ready end,
		getSaveSlice = function() return snapshot end,
		getCollectedMonsters = function() return table.clone(collection) end,
		collectMonster = function(_, id)
			if not table.find(collection, id) then table.insert(collection, id) end
		end,
		incrementStat = function(_, key) snapshot.statistics[key] = 1 end,
		addBrains = function(_, amount) credited += amount end,
	}
	local shared = realGame.ReplicatedStorage.Shared
	local config = realRequire(shared.Config.SanctuaryConfig)
	local incomePeriod = 1 / (farmRules or realRequire(shared.Utilities.FarmProgression)).rate("Zombie")
	local dependencies = {
		SanctuaryConfig = config,
		FarmProgression = farmRules or realRequire(shared.Utilities.FarmProgression),
		MonsterFusion = fusionRules or realRequire(shared.Utilities.MonsterFusion),
		ProgressConfig = progressConfig or realRequire(shared.Config.ProgressConfig),
		HouseConfig = { DEPTH = 85, WIDTH = 74 },
		Levels = { getByNumber = function() return { groups = { { monsterId = "Zombie" } } } end },
		Monsters = { get = function(id) return { id = id } end },
		ProgressService = progress,
		PlotService = { getPlotModel = function() return plot end },
		SaveService = { isProgressionLocked = function() return locked end },
		LevelService = { getSaveProgress = function() return 2, 2 end },
		Resident = { spawn = function()
			count += 1
			return function() count -= 1; clears += 1 end
		end },
	}
	local chunk = assert(loadstring(source))
	local environment = setmetatable({
		script = { Parent = setmetatable({}, { __index = function(_, key) return key end }), Resident = "Resident" },
		require = function(module)
			local name = if typeof(module) == "Instance" then module.Name else module
			return dependencies[name] or realRequire(module)
		end,
		game = { GetService = function(_, name)
			if name == "Players" then
				return { PlayerRemoving = { Connect = function(_, callback) callbacks.remove = callback end }, GetPlayers = function() return { player } end }
			end
			return realGame:GetService(name)
		end },
		workspace = { WaitForChild = function() return { GetChildren = function() return {} end } end },
		task = {
			spawn = function(callback) callbacks.loop = callback end,
			wait = function(seconds)
				elapsed += seconds
				if elapsed > incomePeriod then error("FixtureComplete") end
			end,
		},
	}, { __index = getfenv() })
	setfenv(chunk, environment)
	local service = chunk()
	service.start()
	local ok, err = pcall(callbacks.loop)
	assert(not ok and string.find(tostring(err), "FixtureComplete"), tostring(err))
	assert(#collection == 1 and collection[1] == "Zombie", "prior campaign clear was not restored")
	assert(count == 1, "resident duplicated across updates")
	assert(credited == 1, "income interval did not pay exactly one brain")
	locked = true
	elapsed = 0
	pcall(callbacks.loop)
	assert(credited == 1, "income was granted during a save lock")
	locked = false
	collection = { "Zombie", "Goblin", "Vampire", "Werewolf", "Spider", "Skeleton", "SmallMummy" }
	elapsed = 0
	pcall(callbacks.loop)
	assert(count == 5, "default resident cap was exceeded")
	snapshot.upgrades.FarmCapacity = 6
	elapsed = 0
	pcall(callbacks.loop)
	assert(count == 6, "purchased capacity did not add a resident")
	collection = {}
	elapsed = 0
	pcall(callbacks.loop)
	assert(count == 0, "reset left residents behind")
	local before = credited
	elapsed = 0
	pcall(callbacks.loop)
	assert(credited == before, "empty sanctuary earned income")
	callbacks.remove(player)
	assert(count == 0 and clears > 0, "resident cleanup failed")
	plot:Destroy()
	return "HouseService resident reuse, species income, capacity and cleanup passed"
end
