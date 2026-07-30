--!strict
--[[
	Duke Vampire's last stand: the FIRST time his HP drops to/below
	`lastStandTriggerPercent` of max (or a fatal hit would kill him before
	that), he falls over exactly like a regular monster death (same
	randomized tip-over pose, rig intact) over `lastStandFallDuration`
	seconds, lies on the ground for `lastStandGroundDuration` seconds, then
	rises back up already healed to `lastStandHealPercent` of max HP. He is
	invulnerable for the entire fall + ground + rise sequence so Brainrots
	can't finish him off mid-animation. Never triggers again.

	`onWouldDie` rescues overkill that would skip the threshold check
	between behavior ticks (e.g. Bombardino / stacked DPS).
]]
local DukeVampireFreeze = {}

local DEFAULT_TRIGGER_PERCENT = 20
local DEFAULT_HEAL_TO_PERCENT = 50
-- Matches a regular monster death's tip-over speed (CombatConfig.DEATH_FALL_DURATION).
local DEFAULT_FALL_DURATION = 1.0
local DEFAULT_GROUND_DURATION = 3
local DEFAULT_RISE_DURATION = 0.7
local INVULNERABLE_BUFFER = 0.4 -- extra cushion past the rise so the heal always lands first

local function readParams(definition: any): (number, number, number, number, number)
	local params = definition.abilityParams
	local triggerPercent = if params
		then params.lastStandTriggerPercent or DEFAULT_TRIGGER_PERCENT
		else DEFAULT_TRIGGER_PERCENT
	local healToPercent = if params
		then params.lastStandHealPercent or DEFAULT_HEAL_TO_PERCENT
		else DEFAULT_HEAL_TO_PERCENT
	local fallDuration = if params
		then params.lastStandFallDuration or DEFAULT_FALL_DURATION
		else DEFAULT_FALL_DURATION
	local groundDuration = if params
		then params.lastStandGroundDuration or DEFAULT_GROUND_DURATION
		else DEFAULT_GROUND_DURATION
	local riseDuration = if params
		then params.lastStandRiseDuration or DEFAULT_RISE_DURATION
		else DEFAULT_RISE_DURATION
	return triggerPercent, healToPercent, fallDuration, groundDuration, riseDuration
end

local function beginLastStand(state, callbacks, fallDuration: number, groundDuration: number, riseDuration: number)
	state.lastStandPhase = "falling"
	state.lastStandTimer = fallDuration
	callbacks.setInvulnerable(fallDuration + groundDuration + riseDuration + INVULNERABLE_BUFFER)
	callbacks.beginFall(fallDuration)
end

-- Rescue a fatal hit so last stand isn't skipped by overkill between ticks.
function DukeVampireFreeze.onWouldDie(ctx, state, callbacks): boolean
	if state.lastStandUsed or state.lastStandPhase then
		return false
	end
	local _, _, fallDuration, groundDuration, riseDuration = readParams(ctx.definition)
	beginLastStand(state, callbacks, fallDuration, groundDuration, riseDuration)
	return true
end

function DukeVampireFreeze.onTick(ctx, state, dt: number, callbacks)
	if state.lastStandUsed then
		return
	end

	local triggerPercent, healToPercent, fallDuration, groundDuration, riseDuration = readParams(ctx.definition)

	if not state.lastStandPhase then
		if ctx.health > ctx.maxHealth * (triggerPercent / 100) then
			return
		end
		beginLastStand(state, callbacks, fallDuration, groundDuration, riseDuration)
		return
	end

	if state.lastStandPhase == "falling" then
		state.lastStandTimer -= dt
		if state.lastStandTimer > 0 then
			return
		end
		state.lastStandPhase = "grounded"
		state.lastStandTimer = groundDuration
		callbacks.holdDowned(groundDuration)
		return
	end

	if state.lastStandPhase == "grounded" then
		state.lastStandTimer -= dt
		if state.lastStandTimer > 0 then
			return
		end
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
