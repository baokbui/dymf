--!strict
-- Shared passive shovel image for the HUD button and screen-space cursor.
-- Catalog asset: 129146573433376. ImageLabel uses its texture instead.
local ShovelIcon = {}
local TEXTURE = "rbxassetid://123683019299968"

function ShovelIcon.mount(parent: GuiObject): ImageLabel
	local icon = Instance.new("ImageLabel")
	icon.Name, icon.BackgroundTransparency, icon.Active = "ShovelIcon", 1, false
	icon.Position, icon.Size = UDim2.fromScale(0.08, 0.06), UDim2.fromScale(0.84, 0.88)
	icon.Image, icon.ScaleType = TEXTURE, Enum.ScaleType.Fit
	icon.Parent = parent
	return icon
end

return ShovelIcon
