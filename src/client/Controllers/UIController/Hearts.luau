--!strict
--[[
	Hearts
	House health as five ♥ icons at top-left (no chip).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressConfig = require(Shared.Config.ProgressConfig)
local UITheme = require(Shared.Config.UITheme)

local Hearts = {}
Hearts.__index = Hearts

local HEART_SIZE = 44
local HEART_GAP = 6
local HEART_TEXT_SIZE = 48
local BREAK_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

export type HeartsHud = typeof(setmetatable(
	{} :: {
		frame: Frame,
		icons: { TextLabel },
		health: number?,
		maxHealth: number,
	},
	Hearts
))

function Hearts.new(parent: Frame): HeartsHud
	local maxHealth = ProgressConfig.MAX_PLAYER_HEALTH
	local rowWidth = maxHealth * (HEART_SIZE + HEART_GAP) - HEART_GAP

	parent.Visible = true
	parent.AnchorPoint = Vector2.new(0, 0)
	parent.Position = UDim2.fromOffset(16, 16)
	parent.Size = UDim2.fromOffset(rowWidth, HEART_SIZE)
	parent.BackgroundTransparency = 1
	parent.BorderSizePixel = 0
	parent.ClipsDescendants = false

	local stroke = parent:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke:Destroy()
	end
	local corner = parent:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Destroy()
	end

	local icons: { TextLabel } = {}
	for i = 1, maxHealth do
		local icon = Instance.new("TextLabel")
		icon.Name = "Heart" .. i
		icon.BackgroundTransparency = 1
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, (i - 1) * (HEART_SIZE + HEART_GAP), 0.5, 0)
		icon.Size = UDim2.fromOffset(HEART_SIZE, HEART_SIZE)
		icon.Font = Enum.Font.SourceSansBold
		icon.TextSize = HEART_TEXT_SIZE
		icon.Text = "♥"
		icon.TextColor3 = UITheme.HEART_FILLED
		icon.TextStrokeColor3 = UITheme.OUTLINE
		icon.TextStrokeTransparency = 0
		icon.Parent = parent
		table.insert(icons, icon)
	end

	return setmetatable({
		frame = parent,
		icons = icons,
		maxHealth = maxHealth,
	}, Hearts)
end

local function playBreak(icon: TextLabel)
	local effect = Instance.new("Frame")
	effect.Name = "HeartBreak"
	effect.BackgroundTransparency = 1
	effect.Size = UDim2.fromScale(1, 1)
	effect.ZIndex = icon.ZIndex + 1

	-- Clip two copies at the midpoint so the pieces match the exact HUD glyph.
	for _, direction in { -1, 1 } do
		local side = if direction < 0 then 0 else 0.5
		local half = Instance.new("Frame")
		half.BackgroundTransparency = 1
		half.Size = UDim2.fromScale(0.5, 1)
		half.Position = UDim2.fromScale(side, 0)
		half.ClipsDescendants = true
		half.ZIndex = effect.ZIndex
		half.Parent = effect

		local piece = icon:Clone()
		piece.AnchorPoint = Vector2.zero
		piece.Position = UDim2.fromScale(if direction < 0 then 0 else -1, 0)
		piece.Size = UDim2.fromScale(2, 1)
		piece.ZIndex = effect.ZIndex
		piece.Parent = half

		TweenService:Create(half, BREAK_TWEEN, {
			Position = UDim2.new(side, direction * 13, 0, if direction < 0 then 7 else 12),
		}):Play()
		TweenService:Create(piece, BREAK_TWEEN, {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
	end
	effect.Parent = icon
	task.delay(BREAK_TWEEN.Time, function()
		if effect.Parent then effect:Destroy() end
	end)
end

function Hearts.setHealth(self: HeartsHud, health: number, maxHealth: number?)
	local previous = self.health
	local previousMax = self.maxHealth
	local current = math.max(0, math.floor(health))
	self.health = current
	if type(maxHealth) == "number" then
		self.maxHealth = math.max(1, math.floor(maxHealth))
	end
	for index, icon in self.icons do
		icon.Visible = index <= self.maxHealth
		if index <= current then
			local effect = icon:FindFirstChild("HeartBreak")
			if effect then effect:Destroy() end
			icon.Text = "♥"
			icon.TextColor3 = UITheme.HEART_FILLED
			icon.TextTransparency = 0
			icon.TextStrokeTransparency = 0
		else
			if previous and index <= previous and icon.Visible and self.maxHealth == previousMax then
				playBreak(icon)
			end
			icon.Text = "♡"
			icon.TextColor3 = UITheme.HEART_EMPTY
			icon.TextTransparency = 0.1
			icon.TextStrokeTransparency = 0.35
		end
	end
end

return Hearts
