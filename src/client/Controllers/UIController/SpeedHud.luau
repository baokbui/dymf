--!strict
--[[
	SpeedHud
	Mid-left walk-speed: icon + amount under brains. Display-only.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlayerConfig = require(Shared.Config.PlayerConfig)
local ProgressConfig = require(Shared.Config.ProgressConfig)
local UITheme = require(Shared.Config.UITheme)

local SpeedHud = {}
SpeedHud.__index = SpeedHud

-- Image asset 95328996745955; ImageLabel uses the texture id.
local SPEED_ICON_TEXTURE_ID = "rbxassetid://82103513055414"

export type SpeedHud = typeof(setmetatable(
	{} :: {
		frame: Frame,
		amountLabel: TextLabel,
	},
	SpeedHud
))

local function walkSpeedFromUpgrades(upgrades: { [string]: number }): number
	local speed = PlayerConfig.WALK_SPEED
	local def: any? = nil
	for _, entry in ProgressConfig.UPGRADE_CATALOG do
		if entry.id == "WalkSpeed" then
			def = entry
			break
		end
	end
	if not def then
		return speed
	end
	local level = upgrades["WalkSpeed"] or 0
	local bonus = def.walkSpeedBonusPerLevel
	if type(bonus) ~= "number" then
		bonus = 0
	end
	return speed + level * bonus
end

function SpeedHud.new(frame: Frame): SpeedHud
	frame.Visible = true
	frame.AnchorPoint = Vector2.new(0, 0)
	frame.Position = UDim2.new(0, 16, 0.42, 72)
	frame.Size = UDim2.fromOffset(180, 64)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = false

	local icon = Instance.new("ImageLabel")
	icon.Name = "Glyph"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 0, 0.5, 0)
	icon.Size = UDim2.fromOffset(64, 64)
	icon.Image = SPEED_ICON_TEXTURE_ID
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Amount"
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, 72, 0.5, 0)
	label.Size = UDim2.new(1, -72, 1, 0)
	label.BackgroundTransparency = 1
	label.TextSize = 30
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = tostring(PlayerConfig.WALK_SPEED)
	label.Parent = frame
	UITheme.applyOutlinedTitle(label, UITheme.TITLE)
	label.TextSize = 30

	return setmetatable({
		frame = frame,
		amountLabel = label,
	}, SpeedHud)
end

function SpeedHud.setWalkSpeed(self: SpeedHud, speed: number)
	self.amountLabel.Text = string.format("%d", speed)
end

function SpeedHud.applyUpgrades(self: SpeedHud, upgrades: { [string]: number })
	self:setWalkSpeed(walkSpeedFromUpgrades(upgrades))
end

return SpeedHud
