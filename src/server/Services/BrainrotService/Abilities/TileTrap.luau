--!strict
local BattleClock = require(game:GetService("ReplicatedStorage").Shared.Utilities.BattleClock)
--[[
	TileTrap (Boneca Ambalabu)
	Monsters walk through her tile (ignoreMonsterChew). When one is on her
	tile and still in front of her (east of her tile center), she headbutts
	it: `damage` once plus a `stunDuration` stun once per monster. Each
	headbutt spends one `definition.charges` use (saved with the lawn); the
	last one hands off to TileTrapFinale (poof / GOD Last Laugh).
	Legendary God of Thunder (`lightningDamage` / `lightningStunDuration`)
	adds a bolt on that monster. Immortal Rolling Thunder (`chainDamage`, …)
	jumps currents from that bolt to nearby monsters.
	Mythic Rattled (`rattleSlowPercent` / `rattleSlowDuration`) slows each
	headbutted monster after its stun ends.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GridConfig = require(ReplicatedStorage.Shared.Config.GridConfig)
local GridUtil = require(ReplicatedStorage.Shared.Utilities.GridUtil)

local CombatService = require(script.Parent.Parent.Parent.CombatService)
local TileTrapFinale = require(script.Parent.TileTrapFinale)

local TileTrap = {}

local DEFAULT_STUN_SECONDS = 1

-- Placement instanceId -> monsters already headbutted by that plant.
local hitByTrap: { [string]: { [string]: boolean } } = {}

local function hitSetFor(instanceId: string): { [string]: boolean }
	local hit = hitByTrap[instanceId]
	if not hit then
		hit = {}
		hitByTrap[instanceId] = hit
	end
	return hit
end

-- Closest monster on her tile that has not walked past her tile center yet.
local function targetInFront(ctx, hit: { [string]: boolean }): string?
	local column = ctx.position.column
	local bestId: string? = nil
	local bestColumn = math.huge
	for _, monsterId in CombatService.getAllMonstersInRow(ctx.plotModel, ctx.position.row) do
		if hit[monsterId] then
			continue
		end
		local monsterColumn = CombatService.getMonsterColumn(monsterId)
		if type(monsterColumn) ~= "number" then
			continue
		end
		if GridUtil.tileAtColumn(monsterColumn) ~= column or monsterColumn < column then
			continue
		end
		if monsterColumn < bestColumn then
			bestColumn = monsterColumn
			bestId = monsterId
		end
	end
	return bestId
end

-- Lawn monsters within `rangeTiles` (row/column distance) of a point, closest first.
local function monstersNear(ctx, row: number, column: number, rangeTiles: number, excludeId: string): { string }
	local seen: { [string]: boolean } = { [excludeId] = true }
	local found: { { id: string, distance: number } } = {}
	for otherRow = math.max(1, row - rangeTiles), math.min(GridConfig.ROWS, row + rangeTiles) do
		for _, monsterId in CombatService.getAllMonstersInRow(ctx.plotModel, otherRow) do
			if seen[monsterId] then
				continue
			end
			seen[monsterId] = true
			local monsterColumn = CombatService.getMonsterColumn(monsterId)
			if type(monsterColumn) ~= "number" or not GridUtil.isOnPlotColumn(monsterColumn) then
				continue
			end
			local dRow = otherRow - row
			local dColumn = monsterColumn - column
			local distance = math.sqrt(dRow * dRow + dColumn * dColumn)
			if distance <= rangeTiles then
				table.insert(found, { id = monsterId, distance = distance })
			end
		end
	end
	table.sort(found, function(a, b)
		return a.distance < b.distance
	end)
	local ids: { string } = {}
	for _, entry in found do
		table.insert(ids, entry.id)
	end
	return ids
end

-- Immortal Rolling Thunder: currents jump from the struck monster to 3–4 nearby ones.
local function chainCurrents(ctx, params: { [string]: number }, targetColumn: number, targetId: string): { string }
	local damage = params.chainDamage
	if type(damage) ~= "number" or damage <= 0 then
		return {}
	end
	local minTargets = math.max(1, math.floor(params.chainMinTargets or 3))
	local maxTargets = math.max(minTargets, math.floor(params.chainMaxTargets or minTargets))
	local rangeTiles = params.chainRangeTiles or 2
	local nearby = monstersNear(ctx, ctx.position.row, targetColumn, rangeTiles, targetId)
	local count = math.min(#nearby, math.random(minTargets, maxTargets))
	local chained: { string } = {}
	for index = 1, count do
		local monsterId = nearby[index]
		table.insert(chained, monsterId)
		if not CombatService.damageMonster(monsterId, damage, ctx.definition.id) then
			CombatService.notifyHitVisual(ctx.ownerUserId, monsterId, { muteSound = true })
		end
	end
	return chained
end

-- Legendary God of Thunder: a bolt on the headbutted monster (its damage and
-- stun ride with the headbutt), plus Rolling Thunder currents when claimed.
local function strikeLightning(ctx, params: { [string]: number }, targetColumn: number, targetId: string)
	local chained = chainCurrents(ctx, params, targetColumn, targetId)
	CombatService.notifyLightningStrike(ctx.ownerUserId, targetId, chained)
end

function TileTrap.tryAct(ctx, callbacks): boolean
	if type(ctx.charges) == "number" and ctx.charges <= 0 then
		return false
	end
	local hit = hitSetFor(ctx.instanceId)
	local targetId = targetInFront(ctx, hit)
	if not targetId then
		return false
	end

	hit[targetId] = true
	local remaining = callbacks.useCharge()
	local isLast = remaining ~= nil and remaining <= 0
	local params = ctx.definition.abilityParams
	local stunDuration = if params and type(params.stunDuration) == "number"
		then params.stunDuration
		else DEFAULT_STUN_SECONDS
	local rattlePercent = if params and type(params.rattleSlowPercent) == "number" then params.rattleSlowPercent else 0
	local rattleDuration = if params and type(params.rattleSlowDuration) == "number"
		then params.rattleSlowDuration
		else 0
	local lightningDamage = if params and type(params.lightningDamage) == "number" then params.lightningDamage else 0
	local lightningStun = if params and type(params.lightningStunDuration) == "number"
		then params.lightningStunDuration
		else 0
	if lightningDamage > 0 then
		stunDuration = math.max(stunDuration, lightningStun)
	end
	local hitDelay = if type(ctx.definition.attackHitDelay) == "number" then ctx.definition.attackHitDelay else 0
	local model = ctx.model
	local damage = ctx.definition.damage
	local brainrotId = ctx.definition.id
	local ownerUserId = ctx.ownerUserId
	local instanceId = ctx.instanceId

	callbacks.pulseAttack()
	BattleClock.delay(ctx.plotModel, hitDelay, function()
		if not model.Parent then
			return
		end
		local targetColumn = CombatService.getMonsterColumn(targetId) or ctx.position.column
		callbacks.playSound("TileTrap")
		local killed = CombatService.damageMonster(targetId, damage, brainrotId)
		CombatService.noteLandedAttack(instanceId)
		if not killed and lightningDamage > 0 then
			killed = CombatService.damageMonster(targetId, lightningDamage, brainrotId)
		end
		if not killed then
			CombatService.applyStatusToMonster(targetId, "Stun", stunDuration)
			if rattlePercent > 0 and rattleDuration > 0 then
				-- Stun owns movement first; the slow outlasts it by rattleDuration.
				local factor = math.clamp(1 - rattlePercent / 100, 0.05, 1)
				CombatService.applyStatusToMonster(targetId, "Slow", stunDuration + rattleDuration, factor)
			end
			CombatService.notifyHitVisual(ownerUserId, targetId, { muteSound = true })
		end
		if lightningDamage > 0 and params then
			strikeLightning(ctx, params, targetColumn, targetId)
		end
		if isLast then
			TileTrapFinale.run(ctx, callbacks)
		end
	end)
	return true
end

function TileTrap.onRemoved(ctx, _callbacks)
	hitByTrap[ctx.instanceId] = nil
end

return TileTrap
