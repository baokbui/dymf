--!strict
--[[
	PlantToast
	Stacked failure messages below the Shop bar. Newest under the shop;
	older ones slide up and fade. Cartoon outline look via UITheme.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage:WaitForChild("Shared").Config.UITheme)

local PlantToast = {}
PlantToast.__index = PlantToast

local SHOP_HEIGHT = 100
local TOAST_WIDTH = 420
local TOAST_HEIGHT = 34
local TOAST_GAP = 6
local HOLD_DURATION = 2.4
local MOVE_DURATION = 0.28
local FADE_DURATION = 0.4
local MAX_VISIBLE = 4

type ToastEntry = {
	frame: Frame,
	label: TextLabel,
	accent: Frame,
	stroke: UIStroke,
	token: number,
}

export type PlantToastHud = typeof(setmetatable(
	{} :: {
		container: Frame,
		active: { ToastEntry },
		nextToken: number,
	},
	PlantToast
))

local function tweenFade(entry: ToastEntry, transparency: number, duration: number, yOffset: number?)
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local goals: { [string]: any } = {
		BackgroundTransparency = transparency,
	}
	if yOffset ~= nil then
		goals.Position = UDim2.fromOffset(0, yOffset)
	end
	TweenService:Create(entry.frame, info, goals):Play()
	TweenService:Create(entry.label, info, {
		TextTransparency = transparency,
		TextStrokeTransparency = transparency,
	}):Play()
	TweenService:Create(entry.accent, info, { BackgroundTransparency = transparency }):Play()
	TweenService:Create(entry.stroke, info, { Transparency = transparency }):Play()
end

function PlantToast.new(parent: Frame): PlantToastHud
	local container = Instance.new("Frame")
	container.Name = "PlantToastStack"
	container.AnchorPoint = Vector2.new(0.5, 0)
	container.Position = UDim2.new(0.5, 0, 0, SHOP_HEIGHT + 8)
	container.Size = UDim2.fromOffset(TOAST_WIDTH, (TOAST_HEIGHT + TOAST_GAP) * MAX_VISIBLE + 20)
	container.BackgroundTransparency = 1
	container.ClipsDescendants = false
	container.Active = false
	container.Interactable = false
	container.ZIndex = 30
	container.Parent = parent

	return setmetatable({
		container = container,
		active = {},
		nextToken = 0,
	}, PlantToast)
end

function PlantToast.push(self: PlantToastHud, message: string)
	for index, entry in self.active do
		local targetY = -((TOAST_HEIGHT + TOAST_GAP) * index)
		local fade = math.clamp(0.35 + (index - 1) * 0.2, 0.35, 0.92)
		tweenFade(entry, fade, MOVE_DURATION, targetY)
	end

	self.nextToken += 1
	local token = self.nextToken

	local frame = Instance.new("Frame")
	frame.Name = "Toast"
	frame.Size = UDim2.new(1, 0, 0, TOAST_HEIGHT)
	frame.Position = UDim2.fromOffset(0, 10)
	frame.BackgroundColor3 = UITheme.TOAST_BG
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	frame.ZIndex = 31
	frame.Parent = self.container
	UITheme.styleCorner(frame, UITheme.CORNER_BUTTON)
	local stroke = UITheme.applyStroke(frame, UITheme.STROKE_CARD)

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.Size = UDim2.new(0, 5, 1, -10)
	accent.Position = UDim2.fromOffset(6, 5)
	accent.BackgroundColor3 = UITheme.DANGER
	accent.BorderSizePixel = 0
	accent.ZIndex = 32
	accent.Parent = frame
	UITheme.styleCorner(accent, 2)
	UITheme.applyStroke(accent, 2)

	local label = Instance.new("TextLabel")
	label.Name = "Message"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(18, 0)
	label.Size = UDim2.new(1, -26, 1, 0)
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = message
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.ZIndex = 32
	label.Parent = frame
	UITheme.applyOutlinedTitle(label, UITheme.TOAST_TEXT)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14

	local entry: ToastEntry = {
		frame = frame,
		label = label,
		accent = accent,
		stroke = stroke,
		token = token,
	}
	table.insert(self.active, 1, entry)

	TweenService:Create(
		frame,
		TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(0, 0) }
	):Play()

	while #self.active > MAX_VISIBLE do
		local oldest = table.remove(self.active)
		if oldest then
			oldest.frame:Destroy()
		end
	end

	task.delay(HOLD_DURATION, function()
		if entry.token ~= token or not frame.Parent then
			return
		end
		tweenFade(entry, 1, FADE_DURATION, (frame.Position.Y.Offset) - TOAST_HEIGHT)
		task.delay(FADE_DURATION, function()
			local idx = table.find(self.active, entry)
			if idx then
				table.remove(self.active, idx)
			end
			if frame.Parent then
				frame:Destroy()
			end
		end)
	end)
end

return PlantToast
