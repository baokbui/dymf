--!strict
-- Injected HouseService fixture: no real profile or DataStore access.
return function(source: string): string
	local shared = game.ReplicatedStorage.Shared
	local player = { UserId = 919191 }
	local plot, house, folder = Instance.new("Model"), Instance.new("Model"), Instance.new("Folder")
	house.Name, house.Parent, folder.Name, folder.Parent = "House", plot, "Residents", house
	local snapshot = { farmMonsters = {}, upgrades = { FarmCapacity = 5 }, collectedMonsters = {} }
	for index = 1, 6 do table.insert(snapshot.farmMonsters, { uid = "pet" .. index, monsterId = "Zombie", tier = "Medium", onFarm = index <= 5 }) end
	local request, result
	local clock, mutations, saves, residents = 0, 0, 0, 0
	local paused, locked, hydrated = false, false, true
	local dependencies = {
		Remotes = { getEvent = function() return {
			OnServerEvent = { Connect = function(_, handler) request = handler end },
			FireClient = function(_, _, payload) result = payload end,
		} end },
		BattleClock = { isPaused = function() return paused end },
		ProgressService = {
			isHydrated = function() return hydrated end,
			getSaveSlice = function() return snapshot end,
			getCollectedMonsters = function() return {} end,
			setFarmPets = function(_, monsters) mutations += 1; snapshot.farmMonsters = monsters end,
			addBrains = function() error("Pet toggle awarded an extra income tick") end,
		},
		SaveService = { isProgressionLocked = function() return locked end, saveNow = function() saves += 1 end },
		PlotService = { getPlotModel = function() return plot end },
		Resident = { spawn = function() residents += 1; return function() residents -= 1 end end },
	}
	local chunk = assert(loadstring(source))
	local realGame, realRequire = game, require
	setfenv(chunk, setmetatable({
		script = game.ServerScriptService.Server.Services.HouseService,
		os = { clock = function() return clock end },
		game = { GetService = function(_, name)
			if name == "Players" then return { PlayerRemoving = { Connect = function() end } } end
			return realGame:GetService(name)
		end },
		require = function(module) return dependencies[module.Name] or realRequire(module) end,
	}, { __index = getfenv() }))
	local ok, failure = xpcall(function()
		local service = chunk(); service.init()
		local function send(uid, placed) clock += 1; request(player, uid, placed) end
		send("pet6", true); assert(not result.success and result.reason == "FarmFull" and mutations == 0)
		send("pet2", false); assert(result.success and mutations == 1 and saves == 1 and residents == 4)
		send("pet6", true); assert(result.success and mutations == 2 and saves == 2 and residents == 5)
		send("foreign", true); assert(result.reason == "NotOwned" and mutations == 2)
		paused = true; send("pet1", false); assert(result.reason == "DayPaused" and mutations == 2)
		paused, locked = false, true; send("pet1", false); assert(result.reason == "Busy" and mutations == 2)
		locked, hydrated = false, false; send("pet1", false); assert(result.reason == "Busy" and mutations == 2)
		hydrated = true
		request(player, "pet1", "yes"); assert(mutations == 2, "Malformed intent mutated equipment")
	end, debug.traceback)
	plot:Destroy()
	assert(ok, failure)
	return "Server pet ownership/capacity, placement/removal, pause/save locks, hydration and no extra income passed"
end
