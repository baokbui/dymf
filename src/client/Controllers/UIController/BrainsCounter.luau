--!strict
--[[
	BrainsCounter
	Top-left brains balance display, docked directly under the coin counter.
	Display-only — value comes from ProfileUpdated / RequestState.
	Cartoon thick-outline look via UITheme.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage:WaitForChild("Shared").Config.UITheme)

local BrainsCounter = {}
BrainsCounter.__index = BrainsCounter

local BRAIN_ICON_ASSET_ID = "rbxassetid://12691330734"

local function buildBrainGlyph(parent: Instance)
	local image = Instance.new("ImageLabel")
	image.Name = "Glyph"
	image.BackgroundTransparency = 1
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Size = UDim2.fromScale(0.8, 0.8)
	image.Image = BRAIN_ICON_ASSET_ID
	image.ScaleType = Enum.ScaleType.Fit
	image.Parent = parent
end

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
	frame.Position = UDim2.fromOffset(16, 76)
	frame.Size = UDim2.fromOffset(168, 52)
	frame.ClipsDescendants = false
	UITheme.applyChipLook(frame, UITheme.CHIP_BG_BRAINS)

	-- Round badge (same shape language as the coin chip) holding a small
	-- procedural cartoon brain icon — no external image asset dependency.
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 12, 0.5, 0)
	icon.Size = UDim2.fromOffset(28, 28)
	icon.BackgroundColor3 = Color3.fromRGB(245, 240, 255)
	icon.BorderSizePixel = 0
	icon.Parent = frame
	UITheme.styleCorner(icon, 14)
	UITheme.applyStroke(icon, UITheme.STROKE_CARD)

	buildBrainGlyph(icon)

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

	return setmetatable({
		frame = frame,
		amountLabel = label,
	}, BrainsCounter)
end

function BrainsCounter.setBalance(self: BrainsCounter, amount: number)
	self.amountLabel.Text = string.format("%d", amount)
end

return BrainsCounter
