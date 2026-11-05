--!strict
-- Settings presentation and client input. The caller owns each setting's value.
local UserInputService = game:GetService("UserInputService")
local Theme = require(game:GetService("ReplicatedStorage").Shared.Config.UITheme)
local Controls = {}

function Controls.text(parent: Instance, value: string, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text, label.TextSize = value, size
	label.TextXAlignment = Enum.TextXAlignment.Left
	Theme.applyOutlinedTitle(label)
	label.Parent = parent
	return label
end

function Controls.row(parent: Frame, name: string, title: string, icon: string, order: number, iconImage: string?): Frame
	local row = Instance.new("Frame")
	row.Name, row.LayoutOrder = name, order
	row.Size = UDim2.new(1, 0, 0, 58)
	Theme.applyButtonLook(row, Theme.SETTINGS_ROW, 12)
	Theme.applySurfaceDepth(row)
	row.Parent = parent
	local tile = Controls.text(row, icon, 18)
	tile.Position, tile.Size = UDim2.fromOffset(10, 10), UDim2.fromOffset(38, 38)
	tile.TextXAlignment = Enum.TextXAlignment.Center
	Theme.applyButtonLook(tile, Theme.SETTINGS_TILE)
	if iconImage then
		local image = Instance.new("ImageLabel")
		image.Name = "Icon"
		image.BackgroundTransparency = 1
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Size = UDim2.fromScale(0.65, 0.65)
		image.ScaleType = Enum.ScaleType.Fit
		image.Image = iconImage
		image.Parent = tile
	end
	local label = Controls.text(row, title, 15)
	label.Position, label.Size = UDim2.fromOffset(58, 0), UDim2.new(0.49, -58, 1, 0)
	label.TextWrapped = true
	return row
end

function Controls.switch(row: Frame, name: string, initial: boolean, change: (boolean) -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Name, button.Text = name, ""
	button.AnchorPoint, button.Position = Vector2.new(1, 0.5), UDim2.new(1, -12, 0.5, 0)
	button.Size, button.TextSize = UDim2.fromOffset(98, 34), 14
	button.Parent = row
	Theme.applyButtonLook(button, nil, 17)
	Theme.applySurfaceDepth(button)
	Theme.applyOutlinedTitle(button)
	local thumb = Instance.new("Frame")
	thumb.Name, thumb.Size = "Thumb", UDim2.fromOffset(24, 24)
	Theme.applyButtonLook(thumb, Theme.TITLE, 12)
	thumb.Parent = button
	local caption = Controls.text(button, "", 14)
	caption.TextXAlignment = Enum.TextXAlignment.Center
	caption.Size = UDim2.new(1, -30, 1, 0)
	local enabled = initial
	local function draw()
		button.BackgroundColor3 = if enabled then Theme.SUCCESS_DARK else Theme.SETTINGS_TILE
		caption.Text = if enabled then "ON" else "OFF"
		caption.Position = UDim2.fromOffset(if enabled then 0 else 30, 0)
		thumb.Position = if enabled then UDim2.new(1, -29, 0, 5) else UDim2.fromOffset(5, 5)
	end
	draw()
	button.Activated:Connect(function()
		enabled = not enabled
		draw()
		change(enabled)
	end)
	return button
end

function Controls.slider(row: Frame, scroll: ScrollingFrame, change: (number) -> ())
	local readout = Controls.text(row, "100%", 14)
	readout.AnchorPoint, readout.Position = Vector2.new(1, 0), UDim2.new(1, -10, 0, 0)
	readout.Size, readout.TextXAlignment = UDim2.fromOffset(45, 58), Enum.TextXAlignment.Right

	local target = Instance.new("TextButton")
	target.Name, target.BackgroundTransparency, target.Text = "Slider", 1, ""
	target.Position, target.Size = UDim2.new(0.5, 0, 0, 7), UDim2.new(0.5, -60, 1, -14)
	target.Parent = row
	local track = Instance.new("Frame")
	track.Position, track.Size = UDim2.new(0, 8, 0.5, -5), UDim2.new(1, -16, 0, 10)
	Theme.applyButtonLook(track, Theme.SETTINGS_TILE, 5)
	track.Parent = target
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3, fill.BorderSizePixel = Theme.SUCCESS, 0
	Theme.styleCorner(fill, 5)
	Theme.applySurfaceDepth(fill)
	fill.Parent = track
	local thumb = Instance.new("Frame")
	thumb.Name, thumb.AnchorPoint, thumb.Size = "Thumb", Vector2.new(0.5, 0.5), UDim2.fromOffset(22, 22)
	Theme.applyButtonLook(thumb, Theme.TITLE, 11)
	thumb.Parent = track

	local percent = 100
	local drag: InputObject? = nil
	local function setPercent(value: number)
		local nextPercent = math.clamp(math.round(value), 0, 100)
		fill.Size = UDim2.fromScale(nextPercent / 100, 1)
		thumb.Position = UDim2.fromScale(nextPercent / 100, 0.5)
		readout.Text = string.format("%d%%", nextPercent)
		if nextPercent == percent then return end
		percent = nextPercent
		change(percent / 100)
	end
	setPercent(percent)
	local function move(x: number)
		setPercent(100 * (x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X))
	end
	local function finish()
		if not drag then return end
		drag = nil
		scroll.ScrollingEnabled = true
	end
	target.InputBegan:Connect(function(input)
		if not scroll.ScrollingEnabled then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		drag = input
		scroll.ScrollingEnabled = false
		move(input.Position.X)
	end)
	local moved = UserInputService.InputChanged:Connect(function(input)
		if drag and (input == drag or (drag.UserInputType == Enum.UserInputType.MouseButton1
			and input.UserInputType == Enum.UserInputType.MouseMovement)) then
			move(input.Position.X)
		end
	end)
	local ended = UserInputService.InputEnded:Connect(function(input)
		if input == drag then finish() end
	end)
	local unfocused = UserInputService.WindowFocusReleased:Connect(finish)
	target.Activated:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard or input.KeyCode == Enum.KeyCode.ButtonA then
			setPercent(if percent == 100 then 0 else percent + 10)
		end
	end)
	target.Destroying:Once(function()
		finish()
		moved:Disconnect()
		ended:Disconnect()
		unfocused:Disconnect()
	end)
end

return Controls
