--!strict
--[[
	BrainsCounter
	Mid-left brains balance: icon + amount under coins. Display-only.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage:WaitForChild("Shared").Config.UITheme)

local BrainsCounter = {}
BrainsCounter.__index = BrainsCounter

local BRAIN_ICON_ASSET_ID = "rbxassetid://12691330734"
local FLOAT_DURATION = 0.85
local FLOAT_OFFSET_Y = -40
local DELTA_TEXT_SIZE = 32

local ICON_SIZE = 64

export type BrainsCounter = typeof(setmetatable(
	{} :: {
		frame: Frame,
		amountLabel: TextLabel,
	},
	BrainsCounter
))

function BrainsCounter.new(frame: Frame): BrainsCounter
	frame.Visible = true
	frame.AnchorPoint = Vector2.new(0, 0)
	frame.Position = UDim2.new(0, 16, 0.42, 0)
	frame.Size = UDim2.fromOffset(180, ICON_SIZE)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = false

	local icon = Instance.new("ImageLabel")
	icon.Name = "Glyph"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 0, 0.5, 0)
	icon.Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE)
	icon.Image = BRAIN_ICON_ASSET_ID
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Amount"
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, ICON_SIZE + 6, 0.5, 0)
	label.Size = UDim2.new(1, -(ICON_SIZE + 6), 1, 0)
	label.BackgroundTransparency = 1
	label.TextSize = 30
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = "0"
	label.Parent = frame
	UITheme.applyOutlinedTitle(label, UITheme.TITLE)
	label.TextSize = 30

	return setmetatable({
		frame = frame,
		amountLabel = label,
	}, BrainsCounter)
end

function BrainsCounter.setBalance(self: BrainsCounter, amount: number)
	self.amountLabel.Text = string.format("%d", amount)
end

function BrainsCounter.showDelta(self: BrainsCounter, delta: number)
	if delta == 0 then
		return
	end

	local popup = Instance.new("TextLabel")
	popup.Name = "Delta"
	popup.BackgroundTransparency = 1
	popup.TextSize = DELTA_TEXT_SIZE
	popup.TextXAlignment = Enum.TextXAlignment.Center
	popup.AnchorPoint = Vector2.new(0.5, 0)
	popup.Position = UDim2.new(0.5, 0, 1, 6)
	popup.Size = UDim2.fromOffset(120, 40)
	popup.ZIndex = self.frame.ZIndex + 1

	if delta > 0 then
		popup.Text = string.format("+%d", delta)
		UITheme.applyOutlinedTitle(popup, UITheme.SUCCESS)
	else
		popup.Text = string.format("%d", delta)
		UITheme.applyOutlinedTitle(popup, UITheme.DANGER)
	end
	popup.TextSize = DELTA_TEXT_SIZE
	popup.Parent = self.frame

	local tween = TweenService:Create(
		popup,
		TweenInfo.new(FLOAT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Position = UDim2.new(0.5, 0, 1, 6 + FLOAT_OFFSET_Y),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	)
	tween:Play()
	tween.Completed:Connect(function()
		popup:Destroy()
	end)
end

return BrainsCounter
