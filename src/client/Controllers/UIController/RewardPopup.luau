--!strict
--[[
	RewardPopup
	Victory overlay showing brains earned for clearing a day.
	Cartoon thick-outline look via UITheme.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UITheme = require(ReplicatedStorage:WaitForChild("Shared").Config.UITheme)

local RewardPopup = {}
RewardPopup.__index = RewardPopup

export type RewardPopupHud = typeof(setmetatable(
	{} :: {
		frame: Frame,
		title: TextLabel,
		detail: TextLabel,
	},
	RewardPopup
))

function RewardPopup.new(parent: Frame): RewardPopupHud
	parent.Visible = false
	parent.AnchorPoint = Vector2.new(0.5, 0.5)
	parent.Position = UDim2.fromScale(0.5, 0.42)
	parent.Size = UDim2.fromOffset(320, 140)
	parent.ZIndex = 20
	UITheme.applyPanelLook(parent, nil, UITheme.PANEL_BG_REWARD)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -24, 0, 36)
	title.Position = UDim2.fromOffset(12, 18)
	title.TextSize = 24
	title.Text = "Victory!"
	title.Parent = parent
	UITheme.applyOutlinedTitle(title, UITheme.TITLE)

	local detail = Instance.new("TextLabel")
	detail.Name = "Detail"
	detail.BackgroundTransparency = 1
	detail.Size = UDim2.new(1, -24, 0, 48)
	detail.Position = UDim2.fromOffset(12, 64)
	detail.TextSize = 18
	detail.Text = ""
	detail.TextWrapped = true
	detail.Parent = parent
	UITheme.applyOutlinedTitle(detail, UITheme.BRAIN)
	detail.TextSize = 18

	return setmetatable({
		frame = parent,
		title = title,
		detail = detail,
	}, RewardPopup)
end

function RewardPopup.show(self: RewardPopupHud, clearedLevel: number, brains: number)
	self.title.Text = string.format("Day %d Cleared!", clearedLevel)
	self.detail.Text = string.format("Reward: +%d Brain%s", brains, if brains == 1 then "" else "s")
	UITheme.applyOutlinedTitle(self.detail, UITheme.BRAIN)
	self.detail.TextSize = 18
	self.frame.Visible = true
end

function RewardPopup.hide(self: RewardPopupHud)
	self.frame.Visible = false
end

return RewardPopup
