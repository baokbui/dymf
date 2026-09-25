--!strict
--[[
	LobPineapple
	Throws one pineapple down the row. Prefers the monster behind the front
	one and arcs over graves. A lone monster in the row is the target.
	The fruit leaves the left hand after attackHitDelay (the throw frame).
]]

local CombatService = require(script.Parent.Parent.Parent.CombatService)
local MeleeBat = require(script.Parent.MeleeBat)

local LobPineapple = {}

local function columnOf(instanceId: string): number
	local column = CombatService.getMonsterColumn(instanceId)
	if type(column) ~= "number" then
		return math.huge
	end
	return column
end

function LobPineapple.tryAct(ctx, callbacks)
	local targets = CombatService.getMonstersInRow(
		ctx.plotModel,
		ctx.position.row,
		ctx.position.column,
		ctx.definition.rangeTiles
	)
	if #targets == 0 then
		return false
	end
	table.sort(targets, function(a, b)
		return columnOf(a) < columnOf(b)
	end)
	local targetId = if #targets >= 2 then targets[2] else targets[1]

	callbacks.pulseAttack()

	local hitDelay = ctx.definition.attackHitDelay
	local function launch()
		CombatService.launchProjectile(
			ctx.plotModel,
			ctx.position,
			ctx.definition.rangeTiles,
			ctx.definition.damage,
			ctx.ownerUserId,
			{
				kind = "Pineapple",
				soundKey = "PineappleHit",
				sourceBrainrotId = ctx.definition.id,
				sourceInstanceId = ctx.instanceId,
				targetInstanceId = targetId,
				pierceGraves = true,
				originWorld = MeleeBat.leftHandWorld(ctx.model),
			}
		)
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

return LobPineapple
