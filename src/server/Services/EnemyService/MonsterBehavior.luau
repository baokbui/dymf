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
local MonsterDeath = require(script.Parent.MonsterDeath)
local MonsterFeedback = require(script.Parent.MonsterFeedback)
local MonsterModel = require(script.Parent.MonsterModel)
local MonsterStatus = require(script.Parent.MonsterStatus)

local GridService = require(script.Parent.Parent.GridService)
local GridUtil = require(ReplicatedStorage.Shared.Utilities.GridUtil)
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
	invulnerableUntil: number,
	-- "Downed" window (e.g. Duke Vampire's last-stand fall): movement, attack
	-- and grid-transform sync are suspended so a manual tip/rise tween can
	-- play uninterrupted. `preFallCFrame` is the pivot to rise back to.
	downedUntil: number,
	preFallCFrame: CFrame?,
} & MonsterStatus.StatusFields

export type BehaviorCallbacks = {
	attackBrainrot: (runtime: MonsterRuntime, brainrotInstanceId: string) -> (),
	onHouseBreach: (runtime: MonsterRuntime) -> (),
	spawnMinion: (plotModel: Model, monsterId: string, row: number) -> (),
}

local MonsterBehavior = {}

local TILE_HALF = MonsterConfig.TILE_HALF_WIDTH

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
		setInvulnerable = function(duration: number)
			runtime.invulnerableUntil = math.max(runtime.invulnerableUntil, os.clock() + duration)
		end,
		beginFall = function(duration: number)
			runtime.downedUntil = math.max(runtime.downedUntil, os.clock() + duration)
			MonsterAnimation.setLocomotionPaused(runtime.model, true)
			runtime.preFallCFrame = MonsterDeath.playDowned(runtime.model, duration)
		end,
		holdDowned = function(duration: number)
			runtime.downedUntil = math.max(runtime.downedUntil, os.clock() + duration)
		end,
		beginRise = function(duration: number)
			runtime.downedUntil = math.max(runtime.downedUntil, os.clock() + duration)
			if runtime.preFallCFrame then
				MonsterDeath.riseUp(runtime.model, runtime.preFallCFrame, duration)
			end
		end,
	}
end

local function syncTransform(runtime: MonsterRuntime, floatY: number?)
	-- runtime.row is the anchor (lowest) row for multi-lane units; render at
	-- the midpoint of the occupied span so it stays visually centered.
	local centerRow = GridUtil.laneCenterRow(runtime.row, runtime.definition.laneSpan or 1)
	local worldPos = GridService.getWorldPositionAtColumn(runtime.plotModel, centerRow, runtime.column)
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

-- Stop / chew east of the plant center (same tile) — visual standoff gap.
local function meleeStopColumn(brainrotColumn: number): number
	return brainrotColumn + MonsterConfig.MELEE_CLOSE_REACH
end

-- Engaged on the plant tile (any ally — wall, producer, attacker, …).
-- Stops east of center so models don't overlap; Brainrot melee from one tile
-- west still reaches (monster remains on the plant tile).
local function closeEnoughToAttack(monsterColumn: number, brainrotColumn: number): boolean
	return tileAtColumn(monsterColumn) == brainrotColumn
		and monsterColumn >= meleeStopColumn(brainrotColumn)
end

-- All rows a (possibly multi-lane) monster occupies, anchored at runtime.row.
local function occupiedRows(runtime: MonsterRuntime): { number }
	local span = math.max(1, math.floor(runtime.definition.laneSpan or 1))
	local rows = table.create(span)
	for offset = 0, span - 1 do
		table.insert(rows, runtime.row + offset)
	end
	return rows
end

-- First occupied tile at/west of the monster, checking every row it spans
-- (multi-lane units chew whichever lane's Brainrot they reach first).
local function nearestBrainrotWest(runtime: MonsterRuntime): (string?, number?)
	local plotModel = runtime.plotModel
	local rows = occupiedRows(runtime)
	local currentTile = tileAtColumn(runtime.column)

	for _, row in rows do
		local standing = GridService.getTile(plotModel, { row = row, column = currentTile })
		if standing and standing.occupied and standing.brainrotInstanceId then
			return standing.brainrotInstanceId, currentTile
		end
	end

	for col = currentTile - 1, 1, -1 do
		for _, row in rows do
			local tile = GridService.getTile(plotModel, { row = row, column = col })
			if tile and tile.occupied and tile.brainrotInstanceId then
				return tile.brainrotInstanceId, col
			end
		end
	end

	return nil, nil
end

-- Every Brainrot standing on the given column across all rows a (possibly
-- multi-lane) monster occupies — lets wide units cleave every lane at once
-- instead of only ever hitting their anchor row.
local function brainrotsAtColumn(runtime: MonsterRuntime, column: number): { string }
	local plotModel = runtime.plotModel
	local hits: { string } = {}
	for _, row in occupiedRows(runtime) do
		local tile = GridService.getTile(plotModel, { row = row, column = column })
		if tile and tile.occupied and tile.brainrotInstanceId then
			table.insert(hits, tile.brainrotInstanceId)
		end
	end
	return hits
end

-- While chewing, never walk past the standoff stop (keeps Brainrot melee in range).
local function clampToPlantCenter(runtime: MonsterRuntime, brainrotColumn: number)
	local stopAt = meleeStopColumn(brainrotColumn)
	if runtime.column < stopAt then
		runtime.column = stopAt
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
	MonsterModel.setHealth(runtime.model, runtime.health, runtime.maxHealth)
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

		-- Downed (falling/rising): skip movement, attack, and grid-transform
		-- sync entirely so the manual tip/rise tween isn't fought every frame.
		if now < runtime.downedUntil then
			continue
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
			clampToPlantCenter(runtime, brainrotColumn)

			if closeEnoughToAttack(runtime.column, brainrotColumn) then
				setAttacking(runtime, true)

				-- Keep closing to standoff stop while already on the tile (still chewing).
				local stopAt = meleeStopColumn(brainrotColumn)
				if runtime.column > stopAt then
					local speed = runtime.definition.secondsPerGrid
					if speed > 0 then
						local speedMult = MonsterStatus.movementSpeedMultiplier(runtime, now)
						local nextColumn = runtime.column - (dt / speed) * speedMult
						runtime.column = math.max(nextColumn, stopAt)
					end
				end
				syncTransform(runtime)

				runtime.attackCooldown -= dt
				if runtime.attackCooldown <= 0 then
					-- Multi-lane units cleave every occupied row on this tile, not
					-- just the Brainrot that first drew them in (e.g. Goblin Elite
					-- one-shots Brainrots in both of its lanes).
					for _, targetId in brainrotsAtColumn(runtime, brainrotColumn) do
						callbacks.attackBrainrot(runtime, targetId)
					end
					MonsterAnimation.playMelee(runtime.model)
					MonsterFeedback.pulseAttack(runtime.model)
					runtime.attackCooldown = runtime.definition.attackInterval
				end
			else
				setAttacking(runtime, false)
				local speed = runtime.definition.secondsPerGrid
				if speed > 0 then
					local speedMult = MonsterStatus.movementSpeedMultiplier(runtime, now)
					-- Walk onto the plant tile and stop at the standoff column.
					local minColumn = meleeStopColumn(brainrotColumn)
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
