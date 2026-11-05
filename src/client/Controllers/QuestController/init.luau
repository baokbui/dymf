--!strict
-- Display-only daily quest card. Authoritative progress/rewards arrive from server.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Theme = require(Shared.Config.UITheme)
local Time = require(Shared.Utilities.RetentionTime)
local Audio = require(script.Parent.AudioController)
local UIEvents = require(script.Parent.Parent.UIEvents)
local FirstTimeRewards = require(script.FirstTimeRewards)
local AchievementsPanel = require(script.AchievementsPanel)
local QuestTracker = require(script.QuestTracker)
local DailySpinHud = require(script.DailySpinHud)
local Presentation = require(script.QuestPresentation)
local BrainAmount = require(script.Parent.Parent.Utilities.BrainAmount)
local Menu = require(script.Parent.Parent.Utilities.MenuRouter)
local QuestController = { Name = "QuestController" }
local errors = {
	NotReady = "Finish this quest first!", Expired = "A new quest day has started.",
	AlreadyClaimed = "Already claimed!", Busy = "Saving progress. Try again shortly.",
	SaveUnavailable = "Unable to save. Please try again.", InvalidRequest = "Please reopen Quests.",
	RateLimited = "One moment! Please try again.",
}
local state: any = { ready = false }
local feedback: TextLabel?
local clockLabel: TextLabel?
local frame: Frame?
local rows: { any } = {}
local weeklySelected = false
local campaignSelected = false
local questContent: ScrollingFrame?
local campaignPanel: any = nil
local waiting = false
local refresh: () -> ()
local tabButtons: { TextButton } = {}
local requestSerial = 0
local loginView: any = nil
local claimFeedback: TextLabel?
local achievementsPanel: any = nil
local tracker: any = nil
local spinView: any = nil

local function label(parent: Instance, text: string, position: UDim2, size: UDim2): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Text = text
	item.TextSize = 19
	item.Position = position
	item.Size = size
	item.Parent = parent
	Theme.applyBodyText(item, Theme.BODY)
	return item
end

refresh = function()
	if not frame then return end
	local available = 0
	for _, weekly in { false, true } do
		for _, entry in Presentation.rows(state, weekly) do
			local quest = entry.quest
			if quest.progress >= quest.target and not quest.claimed then available += 1 end
		end
	end
	local achievementsAvailable = 0
	for _, objective in state.achievements or {} do
		if objective.progress >= objective.target and not objective.claimed then achievementsAvailable += 1 end
	end
	for _, objective in state.campaign or {} do
		if objective.progress >= objective.target and not objective.claimed then available += 1 end
	end
	Menu.setBadge("Quests", available)
	Menu.setBadge("Achievements", achievementsAvailable)
	if loginView then loginView.refresh(state.login, waiting); loginView.tick(state.resetAt) end
	if achievementsPanel then achievementsPanel.refresh(state.achievements, state.nextGoal, waiting) end
	if campaignPanel then campaignPanel.refresh(state.campaign, nil, waiting) end
	if tracker then tracker.refresh(state, waiting) end
	if spinView then spinView.refresh(state.spin); spinView.tick(state.resetAt) end
	local displayRows = Presentation.rows(state, weeklySelected)
	for index, row in rows do
		local entry = displayRows[index]
		local quest = if entry then entry.quest else nil
		row.quest = quest
		row.dayKey = if entry then entry.dayKey else state.dayKey
		row.kind = if weeklySelected then "WeeklyQuest" else "Quest"
		row.title.Text = if entry then entry.title else "Loading quests..."
		row.progress.Text = if quest then string.format("%d / %d", quest.progress, quest.target) else ""
		row.fill.Size = UDim2.fromScale(if quest then math.clamp(quest.progress / quest.target, 0, 1) else 0, 1)
		local ready = quest and quest.progress >= quest.target and not quest.claimed
		row.frame.LayoutOrder = if ready then index - #rows else index
		row.button.Active = ready == true and not waiting
		row.button.Selectable = row.button.Active
		row.button.AutoButtonColor = row.button.Active
		local rewardText = if waiting then "Saving..." elseif quest and quest.claimed then "Claimed!"
			elseif ready then tostring(quest.brains)
			elseif quest then tostring(quest.brains) else "..."
		BrainAmount.set(row.button, rewardText, quest ~= nil and not waiting and not quest.claimed)
		Theme.applyButtonLook(row.button, if ready then Theme.SUCCESS else Theme.BUTTON_BG)
	end
end

-- Shared navigation for Menu tabs and right-side quest access.
local function selectTrack(weekly: boolean, campaign: boolean?)
	campaignSelected = campaign == true
	if not campaignSelected then weeklySelected = weekly end
	if questContent then
		questContent.Visible = not campaignSelected
		questContent.CanvasPosition = Vector2.zero
	end
	local firstTab = tabButtons[1]
	local tabs = if firstTab then firstTab.Parent else nil
	if tabs and tabs:IsA("GuiObject") then
		tabs.Position = UDim2.fromOffset(16, if campaignSelected then 51 else 84)
	end
	if campaignPanel then campaignPanel.frame.Visible = campaignSelected end
	local selected = if campaignSelected then 3 elseif weeklySelected then 2 else 1
	for index, tab in tabButtons do
		Theme.applyButtonLook(tab, if index == selected then Theme.SUCCESS else Theme.BUTTON_BG)
	end
	refresh()
	if not clockLabel then return end
	clockLabel.Visible = not campaignSelected
	if not campaignSelected then
		local resetAt = if weeklySelected then state.weeklyResetAt else state.resetAt
		if resetAt then clockLabel.Text = "Resets in " .. Time.formatCountdown(math.max(0, resetAt - workspace:GetServerTimeNow())) .. " UTC" end
	end
end

function QuestController.open(weekly: boolean)
	selectTrack(weekly)
	Menu.open("Quests")
end

local function requestClaim(row: any, kind: string?)
	local quest = row.quest
	if not quest or waiting or quest.claimed or quest.progress < quest.target then return end
	waiting = true
	requestSerial += 1
	local serial = requestSerial
	claimFeedback = if kind == "Login" and loginView then loginView.feedback else feedback
	refresh()
	if claimFeedback then BrainAmount.set(claimFeedback, "Saving your reward...", false) end
	Remotes.getEvent("ClaimRetentionReward"):FireServer({ kind = kind or row.kind or "Quest", id = quest.id, dayKey = row.dayKey or state.dayKey })
	task.delay(20, function()
		if not waiting or requestSerial ~= serial then return end
		waiting = false
		if claimFeedback then BrainAmount.set(claimFeedback, "Still saving? Reopen the rewards to check or try again.", false) end
		refresh()
	end)
end

local function buildRow(parent: GuiObject, index: number)
	local box = Instance.new("Frame")
	box.LayoutOrder = index
	box.Size = UDim2.new(1, 0, 0, 78)
	box.Parent = parent
	Theme.applyButtonLook(box, Theme.QUEST_PAPER, 12)
	Theme.applySurfaceDepth(box)
	local marker = Instance.new("Frame")
	marker.Name = "ObjectiveAccent"
	marker.Position, marker.Size = UDim2.fromOffset(8, 10), UDim2.fromOffset(4, 55)
	marker.BackgroundColor3, marker.BorderSizePixel = Theme.PANEL_BG_QUESTS, 0
	Theme.styleCorner(marker, 2)
	marker.Parent = box
	local title = label(box, "", UDim2.fromOffset(20, 4), UDim2.new(1, -154, 0, 27))
	title.TextXAlignment = Enum.TextXAlignment.Left
	Theme.applyBodyText(title, Theme.QUEST_INK)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	local track = Instance.new("Frame")
	track.Position = UDim2.fromOffset(20, 38)
	track.Size = UDim2.new(1, -164, 0, 23)
	track.BackgroundColor3 = Theme.QUEST_INK
	track.BorderSizePixel = 0
	track.Parent = box
	Theme.styleCorner(track, 8)
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Theme.SUCCESS
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = track
	Theme.styleCorner(fill, 8)
	Theme.applySurfaceDepth(fill)
	local progress = label(track, "", UDim2.new(), UDim2.fromScale(1, 1))
	progress.ZIndex = 3
	Theme.applyOutlinedTitle(progress)
	progress.TextSize = 14
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(116, 45)
	button.Position = UDim2.new(1, -128, 0.5, -22)
	button.TextSize = 17
	button.Parent = box
	Theme.applyOutlinedTitle(button)
	local row = { frame = box, title = title, progress = progress, fill = fill, button = button, quest = nil :: any }
	button.Activated:Connect(function() requestClaim(row) end)
	table.insert(rows, row)
end

function QuestController.start()
	local main = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("MainUI")
	local card = Instance.new("Frame")
	card.Name = "DailyQuests"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(480, 555)
	card.Active = true
	card.ZIndex = 41
	card.Visible = false
	card.Parent = main
	frame = card
	Theme.applyPanelLook(card, nil, Theme.PANEL_BG_QUESTS)
	local title = label(card, "Daily Quests", UDim2.fromOffset(18, 12), UDim2.new(1, -36, 0, 34))
	title.Name, title.TextXAlignment = "Title", Enum.TextXAlignment.Center
	Theme.applyOutlinedTitle(title)
	title.TextSize = 28
	clockLabel = label(card, "", UDim2.fromOffset(18, 49), UDim2.new(1, -36, 0, 23))
	clockLabel.TextSize = 16
	local objectiveContent = Instance.new("ScrollingFrame")
	objectiveContent.Name = "ObjectiveList"
	questContent = objectiveContent
	objectiveContent.Position, objectiveContent.Size = UDim2.fromOffset(16, 132), UDim2.new(1, -32, 1, -190)
	objectiveContent.BackgroundTransparency, objectiveContent.BorderSizePixel = 1, 0
	objectiveContent.AutomaticCanvasSize, objectiveContent.CanvasSize = Enum.AutomaticSize.Y, UDim2.new()
	objectiveContent.ScrollingDirection, objectiveContent.ScrollBarThickness = Enum.ScrollingDirection.Y, 5
	objectiveContent.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 5), UDim.new(0, 5)
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 5), UDim.new(0, 5)
	padding.Parent = objectiveContent
	local layout = Instance.new("UIListLayout")
	layout.SortOrder, layout.Padding = Enum.SortOrder.LayoutOrder, UDim.new(0, 12)
	layout.Parent = objectiveContent
	objectiveContent.Parent = card
	for index = 1, 4 do buildRow(objectiveContent, index) end
	local questTabs = Instance.new("Frame")
	questTabs.Name, questTabs.BackgroundTransparency = "QuestTabs", 1
	questTabs.Position, questTabs.Size = UDim2.fromOffset(16, 84), UDim2.new(1, -32, 0, 36)
	questTabs.Parent = card
	spinView = DailySpinHud.new(main :: ScreenGui, function(day)
		Audio.play("UiClick")
		Remotes.getEvent("ClaimRetentionReward"):FireServer({ kind = "Spin", id = "DailySpin", dayKey = day })
	end)
	for index, name in { "Daily Quests", "Weekly Quests", "Campaign" } do
		local button = Instance.new("TextButton")
		button.Name, button.Text, button.TextSize = name, name, 15
		button.Position, button.Size = UDim2.new((index - 1) / 3, 4, 0, 0), UDim2.new(1 / 3, -8, 1, 0)
		button.Parent = questTabs
		Theme.applyOutlinedTitle(button)
		tabButtons[index] = button
		button.Activated:Connect(function() selectTrack(index == 2, index == 3) end)
		Theme.applyButtonLook(button, if index == 1 then Theme.SUCCESS else Theme.BUTTON_BG)
	end
	loginView = FirstTimeRewards.new(main :: ScreenGui, function(login)
		requestClaim({ dayKey = login.dayKey, quest = { id = login.track, progress = 1, target = 1, claimed = login.claimed } }, "Login")
	end)
	achievementsPanel = AchievementsPanel.build(card, function(objective)
		requestClaim({ quest = objective }, "Achievement")
	end, function(goal)
		Remotes.getEvent("ViewRetentionGoal"):FireServer(goal.id)
		Menu.close()
		if goal.kind ~= "Campaign" and goal.brainrotId then UIEvents.fireInspectOwnedBrainrot(goal.brainrotId) end
	end)
	achievementsPanel.frame.Position = UDim2.fromOffset(16, 91)
	campaignPanel = AchievementsPanel.build(card, function(objective)
		requestClaim({ quest = objective }, "Achievement")
	end)
	campaignPanel.frame.Name = "CampaignQuests"
	campaignPanel.frame.Position = UDim2.fromOffset(16, 99)
	campaignPanel.frame.Size = UDim2.new(1, -32, 1, -157)

	for _, name in { "Quests", "Achievements" } do
		Menu.register(name, card, {
			fill = if name == "Quests" then Theme.PANEL_BG_QUESTS else Theme.PANEL_BG_ACHIEVEMENTS,
			selfScrolling = name == "Achievements",
			open = function()
				if name == "Quests" then
					selectTrack(weeklySelected, campaignSelected)
				else
					objectiveContent.Visible = false
					campaignPanel.frame.Visible = false
				end
				achievementsPanel.frame.Visible = name == "Achievements"
				title.Text = name
				questTabs.Visible = name == "Quests"
				clockLabel.Visible = name == "Quests" and not campaignSelected
				achievementsPanel.frame.Position = UDim2.fromOffset(16, 60)
				achievementsPanel.frame.Size = UDim2.new(1, -32, 1, -120)
				if feedback then BrainAmount.set(feedback, "", false) end
			end,
			close = function() card.Visible = false end,
		})
	end
	Menu.setInnerScroll("Quests", true)
	feedback = label(card, "", UDim2.new(0, 16, 1, -57), UDim2.new(1, -32, 0, 40))
	feedback.TextWrapped = true
	feedback.TextSize = 16
	Remotes.getEvent("RetentionUpdated").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then UIEvents.fireRetentionState(payload) end
	end)
	UIEvents.retentionUpdated:Connect(function(payload)
		if type(payload) == "table" then state = payload; refresh() end
	end)
	local initial = UIEvents.getRetentionState()
	if type(initial) == "table" then state = initial end
	Remotes.getEvent("RetentionClaimResult").OnClientEvent:Connect(function(result)
		if result.kind == "Spin" then spinView.onResult(result); return end
		waiting = false
		local target = claimFeedback or feedback
		if target then
			local message = if result.success then string.format("Claimed %d", result.brainsGranted or 0)
				else errors[result.reason] or "Please try again shortly."
			target.TextColor3 = if result.success then Theme.SUCCESS_DARK else Theme.DANGER_DARK
			local nonBrain = result.reward and result.reward.kind ~= "Brains"
			if result.success and nonBrain then message = "Claimed: " .. (result.reward.name or "reward") .. "!" end
			BrainAmount.set(target, message, result.success == true and not nonBrain)
		end
		if result.success and result.kind == "Login" then
			Audio.play("FirstTimeRewardStamp")
		elseif result.success and (result.kind == "Quest" or result.kind == "WeeklyQuest" or result.kind == "Achievement") then
			Audio.play("ClaimReward")
		else
			Audio.play(if result.success then "PurchaseKaching" else "PurchaseError")
		end
		refresh()
	end)
	tracker = QuestTracker.new(main :: ScreenGui)
	refresh()
	task.spawn(function()
		while main.Parent do
			if loginView then loginView.tick(state.resetAt) end
			if spinView then spinView.tick(state.resetAt) end
			if card.Visible and clockLabel and clockLabel.Visible and not campaignSelected then
				local resetAt = if objectiveContent.Visible and weeklySelected then state.weeklyResetAt else state.resetAt
				clockLabel.Text = if resetAt then "Resets in " .. Time.formatCountdown(math.max(0, resetAt - workspace:GetServerTimeNow())) .. " UTC"
					else "Loading your quests..."
			end
			task.wait(1)
		end
	end)
end

return QuestController
