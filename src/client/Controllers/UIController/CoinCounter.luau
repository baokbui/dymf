--!strict
--[[
	CoinCounter
	Top-left coin balance display plus floating +/- feedback labels.
]]

local TweenService = game:GetService("TweenService")

local CoinCounter = {}
CoinCounter.__index = CoinCounter

local GAIN_COLOR = Color3.fromRGB(120, 255, 140)
local SPEND_COLOR = Color3.fromRGB(255, 110, 110)
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
	frame.BackgroundColor3 = Color3.fromRGB(22, 24, 34)
	frame.BackgroundTransparency = 0.2
	frame.ClipsDescendants = false

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 12, 0.5, 0)
	icon.Size = UDim2.fromOffset(28, 28)
	icon.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
	icon.Parent = frame
	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(1, 0)
	iconCorner.Parent = icon

	local label = Instance.new("TextLabel")
	label.Name = "Amount"
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, 52, 0.5, 0)
	label.Size = UDim2.new(1, -64, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 22
	label.TextColor3 = Color3.fromRGB(255, 215, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = "0"
	label.Parent = frame

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
	popup.Font = Enum.Font.GothamBold
	popup.TextSize = DELTA_TEXT_SIZE
	popup.TextXAlignment = Enum.TextXAlignment.Center
	popup.AnchorPoint = Vector2.new(0.5, 0)
	popup.Position = UDim2.new(0.5, 0, 1, 6)
	popup.Size = UDim2.fromOffset(120, 40)
	popup.ZIndex = self.frame.ZIndex + 1

	if delta > 0 then
		popup.Text = string.format("+%d", delta)
		popup.TextColor3 = GAIN_COLOR
	else
		popup.Text = string.format("%d", delta)
		popup.TextColor3 = SPEND_COLOR
	end

	popup.Parent = self.frame

	local tween = TweenService:Create(
		popup,
		TweenInfo.new(FLOAT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Position = UDim2.new(0.5, 0, 1, 6 + FLOAT_OFFSET_Y),
			TextTransparency = 1,
		}
	)
	tween:Play()
	tween.Completed:Connect(function()
		popup:Destroy()
	end)
end

return CoinCounter
