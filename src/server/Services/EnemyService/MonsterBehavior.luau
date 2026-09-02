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

local function ignoresMonsterChew(brainrotInstanceId: string): boolean
	-- Lazy require avoids EnemyService ↔ BrainrotService init cycles.
	local BrainrotService = require(script.Parent.Parent.BrainrotService)
	local placement = BrainrotService.getPlacement(brainrotInstanceId)
	return placement ~= nil and placement.definition.ignoreMonsterChew == true
end

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
	-- Jump-over arc (e.g. Spider vaulting the first Brainrot). While
	-- `jumpingUntil` is in the future, the tick drives column + floatY along
	-- a parabola from jumpStartColumn → jumpEndColumn instead of walking.
	jumpingUntil: number,
	jumpStartColumn: number,
	jumpEndColumn: number,
	jumpPeakHeight: number,
	jumpDuration: number,
	-- Underground travel (Scorpion). While `burrowingUntil` is in the future,
	-- the tick drives column + negative floatY (sink → slide → rise).
	burrowingUntil: number,
	burrowStartColumn: number,
	burrowEndColumn: number,
	burrowDepth: number,
	burrowDuration: number,
	-- Stationary ability channel (Pharaoh summon/steal): no walk/chew until
	-- the one-shot clip finishes, then resume walk.
	channelingUntil: number,
	-- Rest-pose pivot.Y − visual bottom (stable feet while limbs animate).
	footSnapOffset: number?,
	-- Last Brainrot registry id that damaged this monster (normal-kill XP).
	lastHitBrainrotId: string?,
} & MonsterStatus.StatusFields

export type BehaviorCallbacks = {
	attackBrainrot: (runtime: MonsterRuntime, brainrotInstanceId: string) -> (),
	shootBrainrot: (runtime: MonsterRuntime, brainrotInstanceId: string) -> (),
	onHouseBreach: (runtime: MonsterRuntime) -> (),
	spawnMinion: (plotModel: Model, monsterId: string, row: number) -> (),
}

local MonsterBehavior = {}

local TILE_HALF = MonsterConfig.TILE_HALF_WIDTH

local function resolveAttackHitDelay(definition: Types.MonsterDefinition): number
	local delay = definition.attackHitDelay
	if type(delay) ~= "number" then
		return 0
	end
	return math.max(0, delay)
end

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
			-- Last stand / tip pose owns the body — drop any active freeze.
			runtime.frozenUntil = 0
			runtime.freezeVisual = nil
			MonsterFeedback.setFrozen(runtime.model, false)
			MonsterFeedback.setBubbled(runtime.model, false)
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
		beginBurrow = function(endColumn: number, duration: number, depth: number)
			runtime.burrowDuration = math.max(0.2, duration)
			runtime.burrowDepth = math.max(1, depth)
			runtime.burrowStartColumn = runtime.column
			runtime.burrowEndColumn = endColumn
			runtime.burrowingUntil = os.clock() + runtime.burrowDuration
			runtime.isAttacking = false
			MonsterAnimation.setAttacking(runtime.model, false)
			MonsterAnimation.setLocomotionPaused(runtime.model, true)
		end,
		playAbility = function(abilityId: string)
			MonsterAnimation.playAbility(runtime.model, abilityId)
		end,
		getAbilityLength = function(abilityId: string)
			return MonsterAnimation.getAbilityLength(runtime.model, abilityId)
		end,
		beginChannel = function(duration: number)
			runtime.channelingUntil = math.max(runtime.channelingUntil, os.clock() + math.max(0.05, duration))
			runtime.isAttacking = false
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
	-- Prefer the rest-pose foot cache so procedural / animated limbs don't
	-- rewrite minY every tick (spiders were sinking underground mid-gait).
	ModelUtil.snapFeetToTileTop(runtime.model, worldPos, floatY, runtime.footSnapOffset)
	MonsterModel.setColumn(runtime.model, runtime.column)
	MonsterModel.setHealth(runtime.model, runtime.health, runtime.maxHealth)
end

local function syncTransformUpright(runtime: MonsterRuntime, floatY: number?)
	local centerRow = GridUtil.laneCenterRow(runtime.row, runtime.definition.laneSpan or 1)
	local worldPos = GridService.getWorldPositionAtColumn(runtime.plotModel, centerRow, runtime.column)
	if not worldPos then
		return
	end
	-- Rebuild facing from the definition so burrow never leaves a leftover tilt.
	ModelUtil.pivotToTileTop(
		runtime.model,
		worldPos,
		runtime.definition.modelOrientationDegrees,
		MonsterConfig.MODEL_FACE_DIRECTION,
		floatY
	)
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

-- First occupied chewable tile at/west of the monster, checking every row it
-- spans (multi-lane units chew whichever lane's Brainrot they reach first).
-- Plants with ignoreMonsterChew (e.g. Lirili) are transparent to pathing.
local function nearestBrainrotWest(runtime: MonsterRuntime): (string?, number?)
	local plotModel = runtime.plotModel
	local rows = occupiedRows(runtime)
	local currentTile = tileAtColumn(runtime.column)

	for _, row in rows do
		local standing = GridService.getTile(plotModel, { row = row, column = currentTile })
		if standing and standing.occupied and standing.brainrotInstanceId then
			if not ignoresMonsterChew(standing.brainrotInstanceId) then
				return standing.brainrotInstanceId, currentTile
			end
		end
	end

	for col = currentTile - 1, 1, -1 do
		for _, row in rows do
			local tile = GridService.getTile(plotModel, { row = row, column = col })
			if tile and tile.occupied and tile.brainrotInstanceId then
				if not ignoresMonsterChew(tile.brainrotInstanceId) then
					return tile.brainrotInstanceId, col
				end
			end
		end
	end

	return nil, nil
end

-- Every chewable Brainrot on the given column across all rows a (possibly
-- multi-lane) monster occupies — lets wide units cleave every lane at once
-- instead of only ever hitting their anchor row.
local function brainrotsAtColumn(runtime: MonsterRuntime, column: number): { string }
	local plotModel = runtime.plotModel
	local hits: { string } = {}
	for _, row in occupiedRows(runtime) do
		local tile = GridService.getTile(plotModel, { row = row, column = column })
		if tile and tile.occupied and tile.brainrotInstanceId then
			if not ignoresMonsterChew(tile.brainrotInstanceId) then
				table.insert(hits, tile.brainrotInstanceId)
			end
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
			if handler.shouldSkipBrainrot(abilityContext(runtime), runtime.abilityState, brainrotInstanceId) then
				return true
			end
		end
	end
	return false
end

local function jumpParam(runtime: MonsterRuntime, key: string, fallback: number): number
	local params = runtime.definition.abilityParams
	if params then
		local value = params[key]
		if typeof(value) == "number" then
			return value
		end
	end
	return fallback
end

local function closeEnoughToJump(monsterColumn: number, brainrotColumn: number, triggerReach: number): boolean
	return monsterColumn <= brainrotColumn + triggerReach
end

local function beginJumpOver(runtime: MonsterRuntime, brainrotInstanceId: string, brainrotColumn: number)
	local duration = jumpParam(runtime, "jumpDuration", MonsterConfig.JUMP_DURATION)
	local peak = jumpParam(runtime, "jumpPeakHeight", MonsterConfig.JUMP_PEAK_HEIGHT)
	local landOffset = jumpParam(runtime, "jumpLandOffset", MonsterConfig.JUMP_LAND_OFFSET)

	runtime.jumpDuration = math.max(0.1, duration)
	runtime.jumpPeakHeight = math.max(0.5, peak)
	runtime.jumpStartColumn = runtime.column
	runtime.jumpEndColumn = brainrotColumn - landOffset
	if runtime.jumpEndColumn >= runtime.jumpStartColumn then
		runtime.jumpEndColumn = runtime.jumpStartColumn - landOffset
	end
	runtime.jumpingUntil = os.clock() + runtime.jumpDuration

	runtime.skippedBrainrots[brainrotInstanceId] = true
	runtime.abilityState.jumped = true
	runtime.isAttacking = false
	MonsterAnimation.setAttacking(runtime.model, false)
	MonsterAnimation.setLocomotionPaused(runtime.model, true)
end

local function updateJump(runtime: MonsterRuntime, now: number)
	local duration = runtime.jumpDuration
	if duration <= 0 then
		runtime.jumpingUntil = 0
		return
	end

	local t = 1 - ((runtime.jumpingUntil - now) / duration)
	t = math.clamp(t, 0, 1)
	-- Smoothstep so the leap eases out of and into the march.
	local s = t * t * (3 - 2 * t)
	runtime.column = runtime.jumpStartColumn + (runtime.jumpEndColumn - runtime.jumpStartColumn) * s
	local height = 4 * runtime.jumpPeakHeight * t * (1 - t)
	syncTransform(runtime, height)

	if t >= 1 then
		MonsterAnimation.setLocomotionPaused(runtime.model, false)
	end
end

local function updateBurrow(runtime: MonsterRuntime, now: number)
	local duration = runtime.burrowDuration
	if duration <= 0 then
		runtime.burrowingUntil = 0
		return
	end

	local t = 1 - ((runtime.burrowingUntil - now) / duration)
	t = math.clamp(t, 0, 1)
	local sinkEnd = 0.22
	local riseStart = 0.78
	local depth = runtime.burrowDepth
	local floatY = 0
	if t < sinkEnd then
		floatY = -depth * (t / sinkEnd)
		runtime.column = runtime.burrowStartColumn
	elseif t < riseStart then
		local u = (t - sinkEnd) / (riseStart - sinkEnd)
		local s = u * u * (3 - 2 * u)
		runtime.column = runtime.burrowStartColumn
			+ (runtime.burrowEndColumn - runtime.burrowStartColumn) * s
		floatY = -depth
	else
		runtime.column = runtime.burrowEndColumn
		floatY = -depth * (1 - (t - riseStart) / (1 - riseStart))
	end
	syncTransformUpright(runtime, floatY)

	if t >= 1 then
		MonsterAnimation.setLocomotionPaused(runtime.model, false)
	end
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
	-- Measure feet at rest (procedural gait off) so walk bob doesn't bury the body.
	MonsterAnimation.setLocomotionPaused(runtime.model, true)
	runtime.footSnapOffset = ModelUtil.getPivotToVisualBottom(runtime.model)
	MonsterAnimation.setLocomotionPaused(runtime.model, false)
	syncTransform(runtime)

	if runtime.definition.spawnStyle == "RiseFromGround" then
		local duration = runtime.definition.spawnRiseDuration
		if type(duration) ~= "number" or duration <= 0 then
			duration = MonsterConfig.SPAWN_RISE_DURATION
		end
		runtime.downedUntil = math.max(runtime.downedUntil, os.clock() + duration)
		runtime.invulnerableUntil = math.max(runtime.invulnerableUntil, os.clock() + duration)
		MonsterAnimation.setLocomotionPaused(runtime.model, true)
		MonsterDeath.playRiseFromGround(runtime.model, duration)
	end
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
		-- Freeze does not apply / refresh while downed (see applyStatusToMonster).
		if now < runtime.downedUntil then
			continue
		end

		-- Jump-over arc (Spider): drive column + height along the parabola;
		-- ignore Brainrots/house until the leap lands.
		if now < runtime.jumpingUntil then
			updateJump(runtime, now)
			continue
		end

		if now < runtime.burrowingUntil then
			updateBurrow(runtime, now)
			continue
		end

		if now < runtime.channelingUntil then
			syncTransform(runtime)
			continue
		end
		if runtime.channelingUntil > 0 then
			runtime.channelingUntil = 0
			MonsterAnimation.resumeWalk(runtime.model)
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
		-- each other and only stop for Brainrots (or the house). Jumpers vault
		-- the first plant (once) with a visible arc instead of walking through.
		local brainrotId, brainrotColumn = nearestBrainrotWest(runtime)
		if brainrotId and brainrotColumn and shouldSkipBrainrot(runtime, brainrotId) then
			if not runtime.skippedBrainrots[brainrotId] then
				-- First vaultable plant: approach until jump range, then leap.
				local triggerReach = jumpParam(runtime, "jumpTriggerReach", MonsterConfig.JUMP_TRIGGER_REACH)
				if closeEnoughToJump(runtime.column, brainrotColumn, triggerReach) then
					beginJumpOver(runtime, brainrotId, brainrotColumn)
					updateJump(runtime, now)
					continue
				end
				-- Still east of the plant — walk in, but never chew it.
				setAttacking(runtime, false)
				local speed = runtime.definition.secondsPerGrid
				if speed > 0 then
					local speedMult = MonsterStatus.movementSpeedMultiplier(runtime, now)
					local minColumn = brainrotColumn + triggerReach
					local nextColumn = runtime.column - (dt / speed) * speedMult
					runtime.column = math.max(nextColumn, minColumn)
				end
				syncTransform(runtime)
				continue
			end
			-- Already vaulted this plant — treat it as transparent.
			brainrotId = nil
			brainrotColumn = nil
		end

		if brainrotId and brainrotColumn then
			local rangedTiles = runtime.definition.rangedTiles
			if type(rangedTiles) == "number" and rangedTiles > 0 then
				local stopAt = brainrotColumn + rangedTiles
				if runtime.column > stopAt then
					setAttacking(runtime, false)
					local speed = runtime.definition.secondsPerGrid
					if speed > 0 then
						local speedMult = MonsterStatus.movementSpeedMultiplier(runtime, now)
						local nextColumn = runtime.column - (dt / speed) * speedMult
						runtime.column = math.max(nextColumn, stopAt)
					end
					syncTransform(runtime)
					continue
				end

				setAttacking(runtime, true)
				syncTransform(runtime)
				runtime.attackCooldown -= dt
				if runtime.attackCooldown <= 0 then
					MonsterAnimation.playMelee(runtime.model)
					MonsterFeedback.pulseAttack(runtime.model)
					runtime.attackCooldown = runtime.definition.attackInterval
					local hitDelay = resolveAttackHitDelay(runtime.definition)
					local instanceId = runtime.instanceId
					local targetId = brainrotId
					local fire = function()
						if runtimes[instanceId] ~= runtime or runtime.health <= 0 then
							return
						end
						callbacks.shootBrainrot(runtime, targetId)
					end
					if hitDelay > 0 then
						task.delay(hitDelay, fire)
					else
						fire()
					end
				end
				continue
			end

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
					-- Start swing immediately; optional attackHitDelay defers
					-- chew damage so the impact frame can match the clip.
					MonsterAnimation.playMelee(runtime.model)
					MonsterFeedback.pulseAttack(runtime.model)
					runtime.attackCooldown = runtime.definition.attackInterval

					-- Multi-lane units cleave every occupied row on this tile, not
					-- just the Brainrot that first drew them in (e.g. Goblin Elite
					-- one-shots Brainrots in both of its lanes).
					local targets = brainrotsAtColumn(runtime, brainrotColumn)
					local hitDelay = resolveAttackHitDelay(runtime.definition)
					local instanceId = runtime.instanceId
					local applyHits = function()
						if runtimes[instanceId] ~= runtime or runtime.health <= 0 then
							return
						end
						for _, targetId in targets do
							callbacks.attackBrainrot(runtime, targetId)
						end
					end
					if hitDelay <= 0 then
						applyHits()
					else
						task.delay(hitDelay, applyHits)
					end
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
