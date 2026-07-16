--!strict
--[[
	Projectile
	Server-authoritative lane projectiles. Moves along a row (+X) until it
	reaches its target, then applies damage (and optional status) through a
	callback. Appearance is data-driven via LaunchSpec.kind.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local MonsterConfig = require(ReplicatedStorage.Shared.Config.MonsterConfig)
local Types = require(ReplicatedStorage.Shared.Types)

local Projectile = {}

export type ImpactSpec = {
	soundKey: string?,
	statusKind: Types.StatusEffectKind?,
	statusDuration: number?,
	statusVisual: string?,
}

export type LaunchSpec = {
	plotModel: Model,
	row: number,
	startColumn: number,
	targetInstanceId: string,
	targetColumn: number,
	damage: number,
	ownerUserId: number,
	-- "Knife" (default) or "Bubble"
	kind: string?,
	impact: ImpactSpec?,
}

export type ActiveProjectile = {
	id: string,
	spec: LaunchSpec,
	column: number,
	part: BasePart,
	worldY: number,
}

type ImpactCallback = (
	instanceId: string,
	damage: number,
	ownerUserId: number,
	impact: ImpactSpec?
) -> boolean
type GetColumnCallback = (instanceId: string) -> number?
type SetPositionCallback = (part: BasePart, plotModel: Model, row: number, column: number, worldY: number) -> ()

local active: { [string]: ActiveProjectile } = {}
local nextId = 0

local function projectilesFolder(plotModel: Model): Folder
	local folder = plotModel:FindFirstChild("Projectiles")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Projectiles"
		folder.Parent = plotModel
	end
	return folder :: Folder
end

local function stylePart(part: BasePart, kind: string?)
	local projectileKind = kind or "Knife"
	part:SetAttribute("ProjectileKind", projectileKind)

	if projectileKind == "Bubble" then
		part.Shape = Enum.PartType.Ball
		part.Size = CombatConfig.BUBBLE_PROJECTILE_SIZE
		part.Material = Enum.Material.ForceField
		part.Color = MonsterConfig.BUBBLE_COLOR
		part.Transparency = CombatConfig.BUBBLE_PROJECTILE_TRANSPARENCY
	else
		part.Shape = Enum.PartType.Block
		part.Size = CombatConfig.PROJECTILE_SIZE
		part.Material = Enum.Material.Neon
		part.Color = CombatConfig.PROJECTILE_COLOR
		part.Transparency = 0
	end
end

function Projectile.launch(
	spec: LaunchSpec,
	worldY: number,
	setWorldPosition: SetPositionCallback
): string
	nextId += 1
	local id = string.format("Projectile_%d", nextId)
	local part = Instance.new("Part")
	part.Name = "Projectile"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	stylePart(part, spec.kind)
	part.Parent = projectilesFolder(spec.plotModel)

	setWorldPosition(part, spec.plotModel, spec.row, spec.startColumn, worldY)

	active[id] = {
		id = id,
		spec = spec,
		column = spec.startColumn,
		part = part,
		worldY = worldY,
	}
	return id
end

function Projectile.tick(
	dt: number,
	getColumn: GetColumnCallback,
	setWorldPosition: SetPositionCallback,
	onImpact: ImpactCallback
)
	for id, projectile in active do
		local liveColumn = getColumn(projectile.spec.targetInstanceId)
		if not liveColumn then
			projectile.part:Destroy()
			active[id] = nil
			continue
		end

		projectile.column += CombatConfig.PROJECTILE_COLUMNS_PER_SECOND * dt
		setWorldPosition(
			projectile.part,
			projectile.spec.plotModel,
			projectile.spec.row,
			projectile.column,
			projectile.worldY
		)

		if projectile.column >= liveColumn then
			onImpact(
				projectile.spec.targetInstanceId,
				projectile.spec.damage,
				projectile.spec.ownerUserId,
				projectile.spec.impact
			)
			projectile.part:Destroy()
			active[id] = nil
		end
	end
end

function Projectile.destroyAllOnPlot(plotModel: Model)
	for id, projectile in active do
		if projectile.spec.plotModel == plotModel then
			projectile.part:Destroy()
			active[id] = nil
		end
	end
end

return Projectile
