--!strict
--[[
	Hearts
	House health as five ♥ icons at top-left (no chip).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressConfig = require(Shared.Config.ProgressConfig)
local UITheme = require(Shared.Config.UITheme)

local Hearts = {}
Hearts.__index = Hearts

local HEART_SIZE = 44
local HEART_GAP = 6
local HEART_TEXT_SIZE = 48

export type HeartsHud = typeof(setmetatable(
	{} :: {
		frame: Frame,
		icons: { TextLabel },
		health: number,
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
			icon.TextColor3 = UITheme.HEART_FILLED
			icon.TextTransparency = 0
			icon.TextStrokeTransparency = 0
		else
			icon.Text = "♡"
			icon.TextColor3 = UITheme.HEART_EMPTY
			icon.TextTransparency = 0.1
			icon.TextStrokeTransparency = 0.35
		end
	end
end

return Hearts
