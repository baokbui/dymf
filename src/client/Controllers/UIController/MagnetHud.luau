--!strict
--[[
	MagnetHud
	Bottom-center square: magnet glyph, level, cooldown overlay.
	Display + ActivateMagnet intent only.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MagnetConfig = require(Shared.Config.MagnetConfig)
local ProgressConfig = require(Shared.Config.ProgressConfig)
local UITheme = require(Shared.Config.UITheme)

local MagnetHud = {}
MagnetHud.__index = MagnetHud

local SIZE = 64
local ICON = 36
-- Image asset 114934566416428; ImageLabel uses the texture id.
local MAGNET_ICON_TEXTURE_ID = "rbxassetid://73519143112132"

export type MagnetHud = typeof(setmetatable(
	{} :: {
		button: TextButton,
		levelLabel: TextLabel,
		overlay: Frame,
		timerLabel: TextLabel,
		level: number,
		activeUntil: number,
		readyAt: number,
		pausedRemaining: number,
		onActivate: (() -> ())?,
	},
	MagnetHud
))

local function mountGlyph(parent: Frame)
	local glyph = Instance.new("ImageLabel")
	glyph.Name = "Glyph"
	glyph.BackgroundTransparency = 1
	glyph.AnchorPoint = Vector2.new(0.5, 0)
	glyph.Position = UDim2.new(0.5, 0, 0, 5)
	glyph.Size = UDim2.fromOffset(ICON, ICON)
	glyph.Image = MAGNET_ICON_TEXTURE_ID
	glyph.ScaleType = Enum.ScaleType.Fit
	glyph.ZIndex = 16
	glyph.Parent = parent
end

function MagnetHud.new(parent: Frame): MagnetHud
	local button = Instance.new("TextButton")
	button.Name = "MagnetEntry"
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -16)
	button.Size = UDim2.fromOffset(SIZE, SIZE)
	button.AutoButtonColor = true
	button.Text = ""
	button.ZIndex = 15
	button.ClipsDescendants = true
	button.Parent = parent
	UITheme.applyChipLook(button, UITheme.CHIP_BG_MAGNET)

	mountGlyph(button)

	local hotkey = Instance.new("TextLabel")
	hotkey.Name = "Hotkey"
	hotkey.BackgroundTransparency = 1
	hotkey.Position = UDim2.fromOffset(4, 1)
	hotkey.Size = UDim2.fromOffset(16, 14)
	hotkey.ZIndex = 16
	hotkey.Text = MagnetConfig.HOTKEY_LABEL
	hotkey.TextSize = 10
	hotkey.TextXAlignment = Enum.TextXAlignment.Left
	hotkey.Parent = button
	UITheme.applyOutlinedTitle(hotkey)
	hotkey.TextSize = 10

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "Level"
	levelLabel.BackgroundTransparency = 1
	levelLabel.AnchorPoint = Vector2.new(0.5, 1)
	levelLabel.Position = UDim2.new(0.5, 0, 1, -4)
	levelLabel.Size = UDim2.new(1, -6, 0, 14)
	levelLabel.ZIndex = 16
	levelLabel.Text = "Lv. 1"
	levelLabel.TextSize = 11
	levelLabel.Parent = button
	UITheme.applyOutlinedTitle(levelLabel)
	levelLabel.TextSize = 11

	local overlay = Instance.new("Frame")
	overlay.Name = "Cooldown"
	overlay.BackgroundColor3 = Color3.fromRGB(12, 14, 22)
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.AnchorPoint = Vector2.new(0.5, 1)
	overlay.Position = UDim2.new(0.5, 0, 1, 0)
	overlay.Size = UDim2.fromScale(1, 0)
	overlay.ZIndex = 17
	overlay.Visible = false
	overlay.Active = false
	overlay.Parent = button
	UITheme.styleCorner(overlay, UITheme.CORNER_CHIP)

	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "Timer"
	timerLabel.BackgroundTransparency = 1
	timerLabel.Size = UDim2.fromScale(1, 1)
	timerLabel.ZIndex = 18
	timerLabel.Text = ""
	timerLabel.TextSize = 16
	timerLabel.Visible = false
	timerLabel.Active = false
	timerLabel.Parent = button
	UITheme.applyOutlinedTitle(timerLabel)
	timerLabel.TextSize = 16

	local self = setmetatable({
		button = button,
		levelLabel = levelLabel,
		overlay = overlay,
		timerLabel = timerLabel,
		level = MagnetConfig.DEFAULT_LEVEL,
		activeUntil = 0,
		readyAt = 0,
		pausedRemaining = 0,
		onActivate = nil,
	}, MagnetHud)

	button.Activated:Connect(function()
		if self.onActivate then
			self.onActivate()
		end
	end)

	return self
end

function MagnetHud.setLevel(self: MagnetHud, level: number)
	self.level = math.clamp(math.floor(level), MagnetConfig.DEFAULT_LEVEL, MagnetConfig.MAX_LEVEL)
	self.levelLabel.Text = string.format("Lv. %d", self.level)
end

function MagnetHud.applyUpgrades(self: MagnetHud, upgrades: { [string]: number })
	local def = ProgressConfig.upgradeById(MagnetConfig.ID)
	if not def then
		self:setLevel(MagnetConfig.DEFAULT_LEVEL)
		return
	end
	self:setLevel(ProgressConfig.upgradeLevel(def, upgrades[MagnetConfig.ID]))
end

function MagnetHud.applyState(self: MagnetHud, state: { [string]: any }?)
	if type(state) ~= "table" then
		return
	end
	if type(state.level) == "number" then
		self:setLevel(state.level)
	end
	if type(state.activeUntil) == "number" then
		self.activeUntil = state.activeUntil
	end
	if type(state.readyAt) == "number" then
		self.readyAt = state.readyAt
	end
	if type(state.pausedRemaining) == "number" then
		self.pausedRemaining = math.max(0, state.pausedRemaining)
	end
end

function MagnetHud.isReady(self: MagnetHud): boolean
	if self.pausedRemaining > 0 then
		return false
	end
	local clock = workspace:GetServerTimeNow()
	return clock >= self.activeUntil and clock >= self.readyAt
end

local function showCooldown(self: MagnetHud, remaining: number)
	local window = MagnetConfig.cooldownFor(self.level)
	local alpha = 0
	if window > 0 then
		alpha = math.clamp(remaining / window, 0, 1)
	end
	self.overlay.Visible = true
	self.overlay.Size = UDim2.fromScale(1, alpha)
	self.timerLabel.Visible = true
	self.timerLabel.Text = MagnetConfig.formatSeconds(remaining)
	self.timerLabel.TextColor3 = UITheme.TITLE
end

function MagnetHud.tick(self: MagnetHud)
	local clock = workspace:GetServerTimeNow()
	if clock < self.activeUntil then
		local remaining = self.activeUntil - clock
		self.overlay.Visible = false
		self.timerLabel.Visible = true
		self.timerLabel.Text = MagnetConfig.formatSeconds(remaining)
		self.timerLabel.TextColor3 = Color3.fromRGB(120, 255, 140)
		return
	end
	if self.pausedRemaining > 0 then
		showCooldown(self, self.pausedRemaining)
		return
	end
	if clock < self.readyAt then
		showCooldown(self, self.readyAt - clock)
		return
	end
	self.overlay.Visible = false
	self.timerLabel.Visible = false
	self.timerLabel.Text = ""
end

return MagnetHud
