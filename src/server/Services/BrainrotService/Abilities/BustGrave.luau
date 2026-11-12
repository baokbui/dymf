--!strict
local BattleClock = require(game:GetService("ReplicatedStorage").Shared.Utilities.BattleClock)
--[[
	BustGrave (Brr Brr Patapim)
	Must be planted on a grave. One attack clip contains two smashes (1s
	apart). The clip must finish before the next cycle so the second hit
	is not cut off. Collapsing the grave despawns Patapim.
]]

local BustGrave = {}

local DEFAULT_SMASH_COUNT = 2
local DEFAULT_SMASH_GAP = 1

local function resolveHitDelay(definition: any): number
	local delay = definition.attackHitDelay
	if type(delay) ~= "number" then
		return 0
	end
	return math.max(0, delay)
end

local function smashCount(definition: any): number
	local params = definition.abilityParams
	local count = if params then params.smashCount else nil
	if type(count) ~= "number" then
		return DEFAULT_SMASH_COUNT
	end
	return math.max(1, math.floor(count))
end

local function smashGap(definition: any): number
	local params = definition.abilityParams
	local gap = if params then params.smashGap else nil
	if type(gap) ~= "number" then
		return DEFAULT_SMASH_GAP
	end
	return math.max(0, gap)
end

function BustGrave.onPlaced(ctx)
	local GraveService = require(script.Parent.Parent.Parent.GraveService)
	GraveService.beginBust(ctx.plotModel, ctx.position)
end

function BustGrave.onRemoved(ctx)
	local GraveService = require(script.Parent.Parent.Parent.GraveService)
	GraveService.cancelBust(ctx.plotModel, ctx.position)
end

function BustGrave.tryAct(ctx, callbacks): boolean
	local GraveService = require(script.Parent.Parent.Parent.GraveService)
	if ctx.model:GetAttribute("BustFinishing") == true then
		return false
	end
	if not GraveService.hasGrave(ctx.plotModel, ctx.position) then
		callbacks.destroySelf()
		return false
	end

	callbacks.pulseAttack()

	local firstHit = resolveHitDelay(ctx.definition)
	local hits = smashCount(ctx.definition)
	local gap = smashGap(ctx.definition)
	local plotModel = ctx.plotModel
	local position = ctx.position
	local plantModel = ctx.model

	local function despawnAfterSwing(elapsed: number)
		if plantModel:GetAttribute("BustFinishing") == true then
			return
		end
		plantModel:SetAttribute("BustFinishing", true)

		local remain = gap
		if callbacks.getAttackLength then
			local length = callbacks.getAttackLength()
			if type(length) == "number" and length > 0 then
				remain = math.max(gap, length - elapsed)
			end
		end
		BattleClock.delay(ctx.plotModel, remain, function()
			if plantModel.Parent then
				callbacks.destroySelf()
			end
		end)
	end

	local function smash(elapsed: number)
		if not plantModel.Parent or not plotModel.Parent then
			return
		end
		if plantModel:GetAttribute("BustFinishing") == true then
			return
		end
		local collapsed = GraveService.hitFromPatapim(plotModel, position)
		if collapsed then
			callbacks.playSound("GraveCollapse")
			despawnAfterSwing(elapsed)
		elseif GraveService.hasGrave(plotModel, position) then
			callbacks.playSound("GraveShake")
		end
	end

	for index = 1, hits do
		local at = firstHit + (index - 1) * gap
		if at <= 0 then
			smash(0)
		else
			BattleClock.delay(ctx.plotModel, at, function()
				smash(at)
			end)
		end
	end
	return true
end

return BustGrave
