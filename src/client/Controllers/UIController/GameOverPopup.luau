--!strict
--[[
	GameOverPopup
	Full-screen defeat overlay: slow GAME OVER reveal, Triple T fail message,
	and Rewind Day N. Client-only FX; RewindDay remote asks the server to
	return to Preparation on the failed day.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local UITheme = require(Shared.Config.UITheme)
local UISizing = require(script.Parent.Parent.Parent.Utilities.UISizing)

local AudioController = require(script.Parent.Parent.AudioController)

local GameOverPopup = {}
GameOverPopup.__index = GameOverPopup

local SHOW_TWEEN = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HIDE_TWEEN = TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local CLOCK_SPIN = TweenInfo.new(2.4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 0)
local CLOCK_FADE = TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

export type GameOverPopupHud = typeof(setmetatable(
	{} :: {
		frame: Frame,
		scrim: Frame,
		card: Frame,
		title: TextLabel,
		message: TextLabel,
		rewindButton: TextButton,
		clockRoot: Frame,
		clockHand: Frame,
		dayNumber: number,
		rewinding: boolean,
		showToken: number,
	},
	GameOverPopup
))

local function tween(gui: GuiObject, info: TweenInfo, props: { [string]: any }): Tween
	local t = TweenService:Create(gui, info, props)
	t:Play()
	return t
end

function GameOverPopup.new(parent: Frame): GameOverPopupHud
	parent.Visible = false
	parent.AnchorPoint = Vector2.new(0.5, 0.5)
	parent.Position = UDim2.fromScale(0.5, 0.5)
	parent.Size = UDim2.fromScale(1, 1)
	parent.BackgroundTransparency = 1
	parent.ZIndex = 50
	parent.BorderSizePixel = 0

	local scrim = Instance.new("Frame")
	scrim.Name = "Scrim"
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.BackgroundColor3 = UITheme.MODAL_SCRIM
	scrim.BackgroundTransparency = 1
	scrim.BorderSizePixel = 0
	scrim.ZIndex = 50
	scrim.Parent = parent

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.48)
	card.Size = UDim2.fromOffset(460, 280)
	card.BackgroundTransparency = 1
	card.ZIndex = 51
	card.Parent = parent
	UISizing.scaleContent(card, parent)
	UITheme.applyPanelLook(card, nil, UITheme.PANEL_BG_GAME_OVER)
	card.BackgroundTransparency = 1

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0, 28)
	title.Size = UDim2.new(1, -32, 0, 56)
	title.TextSize = 42
	title.Text = "GAME OVER"
	title.TextTransparency = 1
	title.ZIndex = 52
	title.Parent = card
	UITheme.applyOutlinedTitle(title, UITheme.DANGER)
	title.TextSize = 42

	local message = Instance.new("TextLabel")
	message.Name = "Message"
	message.BackgroundTransparency = 1
	message.AnchorPoint = Vector2.new(0.5, 0)
	message.Position = UDim2.new(0.5, 0, 0, 100)
	message.Size = UDim2.new(1, -48, 0, 64)
	message.TextSize = 16
	message.TextWrapped = true
	message.Text = "You have failed to protect Triple T and his house."
	message.TextTransparency = 1
	message.ZIndex = 52
	message.Parent = card
	UITheme.applyBodyText(message, UITheme.TITLE)
	message.TextSize = 16

	local rewindButton = Instance.new("TextButton")
	rewindButton.Name = "Rewind"
	rewindButton.AnchorPoint = Vector2.new(0.5, 1)
	rewindButton.Position = UDim2.new(0.5, 0, 1, -28)
	rewindButton.Size = UDim2.fromOffset(220, 48)
	rewindButton.TextSize = 18
	rewindButton.Text = "Rewind Day 1"
	rewindButton.TextTransparency = 1
	rewindButton.BackgroundTransparency = 1
	rewindButton.AutoButtonColor = true
	rewindButton.ZIndex = 52
	rewindButton.Parent = card
	UITheme.applyButtonLook(rewindButton, UITheme.WARNING)
	UITheme.applyOutlinedTitle(rewindButton)
	rewindButton.TextSize = 18
	rewindButton.BackgroundTransparency = 1

	local clockRoot = Instance.new("Frame")
	clockRoot.Name = "RewindClock"
	clockRoot.AnchorPoint = Vector2.new(0.5, 0.5)
	clockRoot.Position = UDim2.fromScale(0.5, 0.5)
	clockRoot.Size = UDim2.fromOffset(140, 140)
	clockRoot.BackgroundColor3 = Color3.fromRGB(240, 245, 255)
	clockRoot.BackgroundTransparency = 1
	clockRoot.BorderSizePixel = 0
	clockRoot.Visible = false
	clockRoot.ZIndex = 55
	clockRoot.Parent = parent
	UISizing.scaleContent(clockRoot, parent)
	UITheme.styleCorner(clockRoot, 70)
	local clockStroke = UITheme.applyStroke(clockRoot, 4, Color3.fromRGB(40, 50, 70))
	clockStroke.Transparency = 1

	local clockHand = Instance.new("Frame")
	clockHand.Name = "Hand"
	clockHand.AnchorPoint = Vector2.new(0.5, 1)
	clockHand.Position = UDim2.new(0.5, 0, 0.5, 0)
	clockHand.Size = UDim2.fromOffset(6, 48)
	clockHand.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
	clockHand.BackgroundTransparency = 1
	clockHand.BorderSizePixel = 0
	clockHand.ZIndex = 56
	clockHand.Parent = clockRoot
	UITheme.styleCorner(clockHand, 3)

	local hub = Instance.new("Frame")
	hub.Name = "Hub"
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromScale(0.5, 0.5)
	hub.Size = UDim2.fromOffset(14, 14)
	hub.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
	hub.BackgroundTransparency = 1
	hub.BorderSizePixel = 0
	hub.ZIndex = 57
	hub.Parent = clockRoot
	UITheme.styleCorner(hub, 7)

	local self = setmetatable({
		frame = parent,
		scrim = scrim,
		card = card,
		title = title,
		message = message,
		rewindButton = rewindButton,
		clockRoot = clockRoot,
		clockHand = clockHand,
		dayNumber = 1,
		rewinding = false,
		showToken = 0,
	}, GameOverPopup) :: GameOverPopupHud

	rewindButton.Activated:Connect(function()
		self:requestRewind()
	end)

	return self
end

function GameOverPopup.show(self: GameOverPopupHud, dayNumber: number)
	if self.rewinding then
		return
	end
	self.dayNumber = math.max(1, math.floor(dayNumber))
	self.rewindButton.Text = string.format("Rewind Day %d", self.dayNumber)
	self.showToken += 1
	local token = self.showToken

	self.clockRoot.Visible = false
	self.frame.Visible = true
	self.scrim.BackgroundTransparency = 1
	self.card.BackgroundTransparency = 1
	self.card.Size = UDim2.fromOffset(400, 240)
	self.title.TextTransparency = 1
	self.message.TextTransparency = 1
	self.rewindButton.BackgroundTransparency = 1
	self.rewindButton.TextTransparency = 1

	tween(self.scrim, SHOW_TWEEN, { BackgroundTransparency = 0.35 })
	tween(self.card, SHOW_TWEEN, {
		BackgroundTransparency = 0.08,
		Size = UDim2.fromOffset(460, 280),
	})
	task.delay(0.35, function()
		if self.showToken ~= token or not self.frame.Visible then
			return
		end
		tween(self.title, SHOW_TWEEN, { TextTransparency = 0 })
	end)
	task.delay(0.7, function()
		if self.showToken ~= token or not self.frame.Visible then
			return
		end
		tween(self.message, SHOW_TWEEN, { TextTransparency = 0 })
		tween(self.rewindButton, SHOW_TWEEN, {
			BackgroundTransparency = 0,
			TextTransparency = 0,
		})
	end)
end

function GameOverPopup.hide(self: GameOverPopupHud)
	self.showToken += 1
	self.rewinding = false
	self.clockRoot.Visible = false
	self.frame.Visible = false
end

function GameOverPopup.requestRewind(self: GameOverPopupHud)
	if self.rewinding or not self.frame.Visible then
		return
	end
	self.rewinding = true
	self.showToken += 1
	AudioController.play("UiClick")

	Remotes.getEvent("RewindDay"):FireServer()

	-- Nearly transparent clock spins while the game-over chrome fades out.
	self.clockRoot.Visible = true
	self.clockRoot.BackgroundTransparency = 0.72
	self.clockHand.BackgroundTransparency = 0.55
	local hub = self.clockRoot:FindFirstChild("Hub") :: Frame?
	if hub then
		hub.BackgroundTransparency = 0.55
	end
	local stroke = self.clockRoot:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 0.55
	end
	self.clockHand.Rotation = 0
	local spin = TweenService:Create(self.clockHand, CLOCK_SPIN, { Rotation = -720 })
	spin:Play()

	tween(self.scrim, HIDE_TWEEN, { BackgroundTransparency = 1 })
	tween(self.card, HIDE_TWEEN, { BackgroundTransparency = 1 })
	tween(self.title, HIDE_TWEEN, { TextTransparency = 1 })
	tween(self.message, HIDE_TWEEN, { TextTransparency = 1 })
	tween(self.rewindButton, HIDE_TWEEN, {
		BackgroundTransparency = 1,
		TextTransparency = 1,
	})

	task.delay(1.0, function()
		if not self.rewinding then
			return
		end
		tween(self.clockRoot, CLOCK_FADE, { BackgroundTransparency = 1 })
		tween(self.clockHand, CLOCK_FADE, { BackgroundTransparency = 1 })
		if hub then
			tween(hub, CLOCK_FADE, { BackgroundTransparency = 1 })
		end
		if stroke then
			TweenService:Create(stroke, CLOCK_FADE, { Transparency = 1 }):Play()
		end
	end)

	task.delay(1.7, function()
		spin:Cancel()
		self:hide()
	end)
end

return GameOverPopup
