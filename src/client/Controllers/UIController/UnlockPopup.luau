--!strict
--[[
	UnlockPopup
	Decently-sized center-screen celebration shown the first time a starter
	roster Brainrot unlocks (ProgressConfig.UNLOCK_SCHEDULE, granted by
	LevelService on victory). Display-only — the server decides what/when to
	unlock; this just presents it. Cartoon thick-outline look via UITheme.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared.Brainrots)
local UITheme = require(Shared.Config.UITheme)

local BrainrotPreview = require(script.Parent.Parent.Parent.Utilities.BrainrotPreview)
local BrainrotInfo = require(script.Parent.Parent.Parent.Utilities.BrainrotInfo)
local AudioController = require(script.Parent.Parent.AudioController)

local UnlockPopup = {}
UnlockPopup.__index = UnlockPopup

local PORTRAIT_SIZE = 120

export type UnlockPopupHud = typeof(setmetatable(
	{} :: {
		frame: Frame,
		portraitHolder: Frame,
		nameLabel: TextLabel,
		statsLabel: TextLabel,
		abilityLabel: TextLabel,
		onHidden: (() -> ())?,
	},
	UnlockPopup
))

function UnlockPopup.new(parent: Frame): UnlockPopupHud
	parent.Visible = false
	parent.AnchorPoint = Vector2.new(0.5, 0.5)
	parent.Position = UDim2.fromScale(0.5, 0.5)
	parent.Size = UDim2.fromOffset(400, 400)
	parent.ZIndex = 40
	UITheme.applyPanelLook(parent, nil, UITheme.PANEL_BG_UNLOCK)

	local banner = Instance.new("TextLabel")
	banner.Name = "Banner"
	banner.BackgroundTransparency = 1
	banner.Size = UDim2.new(1, -24, 0, 28)
	banner.Position = UDim2.fromOffset(12, 14)
	banner.TextSize = 16
	banner.Text = "NEW BRAINROT UNLOCKED!"
	banner.Parent = parent
	UITheme.applyOutlinedTitle(banner, UITheme.GOLD_TEXT)

	local portraitHolder = Instance.new("Frame")
	portraitHolder.Name = "PortraitHolder"
	portraitHolder.AnchorPoint = Vector2.new(0.5, 0)
	portraitHolder.Position = UDim2.new(0.5, 0, 0, 50)
	portraitHolder.Size = UDim2.fromOffset(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portraitHolder.BackgroundColor3 = Color3.fromRGB(235, 245, 255)
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
	abilityCard.Size = UDim2.new(1, -32, 0, 60)
	abilityCard.BackgroundColor3 = Color3.fromRGB(245, 240, 255)
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
	UITheme.applyOutlinedTitle(abilityLabel)
	abilityLabel.TextSize = 13

	local dismiss = Instance.new("TextButton")
	dismiss.Name = "Dismiss"
	dismiss.AnchorPoint = Vector2.new(0.5, 1)
	dismiss.Position = UDim2.new(0.5, 0, 1, -16)
	dismiss.Size = UDim2.fromOffset(160, 40)
	dismiss.TextSize = 16
	dismiss.Text = "Awesome!"
	dismiss.Parent = parent
	UITheme.applyButtonLook(dismiss, UITheme.SUCCESS)
	UITheme.applyOutlinedTitle(dismiss)

	local self = setmetatable({
		frame = parent,
		portraitHolder = portraitHolder,
		nameLabel = nameLabel,
		statsLabel = statsLabel,
		abilityLabel = abilityLabel,
	}, UnlockPopup) :: UnlockPopupHud

	dismiss.Activated:Connect(function()
		AudioController.play("UiClick")
		self:hide()
	end)

	return self
end

function UnlockPopup.show(self: UnlockPopupHud, brainrotId: string)
	local definition = Brainrots.get(brainrotId)
	if not definition then
		return
	end

	for _, child in self.portraitHolder:GetChildren() do
		child:Destroy()
	end
	BrainrotPreview.mount(
		self.portraitHolder,
		definition,
		UDim2.fromOffset(PORTRAIT_SIZE - 10, PORTRAIT_SIZE - 10),
		UDim2.new(0.5, 0, 0, 5)
	)

	self.nameLabel.Text = definition.name

	local pieces: { string } = {}
	for _, row in BrainrotInfo.statRows(definition) do
		if row.label ~= "Ability" then
			table.insert(pieces, string.format("%s: %s", row.label, row.value))
		end
	end
	self.statsLabel.Text = table.concat(pieces, "   •   ")

	self.abilityLabel.Text = string.format(
		"%s — %s",
		BrainrotInfo.abilityLabel(definition.ability),
		BrainrotInfo.abilityDescription(definition.ability)
	)

	self.frame.Visible = true
end

function UnlockPopup.hide(self: UnlockPopupHud)
	self.frame.Visible = false
	if self.onHidden then
		self.onHidden()
	end
end

return UnlockPopup
