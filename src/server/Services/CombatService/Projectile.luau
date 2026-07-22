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
	-- "Knife" (legacy bolt), "Sword" (Cappuccino), or "Bubble"
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
	Procedural sword: long axis = local +X. In flight we tip it upright (+Y) and
	spin around world +X so it reads as a vertical wheel toward the enemy.
]]
local function createSwordModel(): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "SwordProjectile"

	local blade = Instance.new("Part")
	blade.Name = "Blade"
	blade.Size = CombatConfig.SWORD_BLADE_SIZE
	blade.Material = Enum.Material.Metal
	blade.Color = CombatConfig.SWORD_BLADE_COLOR
	blade.CFrame = CFrame.new()
	blade.Parent = model
	hardenRoot(blade)

	local tip = Instance.new("WedgePart")
	tip.Name = "Tip"
	tip.Size = Vector3.new(
		CombatConfig.SWORD_BLADE_SIZE.Z,
		CombatConfig.SWORD_BLADE_SIZE.Y,
		CombatConfig.SWORD_BLADE_SIZE.Y * 0.9
	)
	tip.Material = Enum.Material.Metal
	tip.Color = CombatConfig.SWORD_BLADE_COLOR
	tip.CFrame = CFrame.new(CombatConfig.SWORD_BLADE_SIZE.X * 0.5 + tip.Size.Z * 0.5, 0, 0)
		* CFrame.Angles(0, math.rad(90), 0)
	tip.Parent = model
	weldAccessory(blade, tip)

	local guard = Instance.new("Part")
	guard.Name = "Guard"
	guard.Size = CombatConfig.SWORD_GUARD_SIZE
	guard.Material = Enum.Material.Neon
	guard.Color = CombatConfig.SWORD_GUARD_COLOR
	guard.CFrame = CFrame.new(-CombatConfig.SWORD_BLADE_SIZE.X * 0.42, 0, 0)
	guard.Parent = model
	weldAccessory(blade, guard)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = CombatConfig.SWORD_HANDLE_SIZE
	handle.Material = Enum.Material.SmoothPlastic
	handle.Color = CombatConfig.SWORD_HANDLE_COLOR
	handle.CFrame = CFrame.new(
		-CombatConfig.SWORD_BLADE_SIZE.X * 0.42 - CombatConfig.SWORD_HANDLE_SIZE.X * 0.55,
		0,
		0
	)
	handle.Parent = model
	weldAccessory(blade, handle)

	local pommel = Instance.new("Part")
	pommel.Name = "Pommel"
	pommel.Shape = Enum.PartType.Ball
	pommel.Size = Vector3.new(0.5, 0.5, 0.5)
	pommel.Material = Enum.Material.Neon
	pommel.Color = CombatConfig.SWORD_GUARD_COLOR
	pommel.CFrame = CFrame.new(
		-CombatConfig.SWORD_BLADE_SIZE.X * 0.42 - CombatConfig.SWORD_HANDLE_SIZE.X * 1.05,
		0,
		0
	)
	pommel.Parent = model
	weldAccessory(blade, pommel)

	model.PrimaryPart = blade
	model:SetAttribute("ProjectileKind", "Sword")
	blade:SetAttribute("ProjectileKind", "Sword")
	return model, blade
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

	if kind == "Sword" then
		local swordModel, blade = createSwordModel()
		model = swordModel
		part = blade
		swordModel.Parent = folder
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
			projectile.spinRadians += CombatConfig.SWORD_SPIN_RADIANS_PER_SECOND * dt
			-- Vertical wheel: tip starts +Y, rolls around travel (+X) so the blade
			-- spins in the YZ plane (reads as upright spin when facing the enemy).
			local pos = projectile.part.Position
			projectile.part.CFrame = CFrame.new(pos)
				* CFrame.fromAxisAngle(Vector3.xAxis, projectile.spinRadians)
				* CFrame.Angles(0, 0, math.pi / 2)
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
