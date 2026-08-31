--!strict
--[[
	Level
	Campaign day UI. Bottom-right panel with current day, Start Day button,
	spawn-group progress, and big-wave warning. Cartoon look via UITheme.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local LevelConfig = require(Shared.Config.LevelConfig)
local Remotes = require(Shared.Remotes)
local UITheme = require(Shared.Config.UITheme)

local AudioController = require(script.Parent.Parent.AudioController)

local Level = {}
Level.__index = Level

local PHASE = Constants.PHASE

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
		startCountdownLabel: TextLabel,
	},
	Level
))

function Level.new(parent: Frame): LevelPanel
	parent.Visible = true
	parent.AnchorPoint = Vector2.new(1, 1)
	parent.Position = UDim2.new(1, -16, 1, -16)
	parent.Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT_PREP)
	UITheme.applyPanelLook(parent)

	local startCountdownLabel = Instance.new("TextLabel")
	startCountdownLabel.Name = "StartCountdown"
	startCountdownLabel.AnchorPoint = Vector2.new(1, 1)
	startCountdownLabel.Position = UDim2.new(1, 0, 0, -8)
	startCountdownLabel.Size = UDim2.fromOffset(PANEL_WIDTH, 40)
	startCountdownLabel.BackgroundTransparency = 1
	startCountdownLabel.TextSize = 26
	startCountdownLabel.Text = "Day starting in 3"
	startCountdownLabel.Visible = false
	startCountdownLabel.Parent = parent
	UITheme.applyOutlinedTitle(startCountdownLabel, UITheme.DANGER)
	startCountdownLabel.TextSize = 26

	local warningBanner = Instance.new("TextLabel")
	warningBanner.Name = "BigWaveWarning"
	warningBanner.AnchorPoint = Vector2.new(1, 1)
	warningBanner.Position = UDim2.new(1, 0, 0, -8)
	warningBanner.Size = UDim2.fromOffset(PANEL_WIDTH, 28)
	warningBanner.TextSize = 16
	warningBanner.Text = "A huge wave is approaching!"
	warningBanner.Visible = false
	warningBanner.Parent = parent
	UITheme.applyButtonLook(warningBanner, UITheme.DANGER, UITheme.CORNER_BUTTON)
	UITheme.applyOutlinedTitle(warningBanner)

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelTitle"
	levelLabel.Size = UDim2.new(1, -140, 0, 24)
	levelLabel.Position = UDim2.fromOffset(16, 12)
	levelLabel.BackgroundTransparency = 1
	levelLabel.TextSize = 18
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.Text = "Day 1"
	levelLabel.Parent = parent
	UITheme.applyOutlinedTitle(levelLabel)

	local phaseLabel = Instance.new("TextLabel")
	phaseLabel.Name = "Phase"
	phaseLabel.Size = UDim2.new(1, -140, 0, 18)
	phaseLabel.Position = UDim2.fromOffset(16, 38)
	phaseLabel.BackgroundTransparency = 1
	phaseLabel.TextSize = 14
	phaseLabel.TextXAlignment = Enum.TextXAlignment.Left
	phaseLabel.Text = "Start the day to plant and defend"
	phaseLabel.Parent = parent
	UITheme.applyBodyText(phaseLabel, UITheme.SUBTEXT)

	local progressBackground = Instance.new("Frame")
	progressBackground.Name = "ProgressBackground"
	progressBackground.AnchorPoint = Vector2.new(0, 1)
	progressBackground.Position = UDim2.new(0, 16, 1, -12)
	progressBackground.Size = UDim2.new(1, -32, 0, 14)
	progressBackground.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	progressBackground.BorderSizePixel = 0
	progressBackground.Visible = false
	progressBackground.Parent = parent
	UITheme.styleCorner(progressBackground, 8)
	UITheme.applyStroke(progressBackground, UITheme.STROKE_CARD)

	local progressFill = Instance.new("Frame")
	progressFill.Name = "ProgressFill"
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.BackgroundColor3 = UITheme.SUCCESS
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBackground
	UITheme.styleCorner(progressFill, 8)

	local startButton = Instance.new("TextButton")
	startButton.Name = "StartButton"
	startButton.AnchorPoint = Vector2.new(1, 0.5)
	startButton.Position = UDim2.new(1, -12, 0.5, 0)
	startButton.Size = UDim2.fromOffset(120, 40)
	startButton.TextSize = 16
	startButton.Text = "Start Day"
	startButton.Parent = parent
	UITheme.applyButtonLook(startButton, UITheme.SUCCESS)
	UITheme.applyOutlinedTitle(startButton)

	startButton.MouseButton1Click:Connect(function()
		AudioController.play("LevelStart")
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
		startCountdownLabel = startCountdownLabel,
	}, Level)
end

local function startCountdownShown(remaining: number): number
	return math.clamp(math.floor(remaining), 0, math.max(0, LevelConfig.COUNTDOWN_TIME - 1))
end

local function phaseMessage(phase: string, _countdownRemaining: number?): string
	if phase == PHASE.Preparation then
		return "Start the day to plant and defend"
	elseif phase == PHASE.Countdown then
		return "Get ready!"
	elseif phase == PHASE.Active then
		return "Plant before they leave the forest!"
	elseif phase == PHASE.Victory then
		return "Victory!"
	elseif phase == PHASE.Defeat then
		return "Defeat"
	end
	return phase
end

function Level.applyState(self: LevelPanel, state: { [string]: any })
	local levelNumber = state.levelNumber
	if type(levelNumber) == "number" then
		self.levelLabel.Text = string.format("Day %d", levelNumber)
	end

	local phase = state.phase
	if type(phase) ~= "string" then
		return
	end

	local countdown = if type(state.countdownRemaining) == "number" then state.countdownRemaining else nil
	self.phaseLabel.Text = phaseMessage(phase, countdown)

	local countingDown = phase == PHASE.Countdown and countdown ~= nil
	self.startCountdownLabel.Visible = countingDown
	if countingDown and countdown then
		self.startCountdownLabel.Text = string.format("Day starting in %d", startCountdownShown(countdown))
	end

	if phase == PHASE.Victory then
		UITheme.applyOutlinedTitle(self.phaseLabel, UITheme.SUCCESS)
		self.phaseLabel.Font = Enum.Font.GothamBold
		self.phaseLabel.TextSize = 14
	elseif phase == PHASE.Defeat then
		UITheme.applyOutlinedTitle(self.phaseLabel, UITheme.DANGER)
		self.phaseLabel.Font = Enum.Font.GothamBold
		self.phaseLabel.TextSize = 14
	else
		UITheme.applyBodyText(self.phaseLabel, UITheme.SUBTEXT)
		self.phaseLabel.TextSize = 14
	end

	-- Defeat uses GameOverPopup Rewind; Start Day only in Preparation.
	self.startButton.Visible = state.canStart == true and phase ~= PHASE.Defeat
	self.startButton.Text = "Start Day"
	UITheme.applyButtonLook(self.startButton, UITheme.SUCCESS)
	UITheme.applyOutlinedTitle(self.startButton)
	self.startButton.TextSize = 16
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
