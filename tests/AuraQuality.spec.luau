--!strict
-- Real cosmetic instances; mocked client settings/camera and bounded scheduler.
return function(source: string, Aura: any): string
	local root = Instance.new("Folder")
	local models = {}
	for index = 1, 35 do
		local model, body = Instance.new("Model"), Instance.new("Part")
		body.Name, body.Anchored, body.Position, body.Parent = "Body", true, Vector3.new(index, 3, 0), model
		model.PrimaryPart = body; model.Parent = root
		model:SetAttribute("FixtureOwner", true)
		Aura.create(model, body, Color3.fromRGB(155, 55, 230), 1, false, "Epic")
		table.insert(models, model)
	end
	local added, removed, changed = Instance.new("BindableEvent"), Instance.new("BindableEvent"), Instance.new("BindableEvent")
	local quality, showOthers = "Full", true
	local onQuality, onOthers, loop
	local settings = { SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel10, GetPropertyChangedSignal = function() return changed.Event end }
	local queue = {}
	local realGame, realRequire = game, require
	local config = realRequire(game.ReplicatedStorage.Shared.Config.EvolutionVfxConfig)
	local testConfig, burstLookups = table.clone(config), 0
	testConfig.BURST = setmetatable({}, { __index = function(_, name) burstLookups += 1; return config.BURST[name] end })
	local chunk = assert(loadstring(source))
	setfenv(chunk, setmetatable({
		script = game.StarterPlayer.StarterPlayerScripts.Client.Controllers.BrainrotController.AuraQuality,
		workspace = { CurrentCamera = { CFrame = CFrame.new() } },
		UserSettings = function() return { GetService = function() return settings end } end,
		game = { GetService = function(_, name)
			if name == "CollectionService" then return { GetTagged = function() return models end,
				GetInstanceAddedSignal = function() return added.Event end, GetInstanceRemovedSignal = function() return removed.Event end } end
			return realGame:GetService(name)
		end },
		task = { defer = function(callback) table.insert(queue, callback) end,
			wait = coroutine.yield, spawn = function(callback) loop = coroutine.create(callback); assert(coroutine.resume(loop)) end },
		require = function(module)
			if module.Name == "EvolutionVfxConfig" then return testConfig end
			if module.Name == "VfxLoad" then return { quality = function() return quality end, showsOtherPlots = function() return showOthers end,
				onChanged = function(callback) onQuality = callback end, onOtherPlotsChanged = function(callback) onOthers = callback end } end
			if module.Name == "PlotUtil" then return { isOnLocalPlot = function(model) return model:GetAttribute("FixtureOwner") == true end } end
			return realRequire(module)
		end,
	}, { __index = getfenv() }))
	local function flush() local pending = queue; queue = {}; for _, callback in pending do callback() end end
	local function counts()
		local visible, detailed = 0, 0
		for _, model in models do
			if model.AuraVfx.FlameVolume.CoreFlames.Rate > 0 then visible += 1 end
			if model.AuraVfx.FlameVolume.OuterFlames.Rate > 0 then detailed += 1 end
		end
		return visible, detailed
	end
	local ok, failure = xpcall(function()
		local controller = chunk(); controller.start(); controller.start(); flush()
		local visible, detailed = counts(); assert(visible == 28 and detailed == 8, "High crowd budget failed")
		local rateChanges = 0
		local connection = models[1].AuraVfx.FlameVolume.OuterFlames:GetPropertyChangedSignal("Rate"):Connect(function() rateChanges += 1 end)
		assert(coroutine.resume(loop)); assert(rateChanges == 0, "Budget refresh cleared/restarted an unchanged aura")
		connection:Disconnect()
		assert(burstLookups == 0, "Join/start replayed an evolution burst")
		for _, model in models do model.AuraVfx:SetAttribute("BurstId", 1); model:SetAttribute("EvolutionBurst", 1) end
		flush(); assert(burstLookups == 20, "Evolution bursts exceeded the four-unit High budget")
		assert(coroutine.resume(loop)); assert(burstLookups == 20, "Evolution burst replayed on refresh")
		models[2].AuraVfx:SetAttribute("BurstId", 1); models[2]:SetAttribute("EvolutionBurst", 2)
		flush(); assert(burstLookups == 20, "Burst used stale replicated aura")
		models[2].AuraVfx:SetAttribute("BurstId", 2); assert(coroutine.resume(loop)); assert(burstLookups == 25)

		settings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel5; changed:Fire(); flush()
		visible, detailed = counts(); assert(visible == 18 and detailed == 6, "Medium budget failed")
		settings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel2; changed:Fire(); flush()
		visible, detailed = counts(); assert(visible == 10 and detailed == 0, "Low budget failed")
		settings.SavedQualityLevel = Enum.SavedQualitySetting.Automatic; changed:Fire(); flush()
		visible, detailed = counts(); assert(visible == 18 and detailed == 6, "Automatic was not conservative")
		quality = "Minimal"; onQuality(); flush(); visible = counts(); assert(visible == 0)
		assert(models[1].AuraHighlight.Enabled, "Off removed rarity outline")
		local beforeOff = burstLookups
		models[2].AuraVfx:SetAttribute("BurstId", 3); models[2]:SetAttribute("EvolutionBurst", 3); flush()
		assert(burstLookups == beforeOff, "Off emitted a burst")
		quality = "Full"; settings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel10; onQuality(); flush()
		assert(burstLookups == beforeOff, "A suppressed evolution burst replayed when effects returned")
		models[1]:SetAttribute("FixtureOwner", false); showOthers = false; onOthers(); flush()
		assert(models[1].AuraVfx.FlameVolume.OuterFlames.Rate == 0 and models[1].AuraVfx.FlameVolume.CoreFlames.Rate == 0, "Other-plot suppression failed")
		models[2]:SetAttribute("DayPaused", true); flush(); assert(models[2].AuraVfx.FlameVolume.OuterFlames.TimeScale == 0)
		models[2]:SetAttribute("DayPaused", false); flush(); assert(models[2].AuraVfx.FlameVolume.OuterFlames.TimeScale == 1)
		models[2]:SetAttribute("Stoned", true); flush(); assert(models[2].AuraVfx.FlameVolume.OuterFlames.Rate == 0)
		models[2]:SetAttribute("Stoned", false); flush()
		models[2]:PivotTo(CFrame.new(1000, 0, 0)); assert(coroutine.resume(loop)); assert(models[2].AuraVfx.FlameVolume.CoreFlames.Rate == 0, "Distance culling failed")
		removed:Fire(models[3]); flush(); assert(models[3].AuraVfx.FlameVolume.OuterFlames.Rate == 0)
		root:Destroy(); assert(coroutine.resume(loop))
	end, debug.traceback)
	root:Destroy(); added:Destroy(); removed:Destroy(); changed:Destroy()
	assert(ok, failure)
	return "High/Medium/Low/Auto/Off, crowd/distance budgets, stable playback, other plots, pause/stone and cleanup passed"
end
