--!strict
--[[
	Monster Abilities
	Maps ability ids from Monster definitions to handler modules.
]]

local Abilities = {}

export type AbilityContext = {
	instanceId: string,
	definition: any,
	plotModel: Model,
	row: number,
	column: number,
	health: number,
	maxHealth: number,
}

export type AbilityState = { [string]: any }

export type AbilityCallbacks = {
	spawnMinion: (monsterId: string, row: number) -> (),
	-- Ignore incoming damage for `duration` seconds (e.g. Duke Vampire's
	-- last-stand heal). Does not pause movement/attack — pair with a Freeze
	-- status if a channel-like pause is also wanted.
	setInvulnerable: (duration: number) -> (),
	-- Temporarily "downs" the monster (Duke Vampire's last-stand fall):
	-- suspends movement/attack/transform-sync and tips it over for
	-- `duration` seconds, mirroring the regular death-fall pose.
	beginFall: (duration: number) -> (),
	-- Extends the "downed" (movement/attack suspended) window by `duration`
	-- without playing a new fall tween — used to linger on the ground
	-- between the fall landing and the rise starting (Duke Vampire's
	-- last-stand hold).
	holdDowned: (duration: number) -> (),
	-- Tweens the monster back upright over `duration` seconds. Movement
	-- stays suspended until `duration` elapses.
	beginRise: (duration: number) -> (),
}

export type AbilityHandler = {
	onSpawn: ((ctx: AbilityContext, state: AbilityState) -> ())?,
	onTick: ((ctx: AbilityContext, state: AbilityState, dt: number, callbacks: AbilityCallbacks) -> ())?,
	-- Called when a hit would reduce HP to 0. Return true to cancel death
	-- (e.g. Duke Vampire's once-only last stand). Must leave the monster
	-- alive (caller clamps HP) and kick off any downed sequence via callbacks.
	onWouldDie: ((ctx: AbilityContext, state: AbilityState, callbacks: AbilityCallbacks) -> boolean)?,
	shouldSkipBrainrot: ((ctx: AbilityContext, state: AbilityState, brainrotInstanceId: string) -> boolean)?,
	getBrainrotHits: ((ctx: AbilityContext, state: AbilityState, defaultHits: number) -> number)?,
	onBrainrotAttacked: ((ctx: AbilityContext, state: AbilityState, brainrotInstanceId: string) -> ())?,
}

local handlers: { [string]: AbilityHandler } = {}

for _, child in script:GetChildren() do
	if child:IsA("ModuleScript") then
		handlers[child.Name] = require(child) :: AbilityHandler
	end
end

function Abilities.get(abilityId: string): AbilityHandler?
	return handlers[abilityId]
end

function Abilities.iterate(definition: any): { AbilityHandler }
	local result: { AbilityHandler } = {}
	if not definition.abilities then
		return result
	end
	for _, abilityId in definition.abilities do
		local handler = handlers[abilityId]
		if handler then
			table.insert(result, handler)
		end
	end
	return result
end

return Abilities
