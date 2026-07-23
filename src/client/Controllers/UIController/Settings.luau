--!strict
--[[
	Settings
	Mute / volume / Brainrot SFX toggles, statistics, reset progress.
	Cartoon thick-outline look via UITheme.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressConfig = require(Shared.Config.ProgressConfig)
local UITheme = require(Shared.Config.UITheme)
local Remotes = require(Shared.Remotes)

local AudioController = require(script.Parent.Parent.AudioController)

local Settings = {}
Settings.__index = Settings

export type SettingsPanel = typeof(setmetatable(
	{} :: {
		frame: Frame,
		statsLabel: TextLabel,
		resetStep: number,
		resetButton: TextButton,
	},
	Settings
))

local function makeButton(parent: Instance, text: string, fill: Color3): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.Size = UDim2.new(1, 0, 0, 36)
	button.TextSize = 15
	button.Text = text
	button.Parent = parent
	UITheme.applyButtonLook(button, fill)
	UITheme.applyOutlinedTitle(button)
	button.TextSize = 15
	return button
end

function Settings.new(parent: Frame): SettingsPanel
	parent.Visible = false
	parent.AnchorPoint = Vector2.new(0.5, 0.5)
	parent.Position = UDim2.fromScale(0.5, 0.5)
	parent.Size = UDim2.fromOffset(440, 480)
	parent.ZIndex = 25
	UITheme.applyPanelLook(parent)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -80, 0, 32)
	title.Position = UDim2.fromOffset(16, 12)
	title.TextSize = 22
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Settings"
	title.Parent = parent
	UITheme.applyOutlinedTitle(title)

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 10)
	close.Size = UDim2.fromOffset(36, 36)
	close.TextSize = 20
	close.Text = "X"
	close.Parent = parent
	UITheme.applyButtonLook(close, UITheme.DANGER)
	UITheme.applyOutlinedTitle(close)

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(16, 56)
	body.Size = UDim2.new(1, -32, 1, -68)
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 8
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.CanvasSize = UDim2.fromOffset(0, 0)
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = body

	local bodyPad = Instance.new("UIPadding")
	bodyPad.PaddingBottom = UDim.new(0, 16)
	bodyPad.Parent = body

	local function section(label: string, order: number): Frame
		local frame = Instance.new("Frame")
		frame.Name = label
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.new(1, -8, 0, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.LayoutOrder = order
		frame.Parent = body

		local stack = Instance.new("UIListLayout")
		stack.Padding = UDim.new(0, 6)
		stack.SortOrder = Enum.SortOrder.LayoutOrder
		stack.Parent = frame

		local header = Instance.new("TextLabel")
		header.BackgroundTransparency = 1
		header.Size = UDim2.new(1, 0, 0, 22)
		header.LayoutOrder = 0
		header.TextSize = 15
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.Text = label
		header.Parent = frame
		UITheme.applyOutlinedTitle(header, if label == "Danger Zone" then UITheme.DANGER else UITheme.ACCENT)
		header.TextSize = 15
		return frame
	end

	local audioSection = section("Audio", 1)
	local muteButton = makeButton(audioSection, "Mute: Off", UITheme.BUTTON_BG)
	muteButton.LayoutOrder = 1
	local musicButton = makeButton(audioSection, "Music Volume: High", UITheme.BUTTON_BG)
	musicButton.LayoutOrder = 2
	local sfxButton = makeButton(audioSection, "SFX Volume: High", UITheme.BUTTON_BG)
	sfxButton.LayoutOrder = 3
	local brainrotSfxButton = makeButton(audioSection, "Brainrot SFX: On", UITheme.BUTTON_BG)
	brainrotSfxButton.LayoutOrder = 4

	local muted = false
	local musicLevel = 2
	local sfxLevel = 2
	local brainrotSfx = true

	local function applyAudio()
		AudioController.setMuted(muted)
		AudioController.setMusicVolumeScale(if musicLevel == 0 then 0 elseif musicLevel == 1 then 0.45 else 1)
		AudioController.setSfxVolumeScale(if sfxLevel == 0 then 0 elseif sfxLevel == 1 then 0.45 else 1)
		AudioController.setBrainrotSfxEnabled(brainrotSfx)
		muteButton.Text = if muted then "Mute: On" else "Mute: Off"
		musicButton.Text = "Music Volume: " .. (if musicLevel == 0 then "Off" elseif musicLevel == 1 then "Low" else "High")
		sfxButton.Text = "SFX Volume: " .. (if sfxLevel == 0 then "Off" elseif sfxLevel == 1 then "Low" else "High")
		brainrotSfxButton.Text = if brainrotSfx then "Brainrot SFX: On" else "Brainrot SFX: Off"
	end

	muteButton.Activated:Connect(function()
		AudioController.play("UiClick")
		muted = not muted
		applyAudio()
	end)
	musicButton.Activated:Connect(function()
		AudioController.play("UiClick")
		musicLevel = (musicLevel + 1) % 3
		applyAudio()
	end)
	sfxButton.Activated:Connect(function()
		AudioController.play("UiClick")
		sfxLevel = (sfxLevel + 1) % 3
		applyAudio()
	end)
	brainrotSfxButton.Activated:Connect(function()
		AudioController.play("UiClick")
		brainrotSfx = not brainrotSfx
		applyAudio()
	end)

	local statsSection = section("Statistics", 2)
	local statsLabel = Instance.new("TextLabel")
	statsLabel.BackgroundTransparency = 1
	statsLabel.Size = UDim2.new(1, 0, 0, 120)
	statsLabel.LayoutOrder = 1
	statsLabel.TextSize = 14
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.TextYAlignment = Enum.TextYAlignment.Top
	statsLabel.Text = "Loading…"
	statsLabel.TextWrapped = true
	statsLabel.Parent = statsSection
	UITheme.applyBodyText(statsLabel, UITheme.SUBTEXT)

	local dangerSection = section("Danger Zone", 3)
	local dangerHint = Instance.new("TextLabel")
	dangerHint.BackgroundTransparency = 1
	dangerHint.Size = UDim2.new(1, 0, 0, 36)
	dangerHint.TextSize = 12
	dangerHint.TextXAlignment = Enum.TextXAlignment.Left
	dangerHint.TextYAlignment = Enum.TextYAlignment.Top
	dangerHint.TextWrapped = true
	dangerHint.Text = "Resets you to Day 1, clears your lawn, and restores 125 coins. Requires two confirmations."
	dangerHint.LayoutOrder = 1
	dangerHint.Parent = dangerSection
	UITheme.applyBodyText(dangerHint, UITheme.DANGER)

	local resetButton = makeButton(dangerSection, "Reset Progress", UITheme.DANGER)
	resetButton.LayoutOrder = 2

	local self = setmetatable({
		frame = parent,
		statsLabel = statsLabel,
		resetStep = 0,
		resetButton = resetButton,
	}, Settings) :: SettingsPanel

	close.Activated:Connect(function()
		AudioController.play("UiClick")
		self:setOpen(false)
	end)

	local RESET_LABELS = {
		[0] = "Reset Progress",
		[1] = "Are you sure? Click to confirm",
		[2] = "Final confirm — wipe all progress",
	}

	resetButton.Activated:Connect(function()
		AudioController.play("UiClick")
		if self.resetStep < 2 then
			self.resetStep += 1
			resetButton.Text = RESET_LABELS[self.resetStep]
			return
		end

		self.resetStep = 0
		resetButton.Text = RESET_LABELS[0]
		Remotes.getEvent("ResetProgress"):FireServer()
		self:setOpen(false)
	end)

	applyAudio()
	return self
end

function Settings.applyStatistics(self: SettingsPanel, statistics: { [string]: number }?)
	local stats = statistics or {}
	local function get(key: string): number
		return stats[key] or 0
	end
	local minutes = math.floor(get(ProgressConfig.STAT_TIME_PLAYED) / 60)
	self.statsLabel.Text = table.concat({
		string.format("Days cleared: %d", get(ProgressConfig.STAT_LEVELS_CLEARED)),
		string.format("Brainrots placed: %d", get(ProgressConfig.STAT_BRAINROTS_PLACED)),
		string.format("Monsters defeated: %d", get(ProgressConfig.STAT_MONSTERS_DEFEATED)),
		string.format("Brains earned: %d", get(ProgressConfig.STAT_BRAINS_EARNED)),
		string.format("Time played: %d min", minutes),
	}, "\n")
end

function Settings.setOpen(self: SettingsPanel, open: boolean)
	self.frame.Visible = open
	if open then
		self.resetStep = 0
		self.resetButton.Text = "Reset Progress"
	end
end

function Settings.isOpen(self: SettingsPanel): boolean
	return self.frame.Visible
end

return Settings
