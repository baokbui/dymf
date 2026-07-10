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
	applyStatus: (instanceId: string, kind: Types.StatusEffectKind, duration: number, magnitude: number?) -> (),
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

-- Damages the closest monster within short fractional melee reach on a row.
function CombatService.attackFirstInMeleeReach(
	plotModel: Model,
	position: Types.GridPosition,
	reachColumns: number,
	damage: number,
	ownerUserId: number
): boolean
	local targetId = if monsterHandlers
		then monsterHandlers.queryFirstInMeleeReach(plotModel, position.row, position.column, reachColumns)
		else nil
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

-- Damages every monster in range on a row (splash / line effects).
function CombatService.attackInRow(
	plotModel: Model,
	position: Types.GridPosition,
	rangeTiles: number,
	damage: number,
	ownerUserId: number
): boolean
	local targets = CombatService.getMonstersInRow(plotModel, position.row, position.column, rangeTiles)
	if #targets == 0 then
		return false
	end
	for _, monsterId in targets do
		CombatService.damageMonster(monsterId, damage)
		fireCombatVisual(ownerUserId, {
			kind = "Hit",
			instanceId = monsterId,
		})
	end
	return true
end

-- Fires a projectile at the first monster in range; damage applies on impact.
function CombatService.launchProjectile(
	plotModel: Model,
	position: Types.GridPosition,
	rangeTiles: number,
	damage: number,
	ownerUserId: number
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

	local targetColumn = monsterHandlers.getMonsterColumn(targetId)
	if not targetColumn then
		return false
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
		},
		worldY,
		monsterHandlers.setProjectilePosition
	)
	return true
end

function CombatService.dealEntireRowDamage(
	plotModel: Model,
	row: number,
	originColumn: number,
	damage: number,
	ownerUserId: number
)
	local targets = CombatService.getAllMonstersInRow(plotModel, row)
	for _, monsterId in targets do
		CombatService.damageMonster(monsterId, damage)
		fireCombatVisual(ownerUserId, { kind = "Hit", instanceId = monsterId })
	end
	if #targets > 0 then
		fireCombatVisual(ownerUserId, {
			kind = "Explosion",
			row = row,
			column = originColumn,
		})
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
	magnitude: number?
): boolean
	local targets = CombatService.getMonstersInRow(plotModel, row, fromColumn, rangeTiles)
	for _, monsterId in targets do
		CombatService.applyStatusToMonster(monsterId, kind, duration, magnitude)
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
	magnitude: number?
)
	if monsterHandlers then
		monsterHandlers.applyStatus(monsterInstanceId, kind, duration, magnitude)
	end
end

function CombatService.notifyMonsterDeath(ownerUserId: number, instanceId: string, row: number, column: number)
	fireCombatVisual(ownerUserId, {
		kind = "Death",
		instanceId = instanceId,
		row = row,
		column = column,
	})
end

function CombatService.clearPlot(plotModel: Model)
	Projectile.destroyAllOnPlot(plotModel)
end

local function onProjectileImpact(instanceId: string, damage: number, ownerUserId: number): boolean
	local hit = CombatService.damageMonster(instanceId, damage)
	fireCombatVisual(ownerUserId, {
		kind = "Hit",
		instanceId = instanceId,
	})
	return hit
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
				monsterHandlers.getMonsterColumn,
				monsterHandlers.setProjectilePosition,
				onProjectileImpact
			)
		end
	end)

	log:info("started")
end

return CombatService
