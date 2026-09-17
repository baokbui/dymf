--!strict
--[[
	ShieldPulse (Banana Bastion)
	Refresh a HP shield (maxHealth units). Chew hits absorb shield first.
]]

local BrainrotFeedback = require(script.Parent.Parent.BrainrotFeedback)

local ShieldPulse = {}
ShieldPulse.exclusive = false

function ShieldPulse.tryAct(ctx, _callbacks)
	local params = ctx.extraParams
	local shield = 500
	if type(params) == "table" then
		shield = params.shield or shield
	end
	-- Banana Bastion replaces a timed Tenfold shield; drop stun-immunity
	-- so Bastion HP is not wiped when Tenfold's 5s timer expires.
	ctx.buffs.tenfoldShield = false
	ctx.buffs.shieldStunImmune = false
	ctx.buffs.shieldUntil = 0
	ctx.buffs.shieldHp = math.max(0, shield)
	ctx.model:SetAttribute("ShieldOrbit", nil)
	local hitsRemaining = ctx.model:GetAttribute("HitsRemaining")
	if type(hitsRemaining) == "number" then
		local maxHits = ctx.definition.health
		local body = 0
		if type(maxHits) == "number" and maxHits > 0 then
			body = math.floor(ctx.definition.maxHealth * hitsRemaining / maxHits)
		end
		local rounded = math.floor(ctx.buffs.shieldHp)
		ctx.model:SetAttribute("Health", body)
		ctx.model:SetAttribute("MaxHealth", ctx.definition.maxHealth)
		ctx.model:SetAttribute("ShieldHp", rounded)
	end
	BrainrotFeedback.setShield(ctx.model, ctx.buffs.shieldHp > 0)
	return true
end

return ShieldPulse
