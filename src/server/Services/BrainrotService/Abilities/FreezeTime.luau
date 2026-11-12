--!strict
local BattleClock = require(game:GetService("ReplicatedStorage").Shared.Utilities.BattleClock)
--[[
	FreezeTime (Lirili Larila)
	One-shot on place: play attack anim + cast SFX, Freeze 2 tiles ahead
	and 2 tiles behind (plus this tile) for freezeDuration, despawn when
	the cast animation ends, then thaw SFX when the status expires.
	Legendary Winter's Grasp (`abilityParams.freezeEntireLane`) freezes
	the whole row instead. Mythic Permafrost overlays `freezeDuration`.
	Immortal Frostbound Neighbor also freezes one adjacent lawn row
	(`freezeAdjacentLane`): the neighbor with more monsters, ties go to
	the lower row. GOD Glacial Dominion (`freezeEntireLawn`) freezes every
	lawn row, including monsters that have already walked past her, and
	Slow 25% for freezeDuration + lawnSlowDuration (felt after thaw).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EvolutionConfig = require(ReplicatedStorage.Shared.Config.EvolutionConfig)
local GridConfig = require(ReplicatedStorage.Shared.Config.GridConfig)
local CombatService = require(script.Parent.Parent.Parent.CombatService)
local ProgressService = require(script.Parent.Parent.Parent.ProgressService)

local FreezeTime = {}

local DEFAULT_FREEZE_DURATION = 5
local DEFAULT_CAST_FALLBACK = 1.2

function FreezeTime.onPlaced(ctx, callbacks)
	local freezeDuration = DEFAULT_FREEZE_DURATION
	local freezeTiles = 2
	local freezeEntireLane = false
	local freezeAdjacentLane = false
	local freezeEntireLawn = false
	local lawnSlowPercent = 0
	local lawnSlowDuration = 0
	if ctx.definition.abilityParams then
		freezeDuration = ctx.definition.abilityParams.freezeDuration or freezeDuration
		freezeTiles = ctx.definition.abilityParams.freezeTiles or freezeTiles
		freezeEntireLane = (ctx.definition.abilityParams.freezeEntireLane or 0) >= 1
		freezeAdjacentLane = (ctx.definition.abilityParams.freezeAdjacentLane or 0) >= 1
		freezeEntireLawn = (ctx.definition.abilityParams.freezeEntireLawn or 0) >= 1
		lawnSlowPercent = ctx.definition.abilityParams.lawnSlowPercent or lawnSlowPercent
		lawnSlowDuration = ctx.definition.abilityParams.lawnSlowDuration or lawnSlowDuration
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

	BattleClock.delay(ctx.plotModel, hitDelay, function()
		if not plotModel.Parent or not plantModel.Parent then
			return
		end

		local function freezeRow(targetRow: number): number
			if freezeEntireLane or freezeEntireLawn then
				return CombatService.applyEntireRowStatus(
					plotModel,
					targetRow,
					"Freeze",
					freezeDuration,
					nil,
					"Ice",
					column
				)
			end
			return CombatService.applyStatusAroundColumn(
				plotModel,
				targetRow,
				column,
				freezeTiles,
				freezeTiles,
				"Freeze",
				freezeDuration,
				nil,
				"Ice"
			)
		end

		local function applyLawnSlow(targetRow: number)
			if lawnSlowPercent <= 0 or lawnSlowDuration <= 0 then
				return
			end
			local factor = math.clamp(1 - lawnSlowPercent / 100, 0.05, 1)
			-- Freeze owns movement until thaw; Slow lasts through freeze plus
			-- lawnSlowDuration so the 3s is felt after ice breaks.
			CombatService.applyEntireRowStatus(
				plotModel,
				targetRow,
				"Slow",
				freezeDuration + lawnSlowDuration,
				factor,
				nil,
				column
			)
		end

		local function pickAdjacentRow(): number?
			local below = row - 1
			local above = row + 1
			local belowOk = below >= 1
			local aboveOk = above <= GridConfig.ROWS
			if belowOk and aboveOk then
				local nBelow = #CombatService.getAllMonstersInRow(plotModel, below)
				local nAbove = #CombatService.getAllMonstersInRow(plotModel, above)
				if nAbove > nBelow then
					return above
				end
				return below
			end
			if belowOk then
				return below
			end
			if aboveOk then
				return above
			end
			return nil
		end

		local frozen = 0
		if freezeEntireLawn then
			for targetRow = 1, GridConfig.ROWS do
				frozen += freezeRow(targetRow)
				applyLawnSlow(targetRow)
			end
		else
			frozen = freezeRow(row)
			if freezeAdjacentLane then
				local adjacent = pickAdjacentRow()
				if adjacent then
					frozen += freezeRow(adjacent)
				end
			end
		end
		if frozen > 0 then
			ProgressService.grantBrainrotXpForUser(
				ownerUserId,
				brainrotId,
				EvolutionConfig.FREEZE_XP * frozen
			)
		end

		BattleClock.delay(ctx.plotModel, freezeDuration, function()
			callbacks.playSound("FreezeTimeEnd")
		end)
	end)

	BattleClock.delay(ctx.plotModel, despawnAt, function()
		if not plantModel.Parent then
			return
		end
		callbacks.destroySelf()
	end)
end

return FreezeTime
