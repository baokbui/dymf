--!strict
-- Studio-only injected client fixture. Real UI modules; mocked player/remotes/assets.
return function(): number
	local realGame, realRequire = game, require
	local client = game.StarterPlayer.StarterPlayerScripts.Client
	local shared = game.ReplicatedStorage.Shared
	local gui = game.StarterGui.MainUI:Clone()
	gui.Name = "MenuIntegrationValidation"
	gui.Parent = game:GetService("CoreGui")
	local player = { UserId = 999, DisplayName = "Preview", Character = nil }
	function player:WaitForChild(): any return { WaitForChild = function() return gui end } end
	local signals, cache = {}, {}
	local checks = 0
	local function check(value: any, message: string)
		checks += 1
		assert(value, message)
	end
	local function disjoint(a: GuiObject, b: GuiObject): boolean
		local p, q = a.AbsolutePosition, b.AbsolutePosition
		return p.X + a.AbsoluteSize.X <= q.X + 1 or q.X + b.AbsoluteSize.X <= p.X + 1
			or p.Y + a.AbsoluteSize.Y <= q.Y + 1 or q.Y + b.AbsoluteSize.Y <= p.Y + 1
	end
	local function checkHudClear(window: GuiObject)
		for _, name in { "Shop", "DamageMeter", "QuestTracker", "LevelUI", "Coins", "Brains", "Speed", "MenuEntry", "MenuDrawer", "MagnetEntry" } do
			local peer = gui:FindFirstChild(name) :: GuiObject?
			if peer and peer.Visible then check(disjoint(window, peer), window.Name .. " covers " .. name) end
		end
	end
	local function noop() end
	local function signal(name: string): RBXScriptSignal
		if not signals[name] then signals[name] = Instance.new("BindableEvent") end
		return signals[name].Event
	end
	local proxy = setmetatable({}, { __index = function() return noop end })
	local preview = { mount = function(parent: Instance, _definition: any, size: UDim2?, position: UDim2?): Frame
		local frame = Instance.new("Frame")
		frame.Size, frame.Position = size or UDim2.fromScale(1, 1), position or UDim2.new()
		frame.Parent = parent
		return frame
	end }
	local profile = { brains = 100, unlocks = { "BallerinaCappucina", "TungTungSahur", "ChimpanziniBananini", "CappuccinoAssassino", "TralaleroTralala" },
		equipped = { "TungTungSahur" }, upgrades = {}, statistics = {}, brainrotXp = {}, evolutions = {} }
	local payload = { ready = true, dayKey = 20000, resetAt = workspace:GetServerTimeNow() + 3600,
		quests = { { id = "CollectCoins", progress = 150, target = 150, brains = 3, claimed = false },
			{ id = "DefeatMonsters", progress = 0, target = 15, brains = 3, claimed = false },
			{ id = "ClearDay", progress = 0, target = 1, brains = 6, claimed = false } },
		bonusBrains = 6, bonusClaimed = false, brainrotTickets = 1,
		login = { track = "Welcome", step = 3, dayKey = 20000, ready = true, claimed = false, completed = 2, brains = 4, nextStep = 3,
			rewards = { { kind = "Brains", amount = 2 }, { kind = "Upgrade", upgradeId = "WalkSpeed", amount = 1, name = "Speed level" }, { kind = "Brains", amount = 4 },
				{ kind = "Upgrade", upgradeId = "Magnet", amount = 1, name = "Magnet level" }, { kind = "Brains", amount = 6 }, { kind = "Upgrade", upgradeId = "WalkSpeed", amount = 1, name = "Speed level" }, { kind = "Ticket", amount = 1 } } },
		achievements = { { id = "FirstEpic", name = "Going Epic", description = "Claim an Epic evolution.", progress = 1, target = 1, brains = 5, claimed = false } },
		nextGoal = { id = "Evolution:TungTungSahur:Epic", kind = "Evolution", brainrotId = "TungTungSahur", title = "Next evolution", description = "Raise Tung Tung Sahur." } }
	local writes = 0
	local remotes = { getEvent = function(name: string): any
		return { OnClientEvent = signal(name), FireServer = function() writes += 1 end }
	end, getFunction = function(): any return { InvokeServer = function() return { profile = profile, retention = payload } end } end }
	local placement = setmetatable({ selectionChanged = signal("selection"), shovelModeChanged = signal("shovel") }, { __index = function() return noop end })
	local mocks = { AudioController = proxy, PlacementController = placement, InputController = { magnetAction = signal("magnet") },
		VfxUtil = proxy, Remotes = remotes, BrainrotPreview = preview, MonsterPreview = preview, TextShine = proxy,
		PlotUtil = { countOnLocalPlot = function() return 0 end, getLocalPlotModel = function() return nil end },
		VfxLoad = setmetatable({ label = function() return "High" end }, { __index = function() return function() return true end end }) }
	local fakeGame = { GetService = function(_, name: string): any
		if name == "Players" then return { LocalPlayer = player } end
		return realGame:GetService(name)
	end }
	local testTask = table.clone(task)
	testTask.spawn = noop -- do not leave the normal controller polling loops alive
	local fresh: (ModuleScript) -> any
	fresh = function(module: ModuleScript): any
		if mocks[module.Name] then return mocks[module.Name] end
		if cache[module] then return cache[module] end
		if module == client.Controllers.UIController or module:IsDescendantOf(client.Controllers.UIController)
			or module == client.Controllers.QuestController or module:IsDescendantOf(client.Controllers.QuestController)
			or module == client.Utilities.MenuRouter or module == client.Utilities.MenuTiles or module == client.Utilities.MenuDrawer
			or module == client.Utilities.HudLayout or module == client.Utilities.ScrollPolicy or module == client.Utilities.UISizing or module == client.Utilities.OutsideDismiss or module == client.UIEvents or module == shared.Config.UITheme then
			local chunk = assert(loadstring(module.Source, "=" .. module:GetFullName()))
			setfenv(chunk, setmetatable({ game = fakeGame, script = module, require = fresh, task = testTask }, { __index = getfenv() }))
			cache[module] = chunk()
			return cache[module]
		end
		return realRequire(module)
	end
	local ok, result = xpcall(function()
		local ui = fresh(client.Controllers.UIController)
		ui.init(); ui.start()
		fresh(client.Controllers.QuestController).start()
		local menu = fresh(client.Utilities.MenuRouter)
		check(gui:FindFirstChild("MenuEntry") and not gui:FindFirstChild("InventoryEntry") and not gui:FindFirstChild("DailyQuestsEntry"), "old HUD buttons remain")
		local tracker = gui.QuestTracker
		check(tracker and tracker.QuestToggle.Text == "Daily Quests", "right-side quest tabs missing")
		check(tracker.Objectives.Objective1.Content.Progress.Text == "150/150", "tracker progress not rendered")
		check(not tracker:FindFirstChild("ViewQuests"), "View Quests link remains")
		local clicks = 0
		for _, item in tracker:GetDescendants() do if item:IsA("GuiButton") then clicks += 1 end end
		check(clicks == 1, "tracker has click targets beyond quest toggle")
		check(tracker.QuestToggle.TextColor3 == fresh(shared.Config.UITheme).TITLE, "quest heading highlighted")
		check(tracker.QuestToggle.CycleIcon.Image == "rbxassetid://86604833779310" and not tracker.QuestToggle.CycleIcon.Active, "quest cycle hint missing or intercepts clicks")
		task.wait()
		check(tracker.AbsolutePosition.Y >= gui.DamageMeter.AbsolutePosition.Y + gui.DamageMeter.AbsoluteSize.Y, "tracker overlaps Damage")
		check(tracker.AbsolutePosition.Y + tracker.AbsoluteSize.Y < gui.LevelUI.AbsolutePosition.Y, "tracker overlaps day panel")
		local factor = fresh(client.Utilities.UISizing).desktop(gui.AbsoluteSize)
		local function trackerFollowsDamage(): boolean
			local damageBottom = gui.DamageMeter.AbsolutePosition.Y + gui.DamageMeter.AbsoluteSize.Y
			return math.abs(tracker.AbsolutePosition.Y - (damageBottom + 16 * factor)) < 2
		end
		check(trackerFollowsDamage(), "quests not directly below Damage")
		gui.LevelUI.StartCountdown.Visible = true; task.wait()
		check(disjoint(tracker, gui.LevelUI.StartCountdown), "countdown overlaps tracker")
		gui.LevelUI.StartCountdown.Visible = false
		local damageSize = gui.DamageMeter.Size
		gui.DamageMeter.Size = UDim2.fromOffset(damageSize.X.Offset, 300); task.wait()
		check(tracker.Visible and trackerFollowsDamage(), "quests do not follow expanded Damage")
		check(tracker.AbsolutePosition.Y + tracker.AbsoluteSize.Y < gui.LevelUI.AbsolutePosition.Y, "expanded damage pushes quests into day panel")
		gui.DamageMeter.Size = damageSize; task.wait()
		check(trackerFollowsDamage(), "quests do not follow collapsed Damage")
		local window = gui.Menu.Window
		check(not window:FindFirstChild("Home"), "top-left Menu button remains")
		check(gui.MenuDrawer.ZIndex > gui.Menu.ZIndex and gui.MenuEntry.ZIndex > gui.Menu.ZIndex, "outside dismissal blocks navigation")
		check(fresh(shared.Config.UITheme).PANEL_BG_QUESTS ~= fresh(shared.Config.UITheme).PANEL_BG_STORE, "Quests shares Upgrades color")
		local pages = window.Content.Pages
		local drawer = gui.MenuDrawer
		local sections = drawer.Viewport.Sections
		menu.home(); task.wait(0.3)
		check(not gui.Menu.Visible and drawer.Visible and drawer:GetAttribute("Open"), "drawer did not replace large launcher")
		local layout = sections:FindFirstChildOfClass("UIListLayout")
		check(layout and layout.FillDirection == Enum.FillDirection.Horizontal, "icons must slide out in a row")
		check(gui.MenuEntry.Caption.Text == "Close" and math.abs(gui.MenuEntry.MenuBar1.Rotation - 45) < 0.1 and not gui.MenuEntry.MenuBar2.Visible, "menu icon did not become X")
		local tiles = 0
		for _, tile in sections:GetChildren() do
			if tile:IsA("TextButton") then
				tiles += 1
				check(tile.Icon:IsA("ImageLabel") and tile.Caption.Text == tile.Name, "tile missing icon/name")
				check(tile.Icon.Image ~= "" or #tile.Icon:GetChildren() > 1, "empty tile illustration")
			end
		end
		check(tiles == 7, "launcher added unimplemented destinations")
		menu.close(); menu.home(); menu.close(); menu.home(); task.wait(0.3)
		check(drawer.Visible and drawer:GetAttribute("Open") and drawer.AbsoluteSize.X > 0, "rapid toggles broke drawer animation")
		check(drawer.AbsolutePosition.X + drawer.AbsoluteSize.X <= gui.MagnetEntry.AbsolutePosition.X, "drawer overlaps magnet")
		check(not sections.Inventory:FindFirstChildOfClass("UIStroke") and sections.Inventory.BackgroundTransparency == 1, "large tile panels remain")
		check(sections.Inventory.Icon.Image == "rbxassetid://18224282235"
			and sections.Index.Icon.Image == "rbxassetid://110444066627259"
			and sections.Upgrades.Icon.Image == "rbxassetid://90725732857650", "existing icons changed")
		local topbar = gui.Parent:FindFirstChild("BvmTopbar")
		check(not sections:FindFirstChild("Settings") and topbar and topbar.Settings.Icon.Image == "rbxassetid://7059346373", "Settings shortcut missing")
		for _, name in { "Inventory", "Index", "Upgrades", "Quests", "Achievements", "Statistics" } do
			menu.open(name); task.wait(0.05)
			check(sections[name].Caption.TextColor3 == fresh(shared.Config.UITheme).TITLE, "menu label highlighted: " .. name)
			check(gui.Menu.Visible and sections[name].Active and drawer:GetAttribute("Open") and window.Content.Visible, "missing section " .. name)
			checkHudClear(window)
		end
		local firstTime = fresh(client.Controllers.QuestController.FirstTimeRewards)
		check(not sections:FindFirstChild("First-time Rewards") and gui.FirstTimeRewardsEntry.Visible, "first-time rewards remain in Menu")
		firstTime.open(); task.wait()
		check(gui.FirstTimeRewards.Visible and not gui.Menu.Visible, "standalone rewards did not open")
		checkHudClear(gui.FirstTimeRewards.Window)
		local rewardView = gui.FirstTimeRewards.Window.LoginRewards
		local rewards = rewardView.RewardStrip
		check(rewards.ScrollingDirection == Enum.ScrollingDirection.X, "rewards must scroll horizontally")
		check(rewards:FindFirstChildOfClass("UIListLayout").FillDirection == Enum.FillDirection.Horizontal, "reward row is not horizontal")
		check(rewards.RewardDay1.AbsolutePosition.Y == rewards.RewardDay7.AbsolutePosition.Y, "rewards wrap into rows")
		check(rewards.RewardDay3.RewardAmount.Text == "+4 brains" and rewards.RewardDay3.Icon.Image == "rbxassetid://12691330734", "brain icon/amount layout")
		check(rewards.RewardDay1.ClaimedStamp.Visible and rewards.RewardDay1.RewardAmount.Text == "+2 brains", "claimed card loses its reward")
		check(not rewards.RewardDay3.ClaimedStamp.Visible, "unclaimed reward stamped")
		check(rewards.RewardDay4.Icon.Image == "rbxassetid://73519143112132" and rewards.RewardDay4.RewardAmount.Text == "+1 magnet level", "magnet reward")
		check(rewards.RewardDay6.Icon.Image == "rbxassetid://82103513055414", "speed reward")
		check(rewards.RewardDay7.Icon.Ticket.Visible and rewards.RewardDay7.RewardAmount.Text == "+1 Brainrot ticket", "ticket illustration missing")
		menu.open("Quests"); task.wait()
		check(window.Content.AbsoluteCanvasSize.Y <= window.Content.AbsoluteSize.Y + 3, "fitting quests have artificial canvas overflow")
		check(window.Content.ScrollBarThickness == 0, "fitting quests show scrollbar")
		check(not window:FindFirstChild("HeaderAccent") and window.Content.Position.Y.Offset == 8, "Menu divider still reserves header space")
		local questTitle = pages.DailyQuests.Title
		check(math.abs(questTitle.AbsolutePosition.X + questTitle.AbsoluteSize.X / 2 - (window.AbsolutePosition.X + window.AbsoluteSize.X / 2)) < 2, "Quests title off center")
		check(window.BackgroundColor3 == fresh(shared.Config.UITheme).PANEL_BG_QUESTS, "quest background")
		window.Size = UDim2.fromOffset(window.Size.X.Offset, 300); task.wait()
		check(not window.Content.ScrollingEnabled and window.Content.ScrollBarThickness == 0, "small quest window uses outer scrolling")
		local objectives = pages.DailyQuests.ObjectiveList
		check(objectives.AbsoluteCanvasSize.Y > objectives.AbsoluteWindowSize.Y and objectives.ScrollingEnabled,
			"small quest window lost list overflow")
		menu.open("Quests"); task.wait()
		check(not gui.FirstTimeRewards.Visible, "Menu failed to dismiss standalone rewards")
		menu.open("Settings"); task.wait(0.1)
		for _, label in pages.Settings.Body.Graphics:GetChildren() do
			if label:IsA("TextLabel") and label.TextWrapped then check(label.TextFits, "settings description clipped") end
		end
		menu.open("Statistics"); task.wait(0.1)
		local totals = pages.Statistics.Totals
		local totalsOverflow = totals.AbsoluteCanvasSize.Y > totals.AbsoluteSize.Y + 3
		check((totals.ScrollBarThickness > 0) == totalsOverflow, "statistics scrollbar does not match overflow")
		check(pages.DailyQuests.QuestTabs["Daily Quests"].Visible and pages.DailyQuests.QuestTabs["Weekly Quests"].Visible, "weekly tabs missing")
		check(sections["Quests"].Available.Visible and sections.Achievements.Available.Visible, "reward badges")
		check(gui.Menu.Dismiss.BackgroundTransparency == 1, "menu adds background shading")
		check(gui.Menu.Dismiss:IsA("Frame"), "full-screen dismiss button covers panel")
		for _, name in { "Top", "Bottom", "Left", "Right" } do
			local region = gui.Menu.Dismiss[name]
			local a, b = region.AbsolutePosition, region.AbsolutePosition + region.AbsoluteSize
			local c, d = window.AbsolutePosition, window.AbsolutePosition + window.AbsoluteSize
			check(b.X <= c.X + 1 or a.X >= d.X - 1 or b.Y <= c.Y + 1 or a.Y >= d.Y - 1, "dismiss overlaps panel: " .. name)
		end
		for _, name in { "Achievements", "Index", "Settings", "Statistics" } do
			menu.open(name); task.wait()
			check(not window.Content.ScrollingEnabled and window.Content.ScrollBarThickness == 0, "duplicate scrolling: " .. name)
		end
		menu.open("Achievements"); task.wait()
		local rewardRoot = pages.DailyQuests
		check(math.abs(rewardRoot.Title.AbsolutePosition.X + rewardRoot.Title.AbsoluteSize.X / 2 - (window.AbsolutePosition.X + window.AbsoluteSize.X / 2)) < 2, "Achievements title off center")
		check(window.BackgroundColor3 == fresh(shared.Config.UITheme).PANEL_BG_ACHIEVEMENTS, "achievement background")
		local visibleTimer = false
		for _, child in rewardRoot:GetChildren() do
			if child:IsA("TextLabel") and string.find(child.Text, "Resets in", 1, true) and child.Visible then visibleTimer = true end
		end
		check(not visibleTimer, "permanent achievements have a reset timer")
		local goal = rewardRoot.Achievements.NextGoal
		for _, child in goal:GetChildren() do
			if child:IsA("TextLabel") then check(not string.find(child.Text, "›", 1, true), "unsupported goal glyph") end
		end
		local reward = rewardRoot.Achievements.Milestones.FirstEpic:FindFirstChildOfClass("TextButton")
		check(reward.BrainAmount.Icon.Image == "rbxassetid://12691330734", "reward icon missing")
		check(not pages.Settings:FindFirstChild("Statistics", true), "statistics remain in settings")
		check(pages.Statistics.Totals["Monsters defeated"] ~= nil, "statistics page missing totals")
		menu.open("Inventory")
		check(pages.Inventory.BackgroundTransparency == 1 and not pages.Inventory:FindFirstChildOfClass("UIStroke").Enabled, "nested inventory panel remains")
		check(window.BackgroundColor3 == pages.Inventory.BackgroundColor3, "host does not match feature color")
		check(window.Size.X.Offset <= pages.Inventory.Size.X.Offset + 64, "host has excessive empty width")
		fresh(client.UIEvents).fireInspectOwnedBrainrot("TungTungSahur"); task.wait(0.1)
		local inventory = pages.Inventory
		local openedDetail = inventory:FindFirstChild("BrainrotInspect") or pages:FindFirstChild("BrainrotInspect")
		check(inventory.Visible and openedDetail and openedDetail.Visible, "goal-to-inventory details")
		window.Size = UDim2.fromOffset(366, 700); task.wait(0.1)
		local detail = pages:FindFirstChild("BrainrotInspect")
		check(detail and detail.Visible and window.Back.Visible, "narrow inspection page")
		check(detail:FindFirstChild("MenuScale").Scale > 0.7, "detail text shrunk excessively")
		menu.open("Index"); task.wait()
		check(not inventory.Visible and not inventory.BrainrotInspect.Visible and not window.Back.Visible, "detail leaked across pages")
		check(pages.Index.List.Size.X.Offset == -60 and pages.Index.List.VerticalScrollBarInset == Enum.ScrollBarInset.Always, "Index scrollbar not inset")
		check(pages.Index.List.BorderSizePixel == 0 and pages.Index.List.ClipsDescendants, "Index has outward border/scrolling artifacts")
		check(math.abs(pages.Index.List.Cell1.AbsolutePosition.Y - pages.Index.List.Cell4.AbsolutePosition.Y) < 2, "inset breaks four-column Index")
		check(pages.Index.List.Cell4.AbsolutePosition.X + pages.Index.List.Cell4.AbsoluteSize.X < pages.Index.List.AbsolutePosition.X + pages.Index.List.AbsoluteSize.X - 8, "Index scrollbar crowds cards")
		menu.open("Upgrades"); task.wait()
		check(pages.ProgressionStore.Visible, "upgrade view")
		menu.close(); menu.detach("Upgrades")
		check(gui:FindFirstChild("ProgressionStore") and not gui.ProgressionStore:FindFirstChild("MenuScale"), "physical store detach")
		check(gui.ProgressionStore.BackgroundTransparency == 0 and gui.ProgressionStore:FindFirstChildOfClass("UIStroke").Enabled, "standalone store panel not restored")
		signals.OpenProgressionStore:Fire(realRequire(shared.Config.StoreConfig).SHOP_BRAINROTS)
		task.wait(0.05)
		check(gui.ProgressionStore.Visible and not gui.Menu.Visible, "physical stall failed to open independently")
		menu.open("Index"); task.wait()
		check(not gui.ProgressionStore.Visible, "physical stall remained over Menu")
		menu.open("Upgrades"); task.wait()
		check(pages.ProgressionStore.Visible, "upgrade remount")
		menu.home(); task.wait()
		check(drawer:GetAttribute("Open") and not gui.Menu.Visible and not pages.ProgressionStore.Visible, "home did not return to drawer")
		payload.login.ready, payload.login.claimed = false, true
		payload.quests[1].claimed, payload.achievements[1].claimed = true, true
		signals.RetentionUpdated:Fire(payload); task.wait()
		check(not gui.MenuEntry.AvailableRewards.Visible, "stale reward badge")
		check(gui.FirstTimeRewardsEntry.Visible and not gui.FirstTimeRewardsEntry.Available.Visible, "today's claim removed unfinished track")
		check(not rewardView.ClaimLoginReward.Visible, "claimed-for-today button remains")
		check(gui.FirstTimeRewards.Window.Size.Y.Offset == 280, "claimed reward panel has empty bottom space")
		firstTime.open(); task.wait()
		check(gui.FirstTimeRewards.Visible, "unfinished track cannot reopen")
		payload.login.finished, payload.login.completed, payload.login.step = true, 7, 7
		signals.RetentionUpdated:Fire(payload); task.wait()
		check(not gui.FirstTimeRewardsEntry.Visible and not gui.FirstTimeRewards.Visible, "completed track did not disappear")
		firstTime.open()
		check(not gui.FirstTimeRewards.Visible, "completed track reopened")
		signals.LevelStateChanged:Fire({ phase = "Victory", levelNumber = 10, canStart = false })
		task.wait()
		check(not gui.Menu.Visible, "day result did not dismiss Menu")
		menu.close()
		task.wait(0.3)
		check(not gui.Menu.Visible and not drawer.Visible, "menu/drawer close")
		check(gui.MenuEntry.Caption.Text == "Menu" and gui.MenuEntry.MenuBar2.Visible and math.abs(gui.MenuEntry.MenuBar1.Rotation) < 0.1, "menu icon did not restore")
		check(fresh(shared.Config.UITheme).STROKE_PANEL == 4, "existing theme changed")
		check(writes == 0, "navigation sent gameplay requests")
		payload.quests[2].progress = 15
		signals.RetentionUpdated:Fire(payload); task.wait(0.05)
		check(tracker.Objectives.Objective2.Visible and tracker.Objectives.Objective2.Content.Title.TextColor3 == fresh(shared.Config.UITheme).CARD_SELECTED_BG, "completed quest did not animate")
		task.wait(0.9)
		check(not tracker.Objectives.Objective2.Visible, "completed quest not cleared")
		signals.RetentionUpdated:Fire(payload); task.wait()
		check(not tracker.Objectives.Objective2.Visible, "completed quest replayed on refresh")
		local unnecessary = {}
		for _, item in gui:GetDescendants() do
			if item:IsA("ScrollingFrame") and item.AbsoluteSize.X > 0 and item.AbsoluteSize.Y > 0 then
				local x = item.ScrollingDirection ~= Enum.ScrollingDirection.Y and item.AbsoluteCanvasSize.X > item.AbsoluteSize.X + 3
				local y = item.ScrollingDirection ~= Enum.ScrollingDirection.X and item.AbsoluteCanvasSize.Y > item.AbsoluteSize.Y + 3
				if (not item.ScrollingEnabled or not (x or y)) and item.ScrollBarThickness > 0 then table.insert(unnecessary, item:GetFullName()) end
			end
		end
		check(#unnecessary == 0, "unnecessary scrollbars: " .. table.concat(unnecessary, ", "))
		return checks
	end, debug.traceback)
	gui:Destroy()
	for _, event in signals do event:Destroy() end
	if not ok then error(result) end
	return result
end
