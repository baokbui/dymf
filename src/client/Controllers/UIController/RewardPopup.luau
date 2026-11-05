--!strict
--[[
	RewardPopup
	Victory overlay: day-clear brains, leftover-gold brains, and total.
	After the title, lines pop in (scale, no fade) then Continue.
	Cartoon thick-outline look via UITheme.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UITheme = require(ReplicatedStorage:WaitForChild("Shared").Config.UITheme)
local PanelPattern = require(script.Parent.Parent.Parent.Utilities.PanelPattern)
local AudioController = require(script.Parent.Parent.AudioController)

local RewardPopup = {}
RewardPopup.__index = RewardPopup

local POP_INFO = TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local POP_START_DELAY = 0.75
local POP_STAGGER = 0.9

export type RewardPopupHud = typeof(setmetatable(
	{} :: {
		frame: Frame,
		title: TextLabel,
		dayLine: TextLabel,
		leftoverLine: TextLabel,
		totalLine: TextLabel,
		continueButton: TextButton,
		popOrder: { GuiObject },
		popScales: { [GuiObject]: UIScale },
		popToken: number,
		onContinue: (() -> ())?,
	},
	RewardPopup
))

local function attachScale(gui: GuiObject): UIScale
	local scale = Instance.new("UIScale")
	scale.Name = "PopScale"
	scale.Scale = 1
	scale.Parent = gui
	return scale
end

function RewardPopup.new(parent: Frame): RewardPopupHud
	parent.Visible = false
	parent.AnchorPoint = Vector2.new(0.5, 0.5)
	parent.Position = UDim2.fromScale(0.5, 0.42)
	parent.Size = UDim2.fromOffset(420, 268)
	parent.ZIndex = 20
	parent.ClipsDescendants = false
	UITheme.applyPanelLook(parent, nil, UITheme.PANEL_BG_REWARD)
	UITheme.applySurfaceDepth(parent)
	PanelPattern.mount(parent, "Diagonal", UITheme.TITLE, 0.24, 7)
	for _, side in { -1, 1 } do
		for index = 1, 3 do
			local spark = Instance.new("Frame")
			spark.Name = "VictorySpark"
			spark.AnchorPoint = Vector2.new(0.5, 0.5)
			spark.Position = UDim2.new(0.5, side * (80 + index * 15), 0, if index == 2 then 23 else 35)
			spark.Size = UDim2.fromOffset(if index == 2 then 11 else 6, if index == 2 then 11 else 6)
			spark.BackgroundColor3, spark.BorderSizePixel = UITheme.TITLE, 0
			spark.Rotation = 45
			spark.Parent = parent
		end
	end

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0, 14)
	title.Size = UDim2.new(1, -24, 0, 32)
	title.TextSize = 22
	title.Text = "Victory!"
	title.Parent = parent
	UITheme.applyOutlinedTitle(title, UITheme.TITLE)

	local dayLine = Instance.new("TextLabel")
	dayLine.Name = "DayBrains"
	dayLine.BackgroundTransparency = 1
	dayLine.AnchorPoint = Vector2.new(0.5, 0.5)
	dayLine.Position = UDim2.new(0.5, 0, 0, 66)
	dayLine.Size = UDim2.new(1, -24, 0, 28)
	dayLine.TextSize = 16
	dayLine.TextWrapped = true
	dayLine.Visible = false
	dayLine.Text = ""
	dayLine.Parent = parent
	UITheme.applyOutlinedTitle(dayLine, UITheme.TITLE)
	dayLine.TextSize = 16

	local leftoverLine = Instance.new("TextLabel")
	leftoverLine.Name = "LeftoverBrains"
	leftoverLine.BackgroundTransparency = 1
	leftoverLine.AnchorPoint = Vector2.new(0.5, 0.5)
	leftoverLine.Position = UDim2.new(0.5, 0, 0, 93)
	leftoverLine.Size = UDim2.new(1, -24, 0, 22)
	leftoverLine.TextSize = 13
	leftoverLine.TextWrapped = true
	leftoverLine.Visible = false
	leftoverLine.Text = ""
	leftoverLine.Parent = parent
	UITheme.applyOutlinedTitle(leftoverLine, UITheme.TITLE)
	leftoverLine.TextSize = 13

	local totalLine = Instance.new("TextLabel")
	totalLine.Name = "TotalBrains"
	UITheme.applyButtonLook(totalLine, Color3.fromRGB(255, 245, 190), 12)
	totalLine.AnchorPoint = Vector2.new(0.5, 0.5)
	totalLine.Position = UDim2.new(0.5, 0, 0, 142)
	totalLine.Size = UDim2.new(1, -76, 0, 48)
	totalLine.TextSize = 26
	totalLine.TextWrapped = true
	totalLine.Visible = false
	totalLine.Text = ""
	totalLine.Parent = parent
	UITheme.applyOutlinedTitle(totalLine, UITheme.BRAIN)
	totalLine.TextSize = 26

	local continueButton = Instance.new("TextButton")
	continueButton.Name = "Continue"
	continueButton.AnchorPoint = Vector2.new(0.5, 1)
	continueButton.Position = UDim2.new(0.5, 0, 1, -16)
	continueButton.Size = UDim2.fromOffset(180, 42)
	continueButton.ZIndex = 21
	continueButton.Text = "Continue"
	continueButton.TextSize = 18
	continueButton.Visible = false
	continueButton.Active = false
	continueButton.Parent = parent
	UITheme.applyButtonLook(continueButton, UITheme.SUCCESS)
	UITheme.applySurfaceDepth(continueButton)
	UITheme.applyOutlinedTitle(continueButton)
	continueButton.TextSize = 18

	local popOrder: { GuiObject } = { dayLine, leftoverLine, totalLine, continueButton }
	local popScales: { [GuiObject]: UIScale } = {}
	for _, gui in popOrder do
		popScales[gui] = attachScale(gui)
	end

	local self = setmetatable({
		frame = parent,
		title = title,
		dayLine = dayLine,
		leftoverLine = leftoverLine,
		totalLine = totalLine,
		continueButton = continueButton,
		popOrder = popOrder,
		popScales = popScales,
		popToken = 0,
		onContinue = nil,
	}, RewardPopup)

	continueButton.MouseButton1Click:Connect(function()
		if not parent.Visible or not continueButton.Visible or not continueButton.Active then
			return
		end
		AudioController.play("UiClick")
		self:hide()
		local callback = self.onContinue
		if callback then
			callback()
		end
	end)

	return self
end

local function popIn(gui: GuiObject, scale: UIScale)
	scale.Scale = 0.2
	gui.Visible = true
	if gui:IsA("GuiButton") then
		gui.Active = true
	end
	TweenService:Create(scale, POP_INFO, { Scale = 1 }):Play()
end

local function present(self: RewardPopupHud)
	self.popToken += 1
	local token = self.popToken
	for _, gui in self.popOrder do
		gui.Visible = false
		if gui:IsA("GuiButton") then
			gui.Active = false
		end
		self.popScales[gui].Scale = 0.2
	end

	self.frame.Visible = true
	AudioController.play("Victory")

	for index, gui in self.popOrder do
		local delay = POP_START_DELAY + (index - 1) * POP_STAGGER
		task.delay(delay, function()
			if self.popToken ~= token or not self.frame.Visible then
				return
			end
			popIn(gui, self.popScales[gui])
			if gui ~= self.continueButton then
				AudioController.play("RewardLine")
			end
		end)
	end
end

function RewardPopup.show(self: RewardPopupHud, clearedLevel: number, dayBrains: number, leftoverBrains: number?)
	local leftover = leftoverBrains or 0
	local total = dayBrains + leftover
	self.title.Text = string.format("Day %d Cleared!", clearedLevel)
	self.dayLine.Text = string.format("Day reward: %d Brains", dayBrains)
	self.leftoverLine.Text = string.format("Leftover coins: %d Brains", leftover)
	self.totalLine.Text = string.format("Total: %d Brains", total)
	present(self)
end

function RewardPopup.showHidden(self: RewardPopupHud, dayBrains: number, leftoverBrains: number?)
	local leftover = leftoverBrains or 0
	local total = dayBrains + leftover
	self.title.Text = "Hidden Day"
	self.dayLine.Text = string.format("Brains earned: %d Brains", dayBrains)
	self.leftoverLine.Text = string.format("Leftover coins: %d Brains", leftover)
	self.totalLine.Text = string.format("Total: %d Brains", total)
	present(self)
end

function RewardPopup.hide(self: RewardPopupHud)
	self.popToken += 1
	self.continueButton.Active = false
	self.frame.Visible = false
end

return RewardPopup
