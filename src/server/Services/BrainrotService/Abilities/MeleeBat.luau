--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotConfig = require(ReplicatedStorage.Shared.Config.BrainrotConfig)
local CombatService = require(script.Parent.Parent.Parent.CombatService)

local MeleeBat = {}

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

	-- Bat SFX on every connecting hit (including kills). Death SFX still fires
	-- from CombatVisual when damage is fatal.
	callbacks.playSound("MeleeBat")
	local killed = CombatService.damageMonster(targetId, ctx.definition.damage)
	if not killed then
		CombatService.notifyHitVisual(ctx.ownerUserId, targetId, { muteSound = true })
	end
	return true
end

return MeleeBat
