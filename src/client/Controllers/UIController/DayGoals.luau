--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Farm = require(Shared.Utilities.FarmProgression)
local Theme = require(Shared.Config.UITheme)
local DayGoals = {}

function DayGoals.apply(parent: Frame, state: any)
	local button = parent:FindFirstChild("StarGoals") :: TextButton?
	if not button then
		button = Instance.new("TextButton")
		button.Name = "StarGoals"
		button.AnchorPoint = Vector2.new(1, 1)
		button.Position = UDim2.new(1, -6, 0, -5)
		button.Size = UDim2.fromOffset(108, 25)
		button.Text = "★ Star goals"
		button.TextSize = 12
		Theme.applyButtonLook(button, Theme.FIELD_PANEL, 8)
		Theme.applyOutlinedTitle(button)
		button.Parent = parent
		local panel = Instance.new("TextLabel")
		panel.Name = "Goals"
		panel.AnchorPoint = Vector2.new(1, 1)
		panel.Position = UDim2.new(1, 0, 0, -5)
		panel.Size = UDim2.fromOffset(310, 90)
		panel.TextSize, panel.TextWrapped = 13, true
		Theme.applyButtonLook(panel, Theme.FIELD_PANEL, 10)
		Theme.applyOutlinedTitle(panel)
		panel.Visible = false
		panel.Parent = button
		button.Activated:Connect(function() panel.Visible = not panel.Visible end)
	end
	local visible = type(state.levelNumber) == "number" and not state.challengeActive and not state.hiddenDay
		and (state.phase == "Preparation" or state.phase == "Active" or state.phase == "Countdown")
	button.Visible = visible
	local panel = button:FindFirstChild("Goals") :: TextLabel
	if not visible then panel.Visible = false; return end
	local goals = Farm.goals(state.levelNumber)
	panel.Text = "★ Clear the day\n★★ " .. goals[1] .. "\n★★★ " .. goals[2]
end

return DayGoals
