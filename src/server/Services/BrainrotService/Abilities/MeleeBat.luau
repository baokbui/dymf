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
	local killed = CombatService.damageMonster(targetId, ctx.definition.damage)
	if not killed then
		CombatService.notifyHitVisual(ctx.ownerUserId, targetId, { muteSound = true })
	end
end

function MeleeBat.tryAct(ctx, callbacks)
	-- Tile-based reach from `rangeTiles` (Tung Tung = 1): own tile + one ahead.
	-- Friendly Brainrots never block — a bat behind Ballerina, Lirili, a wall,
	-- etc. can still hit a monster chewing that unit on the next tile.
	local rangeTiles = ctx.definition.rangeTiles
	if rangeTiles <= 0 then
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

	local hitDelay = resolveHitDelay(ctx.definition)
	if hitDelay <= 0 then
		applyHit(ctx, callbacks, targetId)
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
		applyHit(ctx, callbacks, stillTarget)
	end)

	return true
end

return MeleeBat
