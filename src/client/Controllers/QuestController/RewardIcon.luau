--!strict
-- Reuses HUD textures; the free ticket is a lightweight native UI illustration.
local Theme = require(game:GetService("ReplicatedStorage").Shared.Config.UITheme)
local RewardIcon = {}
local images = {
	Brains = "rbxassetid://12691330734",
	WalkSpeed = "rbxassetid://82103513055414",
	Magnet = "rbxassetid://73519143112132",
}

function RewardIcon.new(parent: Frame): ImageLabel
	local icon = Instance.new("ImageLabel")
	icon.Name, icon.BackgroundTransparency = "Icon", 1
	icon.AnchorPoint, icon.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 32)
	icon.Size, icon.ScaleType, icon.Parent = UDim2.fromOffset(64, 64), Enum.ScaleType.Fit, parent
	return icon
end

function RewardIcon.set(icon: ImageLabel, reward: any)
	local key = if reward and reward.kind == "Upgrade" then reward.upgradeId else if reward then reward.kind else nil
	icon.Image = images[key or ""] or ""
	local ticket = icon:FindFirstChild("Ticket") :: Frame?
	if key == "Ticket" and not ticket then
		ticket = Instance.new("Frame")
		ticket.Name, ticket.Size = "Ticket", UDim2.fromOffset(60, 39)
		ticket.AnchorPoint, ticket.Position, ticket.Rotation = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), -12
		ticket.Parent = icon
		Theme.applyButtonLook(ticket, Theme.WARNING, 8)
		for index = 0, 3 do
			local dash = Instance.new("Frame")
			dash.BorderSizePixel, dash.BackgroundColor3 = 0, Theme.OUTLINE
			dash.Position, dash.Size, dash.Parent = UDim2.fromOffset(15, 5 + index * 8), UDim2.fromOffset(2, 4), ticket
		end
		local brain = Instance.new("ImageLabel")
		brain.Name, brain.Image, brain.BackgroundTransparency = "Brain", images.Brains, 1
		brain.Position, brain.Size = UDim2.fromOffset(23, 5), UDim2.fromOffset(29, 29)
		brain.ScaleType, brain.Parent = Enum.ScaleType.Fit, ticket
	end
	if ticket then ticket.Visible = key == "Ticket" end
end

return RewardIcon
