--!strict
--[[
	UIController
	Owns the main UI. Displays server-provided state and forwards intent via
	Remotes / controllers — never gameplay logic.

	Milestones 3–4 (Coins/Shop), 8 (Level), 13 (Hearts/Settings/Inventory/Rewards).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared.Brainrots)
local Monsters = require(Shared.Monsters)
local Remotes = require(Shared.Remotes)
local Constants = require(Shared.Constants)
local ProgressConfig = require(Shared.Config.ProgressConfig)
local MagnetConfig = require(Shared.Config.MagnetConfig)
local PlotConfig = require(Shared.Config.PlotConfig)
local LevelConfig = require(Shared.Config.LevelConfig)
local UITheme = require(Shared.Config.UITheme)
local Logger = require(Shared.Utilities.Logger)

local UIEvents = require(script.Parent.Parent.UIEvents)
local Shop = require(script.Shop)
local Level = require(script.Level)
local CoinCounter = require(script.CoinCounter)
local BrainsCounter = require(script.BrainsCounter)
local SpeedHud = require(script.SpeedHud)
local Hearts = require(script.Hearts)
local Settings = require(script.Settings)
local Inventory = require(script.Inventory)
local RewardPopup = require(script.RewardPopup)
local UnlockPopup = require(script.UnlockPopup)
local MonsterIntroPopup = require(script.MonsterIntroPopup)
local MechanicIntroPopup = require(script.MechanicIntroPopup)
local GameOverPopup = require(script.GameOverPopup)
local ProgressionStore = require(script.ProgressionStore)
local PlantToast = require(script.PlantToast)
local BrainrotInspect = require(script.BrainrotInspect)
local MonsterInspect = require(script.MonsterInspect)
local MagnetHud = require(script.MagnetHud)
local DamageMeter = require(script.DamageMeter)
local PlacementController = require(script.Parent.PlacementController)
local AudioController = require(script.Parent.AudioController)
local InputController = require(script.Parent.InputController)
local VfxUtil = require(script.Parent.Parent.Utilities.VfxUtil)

local UIController = {}
UIController.Name = "UIController"

local log = Logger.new(UIController.Name)

local localPlayer = Players.LocalPlayer
local coinCounter: CoinCounter.CoinCounter? = nil
local brainsCounter: BrainsCounter.BrainsCounter? = nil
local speedHud: SpeedHud.SpeedHud? = nil
local magnetHud: MagnetHud.MagnetHud? = nil
local damageMeterHud: DamageMeter.DamageMeterHud? = nil
local shop: Shop.Shop? = nil
local levelPanel: Level.LevelPanel? = nil
local heartsHud: Hearts.HeartsHud? = nil
local settingsPanel: Settings.SettingsPanel? = nil
local inventoryPanel: Inventory.InventoryPanel? = nil
local rewardPopup: RewardPopup.RewardPopupHud? = nil
local unlockPopup: UnlockPopup.UnlockPopupHud? = nil
local monsterIntroPopup: MonsterIntroPopup.MonsterIntroPopupHud? = nil
local mechanicIntroPopup: MechanicIntroPopup.MechanicIntroPopupHud? = nil
local gameOverPopup: GameOverPopup.GameOverPopupHud? = nil
local progressionStore: ProgressionStore.ProgressionStoreHud? = nil
local plantToast: PlantToast.PlantToastHud? = nil
local fieldInspect: BrainrotInspect.InspectCard? = nil
local monsterInspect: MonsterInspect.InspectCard? = nil
local lastBrainrotXp: { [string]: number } = {}
local lastEvolutions: { [string]: { string } } = {}
local settingsEntry: TextButton? = nil
local inventoryEntry: TextButton? = nil
local selectedId: string? = nil
local lastBalance: number? = nil
local spendPending = false
local lastLevelPhase: string? = nil
local lastCountdownCeil: number? = nil
local lastBigWaveWarning = false
local lastMagnetActiveUntil = 0

type IntroItem = { kind: string, id: string }
local introQueue: { IntroItem } = {}
local introBusy = false
local introHoldForReward = false

local function enqueueIntro(kind: string, id: string)
	if id == "" then
		return
	end
	table.insert(introQueue, { kind = kind, id = id })
end

local function enqueueIntroList(kind: string, ids: any)
	if type(ids) ~= "table" then
		return
	end
	for _, id in ids do
		if type(id) == "string" then
			enqueueIntro(kind, id)
		end
	end
end

local function pumpIntros()
	if introBusy or introHoldForReward then
		return
	end
	local nextItem = table.remove(introQueue, 1)
	if not nextItem then
		return
	end
	introBusy = true
	if nextItem.kind == "brainrot" and unlockPopup then
		unlockPopup:show(nextItem.id)
		if not unlockPopup.frame.Visible then
			introBusy = false
			pumpIntros()
		end
	elseif nextItem.kind == "mechanic" and mechanicIntroPopup then
		mechanicIntroPopup:show(nextItem.id)
		if not mechanicIntroPopup.frame.Visible then
			introBusy = false
			pumpIntros()
		end
	elseif nextItem.kind == "monster" and monsterIntroPopup then
		monsterIntroPopup:show(nextItem.id)
		if not monsterIntroPopup.frame.Visible then
			introBusy = false
			pumpIntros()
		end
	else
		introBusy = false
		pumpIntros()
	end
end

local function onIntroHidden()
	introBusy = false
	pumpIntros()
end

local function setBalance(amount: number)
	if coinCounter then
		coinCounter:setBalance(amount)
	end
	if shop then
		shop:setBalance(amount)
	end
	PlacementController.setBalance(amount)
end

local function applyProfile(profile: { [string]: any }?)
	if type(profile) ~= "table" then
		return
	end
	if brainsCounter and type(profile.brains) == "number" then
		brainsCounter:setBalance(profile.brains)
	end
	local upgrades: { [string]: number } = {}
	if type(profile.upgrades) == "table" then
		for key, value in (profile.upgrades :: { [string]: any }) do
			if type(key) == "string" and type(value) == "number" then
				upgrades[key] = value
			end
		end
	end
	if speedHud then
		speedHud:applyUpgrades(upgrades)
	end
	if magnetHud then
		magnetHud:applyUpgrades(upgrades)
	end
	if shop and type(profile.equipped) == "table" then
		local equipped = profile.equipped :: { string }
		shop:setEquipped(equipped)
		if selectedId then
			local stillEquipped = false
			for _, id in equipped do
				if id == selectedId then
					stillEquipped = true
					break
				end
			end
			if not stillEquipped then
				PlacementController.cancel()
			end
		end
	end
	if inventoryPanel then
		inventoryPanel:applyProfile(profile)
	end
	local xp: { [string]: number } = {}
	if type(profile.brainrotXp) == "table" then
		for key, value in (profile.brainrotXp :: { [string]: any }) do
			if type(key) == "string" and type(value) == "number" then
				xp[key] = value
			end
		end
	end
	lastBrainrotXp = xp
	local evolutions: { [string]: { string } } = {}
	if type(profile.evolutions) == "table" then
		for key, value in (profile.evolutions :: { [string]: any }) do
			if type(key) ~= "string" or type(value) ~= "table" then
				continue
			end
			local rarities: { string } = {}
			for _, rarity in value do
				if type(rarity) == "string" then
					table.insert(rarities, rarity)
				end
			end
			evolutions[key] = rarities
		end
	end
	lastEvolutions = evolutions
	if shop then
		shop:setEvolutions(evolutions)
	end
	if fieldInspect and fieldInspect:isOpen() then
		local id = fieldInspect:getBrainrotId()
		if id then
			fieldInspect:setTotalXp(xp[id] or 0)
			fieldInspect:setClaimedRarities(evolutions[id] or {})
		end
	end
	if progressionStore then
		progressionStore:setProfile(profile)
	end
	if settingsPanel and type(profile.statistics) == "table" then
		settingsPanel:applyStatistics(profile.statistics :: { [string]: number })
	end
end

local function buildMain(): Frame
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	return playerGui:WaitForChild("MainUI") :: Frame
end

local function buildCoinCounter(): CoinCounter.CoinCounter
	local frame = buildMain():WaitForChild("Coins") :: Frame
	return CoinCounter.new(frame)
end

local function buildBrainsCounter(): BrainsCounter.BrainsCounter
	local frame = buildMain():WaitForChild("Brains") :: Frame
	return BrainsCounter.new(frame)
end

local function buildSpeedHud(): SpeedHud.SpeedHud
	local frame = buildMain():WaitForChild("Speed") :: Frame
	return SpeedHud.new(frame)
end

local function applyMagnetState(state: { [string]: any }?)
	if magnetHud then
		magnetHud:applyState(state)
	end
	if type(state) ~= "table" then
		return
	end
	if type(state.pausedRemaining) == "number" and state.pausedRemaining > 0 then
		VfxUtil.stopMagnetWaves()
		return
	end
	if type(state.activeUntil) ~= "number" then
		return
	end
	local untilTime = state.activeUntil
	if untilTime <= lastMagnetActiveUntil then
		return
	end
	lastMagnetActiveUntil = untilTime
	local remaining = untilTime - workspace:GetServerTimeNow()
	if remaining < 0.15 then
		return
	end
	local character = localPlayer.Character
	if character then
		local level = if magnetHud then magnetHud.level else MagnetConfig.DEFAULT_LEVEL
		if type(state.level) == "number" then
			level = state.level
		end
		local radius = MagnetConfig.rangeTilesFor(level) * PlotConfig.TILE_SIZE
		VfxUtil.playMagnetWaves(character, remaining, radius)
	end
end

local function requestMagnet()
	if lastLevelPhase ~= Constants.PHASE.Active then
		return
	end
	if magnetHud and not magnetHud:isReady() then
		return
	end
	AudioController.play("UiClick")
	Remotes.getEvent("ActivateMagnet"):FireServer()
end

local function applyDamageMeter(state: { [string]: any }?)
	if damageMeterHud then
		damageMeterHud:apply(state)
	end
end

local function buildMagnetHud(): MagnetHud.MagnetHud
	local hud = MagnetHud.new(buildMain())
	hud.onActivate = requestMagnet
	return hud
end

local function buildDamageMeter(): DamageMeter.DamageMeterHud
	local frame = buildMain():WaitForChild("DamageMeter") :: Frame
	return DamageMeter.new(frame)
end

local function buildShop(): Shop.Shop
	local frame = buildMain():WaitForChild("Shop") :: Frame
	return Shop.new(frame, {
		onCardClicked = function(id: string)
			if PlacementController.isOnCooldown(id) then
				UIEvents.firePlantFailed("Unable to plant — still recharging")
				AudioController.play("UiClick")
				return
			end
			if selectedId == id then
				PlacementController.cancel()
			else
				PlacementController.select(id)
			end
		end,
		onShovelClicked = function()
			PlacementController.toggleShovelMode()
		end,
		onCancelClicked = function()
			PlacementController.cancel()
			PlacementController.setShovelMode(false)
			AudioController.play("UiClick")
		end,
	})
end

local function buildLevelPanel(): Level.LevelPanel
	return Level.new(buildMain():WaitForChild("LevelUI") :: Frame)
end

local function buildHearts(): Hearts.HeartsHud
	return Hearts.new(buildMain():WaitForChild("Hearts") :: Frame)
end

local function buildInventory(): Inventory.InventoryPanel
	return Inventory.new(buildMain():WaitForChild("Inventory") :: Frame)
end

local function buildRewardPopup(): RewardPopup.RewardPopupHud
	return RewardPopup.new(buildMain():WaitForChild("RewardPopup") :: Frame)
end

local function buildUnlockPopup(): UnlockPopup.UnlockPopupHud
	return UnlockPopup.new(buildMain():WaitForChild("UnlockPopup") :: Frame)
end

local function buildMonsterIntroPopup(): MonsterIntroPopup.MonsterIntroPopupHud
	return MonsterIntroPopup.new(buildMain():WaitForChild("MonsterIntroPopup") :: Frame)
end

local function buildMechanicIntroPopup(): MechanicIntroPopup.MechanicIntroPopupHud
	return MechanicIntroPopup.new(buildMain():WaitForChild("MechanicIntroPopup") :: Frame)
end

local function buildGameOverPopup(): GameOverPopup.GameOverPopupHud
	return GameOverPopup.new(buildMain():WaitForChild("GameOverPopup") :: Frame)
end

local function buildProgressionStore(): ProgressionStore.ProgressionStoreHud
	return ProgressionStore.new(buildMain():WaitForChild("ProgressionStore") :: Frame)
end

local function buildSettings(): Settings.SettingsPanel
	return Settings.new(buildMain():WaitForChild("Settings") :: Frame)
end

local function makeHudEntry(
	name: string,
	label: string,
	position: UDim2,
	anchor: Vector2,
	fill: Color3,
	onClick: () -> ()
): TextButton
	local main = buildMain()
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = anchor
	button.Position = position
	button.Size = UDim2.fromOffset(168, 44)
	button.AutoButtonColor = true
	button.TextSize = 18
	button.Text = label
	button.ZIndex = 15
	button.Parent = main
	UITheme.applyChipLook(button, fill)
	UITheme.applyOutlinedTitle(button, UITheme.TITLE)
	button.TextSize = 18
	button.Activated:Connect(function()
		AudioController.play("UiClick")
		onClick()
	end)
	return button
end

local function buildHudEntries()
	-- Bottom-left: Inventory above Settings.
	inventoryEntry = makeHudEntry(
		"InventoryEntry",
		"Inventory",
		UDim2.new(0, 16, 1, -68),
		Vector2.new(0, 1),
		UITheme.CHIP_BG_INVENTORY_BUTTON,
		function()
		if not inventoryPanel then
			return
		end
		local opening = not inventoryPanel:isOpen()
		if settingsPanel then
			settingsPanel:setOpen(false)
		end
		inventoryPanel:setOpen(opening)
		if opening then
			if fieldInspect then
				fieldInspect:hide()
			end
			if monsterInspect then
				monsterInspect:hide()
			end
		end
	end)
	settingsEntry = makeHudEntry(
		"SettingsEntry",
		"Settings",
		UDim2.new(0, 16, 1, -16),
		Vector2.new(0, 1),
		UITheme.CHIP_BG_SETTINGS_BUTTON,
		function()
		if not settingsPanel then
			return
		end
		local opening = not settingsPanel:isOpen()
		if inventoryPanel then
			inventoryPanel:setOpen(false)
		end
		if opening then
			-- Pull fresh statistics (includes live session time) when opening.
			local ok, state = pcall(function()
				return Remotes.getFunction("RequestState"):InvokeServer()
			end)
			if ok and type(state) == "table" and type(state.profile) == "table" then
				applyProfile(state.profile)
			end
		end
		settingsPanel:setOpen(opening)
	end)
end

local function applyLevelState(state: { [string]: any }?)
	if levelPanel and type(state) == "table" then
		levelPanel:applyState(state)
	end
	if type(state) ~= "table" then
		return
	end

	if heartsHud and type(state.playerHealth) == "number" then
		local maxHealth = if type(state.maxPlayerHealth) == "number"
			then state.maxPlayerHealth
			else ProgressConfig.MAX_PLAYER_HEALTH
		heartsHud:setHealth(state.playerHealth, maxHealth)
	end

	if type(state.reward) == "table" and rewardPopup then
		local reward = state.reward :: { [string]: any }
		if type(reward.clearedLevel) == "number" and type(reward.brains) == "number" then
			rewardPopup:show(
				reward.clearedLevel,
				reward.brains,
				if type(reward.leftoverBrains) == "number" then reward.leftoverBrains else 0
			)
			introHoldForReward = true
			if type(reward.unlockedBrainrotId) == "string" then
				enqueueIntro("brainrot", reward.unlockedBrainrotId)
			end
			enqueueIntroList("brainrot", state.introducedBrainrotIds)
			enqueueIntroList("mechanic", state.introducedMechanicIds)
			enqueueIntroList("monster", state.introducedMonsterIds)
		end
	elseif state.phase ~= Constants.PHASE.Victory and rewardPopup then
		rewardPopup:hide()
		introHoldForReward = false
		enqueueIntroList("brainrot", state.introducedBrainrotIds)
		enqueueIntroList("mechanic", state.introducedMechanicIds)
		enqueueIntroList("monster", state.introducedMonsterIds)
		pumpIntros()
	else
		enqueueIntroList("brainrot", state.introducedBrainrotIds)
		enqueueIntroList("mechanic", state.introducedMechanicIds)
		enqueueIntroList("monster", state.introducedMonsterIds)
		pumpIntros()
	end

	local phase = state.phase
	if type(phase) == "string" then
		local isActive = phase == Constants.PHASE.Active
		local canSelect = isActive or phase == Constants.PHASE.Countdown
		PlacementController.setPlacementAllowed(isActive)
		PlacementController.setSelectionAllowed(canSelect)
		PlacementController.setWeather(if type(state.weather) == "string" then state.weather else nil)
		if inventoryPanel then
			inventoryPanel:setLoadoutLocked(isActive)
		end

		if lastLevelPhase ~= phase then
			if phase == Constants.PHASE.Victory then
				AudioController.play("Victory")
				AudioController.setBossMusic(false)
			elseif phase == Constants.PHASE.Defeat then
				AudioController.play("Defeat")
				AudioController.setBossMusic(false)
				if gameOverPopup then
					local day = if type(state.levelNumber) == "number" then state.levelNumber else 1
					gameOverPopup:show(day)
				end
			elseif phase == Constants.PHASE.Preparation or phase == Constants.PHASE.Countdown then
				AudioController.setBossMusic(false)
				if gameOverPopup and lastLevelPhase == Constants.PHASE.Defeat then
					-- Rewind finished server-side; hide if client FX already done.
					if not gameOverPopup.rewinding then
						gameOverPopup:hide()
					end
				end
			end
			lastLevelPhase = phase
		end
	end

	if state.bigWaveWarning == true and not lastBigWaveWarning then
		AudioController.play("BigWave")
		AudioController.setBossMusic(true)
	end
	lastBigWaveWarning = state.bigWaveWarning == true

	if phase == Constants.PHASE.Countdown and type(state.countdownRemaining) == "number" then
		local shown = math.clamp(
			math.floor(state.countdownRemaining),
			0,
			math.max(0, LevelConfig.COUNTDOWN_TIME - 1)
		)
		if lastCountdownCeil ~= shown then
			AudioController.play("CountdownTick")
			lastCountdownCeil = shown
		end
	else
		lastCountdownCeil = nil
	end
end

function UIController.init()
	coinCounter = buildCoinCounter()
	brainsCounter = buildBrainsCounter()
	speedHud = buildSpeedHud()
	magnetHud = buildMagnetHud()
	damageMeterHud = buildDamageMeter()
	shop = buildShop()
	plantToast = PlantToast.new(buildMain())
	fieldInspect = BrainrotInspect.new(buildMain())
	fieldInspect:dockField()
	monsterInspect = MonsterInspect.new(buildMain())
	monsterInspect:dockField()
	levelPanel = buildLevelPanel()
	heartsHud = buildHearts()
	inventoryPanel = buildInventory()
	local function requestEvolve(brainrotId: string, rarity: string)
		Remotes.getEvent("EvolveBrainrot"):FireServer(brainrotId, rarity)
	end
	fieldInspect:setEvolveHandler(requestEvolve)
	inventoryPanel.inspect:setEvolveHandler(requestEvolve)
	rewardPopup = buildRewardPopup()
	rewardPopup.onContinue = function()
		introHoldForReward = false
		Remotes.getEvent("ContinueVictory"):FireServer()
		pumpIntros()
	end
	unlockPopup = buildUnlockPopup()
	monsterIntroPopup = buildMonsterIntroPopup()
	mechanicIntroPopup = buildMechanicIntroPopup()
	if unlockPopup then
		unlockPopup.onHidden = onIntroHidden
	end
	if monsterIntroPopup then
		monsterIntroPopup.onHidden = onIntroHidden
	end
	if mechanicIntroPopup then
		mechanicIntroPopup.onHidden = onIntroHidden
	end
	gameOverPopup = buildGameOverPopup()
	progressionStore = buildProgressionStore()
	settingsPanel = buildSettings()
	buildHudEntries()
end

function UIController.start()
	Remotes.getEvent("CoinsUpdated").OnClientEvent:Connect(function(amount: number)
		if spendPending and lastBalance and amount < lastBalance then
			if coinCounter then
				coinCounter:showDelta(amount - lastBalance)
			end
		end
		spendPending = false
		lastBalance = amount
		setBalance(amount)
	end)

	UIEvents.coinDelta:Connect(function(delta: number)
		if coinCounter then
			coinCounter:showDelta(delta)
		end
	end)

	UIEvents.pendingSpend:Connect(function()
		spendPending = true
	end)

	UIEvents.plantFailed:Connect(function(reason: string)
		if plantToast then
			plantToast:push(reason)
		end
	end)

	UIEvents.fieldInspect:Connect(function(model: Model?)
		if not model then
			if fieldInspect then
				fieldInspect:hide()
			end
			if monsterInspect then
				monsterInspect:hide()
			end
			return
		end
		if inventoryPanel then
			inventoryPanel:setOpen(false)
		end
		if settingsPanel then
			settingsPanel:setOpen(false)
		end

		local monsterId = model:GetAttribute("MonsterId")
		if type(monsterId) == "string" then
			local monsterDef = Monsters.get(monsterId)
			if not monsterDef or not monsterInspect then
				if fieldInspect then
					fieldInspect:hide()
				end
				if monsterInspect then
					monsterInspect:hide()
				end
				return
			end
			if fieldInspect then
				fieldInspect:hide()
			end
			monsterInspect:show({
				definition = monsterDef,
				healthModel = model,
			})
			return
		end

		if not fieldInspect then
			return
		end
		local brainrotId = model:GetAttribute("BrainrotId")
		if type(brainrotId) ~= "string" then
			fieldInspect:hide()
			if monsterInspect then
				monsterInspect:hide()
			end
			return
		end
		local definition = Brainrots.get(brainrotId)
		if not definition then
			fieldInspect:hide()
			if monsterInspect then
				monsterInspect:hide()
			end
			return
		end
		if monsterInspect then
			monsterInspect:hide()
		end
		fieldInspect:show({
			definition = definition,
			mode = "field",
			healthModel = model,
			totalXp = lastBrainrotXp[brainrotId] or 0,
			claimedRarities = lastEvolutions[brainrotId] or {},
		})
	end)

	Remotes.getEvent("PlaceBrainrotFailed").OnClientEvent:Connect(function(reason: unknown)
		if type(reason) == "string" and plantToast then
			plantToast:push(reason)
		end
	end)

	Remotes.getEvent("PlantCooldownsUpdated").OnClientEvent:Connect(function(payload: unknown)
		local map = if type(payload) == "table" then payload :: { [string]: number } else nil
		PlacementController.setPlantCooldowns(map)
		if shop then
			shop:setPlantCooldowns(map)
		end
	end)

	Remotes.getEvent("LevelStateChanged").OnClientEvent:Connect(function(state: unknown)
		if type(state) == "table" then
			applyLevelState(state)
		end
	end)

	Remotes.getEvent("ProfileUpdated").OnClientEvent:Connect(function(profile: unknown)
		if type(profile) == "table" then
			applyProfile(profile :: { [string]: any })
		end
	end)

	Remotes.getEvent("OpenProgressionStore").OnClientEvent:Connect(function(shopKind: unknown, anchor: unknown)
		if type(shopKind) ~= "string" or not progressionStore then
			return
		end
		if inventoryPanel then
			inventoryPanel:setOpen(false)
		end
		if settingsPanel then
			settingsPanel:setOpen(false)
		end
		if fieldInspect then
			fieldInspect:hide()
		end
		if monsterInspect then
			monsterInspect:hide()
		end
		local position = if typeof(anchor) == "Vector3" then anchor else nil
		progressionStore:open(shopKind, position)
	end)

	Remotes.getEvent("StorePurchaseSucceeded").OnClientEvent:Connect(function(cost: unknown)
		if type(cost) == "number" and brainsCounter then
			brainsCounter:showDelta(-cost)
		end
		if progressionStore and progressionStore:isOpen() then
			progressionStore:showPurchaseFeedback(true)
		end
	end)

	Remotes.getEvent("StorePurchaseFailed").OnClientEvent:Connect(function(reason: unknown)
		if type(reason) ~= "string" then
			return
		end
		if reason == "Not enough brains" then
			if progressionStore and progressionStore:isOpen() then
				progressionStore:showPurchaseFeedback(false)
			else
				AudioController.play("PurchaseError")
				if plantToast then
					plantToast:push(reason)
				end
			end
			return
		end
		if plantToast then
			plantToast:push(reason)
		end
		if not (progressionStore and progressionStore:isOpen()) then
			AudioController.play("PurchaseError")
		end
	end)

	PlacementController.selectionChanged:Connect(function(id: string?)
		selectedId = id
		if shop then
			shop:setSelected(id)
			shop:setCancelVisible(id ~= nil or PlacementController.isShovelMode())
		end
	end)

	PlacementController.shovelModeChanged:Connect(function(active: boolean)
		if shop then
			shop:setShovelActive(active)
			shop:setCancelVisible(active or selectedId ~= nil)
		end
	end)

	InputController.magnetAction:Connect(requestMagnet)

	Remotes.getEvent("MagnetStateChanged").OnClientEvent:Connect(function(payload: unknown)
		applyMagnetState(payload :: any)
	end)

	Remotes.getEvent("DamageMeterUpdated").OnClientEvent:Connect(function(payload: unknown)
		applyDamageMeter(payload :: any)
	end)

	local ok, state = pcall(function()
		return Remotes.getFunction("RequestState"):InvokeServer()
	end)
	if ok and type(state) == "table" then
		if type(state.coins) == "number" then
			lastBalance = state.coins
			setBalance(state.coins)
		end
		if type(state.level) == "table" then
			applyLevelState(state.level)
		end
		if type(state.profile) == "table" then
			applyProfile(state.profile)
		end
		if type(state.plantCooldowns) == "table" then
			local map = state.plantCooldowns :: { [string]: number }
			PlacementController.setPlantCooldowns(map)
			if shop then
				shop:setPlantCooldowns(map)
			end
		end
		if type(state.magnet) == "table" then
			applyMagnetState(state.magnet)
		end
		if type(state.damageMeter) == "table" then
			applyDamageMeter(state.damageMeter)
		end
	end

	task.spawn(function()
		while true do
			task.wait(0.1)
			if shop then
				shop:refresh()
			end
			if magnetHud then
				magnetHud:tick()
			end
		end
	end)

	log:info("started")
end

return UIController
