--!strict
--[[
	Settings
	Mute / volume / Brainrot SFX / high-quality VFX toggles,
	reset progress. Cartoon thick-outline look via UITheme.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UITheme = require(Shared.Config.UITheme)
local Remotes = require(Shared.Remotes)
local VfxLoad = require(Shared.Utilities.VfxLoad)

local Controls = require(script.Parent.SettingsControls)
local BrainAmount = require(script.Parent.Parent.Parent.Utilities.BrainAmount)
local AudioController = require(script.Parent.Parent.AudioController)

local Settings = {}
Settings.__index = Settings

export type SettingsPanel = typeof(setmetatable(
	{} :: {
		frame: Frame,
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
	parent.Size = UDim2.fromOffset(480, 560)
	parent.ZIndex = 25
	UITheme.applyPanelLook(parent, nil, UITheme.PANEL_BG_SETTINGS)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -80, 0, 32)
	title.Position = UDim2.fromOffset(16, 12)
	title.TextSize = 22
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "SETTINGS"
	title.Parent = parent
	UITheme.applyOutlinedTitle(title, UITheme.SETTINGS_ACCENT)

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
	body.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	body.ScrollBarImageColor3 = UITheme.SETTINGS_ACCENT
	body.ScrollBarThickness = 8
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.CanvasSize = UDim2.fromOffset(0, 0)
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = body

	-- ScrollingFrame always clips its contents — without inset padding, any
	-- child flush against an edge has its rounded UIStroke corner (which
	-- draws half outside the child's bounds) chopped off flat. Padding on all
	-- sides keeps every card/button's outline fully visible.
	local bodyPad = Instance.new("UIPadding")
	bodyPad.PaddingTop = UDim.new(0, 6)
	bodyPad.PaddingLeft = UDim.new(0, 6)
	bodyPad.PaddingRight = UDim.new(0, 6)
	bodyPad.PaddingBottom = UDim.new(0, 8)
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
		header.Text = string.upper(label)
		header.Parent = frame
		UITheme.applyOutlinedTitle(header, if label == "Danger Zone" then UITheme.DANGER else UITheme.SETTINGS_ACCENT)
		header.TextSize = 15
		return frame
	end

	local audioSection = section("Audio", 1)
	local music = Controls.row(audioSection, "Music", "Music", "♫", 1)
	Controls.slider(music, body, AudioController.setMusicVolumeScale)
	local sfx = Controls.row(audioSection, "SoundEffects", "Sound Effects", "🔊", 2)
	Controls.slider(sfx, body, AudioController.setSfxVolumeScale)
	local mute = Controls.row(audioSection, "Mute", "Mute All", "×", 3)
	Controls.switch(mute, "Toggle", false, function(enabled)
		AudioController.play("UiClick")
		AudioController.setMuted(enabled)
	end)
	local brainrot = Controls.row(audioSection, "BrainrotSfx", "Brainrot Sounds", "", 4, BrainAmount.IMAGE)
	Controls.switch(brainrot, "Toggle", true, function(enabled)
		AudioController.play("UiClick")
		AudioController.setBrainrotSfxEnabled(enabled)
	end)

	local function hint(parent: Frame, value: string, order: number, height: number)
		local label = Controls.text(parent, value, 14)
		label.Size, label.LayoutOrder = UDim2.new(1, 0, 0, height), order
		label.TextWrapped = true
		UITheme.applyBodyText(label, UITheme.TITLE)
	end

	local graphicsSection = section("Graphics", 2)
	local effects = Controls.row(graphicsSection, "Effects", "Effects Quality", "✦", 1)
	local qualityButton = makeButton(effects, VfxLoad.label(), UITheme.SETTINGS_TILE)
	qualityButton.AnchorPoint, qualityButton.Position = Vector2.new(1, 0.5), UDim2.new(1, -12, 0.5, 0)
	qualityButton.Size = UDim2.fromOffset(98, 34)
	UITheme.applySurfaceDepth(qualityButton)
	qualityButton.Activated:Connect(function()
		AudioController.play("UiClick")
		VfxLoad.cycle()
		qualityButton.Text = VfxLoad.label()
	end)
	hint(graphicsSection, "High shows all effects. Low reduces them. Off keeps the colored outline on your Brainrots.", 2, 42)
	local otherPlots = Controls.row(graphicsSection, "OtherPlots", "Other Plots", "▦", 3)
	Controls.switch(otherPlots, "Toggle", VfxLoad.showsOtherPlots(), function(enabled)
		AudioController.play("UiClick")
		VfxLoad.setShowOtherPlots(enabled)
	end)
	hint(graphicsSection, "Turn off effects from other players’ Brainrots to improve performance.", 4, 42)

	local dangerSection = section("Danger Zone", 4)
	hint(dangerSection, "Back to Day 1, with an empty lawn and 125 coins. You’ll be asked twice.", 1, 42)

	local resetButton = makeButton(dangerSection, "Reset Progress", UITheme.DANGER)
	UITheme.applySurfaceDepth(resetButton)
	resetButton.LayoutOrder = 2

	local self = setmetatable({
		frame = parent,
		resetStep = 0,
		resetButton = resetButton,
	}, Settings) :: SettingsPanel

	close.Activated:Connect(function()
		AudioController.play("UiClick")
		self:setOpen(false)
	end)

	local RESET_LABELS = {
		[0] = "Reset Progress",
		[1] = "Are you sure?",
		[2] = "Tap again to erase everything",
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

	return self
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
