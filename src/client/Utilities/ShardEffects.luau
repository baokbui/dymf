--!strict
-- One quality listener and visibility-driven tweens for shard icon accents.
local TweenService = game:GetService("TweenService")
local Quality = require(game.ReplicatedStorage.Shared.Utilities.VfxLoad)
local Effects = {}
local refreshers: { [Frame]: () -> () } = {}
Quality.onChanged(function() for _, refresh in refreshers do refresh() end end)

function Effects.decorateIcon(icon: Frame, border: Frame, color: Color3, rarity: number)
	local stroke = Instance.new("UIStroke")
	stroke.Name, stroke.Color, stroke.Thickness = "RarityGlow", color:Lerp(Color3.new(1, 1, 1), 0.55), if rarity == 2 then 2 else 1
	stroke.Transparency, stroke.Parent = 0.2, border
	for index = 1, if rarity == 2 then 4 else 2 do
		local sparkle = Instance.new("Frame")
		sparkle.Name, sparkle.BackgroundTransparency = "ShardSparkle", 1
		sparkle.Size, sparkle.AnchorPoint = UDim2.fromScale(0.22, 0.22), Vector2.new(0.5, 0.5)
		local angle = index * math.pi / 2 + 0.4
		sparkle.Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.4, 0.47 + math.sin(angle) * 0.4)
		sparkle.Rotation, sparkle.Parent = 25, icon
		for _, size in { UDim2.fromScale(0.14, 1), UDim2.fromScale(1, 0.14) } do
			local ray = Instance.new("Frame")
			ray.AnchorPoint, ray.Position, ray.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), size
			ray.BackgroundColor3, ray.BorderSizePixel, ray.Parent = stroke.Color, 0, sparkle
		end
	end
	local tween = TweenService:Create(stroke, TweenInfo.new(if rarity == 2 then 0.9 else 1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.8 })
	local running = false
	local function refresh()
		local visible = Quality.isHighQuality()
		local ancestor: Instance? = icon
		while ancestor do
			if ancestor:IsA("GuiObject") and not ancestor.Visible then visible = false end
			if ancestor:IsA("ScreenGui") and not ancestor.Enabled then visible = false end
			ancestor = ancestor.Parent
		end
		if visible == running then return end
		running = visible
		if visible then tween:Play() else tween:Cancel(); stroke.Transparency = 0.2 end
	end
	local connections = {}
	local function watch()
		for _, connection in connections do connection:Disconnect() end
		table.clear(connections)
		local ancestor: Instance? = icon
		while ancestor do
			if ancestor:IsA("GuiObject") then table.insert(connections, ancestor:GetPropertyChangedSignal("Visible"):Connect(refresh))
			elseif ancestor:IsA("ScreenGui") then table.insert(connections, ancestor:GetPropertyChangedSignal("Enabled"):Connect(refresh)) end
			ancestor = ancestor.Parent
		end
		refresh()
	end
	refreshers[icon] = refresh
	local ancestry = icon.AncestryChanged:Connect(watch)
	icon.Destroying:Once(function()
		refreshers[icon] = nil
		for _, connection in connections do connection:Disconnect() end
		ancestry:Disconnect(); tween:Cancel()
	end)
	watch()
end

return Effects
