--!strict
-- Standalone, temporary HUD entry. Completion comes only from server login state.
local Theme = require(game:GetService("ReplicatedStorage").Shared.Config.UITheme)
local Time = require(game:GetService("ReplicatedStorage").Shared.Utilities.RetentionTime)
local Utilities = script.Parent.Parent.Parent.Utilities
local Menu = require(Utilities.MenuRouter)
local RewardHudEntry = require(script.Parent.RewardHudEntry)
local OutsideDismiss = require(Utilities.OutsideDismiss)
local UISizing = require(Utilities.UISizing)
local HudLayout = require(Utilities.HudLayout)
local Audio = require(script.Parent.Parent.AudioController)
local LoginPanel = require(script.Parent.LoginRewardsPanel)
local BrainAmount = require(Utilities.BrainAmount)
local FirstTimeRewards = {}
local current: any = nil

local function text(parent: Instance, value: string, size: number, position: UDim2, bounds: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency, label.Text, label.TextSize = 1, value, size
	label.Position, label.Size, label.Parent = position, bounds, parent
	Theme.applyOutlinedTitle(label)
	return label
end

function FirstTimeRewards.close()
	if current then current.layer.Visible = false end
end

function FirstTimeRewards.open()
	if not current or not current.entry.Visible then return end
	Menu.prepareStandalone()
	BrainAmount.set(current.feedback, "", false)
	current.layer.Visible = true
	task.defer(current.revealCurrent)
end

function FirstTimeRewards.new(main: ScreenGui, claim: (any) -> ()): any
	local layer = Instance.new("Frame")
	layer.Name, layer.BackgroundTransparency, layer.Visible = "FirstTimeRewards", 1, false
	layer.Size, layer.ZIndex, layer.Parent = UDim2.fromScale(1, 1), 19, main
	local window = Instance.new("Frame")
	window.Name, window.Active = "Window", true
	window.AnchorPoint, window.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	window.Size, window.ZIndex, window.Parent = UDim2.fromOffset(940, 280), 25, layer
	Theme.applyPanelLook(window, nil, Theme.PANEL_BG_REWARD)
	Theme.applySurfaceDepth(window)
	OutsideDismiss.mount(layer, window, FirstTimeRewards.close)
	text(window, "First-time Rewards", 26, UDim2.fromOffset(12, 15), UDim2.new(1, -64, 0, 34))
	local close = Instance.new("TextButton")
	close.Name, close.Text, close.TextSize = "Close", "X", 21
	close.Position, close.Size = UDim2.new(1, -46, 0, 12), UDim2.fromOffset(34, 34)
	close.Parent = window
	Theme.applyButtonLook(close, Theme.DANGER)
	Theme.applyOutlinedTitle(close)
	close.Activated:Connect(FirstTimeRewards.close)
	local clock = text(window, "", 16, UDim2.fromOffset(16, 52), UDim2.new(1, -32, 0, 24))
	Theme.applyBodyText(clock)
	local login = LoginPanel.build(window, claim)
	login.frame.Position, login.frame.Visible = UDim2.fromOffset(16, 90), true
	local feedback = text(window, "", 16, UDim2.new(0, 16, 1, -57), UDim2.new(1, -32, 0, 40))
	local entry, timer = RewardHudEntry.new(main, "FirstTimeRewardsEntry", "First-time Rewards")
	local badge = text(entry, "!", 15, UDim2.fromOffset(64, 0), UDim2.fromOffset(22, 22))
	badge.Name, badge.BackgroundTransparency, badge.BackgroundColor3 = "Available", 0, Theme.DANGER
	Theme.styleCorner(badge, 11)
	entry.Activated:Connect(function()
		Audio.play("UiClick")
		if layer.Visible then FirstTimeRewards.close() else FirstTimeRewards.open() end
	end)
	local zoom = Instance.new("UIScale")
	zoom.Parent = window
	local function resize()
		local group = feedback:FindFirstChild("BrainAmount")
		local value = if group then group:FindFirstChild("Value") else nil
		local hasFeedback = if value and value:IsA("TextLabel") then value.Text ~= "" else feedback.Text ~= ""
		local hasButton = login.frame.ClaimLoginReward.Visible
		local feedbackY = if hasButton then 338 else 278
		local height = if hasFeedback then feedbackY + 56 elseif hasButton then 336 else 280
		feedback.Visible = hasFeedback
		feedback.Position = UDim2.fromOffset(16, feedbackY)
		local origin, bounds = HudLayout.bounds(main)
		zoom.Scale = math.min(UISizing.desktop(main.AbsoluteSize), math.max(0.1, bounds.Y / height))
		window.Size = UDim2.fromOffset(math.max(1, math.min(940, bounds.X / zoom.Scale)), height)
		window.Position = UDim2.fromOffset(origin.X + bounds.X / 2, origin.Y + bounds.Y / 2)
	end
	feedback.DescendantAdded:Connect(function(child)
		if child:IsA("TextLabel") then child:GetPropertyChangedSignal("Text"):Connect(resize); resize() end
	end)
	login.frame.ClaimLoginReward:GetPropertyChangedSignal("Visible"):Connect(resize)
	HudLayout.watch(main, window, resize)
	resize()
	local rewardState: any
	local function refresh(state: any, waiting: boolean)
		rewardState = state
		entry.Visible = state ~= nil and state.finished ~= true
		badge.Visible = entry.Visible and state.ready == true
		login.refresh(state, waiting)
		resize()
		if not entry.Visible then FirstTimeRewards.close() end
	end
	local function tick(resetAt: number?)
		if entry.Visible then
			timer.Text = if rewardState and rewardState.ready then "Ready" else RewardHudEntry.countdown(resetAt)
		end
		if not layer.Visible then return end
		clock.Text = if resetAt then "Next reward in " .. Time.formatCountdown(math.max(0, resetAt - workspace:GetServerTimeNow())) .. " UTC" else "Loading rewards..."
	end
	current = { layer = layer, entry = entry, feedback = feedback, refresh = refresh, tick = tick, revealCurrent = login.revealCurrent }
	return current
end

return FirstTimeRewards
