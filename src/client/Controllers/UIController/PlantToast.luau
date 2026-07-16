--!strict
--[[
	PlantToast
	Stacked failure messages below the Shop bar. Newest toast sits under the
	shop; older ones slide up (toward the shop) and fade out.
]]

local TweenService = game:GetService("TweenService")

local PlantToast = {}
PlantToast.__index = PlantToast

local SHOP_HEIGHT = 86 -- Shop PANEL_HEIGHT (cards + padding)
local TOAST_WIDTH = 420
local TOAST_HEIGHT = 32
local TOAST_GAP = 6
local HOLD_DURATION = 2.4
local MOVE_DURATION = 0.28
local FADE_DURATION = 0.4
local MAX_VISIBLE = 4

local BG = Color3.fromRGB(28, 22, 28)
local TEXT = Color3.fromRGB(255, 210, 210)
local ACCENT = Color3.fromRGB(220, 90, 90)

type ToastEntry = {
	frame: Frame,
	label: TextLabel,
	accent: Frame,
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

local function styleCorner(instance: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function tweenFade(entry: ToastEntry, transparency: number, duration: number, yOffset: number?)
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local goals: { [string]: any } = {
		BackgroundTransparency = math.clamp(0.12 + transparency * 0.88, 0.12, 1),
	}
	if yOffset ~= nil then
		goals.Position = UDim2.fromOffset(0, yOffset)
	end
	TweenService:Create(entry.frame, info, goals):Play()
	TweenService:Create(entry.label, info, { TextTransparency = transparency }):Play()
	TweenService:Create(entry.accent, info, { BackgroundTransparency = transparency }):Play()
end

function PlantToast.new(parent: Frame): PlantToastHud
	local container = Instance.new("Frame")
	container.Name = "PlantToastStack"
	container.AnchorPoint = Vector2.new(0.5, 0)
	container.Position = UDim2.new(0.5, 0, 0, SHOP_HEIGHT + 8)
	container.Size = UDim2.fromOffset(TOAST_WIDTH, (TOAST_HEIGHT + TOAST_GAP) * MAX_VISIBLE + 20)
	container.BackgroundTransparency = 1
	container.ClipsDescendants = false
	container.ZIndex = 30
	container.Parent = parent

	return setmetatable({
		container = container,
		active = {},
		nextToken = 0,
	}, PlantToast)
end

function PlantToast.push(self: PlantToastHud, message: string)
	-- Older toasts rise toward the shop and fade.
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
	frame.BackgroundColor3 = BG
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.ZIndex = 31
	frame.Parent = self.container
	styleCorner(frame, 8)

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.Size = UDim2.new(0, 4, 1, -8)
	accent.Position = UDim2.fromOffset(6, 4)
	accent.BackgroundColor3 = ACCENT
	accent.BorderSizePixel = 0
	accent.ZIndex = 32
	accent.Parent = frame
	styleCorner(accent, 2)

	local label = Instance.new("TextLabel")
	label.Name = "Message"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(16, 0)
	label.Size = UDim2.new(1, -24, 1, 0)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 15
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = TEXT
	label.Text = message
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.ZIndex = 32
	label.Parent = frame

	local entry: ToastEntry = {
		frame = frame,
		label = label,
		accent = accent,
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
