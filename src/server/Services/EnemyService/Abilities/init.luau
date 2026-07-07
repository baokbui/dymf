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
}

export type AbilityHandler = {
	onSpawn: ((ctx: AbilityContext, state: AbilityState) -> ())?,
	onTick: ((ctx: AbilityContext, state: AbilityState, dt: number, callbacks: AbilityCallbacks) -> ())?,
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
