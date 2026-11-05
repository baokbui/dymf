--!strict
local Theme = require(game:GetService("ReplicatedStorage").Shared.Config.UITheme)
local Utilities = script.Parent.Parent.Parent.Utilities
local Menu = require(Utilities.MenuRouter)
local OutsideDismiss = require(Utilities.OutsideDismiss)
local HudLayout = require(Utilities.HudLayout)
local UISizing = require(Utilities.UISizing)
local Audio = require(script.Parent.Parent.AudioController)
local Panel = require(script.Parent.DailySpinPanel)
local RewardHudEntry = require(script.Parent.RewardHudEntry)

local DailySpinHud = {}
local closeCurrent: (() -> ())?

function DailySpinHud.close()
	if closeCurrent then closeCurrent() end
end

function DailySpinHud.new(main: ScreenGui, request: (number) -> ())
	local layer = Instance.new("Frame")
	layer.Name, layer.BackgroundTransparency, layer.Visible = "DailySpinWindow", 1, false
	layer.Size, layer.ZIndex, layer.Parent = UDim2.fromScale(1, 1), 19, main
	local view = Panel.build(layer, request)
	local window = view.frame
	window.AnchorPoint, window.Size = Vector2.new(0.5, 0.5), UDim2.fromOffset(448, 320)
	window.Active, window.ZIndex, window.Visible = true, 25, true
	closeCurrent = function() layer.Visible = false end
	OutsideDismiss.mount(layer, window, DailySpinHud.close)

	local close = Instance.new("TextButton")
	close.Name, close.Text, close.TextSize = "Close", "X", 18
	close.Position, close.Size = UDim2.new(1, -42, 0, 8), UDim2.fromOffset(34, 34)
	Theme.applyButtonLook(close, Theme.DANGER)
	Theme.applyOutlinedTitle(close)
	close.Parent = window
	close.Activated:Connect(DailySpinHud.close)

	local zoom = Instance.new("UIScale")
	zoom.Parent = window
	local function resize()
		local origin, bounds = HudLayout.bounds(main)
		zoom.Scale = math.max(0.1, math.min(UISizing.desktop(main.AbsoluteSize), bounds.X / 448, bounds.Y / 320))
		window.Position = UDim2.fromOffset(origin.X + bounds.X / 2, origin.Y + bounds.Y / 2)
	end
	HudLayout.watch(main, window, resize)
	resize()

	local entry, timer = RewardHudEntry.new(main, "DailySpinEntry", "Daily Spinner")
	entry.Activated:Connect(function()
		Audio.play("UiClick")
		if layer.Visible then DailySpinHud.close(); return end
		Menu.prepareStandalone()
		layer.Visible = true
	end)
	local state: any
	local function refresh(payload: any)
		state = payload
		entry.Visible = type(payload) == "table"
		view.refresh(payload)
	end
	local function tick(resetAt: number?)
		if not entry.Visible or not state then return end
		timer.Text = if not state.eligible then string.format("Beat Day %d", state.minimumDay - 1)
			elseif not state.spent then "Ready" else RewardHudEntry.countdown(resetAt)
	end
	return { refresh = refresh, onResult = view.onResult, tick = tick }
end

return DailySpinHud
