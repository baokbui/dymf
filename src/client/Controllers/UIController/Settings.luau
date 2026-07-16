--!strict
--[[
	Settings
	Mute / volume / Brainrot SFX toggles, statistics, reset progress.
	Opened from the left HUD "Settings" bar. Inventory is a separate UI.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressConfig = require(Shared.Config.ProgressConfig)
local Remotes = require(Shared.Remotes)

local AudioController = require(script.Parent.Parent.AudioController)

local Settings = {}
Settings.__index = Settings

local PANEL_BG = Color3.fromRGB(18, 20, 30)
local TEXT = Color3.fromRGB(235, 238, 245)
local SUB = Color3.fromRGB(160, 168, 180)
local ACCENT = Color3.fromRGB(120, 200, 255)
local DANGER = Color3.fromRGB(200, 60, 60)
local BUTTON = Color3.fromRGB(40, 44, 58)

export type SettingsPanel = typeof(setmetatable(
	{} :: {
		frame: Frame,
		statsLabel: TextLabel,
		resetStep: number,
		resetButton: TextButton,
	},
	Settings
))

local function styleCorner(instance: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function makeButton(parent: Instance, text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.Size = UDim2.new(1, 0, 0, 36)
	button.BackgroundColor3 = color
	button.Font = Enum.Font.GothamBold
	button.TextSize = 15
	button.TextColor3 = TEXT
	button.Text = text
	button.Parent = parent
	styleCorner(button, 8)
	return button
end

function Settings.new(parent: Frame): SettingsPanel
	parent.Visible = false
	parent.AnchorPoint = Vector2.new(0.5, 0.5)
	parent.Position = UDim2.fromScale(0.5, 0.5)
	parent.Size = UDim2.fromOffset(440, 400)
	parent.BackgroundColor3 = PANEL_BG
	parent.BackgroundTransparency = 0.04
	parent.BorderSizePixel = 0
	parent.ZIndex = 25
	styleCorner(parent, 14)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -80, 0, 32)
	title.Position = UDim2.fromOffset(16, 12)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = TEXT
	title.Text = "Settings"
	title.Parent = parent

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 10)
	close.Size = UDim2.fromOffset(36, 36)
	close.BackgroundColor3 = DANGER
	close.Font = Enum.Font.GothamBold
	close.TextSize = 20
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Text = "X"
	close.Parent = parent
	styleCorner(close, 8)

	local body = Instance.new("ScrollingFrame")
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(16, 56)
	body.Size = UDim2.new(1, -32, 1, -68)
	body.CanvasSize = UDim2.fromOffset(0, 360)
	body.ScrollBarThickness = 6
	body.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = body

	local function section(label: string, order: number): Frame
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.new(1, 0, 0, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.LayoutOrder = order
		frame.Parent = body
		local header = Instance.new("TextLabel")
		header.BackgroundTransparency = 1
		header.Size = UDim2.new(1, 0, 0, 22)
		header.Font = Enum.Font.GothamBold
		header.TextSize = 15
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.TextColor3 = ACCENT
		header.Text = label
		header.Parent = frame
		local stack = Instance.new("UIListLayout")
		stack.Padding = UDim.new(0, 6)
		stack.SortOrder = Enum.SortOrder.LayoutOrder
		stack.Parent = frame
		return frame
	end

	local audioSection = section("Audio", 1)
	local muteButton = makeButton(audioSection, "Mute: Off", BUTTON)
	local musicButton = makeButton(audioSection, "Music Volume: High", BUTTON)
	local sfxButton = makeButton(audioSection, "SFX Volume: High", BUTTON)
	local brainrotSfxButton = makeButton(audioSection, "Brainrot SFX: On", BUTTON)

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
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.TextSize = 14
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.TextYAlignment = Enum.TextYAlignment.Top
	statsLabel.TextColor3 = SUB
	statsLabel.Text = "Loading…"
	statsLabel.TextWrapped = true
	statsLabel.Parent = statsSection

	local dangerSection = section("Danger Zone", 3)
	local resetButton = makeButton(dangerSection, "Reset Progress", DANGER)

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

	resetButton.Activated:Connect(function()
		AudioController.play("UiClick")
		if self.resetStep == 0 then
			self.resetStep = 1
			resetButton.Text = "Confirm Reset? Click again"
		elseif self.resetStep == 1 then
			self.resetStep = 0
			resetButton.Text = "Reset Progress"
			Remotes.getEvent("ResetProgress"):FireServer()
			self:setOpen(false)
		end
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
