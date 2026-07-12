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
local Logger = require(Shared.Utilities.Logger)

local UIEvents = require(script.Parent.Parent.UIEvents)
local Shop = require(script.Shop)
local Level = require(script.Level)
local CoinCounter = require(script.CoinCounter)
local Hearts = require(script.Hearts)
local Settings = require(script.Settings)
local Inventory = require(script.Inventory)
local RewardPopup = require(script.RewardPopup)
local PlacementController = require(script.Parent.PlacementController)
local AudioController = require(script.Parent.AudioController)

local UIController = {}
UIController.Name = "UIController"

local log = Logger.new(UIController.Name)

local localPlayer = Players.LocalPlayer
local coinCounter: CoinCounter.CoinCounter? = nil
local shop: Shop.Shop? = nil
local levelPanel: Level.LevelPanel? = nil
local heartsHud: Hearts.HeartsHud? = nil
local settingsPanel: Settings.SettingsPanel? = nil
local inventoryPanel: Inventory.InventoryPanel? = nil
local rewardPopup: RewardPopup.RewardPopupHud? = nil
local settingsEntry: TextButton? = nil
local inventoryEntry: TextButton? = nil
local selectedId: string? = nil
local lastBalance: number? = nil
local spendPending = false
local lastLevelPhase: string? = nil
local lastCountdownCeil: number? = nil
local lastBigWaveWarning = false

local function setBalance(amount: number)
	if coinCounter then
		coinCounter:setBalance(amount)
	end
	if shop then
		shop:setBalance(amount)
	end
end

local function applyProfile(profile: { [string]: any }?)
	if type(profile) ~= "table" then
		return
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

local function buildShop(): Shop.Shop
	local frame = buildMain():WaitForChild("Shop") :: Frame
	return Shop.new(frame, {
		onCardClicked = function(id: string)
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

local function buildSettings(): Settings.SettingsPanel
	return Settings.new(buildMain():WaitForChild("Settings") :: Frame)
end

local function makeHudEntry(name: string, label: string, y: number, onClick: () -> ()): TextButton
	local main = buildMain()
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = Vector2.new(0, 0)
	button.Position = UDim2.fromOffset(16, y)
	button.Size = UDim2.fromOffset(168, 44)
	button.BackgroundColor3 = Color3.fromRGB(22, 24, 34)
	button.BackgroundTransparency = 0.2
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.TextSize = 18
	button.TextColor3 = Color3.fromRGB(235, 238, 245)
	button.Text = label
	button.ZIndex = 15
	button.Parent = main
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button
	button.Activated:Connect(function()
		AudioController.play("UiClick")
		onClick()
	end)
	return button
end

local function buildHudEntries()
	-- Coins (16,16 h52) → Hearts (16,76 h48) → Inventory → Settings (8px gaps).
	inventoryEntry = makeHudEntry("InventoryEntry", "Inventory", 132, function()
		if not inventoryPanel then
			return
		end
		local opening = not inventoryPanel:isOpen()
		if settingsPanel then
			settingsPanel:setOpen(false)
		end
		inventoryPanel:setOpen(opening)
	end)
	settingsEntry = makeHudEntry("SettingsEntry", "Settings", 184, function()
		if not settingsPanel then
			return
		end
		local opening = not settingsPanel:isOpen()
		if inventoryPanel then
			inventoryPanel:setOpen(false)
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
			rewardPopup:show(reward.clearedLevel, reward.brains)
			task.delay(3, function()
				if rewardPopup then
					rewardPopup:hide()
				end
			end)
		end
	elseif state.phase ~= Constants.PHASE.Victory and rewardPopup then
		rewardPopup:hide()
	end

	local phase = state.phase
	if type(phase) == "string" then
		PlacementController.setPlacementAllowed(phase == Constants.PHASE.Active)

		if lastLevelPhase ~= phase then
			if phase == Constants.PHASE.Victory then
				AudioController.play("Victory")
				AudioController.setBossMusic(false)
			elseif phase == Constants.PHASE.Defeat then
				AudioController.play("Defeat")
				AudioController.setBossMusic(false)
			elseif phase == Constants.PHASE.Preparation or phase == Constants.PHASE.Countdown then
				AudioController.setBossMusic(false)
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
		local ceil = math.ceil(state.countdownRemaining)
		if lastCountdownCeil ~= ceil and ceil > 0 then
			AudioController.play("CountdownTick")
		end
		lastCountdownCeil = ceil
	else
		lastCountdownCeil = nil
	end
end

function UIController.init()
	coinCounter = buildCoinCounter()
	shop = buildShop()
	levelPanel = buildLevelPanel()
	heartsHud = buildHearts()
	inventoryPanel = buildInventory()
	rewardPopup = buildRewardPopup()
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

	PlacementController.selectionChanged:Connect(function(id: string?)
		selectedId = id
		if shop then
			shop:setSelected(id)
			shop:setCancelVisible(id ~= nil)
		end
	end)

	PlacementController.shovelModeChanged:Connect(function(active: boolean)
		if shop then
			shop:setShovelActive(active)
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
	end

	log:info("started")
end

return UIController
