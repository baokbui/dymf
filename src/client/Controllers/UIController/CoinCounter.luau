--!strict
--[[
	CoinCounter
	Mid-left coin balance: icon + amount (no chip). Floating +/- on collect/spend.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage:WaitForChild("Shared").Config.UITheme)

local CoinCounter = {}
CoinCounter.__index = CoinCounter

local FLOAT_DURATION = 0.85
local FLOAT_OFFSET_Y = -40
local DELTA_TEXT_SIZE = 20

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
	frame.Position = UDim2.fromOffset(16, 68)
	frame.Size = UDim2.fromOffset(78, 32)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = false

	local icon = Instance.new("ImageLabel")
	icon.Name = "Glyph"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 0, 0.5, 0)
	icon.Size = UDim2.fromOffset(32, 32)
	icon.Image = "rbxassetid://15993201893"
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Amount"
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, 36, 0.5, 0)
	label.Size = UDim2.new(1, -36, 1, 0)
	label.BackgroundTransparency = 1
	label.TextSize = 19
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = "0"
	label.Parent = frame
	UITheme.applyOutlinedTitle(label, UITheme.TITLE)
	label.TextSize = 19

	self.amountLabel = label
	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MaxTextSize = 19
	textLimit.Parent = label
	label.TextScaled = true

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
	popup.Size = UDim2.fromOffset(78, 28)
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
