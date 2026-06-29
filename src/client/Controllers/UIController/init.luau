--!strict
--[[
	UIController
	Owns the main UI. It only displays server-provided state and forwards intent
	via Remotes — never any gameplay logic. Milestone 3 adds the coin counter:
	it reflects the authoritative balance from CoinsUpdated and pulls the initial
	value with RequestState (avoiding the join-time race).

	Milestones 3-4, 15.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Logger = require(Shared.Utilities.Logger)

local UIController = {}
UIController.Name = "UIController"

local log = Logger.new(UIController.Name)

local localPlayer = Players.LocalPlayer
local amountLabel: TextLabel? = nil

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
end

function UIController.init()
	amountLabel = buildCoinCounter()
end

function UIController.start()
	Remotes.getEvent("CoinsUpdated").OnClientEvent:Connect(function(amount: number)
		setBalance(amount)
	end)

	-- Pull the current balance now that the handler is connected.
	local ok, state = pcall(function()
		return Remotes.getFunction("RequestState"):InvokeServer()
	end)
	if ok and type(state) == "table" and type(state.coins) == "number" then
		setBalance(state.coins)
	end

	log:info("started")
end

return UIController
