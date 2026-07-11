--!strict
--[[
	UIController
	Owns the main UI. It only displays server-provided state and forwards intent
	via Remotes / controllers — never any gameplay logic.

	Milestone 3 added the coin counter (authoritative balance from CoinsUpdated,
	seeded by the RequestState pull). Milestone 4 adds the Shop panel: it lists
	the Brainrot roster from the shared registry and routes card clicks to
	PlacementController, mirroring the selection back into the card highlight.

	Milestone 8 adds the Level panel (current level, Start button, progress bar,
	bottom-right).

	Milestones 3-4, 8, 15.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Constants = require(Shared.Constants)
local Logger = require(Shared.Utilities.Logger)

local UIEvents = require(script.Parent.Parent.UIEvents)
local Shop = require(script.Shop)
local Level = require(script.Level)
local CoinCounter = require(script.CoinCounter)
local PlacementController = require(script.Parent.PlacementController)
local AudioController = require(script.Parent.AudioController)

local UIController = {}
UIController.Name = "UIController"

local log = Logger.new(UIController.Name)

local localPlayer = Players.LocalPlayer
local coinCounter: CoinCounter.CoinCounter? = nil
local shop: Shop.Shop? = nil
local levelPanel: Level.LevelPanel? = nil
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

local function buildCoinCounter(): CoinCounter.CoinCounter
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local mainUI = playerGui:WaitForChild("MainUI")
	local frame = mainUI:WaitForChild("Coins") :: Frame
	return CoinCounter.new(frame)
end

local function buildShop(): Shop.Shop
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local mainUI = playerGui:WaitForChild("MainUI")
	local frame = mainUI:WaitForChild("Shop") :: Frame

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
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local mainUI = playerGui:WaitForChild("MainUI")
	local frame = mainUI:WaitForChild("LevelUI") :: Frame
	return Level.new(frame)
end

local function applyLevelState(state: { [string]: any }?)
	if levelPanel and type(state) == "table" then
		levelPanel:applyState(state)
	end
	if type(state) ~= "table" then
		return
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

	-- Pull the current balance now that the handler is connected.
	local ok, state = pcall(function()
		return Remotes.getFunction("RequestState"):InvokeServer()
	end)
	if ok and type(state) == "table" and type(state.coins) == "number" then
		lastBalance = state.coins
		setBalance(state.coins)
	end
	if ok and type(state) == "table" and type(state.level) == "table" then
		applyLevelState(state.level)
	end

	log:info("started")
end

return UIController
