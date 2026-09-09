--!strict
--[[
	BubbleShot
	Launch a trap bubble from the plant's mouth; claimed Double Bubble may
	fire a second copy.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelUtil = require(ReplicatedStorage.Shared.Utilities.ModelUtil)

local CombatService = require(script.Parent.Parent.Parent.CombatService)

local BubbleShot = {}

local MOUTH_NAMES = { "Mouth", "Snout", "Jaw", "Head" }

local function namedMuzzle(model: Model): Vector3?
	for _, name in MOUTH_NAMES do
		local inst = model:FindFirstChild(name, true)
		if inst and inst:IsA("Attachment") then
			return inst.WorldPosition
		end
		if inst and inst:IsA("Bone") then
			return inst.WorldPosition
		end
		if inst and inst:IsA("BasePart") then
			return inst.Position + Vector3.new(inst.Size.X * 0.35, 0, 0)
		end
	end
	return nil
end

function BubbleShot.mouthWorld(model: Model): Vector3
	local named = namedMuzzle(model)
	if named then
		return named
	end
	-- Units face +X (enemy). Sit the volley on the east face of the visual AABB.
	local size, center = ModelUtil.getVisualSizeAndCenter(model)
	return Vector3.new(center.X + size.X * 0.48, center.Y + size.Y * 0.04, center.Z)
end

function BubbleShot.launch(ctx, position, trapDuration: number): boolean
	local options = {
		kind = "Bubble",
		soundKey = "BubbleTrap",
		statusKind = "Freeze",
		statusDuration = trapDuration,
		statusVisual = "Bubble",
		sourceInstanceId = ctx.instanceId,
		sourceBrainrotId = ctx.definition.id,
		originWorld = BubbleShot.mouthWorld(ctx.model),
	}

	local fired = CombatService.launchProjectile(
		ctx.plotModel,
		position,
		ctx.definition.rangeTiles,
		ctx.definition.damage,
		ctx.ownerUserId,
		options
	)
	if not fired then
		return false
	end

	local chance = 0
	if ctx.definition.abilityParams then
		chance = ctx.definition.abilityParams.extraBubbleChance or 0
	end
	if chance > 0 and math.random() * 100 < chance then
		CombatService.launchProjectile(
			ctx.plotModel,
			position,
			ctx.definition.rangeTiles,
			ctx.definition.damage,
			ctx.ownerUserId,
			options
		)
	end
	return true
end

return BubbleShot
