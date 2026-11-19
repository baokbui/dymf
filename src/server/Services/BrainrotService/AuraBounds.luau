--!strict
-- Aura-only bounds: skinned rig joints can extend beyond their MeshPart boxes.
-- Keep placement/feet snapping untouched; this envelope is cosmetic only.
local Shared = game:GetService("ReplicatedStorage").Shared
local ModelUtil = require(Shared.Utilities.ModelUtil)
local Config = require(Shared.Config.EvolutionVfxConfig)
local Bounds = {}

function Bounds.measure(model: Model): (Vector3, Vector3)
	local size, center = ModelUtil.getVisualSizeAndCenter(model)
	local minimum, maximum = center - size / 2, center + size / 2
	local padding = math.max(Config.RIG_BOUNDS_MIN_PADDING, size.Y * Config.RIG_BOUNDS_PADDING_RATIO)
	for _, item in model:GetDescendants() do
		if not item:IsA("Bone") or item:FindFirstAncestor("AuraVfx") then continue end
		local p = item.TransformedWorldCFrame.Position
		minimum = Vector3.new(math.min(minimum.X, p.X - padding), math.min(minimum.Y, p.Y - padding), math.min(minimum.Z, p.Z - padding))
		maximum = Vector3.new(math.max(maximum.X, p.X + padding), math.max(maximum.Y, p.Y + padding), math.max(maximum.Z, p.Z + padding))
	end
	return maximum - minimum, (minimum + maximum) / 2
end

return Bounds
