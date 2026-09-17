--!strict
--[[
	Tenfold Guard (Tung Tung Immortal)
	Every N attacks: shield shieldPercent of max HP for duration seconds.
	Stun-immune while that timed shield remains. Returns false so attack
	counting is not blocked by extraCooldowns.
]]

local BrainrotFeedback = require(script.Parent.Parent.BrainrotFeedback)

local TenfoldGuard = {}
TenfoldGuard.exclusive = false

function TenfoldGuard.tryAct(ctx, _callbacks)
	local params = ctx.extraParams
	local every = 10
	local shieldPercent = 30
	local duration = 5
	if type(params) == "table" then
		every = params.every or every
		shieldPercent = params.shieldPercent or shieldPercent
		duration = params.duration or duration
	end
	if every <= 0 or ctx.buffs.attackCount <= 0 then
		return false
	end
	if ctx.buffs.attackCount % every ~= 0 then
		return false
	end
	if ctx.buffs.tenfoldAt == ctx.buffs.attackCount then
		return false
	end

	local maxHealth = ctx.definition.maxHealth
	if type(maxHealth) ~= "number" or maxHealth <= 0 then
		return false
	end

	ctx.buffs.tenfoldAt = ctx.buffs.attackCount
	ctx.buffs.tenfoldShield = true
	ctx.buffs.shieldStunImmune = true
	ctx.buffs.shieldUntil = os.clock() + math.max(0, duration)
	ctx.buffs.shieldHp = math.max(0, maxHealth * shieldPercent / 100)
	if type(params) == "table" and (params.orbitShield or 0) >= 1 then
		ctx.model:SetAttribute("ShieldOrbit", true)
	end

	local hitsRemaining = ctx.model:GetAttribute("HitsRemaining")
	if type(hitsRemaining) == "number" then
		local maxHits = ctx.definition.health
		local body = 0
		if type(maxHits) == "number" and maxHits > 0 then
			body = math.floor(maxHealth * hitsRemaining / maxHits)
		end
		ctx.model:SetAttribute("Health", body)
		ctx.model:SetAttribute("MaxHealth", maxHealth)
		ctx.model:SetAttribute("ShieldHp", math.floor(ctx.buffs.shieldHp))
	end
	BrainrotFeedback.setShield(ctx.model, ctx.buffs.shieldHp > 0)
	return false
end

return TenfoldGuard
