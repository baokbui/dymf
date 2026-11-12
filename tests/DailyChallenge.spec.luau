--!strict
-- Isolated LevelService lifecycle. No live plot, player, or DataStore access.
return function(sources: any): string
	local shared = game.ReplicatedStorage.Shared
	local scriptRoot = game.ServerScriptService.Server.Services.LevelService
	local player = { UserId = 1, Name = "ChallengeFixture", Parent = true }
	local plot = Instance.new("Model")
	plot:SetAttribute("OwnerUserId", player.UserId)
	local clock = 0
	local balance, spawns, payouts = 47, 0, 0
	local lawn = { { brainrotId = "TungTungSahur", health = 100, position = { row = 1, column = 1 } } }
	local originalLawn = lawn
	local remotes, breach, loop = {}, nil, nil
	local removePlayer
	local function noop() end
	local players = {
		GetPlayers = function() return { player } end,
		GetPlayerByUserId = function() return player end,
		PlayerAdded = { Connect = noop },
		PlayerRemoving = { Connect = function(_, callback) removePlayer = callback end },
	}
	local fakeGame = setmetatable({}, { __index = { GetService = function(_, service)
		return if service == "Players" then players else game:GetService(service)
	end } })
	local mockTask = {
		wait = coroutine.yield,
		defer = function(callback) callback() end,
		spawn = function(callback)
			local thread = coroutine.create(callback)
			assert(coroutine.resume(thread))
			if coroutine.status(thread) == "suspended" then loop = thread end
		end,
	}
	local mocks = {
		Logger = { new = function() return { info = noop, warn = noop } end },
		BrainrotService = {
			getSavePlacements = function() return lawn end,
			clearPlot = function() lawn = {} end,
			restorePlacements = function(_, saved) lawn = saved end,
			clearPlantCooldowns = noop,
			resumeDayTimers = noop,
		},
		CoinService = {
			getBalance = function() return balance end,
			setBalance = function(_, coins) balance = coins end,
			clearPlot = noop,
		},
		EnemyService = {
			setHouseBreachHandler = function(handler) breach = handler end,
			setKillHandler = noop, clearPlot = noop,
			spawn = function() spawns += 1; return "Spawned" end,
			countOnPlot = function() return 0 end,
		},
		GraveService = { clearPlot = noop, spawnForDay = noop, notifyWavesComplete = noop, hasPending = function() return false end },
		PlotService = { getPlotModel = function() return plot end },
		ProgressService = { isHydrated = function() return true end },
		CombatService = { clearPlot = noop },
		MagnetService = { resumeDayTimers = noop, resumeCooldown = function() error("Challenge resumed campaign magnet") end },
		PauseScene = { pause = noop, resume = noop },
		LineBomb = { clearProjectiles = noop },
		DamageMeterService = { reset = noop },
		Analytics = { log = noop },
		SaveService = {
			isProgressionLocked = function() return false end,
			claimRetentionReward = function(_, kind)
				assert(kind == "Challenge")
				payouts += 1
				return true, nil, 8
			end,
		},
		Remotes = {
			getEvent = function(name)
				return { FireClient = noop, OnServerEvent = { Connect = function(_, handler) remotes[name] = handler end } }
			end,
			getFunction = function() return {} end,
		},
	}
	local function loadModule(source, module)
		local chunk = assert(loadstring(source))
		setfenv(chunk, setmetatable({
			game = fakeGame, script = module, task = mockTask,
			os = { clock = function() return clock end, time = function() return 20000 * 86400 end },
			require = function(target) return mocks[target.Name] or require(target) end,
		}, { __index = getfenv() }))
		return chunk()
	end
	local ok, result = xpcall(function()
		if sources.Clock then mocks.BattleClock = loadModule(sources.Clock, shared.Utilities.BattleClock) end
		mocks.LevelRun = loadModule(sources.Run, scriptRoot.LevelRun)
		mocks.ChallengeRun = loadModule(sources.Challenge, scriptRoot.ChallengeRun)
		local level = loadModule(sources.Level, scriptRoot)
		level.init()
		level.applySaveProgress(player, 4, 4, 3)
		level.start()
		local restoredDay, restoredHighest, restoredHearts = level.getSaveProgress(player)
		assert(restoredDay == 4 and restoredHighest == 4 and restoredHearts == 3,
			"LevelService.start overwrote a save hydrated before startup")
		local function tick(seconds: number?)
			clock += seconds or 100
			local resumed, failure = coroutine.resume(loop)
			assert(resumed, failure)
		end
		level.applySaveProgress(player, 9, 9, 4, true)
		level.applyWeatherRulesForPlayer(player)
		remotes.StartDailyChallenge(player)
		assert(not level.getClientState(player).challengeActive, "locked player entered")
		level.applySaveProgress(player, 9, 10, 4, true)
		remotes.StartDailyChallenge(player)
		remotes.StartDailyChallenge(player)
		assert(#lawn == 0 and balance == require(shared.Config.DailyChallengeConfig).STARTING_COINS)
		assert(level.getClientState(player).playerHealth == 3)
		local day, highest, health = level.getSaveProgress(player)
		assert(day == 9 and highest == 10 and health == 4 and level.isHiddenDayPending(player))
		tick()
		assert(level.getClientState(player).elapsedSeconds == 0, "active timer must start at zero")
		local spawnedBefore = spawns
		remotes.PauseDay(player)
		assert(level.getClientState(player).phase == "Paused" and not level.isLevelActive(player))
		assert(plot:GetAttribute("DayPaused") == true)
		tick(20)
		assert(spawns == spawnedBefore and level.getClientState(player).elapsedSeconds == 0, "Paused day advanced")
		remotes.ResumeDay(player)
		assert(level.getClientState(player).phase == "Resuming")
		tick(2)
		remotes.ResumeDay(player)
		assert(level.getClientState(player).phase == "Resuming", "Resume countdown finished early")
		tick(1)
		assert(level.isLevelActive(player) and level.getClientState(player).elapsedSeconds == 0)
		assert(plot:GetAttribute("DayPaused") == nil)

		tick()
		assert(level.getClientState(player).elapsedSeconds == 100, "active timer must follow server elapsed time")
		for _ = 1, 3 do breach(plot, 3) end
		assert(lawn == originalLawn and balance == 47 and payouts == 0)
		assert(level.getClientState(player).challengeAvailable and level.getClientState(player).hiddenDay)
		assert(level.getClientState(player).elapsedSeconds == nil, "completed timer leaked into Preparation")
		remotes.StartDailyChallenge(player)
		spawns = 0
		for _ = 1, 20 do tick() end
		assert(spawns == 12 and payouts == 1)
		assert(lawn == originalLawn and balance == 47 and level.isHiddenDayPending(player))
		assert(level.getClientState(player).challengeResult == "Challenge cleared · +8 brains")
		-- A paused numbered attempt serializes the pre-attempt hearts and reloads
		-- the same selected day in Preparation, never its temporary pause/run.
		mocks.MagnetService.resumeCooldown = noop
		mocks.ProgressService.checkpointBrainrotXp = noop
		mocks.FarmProgressionService = { begin = noop, breach = noop }
		mocks.RetentionService = { beginRun = noop, recordEvent = noop }
		level.applySaveProgress(player, 9, 10, 4, false)
		level.applyWeatherRulesForPlayer(player)
		remotes.StartLevel(player); tick()
		breach(plot, 1)
		remotes.PauseDay(player)
		local savedDay, savedHighest, savedHearts = level.getSaveProgress(player)
		assert(savedDay == 9 and savedHighest == 10 and savedHearts == 4, "Paused attempt leaked damaged hearts into saved restart")
		removePlayer(player)
		level.applySaveProgress(player, savedDay, savedHighest, savedHearts, false)
		local rejoined = level.getClientState(player)
		assert(rejoined.phase == "Preparation" and rejoined.levelNumber == 9 and not rejoined.dayPaused and rejoined.elapsedSeconds == nil,
			"Paused leave/rejoin did not restart the selected day")
		return "Daily Challenge entry, isolation, pause, three-second resume, paused leave/rejoin, loss, retry, all waves, clear, and restoration passed"
	end, debug.traceback)
	plot:Destroy()
	assert(ok, result)
	return result
end
