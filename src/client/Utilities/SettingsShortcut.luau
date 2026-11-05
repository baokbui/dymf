--!strict
local GuiService = game:GetService("GuiService")
local SettingsShortcut = {}
local MAX_BUTTON_SIZE = 48

function SettingsShortcut.mount(main: ScreenGui, open: () -> ()): ImageButton
	local bar = Instance.new("ScreenGui")
	bar.Name = "BvmTopbar"
	bar.ResetOnSpawn = false
	bar.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets

	local button = Instance.new("ImageButton")
	button.Name = "Settings"
	button.AnchorPoint = Vector2.new(0, 0.5)
	button.BackgroundColor3 = Color3.fromRGB(24, 28, 32)
	button.BorderSizePixel = 0
	button.Active = false
	button.Visible = false
	button.Size = UDim2.fromOffset(0, 0)
	button.Parent = bar

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button

	local icon = Instance.new("ImageLabel")
	icon.Name, icon.Image = "Icon", "rbxassetid://7059346373"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint, icon.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	icon.Size, icon.ScaleType = UDim2.fromScale(0.5, 0.5), Enum.ScaleType.Fit
	icon.Parent = button

	local function resize()
		local height = GuiService.TopbarInset.Height
		-- Safe-inset ScreenGuis can briefly report the entire viewport on join.
		if height <= 0 or bar.AbsoluteSize.Y <= 0 or bar.AbsoluteSize.Y > height + 1 then
			button.Visible = false
			return
		end
		local size = math.min(math.round(height * 0.76), bar.AbsoluteSize.X - 12, MAX_BUTTON_SIZE)
		button.Visible = size > 0
		button.Size = UDim2.fromOffset(math.max(0, size), math.max(0, size))
		button.Position = UDim2.new(0, 6, 0.5, math.round(height * 0.085))
	end
	local sizeConnection = bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	local insetConnection = GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(resize)
	bar.Destroying:Once(function()
		sizeConnection:Disconnect()
		insetConnection:Disconnect()
	end)
	button.Activated:Connect(open)
	main.Destroying:Once(function() bar:Destroy() end)
	bar.Parent = main.Parent
	resize()
	return button
end

return SettingsShortcut
