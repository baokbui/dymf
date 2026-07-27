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
	-- "Knife" (legacy bolt), "Shuriken" (Cappuccino), or "Bubble"
	kind: string?,
	impact: ImpactSpec?,
}

export type ActiveProjectile = {
	id: string,
	spec: LaunchSpec,
	column: number,
	part: BasePart,
	model: Model?,
	spinRadians: number,
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

local function hardenRoot(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
end

local function weldAccessory(root: BasePart, part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = root
end

--[[
	Procedural shuriken: a flat 4-point star (thin disc + wedge blades) built
	flat in the world XZ plane. In flight we spin it around world +Y so it
	stays horizontal and reads as a real thrown shuriken spinning flat.
]]
local function createShurikenModel(): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "ShurikenProjectile"

	local hub = Instance.new("Part")
	hub.Name = "Hub"
	hub.Shape = Enum.PartType.Cylinder
	hub.Size = CombatConfig.SHURIKEN_HUB_SIZE
	hub.Material = Enum.Material.Metal
	hub.Color = CombatConfig.SHURIKEN_HUB_COLOR
	hub.CFrame = CFrame.new() * CFrame.Angles(0, 0, math.rad(90))
	hub.Parent = model
	hardenRoot(hub)

	local bladeSpan = CombatConfig.SHURIKEN_BLADE_SIZE.X
	local bladeThickness = CombatConfig.SHURIKEN_BLADE_SIZE.Y
	local bladeWidth = CombatConfig.SHURIKEN_BLADE_SIZE.Z

	-- Four wedge blades pointing outward at 90° increments in the XZ plane.
	for i = 0, 3 do
		local angle = math.rad(90 * i)
		local blade = Instance.new("WedgePart")
		blade.Name = string.format("Blade%d", i + 1)
		blade.Size = Vector3.new(bladeThickness, bladeWidth, bladeSpan * 0.5)
		blade.Material = Enum.Material.Metal
		blade.Color = CombatConfig.SHURIKEN_BLADE_COLOR
		blade.CFrame = CFrame.new(hub.Position)
			* CFrame.Angles(math.rad(90), angle, 0)
			* CFrame.new(0, 0, -bladeSpan * 0.25)
		blade.Parent = model
		weldAccessory(hub, blade)
	end

	model.PrimaryPart = hub
	model:SetAttribute("ProjectileKind", "Shuriken")
	hub:SetAttribute("ProjectileKind", "Shuriken")
	return model, hub
end

local function createBoltPart(): BasePart
	local part = Instance.new("Part")
	part.Name = "Projectile"
	part.Shape = Enum.PartType.Block
	part.Size = CombatConfig.PROJECTILE_SIZE
	part.Material = Enum.Material.Neon
	part.Color = CombatConfig.PROJECTILE_COLOR
	part.Transparency = 0
	hardenRoot(part)
	part:SetAttribute("ProjectileKind", "Knife")
	return part
end

local function createBubblePart(): BasePart
	local part = Instance.new("Part")
	part.Name = "Projectile"
	part.Shape = Enum.PartType.Ball
	part.Size = CombatConfig.BUBBLE_PROJECTILE_SIZE
	part.Material = Enum.Material.ForceField
	part.Color = MonsterConfig.BUBBLE_COLOR
	part.Transparency = CombatConfig.BUBBLE_PROJECTILE_TRANSPARENCY
	hardenRoot(part)
	part:SetAttribute("ProjectileKind", "Bubble")
	return part
end

local function destroyProjectile(projectile: ActiveProjectile)
	if projectile.model then
		projectile.model:Destroy()
	elseif projectile.part.Parent then
		projectile.part:Destroy()
	end
end

function Projectile.launch(
	spec: LaunchSpec,
	worldY: number,
	setWorldPosition: SetPositionCallback
): string
	nextId += 1
	local id = string.format("Projectile_%d", nextId)
	local kind = spec.kind or "Knife"
	local folder = projectilesFolder(spec.plotModel)

	local part: BasePart
	local model: Model? = nil

	if kind == "Shuriken" then
		local shurikenModel, hub = createShurikenModel()
		model = shurikenModel
		part = hub
		shurikenModel.Parent = folder
	elseif kind == "Bubble" then
		part = createBubblePart()
		part.Parent = folder
	else
		part = createBoltPart()
		part.Parent = folder
	end

	setWorldPosition(part, spec.plotModel, spec.row, spec.startColumn, worldY)

	active[id] = {
		id = id,
		spec = spec,
		column = spec.startColumn,
		part = part,
		model = model,
		spinRadians = 0,
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
			destroyProjectile(projectile)
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

		if projectile.model then
			projectile.spinRadians += CombatConfig.SHURIKEN_SPIN_RADIANS_PER_SECOND * dt
			-- Flat disc: spin around world +Y so it stays horizontal and reads
			-- as a real thrown shuriken spinning flat while it flies.
			local pos = projectile.part.Position
			projectile.part.CFrame = CFrame.new(pos) * CFrame.fromAxisAngle(Vector3.yAxis, projectile.spinRadians)
		end

		if projectile.column >= liveColumn then
			onImpact(
				projectile.spec.targetInstanceId,
				projectile.spec.damage,
				projectile.spec.ownerUserId,
				projectile.spec.impact
			)
			destroyProjectile(projectile)
			active[id] = nil
		end
	end
end

function Projectile.destroyAllOnPlot(plotModel: Model)
	for id, projectile in active do
		if projectile.spec.plotModel == plotModel then
			destroyProjectile(projectile)
			active[id] = nil
		end
	end
end

return Projectile
