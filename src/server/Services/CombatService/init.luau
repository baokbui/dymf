--!strict
--[[
	CombatService
	The ONLY system that modifies health. Owns damage, healing, death routing,
	target acquisition, projectiles, and status effects. Brainrots and monsters
	route all health changes through here.

	Milestone 7.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotConfig = require(ReplicatedStorage.Shared.Config.BrainrotConfig)
local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local GridUtil = require(ReplicatedStorage.Shared.Utilities.GridUtil)
local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)

local Projectile = require(script.Projectile)

local CombatService = {}
CombatService.Name = "CombatService"

local log = Logger.new(CombatService.Name)

local FULL_LINE = BrainrotConfig.FULL_LINE_RANGE

local brainrotDamageHandler: ((instanceId: string, hits: number) -> boolean)?
local brainrotStatusHandler: ((instanceId: string, kind: Types.StatusEffectKind, duration: number, magnitude: number?) -> ())?

type MonsterHandlers = {
	queryEntireRow: (plotModel: Model, row: number) -> { string },
	queryRow: (plotModel: Model, row: number, fromColumn: number, rangeTiles: number) -> { string },
	queryFirstInRow: (plotModel: Model, row: number, fromColumn: number, rangeTiles: number) -> string?,
	queryFirstInMeleeReach: (plotModel: Model, row: number, fromColumn: number, reachColumns: number) -> string?,
	getMonsterColumn: (instanceId: string) -> number?,
	getProjectileWorldY: (plotModel: Model, row: number, startColumn: number) -> number?,
	setProjectilePosition: (part: BasePart, plotModel: Model, row: number, column: number, worldY: number) -> (),
	damage: (instanceId: string, damage: number) -> boolean,
	applyStatus: (instanceId: string, kind: Types.StatusEffectKind, duration: number, magnitude: number?, visual: string?) -> (),
	tickStatuses: (dt: number) -> (),
}

local monsterHandlers: MonsterHandlers?

local function fireCombatVisual(ownerUserId: number, payload: { [string]: any })
	local player = Players:GetPlayerByUserId(ownerUserId)
	if not player then
		return
	end
	Remotes.getEvent("CombatVisual"):FireClient(player, payload)
end

function CombatService.setBrainrotDamageHandler(handler: (instanceId: string, hits: number) -> boolean)
	brainrotDamageHandler = handler
end

function CombatService.setBrainrotStatusHandler(
	handler: (instanceId: string, kind: Types.StatusEffectKind, duration: number, magnitude: number?) -> ()
)
	brainrotStatusHandler = handler
end

function CombatService.setMonsterHandlers(handlers: MonsterHandlers)
	monsterHandlers = handlers
end

function CombatService.damageBrainrot(instanceId: string, hits: number): boolean
	if brainrotDamageHandler then
		return brainrotDamageHandler(instanceId, hits)
	end
	return false
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
	ownerUserId: number
): boolean
	local targetId = CombatService.getFirstMonsterInRow(plotModel, position.row, position.column, rangeTiles)
	if not targetId then
		return false
	end
	CombatService.damageMonster(targetId, damage)
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
	muteSound: boolean?
): boolean
	local targetId = if monsterHandlers
		then monsterHandlers.queryFirstInMeleeReach(plotModel, position.row, position.column, reachColumns)
		else nil
	if not targetId then
		return false
	end
	CombatService.damageMonster(targetId, damage)
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
	soundKey: string?
): boolean
	local targets = CombatService.getMonstersInRow(plotModel, position.row, position.column, rangeTiles)
	if #targets == 0 then
		return false
	end
	for _, monsterId in targets do
		CombatService.damageMonster(monsterId, damage)
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
	statusVisual: string?,
	-- Spawn at this world point (Skeleton bow / LArm) instead of lane center.
	originWorld: Vector3?,
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

	local targetId = CombatService.getFirstMonsterInRow(plotModel, position.row, position.column, rangeTiles)
	if not targetId then
		return false
	end

	local worldY = monsterHandlers.getProjectileWorldY(plotModel, position.row, position.column)
	if not worldY then
		return false
	end
	-- Shurikens spin flat and fly a little higher than the legacy bolt.
	if options and options.kind == "Shuriken" then
		worldY = worldY
			- CombatConfig.PROJECTILE_HEIGHT_OFFSET
			+ CombatConfig.SHURIKEN_PROJECTILE_HEIGHT_OFFSET
	end

	local targetColumn = monsterHandlers.getMonsterColumn(targetId)
	if not targetColumn then
		return false
	end

	local impact: Projectile.ImpactSpec? = nil
	if options then
		impact = {
			soundKey = options.soundKey,
			statusKind = options.statusKind,
			statusDuration = options.statusDuration,
			statusVisual = options.statusVisual,
		}
	end

	Projectile.launch(
		{
			plotModel = plotModel,
			row = position.row,
			startColumn = position.column,
			targetInstanceId = targetId,
			targetColumn = targetColumn,
			damage = damage,
			ownerUserId = ownerUserId,
			kind = if options then options.kind else nil,
			impact = impact,
		},
		worldY,
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
		},
		worldY,
		monsterHandlers.setProjectilePosition
	)
	return true
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

function CombatService.dealColumnDamage(
	plotModel: Model,
	row: number,
	column: number,
	damage: number,
	ownerUserId: number
)
	local targets = CombatService.getAllMonstersInRow(plotModel, row)
	for _, monsterId in targets do
		local monsterColumn = if monsterHandlers then monsterHandlers.getMonsterColumn(monsterId) else nil
		-- Match by lawn tile (not a tight fractional window) so chewing
		-- monsters at MELEE_CLOSE_REACH standoff still take the bomb.
		if type(monsterColumn) == "number" and GridUtil.tileAtColumn(monsterColumn) == column then
			CombatService.damageMonster(monsterId, damage)
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
	options: { skipExplosion: boolean?, explosionStagger: number?, muteExplosionSound: boolean? }?
)
	local targets = CombatService.getAllMonstersInRow(plotModel, row)
	for _, monsterId in targets do
		CombatService.damageMonster(monsterId, damage)
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
	_ownerUserId: number
)
	local targets = CombatService.getMonstersInRow(plotModel, row, fromColumn, FULL_LINE)
	for _, monsterId in targets do
		CombatService.damageMonster(monsterId, damage)
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
	for _, monsterId in targets do
		CombatService.applyStatusToMonster(monsterId, kind, duration, magnitude, visual)
	end
	return #targets > 0
end

-- Status on every monster on the row (ahead and behind the caster).
function CombatService.applyEntireRowStatus(
	plotModel: Model,
	row: number,
	kind: Types.StatusEffectKind,
	duration: number,
	magnitude: number?,
	visual: string?
): boolean
	local targets = CombatService.getAllMonstersInRow(plotModel, row)
	for _, monsterId in targets do
		CombatService.applyStatusToMonster(monsterId, kind, duration, magnitude, visual)
	end
	return #targets > 0
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

function CombatService.damageMonster(monsterInstanceId: string, damage: number): boolean
	if monsterHandlers then
		return monsterHandlers.damage(monsterInstanceId, damage)
	end
	return false
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

function CombatService.notifyMonsterDeath(
	ownerUserId: number,
	instanceId: string,
	monsterId: string,
	row: number,
	column: number
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
		ProgressService.incrementStat(player, ProgressConfig.STAT_MONSTERS_DEFEATED)
	end
end

function CombatService.clearPlot(plotModel: Model)
	Projectile.destroyAllOnPlot(plotModel)
end

local function onProjectileImpact(
	instanceId: string,
	damage: number,
	ownerUserId: number,
	impact: Projectile.ImpactSpec?,
	targetKind: string?
): boolean
	if targetKind == "Brainrot" then
		local killed = CombatService.damageBrainrot(instanceId, damage)
		fireCombatVisual(ownerUserId, {
			kind = "Hit",
			instanceId = instanceId,
			soundKey = if impact and impact.soundKey then impact.soundKey else "ThrowKnifeHit",
		})
		return killed
	end

	local killed = CombatService.damageMonster(instanceId, damage)
	local payload: { [string]: any } = {
		kind = "Hit",
		instanceId = instanceId,
		soundKey = if impact and impact.soundKey then impact.soundKey else "ThrowKnifeHit",
	}
	fireCombatVisual(ownerUserId, payload)

	if not killed and impact and impact.statusKind and impact.statusDuration then
		CombatService.applyStatusToMonster(
			instanceId,
			impact.statusKind,
			impact.statusDuration,
			nil,
			impact.statusVisual
		)
	end
	return killed
end

function CombatService.init()
end

function CombatService.start()
	task.spawn(function()
		while true do
			task.wait(CombatConfig.TICK)
			if not monsterHandlers then
				continue
			end
			monsterHandlers.tickStatuses(CombatConfig.TICK)
			Projectile.tick(
				CombatConfig.TICK,
				function(instanceId: string, targetKind: string?): number?
					if targetKind == "Brainrot" then
						local BrainrotService = require(script.Parent.BrainrotService)
						local placement = BrainrotService.getPlacement(instanceId)
						return if placement then placement.position.column else nil
					end
					return monsterHandlers.getMonsterColumn(instanceId)
				end,
				monsterHandlers.setProjectilePosition,
				onProjectileImpact
			)
		end
	end)

	log:info("started")
end

return CombatService
