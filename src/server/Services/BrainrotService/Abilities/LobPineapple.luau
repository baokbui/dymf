--!strict
--[[
	LobPineapple (Orangutini Ananassini)
	Throws one pineapple down the row. Prefers the monster behind the front
	one and arcs over graves. A lone monster in the row is the target.
	The fruit leaves the left hand after attackHitDelay (the throw frame).

	Claimed params (Evolutions.applyStats):
	- secondServingCooldown: that throw also lobs a second fruit at the next
	  monster behind the usual target (the furthest one, if the row is short).
	- juiceSplashPercent: each fruit also damages the monster it jumped over.
	- overripePercent: a killing hit bursts that tile for this percent of the shot.
]]

local CombatService = require(script.Parent.Parent.Parent.CombatService)
local MeleeBat = require(script.Parent.MeleeBat)

local LobPineapple = {}

-- instanceId -> os.clock() when Second Serving may fire again.
local nextExtraAt: { [string]: number } = {}

local function columnOf(instanceId: string): number
	local column = CombatService.getMonsterColumn(instanceId)
	if type(column) ~= "number" then
		return math.huge
	end
	return column
end

local function targetsInRow(ctx): { string }
	local targets = CombatService.getMonstersInRow(
		ctx.plotModel,
		ctx.position.row,
		ctx.position.column,
		ctx.definition.rangeTiles
	)
	table.sort(targets, function(a, b)
		return columnOf(a) < columnOf(b)
	end)
	return targets
end

-- The monster immediately in front of `targetId` (the one the arc jumps).
local function jumpedOver(targets: { string }, targetId: string): string?
	for index, monsterId in targets do
		if monsterId == targetId then
			return if index > 1 then targets[index - 1] else nil
		end
	end
	return nil
end

local function launchFruit(ctx, targetId: string, targets: { string })
	local params = ctx.definition.abilityParams
	local damage = ctx.definition.damage
	local splashId: string? = nil
	local splashDamage: number? = nil
	local percent = if params then params.juiceSplashPercent else nil
	local over = jumpedOver(targets, targetId)
	if over and type(percent) == "number" and percent > 0 then
		splashId = over
		splashDamage = math.max(1, math.floor(damage * percent / 100 + 0.5))
	end
	local overripePercent = if params then params.overripePercent else nil
	local overripe = if type(overripePercent) == "number" and overripePercent > 0
		then math.max(1, math.floor(damage * overripePercent / 100 + 0.5))
		else nil

	CombatService.launchProjectile(
		ctx.plotModel,
		ctx.position,
		ctx.definition.rangeTiles,
		damage,
		ctx.ownerUserId,
		{
			kind = "Pineapple",
			soundKey = "PineappleHit",
			sourceBrainrotId = ctx.definition.id,
			sourceInstanceId = ctx.instanceId,
			targetInstanceId = targetId,
			pierceGraves = true,
			originWorld = MeleeBat.leftHandWorld(ctx.model),
			splashInstanceId = splashId,
			splashDamage = splashDamage,
			overripeDamage = overripe,
		}
	)
end

function LobPineapple.tryAct(ctx, callbacks): boolean
	local targets = targetsInRow(ctx)
	if #targets == 0 then
		return false
	end
	local targetId = if #targets >= 2 then targets[2] else targets[1]

	callbacks.pulseAttack()

	local hitDelay = ctx.definition.attackHitDelay
	local params = ctx.definition.abilityParams
	local extraCooldown = if params then params.secondServingCooldown else nil
	local instanceId = ctx.instanceId
	local function launch()
		launchFruit(ctx, targetId, targets)
		if type(extraCooldown) ~= "number" or extraCooldown <= 0 then
			return
		end
		if os.clock() < (nextExtraAt[instanceId] or 0) then
			return
		end
		-- Next monster behind the usual target. A short row reuses the furthest one.
		local extraId = if #targets >= 3 then targets[3] else targets[#targets]
		nextExtraAt[instanceId] = os.clock() + extraCooldown
		launchFruit(ctx, extraId, targets)
	end

	if type(hitDelay) == "number" and hitDelay > 0 then
		local model = ctx.model
		task.delay(hitDelay, function()
			if model.Parent then
				launch()
			end
		end)
	else
		launch()
	end
	return true
end

function LobPineapple.onRemoved(ctx)
	nextExtraAt[ctx.instanceId] = nil
end

return LobPineapple
