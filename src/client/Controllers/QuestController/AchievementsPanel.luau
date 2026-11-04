--!strict
-- Permanent milestones and one server-selected next goal, inside the quest window.
local Theme = require(game:GetService("ReplicatedStorage").Shared.Config.UITheme)
local BrainAmount = require(script.Parent.Parent.Parent.Utilities.BrainAmount)
local AchievementsPanel = {}

local function label(parent: Instance, text: string, position: UDim2, size: UDim2, fontSize: number): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Position, item.Size = position, size
	item.Text, item.TextSize = text, fontSize
	item.TextWrapped = true
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.Parent = parent
	Theme.applyBodyText(item, Theme.BODY)
	return item
end

function AchievementsPanel.build(parent: Frame, claim: (any) -> (), viewGoal: (any) -> ()): any
	local frame = Instance.new("Frame")
	frame.Name = "Achievements"
	frame.BackgroundTransparency = 1
	frame.Position = UDim2.fromOffset(16, 131)
	frame.Size = UDim2.new(1, -32, 0, 348)
	frame.Visible = false
	frame.Parent = parent
	local goalButton = Instance.new("TextButton")
	goalButton.Name = "NextGoal"
	goalButton.Text = ""
	goalButton.Size = UDim2.new(1, 0, 0, 91)
	goalButton.Parent = frame
	Theme.applyCardLook(goalButton, true)
	local goalTitle = label(goalButton, "Your next goal", UDim2.fromOffset(10, 3), UDim2.new(1, -20, 0, 24), 18)
	Theme.applyOutlinedTitle(goalTitle)
	local goalCopy = label(goalButton, "Loading...", UDim2.fromOffset(10, 30), UDim2.new(1, -20, 0, 52), 15)
	local currentGoal: any = nil
	goalButton.Activated:Connect(function() if currentGoal then viewGoal(currentGoal) end end)
	local list = Instance.new("ScrollingFrame")
	list.Name = "Milestones"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(0, 102)
	list.Size = UDim2.new(1, 0, 1, -102)
	list.ScrollBarThickness = 5
	list.ScrollBarImageColor3 = Theme.OUTLINE
	list.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = frame
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 5)
	padding.PaddingBottom = UDim.new(0, 5)
	padding.PaddingLeft = UDim.new(0, 5)
	padding.PaddingRight = UDim.new(0, 15)
	padding.Parent = list
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local rows = {}
	local function refresh(achievements: any, goal: any, waiting: boolean)
		currentGoal = goal
		goalTitle.Text = if goal then goal.title else "Your next goal"
		goalCopy.Text = if goal then goal.description else "Loading..."
		for index, objective in achievements or {} do
			local row = rows[index]
			if not row then
				local box = Instance.new("Frame")
				box.Name = objective.id
				box.LayoutOrder = index
				box.Size = UDim2.new(1, 0, 0, 100)
				box.Parent = list
				Theme.applyCardLook(box, false)
				local title = label(box, "", UDim2.fromOffset(10, 5), UDim2.new(1, -126, 0, 25), 17)
				Theme.applyOutlinedTitle(title)
				local description = label(box, "", UDim2.fromOffset(10, 34), UDim2.new(1, -130, 0, 38), 14)
				local progress = label(box, "", UDim2.fromOffset(10, 77), UDim2.new(1, -126, 0, 19), 13)
				local button = Instance.new("TextButton")
				button.Position = UDim2.new(1, -114, 0.5, -22)
				button.Size = UDim2.fromOffset(103, 44)
				button.TextSize = 16
				button.Parent = box
				Theme.applyButtonLook(button)
				Theme.applyOutlinedTitle(button)
				row = { title = title, description = description, progress = progress, button = button, objective = objective }
				button.Activated:Connect(function() if button.Active then claim(row.objective) end end)
				rows[index] = row
			end
			row.objective = objective
			row.title.Text, row.description.Text = objective.name, objective.description
			row.progress.Text = string.format("%d / %d", objective.progress, objective.target)
			local ready = objective.progress >= objective.target and not objective.claimed
			row.button.Active = ready and not waiting
			row.button.Selectable = row.button.Active
			local rewardText = if waiting then "Saving..." elseif objective.claimed then "Claimed!"
				elseif ready then tostring(objective.brains) else tostring(objective.brains)
			BrainAmount.set(row.button, rewardText, not waiting and not objective.claimed)
			Theme.applyButtonLook(row.button, if ready then Theme.SUCCESS else Theme.BUTTON_BG)
		end
	end
	return { frame = frame, refresh = refresh }
end

return AchievementsPanel
