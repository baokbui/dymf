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
local Remotes = require(Shared.Remotes)
local Constants = require(Shared.Constants)
local ProgressConfig = require(Shared.Config.ProgressConfig)
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
local GameOverPopup = require(script.GameOverPopup)
local ProgressionStore = require(script.ProgressionStore)
local PlantToast = require(script.PlantToast)
local PlacementController = require(script.Parent.PlacementController)
local AudioController = require(script.Parent.AudioController)

local UIController = {}
UIController.Name = "UIController"

local log = Logger.new(UIController.Name)

local localPlayer = Players.LocalPlayer
local coinCounter: CoinCounter.CoinCounter? = nil
local brainsCounter: BrainsCounter.BrainsCounter? = nil
local speedHud: SpeedHud.SpeedHud? = nil
local shop: Shop.Shop? = nil
local levelPanel: Level.LevelPanel? = nil
local heartsHud: Hearts.HeartsHud? = nil
local settingsPanel: Settings.SettingsPanel? = nil
local inventoryPanel: Inventory.InventoryPanel? = nil
local rewardPopup: RewardPopup.RewardPopupHud? = nil
local unlockPopup: UnlockPopup.UnlockPopupHud? = nil
local monsterIntroPopup: MonsterIntroPopup.MonsterIntroPopupHud? = nil
local gameOverPopup: GameOverPopup.GameOverPopupHud? = nil
local progressionStore: ProgressionStore.ProgressionStoreHud? = nil
local plantToast: PlantToast.PlantToastHud? = nil
local settingsEntry: TextButton? = nil
local inventoryEntry: TextButton? = nil
local selectedId: string? = nil
local lastBalance: number? = nil
local spendPending = false
local lastLevelPhase: string? = nil
local lastCountdownCeil: number? = nil
local lastBigWaveWarning = false

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
	if speedHud then
		local upgrades: { [string]: number } = {}
		if type(profile.upgrades) == "table" then
			for key, value in (profile.upgrades :: { [string]: any }) do
				if type(key) == "string" and type(value) == "number" then
					upgrades[key] = value
				end
			end
		end
		speedHud:applyUpgrades(upgrades)
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
			enqueueIntroList("monster", state.introducedMonsterIds)
		end
	elseif state.phase ~= Constants.PHASE.Victory and rewardPopup then
		rewardPopup:hide()
		introHoldForReward = false
		enqueueIntroList("brainrot", state.introducedBrainrotIds)
		enqueueIntroList("monster", state.introducedMonsterIds)
		pumpIntros()
	else
		enqueueIntroList("brainrot", state.introducedBrainrotIds)
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
	shop = buildShop()
	plantToast = PlantToast.new(buildMain())
	levelPanel = buildLevelPanel()
	heartsHud = buildHearts()
	inventoryPanel = buildInventory()
	rewardPopup = buildRewardPopup()
	rewardPopup.onContinue = function()
		introHoldForReward = false
		Remotes.getEvent("ContinueVictory"):FireServer()
		pumpIntros()
	end
	unlockPopup = buildUnlockPopup()
	monsterIntroPopup = buildMonsterIntroPopup()
	if unlockPopup then
		unlockPopup.onHidden = onIntroHidden
	end
	if monsterIntroPopup then
		monsterIntroPopup.onHidden = onIntroHidden
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
		local position = if typeof(anchor) == "Vector3" then anchor else nil
		progressionStore:open(shopKind, position)
	end)

	Remotes.getEvent("StorePurchaseSucceeded").OnClientEvent:Connect(function(cost: unknown)
		if type(cost) == "number" and brainsCounter then
			brainsCounter:showDelta(-cost)
		end
		if progressionStore then
			progressionStore:showPurchaseFeedback(true)
		end
	end)

	Remotes.getEvent("StorePurchaseFailed").OnClientEvent:Connect(function(reason: unknown)
		if type(reason) ~= "string" then
			return
		end
		if reason == "Not enough brains" then
			if progressionStore then
				progressionStore:showPurchaseFeedback(false)
			end
			return
		end
		if plantToast then
			plantToast:push(reason)
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
	end

	task.spawn(function()
		while true do
			task.wait(0.1)
			if shop then
				shop:refresh()
			end
		end
	end)

	log:info("started")
end

return UIController
