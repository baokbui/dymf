--!strict
--[[
	EnemyService
	Owns monster spawning, grid movement, per-instance state, and death. All
	monsters share one base behavior pipeline; types are data entries in
	Shared.Monsters with optional ability handlers. Spawning is driven by
	LevelService (M8); set MonsterConfig.DEV_SPAWN.ENABLED for isolated testing.

	Milestone 6–7.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GridConfig = require(ReplicatedStorage.Shared.Config.GridConfig)
local MonsterConfig = require(ReplicatedStorage.Shared.Config.MonsterConfig)
local Monsters = require(ReplicatedStorage.Shared.Monsters)
local Types = require(ReplicatedStorage.Shared.Types)
local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)
local GridUtil = require(ReplicatedStorage.Shared.Utilities.GridUtil)
local ModelUtil = require(ReplicatedStorage.Shared.Utilities.ModelUtil)
local CollisionUtil = require(ReplicatedStorage.Shared.Utilities.CollisionUtil)

local Abilities = require(script.Abilities)
local MonsterAnimation = require(script.MonsterAnimation)
local MonsterBehavior = require(script.MonsterBehavior)
local MonsterDeath = require(script.MonsterDeath)
local MonsterFeedback = require(script.MonsterFeedback)
local MonsterModel = require(script.MonsterModel)
local MonsterStatus = require(script.MonsterStatus)
local CombatService = require(script.Parent.CombatService)
local GridService = require(script.Parent.GridService)
local PlotService = require(script.Parent.PlotService)

local EnemyService = {}
EnemyService.Name = "EnemyService"

local log = Logger.new(EnemyService.Name)

local MONSTERS_FOLDER = "Monsters"

type MonsterRuntime = MonsterBehavior.MonsterRuntime

local monsters: { [string]: MonsterRuntime } = {}
local nextInstanceId = 0

local function monstersFolder(plotModel: Model): Folder
	local folder = plotModel:FindFirstChild(MONSTERS_FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = MONSTERS_FOLDER
		folder.Parent = plotModel
	end
	return folder :: Folder
end

-- Boss stages must never stack two of the same boss (Studio soft-reload can
-- leave a second LevelService/EnemyService tick that also spawns into the plot).
local function plotHasLivingMonsterId(plotModel: Model, monsterId: string): boolean
	local folder = plotModel:FindFirstChild(MONSTERS_FOLDER)
	if not folder then
		return false
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Model")
			and child:GetAttribute("MonsterId") == monsterId
			and child:GetAttribute("Dying") ~= true
		then
			local health = child:GetAttribute("Health")
			if type(health) ~= "number" or health > 0 then
				return true
			end
		end
	end
	return false
end

local houseBreachHandler: ((plotModel: Model, row: number) -> ())?

local function destroyMonster(runtime: MonsterRuntime, silent: boolean?)
	if not silent then
		local ownerUserId = runtime.plotModel:GetAttribute("OwnerUserId")
		if type(ownerUserId) == "number" then
			CombatService.notifyMonsterDeath(
				ownerUserId,
				runtime.instanceId,
				runtime.monsterId,
				runtime.row,
				runtime.column
			)
		end
	end
	monsters[runtime.instanceId] = nil
	MonsterAnimation.unbind(runtime.model)
	MonsterFeedback.cleanup(runtime.model)
	if silent then
		runtime.model:Destroy()
	else
		MonsterDeath.play(runtime.model, runtime.definition.deathStyle)
		task.delay(MonsterDeath.totalLifetime(), function()
			if runtime.model.Parent then
				runtime.model:Destroy()
			end
		end)
	end
end

local function computeBrainrotHits(runtime: MonsterRuntime, brainrotInstanceId: string): number
	local BrainrotService = require(script.Parent.BrainrotService)
	local placement = BrainrotService.getPlacement(brainrotInstanceId)
	if not placement then
		return 1
	end

	local def = placement.definition
	local damagePerHit = def.maxHealth / def.health
	local defaultHits = math.max(1, math.ceil(runtime.definition.damage / damagePerHit))

	local hits = defaultHits
	local ctx = {
		instanceId = runtime.instanceId,
		definition = runtime.definition,
		plotModel = runtime.plotModel,
		row = runtime.row,
		column = runtime.column,
		health = runtime.health,
		maxHealth = runtime.maxHealth,
	}

	for _, handler in Abilities.iterate(runtime.definition) do
		if handler.getBrainrotHits then
			hits = math.max(hits, handler.getBrainrotHits(ctx, runtime.abilityState, defaultHits))
		end
	end

	return math.min(hits, placement.health)
end

local function attackBrainrot(runtime: MonsterRuntime, brainrotInstanceId: string)
	-- Status hooks first so Stun/Poison VFX land while the Brainrot still
	-- exists — a killing chew would otherwise destroy the placement before
	-- `applyStatusToBrainrot` could fire `notifyDizzy` / `notifyPoison`.
	local ctx = {
		instanceId = runtime.instanceId,
		definition = runtime.definition,
		plotModel = runtime.plotModel,
		row = runtime.row,
		column = runtime.column,
		health = runtime.health,
		maxHealth = runtime.maxHealth,
	}
	for _, handler in Abilities.iterate(runtime.definition) do
		if handler.onBrainrotAttacked then
			handler.onBrainrotAttacked(ctx, runtime.abilityState, brainrotInstanceId)
		end
	end

	if runtime.definition.damage > 0 then
		local hits = computeBrainrotHits(runtime, brainrotInstanceId)
		CombatService.damageBrainrot(brainrotInstanceId, hits)
		local ownerUserId = runtime.plotModel:GetAttribute("OwnerUserId")
		if type(ownerUserId) == "number" then
			CombatService.notifyMonsterAttack(ownerUserId, runtime.monsterId)
		end
	end
end

local ARROW_MUZZLE_ATTACHMENTS = { "Middle", "Muzzle", "Top" }
local LEFT_ARM_NAMES = { "LArm", "LeftArm", "Left Arm", "LeftUpperArm" }

local function findArrowMuzzle(model: Model): Vector3?
	local bow = model:FindFirstChild("Bow", true)
	if bow then
		for _, name in ARROW_MUZZLE_ATTACHMENTS do
			local attachment = bow:FindFirstChild(name, true)
			if attachment and attachment:IsA("Attachment") then
				return attachment.WorldPosition
			end
		end
		if bow:IsA("BasePart") then
			return bow.Position
		end
		if bow:IsA("Model") then
			local part = bow.PrimaryPart or bow:FindFirstChildWhichIsA("BasePart", true)
			if part then
				return part.Position
			end
		end
	end
	for _, name in LEFT_ARM_NAMES do
		local arm = model:FindFirstChild(name, true)
		if arm and arm:IsA("BasePart") then
			return arm.Position
		end
	end
	return nil
end

local function shootBrainrot(runtime: MonsterRuntime, brainrotInstanceId: string)
	local hits = computeBrainrotHits(runtime, brainrotInstanceId)
	local ownerUserId = runtime.plotModel:GetAttribute("OwnerUserId")
	if type(ownerUserId) ~= "number" then
		return
	end
	CombatService.launchTowardBrainrot(
		runtime.plotModel,
		runtime.row,
		runtime.column,
		brainrotInstanceId,
		hits,
		ownerUserId,
		{
			kind = "Arrow",
			originWorld = findArrowMuzzle(runtime.model),
		}
	)
	CombatService.notifyMonsterAttack(ownerUserId, runtime.monsterId)
end

local function onHouseBreach(runtime: MonsterRuntime)
	log:info(string.format("%s breached house on %s row %d", runtime.monsterId, runtime.plotModel.Name, runtime.row))
	if houseBreachHandler then
		houseBreachHandler(runtime.plotModel, runtime.row)
	end
	destroyMonster(runtime, true)
end

local function spawnInternal(plotModel: Model, monsterId: string, gridRow: number, spawnColumn: number?): MonsterRuntime?
	local definition = Monsters.get(monsterId)
	if not definition then
		return nil
	end
	if not GridUtil.isInBounds({ row = gridRow, column = 1 }) then
		return nil
	end
	if definition.isBoss and plotHasLivingMonsterId(plotModel, monsterId) then
		return nil
	end

	nextInstanceId += 1
	local instanceId = string.format("Monster_%d", nextInstanceId)
	local column = spawnColumn or (GridConfig.COLUMNS + MonsterConfig.SPAWN_COLUMN_OFFSET)

	-- gridRow is the anchor (lowest) row for multi-lane units; visual
	-- placement centers on the midpoint of the occupied span.
	local centerRow = GridUtil.laneCenterRow(gridRow, definition.laneSpan or 1)
	local worldPos = GridService.getWorldPositionAtColumn(plotModel, centerRow, column)
	if not worldPos then
		return nil
	end

	local model = MonsterModel.create(
		instanceId,
		definition,
		plotModel,
		gridRow,
		worldPos,
		monstersFolder(plotModel)
	)
	MonsterFeedback.applyAura(model, definition.auraColor, definition.auraScale)

	local runtime: MonsterRuntime = {
		instanceId = instanceId,
		monsterId = definition.id,
		definition = definition,
		plotModel = plotModel,
		row = gridRow,
		column = column,
		model = model,
		health = definition.health,
		maxHealth = definition.health,
		attackCooldown = definition.attackInterval,
		isAttacking = false,
		abilityState = {},
		skippedBrainrots = {},
		freezeVisual = nil,
		invulnerableUntil = 0,
		downedUntil = 0,
		preFallCFrame = nil,
		jumpingUntil = 0,
		jumpStartColumn = 0,
		jumpEndColumn = 0,
		jumpPeakHeight = 0,
		jumpDuration = 0,
		burrowingUntil = 0,
		burrowStartColumn = 0,
		burrowEndColumn = 0,
		burrowDepth = 0,
		burrowDuration = 0,
		channelingUntil = 0,
		footSnapOffset = nil,
	}
	for key, value in MonsterStatus.createFields() do
		(runtime :: any)[key] = value
	end

	monsters[instanceId] = runtime
	MonsterBehavior.onSpawn(runtime)
	log:info(string.format("spawned %s on %s row %d", monsterId, plotModel.Name, gridRow))
	return runtime
end

local behaviorCallbacks: MonsterBehavior.BehaviorCallbacks = {
	attackBrainrot = attackBrainrot,
	shootBrainrot = shootBrainrot,
	onHouseBreach = onHouseBreach,
	spawnMinion = function(plotModel, monsterId, row)
		spawnInternal(plotModel, monsterId, row)
	end,
}

-- ===== Public API =====

function EnemyService.spawn(plotModel: Model, monsterId: string, gridRow: number): string?
	local runtime = spawnInternal(plotModel, monsterId, gridRow)
	return if runtime then runtime.instanceId else nil
end

function EnemyService.spawnAt(plotModel: Model, monsterId: string, gridRow: number, column: number): string?
	local runtime = spawnInternal(plotModel, monsterId, gridRow, column)
	return if runtime then runtime.instanceId else nil
end

function EnemyService.getModel(instanceId: string): Model?
	local runtime = monsters[instanceId]
	return if runtime then runtime.model else nil
end

-- Pause walk/attack/transform-sync so a PivotTo tween isn't fought (grave rise).
function EnemyService.suspendLocomotion(instanceId: string, duration: number)
	local runtime = monsters[instanceId]
	if not runtime or duration <= 0 then
		return
	end
	runtime.downedUntil = math.max(runtime.downedUntil, os.clock() + duration)
	MonsterAnimation.setLocomotionPaused(runtime.model, true)
end

function EnemyService.resumeLocomotion(instanceId: string)
	local runtime = monsters[instanceId]
	if not runtime then
		return
	end
	runtime.downedUntil = 0
	MonsterAnimation.setLocomotionPaused(runtime.model, false)
end

function EnemyService.countOnPlot(plotModel: Model): number
	local count = 0
	for _, runtime in monsters do
		if runtime.plotModel == plotModel and runtime.health > 0 then
			count += 1
		end
	end
	return count
end

function EnemyService.setHouseBreachHandler(handler: (plotModel: Model, row: number) -> ())
	houseBreachHandler = handler
end

local function isCombatTarget(runtime: MonsterRuntime): boolean
	return runtime.health > 0 and os.clock() >= runtime.invulnerableUntil
end

local function occupiesRow(runtime: MonsterRuntime, row: number): boolean
	return GridUtil.occupiesLaneRow(runtime.row, runtime.definition.laneSpan or 1, row)
end

function EnemyService.getAllMonstersInRow(plotModel: Model, row: number): { string }
	local result: { string } = {}
	for _, runtime in monsters do
		if runtime.plotModel == plotModel
			and isCombatTarget(runtime)
			and occupiesRow(runtime, row)
			and GridUtil.isOnPlotColumn(runtime.column)
		then
			table.insert(result, runtime.instanceId)
		end
	end
	return result
end

function EnemyService.getFirstMonsterInRow(
	plotModel: Model,
	row: number,
	fromColumn: number,
	rangeTiles: number
): string?
	local fullLine = require(ReplicatedStorage.Shared.Config.BrainrotConfig).FULL_LINE_RANGE
	local bestId: string? = nil
	local bestColumn = math.huge
	for instanceId, runtime in monsters do
		if runtime.plotModel ~= plotModel or not occupiesRow(runtime, row) then
			continue
		end
		if not isCombatTarget(runtime) then
			continue
		end
		if not GridUtil.isColumnInRange(fromColumn, runtime.column, rangeTiles, fullLine) then
			continue
		end
		if runtime.column < bestColumn then
			bestColumn = runtime.column
			bestId = instanceId
		end
	end
	return bestId
end

function EnemyService.getFirstMonsterInMeleeReach(
	plotModel: Model,
	row: number,
	fromColumn: number,
	reachColumns: number
): string?
	local bestId: string? = nil
	local bestColumn = math.huge
	for instanceId, runtime in monsters do
		if runtime.plotModel ~= plotModel or not occupiesRow(runtime, row) then
			continue
		end
		if not isCombatTarget(runtime) then
			continue
		end
		if not GridUtil.isWithinMeleeReach(fromColumn, runtime.column, reachColumns) then
			continue
		end
		if runtime.column < bestColumn then
			bestColumn = runtime.column
			bestId = instanceId
		end
	end
	return bestId
end

function EnemyService.getMonstersInRow(
	plotModel: Model,
	row: number,
	fromColumn: number,
	rangeTiles: number
): { string }
	local fullLine = require(ReplicatedStorage.Shared.Config.BrainrotConfig).FULL_LINE_RANGE
	local result: { string } = {}
	for _, runtime in monsters do
		if runtime.plotModel ~= plotModel or not occupiesRow(runtime, row) then
			continue
		end
		if not isCombatTarget(runtime) then
			continue
		end
		if GridUtil.isColumnInRange(fromColumn, runtime.column, rangeTiles, fullLine) then
			table.insert(result, runtime.instanceId)
		end
	end
	return result
end

function EnemyService.getMonsterColumn(instanceId: string): number?
	local runtime = monsters[instanceId]
	return if runtime then runtime.column else nil
end

function EnemyService.getProjectileWorldY(plotModel: Model, row: number, startColumn: number): number?
	local pos = GridService.getWorldPositionAtColumn(plotModel, row, startColumn)
	if not pos then
		return nil
	end
	return pos.Y + require(ReplicatedStorage.Shared.Config.CombatConfig).PROJECTILE_HEIGHT_OFFSET
end

function EnemyService.setProjectilePosition(
	part: BasePart,
	plotModel: Model,
	row: number,
	column: number,
	worldY: number
)
	local pos = GridService.getWorldPositionAtColumn(plotModel, row, column)
	if not pos then
		return
	end
	part.CFrame = CFrame.new(pos.X, worldY, pos.Z)
end

function EnemyService.damageMonster(instanceId: string, damage: number): boolean
	local runtime = monsters[instanceId]
	if not runtime or runtime.health <= 0 then
		return false
	end
	if os.clock() < runtime.invulnerableUntil then
		return false
	end

	runtime.health = math.max(0, runtime.health - damage)
	MonsterModel.setHealth(runtime.model, runtime.health, runtime.maxHealth)

	local isFatal = runtime.health <= 0
	-- Server-owned Color replicates; client Color flashes are overwritten.
	MonsterFeedback.flashHit(runtime.model, isFatal)

	if isFatal then
		-- Let abilities rescue overkill (Duke Vampire last stand) so a single
		-- big hit can't skip the ≤20% threshold between behavior ticks.
		local ctx = {
			instanceId = runtime.instanceId,
			definition = runtime.definition,
			plotModel = runtime.plotModel,
			row = runtime.row,
			column = runtime.column,
			health = 0,
			maxHealth = runtime.maxHealth,
		}
		local rescueCallbacks: Abilities.AbilityCallbacks = {
			spawnMinion = function() end,
			setInvulnerable = function(duration: number)
				runtime.invulnerableUntil = math.max(runtime.invulnerableUntil, os.clock() + duration)
			end,
			beginFall = function(duration: number)
				runtime.downedUntil = math.max(runtime.downedUntil, os.clock() + duration)
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
			beginBurrow = function() end,
		}
		for _, handler in Abilities.iterate(runtime.definition) do
			if handler.onWouldDie and handler.onWouldDie(ctx, runtime.abilityState, rescueCallbacks) then
				-- Keep a sliver of HP; rise phase heals to lastStandHealPercent.
				runtime.health = math.max(1, math.floor(runtime.maxHealth * 0.01))
				MonsterModel.setHealth(runtime.model, runtime.health, runtime.maxHealth)
				MonsterFeedback.flashHit(runtime.model, false)
				return false
			end
		end

		destroyMonster(runtime)
		return true
	end
	return false
end

function EnemyService.applyStatusToMonster(
	instanceId: string,
	kind: Types.StatusEffectKind,
	duration: number,
	magnitude: number?,
	visual: string?
)
	local runtime = monsters[instanceId]
	if not runtime then
		return
	end
	-- Last-stand / downed bosses (e.g. Duke Vampire) ignore Freeze — the tip
	-- pose owns the body until they rise.
	if (kind == "Freeze" or kind == "Stun") and os.clock() < runtime.downedUntil then
		return
	end
	MonsterStatus.apply(runtime, kind, duration, magnitude)
	if kind == "Freeze" or kind == "Stun" then
		local style = if visual == "Bubble" then "Bubble" else "Ice"
		;(runtime :: any).freezeVisual = style
		if style == "Bubble" then
			MonsterFeedback.setFrozen(runtime.model, false)
			MonsterFeedback.setBubbled(runtime.model, true)
		else
			MonsterFeedback.setBubbled(runtime.model, false)
			MonsterFeedback.setFrozen(runtime.model, true)
		end
	end
	if kind == "Knockback" then
		local centerRow = GridUtil.laneCenterRow(runtime.row, runtime.definition.laneSpan or 1)
		local worldPos = GridService.getWorldPositionAtColumn(runtime.plotModel, centerRow, runtime.column)
		if worldPos then
			ModelUtil.snapFeetToTileTop(runtime.model, worldPos)
			MonsterModel.setColumn(runtime.model, runtime.column)
		end
	end
end

function EnemyService.tickMonsterStatuses(dt: number)
	local now = os.clock()
	for _, runtime in monsters do
		if runtime.health <= 0 then
			continue
		end
		MonsterStatus.tick(runtime, now, function(amount: number)
			EnemyService.damageMonster(runtime.instanceId, amount)
		end)
	end
end

function EnemyService.clearPlot(plotModel: Model)
	CombatService.clearPlot(plotModel)
	local toRemove: { MonsterRuntime } = {}
	for _, runtime in monsters do
		if runtime.plotModel == plotModel then
			table.insert(toRemove, runtime)
		end
	end
	for _, runtime in toRemove do
		destroyMonster(runtime, true)
	end
end

function EnemyService.init()
	CombatService.setMonsterHandlers({
		queryEntireRow = EnemyService.getAllMonstersInRow,
		queryRow = EnemyService.getMonstersInRow,
		queryFirstInRow = EnemyService.getFirstMonsterInRow,
		queryFirstInMeleeReach = EnemyService.getFirstMonsterInMeleeReach,
		getMonsterColumn = EnemyService.getMonsterColumn,
		getProjectileWorldY = EnemyService.getProjectileWorldY,
		setProjectilePosition = EnemyService.setProjectilePosition,
		damage = EnemyService.damageMonster,
		applyStatus = EnemyService.applyStatusToMonster,
		tickStatuses = EnemyService.tickMonsterStatuses,
	})
end

function EnemyService.start()
	if (EnemyService :: any)._started then
		return
	end
	(EnemyService :: any)._started = true

	CollisionUtil.init()

	-- Strip Toolbox Scripts / Tools / Sounds from Assets.Monsters in-place;
	-- keep Motor6D + AnimationController for walk/attack tracks. Humanoid is
	-- kept but neutralized (Shirt/Pants + layered clothing need one to render).
	ModelUtil.sanitizeAllMonsterAssets()

	task.spawn(function()
		while true do
			task.wait(MonsterConfig.BEHAVIOR_TICK)
			MonsterBehavior.tick(monsters, MonsterConfig.BEHAVIOR_TICK, behaviorCallbacks)
		end
	end)

	if MonsterConfig.DEV_SPAWN.ENABLED then
		task.spawn(function()
			while true do
				task.wait(MonsterConfig.DEV_SPAWN.INTERVAL)
				local row = math.random(1, GridConfig.ROWS)
				for _, player in Players:GetPlayers() do
					local plotModel = PlotService.getPlotModel(player)
					if plotModel then
						EnemyService.spawn(plotModel, MonsterConfig.DEV_SPAWN.MONSTER_ID, row)
					end
				end
			end
		end)
		log:info("dev monster spawns enabled")
	end

	log:info("started")
end

return EnemyService
