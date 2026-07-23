--!strict
--[[
	MonsterBehavior
	Grid-based movement and attack tick for all monsters. Ability hooks are
	resolved from definition data — never branches on monster names.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GridConfig = require(ReplicatedStorage.Shared.Config.GridConfig)
local MonsterConfig = require(ReplicatedStorage.Shared.Config.MonsterConfig)
local Types = require(ReplicatedStorage.Shared.Types)

local Abilities = require(script.Parent.Abilities)
local MonsterAnimation = require(script.Parent.MonsterAnimation)
local MonsterFeedback = require(script.Parent.MonsterFeedback)
local MonsterModel = require(script.Parent.MonsterModel)
local MonsterStatus = require(script.Parent.MonsterStatus)

local GridService = require(script.Parent.Parent.GridService)
local ModelUtil = require(ReplicatedStorage.Shared.Utilities.ModelUtil)

export type MonsterRuntime = {
	instanceId: string,
	monsterId: string,
	definition: Types.MonsterDefinition,
	plotModel: Model,
	row: number,
	column: number,
	model: Model,
	health: number,
	maxHealth: number,
	attackCooldown: number,
	isAttacking: boolean,
	abilityState: Abilities.AbilityState,
	skippedBrainrots: { [string]: boolean },
	freezeVisual: string?,
} & MonsterStatus.StatusFields

export type BehaviorCallbacks = {
	attackBrainrot: (runtime: MonsterRuntime, brainrotInstanceId: string) -> (),
	onHouseBreach: (runtime: MonsterRuntime) -> (),
	spawnMinion: (plotModel: Model, monsterId: string, row: number) -> (),
}

local MonsterBehavior = {}

local TILE_HALF = MonsterConfig.TILE_HALF_WIDTH
local OVERSHOOT_EPS = MonsterConfig.MELEE_OVERSHOOT_EPSILON
local CLOSE_REACH = MonsterConfig.MELEE_CLOSE_REACH

local function abilityContext(runtime: MonsterRuntime): Abilities.AbilityContext
	return {
		instanceId = runtime.instanceId,
		definition = runtime.definition,
		plotModel = runtime.plotModel,
		row = runtime.row,
		column = runtime.column,
		health = runtime.health,
		maxHealth = runtime.maxHealth,
	}
end

local function abilityCallbacks(runtime: MonsterRuntime, callbacks: BehaviorCallbacks): Abilities.AbilityCallbacks
	return {
		spawnMinion = function(monsterId: string, row: number)
			callbacks.spawnMinion(runtime.plotModel, monsterId, row)
		end,
	}
end

local function syncTransform(runtime: MonsterRuntime, floatY: number?)
	local worldPos = GridService.getWorldPositionAtColumn(runtime.plotModel, runtime.row, runtime.column)
	if not worldPos then
		return
	end
	-- Preserve facing; snap feet to the lane center (no lateral stagger).
	ModelUtil.snapFeetToTileTop(runtime.model, worldPos, floatY)
	MonsterModel.setColumn(runtime.model, runtime.column)
	MonsterModel.setHealth(runtime.model, runtime.health, runtime.maxHealth)
end

local function tileAtColumn(column: number): number
	return math.floor(column + TILE_HALF)
end

local function brainrotWestEdge(brainrotColumn: number): number
	return brainrotColumn + TILE_HALF
end

-- Closest column a melee monster holds while chewing (just east of the Brainrot).
local function meleeEngageMaxColumn(brainrotColumn: number): number
	return brainrotColumn + TILE_HALF + CLOSE_REACH
end

local function closeEnoughToAttack(monsterColumn: number, brainrotColumn: number): boolean
	local westEdge = brainrotWestEdge(brainrotColumn)
	return monsterColumn > westEdge and monsterColumn <= meleeEngageMaxColumn(brainrotColumn)
end

-- First occupied tile west of the monster on its row (the one it would chew).
local function nearestBrainrotWest(runtime: MonsterRuntime): (string?, number?)
	local plotModel = runtime.plotModel
	local row = runtime.row
	local currentTile = tileAtColumn(runtime.column)

	local standing = GridService.getTile(plotModel, { row = row, column = currentTile })
	if standing and standing.occupied and standing.brainrotInstanceId then
		return standing.brainrotInstanceId, currentTile
	end

	for col = currentTile - 1, 1, -1 do
		local tile = GridService.getTile(plotModel, { row = row, column = col })
		if tile and tile.occupied and tile.brainrotInstanceId then
			return tile.brainrotInstanceId, col
		end
	end

	return nil, nil
end

local function clampOutOfBrainrotTile(runtime: MonsterRuntime, brainrotColumn: number)
	local westEdge = brainrotWestEdge(brainrotColumn)
	if runtime.column <= westEdge then
		runtime.column = westEdge + OVERSHOOT_EPS
	end
end

local function shouldSkipBrainrot(runtime: MonsterRuntime, brainrotInstanceId: string): boolean
	if runtime.skippedBrainrots[brainrotInstanceId] then
		return true
	end
	for _, handler in Abilities.iterate(runtime.definition) do
		if handler.shouldSkipBrainrot then
			local state = runtime.abilityState
			if handler.shouldSkipBrainrot(abilityContext(runtime), state, brainrotInstanceId) then
				runtime.skippedBrainrots[brainrotInstanceId] = true
				return true
			end
		end
	end
	return false
end

local function applyPendingHeal(runtime: MonsterRuntime)
	local pending = runtime.abilityState.pendingHeal
	if not pending or pending <= 0 then
		return
	end
	runtime.health = math.min(runtime.maxHealth, runtime.health + pending)
	runtime.abilityState.pendingHeal = 0
end

function MonsterBehavior.onSpawn(runtime: MonsterRuntime)
	for _, handler in Abilities.iterate(runtime.definition) do
		if handler.onSpawn then
			handler.onSpawn(abilityContext(runtime), runtime.abilityState)
		end
	end
	MonsterAnimation.bind(runtime.model, runtime.definition)
	syncTransform(runtime)
end

local function setAttacking(runtime: MonsterRuntime, attacking: boolean)
	if runtime.isAttacking == attacking then
		return
	end
	runtime.isAttacking = attacking
	MonsterAnimation.setAttacking(runtime.model, attacking)
end

function MonsterBehavior.tick(runtimes: { [string]: MonsterRuntime }, dt: number, callbacks: BehaviorCallbacks)
	local now = os.clock()

	-- East → west so trailing (often faster) units update after leaders and can
	-- overtake in the same tick without appearing stuck behind.
	local ordered: { MonsterRuntime } = {}
	for _, runtime in runtimes do
		table.insert(ordered, runtime)
	end
	table.sort(ordered, function(a, b)
		if a.plotModel ~= b.plotModel then
			return a.plotModel.Name < b.plotModel.Name
		end
		if a.row ~= b.row then
			return a.row < b.row
		end
		return a.column > b.column
	end)

	for _, runtime in ordered do
		if runtime.health <= 0 then
			continue
		end

		applyPendingHeal(runtime)

		for _, handler in Abilities.iterate(runtime.definition) do
			if handler.onTick then
				handler.onTick(abilityContext(runtime), runtime.abilityState, dt, abilityCallbacks(runtime, callbacks))
			end
		end

		if now < runtime.frozenUntil then
			MonsterAnimation.setLocomotionPaused(runtime.model, true)
			if runtime.freezeVisual == "Bubble" then
				local bob = MonsterConfig.BUBBLE_FLOAT_OFFSET
					+ math.sin(now * MonsterConfig.BUBBLE_BOB_SPEED) * MonsterConfig.BUBBLE_BOB_AMPLITUDE
				syncTransform(runtime, bob)
				MonsterFeedback.setBubbled(runtime.model, true)
			else
				MonsterFeedback.setFrozen(runtime.model, true)
				syncTransform(runtime)
			end
			continue
		end

		if runtime.freezeVisual ~= nil then
			runtime.freezeVisual = nil
			MonsterFeedback.setFrozen(runtime.model, false)
			MonsterFeedback.setBubbled(runtime.model, false)
		end
		MonsterAnimation.setLocomotionPaused(runtime.model, false)

		-- Movement / attack never considers other monsters — units phase through
		-- each other and only stop for Brainrots (or the house).
		local brainrotId, brainrotColumn = nearestBrainrotWest(runtime)
		if brainrotId and shouldSkipBrainrot(runtime, brainrotId) then
			brainrotId = nil
			brainrotColumn = nil
		end

		if brainrotId and brainrotColumn then
			clampOutOfBrainrotTile(runtime, brainrotColumn)

			if closeEnoughToAttack(runtime.column, brainrotColumn) then
				setAttacking(runtime, true)
				syncTransform(runtime)

				runtime.attackCooldown -= dt
				if runtime.attackCooldown <= 0 then
					callbacks.attackBrainrot(runtime, brainrotId)
					MonsterAnimation.playMelee(runtime.model)
					MonsterFeedback.pulseAttack(runtime.model)
					runtime.attackCooldown = runtime.definition.attackInterval
				end
			else
				setAttacking(runtime, false)
				local speed = runtime.definition.secondsPerGrid
				if speed > 0 then
					local speedMult = MonsterStatus.movementSpeedMultiplier(runtime, now)
					local minColumn = brainrotWestEdge(brainrotColumn) + OVERSHOOT_EPS
					local nextColumn = runtime.column - (dt / speed) * speedMult
					runtime.column = math.max(nextColumn, minColumn)
				end
				syncTransform(runtime)
			end
		else
			setAttacking(runtime, false)
			local speed = runtime.definition.secondsPerGrid
			if speed > 0 then
				local speedMult = MonsterStatus.movementSpeedMultiplier(runtime, now)
				runtime.column -= (dt / speed) * speedMult
			end
			syncTransform(runtime)

			if runtime.column <= MonsterConfig.HOUSE_BREACH_COLUMN then
				callbacks.onHouseBreach(runtime)
			end
		end
	end
end

return MonsterBehavior
