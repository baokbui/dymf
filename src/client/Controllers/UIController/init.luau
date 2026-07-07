--!strict
--[[
	UIController
	Owns the main UI. It only displays server-provided state and forwards intent
	via Remotes / controllers — never any gameplay logic.

	Milestone 3 added the coin counter (authoritative balance from CoinsUpdated,
	seeded by the RequestState pull). Milestone 4 adds the Shop panel: it lists
	the Brainrot roster from the shared registry and routes card clicks to
	PlacementController, mirroring the selection back into the card highlight.

	Milestone 3 added the coin counter (authoritative balance from CoinsUpdated,
	seeded by the RequestState pull). Milestone 4 adds the Shop panel. Milestone 8
	adds the Level panel (current level, Start button, progress bar, bottom-right).

	Milestones 3-4, 8, 15.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Constants = require(Shared.Constants)
local Logger = require(Shared.Utilities.Logger)

local Shop = require(script.Shop)
local Level = require(script.Level)
local PlacementController = require(script.Parent.PlacementController)

local UIController = {}
UIController.Name = "UIController"

local log = Logger.new(UIController.Name)

local localPlayer = Players.LocalPlayer
local amountLabel: TextLabel? = nil
local shop: Shop.Shop? = nil
local levelPanel: Level.LevelPanel? = nil
local selectedId: string? = nil

local function buildCoinCounter(): TextLabel
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local mainUI = playerGui:WaitForChild("MainUI")
	local frame = mainUI:WaitForChild("Coins") :: Frame

	frame.Visible = true
	frame.AnchorPoint = Vector2.new(0, 0)
	frame.Position = UDim2.fromOffset(16, 16)
	frame.Size = UDim2.fromOffset(168, 52)
	frame.BackgroundColor3 = Color3.fromRGB(22, 24, 34)
	frame.BackgroundTransparency = 0.2

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 12, 0.5, 0)
	icon.Size = UDim2.fromOffset(28, 28)
	icon.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
	icon.Parent = frame
	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(1, 0)
	iconCorner.Parent = icon

	local label = Instance.new("TextLabel")
	label.Name = "Amount"
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, 52, 0.5, 0)
	label.Size = UDim2.new(1, -64, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 22
	label.TextColor3 = Color3.fromRGB(255, 215, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = "0"
	label.Parent = frame

	return label
end

local function setBalance(amount: number)
	if amountLabel then
		amountLabel.Text = string.format("%d", amount)
	end
	if shop then
		shop:setBalance(amount)
	end
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
	if type(state) == "table" and type(state.phase) == "string" then
		PlacementController.setPlacementAllowed(state.phase == Constants.PHASE.Active)
	end
end

function UIController.init()
	amountLabel = buildCoinCounter()
	shop = buildShop()
	levelPanel = buildLevelPanel()
end

function UIController.start()
	Remotes.getEvent("CoinsUpdated").OnClientEvent:Connect(function(amount: number)
		setBalance(amount)
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
		setBalance(state.coins)
	end
	if ok and type(state) == "table" and type(state.level) == "table" then
		applyLevelState(state.level)
	end

	log:info("started")
end

return UIController
