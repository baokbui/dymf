--!strict
--[[
	TileTrapFinale
	What Boneca does after her last headbutt, from her claimed params:
	- lastLaughDamage (GOD Last Laugh): mushroom cloud blast on her tile
	  ± lastLaughRadius, then poof.
	- otherwise: poof.
	Not an ability handler; TileTrap calls it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GridConfig = require(ReplicatedStorage.Shared.Config.GridConfig)

local CombatService = require(script.Parent.Parent.Parent.CombatService)

local TileTrapFinale = {}

local function modelCenter(model: Model): Vector3
	local boxCFrame = model:GetBoundingBox()
	return boxCFrame.Position
end

-- Damage on lawn tiles fromColumn..toColumn of her row, shown as one mushroom cloud over them.
local function blastTiles(ctx, fromColumn: number, toColumn: number, damage: number)
	local first = math.max(1, fromColumn)
	local last = math.min(GridConfig.COLUMNS, toColumn)
	for column = first, last do
		CombatService.dealColumnDamage(ctx.plotModel, ctx.position.row, column, damage, ctx.ownerUserId, ctx.definition.id)
	end
	CombatService.fireMushroomExplosion(ctx.ownerUserId, ctx.position.row, first, last)
end

function TileTrapFinale.run(ctx, callbacks)
	local params = ctx.definition.abilityParams or {}
	local center = modelCenter(ctx.model)
	callbacks.destroySelf()
	local damage = params.lastLaughDamage
	if type(damage) == "number" and damage > 0 then
		local radius = math.max(0, math.floor(params.lastLaughRadius or 1))
		local column = ctx.position.column
		blastTiles(ctx, column - radius, column + radius, damage)
	end
	CombatService.notifyPoof(ctx.ownerUserId, center)
end

return TileTrapFinale
