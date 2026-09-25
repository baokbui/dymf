--!strict
--[[
	CombatService
	The ONLY system that modifies health. Owns damage, healing, death routing,
	target acquisition, projectiles, and status effects. Brainrots and monsters
	route all health changes through here.

	Milestone 7.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotConfig = require(ReplicatedStorage.Shared.Config.BrainrotConfig)
local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local GridConfig = require(ReplicatedStorage.Shared.Config.GridConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local GridUtil = require(ReplicatedStorage.Shared.Utilities.GridUtil)
local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)

local Projectile = require(script.Projectile)

local CombatService = {}
CombatService.Name = "CombatService"

local log = Logger.new(CombatService.Name)

local FULL_LINE = BrainrotConfig.FULL_LINE_RANGE

local waveHits: { [string]: { hits: { [string]: boolean }, expires: number } } = {}

local brainrotDamageHandler: ((instanceId: string, hits: number, sourceMonsterId: string?) -> boolean)?
local brainrotHealHandler: ((instanceId: string, hits: number) -> ())?
local brainrotStatusHandler: ((instanceId: string, kind: Types.StatusEffectKind, duration: number, magnitude: number?) -> ())?

type MonsterHandlers = {
	queryEntireRow: (plotModel: Model, row: number) -> { string },
	queryRow: (plotModel: Model, row: number, fromColumn: number, rangeTiles: number) -> { string },
	queryFirstInRow: (plotModel: Model, row: number, fromColumn: number, rangeTiles: number) -> string?,
	queryFirstInMeleeReach: (plotModel: Model, row: number, fromColumn: number, reachColumns: number) -> string?,
	getMonsterColumn: (instanceId: string) -> number?,
	getMonsterLaneSpan: (instanceId: string) -> number,
	getMonsterRegistryId: (instanceId: string) -> string?,
	isBoss: (instanceId: string) -> boolean,
	getProjectileWorldY: (plotModel: Model, row: number, startColumn: number) -> number?,
	setProjectilePosition: (part: BasePart, plotModel: Model, row: number, column: number, worldY: number) -> (),
	damage: (instanceId: string, damage: number, sourceBrainrotId: string?) -> boolean,
	applyStatus: (instanceId: string, kind: Types.StatusEffectKind, duration: number, magnitude: number?, visual: string?) -> (),
	tickStatuses: (dt: number) -> (),
}

local monsterHandlers: MonsterHandlers?

local function graveService()
	return require(script.Parent.GraveService)
end

local function monsterColumnOf(instanceId: string): number?
	if monsterHandlers then
		return monsterHandlers.getMonsterColumn(instanceId)
	end
	return nil
end

function CombatService.getMonsterColumn(instanceId: string): number?
	return monsterColumnOf(instanceId)
end

local function monsterLaneSpanOf(instanceId: string): number
	if monsterHandlers then
		return monsterHandlers.getMonsterLaneSpan(instanceId)
	end
	return 1
end

-- Remaining strength of a Tralalero crowd-control effect (1 = full, 0 = immune).
local function tralaleroCcKeep(laneSpan: number): number
	local extraRows = math.max(0, math.floor(laneSpan) - 1)
	local resist = math.clamp(extraRows * CombatConfig.TRALALERO_CC_RESIST_PER_EXTRA_ROW, 0, 1)
	return 1 - resist
end

-- Scales trap / stun duration, knockback tiles, and slow amount. Nil duration
-- means the monster is immune and the status should not be applied.
local function scaleTralaleroCrowdControl(
	instanceId: string,
	kind: Types.StatusEffectKind,
	duration: number,
	magnitude: number?
): (number?, number?)
	local keep = tralaleroCcKeep(monsterLaneSpanOf(instanceId))
	if keep <= 0 then
		return nil, nil
	end
	if kind == "Knockback" then
		local tiles = (magnitude or CombatConfig.KNOCKBACK_TILES) * keep
		if tiles <= 0 then
			return nil, nil
		end
		return 0, tiles
	end
	local scaledDuration = duration * keep
	if scaledDuration <= 0 then
		return nil, nil
	end
	local scaledMagnitude = magnitude
	if kind == "Slow" and type(magnitude) == "number" then
		local slow = math.clamp(1 - magnitude, 0, 1)
		scaledMagnitude = 1 - slow * keep
	end
	return scaledDuration, scaledMagnitude
end

-- If a grave sits between the shooter and this monster, shake the stone (no HP).
local function absorbGraveBlock(plotModel: Model, row: number, fromColumn: number, targetColumn: number): boolean
	return graveService().absorbLaneHit(plotModel, row, fromColumn, targetColumn)
end

local function isBehindGrave(plotModel: Model, row: number, fromColumn: number, targetColumn: number): boolean
	return graveService().isMonsterBehindGrave(plotModel, row, fromColumn, targetColumn)
end

-- Graves only block status aimed past the stone — not a unit whose body already
-- overlaps the caster's tile (Lirili planted on a multi-lane boss).
local function statusBlockedByGrave(
	plotModel: Model,
	row: number,
	fromColumn: number,
	targetColumn: number,
	laneSpan: number
): boolean
	if GridUtil.columnOverlapsTileBand(targetColumn, laneSpan, fromColumn, fromColumn) then
		return false
	end
	if targetColumn <= fromColumn then
		return false
	end
	return isBehindGrave(plotModel, row, fromColumn, targetColumn)
end

local function fireCombatVisual(ownerUserId: number, payload: { [string]: any })
	local player = Players:GetPlayerByUserId(ownerUserId)
	if not player then
		return
	end
	Remotes.getEvent("CombatVisual"):FireClient(player, payload)
end

function CombatService.setBrainrotDamageHandler(
	handler: (instanceId: string, hits: number, sourceMonsterId: string?) -> boolean
)
	brainrotDamageHandler = handler
end

function CombatService.setBrainrotHealHandler(handler: (instanceId: string, hits: number) -> ())
	brainrotHealHandler = handler
end

function CombatService.setBrainrotStatusHandler(
	handler: (instanceId: string, kind: Types.StatusEffectKind, duration: number, magnitude: number?) -> ()
)
	brainrotStatusHandler = handler
end

function CombatService.setMonsterHandlers(handlers: MonsterHandlers)
	monsterHandlers = handlers
end

function CombatService.damageBrainrot(instanceId: string, hits: number, sourceMonsterInstanceId: string?): boolean
	if brainrotDamageHandler then
		return brainrotDamageHandler(instanceId, hits, sourceMonsterInstanceId)
	end
	return false
end

function CombatService.healBrainrot(instanceId: string, hits: number)
	if hits <= 0 then
		return
	end
	if brainrotHealHandler then
		brainrotHealHandler(instanceId, hits)
	end
end

function CombatService.applyStatusToBrainrot(
	instanceId: string,
	kind: Types.StatusEffectKind,
	duration: number,
	magnitude: number?
)
	if brainrotStatusHandler then
		brainrotStatusHandler(instanceId, kind, duration, magnitude)
	end
end

-- Duke Vampire's Terrify: a visible "scream" pulse centered on him, plus a
-- dizzy icon over each Brainrot it afflicts. No damage — purely feedback for
-- the Weaken + Stun already applied via applyStatusToBrainrot.
function CombatService.notifyTerrifyPulse(ownerUserId: number, instanceId: string)
	fireCombatVisual(ownerUserId, {
		kind = "Terrify",
		instanceId = instanceId,
	})
end

-- Pharaoh steal: sand tornado at the boss, sucking from plant origins.
function CombatService.notifySandTornado(
	ownerUserId: number,
	instanceId: string,
	destination: Vector3,
	origins: { Vector3 }
)
	local originPayload: { { x: number, y: number, z: number } } = {}
	for _, point in origins do
		table.insert(originPayload, { x = point.X, y = point.Y, z = point.Z })
	end
	fireCombatVisual(ownerUserId, {
		kind = "SandTornado",
		instanceId = instanceId,
		destX = destination.X,
		destY = destination.Y,
		destZ = destination.Z,
		origins = originPayload,
	})
end

-- La Vacca: gravity well on her, grit sucked from the pulled monster.
function CombatService.notifyGravityPull(ownerUserId: number, center: Vector3, origins: { Vector3 }?)
	local payload: { [string]: any } = {
		kind = "GravityPull",
		destX = center.X,
		destY = center.Y,
		destZ = center.Z,
	}
	if origins then
		for index, origin in origins do
			local prefix = if index == 1 then "origin" else "origin" .. tostring(index)
			payload[prefix .. "X"] = origin.X
			payload[prefix .. "Y"] = origin.Y
			payload[prefix .. "Z"] = origin.Z
		end
	end
	fireCombatVisual(ownerUserId, payload)
end

function CombatService.notifyInkDrop(ownerUserId: number, from: Vector3, to: Vector3)
	fireCombatVisual(ownerUserId, {
		kind = "InkDrop",
		originX = from.X,
		originY = from.Y,
		originZ = from.Z,
		destX = to.X,
		destY = to.Y,
		destZ = to.Z,
	})
end

function CombatService.notifyDizzy(ownerUserId: number, brainrotInstanceId: string, duration: number)
	fireCombatVisual(ownerUserId, {
		kind = "Dizzy",
		instanceId = brainrotInstanceId,
		duration = duration,
	})
end

-- Purple poison aura over a Brainrot for `duration` seconds (Queen Spider, …).
function CombatService.notifyPoison(ownerUserId: number, brainrotInstanceId: string, duration: number)
	fireCombatVisual(ownerUserId, {
		kind = "Poison",
		instanceId = brainrotInstanceId,
		duration = duration,
	})
end

-- Monster chew / club swing SFX on the owning client (`MonsterAttack_<id>` or
-- generic `MonsterAttack`).
function CombatService.notifyMonsterAttack(ownerUserId: number, monsterId: string)
	fireCombatVisual(ownerUserId, {
		kind = "MonsterAttack",
		monsterId = monsterId,
	})
end

-- Damages the closest monster in range on a row (lowest column = nearest the house).
function CombatService.attackFirstInRow(
	plotModel: Model,
	position: Types.GridPosition,
	rangeTiles: number,
	damage: number,
	ownerUserId: number,
	sourceBrainrotId: string?
): boolean
	local targetId = CombatService.getFirstMonsterInRow(plotModel, position.row, position.column, rangeTiles)
	if not targetId then
		return false
	end
	local targetColumn = monsterColumnOf(targetId)
	if type(targetColumn) == "number" and isBehindGrave(plotModel, position.row, position.column, targetColumn) then
		absorbGraveBlock(plotModel, position.row, position.column, targetColumn)
		return true
	end
	CombatService.damageMonster(targetId, damage, sourceBrainrotId)
	fireCombatVisual(ownerUserId, {
		kind = "Hit",
		instanceId = targetId,
	})
	return true
end

function CombatService.notifyHitVisual(
	ownerUserId: number,
	instanceId: string,
	options: { soundKey: string?, muteSound: boolean? }?
)
	local payload: { [string]: any } = {
		kind = "Hit",
		instanceId = instanceId,
	}
	if options and options.muteSound then
		payload.muteSound = true
	elseif options and options.soundKey then
		payload.soundKey = options.soundKey
	end
	fireCombatVisual(ownerUserId, payload)
end

-- Damages the closest monster within short fractional melee reach on a row.
-- muteSound: when true, CombatVisual still flashes/particles but client skips SFX
-- (caller plays ability audio via BrainrotAction so it isn't behind property replication).
function CombatService.attackFirstInMeleeReach(
	plotModel: Model,
	position: Types.GridPosition,
	reachColumns: number,
	damage: number,
	ownerUserId: number,
	muteSound: boolean?,
	sourceBrainrotId: string?
): boolean
	local targetId = if monsterHandlers
		then monsterHandlers.queryFirstInMeleeReach(plotModel, position.row, position.column, reachColumns)
		else nil
	if not targetId then
		return false
	end
	local targetColumn = monsterColumnOf(targetId)
	if type(targetColumn) == "number" and isBehindGrave(plotModel, position.row, position.column, targetColumn) then
		absorbGraveBlock(plotModel, position.row, position.column, targetColumn)
		return true
	end
	CombatService.damageMonster(targetId, damage, sourceBrainrotId)
	CombatService.notifyHitVisual(ownerUserId, targetId, {
		muteSound = muteSound == true,
		soundKey = if muteSound then nil else "MeleeBat",
	})
	return true
end

-- Damages every monster in range on a row (splash / line effects).
function CombatService.attackInRow(
	plotModel: Model,
	position: Types.GridPosition,
	rangeTiles: number,
	damage: number,
	ownerUserId: number,
	soundKey: string?,
	sourceBrainrotId: string?
): boolean
	local targets = CombatService.getMonstersInRow(plotModel, position.row, position.column, rangeTiles)
	if #targets == 0 then
		return false
	end
	local hitAny = false
	for _, monsterId in targets do
		local targetColumn = monsterColumnOf(monsterId)
		if type(targetColumn) == "number" and isBehindGrave(plotModel, position.row, position.column, targetColumn) then
			absorbGraveBlock(plotModel, position.row, position.column, targetColumn)
			hitAny = true
			continue
		end
		hitAny = true
		CombatService.damageMonster(monsterId, damage, sourceBrainrotId)
		local payload: { [string]: any } = {
			kind = "Hit",
			instanceId = monsterId,
		}
		if soundKey then
			payload.soundKey = soundKey
		end
		fireCombatVisual(ownerUserId, payload)
	end
	return true
end

export type ProjectileLaunchOptions = {
	kind: string?,
	soundKey: string?,
	statusKind: Types.StatusEffectKind?,
	statusDuration: number?,
	statusMagnitude: number?,
	statusVisual: string?,
	-- Spawn at this world point (Skeleton bow / LArm / Tralalero mouth) instead of lane center.
	originWorld: Vector3?,
	sourceBrainrotId: string?,
	sourceInstanceId: string?,
	sourceMonsterId: string?,
	-- Extra monsters east of the first hit.
	pierceCount: number?,
	-- Lob at this monster instead of the closest one in the row.
	targetInstanceId: string?,
	-- Fly through graves; the stone takes no HP. Implied when pierceCount > 0.
	pierceGraves: boolean?,
	-- Keep flying through every remaining monster, then to the last lawn tile.
	pierceAll: boolean?,
	-- Shared id so two Shadow Requiem waves don't double-hit the same monster.
	waveGroupId: string?,
	-- Extra last-tile damage when a SwordWave detonates into the light pillar.
	laneEndBonus: number?,
	-- Plant tile for travel ramp; extra HP per tile past the first.
	waveOriginColumn: number?,
	waveTravelBonus: number?,
	-- Bubble Barrage / Double Bubble extras after the seed splits.
	extraBubbleChance: number?,
}

-- Fires a projectile at the first monster in range; damage (and optional status) apply on impact.
function CombatService.launchProjectile(
	plotModel: Model,
	position: Types.GridPosition,
	rangeTiles: number,
	damage: number,
	ownerUserId: number,
	options: ProjectileLaunchOptions?
): boolean
	if not monsterHandlers then
		return false
	end

	local preferred = if options then options.targetInstanceId else nil
	local targetId = if type(preferred) == "string" and preferred ~= ""
		then preferred
		else CombatService.getFirstMonsterInRow(plotModel, position.row, position.column, rangeTiles)
	if not targetId then
		return false
	end

	local worldY = monsterHandlers.getProjectileWorldY(plotModel, position.row, position.column)
	if not worldY then
		return false
	end
	-- Shurikens cartwheel vertically and fly a little higher than the legacy bolt.
	if options and options.kind == "Shuriken" then
		worldY = worldY
			- CombatConfig.PROJECTILE_HEIGHT_OFFSET
			+ CombatConfig.SHURIKEN_PROJECTILE_HEIGHT_OFFSET
	end

	local targetColumn = monsterHandlers.getMonsterColumn(targetId)
	if not targetColumn then
		return false
	end

	local pierceCount = if options then options.pierceCount else nil
	local pierceGraves = (options and options.pierceGraves == true)
		or (type(pierceCount) == "number" and pierceCount > 0)
	local blockingColumn = if pierceGraves
		then nil
		else graveService().getBlockingColumn(
			plotModel,
			position.row,
			position.column,
			targetColumn
		)
	local targetKind: string? = nil
	local targetInstanceId = targetId
	if blockingColumn then
		targetKind = "Grave"
		targetInstanceId = "Grave"
		targetColumn = blockingColumn
	end

	local impact: Projectile.ImpactSpec? = nil
	if options then
		impact = {
			soundKey = options.soundKey,
			statusKind = if blockingColumn then nil else options.statusKind,
			statusDuration = if blockingColumn then nil else options.statusDuration,
			statusMagnitude = if blockingColumn then nil else options.statusMagnitude,
			statusVisual = if blockingColumn then nil else options.statusVisual,
			sourceBrainrotId = options.sourceBrainrotId,
			sourceInstanceId = options.sourceInstanceId,
			sourceMonsterId = options.sourceMonsterId,
			-- Keep pierce + source on grave-blocked shots so Piercing Brew
			-- still attributes both hits if a stone is the first blocker.
			pierceCount = pierceCount,
			pierceGraves = if pierceGraves then true else nil,
		}
	end

	local startColumn = position.column
	local originWorld = if options then options.originWorld else nil
	local worldZ: number? = nil
	local worldZEnd: number? = nil
	local zLerpColumns: number? = nil
	if originWorld and options then
		local GridService = require(script.Parent.GridService)
		local fromX = GridService.worldXToColumn(plotModel, originWorld.X)
		if type(fromX) == "number" then
			startColumn = fromX
		end
		if options.kind == "Bubble" then
			worldY = originWorld.Y
			local lanePos = GridService.getWorldPositionAtColumn(plotModel, position.row, position.column)
			if lanePos then
				worldZEnd = lanePos.Z
				zLerpColumns = 0.7
			end
		elseif options.kind == "Bat" then
			worldY = originWorld.Y
			worldZ = originWorld.Z
		end
	end

	Projectile.launch(
		{
			plotModel = plotModel,
			row = position.row,
			startColumn = startColumn,
			targetInstanceId = targetInstanceId,
			targetColumn = targetColumn,
			damage = if blockingColumn then 0 else damage,
			ownerUserId = ownerUserId,
			kind = if options then options.kind else nil,
			impact = impact,
			targetKind = targetKind,
			arcHeight = if options and options.kind == "Pineapple" then CombatConfig.PINEAPPLE_ARC_HEIGHT else nil,
			originWorld = originWorld,
			worldZ = worldZ,
			zLerpColumns = zLerpColumns,
			worldZEnd = worldZEnd,
		},
		worldY,
		monsterHandlers.setProjectilePosition
	)
	return true
end

-- One bubble per lawn row for Bubble Barrage: spawn at the plant's mouth and
-- ease Z into that row while flying +X. Empty rows still get a bubble (flies
-- to the east edge and pops).
function CombatService.launchSpreadingBubble(
	plotModel: Model,
	plantColumn: number,
	targetRow: number,
	rangeTiles: number,
	damage: number,
	ownerUserId: number,
	originWorld: Vector3,
	options: ProjectileLaunchOptions?
): boolean
	if not monsterHandlers then
		return false
	end

	local GridService = require(script.Parent.GridService)
	local lanePos = GridService.getWorldPositionAtColumn(plotModel, targetRow, plantColumn)
	if not lanePos then
		return false
	end

	local targetId = CombatService.getFirstMonsterInRow(plotModel, targetRow, plantColumn, rangeTiles)
	local targetColumn = GridConfig.COLUMNS
	local targetKind: string? = "LaneEnd"
	local targetInstanceId = "LaneEnd"
	local impactDamage = 0
	if targetId then
		local live = monsterHandlers.getMonsterColumn(targetId)
		if type(live) == "number" then
			targetColumn = live
			targetKind = nil
			targetInstanceId = targetId
			impactDamage = damage
		end
	end

	local blockingColumn = graveService().getBlockingColumn(
		plotModel,
		targetRow,
		plantColumn,
		targetColumn
	)
	if blockingColumn then
		targetKind = "Grave"
		targetInstanceId = "Grave"
		targetColumn = blockingColumn
		impactDamage = 0
	end

	local skipStatus = targetKind == "LaneEnd" or targetKind == "Grave"
	local impact: Projectile.ImpactSpec? = nil
	if options then
		impact = {
			soundKey = options.soundKey,
			statusKind = if skipStatus then nil else options.statusKind,
			statusDuration = if skipStatus then nil else options.statusDuration,
			statusVisual = if skipStatus then nil else options.statusVisual,
			sourceBrainrotId = options.sourceBrainrotId,
			sourceInstanceId = options.sourceInstanceId,
		}
	end

	local startColumn = plantColumn
	local fromX = GridService.worldXToColumn(plotModel, originWorld.X)
	if type(fromX) == "number" then
		startColumn = fromX
	end

	-- Leave the mouth already slightly fanned so all five aren't stacked on frame 0.
	local spawnZ = originWorld.Z + (lanePos.Z - originWorld.Z) * 0.14
	local spawn = Vector3.new(originWorld.X, originWorld.Y, spawnZ)
	local travel = math.abs(targetColumn - startColumn)
	local zLerp = math.max(CombatConfig.BUBBLE_BARRAGE_Z_LERP_TILES, travel * 0.45)

	Projectile.launch(
		{
			plotModel = plotModel,
			row = targetRow,
			startColumn = startColumn,
			targetInstanceId = targetInstanceId,
			targetColumn = targetColumn,
			damage = impactDamage,
			ownerUserId = ownerUserId,
			kind = "Bubble",
			impact = impact,
			targetKind = targetKind,
			originWorld = spawn,
			zLerpColumns = zLerp,
			worldZEnd = lanePos.Z,
			streak = true,
		},
		spawn.Y,
		monsterHandlers.setProjectilePosition
	)
	return true
end

-- Shadow Requiem sword wave: always flies to the last lawn tile. Damage is
-- applied as the wave's column passes each monster (graves never block),
-- ramped per tile past the first. Origin stays at the blades' midpoint.
-- On arrival the wave detonates a last-tile finale (white pillar + flat bonus).
function CombatService.launchSwordWave(
	plotModel: Model,
	position: Types.GridPosition,
	damage: number,
	ownerUserId: number,
	originWorld: Vector3,
	options: ProjectileLaunchOptions?
): boolean
	if not monsterHandlers then
		return false
	end

	local GridService = require(script.Parent.GridService)
	local startColumn = position.column
	local fromX = GridService.worldXToColumn(plotModel, originWorld.X)
	if type(fromX) == "number" then
		startColumn = fromX
	end

	local lastTile = GridConfig.COLUMNS + CombatConfig.SWORD_WAVE_EAST_EDGE
	local impact: Projectile.ImpactSpec = {
		soundKey = if options then options.soundKey else nil,
		sourceBrainrotId = if options then options.sourceBrainrotId else nil,
		sourceInstanceId = if options then options.sourceInstanceId else nil,
		pierceCount = CombatConfig.SWORD_WAVE_PIERCE_COUNT,
		pierceGraves = true,
		pierceAll = true,
		waveFinale = true,
		waveGroupId = if options then options.waveGroupId else nil,
		laneEndBonus = if options then options.laneEndBonus else nil,
		waveOriginColumn = if options and type(options.waveOriginColumn) == "number"
			then options.waveOriginColumn
			else position.column,
		waveTravelBonus = if options then options.waveTravelBonus else nil,
	}

	Projectile.launch(
		{
			plotModel = plotModel,
			row = position.row,
			startColumn = startColumn,
			targetInstanceId = "LaneEnd",
			targetColumn = lastTile,
			damage = damage,
			ownerUserId = ownerUserId,
			kind = "SwordWave",
			impact = impact,
			targetKind = "LaneEnd",
			originWorld = originWorld,
			worldZ = originWorld.Z,
			columnsPerSecond = CombatConfig.SWORD_WAVE_COLUMNS_PER_SECOND,
		},
		originWorld.Y,
		monsterHandlers.setProjectilePosition
	)
	return true
end

-- One seed bubble from the mouth; on Split it fans into every lawn row.
function CombatService.launchBarrageSeed(
	plotModel: Model,
	plantRow: number,
	plantColumn: number,
	rangeTiles: number,
	damage: number,
	ownerUserId: number,
	originWorld: Vector3,
	options: ProjectileLaunchOptions?
): boolean
	if not monsterHandlers then
		return false
	end

	local GridService = require(script.Parent.GridService)
	local startColumn = plantColumn
	local fromX = GridService.worldXToColumn(plotModel, originWorld.X)
	if type(fromX) == "number" then
		startColumn = fromX
	end

	local splitAt = startColumn + CombatConfig.BUBBLE_BARRAGE_SPLIT_TILES
	local nearbyId = CombatService.getFirstMonsterInRow(plotModel, plantRow, plantColumn, rangeTiles)
	if nearbyId then
		local live = monsterHandlers.getMonsterColumn(nearbyId)
		if type(live) == "number" and live < splitAt then
			splitAt = math.max(startColumn + 0.35, live - 0.25)
		end
	end
	splitAt = math.clamp(splitAt, startColumn + 0.35, GridConfig.COLUMNS)

	local extraChance = if options then (options.extraBubbleChance or 0) else 0
	local impact: Projectile.ImpactSpec = {
		soundKey = if options then options.soundKey else nil,
		statusKind = if options then options.statusKind else nil,
		statusDuration = if options then options.statusDuration else nil,
		statusVisual = if options then options.statusVisual else nil,
		sourceBrainrotId = if options then options.sourceBrainrotId else nil,
		sourceInstanceId = if options then options.sourceInstanceId else nil,
		splitBarrage = {
			rangeTiles = rangeTiles,
			plantColumn = plantColumn,
			extraChance = extraChance,
			worldY = originWorld.Y,
			damage = damage,
		},
	}

	Projectile.launch(
		{
			plotModel = plotModel,
			row = plantRow,
			startColumn = startColumn,
			targetInstanceId = "Split",
			targetColumn = splitAt,
			damage = 0,
			ownerUserId = ownerUserId,
			kind = "Bubble",
			impact = impact,
			targetKind = "Split",
			originWorld = originWorld,
			streak = true,
		},
		originWorld.Y,
		monsterHandlers.setProjectilePosition
	)
	return true
end

-- Westbound shot at a planted Brainrot (Skeleton arrows). `hits` is chew-equivalent.
function CombatService.launchTowardBrainrot(
	plotModel: Model,
	row: number,
	startColumn: number,
	brainrotInstanceId: string,
	hits: number,
	ownerUserId: number,
	options: ProjectileLaunchOptions?
): boolean
	if not monsterHandlers then
		return false
	end

	local worldY = monsterHandlers.getProjectileWorldY(plotModel, row, startColumn)
	if not worldY then
		return false
	end
	if options and options.kind == "Arrow" then
		worldY = worldY
			- CombatConfig.PROJECTILE_HEIGHT_OFFSET
			+ CombatConfig.ARROW_PROJECTILE_HEIGHT_OFFSET
	end

	local worldZ: number? = nil
	local column = startColumn
	if options and options.originWorld then
		worldY = options.originWorld.Y
		worldZ = options.originWorld.Z
		local GridService = require(script.Parent.GridService)
		local fromX = GridService.worldXToColumn(plotModel, options.originWorld.X)
		if fromX then
			column = fromX
		end
	end

	local BrainrotService = require(script.Parent.BrainrotService)
	local placement = BrainrotService.getPlacement(brainrotInstanceId)
	if not placement then
		return false
	end

	Projectile.launch(
		{
			plotModel = plotModel,
			row = row,
			startColumn = column,
			targetInstanceId = brainrotInstanceId,
			targetColumn = placement.position.column,
			damage = hits,
			ownerUserId = ownerUserId,
			kind = if options then options.kind else "Arrow",
			targetKind = "Brainrot",
			columnDirection = -1,
			worldZ = worldZ,
			impact = {
				sourceMonsterId = if options then options.sourceMonsterId else nil,
				soundKey = if options then options.soundKey else nil,
			},
		},
		worldY,
		monsterHandlers.setProjectilePosition
	)
	return true
end

function CombatService.fireWindGust(ownerUserId: number)
	fireCombatVisual(ownerUserId, { kind = "WindGust" })
end

function CombatService.fireRowExplosion(
	ownerUserId: number,
	row: number,
	originColumn: number,
	stagger: number?,
	muteSound: boolean?
)
	fireCombatVisual(ownerUserId, {
		kind = "Explosion",
		row = row,
		entireRow = true,
		column = originColumn,
		stagger = stagger,
		muteSound = muteSound == true,
	})
end

function CombatService.fireTileExplosion(
	ownerUserId: number,
	row: number,
	column: number,
	muteSound: boolean?
)
	fireCombatVisual(ownerUserId, {
		kind = "Explosion",
		row = row,
		column = column,
		muteSound = muteSound == true,
	})
end

function CombatService.fireBatSlam(ownerUserId: number, plotModel: Model, row: number)
	local GridService = require(script.Parent.GridService)
	local hits: { { x: number, y: number, z: number } } = {}
	local seen: { [string]: boolean } = {}
	if row < 1 or row > GridConfig.ROWS then
		return
	end
	for _, monsterId in CombatService.getAllMonstersInRow(plotModel, row) do
		if seen[monsterId] then
			continue
		end
		seen[monsterId] = true
		local column = monsterColumnOf(monsterId)
		if type(column) ~= "number" then
			continue
		end
		local pos = GridService.getWorldPositionAtColumn(plotModel, row, column)
		if pos then
			table.insert(hits, {
				x = pos.X,
				y = pos.Y,
				z = pos.Z,
			})
		end
	end
	if #hits == 0 then
		return
	end
	fireCombatVisual(ownerUserId, {
		kind = "BatSlam",
		hits = hits,
	})
end

function CombatService.fireJackpot(ownerUserId: number, position: Vector3)
	fireCombatVisual(ownerUserId, {
		kind = "Jackpot",
		x = position.X,
		y = position.Y,
		z = position.Z,
	})
end

function CombatService.dealColumnDamage(
	plotModel: Model,
	row: number,
	column: number,
	damage: number,
	ownerUserId: number,
	sourceBrainrotId: string?
)
	local targets = CombatService.getAllMonstersInRow(plotModel, row)
	for _, monsterId in targets do
		local monsterColumn = if monsterHandlers then monsterHandlers.getMonsterColumn(monsterId) else nil
		-- Match by lawn tile (not a tight fractional window) so chewing
		-- monsters at MELEE_CLOSE_REACH standoff still take the bomb.
		if type(monsterColumn) == "number" and GridUtil.tileAtColumn(monsterColumn) == column then
			CombatService.damageMonster(monsterId, damage, sourceBrainrotId)
			fireCombatVisual(ownerUserId, { kind = "Hit", instanceId = monsterId })
		end
	end
end

function CombatService.dealEntireRowDamage(
	plotModel: Model,
	row: number,
	originColumn: number,
	damage: number,
	ownerUserId: number,
	options: { skipExplosion: boolean?, explosionStagger: number?, muteExplosionSound: boolean?, sourceBrainrotId: string?, ignoreIds: { [string]: boolean }? }?
)
	local targets = CombatService.getAllMonstersInRow(plotModel, row)
	local ignoreIds = if options then options.ignoreIds else nil
	for _, monsterId in targets do
		if ignoreIds and ignoreIds[monsterId] then
			continue
		end
		CombatService.damageMonster(monsterId, damage, options and options.sourceBrainrotId)
		fireCombatVisual(ownerUserId, { kind = "Hit", instanceId = monsterId })
	end
	if not (options and options.skipExplosion) then
		CombatService.fireRowExplosion(
			ownerUserId,
			row,
			originColumn,
			options and options.explosionStagger,
			options and options.muteExplosionSound
		)
	end
	if #targets > 0 then
		log:info(string.format("entire-row damage %d on row %d (%d targets)", damage, row, #targets))
	end
end

function CombatService.dealRowDamage(
	plotModel: Model,
	row: number,
	fromColumn: number,
	damage: number,
	_ownerUserId: number,
	sourceBrainrotId: string?
)
	local targets = CombatService.getMonstersInRow(plotModel, row, fromColumn, FULL_LINE)
	for _, monsterId in targets do
		local targetColumn = monsterColumnOf(monsterId)
		if type(targetColumn) == "number" and isBehindGrave(plotModel, row, fromColumn, targetColumn) then
			absorbGraveBlock(plotModel, row, fromColumn, targetColumn)
			continue
		end
		CombatService.damageMonster(monsterId, damage, sourceBrainrotId)
	end
	if #targets > 0 then
		log:info(string.format("line damage %d on row %d (%d targets)", damage, row, #targets))
	end
end

function CombatService.applyRowStatus(
	plotModel: Model,
	row: number,
	fromColumn: number,
	rangeTiles: number,
	kind: Types.StatusEffectKind,
	duration: number,
	ownerUserId: number,
	magnitude: number?,
	visual: string?
): boolean
	local targets = CombatService.getMonstersInRow(plotModel, row, fromColumn, rangeTiles)
	local applied = false
	for _, monsterId in targets do
		local targetColumn = monsterColumnOf(monsterId)
		if type(targetColumn) == "number" and isBehindGrave(plotModel, row, fromColumn, targetColumn) then
			absorbGraveBlock(plotModel, row, fromColumn, targetColumn)
			continue
		end
		CombatService.applyStatusToMonster(monsterId, kind, duration, magnitude, visual)
		applied = true
	end
	return applied
end

-- Status on every monster on the row (ahead and behind the caster).
-- `fromColumn` is the caster tile for grave LOS (Winter's Grasp). Nil = house
-- (column 0), which would let a fog grave eat the whole freeze.
function CombatService.applyEntireRowStatus(
	plotModel: Model,
	row: number,
	kind: Types.StatusEffectKind,
	duration: number,
	magnitude: number?,
	visual: string?,
	fromColumn: number?
): number
	local origin = if type(fromColumn) == "number" then fromColumn else 0
	local targets = CombatService.getAllMonstersInRow(plotModel, row)
	local applied = 0
	for _, monsterId in targets do
		local targetColumn = monsterColumnOf(monsterId)
		if type(targetColumn) ~= "number" then
			continue
		end
		local span = monsterLaneSpanOf(monsterId)
		if statusBlockedByGrave(plotModel, row, origin, targetColumn, span) then
			absorbGraveBlock(plotModel, row, origin, targetColumn)
			continue
		end
		CombatService.applyStatusToMonster(monsterId, kind, duration, magnitude, visual)
		applied += 1
	end
	return applied
end

-- Status on this row in a band: `tilesBehind` west of `centerColumn` and
-- `tilesAhead` east (inclusive lawn tiles). Match by tile / multi-lane
-- footprint (not a tight fractional window) so a 3-lane boss standing on the
-- caster tile still freezes. Graves still block eastward past the stone.
function CombatService.applyStatusAroundColumn(
	plotModel: Model,
	row: number,
	centerColumn: number,
	tilesAhead: number,
	tilesBehind: number,
	kind: Types.StatusEffectKind,
	duration: number,
	magnitude: number?,
	visual: string?
): number
	local ahead = math.max(0, tilesAhead)
	local behind = math.max(0, tilesBehind)
	local minTile = math.max(1, centerColumn - behind)
	local maxTile = math.min(GridConfig.COLUMNS, centerColumn + ahead)
	local targets = CombatService.getAllMonstersInRow(plotModel, row)
	local applied = 0
	for _, monsterId in targets do
		local targetColumn = monsterColumnOf(monsterId)
		if type(targetColumn) ~= "number" then
			continue
		end
		local span = monsterLaneSpanOf(monsterId)
		if not GridUtil.columnOverlapsTileBand(targetColumn, span, minTile, maxTile) then
			continue
		end
		if statusBlockedByGrave(plotModel, row, centerColumn, targetColumn, span) then
			absorbGraveBlock(plotModel, row, centerColumn, targetColumn)
			continue
		end
		CombatService.applyStatusToMonster(monsterId, kind, duration, magnitude, visual)
		applied += 1
	end
	return applied
end

function CombatService.getFirstMonsterInRow(
	plotModel: Model,
	row: number,
	fromColumn: number,
	rangeTiles: number
): string?
	if monsterHandlers then
		return monsterHandlers.queryFirstInRow(plotModel, row, fromColumn, rangeTiles)
	end
	return nil
end

function CombatService.getFirstMonsterInMeleeReach(
	plotModel: Model,
	row: number,
	fromColumn: number,
	reachColumns: number
): string?
	if monsterHandlers then
		return monsterHandlers.queryFirstInMeleeReach(plotModel, row, fromColumn, reachColumns)
	end
	return nil
end

function CombatService.getAllMonstersInRow(plotModel: Model, row: number): { string }
	if monsterHandlers then
		return monsterHandlers.queryEntireRow(plotModel, row)
	end
	return {}
end

function CombatService.rowHasBoss(plotModel: Model, row: number): boolean
	if not monsterHandlers then
		return false
	end
	for _, monsterId in CombatService.getAllMonstersInRow(plotModel, row) do
		if monsterHandlers.isBoss(monsterId) then
			return true
		end
	end
	return false
end

function CombatService.hasMonsterOnPlot(plotModel: Model): boolean
	for row = 1, GridConfig.ROWS do
		if #CombatService.getAllMonstersInRow(plotModel, row) > 0 then
			return true
		end
	end
	return false
end

function CombatService.getMonstersInRow(
	plotModel: Model,
	row: number,
	fromColumn: number,
	rangeTiles: number
): { string }
	if monsterHandlers then
		return monsterHandlers.queryRow(plotModel, row, fromColumn, rangeTiles)
	end
	return {}
end

-- `sourceBrainrotId` is required for DamageMeter ranks (HP dealt this day).
function CombatService.damageMonster(monsterInstanceId: string, damage: number, sourceBrainrotId: string?): boolean
	if monsterHandlers then
		return monsterHandlers.damage(monsterInstanceId, damage, sourceBrainrotId)
	end
	return false
end

function CombatService.getMonsterRegistryId(instanceId: string): string?
	if monsterHandlers then
		return monsterHandlers.getMonsterRegistryId(instanceId)
	end
	return nil
end

function CombatService.applyStatusToMonster(
	monsterInstanceId: string,
	kind: Types.StatusEffectKind,
	duration: number,
	magnitude: number?,
	visual: string?
)
	if monsterHandlers then
		monsterHandlers.applyStatus(monsterInstanceId, kind, duration, magnitude, visual)
	end
end

-- Wound of the Shark: when a bubble freeze ends, Slow from claimed Immortal
-- `bubbleExitSlowPercent` (params-only; any roster id, never a unit-name branch).
function CombatService.applyBubbleExitSlow(plotModel: Model, monsterInstanceId: string)
	local ownerUserId = plotModel:GetAttribute("OwnerUserId")
	if type(ownerUserId) ~= "number" then
		return
	end
	local player = Players:GetPlayerByUserId(ownerUserId)
	if not player then
		return
	end
	local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
	local Evolutions = require(ReplicatedStorage.Shared.Evolutions)
	local ProgressService = require(script.Parent.ProgressService)
	local percent = 0
	local duration = 3
	for _, definition in Brainrots.getAll() do
		local claimed = ProgressService.getClaimedEvolutions(player, definition.id)
		local overlaid = Evolutions.applyStats(definition, claimed)
		local params = overlaid.abilityParams
		if params and type(params.bubbleExitSlowPercent) == "number" and params.bubbleExitSlowPercent > 0 then
			percent = params.bubbleExitSlowPercent
			if type(params.bubbleExitSlowDuration) == "number" and params.bubbleExitSlowDuration > 0 then
				duration = params.bubbleExitSlowDuration
			end
			break
		end
	end
	if percent <= 0 then
		return
	end
	local factor = math.clamp(1 - percent / 100, 0.05, 1)
	local scaledDuration, scaledFactor = scaleTralaleroCrowdControl(monsterInstanceId, "Slow", duration, factor)
	if scaledDuration == nil then
		return
	end
	CombatService.applyStatusToMonster(monsterInstanceId, "Slow", scaledDuration, scaledFactor)
end

function CombatService.noteLandedAttack(sourceInstanceId: string)
	local BrainrotService = require(script.Parent.BrainrotService)
	BrainrotService.noteLandedAttack(sourceInstanceId)
end

function CombatService.notifyMonsterDeath(
	ownerUserId: number,
	instanceId: string,
	monsterId: string,
	row: number,
	column: number,
	lastHitBrainrotId: string?,
	isBoss: boolean
)
	fireCombatVisual(ownerUserId, {
		kind = "Death",
		instanceId = instanceId,
		monsterId = monsterId,
		row = row,
		column = column,
	})
	local player = Players:GetPlayerByUserId(ownerUserId)
	if player then
		local ProgressService = require(script.Parent.ProgressService)
		local ProgressConfig = require(ReplicatedStorage.Shared.Config.ProgressConfig)
		ProgressService.grantKillXp(player, lastHitBrainrotId, isBoss)
		ProgressService.incrementStat(player, ProgressConfig.STAT_MONSTERS_DEFEATED)
	end
end

function CombatService.clearPlot(plotModel: Model)
	Projectile.destroyAllOnPlot(plotModel)
end

local function shotPiercesGraves(impact: Projectile.ImpactSpec?): boolean
	if not impact then
		return false
	end
	if impact.pierceGraves == true then
		return true
	end
	return type(impact.pierceCount) == "number" and impact.pierceCount > 0
end

local function shotPiercesAll(impact: Projectile.ImpactSpec?): boolean
	return impact ~= nil and impact.pierceAll == true
end

local function claimWaveHit(waveGroupId: string?, monsterId: string): boolean
	if type(waveGroupId) ~= "string" or waveGroupId == "" then
		return true
	end
	local now = os.clock()
	local bucket = waveHits[waveGroupId]
	if not bucket or now >= bucket.expires then
		bucket = { hits = {}, expires = now + 8 }
		waveHits[waveGroupId] = bucket
	end
	if bucket.hits[monsterId] then
		return false
	end
	bucket.hits[monsterId] = true
	return true
end

local WAVE_FINALE_KEY = "__finale"

local function detonateSwordWaveFinale(
	plotModel: Model,
	row: number,
	ownerUserId: number,
	impact: Projectile.ImpactSpec?
)
	if not (impact and impact.waveFinale == true) then
		return
	end
	if not claimWaveHit(impact.waveGroupId, WAVE_FINALE_KEY) then
		return
	end

	local GridService = require(script.Parent.GridService)
	local lastTile = GridConfig.COLUMNS
	local worldPos = GridService.getWorldPositionAtColumn(plotModel, row, lastTile)
	if worldPos then
		Projectile.playSwordWaveFinale(plotModel, worldPos)
	end

	local bonus = impact.laneEndBonus
	if type(bonus) ~= "number" or bonus <= 0 then
		return
	end

	for _, monsterId in CombatService.getAllMonstersInRow(plotModel, row) do
		local monsterColumn = monsterColumnOf(monsterId)
		if type(monsterColumn) ~= "number" then
			continue
		end
		local span = monsterLaneSpanOf(monsterId)
		if not GridUtil.columnOverlapsTileBand(monsterColumn, span, lastTile, lastTile) then
			continue
		end
		CombatService.damageMonster(monsterId, bonus, impact.sourceBrainrotId)
		fireCombatVisual(ownerUserId, {
			kind = "Hit",
			instanceId = monsterId,
			soundKey = impact.soundKey,
		})
	end
end

local function nextPierceTarget(
	plotModel: Model,
	row: number,
	searchFrom: number,
	excludeId: string?
): string?
	local pierceId = CombatService.getFirstMonsterInRow(plotModel, row, searchFrom + 0.01, FULL_LINE)
	if pierceId and pierceId ~= excludeId then
		return pierceId
	end
	return nil
end

local function pierceContinue(
	plotModel: Model,
	row: number,
	searchFrom: number,
	excludeId: string?,
	impact: Projectile.ImpactSpec?
): string?
	local nextId = nextPierceTarget(plotModel, row, searchFrom, excludeId)
	if nextId then
		return nextId
	end
	if shotPiercesAll(impact) then
		return "LaneEnd"
	end
	return nil
end

local function swordWaveHitDamage(
	baseDamage: number,
	monsterColumn: number,
	impact: Projectile.ImpactSpec?
): number
	if not impact then
		return baseDamage
	end
	local origin = impact.waveOriginColumn
	local bonus = impact.waveTravelBonus
	if type(origin) ~= "number" or type(bonus) ~= "number" or bonus <= 0 then
		return baseDamage
	end
	local tilesAway = GridUtil.tileAtColumn(monsterColumn) - origin
	local extraTiles = math.max(0, tilesAway - 1)
	return math.max(1, baseDamage + extraTiles * bonus)
end

local function onWaveSweep(
	plotModel: Model,
	row: number,
	fromColumn: number,
	toColumn: number,
	damage: number,
	ownerUserId: number,
	impact: Projectile.ImpactSpec?
)
	if damage <= 0 then
		return
	end
	local lo = math.min(fromColumn, toColumn)
	local hi = math.max(fromColumn, toColumn)
	for _, monsterId in CombatService.getAllMonstersInRow(plotModel, row) do
		local column = monsterColumnOf(monsterId)
		if type(column) ~= "number" then
			continue
		end
		if column <= lo or column > hi then
			continue
		end
		local waveId = if impact then impact.waveGroupId else nil
		if not claimWaveHit(waveId, monsterId) then
			continue
		end
		local hitDamage = swordWaveHitDamage(damage, column, impact)
		CombatService.damageMonster(monsterId, hitDamage, if impact then impact.sourceBrainrotId else nil)
		fireCombatVisual(ownerUserId, {
			kind = "Hit",
			instanceId = monsterId,
			soundKey = if impact then impact.soundKey else nil,
		})
	end
end

local function onProjectileImpact(
	instanceId: string,
	damage: number,
	ownerUserId: number,
	impact: Projectile.ImpactSpec?,
	targetKind: string?,
	plotModel: Model?,
	row: number?,
	column: number?
): (boolean, string?)
	if targetKind == "Grave" or targetKind == "LaneEnd" or targetKind == "Split" then
		if targetKind == "Split" and plotModel and type(row) == "number" and type(column) == "number" then
			local split = if impact then impact.splitBarrage else nil
			if split then
				local GridService = require(script.Parent.GridService)
				local pos = GridService.getWorldPositionAtColumn(plotModel, row, column)
				if pos then
					local origin = Vector3.new(pos.X, split.worldY, pos.Z)
					local childOptions: ProjectileLaunchOptions = {
						kind = "Bubble",
						soundKey = if impact then impact.soundKey else nil,
						statusKind = if impact then impact.statusKind else nil,
						statusDuration = if impact then impact.statusDuration else nil,
						statusVisual = if impact then impact.statusVisual else nil,
						sourceBrainrotId = if impact then impact.sourceBrainrotId else nil,
						sourceInstanceId = if impact then impact.sourceInstanceId else nil,
					}
					for childRow = 1, GridConfig.ROWS do
						CombatService.launchSpreadingBubble(
							plotModel,
							split.plantColumn,
							childRow,
							split.rangeTiles,
							split.damage,
							ownerUserId,
							origin,
							childOptions
						)
						if split.extraChance > 0 and math.random() * 100 < split.extraChance then
							CombatService.launchSpreadingBubble(
								plotModel,
								split.plantColumn,
								childRow,
								split.rangeTiles,
								split.damage,
								ownerUserId,
								origin + Vector3.new(0.45, 0.18, 0),
								childOptions
							)
						end
					end
				end
			end
		end
		-- Piercing Brew: skip the stone (no HP / shake) and keep flying to the
		-- monster east of it.
		if targetKind == "Grave"
			and shotPiercesGraves(impact)
			and plotModel
			and type(row) == "number"
			and type(column) == "number"
		then
			return false, pierceContinue(plotModel, row, column, nil, impact)
		end
		if targetKind == "Grave" then
			fireCombatVisual(ownerUserId, {
				kind = "Hit",
				soundKey = if impact and impact.soundKey then impact.soundKey else "ThrowKnifeHit",
			})
		end
		if targetKind == "LaneEnd" and plotModel and type(row) == "number" then
			detonateSwordWaveFinale(plotModel, row, ownerUserId, impact)
		end
		return false, nil
	end

	if targetKind == "Brainrot" then
		local killed = CombatService.damageBrainrot(
			instanceId,
			damage,
			if impact then impact.sourceMonsterId else nil
		)
		fireCombatVisual(ownerUserId, {
			kind = "Hit",
			instanceId = instanceId,
			soundKey = if impact and impact.soundKey then impact.soundKey else "ThrowKnifeHit",
		})
		return killed, nil
	end

	local alreadyHit = false
	if impact and type(impact.waveGroupId) == "string" then
		alreadyHit = not claimWaveHit(impact.waveGroupId, instanceId)
	end

	local killed = false
	if not alreadyHit then
		killed = CombatService.damageMonster(instanceId, damage, if impact then impact.sourceBrainrotId else nil)
		if impact and type(impact.sourceInstanceId) == "string" then
			CombatService.noteLandedAttack(impact.sourceInstanceId)
		end
		local payload: { [string]: any } = {
			kind = "Hit",
			instanceId = instanceId,
			soundKey = if impact and impact.soundKey then impact.soundKey else "ThrowKnifeHit",
		}
		fireCombatVisual(ownerUserId, payload)

		if not killed and impact and impact.statusKind then
			local duration = if type(impact.statusDuration) == "number" then impact.statusDuration else 0
			local magnitude = impact.statusMagnitude
			local applyStatus = impact.statusKind == "Knockback" or duration > 0
			if applyStatus and impact.statusVisual == "Bubble" then
				local scaledDuration, scaledMagnitude = scaleTralaleroCrowdControl(
					instanceId,
					impact.statusKind,
					duration,
					magnitude
				)
				if scaledDuration == nil then
					applyStatus = false
				else
					duration = scaledDuration
					magnitude = scaledMagnitude
				end
			end
			if applyStatus then
				CombatService.applyStatusToMonster(
					instanceId,
					impact.statusKind,
					duration,
					magnitude,
					impact.statusVisual
				)
			end
		end
	end

	local pierceCount = if impact then impact.pierceCount else nil
	local shouldPierce = shotPiercesAll(impact)
		or (type(pierceCount) == "number" and pierceCount > 0)
	if shouldPierce and plotModel and type(row) == "number" then
		local searchFrom = column
		if not killed and monsterHandlers then
			local liveColumn = monsterHandlers.getMonsterColumn(instanceId)
			if type(liveColumn) == "number" then
				searchFrom = liveColumn
			end
		end
		if type(searchFrom) == "number" then
			return killed, pierceContinue(plotModel, row, searchFrom, instanceId, impact)
		end
	end
	return killed, nil
end

function CombatService.init()
end

function CombatService.start()
	local function projectileColumn(instanceId: string, targetKind: string?): number?
		if not monsterHandlers then
			return nil
		end
		if targetKind == "Brainrot" then
			local BrainrotService = require(script.Parent.BrainrotService)
			local placement = BrainrotService.getPlacement(instanceId)
			return if placement then placement.position.column else nil
		end
		return monsterHandlers.getMonsterColumn(instanceId)
	end

	-- Frame step so knives, shurikens, pineapples, and the rest glide
	-- instead of jumping on the 0.1s combat tick. Hits stay server-side.
	RunService.Heartbeat:Connect(function(dt)
		if not monsterHandlers then
			return
		end
		Projectile.tick(
			dt,
			projectileColumn,
			monsterHandlers.setProjectilePosition,
			onProjectileImpact,
			onWaveSweep
		)
	end)

	task.spawn(function()
		while true do
			task.wait(CombatConfig.TICK)
			if not monsterHandlers then
				continue
			end
			monsterHandlers.tickStatuses(CombatConfig.TICK)
		end
	end)

	log:info("started")
end

return CombatService
