--!strict
--[[
	PineappleExpress (Orangutini GOD)
	Lobs one giant pineapple at the furthest monster in the row for
	`damagePercent` of his current pineapple damage, and stuns that monster.
	No crowd or boss gate: any monster in the row is enough. Holds the normal
	throw until the clip ends so the two windups don't overlap.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)

local CombatService = require(script.Parent.Parent.Parent.CombatService)
local MeleeBat = require(script.Parent.MeleeBat)

local PineappleExpress = {}

local DEFAULT_PERCENT = 1200
local DEFAULT_STUN = 1.5

local function columnOf(instanceId: string): number
	local column = CombatService.getMonsterColumn(instanceId)
	if type(column) ~= "number" then
		return -math.huge
	end
	return column
end

local function furthestInRow(ctx): string?
	local bestId: string? = nil
	local bestColumn = -math.huge
	for _, monsterId in CombatService.getMonstersInRow(ctx.plotModel, ctx.position.row, ctx.position.column, ctx.definition.rangeTiles) do
		if not CombatService.isStillInFront(monsterId, ctx.position.column) then
			continue
		end
		local column = columnOf(monsterId)
		if column > bestColumn then
			bestColumn = column
			bestId = monsterId
		end
	end
	return bestId
end

function PineappleExpress.tryAct(ctx, callbacks): boolean
	local targetId = furthestInRow(ctx)
	if not targetId then
		return false
	end

	local params = ctx.extraParams or {}
	local percent = if type(params.damagePercent) == "number" then params.damagePercent else DEFAULT_PERCENT
	local stunDuration = if type(params.stunDuration) == "number" then params.stunDuration else DEFAULT_STUN
	local damage = math.max(1, math.floor(ctx.definition.damage * percent / 100 + 0.5))
	local hitDelay = if type(ctx.definition.attackHitDelay) == "number" then ctx.definition.attackHitDelay else 0
	local model = ctx.model
	local plotModel = ctx.plotModel
	local position = ctx.position
	local rangeTiles = ctx.definition.rangeTiles
	local ownerUserId = ctx.ownerUserId
	local brainrotId = ctx.definition.id
	local instanceId = ctx.instanceId

	local clipLength = if callbacks.getAttackLength then callbacks.getAttackLength() else nil
	callbacks.lockCore(clipLength or ctx.definition.attackInterval)
	callbacks.pulseAttack()

	task.delay(hitDelay, function()
		if not model.Parent then
			return
		end
		CombatService.launchProjectile(plotModel, position, rangeTiles, damage, ownerUserId, {
			kind = "Pineapple",
			soundKey = "PineappleHit",
			sourceBrainrotId = brainrotId,
			sourceInstanceId = instanceId,
			targetInstanceId = targetId,
			pierceGraves = true,
			originWorld = MeleeBat.leftHandWorld(model),
			statusKind = "Stun",
			statusDuration = stunDuration,
			arcHeight = CombatConfig.GIANT_PINEAPPLE_ARC_HEIGHT,
			modelScale = CombatConfig.GIANT_PINEAPPLE_SCALE,
		})
	end)
	return true
end

return PineappleExpress
