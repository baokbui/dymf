--!strict
--[[
	Duke Vampire's last stand: the FIRST time his HP drops to/below
	`lastStandTriggerPercent` of max, he plays a brief "downed" fall (like a
	regular monster death-tip, rig intact) for `lastStandFallDuration`
	seconds, then rises back up already healed to `lastStandHealPercent` of
	max HP. He is invulnerable for the entire fall + rise sequence so
	Brainrots can't finish him off mid-animation. Never triggers again.
]]
local DukeVampireFreeze = {}

local DEFAULT_TRIGGER_PERCENT = 20
local DEFAULT_HEAL_TO_PERCENT = 50
local DEFAULT_FALL_DURATION = 1.4
local DEFAULT_RISE_DURATION = 0.7
local INVULNERABLE_BUFFER = 0.4 -- extra cushion past the rise so the heal always lands first

function DukeVampireFreeze.onTick(ctx, state, dt: number, callbacks)
	if state.lastStandUsed then
		return
	end

	local params = ctx.definition.abilityParams
	local triggerPercent = if params
		then params.lastStandTriggerPercent or DEFAULT_TRIGGER_PERCENT
		else DEFAULT_TRIGGER_PERCENT
	local healToPercent = if params
		then params.lastStandHealPercent or DEFAULT_HEAL_TO_PERCENT
		else DEFAULT_HEAL_TO_PERCENT
	local fallDuration = if params
		then params.lastStandFallDuration or DEFAULT_FALL_DURATION
		else DEFAULT_FALL_DURATION
	local riseDuration = if params
		then params.lastStandRiseDuration or DEFAULT_RISE_DURATION
		else DEFAULT_RISE_DURATION

	if not state.lastStandPhase then
		if ctx.health > ctx.maxHealth * (triggerPercent / 100) then
			return
		end
		-- Phase 1: fall over, invulnerable through the whole sequence.
		state.lastStandPhase = "falling"
		state.lastStandTimer = fallDuration
		callbacks.setInvulnerable(fallDuration + riseDuration + INVULNERABLE_BUFFER)
		callbacks.beginFall(fallDuration)
		return
	end

	if state.lastStandPhase == "falling" then
		state.lastStandTimer -= dt
		if state.lastStandTimer > 0 then
			return
		end
		-- Phase 2: rise back up, healed to `healToPercent` of max HP.
		state.lastStandPhase = "rising"
		state.lastStandTimer = riseDuration
		callbacks.beginRise(riseDuration)

		local healTarget = ctx.maxHealth * (healToPercent / 100)
		local healAmount = healTarget - ctx.health
		if healAmount > 0 then
			state.pendingHeal = (state.pendingHeal or 0) + healAmount
		end
		return
	end

	if state.lastStandPhase == "rising" then
		state.lastStandTimer -= dt
		if state.lastStandTimer > 0 then
			return
		end
		state.lastStandPhase = "done"
		state.lastStandUsed = true
	end
end

return DukeVampireFreeze
