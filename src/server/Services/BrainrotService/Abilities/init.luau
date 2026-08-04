--!strict
--[[
	Brainrot Abilities
	Maps ability ids from Brainrot definitions to handler modules.
]]

local Abilities = {}

export type AbilityCallbacks = {
	dropCoinsOnGrid: (amount: number) -> (),
	destroySelf: () -> (),
	-- Unregisters + frees the tile but keeps the model (LineBomb fly-over).
	detachSelf: () -> Model?,
	freezeSelf: (duration: number) -> (),
	pulseAttack: () -> (),
	playSound: (soundKey: string) -> (),
}

export type AbilityContext = {
	instanceId: string,
	definition: any,
	ownerUserId: number,
	plotModel: Model,
	model: Model,
	position: any,
	row: number,
	column: number,
}

export type AbilityHandler = {
	onPlaced: ((ctx: AbilityContext, callbacks: AbilityCallbacks) -> ())?,
	tryAct: ((ctx: AbilityContext, callbacks: AbilityCallbacks) -> boolean)?,
}

-- Explicit requires so handlers resolve reliably (matches definition.ability ids).
local handlers: { [string]: AbilityHandler } = {
	GenerateCoins = require(script.GenerateCoins),
	MeleeBat = require(script.MeleeBat),
	BubbleTrap = require(script.BubbleTrap),
	LineBomb = require(script.LineBomb),
	FreezeTime = require(script.FreezeTime),
	ThrowKnife = require(script.ThrowKnife),
	Wall = require(script.Wall),
}

function Abilities.get(abilityId: string?): AbilityHandler?
	if not abilityId then
		return nil
	end
	return handlers[abilityId]
end

return Abilities
