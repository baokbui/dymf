--!strict
--[[
	Projectile
	Server-authoritative lane projectiles. Moves along a row (+X) until it
	reaches its target, then applies damage (and optional status) through a
	callback. Appearance is data-driven via LaunchSpec.kind.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local VfxConfig = require(ReplicatedStorage.Shared.Config.VfxConfig)
local Types = require(ReplicatedStorage.Shared.Types)
local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)
local ModelUtil = require(ReplicatedStorage.Shared.Utilities.ModelUtil)

local Projectile = {}

local log = Logger.new("Projectile")
local missingShurikenLogged = false

export type ImpactSpec = {
	soundKey: string?,
	statusKind: Types.StatusEffectKind?,
	statusDuration: number?,
	statusVisual: string?,
	sourceBrainrotId: string?,
	sourceInstanceId: string?,
	pierceCount: number?,
	-- Bubble Barrage: this projectile is the seed; on Split, spawn one child per row.
	splitBarrage: {
		rangeTiles: number,
		plantColumn: number,
		extraChance: number,
		worldY: number,
		damage: number,
	}?,
}

export type LaunchSpec = {
	plotModel: Model,
	row: number,
	startColumn: number,
	targetInstanceId: string,
	targetColumn: number,
	damage: number,
	ownerUserId: number,
	-- "Knife" (legacy bolt), "Shuriken" (Cappuccino), "Bubble", or "Arrow"
	kind: string?,
	impact: ImpactSpec?,
	-- Default "Monster". "Brainrot" = westbound shots (Skeleton arrows).
	targetKind: string?,
	-- Grid travel: +1 toward the forest, −1 toward the house.
	columnDirection: number?,
	-- Keep this Z for the whole flight (bow / arm spawn). Nil = lane-center Z.
	worldZ: number?,
	-- Fan from mouth (originWorld.Z) into the target lane over zLerpColumns of travel.
	originWorld: Vector3?,
	zLerpColumns: number?,
	worldZEnd: number?,
	-- Bubble Barrage only: gold light-streak trail (normal BubbleTrap stays trail-less).
	streak: boolean?,
}

export type ActiveProjectile = {
	id: string,
	spec: LaunchSpec,
	column: number,
	part: BasePart,
	model: Model?,
	spinRadians: number,
	worldY: number,
	worldZ: number?,
	zStart: number?,
	zEnd: number?,
	zLerpColumns: number?,
}

type ImpactCallback = (
	instanceId: string,
	damage: number,
	ownerUserId: number,
	impact: ImpactSpec?,
	targetKind: string?,
	plotModel: Model?,
	row: number?,
	column: number?
) -> boolean
type GetColumnCallback = (instanceId: string, targetKind: string?) -> number?
type SetPositionCallback = (part: BasePart, plotModel: Model, row: number, column: number, worldY: number) -> ()

local active: { [string]: ActiveProjectile } = {}
local nextId = 0

local SCRIPT_CLASSES: { [string]: boolean } = {
	Script = true,
	LocalScript = true,
	ModuleScript = true,
}

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

local function stripScripts(root: Instance)
	for _, descendant in root:GetDescendants() do
		if SCRIPT_CLASSES[descendant.ClassName] or descendant:IsA("Tool") or descendant:IsA("Sound") then
			descendant:Destroy()
		end
	end
end

local function pickPrimary(model: Model): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	local best: BasePart? = nil
	local bestVolume = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Transparency < 0.95 then
			local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
			if volume > bestVolume then
				bestVolume = volume
				best = descendant
			end
		end
	end
	return best
end

local function prepareAuthoredShuriken(model: Model): BasePart?
	stripScripts(model)
	local primary = pickPrimary(model)
	if not primary then
		return nil
	end
	model.PrimaryPart = primary

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			if descendant == primary then
				hardenRoot(descendant)
			else
				weldAccessory(primary, descendant)
			end
		end
	end

	local size = select(1, ModelUtil.getVisualSizeAndCenter(model))
	local extent = math.max(size.X, size.Z)
	local target = CombatConfig.SHURIKEN_TARGET_EXTENT
	if extent > 0.01 and target > 0.01 then
		local scale = math.clamp(target / extent, 0.05, 20)
		model:ScaleTo(model:GetScale() * scale)
		-- ScaleTo can leave weld/anchor inconsistent — re-harden.
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				if descendant == model.PrimaryPart then
					hardenRoot(descendant)
				else
					descendant.Anchored = false
					descendant.CanCollide = false
					descendant.CanTouch = false
					descendant.CanQuery = false
					descendant.Massless = true
				end
			end
		end
	end

	model.Name = "ShurikenProjectile"
	model:SetAttribute("ProjectileKind", "Shuriken")
	primary:SetAttribute("ProjectileKind", "Shuriken")
	return primary
end

--[[
	Procedural shuriken: a flat 4-point star (thin disc + wedge blades) built
	flat in the world XZ plane. Fallback when Assets.Projectiles is missing.
]]
local function createProceduralShuriken(): (Model, BasePart)
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

local function createShurikenModel(): (Model, BasePart)
	local template = ModelUtil.findProjectileTemplate(CombatConfig.SHURIKEN_MODEL_ID)
	if template then
		local model = template:Clone()
		local primary = prepareAuthoredShuriken(model)
		if primary then
			return model, primary
		end
		model:Destroy()
		log:warn("Assets.Projectiles." .. CombatConfig.SHURIKEN_MODEL_ID .. " has no BasePart — using procedural")
	elseif not missingShurikenLogged then
		missingShurikenLogged = true
		log:warn(string.format(
			"missing Assets.Projectiles.%s — using procedural shuriken (move your model there in Studio)",
			CombatConfig.SHURIKEN_MODEL_ID
		))
	end
	return createProceduralShuriken()
end

local function applyPierceAura(model: Model, hub: BasePart)
	model:SetAttribute("PiercingBrew", true)
	hub:SetAttribute("PiercingBrew", true)

	local gold = VfxConfig.PIERCE_SHURIKEN_AURA_COLOR
	local highlight = Instance.new("Highlight")
	highlight.Name = "PierceAura"
	highlight.Adornee = model
	highlight.FillColor = gold
	highlight.FillTransparency = 0.78
	highlight.OutlineColor = gold:Lerp(Color3.fromRGB(255, 255, 255), 0.35)
	highlight.OutlineTransparency = 0.05
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model

	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "PierceSparks"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 230)),
		ColorSequenceKeypoint.new(0.45, gold),
		ColorSequenceKeypoint.new(1, gold:Lerp(Color3.fromRGB(255, 120, 30), 0.25)),
	})
	sparks.LightEmission = 1
	sparks.Brightness = 3.4
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.42),
		NumberSequenceKeypoint.new(0.55, 0.22),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparks.Lifetime = NumberRange.new(0.18, 0.4)
	sparks.Speed = NumberRange.new(1.5, 5)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = 36
	sparks.Rotation = NumberRange.new(0, 360)
	sparks.RotSpeed = NumberRange.new(-120, 120)
	sparks.Drag = 1.2
	sparks.ZOffset = 2
	sparks.Parent = hub

	-- Ribbon perpendicular to +X travel so the gold trail actually has area.
	-- Authored shurikens often ship a silver Trail — replace it so only gold shows.
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Trail") then
			descendant:Destroy()
		end
	end

	local gold = VfxConfig.PIERCE_SHURIKEN_TRAIL_COLOR
	local tail = VfxConfig.PIERCE_SHURIKEN_TRAIL_COLOR_TAIL
	local att0 = Instance.new("Attachment")
	att0.Name = "PierceTrailA"
	att0.Position = Vector3.new(0, 0.42, 0)
	att0.Parent = hub
	local att1 = Instance.new("Attachment")
	att1.Name = "PierceTrailB"
	att1.Position = Vector3.new(0, -0.42, 0)
	att1.Parent = hub
	local trail = Instance.new("Trail")
	trail.Name = "PierceTrail"
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, gold),
		ColorSequenceKeypoint.new(1, tail),
	})
	trail.Lifetime = VfxConfig.PIERCE_SHURIKEN_TRAIL_LIFETIME
	trail.WidthScale = NumberSequence.new(VfxConfig.PIERCE_SHURIKEN_TRAIL_WIDTH)
	trail.LightEmission = VfxConfig.PIERCE_SHURIKEN_TRAIL_LIGHT_EMISSION
	trail.Transparency = NumberSequence.new(0, 1)
	trail.FaceCamera = true
	trail.MinLength = 0.4
	trail.MaxLength = 32
	trail.Parent = hub
end

local function createProceduralArrow(): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "ArrowProjectile"

	local shaft = Instance.new("Part")
	shaft.Name = "Shaft"
	shaft.Size = CombatConfig.ARROW_FALLBACK_SIZE
	shaft.Material = Enum.Material.Wood
	shaft.Color = CombatConfig.ARROW_FALLBACK_COLOR
	shaft.Parent = model
	hardenRoot(shaft)
	model.PrimaryPart = shaft
	model:SetAttribute("ProjectileKind", "Arrow")
	shaft:SetAttribute("ProjectileKind", "Arrow")
	return model, shaft
end

local missingArrowLogged = false

local function prepareAuthoredArrow(model: Model): BasePart?
	stripScripts(model)
	local primary = pickPrimary(model)
	if not primary then
		return nil
	end
	model.PrimaryPart = primary
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			if descendant == primary then
				hardenRoot(descendant)
			else
				weldAccessory(primary, descendant)
			end
		end
	end
	model.Name = "ArrowProjectile"
	model:SetAttribute("ProjectileKind", "Arrow")
	primary:SetAttribute("ProjectileKind", "Arrow")
	return primary
end

local function createArrowModel(): (Model, BasePart)
	local folder = ModelUtil.getProjectileTemplatesFolder()
	local child = if folder then folder:FindFirstChild(CombatConfig.ARROW_MODEL_ID) else nil

	if child and child:IsA("Model") then
		local model = child:Clone()
		local primary = prepareAuthoredArrow(model)
		if primary then
			return model, primary
		end
		model:Destroy()
		log:warn("Assets.Projectiles." .. CombatConfig.ARROW_MODEL_ID .. " has no BasePart — using procedural")
	elseif child and child:IsA("BasePart") then
		local model = Instance.new("Model")
		model.Name = "ArrowProjectile"
		local part = child:Clone()
		part.Name = "Arrow"
		part.Parent = model
		model.PrimaryPart = part
		local primary = prepareAuthoredArrow(model)
		if primary then
			return model, primary
		end
		model:Destroy()
		log:warn("Assets.Projectiles." .. CombatConfig.ARROW_MODEL_ID .. " clone failed — using procedural")
	elseif not missingArrowLogged then
		missingArrowLogged = true
		log:warn(string.format(
			"missing Assets.Projectiles.%s — using procedural arrow",
			CombatConfig.ARROW_MODEL_ID
		))
	end
	return createProceduralArrow()
end

local function arrowFlightCFrame(position: Vector3, columnDirection: number): CFrame
	local o = CombatConfig.ARROW_MODEL_ORIENTATION_DEGREES
	local orient = CFrame.Angles(math.rad(o.X), math.rad(o.Y), math.rad(o.Z))
	local look = Vector3.new(columnDirection, 0, 0)
	if look.Magnitude < 0.01 then
		look = Vector3.new(-1, 0, 0)
	end
	return CFrame.lookAt(position, position + look) * orient
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

local function createBubbleModel(isSeed: boolean): (Model, BasePart)
	local size = if isSeed then CombatConfig.BUBBLE_PROJECTILE_SEED_SIZE else CombatConfig.BUBBLE_PROJECTILE_SIZE
	local gold = VfxConfig.BUBBLE_PROJECTILE_COLOR
	local innerColor = VfxConfig.BUBBLE_PROJECTILE_INNER_COLOR

	local model = Instance.new("Model")
	model.Name = if isSeed then "BubbleSeed" else "BubbleProjectile"

	local hub = Instance.new("Part")
	hub.Name = "Bubble"
	hub.Shape = Enum.PartType.Ball
	hub.Size = size
	hub.Material = Enum.Material.ForceField
	hub.Color = gold
	hub.Transparency = CombatConfig.BUBBLE_PROJECTILE_TRANSPARENCY
	hub.Parent = model
	hardenRoot(hub)
	model.PrimaryPart = hub

	local inner = Instance.new("Part")
	inner.Name = "BubbleCore"
	inner.Shape = Enum.PartType.Ball
	inner.Size = size * 0.62
	inner.Material = Enum.Material.Glass
	inner.Color = innerColor
	inner.Transparency = 0.42
	inner.Reflectance = 0.35
	inner.CFrame = hub.CFrame
	inner.Parent = model
	weldAccessory(hub, inner)

	local highlight = Instance.new("Highlight")
	highlight.Name = "BubbleRim"
	highlight.Adornee = model
	highlight.FillColor = gold
	highlight.FillTransparency = 0.82
	highlight.OutlineColor = gold:Lerp(Color3.fromRGB(255, 255, 220), 0.35)
	highlight.OutlineTransparency = 0.05
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model

	model:SetAttribute("ProjectileKind", "Bubble")
	hub:SetAttribute("ProjectileKind", "Bubble")
	return model, hub
end

local function applyBarrageStreak(model: Model, hub: BasePart)
	model:SetAttribute("BubbleBarrage", true)
	hub:SetAttribute("BubbleBarrage", true)

	local gold = VfxConfig.BUBBLE_BARRAGE_STREAK_COLOR
	local tail = VfxConfig.BUBBLE_BARRAGE_STREAK_COLOR_TAIL
	local att0 = Instance.new("Attachment")
	att0.Name = "BarrageStreakA"
	att0.Position = Vector3.new(0, 0.4, 0)
	att0.Parent = hub
	local att1 = Instance.new("Attachment")
	att1.Name = "BarrageStreakB"
	att1.Position = Vector3.new(0, -0.4, 0)
	att1.Parent = hub
	local trail = Instance.new("Trail")
	trail.Name = "BarrageStreak"
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, gold),
		ColorSequenceKeypoint.new(1, tail),
	})
	trail.Lifetime = VfxConfig.BUBBLE_BARRAGE_STREAK_LIFETIME
	trail.WidthScale = NumberSequence.new(VfxConfig.BUBBLE_BARRAGE_STREAK_WIDTH)
	trail.LightEmission = 1
	trail.Transparency = NumberSequence.new(0.05, 1)
	trail.FaceCamera = true
	trail.MinLength = 0.5
	trail.MaxLength = 36
	trail.Parent = hub
end

local function destroyProjectile(projectile: ActiveProjectile)
	if projectile.model then
		projectile.model:Destroy()
	elseif projectile.part.Parent then
		projectile.part:Destroy()
	end
end

local function shurikenFlightCFrame(position: Vector3, spinRadians: number): CFrame
	local o = CombatConfig.SHURIKEN_MODEL_ORIENTATION_DEGREES
	local orient = CFrame.Angles(math.rad(o.X), math.rad(o.Y), math.rad(o.Z))
	return CFrame.new(position) * CFrame.fromAxisAngle(Vector3.yAxis, spinRadians) * orient
end

local function applyHeldZ(part: BasePart, worldY: number, worldZ: number?): Vector3
	local pos = part.Position
	if worldZ == nil then
		return Vector3.new(pos.X, worldY, pos.Z)
	end
	return Vector3.new(pos.X, worldY, worldZ)
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
		local pierceCount = if spec.impact then spec.impact.pierceCount else nil
		if type(pierceCount) == "number" and pierceCount > 0 then
			applyPierceAura(shurikenModel, hub)
		end
		shurikenModel.Parent = folder
	elseif kind == "Arrow" then
		local arrowModel, hub = createArrowModel()
		model = arrowModel
		part = hub
		arrowModel.Parent = folder
	elseif kind == "Bubble" then
		local isSeed = spec.targetKind == "Split"
		local bubbleModel, hub = createBubbleModel(isSeed)
		model = bubbleModel
		part = hub
		if spec.streak then
			applyBarrageStreak(bubbleModel, hub)
		end
		bubbleModel.Parent = folder
	else
		part = createBoltPart()
		part.Parent = folder
	end

	setWorldPosition(part, spec.plotModel, spec.row, spec.startColumn, worldY)
	if spec.originWorld then
		part.CFrame = CFrame.new(spec.originWorld)
	end
	local held = applyHeldZ(part, worldY, spec.worldZ or (if spec.originWorld then spec.originWorld.Z else nil))
	if model then
		local dir = spec.columnDirection or 1
		if kind == "Arrow" then
			part.CFrame = arrowFlightCFrame(held, dir)
		elseif kind == "Bubble" then
			part.CFrame = CFrame.new(if spec.originWorld then spec.originWorld else held)
		else
			part.CFrame = shurikenFlightCFrame(held, 0)
		end
	elseif spec.worldZ ~= nil then
		part.CFrame = CFrame.new(held)
	end

	active[id] = {
		id = id,
		spec = spec,
		column = spec.startColumn,
		part = part,
		model = model,
		spinRadians = 0,
		worldY = worldY,
		worldZ = spec.worldZ,
		zStart = if spec.originWorld then spec.originWorld.Z else nil,
		zEnd = spec.worldZEnd,
		zLerpColumns = spec.zLerpColumns,
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
		local liveColumn = if projectile.spec.targetKind == "Grave"
			or projectile.spec.targetKind == "LaneEnd"
			or projectile.spec.targetKind == "Split"
			then projectile.spec.targetColumn
			else getColumn(projectile.spec.targetInstanceId, projectile.spec.targetKind)
		if not liveColumn then
			destroyProjectile(projectile)
			active[id] = nil
			continue
		end

		local dir = projectile.spec.columnDirection or 1
		projectile.column += CombatConfig.PROJECTILE_COLUMNS_PER_SECOND * dt * dir
		setWorldPosition(
			projectile.part,
			projectile.spec.plotModel,
			projectile.spec.row,
			projectile.column,
			projectile.worldY
		)

		local travelZ = projectile.worldZ
		local zStart = projectile.zStart
		local zEnd = projectile.zEnd
		local zLerp = projectile.zLerpColumns
		if type(zStart) == "number" and type(zEnd) == "number" and type(zLerp) == "number" and zLerp > 0 then
			local traveled = math.abs(projectile.column - projectile.spec.startColumn)
			local alpha = math.clamp(traveled / zLerp, 0, 1)
			alpha = alpha * alpha * (3 - 2 * alpha)
			travelZ = zStart + (zEnd - zStart) * alpha
		end
		local held = applyHeldZ(projectile.part, projectile.worldY, travelZ)
		local kind = projectile.spec.kind or "Knife"
		if projectile.model then
			if kind == "Arrow" then
				projectile.part.CFrame = arrowFlightCFrame(held, dir)
			elseif kind == "Bubble" then
				projectile.part.CFrame = CFrame.new(held)
			else
				projectile.spinRadians += CombatConfig.SHURIKEN_SPIN_RADIANS_PER_SECOND * dt
				projectile.part.CFrame = shurikenFlightCFrame(held, projectile.spinRadians)
			end
		elseif travelZ ~= nil then
			projectile.part.CFrame = CFrame.new(held)
		end

		local reached = if dir < 0
			then projectile.column <= liveColumn
			else projectile.column >= liveColumn
		if reached then
			onImpact(
				projectile.spec.targetInstanceId,
				projectile.spec.damage,
				projectile.spec.ownerUserId,
				projectile.spec.impact,
				projectile.spec.targetKind,
				projectile.spec.plotModel,
				projectile.spec.row,
				projectile.spec.targetColumn
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
