--!strict
--[[
	MonsterIntroPopup
	Center-screen intro shown the first time the player reaches a day that
	introduces a new monster / boss (ProgressConfig.MONSTER_INTRO_SCHEDULE).
	Display-only — LevelService decides what/when via introducedMonsterId.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monsters = require(Shared.Monsters)
local UITheme = require(Shared.Config.UITheme)

local MonsterPreview = require(script.Parent.Parent.Parent.Utilities.MonsterPreview)
local MonsterInfo = require(script.Parent.Parent.Parent.Utilities.MonsterInfo)
local AudioController = require(script.Parent.Parent.AudioController)

local MonsterIntroPopup = {}
MonsterIntroPopup.__index = MonsterIntroPopup

local PORTRAIT_SIZE = 120

export type MonsterIntroPopupHud = typeof(setmetatable(
	{} :: {
		frame: Frame,
		banner: TextLabel,
		portraitHolder: Frame,
		nameLabel: TextLabel,
		statsLabel: TextLabel,
		abilityLabel: TextLabel,
	},
	MonsterIntroPopup
))

function MonsterIntroPopup.new(parent: Frame): MonsterIntroPopupHud
	parent.Visible = false
	parent.AnchorPoint = Vector2.new(0.5, 0.5)
	parent.Position = UDim2.fromScale(0.5, 0.5)
	parent.Size = UDim2.fromOffset(400, 420)
	parent.ZIndex = 41
	UITheme.applyPanelLook(parent, nil, UITheme.PANEL_BG_MONSTER_INTRO)

	local banner = Instance.new("TextLabel")
	banner.Name = "Banner"
	banner.BackgroundTransparency = 1
	banner.Size = UDim2.new(1, -24, 0, 28)
	banner.Position = UDim2.fromOffset(12, 14)
	banner.TextSize = 16
	banner.Text = "NEW MONSTER!"
	banner.Parent = parent
	UITheme.applyOutlinedTitle(banner, UITheme.WARNING)

	local portraitHolder = Instance.new("Frame")
	portraitHolder.Name = "PortraitHolder"
	portraitHolder.AnchorPoint = Vector2.new(0.5, 0)
	portraitHolder.Position = UDim2.new(0.5, 0, 0, 50)
	portraitHolder.Size = UDim2.fromOffset(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portraitHolder.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
	portraitHolder.BackgroundTransparency = 0.15
	portraitHolder.BorderSizePixel = 0
	portraitHolder.Parent = parent
	UITheme.styleCorner(portraitHolder, 12)
	UITheme.applyStroke(portraitHolder, 3)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.BackgroundTransparency = 1
	nameLabel.AnchorPoint = Vector2.new(0.5, 0)
	nameLabel.Position = UDim2.new(0.5, 0, 0, 182)
	nameLabel.Size = UDim2.new(1, -24, 0, 26)
	nameLabel.TextSize = 20
	nameLabel.Text = ""
	nameLabel.Parent = parent
	UITheme.applyOutlinedTitle(nameLabel)

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "Stats"
	statsLabel.BackgroundTransparency = 1
	statsLabel.AnchorPoint = Vector2.new(0.5, 0)
	statsLabel.Position = UDim2.new(0.5, 0, 0, 210)
	statsLabel.Size = UDim2.new(1, -32, 0, 40)
	statsLabel.TextSize = 13
	statsLabel.TextWrapped = true
	statsLabel.Text = ""
	statsLabel.Parent = parent
	UITheme.applyOutlinedTitle(statsLabel, UITheme.TITLE)

	local abilityCard = Instance.new("Frame")
	abilityCard.Name = "AbilityCard"
	abilityCard.AnchorPoint = Vector2.new(0.5, 0)
	abilityCard.Position = UDim2.new(0.5, 0, 0, 256)
	abilityCard.Size = UDim2.new(1, -32, 0, 78)
	abilityCard.BackgroundColor3 = Color3.fromRGB(255, 245, 230)
	abilityCard.BorderSizePixel = 0
	abilityCard.Parent = parent
	UITheme.styleCorner(abilityCard, 10)
	UITheme.applyStroke(abilityCard, 2)

	local abilityLabel = Instance.new("TextLabel")
	abilityLabel.Name = "Ability"
	abilityLabel.BackgroundTransparency = 1
	abilityLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	abilityLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
	abilityLabel.Size = UDim2.new(1, -16, 1, -10)
	abilityLabel.TextSize = 13
	abilityLabel.TextWrapped = true
	abilityLabel.Text = ""
	abilityLabel.Parent = abilityCard
	UITheme.applyBodyText(abilityLabel, UITheme.SUBTEXT)

	local dismiss = Instance.new("TextButton")
	dismiss.Name = "Dismiss"
	dismiss.AnchorPoint = Vector2.new(0.5, 1)
	dismiss.Position = UDim2.new(0.5, 0, 1, -16)
	dismiss.Size = UDim2.fromOffset(160, 40)
	dismiss.TextSize = 16
	dismiss.Text = "Got it!"
	dismiss.Parent = parent
	UITheme.applyButtonLook(dismiss, UITheme.WARNING)
	UITheme.applyOutlinedTitle(dismiss)

	local self = setmetatable({
		frame = parent,
		banner = banner,
		portraitHolder = portraitHolder,
		nameLabel = nameLabel,
		statsLabel = statsLabel,
		abilityLabel = abilityLabel,
	}, MonsterIntroPopup) :: MonsterIntroPopupHud

	dismiss.Activated:Connect(function()
		AudioController.play("UiClick")
		self:hide()
	end)

	return self
end

function MonsterIntroPopup.show(self: MonsterIntroPopupHud, monsterId: string)
	local definition = Monsters.get(monsterId)
	if not definition then
		return
	end

	for _, child in self.portraitHolder:GetChildren() do
		child:Destroy()
	end
	MonsterPreview.mount(
		self.portraitHolder,
		definition,
		UDim2.fromOffset(PORTRAIT_SIZE - 10, PORTRAIT_SIZE - 10),
		UDim2.new(0.5, 0, 0, 5)
	)

	self.banner.Text = if definition.isBoss then "NEW BOSS!" else "NEW MONSTER!"
	self.nameLabel.Text = definition.name

	local pieces: { string } = {}
	for _, row in MonsterInfo.statRows(definition) do
		table.insert(pieces, string.format("%s: %s", row.label, row.value))
	end
	self.statsLabel.Text = table.concat(pieces, "   •   ")
	self.abilityLabel.Text = MonsterInfo.abilitySummary(definition)

	self.frame.Visible = true
end

function MonsterIntroPopup.hide(self: MonsterIntroPopupHud)
	self.frame.Visible = false
end

return MonsterIntroPopup
