--!strict
-- Flat, resolution-independent crystal artwork using native UI geometry.
local Shared = game:GetService("ReplicatedStorage").Shared
local Appearance = require(Shared.Utilities.ShardAppearance)
local Config = require(Shared.Config.ShardVisualConfig)
local ShardIcon = {}
local MonsterPreview = require(script.Parent.MonsterPreview)
local Monsters = require(Shared.Monsters)
local ShardEffects = require(script.Parent.ShardEffects)

local function square(parent: Instance, name: string, size: UDim2, position: UDim2, color: Color3): Frame
	local frame = Instance.new("Frame")
	frame.Name, frame.Size, frame.Position = name, size, position
	frame.BackgroundColor3, frame.BorderSizePixel = color, 0
	frame.Parent = parent
	return frame
end

function ShardIcon.new(parent: Instance, monsterId: string): Frame
	local color = Appearance.color(monsterId)
	local icon = Instance.new("Frame")
	icon.Name, icon.BackgroundTransparency = "ShardIcon", 1
	icon.Size = UDim2.fromOffset(68, 68)
	icon:SetAttribute("MonsterId", monsterId)
	icon.Parent = parent
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = icon
	local shadow = square(icon, "Shadow", UDim2.fromScale(0.59, 0.59), UDim2.fromScale(0.5, 0.54), Config.OUTLINE_COLOR)
	shadow.AnchorPoint, shadow.Rotation = Vector2.new(0.5, 0.5), 45
	shadow.BackgroundTransparency = 0.7
	local border = square(icon, "CrystalOutline", UDim2.fromScale(0.59, 0.59), UDim2.fromScale(0.5, 0.47), Config.OUTLINE_COLOR)
	border.AnchorPoint, border.Rotation = Vector2.new(0.5, 0.5), 45
	local face = square(border, "Crystal", UDim2.fromScale(0.86, 0.86), UDim2.fromScale(0.5, 0.5), color)
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	square(face, "LightFacet", UDim2.fromScale(0.5, 0.5), UDim2.new(), color:Lerp(Color3.new(1, 1, 1), 0.55))
	square(face, "TopFacet", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.5, 0), color:Lerp(Color3.new(1, 1, 1), 0.2))
	square(face, "DarkFacet", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.5, 0.5), color:Lerp(Config.OUTLINE_COLOR, 0.35))
	local gleam = square(face, "Gleam", UDim2.fromScale(0.08, 0.44), UDim2.fromScale(0.12, 0.1), Color3.new(1, 1, 1))
	gleam.BackgroundTransparency = 0.25
	-- The portrait sits between the base crystal and this translucent face layer.
	local glass = border:Clone()
	glass.Name, glass.ZIndex, glass.BackgroundTransparency = "CrystalOverlay", 4, 1
	for _, layer in glass:GetDescendants() do
		if layer:IsA("GuiObject") then
			layer.ZIndex = 4
			layer.BackgroundTransparency = if layer.Name == "Crystal" then 1
				elseif layer.Name == "Gleam" then 0.4 else Config.ICON_GLASS_TRANSPARENCY
		end
	end
	glass.Parent = icon
	local rarity = Appearance.rarity(monsterId)
	if rarity > 0 then ShardEffects.decorateIcon(icon, border, color, rarity) end
	return icon
end

function ShardIcon.mountPortrait(icon: Frame)
	if icon:FindFirstChild("MonsterPortrait") then return end
	local id = icon:GetAttribute("MonsterId")
	local definition = if type(id) == "string" then Monsters.get(id) else nil
	if not definition then return end
	local holder = Instance.new("Frame")
	holder.Name, holder.BackgroundTransparency = "MonsterPortrait", 1
	holder.Size, holder.AnchorPoint, holder.Position = UDim2.fromScale(Config.ICON_PORTRAIT_SIZE.X, Config.ICON_PORTRAIT_SIZE.Y), Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.47)
	-- This clipped rectangle fits entirely within the diamond's inner facets.
	holder.ClipsDescendants = true
	holder.ZIndex = 2
	holder.Parent = icon
	local portrait = MonsterPreview.mount(holder, definition, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0), nil, Config.PORTRAIT_TRANSPARENCY, true)
	portrait.ZIndex = 2
end

return ShardIcon
