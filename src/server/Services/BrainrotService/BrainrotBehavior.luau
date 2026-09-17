--!strict
--[[
	BrainrotBehavior
	Runs the server-side behavior tick for every placed Brainrot. Resolves
	ability handlers from definition data and drives cooldowns — never branches
	on Brainrot names.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotConfig = require(ReplicatedStorage.Shared.Config.BrainrotConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local EvolutionConfig = require(ReplicatedStorage.Shared.Config.EvolutionConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Evolutions = require(ReplicatedStorage.Shared.Evolutions)
local ModelUtil = require(ReplicatedStorage.Shared.Utilities.ModelUtil)
local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)

local Abilities = require(script.Parent.Abilities)
local BrainrotAnimation = require(script.Parent.BrainrotAnimation)
local BrainrotFeedback = require(script.Parent.BrainrotFeedback)
local CoinService = require(script.Parent.Parent.CoinService)
local CombatService = require(script.Parent.Parent.CombatService)
local ProgressService = require(script.Parent.Parent.ProgressService)

local log = Logger.new("BrainrotBehavior")

export type RuntimePlacement = {
	instanceId: string,
	brainrotId: string,
	ownerUserId: number,
	plotModel: Model,
	position: Types.GridPosition,
	model: Model,
	health: number,
	definition: Types.BrainrotDefinition,
	cooldownRemaining: number,
	frozenUntil: number,
	poisonUntil: number,
	poisonHitsPerTick: number,
	poisonNextTick: number,
	poisonTintActive: boolean,
	burnUntil: number,
	burnHitsPerTick: number,
	burnNextTick: number,
	weakenUntil: number,
	weakenFactor: number,
	extraCooldowns: { [string]: number },
	buffs: Abilities.EvolutionBuffs,
}

local BrainrotBehavior = {}

local active: { [string]: RuntimePlacement } = {}
local bubbleHits: { [string]: number } = {}
local destroyHandler: ((placement: RuntimePlacement) -> ())?
local detachHandler: ((placement: RuntimePlacement) -> Model?)?

-- "Weaken" (e.g. Duke Vampire's Terrify) scales outgoing damage without
-- mutating the shared registry definition — every ability reads
-- `ctx.definition.damage`, so overriding it once here (via `__index` fallback
-- to the real definition for every other field) applies everywhere for free.
local function effectiveDefinition(placement: RuntimePlacement): Types.BrainrotDefinition
	local now = os.clock()
	local base = placement.definition
	local damage = base.damage
	local interval = base.attackInterval
	if now < placement.weakenUntil then
		damage = damage * (1 - placement.weakenFactor)
	end
	local coinHaste = 1
	if now < placement.buffs.coinHasteUntil and placement.buffs.coinHasteFactor > 1 then
		coinHaste = math.max(coinHaste, placement.buffs.coinHasteFactor)
	end
	if now < placement.buffs.jackpotUntil and placement.buffs.jackpotFactor > 1 then
		coinHaste = math.max(coinHaste, placement.buffs.jackpotFactor)
	end
	if coinHaste > 1 then
		interval = interval / coinHaste
	end
	if now < placement.buffs.attackHasteUntil and placement.buffs.attackHasteFactor > 1 then
		interval = interval / placement.buffs.attackHasteFactor
	end
	if damage == base.damage and interval == base.attackInterval then
		return base
	end
	local scaled = setmetatable({ damage = damage, attackInterval = interval }, { __index = base })
	return (scaled :: any) :: Types.BrainrotDefinition
end

local function buildContext(placement: RuntimePlacement)
	return {
		instanceId = placement.instanceId,
		definition = effectiveDefinition(placement),
		ownerUserId = placement.ownerUserId,
		plotModel = placement.plotModel,
		model = placement.model,
		position = placement.position,
		row = placement.position.row,
		column = placement.position.column,
		buffs = placement.buffs,
		health = placement.health,
	}
end

local function buildCallbacks(placement: RuntimePlacement): Abilities.AbilityCallbacks
	return {
		dropCoinsOnGrid = function(amount: number)
			-- Spit from above the visible mesh top (not RootPart / pivot).
			local size, center = ModelUtil.getVisualSizeAndCenter(placement.model)
			local origin = Vector3.new(
				center.X,
				center.Y + size.Y * 0.5 + EconomyConfig.PRODUCER_SPIT_ORIGIN_CLEARANCE,
				center.Z
			)
			local function spit(value: number): boolean
				local dropped = CoinService.dropRandomCoinForOwner(placement.ownerUserId, value, origin)
				if dropped then
					ProgressService.grantBrainrotXpForUser(
						placement.ownerUserId,
						placement.definition.id,
						EvolutionConfig.COIN_XP
					)
					local percent = 0
					if placement.definition.abilityParams then
						percent = placement.definition.abilityParams.plantDiscountPercent or 0
					end
					if percent > 0 then
						require(script.Parent).setPlantDiscount(placement.plotModel, percent)
					end
				end
				return dropped
			end
			if not spit(amount) then
				return
			end
			local chance = 0
			if placement.definition.abilityParams then
				chance = placement.definition.abilityParams.extraCoinChance or 0
			end
			if chance > 0 and math.random() * 100 < chance then
				spit(amount)
			end
			if os.clock() < placement.buffs.jackpotUntil then
				local jackpotChance = placement.buffs.jackpotExtraChance
				if jackpotChance > 0 and math.random() * 100 < jackpotChance then
					spit(amount)
				end
			end
		end,
		destroySelf = function()
			if destroyHandler then
				destroyHandler(placement)
			end
		end,
		detachSelf = function()
			if detachHandler then
				return detachHandler(placement)
			end
			return nil
		end,
		freezeSelf = function(duration: number)
			placement.frozenUntil = os.clock() + duration
		end,
		pulseAttack = function(speed: number?)
			-- Authored swing clips replace the old ScaleTo attack pulse.
			if placement.definition.animated then
				BrainrotAnimation.playAttack(placement.model, speed)
			else
				BrainrotFeedback.pulseAttack(placement.model)
			end
		end,
		getAttackLength = function()
			return BrainrotAnimation.getAttackLength(placement.model)
		end,
		playAbility = function(abilityId: string)
			BrainrotAnimation.playAbility(placement.model, abilityId)
		end,
		getAbilityLength = function(abilityId: string)
			return BrainrotAnimation.getAbilityLength(placement.model, abilityId)
		end,
		playSound = function(soundKey: string)
			local player = Players:GetPlayerByUserId(placement.ownerUserId)
			if not player then
				return
			end
			Remotes.getEvent("BrainrotAction"):FireClient(player, {
				action = soundKey,
				instanceId = placement.instanceId,
				brainrotId = placement.brainrotId,
			})
		end,
		lockExclusive = function(duration: number)
			local untilTime = os.clock() + math.max(0, duration)
			if untilTime > placement.buffs.exclusiveUntil then
				placement.buffs.exclusiveUntil = untilTime
			end
		end,
		lockCore = function(duration: number)
			local untilTime = os.clock() + math.max(0, duration)
			if untilTime > placement.buffs.coreLockUntil then
				placement.buffs.coreLockUntil = untilTime
			end
		end,
	}
end

function BrainrotBehavior.setDestroyHandler(handler: (placement: RuntimePlacement) -> ())
	destroyHandler = handler
end

function BrainrotBehavior.setDetachHandler(handler: (placement: RuntimePlacement) -> Model?)
	detachHandler = handler
end

function BrainrotBehavior.register(placement: RuntimePlacement)
	-- cooldownRemaining is initialized by the caller (BrainrotService.createPlacement)
	-- — fresh plants get the full interval, restored/rejoined units get a
	-- jittered one so they don't all fire in lockstep. Don't stomp it here.
	placement.frozenUntil = 0
	placement.poisonUntil = 0
	placement.poisonHitsPerTick = 0
	placement.poisonNextTick = 0
	placement.poisonTintActive = false
	placement.burnUntil = 0
	placement.burnHitsPerTick = 0
	placement.burnNextTick = 0
	placement.weakenUntil = 0
	placement.weakenFactor = 0
	placement.extraCooldowns = {}
	placement.buffs = Abilities.defaultBuffs()
	active[placement.instanceId] = placement
	BrainrotAnimation.bind(placement.model, placement.definition)

	local handler = Abilities.get(placement.definition.ability)
	if handler and handler.onPlaced then
		local onPlaced = handler.onPlaced
		task.defer(function()
			if active[placement.instanceId] ~= placement then
				return
			end
			onPlaced(buildContext(placement), buildCallbacks(placement))
		end)
	end
end

local function isBehaviorAlive(placement: RuntimePlacement): boolean
	if placement.definition.ignoreMonsterChew == true then
		return placement.model.Parent ~= nil
	end
	return placement.health > 0
end

function BrainrotBehavior.unregister(placement: RuntimePlacement)
	local handler = Abilities.get(placement.definition.ability)
	if handler and handler.onRemoved then
		handler.onRemoved(buildContext(placement), buildCallbacks(placement))
	end
	active[placement.instanceId] = nil
	bubbleHits[placement.instanceId] = nil
	BrainrotAnimation.unbind(placement.model)
	BrainrotFeedback.cleanup(placement.model)
end

local function hasClaimedExtra(placement: RuntimePlacement, abilityId: string): boolean
	local player = Players:GetPlayerByUserId(placement.ownerUserId)
	if not player then
		return false
	end
	local extras = Evolutions.claimedExtras(
		placement.brainrotId,
		ProgressService.getClaimedEvolutions(player, placement.brainrotId)
	)
	for _, extra in extras do
		if extra.ability == abilityId then
			return true
		end
	end
	return false
end

-- True when another living plant on the same row has this extra ready and sits
-- further east (closer to incoming monsters). Used so Sahur's Wrath doesn't
-- double-cast; the easternmost ready Tung goes first.
function BrainrotBehavior.hasCloserReadyAlly(instanceId: string, abilityId: string): boolean
	local placement = active[instanceId]
	if not placement then
		return false
	end
	local myColumn = placement.position.column
	for _, other in active do
		if other.instanceId == instanceId then
			continue
		end
		if other.plotModel ~= placement.plotModel then
			continue
		end
		if other.position.row ~= placement.position.row then
			continue
		end
		if other.brainrotId ~= placement.brainrotId then
			continue
		end
		if not isBehaviorAlive(other) then
			continue
		end
		if other.position.column <= myColumn then
			continue
		end
		if os.clock() < other.buffs.stoneUntil then
			continue
		end
		if (other.extraCooldowns[abilityId] or 0) > 0 then
			continue
		end
		if hasClaimedExtra(other, abilityId) then
			return true
		end
	end
	return false
end

local function tickExtras(placement: RuntimePlacement, dt: number)
	local player = Players:GetPlayerByUserId(placement.ownerUserId)
	if not player then
		return
	end
	local extras = Evolutions.claimedExtras(
		placement.brainrotId,
		ProgressService.getClaimedEvolutions(player, placement.brainrotId)
	)
	local stoned = os.clock() < placement.buffs.stoneUntil
	local overlayExtras: { Evolutions.ExtraAbility } = {}
	local exclusiveExtras: { Evolutions.ExtraAbility } = {}
	for _, extra in extras do
		local handler = Abilities.get(extra.ability)
		if handler and handler.exclusive == false then
			table.insert(overlayExtras, extra)
		else
			table.insert(exclusiveExtras, extra)
		end
	end

	local function runExtra(extra: Evolutions.ExtraAbility): boolean
		local remaining = (placement.extraCooldowns[extra.ability] or 0) - dt
		if remaining > 0 then
			placement.extraCooldowns[extra.ability] = remaining
			return false
		end
		if stoned then
			return false
		end
		local handler = Abilities.get(extra.ability)
		if not handler or not handler.tryAct then
			placement.extraCooldowns[extra.ability] = extra.params.cooldown or 10
			return false
		end
		local ctx = buildContext(placement)
		ctx.extraParams = extra.params
		local ok, acted = pcall(handler.tryAct, ctx, buildCallbacks(placement))
		if not ok then
			log:warn("extra ability error", extra.ability, acted)
			placement.extraCooldowns[extra.ability] = extra.params.cooldown or 10
			return false
		end
		if acted then
			placement.extraCooldowns[extra.ability] = extra.params.cooldown or 10
			return true
		end
		return false
	end

	for _, extra in overlayExtras do
		runExtra(extra)
	end

	local exclusiveBusy = os.clock() < placement.buffs.exclusiveUntil
	local exclusiveStarted = false
	-- God rows are last in claimedExtras; run them first so ultimates win the slot.
	for index = #exclusiveExtras, 1, -1 do
		if exclusiveBusy or exclusiveStarted then
			local extra = exclusiveExtras[index]
			local remaining = (placement.extraCooldowns[extra.ability] or 0) - dt
			if remaining > 0 then
				placement.extraCooldowns[extra.ability] = remaining
			end
			continue
		end
		if runExtra(exclusiveExtras[index]) then
			exclusiveStarted = true
			if placement.buffs.exclusiveUntil <= os.clock() then
				placement.buffs.exclusiveUntil = os.clock() + 0.05
			end
		end
	end
end

local function expireTimedBuffs(placement: RuntimePlacement, now: number)
	if placement.buffs.stoneUntil > 0 and now >= placement.buffs.stoneUntil then
		placement.buffs.stoneUntil = 0
		BrainrotFeedback.setStoned(placement.model, false)
		if placement.poisonTintActive and placement.poisonUntil > now then
			BrainrotFeedback.setPoisoned(placement.model, true)
		end
	end
	if placement.buffs.tenfoldShield and placement.buffs.shieldUntil > 0 and now >= placement.buffs.shieldUntil then
		placement.buffs.tenfoldShield = false
		placement.buffs.shieldStunImmune = false
		placement.buffs.shieldUntil = 0
		placement.buffs.shieldHp = 0
		local maxHits = placement.definition.health
		local body = 0
		if maxHits > 0 then
			body = math.floor(placement.definition.maxHealth * placement.health / maxHits)
		end
		placement.model:SetAttribute("Health", body)
		placement.model:SetAttribute("ShieldHp", 0)
		BrainrotFeedback.setShield(placement.model, false)
	end
	if placement.buffs.reflectUntil > 0 and now >= placement.buffs.reflectUntil then
		placement.buffs.reflectUntil = 0
		placement.buffs.reflectPercent = 0
		BrainrotFeedback.setRetaliation(placement.model, false)
	end
end

-- Landed-hit XP jobs (BubbleTrap, MeleeBat): every N connecting hits instead of last-hit.
function BrainrotBehavior.noteLandedAttack(instanceId: string)
	local placement = active[instanceId]
	if not placement then
		return
	end
	local job = EvolutionConfig.hitJob(placement.definition.ability)
	if not job then
		return
	end
	local hits = (bubbleHits[instanceId] or 0) + 1
	bubbleHits[instanceId] = hits
	if hits % job.hits ~= 0 then
		return
	end
	ProgressService.grantBrainrotXpForUser(
		placement.ownerUserId,
		placement.definition.id,
		job.xp
	)
end

function BrainrotBehavior.tick(dt: number)
	local now = os.clock()
	for _, placement in active do
		if not isBehaviorAlive(placement) then
			continue
		end

		local combatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
		local nowStone = now < placement.buffs.stoneUntil
		if not nowStone and placement.poisonUntil > now and now >= placement.poisonNextTick then
			CombatService.damageBrainrot(placement.instanceId, placement.poisonHitsPerTick)
			placement.poisonNextTick = now + combatConfig.POISON_TICK_INTERVAL
		end
		if not nowStone and placement.burnUntil > now and now >= placement.burnNextTick then
			CombatService.damageBrainrot(placement.instanceId, placement.burnHitsPerTick)
			placement.burnNextTick = now + combatConfig.BURN_TICK_INTERVAL
		end

		-- Clear the purple wash when poison expires (refreshes keep it on via applyStatus).
		if placement.poisonTintActive and placement.poisonUntil <= now then
			placement.poisonTintActive = false
			BrainrotFeedback.setPoisoned(placement.model, false)
		end

		if not isBehaviorAlive(placement) then
			continue
		end

		expireTimedBuffs(placement, now)

		-- Lazy require avoids LevelService ↔ BrainrotService cycle.
		local LevelService = require(script.Parent.Parent.LevelService)
		local owner = Players:GetPlayerByUserId(placement.ownerUserId)
		if not owner or not LevelService.isLevelActive(owner) then
			continue
		end

		tickExtras(placement, dt)

		if now < placement.buffs.coreLockUntil then
			continue
		end

		if now < placement.buffs.stoneUntil then
			continue
		end

		if now < placement.frozenUntil then
			continue
		end

		local interval = effectiveDefinition(placement).attackInterval
		if interval <= 0 then
			continue
		end

		placement.cooldownRemaining -= dt
		if placement.cooldownRemaining > 0 then
			continue
		end

		local handler = Abilities.get(placement.definition.ability)
		if not handler or not handler.tryAct then
			placement.cooldownRemaining = interval
			continue
		end

		local ok, acted = pcall(handler.tryAct, buildContext(placement), buildCallbacks(placement))
		if not ok then
			log:warn("ability error", placement.brainrotId, acted)
			placement.cooldownRemaining = interval
			continue
		end

		if acted then
			placement.cooldownRemaining = interval
		end
	end
end

function BrainrotBehavior.start()
	task.spawn(function()
		while true do
			task.wait(BrainrotConfig.BEHAVIOR_TICK)
			local ok, err = pcall(BrainrotBehavior.tick, BrainrotConfig.BEHAVIOR_TICK)
			if not ok then
				log:warn("tick error", err)
			end
		end
	end)
end

return BrainrotBehavior
