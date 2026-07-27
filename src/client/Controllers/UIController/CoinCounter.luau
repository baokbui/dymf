--!strict
--[[
	CoinCounter
	Top-left coin balance display plus floating +/- feedback labels.
	Cartoon thick-outline look via UITheme.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage:WaitForChild("Shared").Config.UITheme)

local CoinCounter = {}
CoinCounter.__index = CoinCounter

local FLOAT_DURATION = 0.85
local FLOAT_OFFSET_Y = -40
local DELTA_TEXT_SIZE = 32

export type CoinCounter = typeof(setmetatable(
	{} :: {
		frame: Frame,
		amountLabel: TextLabel,
	},
	CoinCounter
))

function CoinCounter.new(frame: Frame): CoinCounter
	local self = setmetatable({
		frame = frame,
		amountLabel = nil :: TextLabel?,
	}, CoinCounter)

	frame.Visible = true
	frame.AnchorPoint = Vector2.new(0, 0)
	frame.Position = UDim2.fromOffset(16, 16)
	frame.Size = UDim2.fromOffset(168, 52)
	frame.ClipsDescendants = false
	UITheme.applyChipLook(frame, UITheme.CHIP_BG_COINS)

	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 12, 0.5, 0)
	icon.Size = UDim2.fromOffset(28, 28)
	icon.BackgroundColor3 = Color3.fromRGB(255, 250, 235)
	icon.BorderSizePixel = 0
	icon.Parent = frame
	UITheme.styleCorner(icon, 14)
	UITheme.applyStroke(icon, UITheme.STROKE_CARD)

	local iconImage = Instance.new("ImageLabel")
	iconImage.Name = "Glyph"
	iconImage.BackgroundTransparency = 1
	iconImage.AnchorPoint = Vector2.new(0.5, 0.5)
	iconImage.Position = UDim2.fromScale(0.5, 0.5)
	iconImage.Size = UDim2.fromScale(0.8, 0.8)
	iconImage.Image = "rbxassetid://15993201893"
	iconImage.ScaleType = Enum.ScaleType.Fit
	iconImage.Parent = icon

	local label = Instance.new("TextLabel")
	label.Name = "Amount"
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, 52, 0.5, 0)
	label.Size = UDim2.new(1, -64, 1, 0)
	label.BackgroundTransparency = 1
	label.TextSize = 22
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = "0"
	label.Parent = frame
	UITheme.applyOutlinedTitle(label, UITheme.TITLE)
	label.TextSize = 22

	self.amountLabel = label
	return self
end

function CoinCounter.setBalance(self: CoinCounter, amount: number)
	if self.amountLabel then
		self.amountLabel.Text = string.format("%d", amount)
	end
end

function CoinCounter.showDelta(self: CoinCounter, delta: number)
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

return CoinCounter
