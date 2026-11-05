--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Theme = require(Shared.Config.UITheme)
local Time = require(Shared.Utilities.RetentionTime)
local Tiles = require(script.Parent.Parent.Parent.Utilities.MenuTiles)
local RewardHudEntry = {}

function RewardHudEntry.new(main: ScreenGui, name: string, caption: string): (TextButton, TextLabel)
	local entry = Instance.new("TextButton")
	entry.Name, entry.Text, entry.Visible = name, "", false
	entry.BackgroundTransparency, entry.BorderSizePixel, entry.ZIndex = 1, 0, 15
	entry.AnchorPoint, entry.Position = Vector2.new(0, 1), UDim2.new(0, 16, 1, -116)
	entry.Size = UDim2.fromOffset(96, 76)

	local icon = Instance.new("Frame")
	icon.Name, icon.BackgroundTransparency = "Icon", 1
	icon.Position, icon.Size, icon.Parent = UDim2.fromOffset(27, 0), UDim2.fromOffset(42, 42), entry
	Tiles.illustrate(icon, caption)

	local title = Instance.new("TextLabel")
	title.Name, title.Text, title.TextSize = "Caption", caption, 11
	title.BackgroundTransparency = 1
	title.Position, title.Size, title.Parent = UDim2.fromOffset(0, 40), UDim2.fromOffset(96, 17), entry
	Theme.applyOutlinedTitle(title)

	local timer = Instance.new("TextLabel")
	timer.Name, timer.Text, timer.TextSize = "Timer", "…", 11
	timer.Position, timer.Size, timer.Parent = UDim2.fromOffset(17, 58), UDim2.fromOffset(62, 16), entry
	Theme.applyButtonLook(timer, Theme.FIELD_PANEL, 6)
	Theme.applyStroke(timer, 1)
	Theme.applyOutlinedTitle(timer, Theme.FIELD_TEXT)
	entry.Parent = main
	return entry, timer
end

function RewardHudEntry.countdown(resetAt: number?): string
	return if resetAt then Time.formatCountdown(math.max(0, resetAt - workspace:GetServerTimeNow())) else "…"
end

return RewardHudEntry
