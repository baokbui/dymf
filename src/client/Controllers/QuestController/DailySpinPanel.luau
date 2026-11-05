--!strict
-- The wheel reveals a committed server outcome. Its movement has no effect on rewards.
local TweenService = game:GetService("TweenService")
local Theme = require(game:GetService("ReplicatedStorage").Shared.Config.UITheme)
local SpinWheel = require(script.Parent.SpinWheel)
local DailySpinPanel = {}

local function text(parent: GuiObject, name: string, value: string, y: number, height: number, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name, label.Text, label.TextSize = name, value, size
	label.Position, label.Size = UDim2.new(0, 12, 0, y), UDim2.new(1, -24, 0, height)
	label.BackgroundTransparency = 1
	label.TextWrapped = true
	Theme.applyOutlinedTitle(label)
	label.Parent = parent
	return label
end

function DailySpinPanel.build(parent: Frame, request: (number) -> ())
	local frame = Instance.new("Frame")
	frame.Name, frame.Visible = "DailySpin", false
	frame.Position, frame.Size = UDim2.fromOffset(16, 132), UDim2.new(1, -32, 0, 510)
	Theme.applyPanelLook(frame, nil, Theme.PANEL_BG_SETTINGS)
	Theme.applySurfaceDepth(frame)
	frame.Parent = parent

	text(frame, "Title", "Daily Free Spin", 12, 30, 22)
	local wheel = SpinWheel.build(frame)
	local result = text(frame, "Result", "One free spin per day", 328, 30, 22)
	local odds = text(frame, "Odds", "", 365, 42, 15)
	local status = text(frame, "Status", "Loading…", 412, 32, 14)
	local button = Instance.new("TextButton")
	button.Name, button.Text, button.TextSize = "SpinButton", "Free Spin", 17
	button.AnchorPoint, button.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 454)
	button.Size = UDim2.fromOffset(180, 43)
	Theme.applyButtonLook(button, Theme.SUCCESS)
	Theme.applySurfaceDepth(button)
	Theme.applyOutlinedTitle(button)
	button.Parent = frame

	local state: any = nil
	local pendingDay: number? = nil
	local animating = false
	local failure: string? = nil
	local serial = 0
	local spinTween: Tween? = nil
	local function draw()
		local ready = state ~= nil and state.eligible and not state.spent and not pendingDay and not animating
		button.Active, button.Selectable, button.AutoButtonColor = ready == true, ready == true, ready == true
		button.BackgroundColor3 = if ready then Theme.SUCCESS else Theme.FIELD_INSET
		button.Text = if animating then "Spinning…" elseif pendingDay then "Saving…" elseif state and state.spent then "Spin used" else "Free Spin"
		if animating then return end
		local outcome = if state then state.outcome else nil
		result.Text = if outcome then string.format("+%d Brains", outcome.brains) else "One free spin per day"
		status.Text = if pendingDay then "Saving your spin…"
			elseif failure then failure
			elseif not state then "Loading…"
			elseif not state.eligible then string.format("Complete Day %d to unlock.", state.minimumDay - 1)
			elseif state.spent then "Next free spin at 00:00 UTC."
			else "Your reward goes straight to your balance."
	end

	local function reveal(outcome: any)
		animating = true
		result.Visible = false
		status.Text = "Revealing your reward…"
		local start = wheel.rotor.Rotation % 360
		wheel.rotor.Rotation = start
		local target = wheel.angleFor(outcome.rewardId)
		local tween = TweenService:Create(wheel.rotor, TweenInfo.new(4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Rotation = start + 360 * 5 + (target - start) % 360,
		})
		spinTween = tween
		tween.Completed:Once(function(playbackState)
			spinTween = nil
			if playbackState ~= Enum.PlaybackState.Completed or not frame.Parent then return end
			wheel.rotor.Rotation = target
			animating = false
			result.Visible = true
			wheel.configure(state.rewards)
			if state.outcome then wheel.rotor.Rotation = wheel.angleFor(state.outcome.rewardId) end
			draw()
		end)
		tween:Play()
	end

	button.Activated:Connect(function()
		if not button.Active or not state then return end
		pendingDay, failure = state.dayKey, nil
		serial += 1
		local attempt = serial
		draw()
		request(state.dayKey)
		task.delay(20, function()
			if frame.Parent and serial == attempt and pendingDay then
				pendingDay = nil
				failure = "Still saving? Try again shortly."
				draw()
			end
		end)
	end)

	local function refresh(nextState: any)
		if type(nextState) ~= "table" then return end
		if state and nextState.dayKey < state.dayKey then return end
		if not state or state.dayKey ~= nextState.dayKey then failure = nil end
		state = nextState
		if not animating then wheel.configure(state.rewards) end
		local entries = {}
		for _, reward in state.rewards do
			table.insert(entries, string.format("%d brains  %d%%", reward.brains, math.round(reward.odds * 100)))
		end
		odds.Text = "REWARD ODDS\n" .. table.concat(entries, "   •   ")
		if pendingDay == state.dayKey and state.outcome then
			pendingDay, failure = nil, nil
			reveal(state.outcome)
		elseif pendingDay and pendingDay ~= state.dayKey then
			pendingDay = nil
		end
		if not animating and state.outcome then wheel.rotor.Rotation = wheel.angleFor(state.outcome.rewardId) end
		draw()
	end
	frame.Destroying:Once(function()
		serial += 1
		if spinTween then spinTween:Cancel() end
	end)

	local function onResult(response: any)
		if not pendingDay or response.success then return end
		pendingDay = nil
		failure = if response.reason == "Busy" or response.reason == "RateLimited" then "Try again shortly."
			elseif response.reason == "Expired" then "A new spin day has started."
			elseif response.reason == "AlreadyClaimed" then "Today's spin was already used."
			else "Unable to spin right now."
		draw()
	end
	draw()
	return { frame = frame, refresh = refresh, onResult = onResult }
end

return DailySpinPanel
