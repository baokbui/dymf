--!strict
--[[
	Level
	Campaign day UI. Bottom-right panel with current day, Start Day button,
	spawn-group progress, and big-wave warning. Cartoon look via UITheme.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local LevelConfig = require(Shared.Config.LevelConfig)
local ChallengeConfig = require(Shared.Config.DailyChallengeConfig)
local Remotes = require(Shared.Remotes)
local UITheme = require(Shared.Config.UITheme)

local AudioController = require(script.Parent.Parent.AudioController)

local Level = {}
Level.__index = Level

local PHASE = Constants.PHASE

local PANEL_WIDTH = 320
local PANEL_HEIGHT_PREP = 68
local PANEL_HEIGHT_ACTIVE = 94
local CHALLENGE_ROW_HEIGHT = 52
local SUBTITLE_WIDTH = PANEL_WIDTH - 138

export type LevelPanel = typeof(setmetatable(
	{} :: {
		frame: Frame,
		levelLabel: TextLabel,
		phaseLabel: TextLabel,
		setSubtitle: (string, boolean) -> (),
		progressBackground: Frame,
		progressFill: Frame,
		progressLabel: TextLabel,
		startButton: TextButton,
		challengeRow: Frame,
		challengeButton: TextButton,
		challengeLabel: TextLabel,
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
	UITheme.applyPanelLook(parent, nil, UITheme.FIELD_DAY)
	parent.BackgroundTransparency = 0.3
	UITheme.applySurfaceDepth(parent)

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

	local accent = Instance.new("Frame")
	accent.Name = "DayAccent"
	accent.Position, accent.Size = UDim2.fromOffset(10, 12), UDim2.fromOffset(3, 40)
	accent.BackgroundColor3, accent.BorderSizePixel = UITheme.FIELD_ACCENT, 0
	UITheme.styleCorner(accent, 2)
	accent.Parent = parent

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelTitle"
	levelLabel.Size = UDim2.new(1, -138, 0, 23)
	levelLabel.Position = UDim2.fromOffset(20, 10)
	levelLabel.BackgroundTransparency = 1
	levelLabel.TextSize = 21
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.Text = "Loading day…"
	levelLabel.Parent = parent
	UITheme.applyOutlinedTitle(levelLabel)

	local subtitle = Instance.new("Frame")
	subtitle.Name = "Subtitle"
	subtitle.Position, subtitle.Size = UDim2.fromOffset(20, 36), UDim2.fromOffset(SUBTITLE_WIDTH, 17)
	subtitle.BackgroundTransparency, subtitle.ClipsDescendants = 1, true
	subtitle.Parent = parent

	local phaseLabel = Instance.new("TextLabel")
	phaseLabel.Name = "Phase"
	phaseLabel.Size = UDim2.fromScale(1, 1)
	phaseLabel.BackgroundTransparency = 1
	phaseLabel.TextSize = 13
	phaseLabel.TextXAlignment = Enum.TextXAlignment.Left
	phaseLabel.Text = ""
	phaseLabel.Parent = subtitle
	UITheme.applyBodyText(phaseLabel, UITheme.FIELD_TEXT)

	local hovered, canReveal = false, false
	local overflow = 0
	local slide: Tween? = nil
	local function move(reveal: boolean)
		if slide then slide:Cancel(); slide = nil end
		local destination = if reveal then -overflow else 0
		if phaseLabel.Position.X.Offset == destination then return end
		local duration = if reveal then math.max(0.35, overflow / 55) else 0.18
		slide = TweenService:Create(phaseLabel, TweenInfo.new(duration, Enum.EasingStyle.Sine), {
			Position = UDim2.fromOffset(destination, 0),
		})
		slide:Play()
	end
	subtitle.MouseEnter:Connect(function()
		hovered = true
		if overflow > 0 then move(true) end
	end)
	subtitle.MouseLeave:Connect(function()
		hovered = false
		move(false)
	end)
	parent:GetPropertyChangedSignal("Visible"):Connect(function()
		if parent.Visible then return end
		hovered = false
		if slide then slide:Cancel(); slide = nil end
		phaseLabel.Position = UDim2.new()
	end)
	local function setSubtitle(copy: string, reveal: boolean)
		if phaseLabel.Text == copy and canReveal == reveal then return end
		canReveal = reveal
		if slide then slide:Cancel(); slide = nil end
		phaseLabel.Text, phaseLabel.Position = copy, UDim2.new()
		local width = if reveal then TextService:GetTextSize(copy, phaseLabel.TextSize, phaseLabel.Font, Vector2.new(10000, 1000)).X else 0
		overflow = if width > SUBTITLE_WIDTH then math.ceil(width) + 2 - SUBTITLE_WIDTH else 0
		phaseLabel.Size = UDim2.new(1, overflow, 1, 0)
		if hovered and overflow > 0 then move(true) end
	end

	local progressBackground = Instance.new("Frame")
	progressBackground.Name = "ProgressBackground"
	progressBackground.AnchorPoint = Vector2.new(0, 1)
	progressBackground.Position = UDim2.new(0, 12, 1, -10)
	progressBackground.Size = UDim2.new(1, -24, 0, 10)
	progressBackground.BackgroundColor3 = UITheme.FIELD_INSET
	progressBackground.BorderSizePixel = 0
	progressBackground.Visible = false
	progressBackground.Parent = parent
	UITheme.styleCorner(progressBackground, 7)
	UITheme.applyStroke(progressBackground, UITheme.STROKE_CARD)

	local progressFill = Instance.new("Frame")
	progressFill.Name = "ProgressFill"
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.BackgroundColor3 = UITheme.SUCCESS
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBackground
	UITheme.styleCorner(progressFill, 7)
	UITheme.applySurfaceDepth(progressFill)

	local progressLabel = Instance.new("TextLabel")
	progressLabel.Name = "WaveProgress"
	progressLabel.AnchorPoint = Vector2.new(1, 1)
	progressLabel.Position, progressLabel.Size = UDim2.new(1, -12, 1, -23), UDim2.fromOffset(140, 17)
	progressLabel.BackgroundTransparency = 1
	progressLabel.Text, progressLabel.TextSize = "Wave progress  0%", 12
	progressLabel.TextXAlignment = Enum.TextXAlignment.Right
	progressLabel.Visible = false
	UITheme.applyOutlinedTitle(progressLabel, UITheme.FIELD_TEXT)
	progressLabel.Parent = parent

	local startButton = Instance.new("TextButton")
	startButton.Name = "StartButton"
	startButton.AnchorPoint = Vector2.new(1, 0.5)
	startButton.Position = UDim2.new(1, -12, 0, PANEL_HEIGHT_PREP / 2)
	startButton.Size = UDim2.fromOffset(104, 42)
	startButton.TextSize = 16
	startButton.Text = "Start Day"
	startButton.Visible = false
	startButton.Parent = parent
	UITheme.applyButtonLook(startButton, UITheme.SUCCESS)
	UITheme.applySurfaceDepth(startButton)
	UITheme.applyOutlinedTitle(startButton)

	startButton.Activated:Connect(function()
		AudioController.play("LevelStart")
		Remotes.getEvent("StartLevel"):FireServer()
	end)

	local challengeRow = Instance.new("Frame")
	challengeRow.Name = "DailyChallenge"
	challengeRow.Position = UDim2.fromOffset(10, PANEL_HEIGHT_PREP - 4)
	challengeRow.Size = UDim2.new(1, -20, 0, CHALLENGE_ROW_HEIGHT - 8)
	challengeRow.Visible = false
	UITheme.applyButtonLook(challengeRow, UITheme.FIELD_INSET, 9)
	challengeRow.Parent = parent

	local challengeLabel = Instance.new("TextLabel")
	challengeLabel.Name = "Description"
	challengeLabel.Position, challengeLabel.Size = UDim2.fromOffset(8, 0), UDim2.new(1, -110, 1, 0)
	challengeLabel.TextSize = 12
	challengeLabel.BackgroundTransparency = 1
	challengeLabel.TextWrapped = true
	challengeLabel.TextXAlignment = Enum.TextXAlignment.Left
	UITheme.applyBodyText(challengeLabel, UITheme.FIELD_TEXT)
	challengeLabel.Parent = challengeRow

	local challengeButton = Instance.new("TextButton")
	challengeButton.Name = "Enter"
	challengeButton.AnchorPoint, challengeButton.Position = Vector2.new(1, 0.5), UDim2.new(1, -8, 0.5, 0)
	challengeButton.Size = UDim2.fromOffset(86, 34)
	challengeButton.Text, challengeButton.TextSize = "Challenge", 13
	UITheme.applyButtonLook(challengeButton, UITheme.PANEL_BG_ACHIEVEMENTS)
	UITheme.applyOutlinedTitle(challengeButton)
	challengeButton.Parent = challengeRow
	challengeButton.Activated:Connect(function()
		AudioController.play("UiClick")
		Remotes.getEvent("StartDailyChallenge"):FireServer()
	end)

	return setmetatable({
		frame = parent,
		levelLabel = levelLabel,
		phaseLabel = phaseLabel,
		setSubtitle = setSubtitle,
		progressBackground = progressBackground,
		progressFill = progressFill,
		progressLabel = progressLabel,
		startButton = startButton,
		challengeRow = challengeRow,
		challengeLabel = challengeLabel,
		challengeButton = challengeButton,
		warningBanner = warningBanner,
		startCountdownLabel = startCountdownLabel,
	}, Level)
end

local function startCountdownShown(remaining: number): number
	return math.clamp(math.floor(remaining), 0, math.max(0, LevelConfig.COUNTDOWN_TIME - 1))
end

local function phaseMessage(phase: string): string
	if phase == PHASE.Countdown then
		return "Get ready!"
	elseif phase == PHASE.Active then
		return "Defend your lawn"
	elseif phase == PHASE.Victory then
		return "Victory!"
	elseif phase == PHASE.Defeat then
		return "Defeat"
	end
	return phase
end

function Level.applyState(self: LevelPanel, state: { [string]: any })
	local levelNumber = state.levelNumber
	if state.challengeActive == true then
		self.levelLabel.Text = ChallengeConfig.ENCOUNTER.name
	elseif state.hiddenDay == true then
		self.levelLabel.Text = "Hidden Day"
	elseif type(levelNumber) == "number" then
		self.levelLabel.Text = string.format("Day %d", levelNumber)
	end

	local phase = state.phase
	if type(phase) ~= "string" then
		return
	end

	local countdown = if type(state.countdownRemaining) == "number" then state.countdownRemaining else nil

	local countingDown = phase == PHASE.Countdown and countdown ~= nil
	self.startCountdownLabel.Visible = countingDown
	if countingDown and countdown then
		self.startCountdownLabel.Text = if state.challengeActive then string.format("Challenge starts in %d", startCountdownShown(countdown))
			elseif state.hiddenDay == true
			then string.format("Hidden Day starting in %d", startCountdownShown(countdown))
			else string.format("Day starting in %d", startCountdownShown(countdown))
	end

	if phase == PHASE.Victory then
		UITheme.applyOutlinedTitle(self.phaseLabel, UITheme.SUCCESS)
		self.phaseLabel.Font = Enum.Font.GothamBold
		self.phaseLabel.TextSize = 13
	elseif phase == PHASE.Defeat then
		UITheme.applyOutlinedTitle(self.phaseLabel, UITheme.DANGER)
		self.phaseLabel.Font = Enum.Font.GothamBold
		self.phaseLabel.TextSize = 13
	else
		UITheme.applyBodyText(self.phaseLabel, UITheme.FIELD_TEXT)
		self.phaseLabel.TextSize = 13
	end

	local preparing = phase == PHASE.Preparation and state.challengeActive ~= true
	local copy = if state.challengeActive then "Daily Challenge · No magnet"
		elseif preparing then (if state.hiddenDay ~= true and type(state.levelName) == "string" then state.levelName else "")
		else phaseMessage(phase)
	self.setSubtitle(copy, preparing)

	-- Defeat uses GameOverPopup Rewind; Start Day only in Preparation.
	self.startButton.Visible = state.canStart == true and phase ~= PHASE.Defeat
	self.warningBanner.Visible = state.bigWaveWarning == true

	local showProgress = phase == PHASE.Active
	local result = if type(state.challengeResult) == "string" then state.challengeResult else nil
	local showChallenge = phase == PHASE.Preparation and (state.challengeAvailable == true or result ~= nil)
	self.challengeRow.Visible = showChallenge
	self.challengeButton.Visible = state.challengeAvailable == true
	self.challengeButton.Text = if result then "Retry" else "Challenge"
	if showChallenge then
		self.challengeLabel.Text = result or string.format("%s · %d brains first clear\n%s",
			ChallengeConfig.ENCOUNTER.name, state.challengeReward or 0, ChallengeConfig.MODIFIER)
		self.challengeLabel.Size = UDim2.new(1, if self.challengeButton.Visible then -110 else -16, 1, 0)
	end
	self.progressBackground.Visible = showProgress
	self.progressLabel.Visible = showProgress
	self.frame.Size = UDim2.fromOffset(
		PANEL_WIDTH,
		if showProgress then PANEL_HEIGHT_ACTIVE elseif showChallenge then PANEL_HEIGHT_PREP + CHALLENGE_ROW_HEIGHT else PANEL_HEIGHT_PREP
	)
	if showProgress then
		local progress = if type(state.progress) == "number" then math.clamp(state.progress, 0, 1) else 0
		self.progressFill.Size = UDim2.fromScale(progress, 1)
		self.progressLabel.Text = string.format("Wave progress  %d%%", math.round(progress * 100))
	end
end

return Level
