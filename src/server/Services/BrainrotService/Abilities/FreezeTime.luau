--!strict
--[[
	FreezeTime (Lirili Larila)
	One-shot on place: play attack anim + cast SFX, Freeze 2 tiles ahead
	and 2 tiles behind (plus this tile) for freezeDuration, despawn when
	the cast animation ends, then thaw SFX when the status expires.
	Legendary Winter's Grasp (`abilityParams.freezeEntireLane`) freezes
	the whole row instead.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EvolutionConfig = require(ReplicatedStorage.Shared.Config.EvolutionConfig)
local CombatService = require(script.Parent.Parent.Parent.CombatService)
local ProgressService = require(script.Parent.Parent.Parent.ProgressService)

local FreezeTime = {}

local DEFAULT_FREEZE_DURATION = 7
local DEFAULT_CAST_FALLBACK = 1.2

function FreezeTime.onPlaced(ctx, callbacks)
	local freezeDuration = DEFAULT_FREEZE_DURATION
	local freezeTiles = 2
	local freezeEntireLane = false
	if ctx.definition.abilityParams then
		freezeDuration = ctx.definition.abilityParams.freezeDuration or freezeDuration
		freezeTiles = ctx.definition.abilityParams.freezeTiles or freezeTiles
		freezeEntireLane = (ctx.definition.abilityParams.freezeEntireLane or 0) >= 1
	end

	local hitDelay = 0
	if type(ctx.definition.attackHitDelay) == "number" and ctx.definition.attackHitDelay > 0 then
		hitDelay = ctx.definition.attackHitDelay
	end

	callbacks.pulseAttack()
	callbacks.playSound("FreezeTime")

	local plotModel = ctx.plotModel
	local row = ctx.position.row
	local column = ctx.position.column
	local plantModel = ctx.model
	local ownerUserId = ctx.ownerUserId
	local brainrotId = ctx.definition.id

	local animLength = DEFAULT_CAST_FALLBACK
	if callbacks.getAttackLength then
		local length = callbacks.getAttackLength()
		if type(length) == "number" and length > 0 then
			animLength = length
		end
	end
	-- Never despawn before the freeze actually applies.
	local despawnAt = math.max(animLength, hitDelay + 0.05)

	task.delay(hitDelay, function()
		if not plotModel.Parent or not plantModel.Parent then
			return
		end

		local frozen = 0
		if freezeEntireLane then
			frozen = CombatService.applyEntireRowStatus(
				plotModel,
				row,
				"Freeze",
				freezeDuration,
				nil,
				"Ice"
			)
		else
			frozen = CombatService.applyStatusAroundColumn(
				plotModel,
				row,
				column,
				freezeTiles,
				freezeTiles,
				"Freeze",
				freezeDuration,
				nil,
				"Ice"
			)
		end
		if frozen > 0 then
			ProgressService.grantBrainrotXpForUser(
				ownerUserId,
				brainrotId,
				EvolutionConfig.FREEZE_XP * frozen
			)
		end

		task.delay(freezeDuration, function()
			callbacks.playSound("FreezeTimeEnd")
		end)
	end)

	task.delay(despawnAt, function()
		if not plantModel.Parent then
			return
		end
		callbacks.destroySelf()
	end)
end

return FreezeTime
