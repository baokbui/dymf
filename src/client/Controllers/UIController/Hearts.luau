--!strict
--[[
	Hearts
	House health as five ♥ icons inside a horizontal HUD box (below coins).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProgressConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.ProgressConfig)

local Hearts = {}
Hearts.__index = Hearts

local PANEL_WIDTH = 168
local PANEL_HEIGHT = 48
local HEART_SIZE = 28
local HEART_GAP = 4
local FILLED = Color3.fromRGB(235, 75, 95)
local EMPTY = Color3.fromRGB(90, 78, 88)
local PANEL_BG = Color3.fromRGB(22, 24, 34)

export type HeartsHud = typeof(setmetatable(
	{} :: {
		frame: Frame,
		icons: { TextLabel },
		health: number,
		maxHealth: number,
	},
	Hearts
))

local function styleCorner(instance: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

function Hearts.new(parent: Frame): HeartsHud
	local maxHealth = ProgressConfig.MAX_PLAYER_HEALTH
	parent.Visible = true
	parent.AnchorPoint = Vector2.new(0, 0)
	-- Coins sit at (16, 16) with height 52; leave an 8px gap.
	parent.Position = UDim2.fromOffset(16, 76)
	parent.Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT)
	parent.BackgroundColor3 = PANEL_BG
	parent.BackgroundTransparency = 0.2
	parent.BorderSizePixel = 0
	styleCorner(parent, 12)

	local rowWidth = maxHealth * (HEART_SIZE + HEART_GAP) - HEART_GAP
	local startX = math.floor((PANEL_WIDTH - rowWidth) / 2)

	local icons: { TextLabel } = {}
	for i = 1, maxHealth do
		local icon = Instance.new("TextLabel")
		icon.Name = "Heart" .. i
		icon.BackgroundTransparency = 1
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, startX + (i - 1) * (HEART_SIZE + HEART_GAP), 0.5, 0)
		icon.Size = UDim2.fromOffset(HEART_SIZE, HEART_SIZE)
		-- SourceSans renders the heart glyph cleanly; Gotham often falls back to a box.
		icon.Font = Enum.Font.SourceSansBold
		icon.TextSize = 30
		icon.Text = "♥"
		icon.TextColor3 = FILLED
		icon.TextStrokeColor3 = Color3.fromRGB(40, 12, 18)
		icon.TextStrokeTransparency = 0.55
		icon.Parent = parent
		table.insert(icons, icon)
	end

	return setmetatable({
		frame = parent,
		icons = icons,
		health = maxHealth,
		maxHealth = maxHealth,
	}, Hearts)
end

function Hearts.setHealth(self: HeartsHud, health: number, maxHealth: number?)
	self.health = math.max(0, math.floor(health))
	if type(maxHealth) == "number" then
		self.maxHealth = math.max(1, math.floor(maxHealth))
	end
	for index, icon in self.icons do
		if index <= self.health then
			icon.Text = "♥"
			icon.TextColor3 = FILLED
			icon.TextTransparency = 0
			icon.TextStrokeTransparency = 0.55
		else
			icon.Text = "♡"
			icon.TextColor3 = EMPTY
			icon.TextTransparency = 0.15
			icon.TextStrokeTransparency = 0.85
		end
	end
end

return Hearts
