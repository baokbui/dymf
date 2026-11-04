--!strict
-- Compact animated HUD navigation, independent from the feature window.
local TweenService = game:GetService("TweenService")
local Sizing = require(script.Parent.UISizing)
local MenuDrawer = {}
local INFO = TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

function MenuDrawer.new(main: ScreenGui, entry: TextButton, sections: Frame, bars: { Frame }, caption: TextLabel): any
	local root = Instance.new("Frame")
	root.Name, root.BackgroundTransparency, root.Visible, root.ZIndex = "MenuDrawer", 1, false, 40
	root:SetAttribute("ScreenSpaceUI", true)
	root.Parent = main
	local viewport = Instance.new("ScrollingFrame")
	viewport.Name, viewport.Size = "Viewport", UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency, viewport.BorderSizePixel, viewport.ScrollBarThickness = 1, 0, 3
	viewport.ScrollingDirection, viewport.Parent = Enum.ScrollingDirection.X, root
	sections.Parent, sections.Position = viewport, UDim2.new()
	local zoom = Instance.new("UIScale")
	zoom.Parent = sections
	local opened, width, height = false, 0, 0
	local magnet = main:FindFirstChild("MagnetEntry") :: GuiObject?
	local tweens, completion = {}, nil :: RBXScriptConnection?
	local function cancel()
		if completion then completion:Disconnect(); completion = nil end
		for _, tween in tweens do tween:Cancel() end
		table.clear(tweens)
	end
	local function tween(gui: Instance, values: any)
		local animation = TweenService:Create(gui, INFO, values)
		table.insert(tweens, animation)
		animation:Play()
		return animation
	end
	local function resize()
		cancel()
		local factor = Sizing.desktop(main.AbsoluteSize)
		local start = entry.AbsolutePosition - main.AbsolutePosition
		local x = start.X + entry.AbsoluteSize.X + 12 * factor
		local right = main.AbsoluteSize.X - 16 * factor
		if magnet and main.AbsoluteSize.X >= 900 then right = math.min(right, magnet.AbsolutePosition.X - main.AbsolutePosition.X - 12 * factor) end
		local available = math.max(0, right - x)
		local iconScale = math.min(factor, math.max(1, available / sections.Size.X.Offset))
		height = 94 * iconScale
		width = math.min(sections.Size.X.Offset * iconScale, available)
		zoom.Scale = iconScale
		root.Position, root.Size = UDim2.fromOffset(x, start.Y + entry.AbsoluteSize.Y - height), UDim2.fromOffset(if opened then width else 0, height)
		sections.Position = UDim2.new()
		viewport.CanvasSize = UDim2.fromOffset(sections.Size.X.Offset * iconScale, height)
		root.Visible = opened
		bars[1].Rotation, bars[3].Rotation = if opened then 45 else 0, if opened then -45 else 0
		bars[1].Position = UDim2.fromOffset(22, if opened then 29 else 12)
		bars[3].Position = UDim2.fromOffset(22, if opened then 29 else 46)
		bars[2].Visible = not opened
	end
	local function setOpen(value: boolean)
		cancel()
		opened = value
		root:SetAttribute("Open", value)
		caption.Text = if value then "Close" else "Menu"
		bars[2].Visible = not value
		tween(bars[1], { Rotation = if value then 45 else 0, Position = UDim2.fromOffset(22, if value then 29 else 12) })
		tween(bars[3], { Rotation = if value then -45 else 0, Position = UDim2.fromOffset(22, if value then 29 else 46) })
		if value then root.Visible = true; viewport.CanvasPosition = Vector2.zero end
		tween(sections, { Position = UDim2.fromOffset(if value then 0 else -32, 0) })
		local animation = tween(root, { Size = UDim2.fromOffset(if value then width else 0, height) })
		completion = animation.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and not opened then root.Visible = false end
		end)
	end
	main:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	entry:GetPropertyChangedSignal("AbsolutePosition"):Connect(resize)
	entry:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	if magnet then
		magnet:GetPropertyChangedSignal("AbsolutePosition"):Connect(resize)
		magnet:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	end
	root.Destroying:Once(cancel)
	resize()
	return { setOpen = setOpen, isOpen = function() return opened end }
end

return MenuDrawer
