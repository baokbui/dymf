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
	pulseAttack: (speed: number?) -> (),
	-- Loaded attack AnimationTrack.Length when animated; nil otherwise.
	getAttackLength: (() -> number?)?,
	playAbility: (abilityId: string) -> (),
	getAbilityLength: (abilityId: string) -> number?,
	playSound: (soundKey: string) -> (),
	-- Pause other exclusive extras until os.clock() + duration.
	lockExclusive: (duration: number) -> (),
	-- Pause the core attack until os.clock() + duration.
	lockCore: (duration: number) -> (),
}

export type EvolutionBuffs = {
	coinHasteUntil: number,
	coinHasteFactor: number,
	attackHasteUntil: number,
	attackHasteFactor: number,
	rangedUntil: number,
	pierceUntil: number,
	shieldHp: number,
	attackCount: number,
	furyTriggered: boolean,
	stoneUntil: number,
	stoneTriggered: boolean,
	shieldUntil: number,
	shieldStunImmune: boolean,
	tenfoldAt: number,
	tenfoldShield: boolean,
	jackpotUntil: number,
	jackpotFactor: number,
	jackpotExtraChance: number,
	reflectUntil: number,
	reflectPercent: number,
	exclusiveUntil: number,
	coreLockUntil: number,
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
	buffs: EvolutionBuffs,
	extraParams: { [string]: number }?,
	health: number,
}

export type AbilityHandler = {
	onPlaced: ((ctx: AbilityContext, callbacks: AbilityCallbacks) -> ())?,
	onRemoved: ((ctx: AbilityContext, callbacks: AbilityCallbacks) -> ())?,
	tryAct: ((ctx: AbilityContext, callbacks: AbilityCallbacks) -> boolean)?,
	-- false = may run with other abilities (Ballerina coin boosts, silent passives).
	exclusive: boolean?,
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
	ClearFogRow = require(script.ClearFogRow),
	BustGrave = require(script.BustGrave),
	CoinHaste = require(script.CoinHaste),
	ShieldPulse = require(script.ShieldPulse),
	RangedRampage = require(script.RangedRampage),
	BubbleBarrage = require(script.BubbleBarrage),
	PierceBrew = require(script.PierceBrew),
	RegenPulse = require(script.RegenPulse),
	DesperateFury = require(script.DesperateFury),
	Stoneheart = require(script.Stoneheart),
	TenfoldGuard = require(script.TenfoldGuard),
	SahurWrath = require(script.SahurWrath),
	Jackpot = require(script.Jackpot),
	PrimalRetaliation = require(script.PrimalRetaliation),
	ShadowRequiem = require(script.ShadowRequiem),
}

function Abilities.defaultBuffs(): EvolutionBuffs
	return {
		coinHasteUntil = 0,
		coinHasteFactor = 1,
		attackHasteUntil = 0,
		attackHasteFactor = 1,
		rangedUntil = 0,
		pierceUntil = 0,
		shieldHp = 0,
		attackCount = 0,
		furyTriggered = false,
		stoneUntil = 0,
		stoneTriggered = false,
		shieldUntil = 0,
		shieldStunImmune = false,
		tenfoldAt = 0,
		tenfoldShield = false,
		jackpotUntil = 0,
		jackpotFactor = 1,
		jackpotExtraChance = 0,
		reflectUntil = 0,
		reflectPercent = 0,
		exclusiveUntil = 0,
		coreLockUntil = 0,
	}
end

function Abilities.get(abilityId: string?): AbilityHandler?
	if not abilityId then
		return nil
	end
	return handlers[abilityId]
end

return Abilities
