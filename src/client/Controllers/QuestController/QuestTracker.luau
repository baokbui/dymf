--!strict
-- Right-rail progress only. Claims continue through the existing full quest view.
local TweenService = game:GetService("TweenService")
local Theme = require(game:GetService("ReplicatedStorage").Shared.Config.UITheme)
local Sizing = require(script.Parent.Parent.Parent.Utilities.UISizing)
local Audio = require(script.Parent.Parent.AudioController)
local Presentation = require(script.Parent.QuestPresentation)
local QuestTracker = {}
local WIDTH, HEIGHT = 270, 220
local CLEAR_TWEEN = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.35)
local function transparent(gui: GuiObject)
	gui.BackgroundTransparency = 1
	local stroke = gui:FindFirstChildOfClass("UIStroke")
	if stroke then stroke.Transparency = 1 end
end

local function text(parent: Instance, name: string, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name, label.BackgroundTransparency, label.TextSize = name, 1, size
	label.Parent = parent
	Theme.applyOutlinedTitle(label)
	return label
end

function QuestTracker.new(main: ScreenGui): any
	local frame = Instance.new("Frame")
	frame.Name, frame.Active = "QuestTracker", true
	frame:SetAttribute("ScreenSpaceUI", true) -- layout already uses physical HUD bounds
	frame.AnchorPoint, frame.Size, frame.ZIndex = Vector2.new(1, 0), UDim2.fromOffset(WIDTH, HEIGHT), 12
	frame.Parent = main
	Theme.applyPanelLook(frame, nil, Theme.PANEL_BG_INVENTORY)
	transparent(frame)
	local zoom = Instance.new("UIScale")
	zoom.Parent = frame
	local weekly, payload = false, { ready = false } :: any
	local tracks = { { period = nil, seen = {} }, { period = nil, seen = {} } }
	local heading: TextButton? = nil
	local rows = {}
	local list = Instance.new("ScrollingFrame")
	list.Name, list.BackgroundTransparency, list.BorderSizePixel = "Objectives", 1, 0
	list.Position, list.Size = UDim2.fromOffset(8, 46), UDim2.new(1, -16, 1, -58)
	list.ScrollingDirection, list.AutomaticCanvasSize = Enum.ScrollingDirection.Y, Enum.AutomaticSize.Y
	list.CanvasSize, list.ScrollBarThickness = UDim2.new(), 0
	list.VerticalScrollBarInset, list.Parent = Enum.ScrollBarInset.ScrollBar, frame
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 4), UDim.new(0, 4), UDim.new(0, 4), UDim.new(0, 8)
	pad.Parent = list
	local layout = Instance.new("UIListLayout")
	layout.Padding, layout.SortOrder, layout.Parent = UDim.new(0, 5), Enum.SortOrder.LayoutOrder, list
	for index = 1, 4 do
		local row = Instance.new("Frame")
		row.Name, row.Size, row.LayoutOrder, row.Parent = "Objective" .. index, UDim2.new(1, 0, 0, 34), index, list
		Theme.applyCardLook(row)
		transparent(row)
		local content = Instance.new("Frame")
		content.Name, content.BackgroundTransparency = "Content", 1
		content.Size, content.Parent = UDim2.fromScale(1, 1), row
		local title, amount = text(content, "Title", 13), text(content, "Progress", 12)
		title.Position, title.Size, title.TextXAlignment = UDim2.fromOffset(6, 1), UDim2.new(0.65, -6, 0, 23), Enum.TextXAlignment.Left
		title.TextTruncate = Enum.TextTruncate.AtEnd
		amount.Position, amount.Size = UDim2.fromScale(0.65, 0), UDim2.new(0.35, -6, 0, 23)
		amount.TextXAlignment = Enum.TextXAlignment.Right
		rows[index] = { title = title, amount = amount, content = content, frame = row, tweens = {} }
	end
	local function stopAnimation(row: any)
		if row.connection then row.connection:Disconnect(); row.connection = nil end
		for _, tween in row.tweens do tween:Cancel() end
		table.clear(row.tweens)
		row.animating = false
		row.content.Position = UDim2.new()
		for _, label in { row.title, row.amount } do label.TextTransparency, label.TextStrokeTransparency = 0, Theme.TEXT_STROKE_TRANSPARENCY end
	end
	frame.Destroying:Once(function() for _, row in rows do stopAnimation(row) end end)
	local function clearRow(row: any, key: string)
		row.animating = true
		local slide = TweenService:Create(row.content, CLEAR_TWEEN, { Position = UDim2.fromOffset(48, -8) })
		table.insert(row.tweens, slide)
		for _, label in { row.title, row.amount } do
			Theme.applyOutlinedTitle(label, Theme.CARD_SELECTED_BG)
			table.insert(row.tweens, TweenService:Create(label, CLEAR_TWEEN, { TextTransparency = 1, TextStrokeTransparency = 1 }))
		end
		row.connection = slide.Completed:Connect(function(state)
			if state ~= Enum.PlaybackState.Completed or row.key ~= key then return end
			row.frame.Visible = false
			stopAnimation(row)
		end)
		for _, tween in row.tweens do tween:Play() end
	end
	local function refresh()
		local entries = Presentation.rows(payload, weekly)
		local track = tracks[if weekly then 2 else 1]
		local period = if entries[1] then entries[1].dayKey else nil
		if track.period ~= period then track.period, track.seen = period, {} end
		for index, row in rows do
			local entry = entries[index]
			local quest = if entry then entry.quest else nil
			local key = (if weekly then "Weekly:" else "Daily:") .. tostring(period) .. ":" .. (if quest then quest.id else "Loading")
			if row.key ~= key then stopAnimation(row); row.key = key end
			row.title.Text = if entry then entry.title else "Loading quests..."
			row.amount.Text = if quest then string.format("%d/%d", quest.progress, quest.target) else ""
			if not quest then row.frame.Visible = false; continue end
			local complete = quest.progress >= quest.target
			local newlyComplete = complete and track.seen[quest.id] == false
			track.seen[quest.id] = complete
			if not complete then
				stopAnimation(row)
				row.frame.Visible = true
				Theme.applyOutlinedTitle(row.title)
				Theme.applyOutlinedTitle(row.amount)
			elseif newlyComplete then
				row.frame.Visible = true
				clearRow(row, key)
			elseif not row.animating then
				-- Already-complete objectives stay cleared on rejoin/tab switches.
				row.frame.Visible = false
			end
		end
		if heading then heading.Text = if weekly then "Weekly Quests" else "Daily Quests" end
	end
	heading = Instance.new("TextButton")
	heading.Name, heading.Text, heading.TextSize = "QuestToggle", "Daily Quests", 14
	heading.Position, heading.Size = UDim2.fromOffset(8, 8), UDim2.new(1, -16, 0, 30)
	heading.Parent = frame
	Theme.applyOutlinedTitle(heading)
	transparent(heading)
	heading.Activated:Connect(function() Audio.play("UiClick"); weekly = not weekly; refresh() end)
	local cycle = Instance.new("ImageLabel")
	cycle.Name, cycle.Image = "CycleIcon", "rbxassetid://86604833779310"
	cycle.BackgroundTransparency, cycle.Active = 1, false
	cycle.AnchorPoint, cycle.Position = Vector2.new(0, 0.5), UDim2.new(0.5, 62, 0.5, 0)
	cycle.Size, cycle.ScaleType, cycle.Parent = UDim2.fromOffset(22, 22), Enum.ScaleType.Fit, heading
	local damage, day = main:FindFirstChild("DamageMeter") :: Frame?, main:FindFirstChild("LevelUI") :: Frame?
	local function resize()
		local factor = Sizing.desktop(main.AbsoluteSize)
		local top = if damage then damage.AbsolutePosition.Y + damage.AbsoluteSize.Y - main.AbsolutePosition.Y + 16 * factor else main.AbsoluteSize.Y * 0.3
		local messageVisible = day and ((day:FindFirstChild("StartCountdown") and day.StartCountdown.Visible) or (day:FindFirstChild("BigWaveWarning") and day.BigWaveWarning.Visible))
		local bottom = if day then day.AbsolutePosition.Y - main.AbsolutePosition.Y - (if messageVisible then 56 else 12) * factor else main.AbsoluteSize.Y - 150 * factor
		local space = bottom - top
		frame.Visible = space >= 80 * factor
		if not frame.Visible then return end
		local height = math.min(HEIGHT, space / factor)
		list.Visible = height >= 150
		zoom.Scale = factor
		frame.Size = UDim2.fromOffset(WIDTH, height)
		frame.Position = UDim2.fromOffset(main.AbsoluteSize.X - 16 * factor, bottom - height * factor)
	end
	main:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	for _, neighbor in { damage, day } do
		neighbor:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
		neighbor:GetPropertyChangedSignal("AbsolutePosition"):Connect(resize)
	end
	if day then
		for _, child in day:GetChildren() do
			if child:IsA("GuiObject") then child:GetPropertyChangedSignal("Visible"):Connect(resize) end
		end
	end
	resize(); refresh()
	return { frame = frame, refresh = function(state: any, _busy: boolean) payload = state; refresh() end }
end

return QuestTracker
