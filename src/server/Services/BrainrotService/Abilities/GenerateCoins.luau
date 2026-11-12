--!strict
local BattleClock = require(game:GetService("ReplicatedStorage").Shared.Utilities.BattleClock)
local GenerateCoins = {}

local function resolveSpitDelay(definition: any): number
	local delay = definition.attackHitDelay
	if type(delay) ~= "number" then
		return 0
	end
	return math.max(0, delay)
end

function GenerateCoins.tryAct(ctx, callbacks)
	local amount = ctx.definition.coinGeneration
	if not amount or amount <= 0 then
		return false
	end

	-- Start spit/action anim; optional attackHitDelay can defer the coin drop
	-- so the projectile leaves on the authored frame.
	callbacks.pulseAttack()

	local spitDelay = resolveSpitDelay(ctx.definition)
	if spitDelay <= 0 then
		callbacks.dropCoinsOnGrid(amount)
		return true
	end

	local model = ctx.model
	BattleClock.delay(ctx.plotModel, spitDelay, function()
		if not model.Parent then
			return
		end
		callbacks.dropCoinsOnGrid(amount)
	end)
	return true
end

return GenerateCoins
