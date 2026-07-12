--!strict
--[[
	RewardPopup
	Victory overlay showing brains earned for clearing a level.
]]

local RewardPopup = {}
RewardPopup.__index = RewardPopup

local PANEL_BG = Color3.fromRGB(18, 20, 30)
local TEXT = Color3.fromRGB(235, 238, 245)
local ACCENT = Color3.fromRGB(120, 220, 140)
local BRAIN = Color3.fromRGB(180, 140, 255)

export type RewardPopupHud = typeof(setmetatable(
	{} :: {
		frame: Frame,
		title: TextLabel,
		detail: TextLabel,
	},
	RewardPopup
))

local function styleCorner(instance: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

function RewardPopup.new(parent: Frame): RewardPopupHud
	parent.Visible = false
	parent.AnchorPoint = Vector2.new(0.5, 0.5)
	parent.Position = UDim2.fromScale(0.5, 0.42)
	parent.Size = UDim2.fromOffset(320, 140)
	parent.BackgroundColor3 = PANEL_BG
	parent.BackgroundTransparency = 0.08
	parent.ZIndex = 20
	styleCorner(parent, 14)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -24, 0, 36)
	title.Position = UDim2.fromOffset(12, 18)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 24
	title.TextColor3 = ACCENT
	title.Text = "Victory!"
	title.Parent = parent

	local detail = Instance.new("TextLabel")
	detail.Name = "Detail"
	detail.BackgroundTransparency = 1
	detail.Size = UDim2.new(1, -24, 0, 48)
	detail.Position = UDim2.fromOffset(12, 64)
	detail.Font = Enum.Font.Gotham
	detail.TextSize = 18
	detail.TextColor3 = TEXT
	detail.Text = ""
	detail.TextWrapped = true
	detail.Parent = parent

	return setmetatable({
		frame = parent,
		title = title,
		detail = detail,
	}, RewardPopup)
end

function RewardPopup.show(self: RewardPopupHud, clearedLevel: number, brains: number)
	self.title.Text = string.format("Level %d Cleared!", clearedLevel)
	self.detail.Text = string.format("Reward: +%d Brain%s", brains, if brains == 1 then "" else "s")
	self.detail.TextColor3 = BRAIN
	self.frame.Visible = true
end

function RewardPopup.hide(self: RewardPopupHud)
	self.frame.Visible = false
end

return RewardPopup
