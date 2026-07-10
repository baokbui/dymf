--!strict
--[[
	Level
	Level campaign UI for UIController. Bottom-right panel with the current level,
	a green Start Level button, spawn-group progress bar, and big-wave warning.
	Sends Start Level intent via Remotes — no gameplay logic on the client.

	Milestone 8.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Remotes = require(Shared.Remotes)

local Level = {}
Level.__index = Level

local PHASE = Constants.PHASE

local PANEL_BG = Color3.fromRGB(18, 20, 30)
local TEXT_COLOR = Color3.fromRGB(235, 238, 245)
local SUBTEXT_COLOR = Color3.fromRGB(120, 200, 255)
local START_BUTTON_COLOR = Color3.fromRGB(90, 200, 120)
local RESTART_BUTTON_COLOR = Color3.fromRGB(220, 70, 70)
local PROGRESS_BG = Color3.fromRGB(40, 44, 58)
local PROGRESS_FILL = Color3.fromRGB(90, 200, 120)
local WARNING_COLOR = Color3.fromRGB(255, 90, 90)
local VICTORY_COLOR = Color3.fromRGB(120, 220, 140)
local DEFEAT_COLOR = Color3.fromRGB(255, 110, 110)

local PANEL_WIDTH = 360
local PANEL_HEIGHT_PREP = 72
local PANEL_HEIGHT_ACTIVE = 100

export type LevelPanel = typeof(setmetatable(
	{} :: {
		frame: Frame,
		levelLabel: TextLabel,
		phaseLabel: TextLabel,
		progressBackground: Frame,
		progressFill: Frame,
		startButton: TextButton,
		warningBanner: TextLabel,
	},
	Level
))

local function styleCorner(instance: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

function Level.new(parent: Frame): LevelPanel
	parent.Visible = true
	parent.AnchorPoint = Vector2.new(1, 1)
	parent.Position = UDim2.new(1, -16, 1, -16)
	parent.Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT_PREP)
	parent.BackgroundColor3 = PANEL_BG
	parent.BackgroundTransparency = 0.12
	styleCorner(parent, 12)

	local warningBanner = Instance.new("TextLabel")
	warningBanner.Name = "BigWaveWarning"
	warningBanner.AnchorPoint = Vector2.new(1, 1)
	warningBanner.Position = UDim2.new(1, 0, 0, -8)
	warningBanner.Size = UDim2.fromOffset(PANEL_WIDTH, 28)
	warningBanner.BackgroundColor3 = WARNING_COLOR
	warningBanner.BackgroundTransparency = 0.15
	warningBanner.Font = Enum.Font.GothamBold
	warningBanner.TextSize = 16
	warningBanner.TextColor3 = Color3.new(1, 1, 1)
	warningBanner.Text = "A huge wave is approaching!"
	warningBanner.Visible = false
	warningBanner.Parent = parent
	styleCorner(warningBanner, 8)

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelTitle"
	levelLabel.Size = UDim2.new(1, -140, 0, 24)
	levelLabel.Position = UDim2.fromOffset(16, 12)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.TextSize = 18
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.TextColor3 = TEXT_COLOR
	levelLabel.Text = "Level 1"
	levelLabel.Parent = parent

	local phaseLabel = Instance.new("TextLabel")
	phaseLabel.Name = "Phase"
	phaseLabel.Size = UDim2.new(1, -140, 0, 18)
	phaseLabel.Position = UDim2.fromOffset(16, 38)
	phaseLabel.BackgroundTransparency = 1
	phaseLabel.Font = Enum.Font.Gotham
	phaseLabel.TextSize = 14
	phaseLabel.TextXAlignment = Enum.TextXAlignment.Left
	phaseLabel.TextColor3 = SUBTEXT_COLOR
	phaseLabel.Text = "Start the level to plant and defend"
	phaseLabel.Parent = parent

	local progressBackground = Instance.new("Frame")
	progressBackground.Name = "ProgressBackground"
	progressBackground.AnchorPoint = Vector2.new(0, 1)
	progressBackground.Position = UDim2.new(0, 16, 1, -12)
	progressBackground.Size = UDim2.new(1, -32, 0, 14)
	progressBackground.BackgroundColor3 = PROGRESS_BG
	progressBackground.BorderSizePixel = 0
	progressBackground.Visible = false
	progressBackground.Parent = parent
	styleCorner(progressBackground, 6)

	local progressFill = Instance.new("Frame")
	progressFill.Name = "ProgressFill"
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.BackgroundColor3 = PROGRESS_FILL
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBackground
	styleCorner(progressFill, 6)

	local startButton = Instance.new("TextButton")
	startButton.Name = "StartButton"
	startButton.AnchorPoint = Vector2.new(1, 0.5)
	startButton.Position = UDim2.new(1, -12, 0.5, 0)
	startButton.Size = UDim2.fromOffset(120, 40)
	startButton.BackgroundColor3 = START_BUTTON_COLOR
	startButton.Font = Enum.Font.GothamBold
	startButton.TextSize = 16
	startButton.TextColor3 = Color3.fromRGB(18, 20, 30)
	startButton.Text = "Start Level"
	startButton.Parent = parent
	styleCorner(startButton, 10)

	startButton.MouseButton1Click:Connect(function()
		Remotes.getEvent("StartLevel"):FireServer()
	end)

	return setmetatable({
		frame = parent,
		levelLabel = levelLabel,
		phaseLabel = phaseLabel,
		progressBackground = progressBackground,
		progressFill = progressFill,
		startButton = startButton,
		warningBanner = warningBanner,
	}, Level)
end

local function phaseMessage(phase: string, countdownRemaining: number?): string
	if phase == PHASE.Preparation then
		return "Start the level to plant and defend"
	elseif phase == PHASE.Countdown then
		local n = if countdownRemaining then math.ceil(countdownRemaining) else 0
		return string.format("Starting in %d…", n)
	elseif phase == PHASE.Active then
		return "Defend your house!"
	elseif phase == PHASE.Victory then
		return "Victory!"
	elseif phase == PHASE.Defeat then
		return "Defeat — try again"
	end
	return phase
end

function Level.applyState(self: LevelPanel, state: { [string]: any })
	local levelNumber = state.levelNumber
	local levelName = state.levelName
	if type(levelNumber) == "number" and type(levelName) == "string" then
		self.levelLabel.Text = string.format("Level %d — %s", levelNumber, levelName)
	end

	local phase = state.phase
	if type(phase) ~= "string" then
		return
	end

	local countdown = if type(state.countdownRemaining) == "number" then state.countdownRemaining else nil
	self.phaseLabel.Text = phaseMessage(phase, countdown)

	if phase == PHASE.Victory then
		self.phaseLabel.TextColor3 = VICTORY_COLOR
	elseif phase == PHASE.Defeat then
		self.phaseLabel.TextColor3 = DEFEAT_COLOR
	else
		self.phaseLabel.TextColor3 = SUBTEXT_COLOR
	end

	self.startButton.Visible = state.canStart == true
	if phase == PHASE.Defeat then
		self.startButton.Text = "Restart Level"
		self.startButton.BackgroundColor3 = RESTART_BUTTON_COLOR
	else
		self.startButton.Text = "Start Level"
		self.startButton.BackgroundColor3 = START_BUTTON_COLOR
	end
	self.warningBanner.Visible = state.bigWaveWarning == true

	local showProgress = phase == PHASE.Active
	self.progressBackground.Visible = showProgress
	self.frame.Size = UDim2.fromOffset(
		PANEL_WIDTH,
		if showProgress then PANEL_HEIGHT_ACTIVE else PANEL_HEIGHT_PREP
	)
	if showProgress and type(state.progress) == "number" then
		self.progressFill.Size = UDim2.fromScale(math.clamp(state.progress, 0, 1), 1)
	end
end

return Level
