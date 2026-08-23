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
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local ModelUtil = require(ReplicatedStorage.Shared.Utilities.ModelUtil)
local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)

local Abilities = require(script.Parent.Abilities)
local BrainrotAnimation = require(script.Parent.BrainrotAnimation)
local BrainrotFeedback = require(script.Parent.BrainrotFeedback)
local CoinService = require(script.Parent.Parent.CoinService)
local CombatService = require(script.Parent.Parent.CombatService)

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
}

local BrainrotBehavior = {}

local active: { [string]: RuntimePlacement } = {}
local destroyHandler: ((placement: RuntimePlacement) -> ())?
local detachHandler: ((placement: RuntimePlacement) -> Model?)?

-- "Weaken" (e.g. Duke Vampire's Terrify) scales outgoing damage without
-- mutating the shared registry definition — every ability reads
-- `ctx.definition.damage`, so overriding it once here (via `__index` fallback
-- to the real definition for every other field) applies everywhere for free.
local function effectiveDefinition(placement: RuntimePlacement): Types.BrainrotDefinition
	if os.clock() >= placement.weakenUntil then
		return placement.definition
	end
	local base = placement.definition
	local scaled = setmetatable({ damage = base.damage * (1 - placement.weakenFactor) }, { __index = base })
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
			CoinService.dropRandomCoinForOwner(placement.ownerUserId, amount, origin)
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
		pulseAttack = function()
			-- Authored swing clips replace the old ScaleTo attack pulse.
			if placement.definition.animated then
				BrainrotAnimation.playAttack(placement.model)
			else
				BrainrotFeedback.pulseAttack(placement.model)
			end
		end,
		getAttackLength = function()
			return BrainrotAnimation.getAttackLength(placement.model)
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

function BrainrotBehavior.unregister(placement: RuntimePlacement)
	local handler = Abilities.get(placement.definition.ability)
	if handler and handler.onRemoved then
		handler.onRemoved(buildContext(placement), buildCallbacks(placement))
	end
	active[placement.instanceId] = nil
	BrainrotAnimation.unbind(placement.model)
	BrainrotFeedback.cleanup(placement.model)
end

function BrainrotBehavior.tick(dt: number)
	local now = os.clock()
	for _, placement in active do
		if placement.health <= 0 then
			continue
		end

		local combatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
		if placement.poisonUntil > now and now >= placement.poisonNextTick then
			CombatService.damageBrainrot(placement.instanceId, placement.poisonHitsPerTick)
			placement.poisonNextTick = now + combatConfig.POISON_TICK_INTERVAL
		end
		if placement.burnUntil > now and now >= placement.burnNextTick then
			CombatService.damageBrainrot(placement.instanceId, placement.burnHitsPerTick)
			placement.burnNextTick = now + combatConfig.BURN_TICK_INTERVAL
		end

		-- Clear the purple wash when poison expires (refreshes keep it on via applyStatus).
		if placement.poisonTintActive and placement.poisonUntil <= now then
			placement.poisonTintActive = false
			BrainrotFeedback.setPoisoned(placement.model, false)
		end

		if placement.health <= 0 then
			continue
		end

		if now < placement.frozenUntil then
			continue
		end

		-- Lazy require avoids LevelService ↔ BrainrotService cycle.
		local LevelService = require(script.Parent.Parent.LevelService)
		local owner = Players:GetPlayerByUserId(placement.ownerUserId)
		if not owner or not LevelService.isLevelActive(owner) then
			continue
		end

		local interval = placement.definition.attackInterval
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
