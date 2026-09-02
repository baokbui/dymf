--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotConfig = require(ReplicatedStorage.Shared.Config.BrainrotConfig)
local CombatService = require(script.Parent.Parent.Parent.CombatService)

local MeleeBat = {}

local function resolveHitDelay(definition: any): number
	local delay = definition.attackHitDelay
	if type(delay) ~= "number" then
		return 0
	end
	return math.max(0, delay)
end

local function applyHit(ctx, callbacks, targetId: string)
	-- Bat SFX on every connecting hit (including kills). Death SFX still fires
	-- from CombatVisual when damage is fatal.
	callbacks.playSound("MeleeBat")
	local killed = CombatService.damageMonster(targetId, ctx.definition.damage, ctx.definition.id)
	CombatService.noteLandedAttack(ctx.instanceId)
	if not killed then
		CombatService.notifyHitVisual(ctx.ownerUserId, targetId, { muteSound = true })
	end
end

function MeleeBat.tryAct(ctx, callbacks)
	-- Tile-based reach from `rangeTiles` (Tung Tung = 1): own tile + one ahead.
	-- Friendly Brainrots never block — a bat behind Ballerina, Lirili, a wall,
	-- etc. can still hit a monster chewing that unit on the next tile.
	-- Ranged Rampage swaps that for a full-lane projectile for `rangedUntil`.
	local ranged = os.clock() < ctx.buffs.rangedUntil
	local rangeTiles = ctx.definition.rangeTiles
	if ranged then
		rangeTiles = BrainrotConfig.FULL_LINE_RANGE
	elseif rangeTiles <= 0 then
		rangeTiles = BrainrotConfig.MELEE_BAT_REACH_TILES
	end

	local targetId = CombatService.getFirstMonsterInRow(
		ctx.plotModel,
		ctx.position.row,
		ctx.position.column,
		rangeTiles
	)
	if not targetId then
		return false
	end

	-- Start swing anim / pulse immediately; damage waits for attackHitDelay so
	-- the impact frame can line up with the authored clip.
	callbacks.pulseAttack()

	local function strike(foundId: string)
		if ranged then
			CombatService.launchProjectile(
				ctx.plotModel,
				ctx.position,
				BrainrotConfig.FULL_LINE_RANGE,
				ctx.definition.damage,
				ctx.ownerUserId,
				{
					kind = "Knife",
					soundKey = "MeleeBat",
					sourceBrainrotId = ctx.definition.id,
					sourceInstanceId = ctx.instanceId,
				}
			)
			return
		end
		applyHit(ctx, callbacks, foundId)
	end

	local hitDelay = resolveHitDelay(ctx.definition)
	if hitDelay <= 0 then
		strike(targetId)
		return true
	end

	local plotModel = ctx.plotModel
	local row = ctx.position.row
	local column = ctx.position.column
	local model = ctx.model

	task.delay(hitDelay, function()
		if not model.Parent then
			return
		end
		local stillTarget = CombatService.getFirstMonsterInRow(plotModel, row, column, rangeTiles)
		if not stillTarget then
			return
		end
		strike(stillTarget)
	end)

	return true
end

return MeleeBat
