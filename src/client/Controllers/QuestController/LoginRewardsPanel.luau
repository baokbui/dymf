--!strict
-- Presents server-authored login offers. No client eligibility or currency math.
local Theme = require(game:GetService("ReplicatedStorage").Shared.Config.UITheme)
local RewardIcon = require(script.Parent.RewardIcon)
local LoginRewardsPanel = {}

local function text(parent: Instance, value: string, y: number, height: number, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, height)
	label.Position = UDim2.fromOffset(0, y)
	label.TextSize = size
	label.Text = value
	label.TextWrapped = true
	label.Parent = parent
	Theme.applyBodyText(label, Theme.BODY)
	return label
end

function LoginRewardsPanel.build(parent: Frame, claim: (any) -> ()): any
	local frame = Instance.new("Frame")
	frame.Name = "LoginRewards"
	frame.BackgroundTransparency = 1
	frame.Position = UDim2.fromOffset(16, 90)
	frame.Size = UDim2.new(1, -32, 0, 240)
	frame.Visible = false
	frame.Parent = parent
	local strip = Instance.new("ScrollingFrame")
	strip.Name, strip.BackgroundTransparency, strip.BorderSizePixel = "RewardStrip", 1, 0
	strip.Position, strip.Size = UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 174)
	strip.ScrollingDirection, strip.AutomaticCanvasSize = Enum.ScrollingDirection.X, Enum.AutomaticSize.X
	strip.CanvasSize, strip.ScrollBarThickness = UDim2.new(), 6
	strip.ScrollBarImageColor3, strip.Parent = Theme.OUTLINE, frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 12)
	pad.Parent = strip
	local layout = Instance.new("UIListLayout")
	layout.FillDirection, layout.SortOrder = Enum.FillDirection.Horizontal, Enum.SortOrder.LayoutOrder
	layout.Padding, layout.Parent = UDim.new(0, 12), strip
	local slots = {}
	for index = 1, 7 do
		local slot = Instance.new("Frame")
		slot.Name = "RewardDay" .. index
		slot.LayoutOrder = index
		slot.Size = UDim2.fromOffset(116, 150)
		slot.Parent = strip
		Theme.applyCardLook(slot, false)
		text(slot, "Day " .. index, 5, 24, 18)
		local icon = RewardIcon.new(slot)
		local amount = text(slot, "...", 102, 42, 14)
		amount.Name = "RewardAmount"
		local stamp = text(slot, "Claimed", 5, 27, 18)
		stamp.Name, stamp.Size, stamp.Position = "ClaimedStamp", UDim2.fromOffset(106, 27), UDim2.fromOffset(5, 5)
		stamp.Rotation, stamp.ZIndex, stamp.Visible = -10, 10, false
		stamp.TextColor3, stamp.Font = Theme.DANGER_DARK, Enum.Font.GothamBlack
		stamp.BackgroundTransparency, stamp.BackgroundColor3 = 0.15, Theme.TITLE
		Theme.styleCorner(stamp, 4)
		Theme.applyStroke(stamp, 2, Theme.DANGER_DARK)
		table.insert(slots, { frame = slot, amount = amount, icon = icon, stamp = stamp })
	end
	local button = Instance.new("TextButton")
	button.Name = "ClaimLoginReward"
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.new(0.5, 0, 0, 192)
	button.Size = UDim2.new(0.6, 0, 0, 38)
	button.TextSize = 20
	button.Parent = frame
	Theme.applyButtonLook(button, Theme.SUCCESS)
	Theme.applyOutlinedTitle(button)
	local current: any = nil
	button.Activated:Connect(function()
		if current and button.Active then claim(current) end
	end)
	local function refresh(login: any, waiting: boolean)
		current = login
		local ready = login and login.ready == true and not waiting
		for index, slot in slots do
			local selected = login and index == login.step
			local paid = login and (index < login.step or (selected and login.claimed))
			local reward = if login then login.rewards[index] else nil
			RewardIcon.set(slot.icon, reward)
			local suffix = if not reward then "" elseif reward.kind == "Brains" then "brains"
				elseif reward.kind == "Ticket" then "Brainrot ticket"
				elseif reward.upgradeId == "Magnet" then "magnet level" else "speed level"
			slot.amount.Text = if reward then string.format("+%d %s", reward.amount, suffix) else "Loading..."
			slot.stamp.Visible = paid == true
			slot.frame.BackgroundColor3 = if paid then Theme.CARD_CLAIMED_BG elseif selected then Theme.PANEL_BG_REWARD else Theme.CARD_BG
		end
		button.Active = ready == true
		button.Selectable = button.Active
		button.AutoButtonColor = button.Active
		button.Visible = login ~= nil and login.claimed ~= true and login.finished ~= true
		button.Text = if waiting then "Saving..." elseif ready then "Claim reward" else "Come back after reset"
		Theme.applyButtonLook(button, if ready then Theme.SUCCESS else Theme.BUTTON_BG)
	end
	local function revealCurrent()
		if not current then return end
		local target = 6 + (current.step - 1) * 128 - (strip.AbsoluteSize.X - 116) / 2
		strip.CanvasPosition = Vector2.new(math.clamp(target, 0, math.max(0, 896 - strip.AbsoluteSize.X)), 0)
	end
	return { frame = frame, refresh = refresh, revealCurrent = revealCurrent }
end

return LoginRewardsPanel
