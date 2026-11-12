--!strict
local BattleClock = require(game:GetService("ReplicatedStorage").Shared.Utilities.BattleClock)
--[[
	Projectile
	Server-authoritative lane projectiles. Moves along a row (+X) until it
	reaches its target, then applies damage (and optional status) through a
	callback. Appearance is data-driven via LaunchSpec.kind.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local GridConfig = require(ReplicatedStorage.Shared.Config.GridConfig)
local VfxConfig = require(ReplicatedStorage.Shared.Config.VfxConfig)
local Types = require(ReplicatedStorage.Shared.Types)
local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)
local ModelUtil = require(ReplicatedStorage.Shared.Utilities.ModelUtil)
local VfxLoad = require(ReplicatedStorage.Shared.Utilities.VfxLoad)

local LANE_END_ID = "LaneEnd"

local Projectile = {}

local log = Logger.new("Projectile")
local missingShurikenLogged = false
local missingBatLogged = false
local missingArrowLogged = false
local missingPineappleLogged = false

export type ImpactSpec = {
	soundKey: string?,
	statusKind: Types.StatusEffectKind?,
	statusDuration: number?,
	statusMagnitude: number?,
	statusVisual: string?,
	sourceBrainrotId: string?,
	sourceInstanceId: string?,
	sourceMonsterId: string?,
	pierceCount: number?,
	-- Piercing Brew: fly through graves (no grave HP / shake) to the next monster.
	pierceGraves: boolean?,
	-- Keep flying through every remaining monster, then to the last lawn tile.
	pierceAll: boolean?,
	-- Two Shadow Requiem waves share this so each monster is damaged once.
	waveGroupId: string?,
	-- Last-tile white pillar + optional extra damage (once per waveGroupId).
	waveFinale: boolean?,
	laneEndBonus: number?,
	-- Shadow Requiem: plant tile + extra HP per lawn tile past the first.
	waveOriginColumn: number?,
	waveTravelBonus: number?,
	-- Juice Splash: damage the monster this shot jumped over.
	splashInstanceId: string?,
	splashDamage: number?,
	-- Overripe: flat damage to other monsters on the target's tile when this shot kills.
	overripeDamage: number?,
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
	-- "Knife" (legacy bolt), "Shuriken", "Bat", "Bubble", "Arrow", "Pineapple", or "SwordWave"
	kind: string?,
	impact: ImpactSpec?,
	-- Override CombatConfig.PROJECTILE_COLUMNS_PER_SECOND for this shot.
	columnsPerSecond: number?,
	-- Default "Monster". "Brainrot" = westbound shots (Skeleton arrows).
	targetKind: string?,
	-- Grid travel: +1 toward the forest, −1 toward the house.
	columnDirection: number?,
	-- Keep this Z for the whole flight (bow / arm spawn). Nil = lane-center Z.
	worldZ: number?,
	-- Peak studs above the lane during flight (pineapple lob). Nil = flat.
	arcHeight: number?,
	-- Multiplier on the fitted pineapple size (Pineapple Express).
	modelScale: number?,
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
	waveHue: number?,
	finaleAt: number?,
	releaseVfx: (() -> ())?,
}

local function impactPiercesAll(impact: ImpactSpec?): boolean
	return impact ~= nil and impact.pierceAll == true
end

local function swordWaveLaneEndColumn(): number
	return GridConfig.COLUMNS + CombatConfig.SWORD_WAVE_EAST_EDGE
end

-- Returns killed, then an optional next instance id so piercing shots keep flying.
type ImpactCallback = (
	instanceId: string,
	damage: number,
	ownerUserId: number,
	impact: ImpactSpec?,
	targetKind: string?,
	plotModel: Model?,
	row: number?,
	column: number?
) -> (boolean, string?)
type GetColumnCallback = (instanceId: string, targetKind: string?) -> number?
type SetPositionCallback = (part: BasePart, plotModel: Model, row: number, column: number, worldY: number) -> ()
-- Called after a pierce-all wave moves, with the column band it just covered.
type SweepCallback = (
	plotModel: Model,
	row: number,
	fromColumn: number,
	toColumn: number,
	damage: number,
	ownerUserId: number,
	impact: ImpactSpec?
) -> ()

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

-- Stand the star so its thinnest axis is +Z (across the row). The disc sits
-- in XY: upright, sharp rim leading +X toward monsters. Spin about +Z.
local function bakeShurikenStand(model: Model, hub: BasePart)
	model:PivotTo(CFrame.new())
	local size = select(1, ModelUtil.getVisualSizeAndCenter(model))
	local stand = CFrame.Angles(math.rad(90), 0, 0)
	if size.Z <= size.X and size.Z <= size.Y then
		stand = CFrame.new()
	elseif size.X <= size.Y and size.X <= size.Z then
		stand = CFrame.Angles(0, math.rad(90), 0)
	end
	local rx, ry, rz = stand:ToEulerAnglesXYZ()
	hub:SetAttribute("ShurikenStandX", math.deg(rx))
	hub:SetAttribute("ShurikenStandY", math.deg(ry))
	hub:SetAttribute("ShurikenStandZ", math.deg(rz))
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
	bakeShurikenStand(model, primary)
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
	hub.Shape = Enum.PartType.Ball
	hub.Size = Vector3.new(
		CombatConfig.SHURIKEN_HUB_SIZE.Y,
		CombatConfig.SHURIKEN_HUB_SIZE.Y,
		CombatConfig.SHURIKEN_HUB_SIZE.Y
	)
	hub.Material = Enum.Material.Metal
	hub.Color = CombatConfig.SHURIKEN_HUB_COLOR
	hub.CFrame = CFrame.new()
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
	bakeShurikenStand(model, hub)
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

local function prepareAuthoredBat(model: Model): BasePart?
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
	local extent = math.max(size.X, size.Y, size.Z)
	local target = CombatConfig.BAT_TARGET_EXTENT
	if extent > 0.01 and target > 0.01 then
		local scale = math.clamp(target / extent, 0.05, 20)
		model:ScaleTo(model:GetScale() * scale)
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

	model.Name = "BatProjectile"
	model:SetAttribute("ProjectileKind", "Bat")
	primary:SetAttribute("ProjectileKind", "Bat")
	return primary
end

local function createProceduralBat(): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "BatProjectile"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = CombatConfig.BAT_FALLBACK_HANDLE_SIZE
	handle.Material = Enum.Material.Wood
	handle.Color = CombatConfig.BAT_FALLBACK_HANDLE_COLOR
	handle.Parent = model
	hardenRoot(handle)

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = CombatConfig.BAT_FALLBACK_HEAD_SIZE
	head.Material = Enum.Material.Wood
	head.Color = CombatConfig.BAT_FALLBACK_HEAD_COLOR
	head.CFrame = CFrame.new(handle.Size.X * 0.38, 0, 0)
	head.Parent = model
	weldAccessory(handle, head)

	model.PrimaryPart = handle
	model:SetAttribute("ProjectileKind", "Bat")
	handle:SetAttribute("ProjectileKind", "Bat")
	return model, handle
end

local function createBatModel(): (Model, BasePart)
	local folder = ModelUtil.getProjectileTemplatesFolder()
	local child = if folder then folder:FindFirstChild(CombatConfig.BAT_MODEL_ID) else nil

	if child and child:IsA("Model") then
		local model = child:Clone()
		local primary = prepareAuthoredBat(model)
		if primary then
			return model, primary
		end
		model:Destroy()
		log:warn("Assets.Projectiles." .. CombatConfig.BAT_MODEL_ID .. " has no BasePart — using procedural")
	elseif child and child:IsA("BasePart") then
		local model = Instance.new("Model")
		model.Name = "BatProjectile"
		local part = child:Clone()
		part.Name = "Bat"
		part.Parent = model
		model.PrimaryPart = part
		local primary = prepareAuthoredBat(model)
		if primary then
			return model, primary
		end
		model:Destroy()
		log:warn("Assets.Projectiles." .. CombatConfig.BAT_MODEL_ID .. " clone failed — using procedural")
	elseif not missingBatLogged then
		missingBatLogged = true
		log:warn(string.format(
			"missing Assets.Projectiles.%s — using procedural bat (move your model there in Studio)",
			CombatConfig.BAT_MODEL_ID
		))
	end
	return createProceduralBat()
end

local function batFlightCFrame(position: Vector3, spinRadians: number): CFrame
	local o = CombatConfig.BAT_MODEL_ORIENTATION_DEGREES
	local orient = CFrame.Angles(math.rad(o.X), math.rad(o.Y), math.rad(o.Z))
	-- End-over-end along +X (lane). Tune BAT_MODEL_ORIENTATION_DEGREES if the mesh tumbles on the wrong axis.
	return CFrame.new(position) * CFrame.fromAxisAngle(Vector3.zAxis, spinRadians) * orient
end

local function goldSparkSequence(aura: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 230)),
		ColorSequenceKeypoint.new(0.4, aura),
		ColorSequenceKeypoint.new(1, aura:Lerp(Color3.fromRGB(255, 120, 30), 0.3)),
	})
end

local function addPierceSparkCloud(hub: BasePart, aura: Color3)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "PierceSparks"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = goldSparkSequence(aura)
	sparks.LightEmission = 0.85
	sparks.Brightness = 4
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, VfxConfig.PIERCE_SHURIKEN_SPARK_SIZE),
		NumberSequenceKeypoint.new(0.45, VfxConfig.PIERCE_SHURIKEN_SPARK_SIZE * 0.55),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.04),
		NumberSequenceKeypoint.new(0.65, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparks.Lifetime = VfxConfig.PIERCE_SHURIKEN_SPARK_LIFETIME
	sparks.Speed = VfxConfig.PIERCE_SHURIKEN_SPARK_SPEED
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = VfxConfig.PIERCE_SHURIKEN_SPARK_RATE
	sparks.Rotation = NumberRange.new(0, 360)
	sparks.RotSpeed = NumberRange.new(-180, 180)
	sparks.Drag = 2.4
	sparks.Acceleration = Vector3.new(0, 6, 0)
	sparks.Shape = Enum.ParticleEmitterShape.Sphere
	sparks.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	sparks.LockedToPart = false
	sparks.ZOffset = 1.4
	sparks.Parent = hub

	local embers = Instance.new("ParticleEmitter")
	embers.Name = "PierceEmbers"
	embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	embers.Color = goldSparkSequence(aura)
	embers.LightEmission = 1
	embers.Brightness = 5.5
	embers.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.28),
		NumberSequenceKeypoint.new(0.35, 0.16),
		NumberSequenceKeypoint.new(1, 0),
	})
	embers.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.02),
		NumberSequenceKeypoint.new(1, 1),
	})
	embers.Lifetime = VfxConfig.PIERCE_SHURIKEN_EMBER_LIFETIME
	embers.Speed = VfxConfig.PIERCE_SHURIKEN_EMBER_SPEED
	embers.SpreadAngle = Vector2.new(180, 180)
	embers.Rate = VfxConfig.PIERCE_SHURIKEN_EMBER_RATE
	embers.Squash = NumberSequence.new(-1.4)
	embers.Orientation = Enum.ParticleOrientation.VelocityParallel
	embers.Drag = 3.2
	embers.Acceleration = Vector3.new(-10, 2, 0)
	embers.Shape = Enum.ParticleEmitterShape.Sphere
	embers.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	embers.LockedToPart = false
	embers.ZOffset = 1.8
	embers.Parent = hub

	sparks:Emit(12)
	embers:Emit(8)
end

local function applyPierceAura(model: Model, hub: BasePart)
	model:SetAttribute("PiercingBrew", true)
	hub:SetAttribute("PiercingBrew", true)

	local auraGold = VfxConfig.PIERCE_SHURIKEN_AURA_COLOR
	local highlight = Instance.new("Highlight")
	highlight.Name = "PierceAura"
	highlight.Adornee = model
	highlight.FillColor = auraGold
	highlight.FillTransparency = 0.78
	highlight.OutlineColor = auraGold:Lerp(Color3.fromRGB(255, 255, 255), 0.35)
	highlight.OutlineTransparency = 0.05
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model

	addPierceSparkCloud(hub, auraGold)

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

local function blackSequence(): ColorSequence
	local ink = VfxConfig.SWORD_WAVE_COLOR
	local edge = VfxConfig.SWORD_WAVE_COLOR_EDGE
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, edge),
		ColorSequenceKeypoint.new(0.45, ink),
		ColorSequenceKeypoint.new(1, ink),
	})
end

local function poseArcSegment(
	part: BasePart,
	fromPos: Vector3,
	toPos: Vector3,
	stroke: number,
	width: number,
	color: Color3,
	transparency: number
)
	local delta = toPos - fromPos
	local length = delta.Magnitude
	if length < 0.05 then
		part.Transparency = 1
		return
	end
	local mid = fromPos:Lerp(toPos, 0.5)
	part.Size = Vector3.new(stroke, width, length)
	part.CFrame = CFrame.lookAt(mid, toPos, Vector3.zAxis)
	part.Color = color
	part.Transparency = transparency
end

-- Vertical backwards-C: bulge at the hub (east / +X), tips west and up/down.
-- Extra west pull near |t|=1 so the last chord aims into a needle.
local function swordWavePoint(hub: Vector3, height: number, bow: number, t: number): Vector3
	local u = math.abs(t)
	local back = bow * (u * u * (1 + 0.7 * u * u)) / 1.7
	return hub + Vector3.new(-back, t * height * 0.5, 0)
end

-- Cluster samples at ±1 so tip chords stay short.
local function swordWaveSampleT(i: number, segments: number): number
	return -math.cos(math.pi * i / segments)
end

local function swordWaveTaper(t: number): number
	local u = math.abs(t)
	local start = VfxConfig.SWORD_WAVE_TIP_START
	if u <= start then
		return 1
	end
	local v = (u - start) / math.max(1 - start, 0.01)
	local minScale = VfxConfig.SWORD_WAVE_TIP_MIN
	return minScale + (1 - minScale) * (1 - v) * (1 - v)
end

local function addFlameStreak(parent: BasePart)
	local att = Instance.new("Attachment")
	att.Name = "FlameAtt"
	att.Parent = parent

	local fire = Instance.new("ParticleEmitter")
	fire.Name = "SwordWaveFlame"
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Color = blackSequence()
	fire.LightEmission = 0
	fire.Brightness = 0.8
	fire.Orientation = Enum.ParticleOrientation.VelocityParallel
	fire.Squash = NumberSequence.new(-1.7)
	fire.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.05),
		NumberSequenceKeypoint.new(0.32, 1.45),
		NumberSequenceKeypoint.new(1, 0.12),
	})
	fire.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.04),
		NumberSequenceKeypoint.new(0.4, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	fire.Lifetime = VfxConfig.SWORD_WAVE_FLAME_LIFETIME
	fire.Speed = VfxConfig.SWORD_WAVE_FLAME_SPEED
	fire.SpreadAngle = VfxConfig.SWORD_WAVE_FLAME_SPREAD
	fire.Rate = VfxConfig.SWORD_WAVE_FLAME_RATE
	fire.Acceleration = Vector3.new(-32, 0, 0)
	fire.Drag = 1.6
	fire.EmissionDirection = Enum.NormalId.Front
	fire.LockedToPart = false
	fire.ZOffset = 1.2
	fire.Parent = att

	local trailA = Instance.new("Attachment")
	trailA.Name = "WakeTrailA"
	trailA.Parent = parent
	local trailB = Instance.new("Attachment")
	trailB.Name = "WakeTrailB"
	trailB.Parent = parent
	local trail = Instance.new("Trail")
	trail.Name = "WakeTrail"
	trail.Attachment0 = trailA
	trail.Attachment1 = trailB
	trail.Color = blackSequence()
	trail.Lifetime = VfxConfig.SWORD_WAVE_TRAIL_LIFETIME
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, VfxConfig.SWORD_WAVE_TRAIL_WIDTH),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	trail.LightEmission = 0
	trail.Transparency = NumberSequence.new(0.12, 1)
	trail.FaceCamera = true
	trail.MinLength = 0.4
	trail.MaxLength = 28
	trail.Parent = parent
end

local function applySwordWaveAura(model: Model, hub: BasePart)
	local highlight = Instance.new("Highlight")
	highlight.Name = "SwordWaveRim"
	highlight.Adornee = model
	highlight.FillColor = VfxConfig.SWORD_WAVE_COLOR_INNER
	highlight.FillTransparency = 1
	highlight.OutlineColor = VfxConfig.SWORD_WAVE_COLOR
	highlight.OutlineTransparency = 0.12
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model

	local glow = Instance.new("PointLight")
	glow.Name = "SwordWaveGlow"
	glow.Brightness = 0
	glow.Range = VfxConfig.SWORD_WAVE_GLOW_RANGE
	glow.Color = VfxConfig.SWORD_WAVE_COLOR_INNER
	glow.Parent = hub
end

local function createSwordWaveModel(quality: VfxLoad.Quality): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "SwordWaveProjectile"

	local hub = Instance.new("Part")
	hub.Name = "WaveHub"
	hub.Size = Vector3.new(0.2, 0.2, 0.2)
	hub.Transparency = 1
	hub.Material = Enum.Material.Neon
	hub.Color = VfxConfig.SWORD_WAVE_COLOR
	hub.Parent = model
	hardenRoot(hub)
	model.PrimaryPart = hub

	local flameEvery = math.max(1, VfxConfig.SWORD_WAVE_FLAME_EVERY)
	if quality == "Reduced" then
		flameEvery = math.max(flameEvery * 2, 4)
	end
	local spawnFlames = quality ~= "Minimal"

	local segments = VfxConfig.SWORD_WAVE_SEGMENTS
	for i = 1, segments do
		local seg = Instance.new("Part")
		seg.Name = string.format("WaveSeg%d", i)
		seg.Size = Vector3.new(VfxConfig.SWORD_WAVE_STROKE, VfxConfig.SWORD_WAVE_WIDTH, 1)
		seg.Material = Enum.Material.Neon
		seg.Color = VfxConfig.SWORD_WAVE_COLOR_INNER
		seg.Transparency = CombatConfig.SWORD_WAVE_TRANSPARENCY
		seg.Parent = model
		hardenRoot(seg)
		if spawnFlames and (i - 1) % flameEvery == 0 then
			addFlameStreak(seg)
		end

		local wake = Instance.new("Part")
		wake.Name = string.format("WaveWake%d", i)
		wake.Size = Vector3.new(VfxConfig.SWORD_WAVE_WAKE_STROKE, VfxConfig.SWORD_WAVE_WIDTH * 0.85, 1)
		wake.Material = Enum.Material.SmoothPlastic
		wake.Color = VfxConfig.SWORD_WAVE_COLOR
		wake.Transparency = 0.45
		wake.Parent = model
		hardenRoot(wake)
	end

	if quality == "Reduced" then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("ParticleEmitter") then
				descendant.Rate = descendant.Rate * 0.5
			end
		end
	end

	applySwordWaveAura(model, hub)
	model:SetAttribute("ProjectileKind", "SwordWave")
	hub:SetAttribute("ProjectileKind", "SwordWave")
	return model, hub
end

local function swordWaveCFrame(position: Vector3): CFrame
	return CFrame.new(position)
end

local function applySwordWaveLook(projectile: ActiveProjectile, dt: number)
	local model = projectile.model
	if not model then
		return
	end

	local traveled = math.max(0, projectile.column - projectile.spec.startColumn)
	local growSpan = math.max(CombatConfig.SWORD_WAVE_GROW_COLUMNS, 0.01)
	local growth = math.clamp(traveled / growSpan, 0, 1)
	growth = growth * growth * (3 - 2 * growth)

	local height = VfxConfig.SWORD_WAVE_START_HEIGHT
		+ (VfxConfig.SWORD_WAVE_END_HEIGHT - VfxConfig.SWORD_WAVE_START_HEIGHT) * growth
	local bow = VfxConfig.SWORD_WAVE_BOW
	local width = VfxConfig.SWORD_WAVE_WIDTH
	local stroke = VfxConfig.SWORD_WAVE_STROKE
	local wakeStroke = VfxConfig.SWORD_WAVE_WAKE_STROKE

	local fade = 0
	local fadeColumns = CombatConfig.SWORD_WAVE_FADE_COLUMNS
	if fadeColumns > 0 then
		local eastEdge = swordWaveLaneEndColumn()
		local fadeFrom = GridConfig.COLUMNS - fadeColumns
		local fadeSpan = math.max(eastEdge - fadeFrom, 0.01)
		fade = math.clamp((projectile.column - fadeFrom) / fadeSpan, 0, 1)
	end
	local baseT = CombatConfig.SWORD_WAVE_TRANSPARENCY
	local transparency = baseT + (1 - baseT) * fade

	local ink = VfxConfig.SWORD_WAVE_COLOR
	local inner = VfxConfig.SWORD_WAVE_COLOR_INNER
	local hubPos = projectile.part.Position
	local segments = VfxConfig.SWORD_WAVE_SEGMENTS
	for i = 1, segments do
		local seg = model:FindFirstChild(string.format("WaveSeg%d", i))
		if not (seg and seg:IsA("BasePart")) then
			continue
		end
		local t0 = swordWaveSampleT(i - 1, segments)
		local t1 = swordWaveSampleT(i, segments)
		local a = swordWavePoint(hubPos, height, bow, t0)
		local b = swordWavePoint(hubPos, height, bow, t1)
		local taper = swordWaveTaper(math.max(math.abs(t0), math.abs(t1)))
		local tipStroke = stroke * taper
		local tipWake = wakeStroke * taper
		local tipWidth = width * (0.18 + 0.82 * taper)
		-- Thicker black crescent first so it reads as the wave outline.
		local wake = model:FindFirstChild(string.format("WaveWake%d", i))
		if wake and wake:IsA("BasePart") then
			poseArcSegment(
				wake,
				a,
				b,
				tipWake,
				tipWidth * 1.2,
				ink,
				math.clamp(transparency * 0.55, 0, 1)
			)
		end
		poseArcSegment(seg, a, b, tipStroke, tipWidth, inner, transparency)

		local flameAtt = seg:FindFirstChild("FlameAtt")
		if flameAtt and flameAtt:IsA("Attachment") then
			flameAtt.WorldCFrame = CFrame.lookAt(seg.Position, seg.Position + Vector3.new(-1, 0, 0))
			local flame = flameAtt:FindFirstChild("SwordWaveFlame")
			if flame and flame:IsA("ParticleEmitter") then
				local flameOn = fade < 0.95 and taper > 0.28
				flame.Enabled = flameOn
				flame.Rate = if flameOn
					then VfxConfig.SWORD_WAVE_FLAME_RATE * (1 - fade) * taper
					else 0
			end
		end
		local trailB = seg:FindFirstChild("WakeTrailB")
		if trailB and trailB:IsA("Attachment") then
			trailB.Position = seg.CFrame:VectorToObjectSpace(Vector3.new(-4.6 * taper, 0, 0))
		end
		local trail = seg:FindFirstChild("WakeTrail")
		if trail and trail:IsA("Trail") then
			trail.Color = blackSequence()
			trail.Transparency = NumberSequence.new(math.clamp(0.12 + fade * 0.85, 0, 1), 1)
			trail.WidthScale = NumberSequence.new({
				NumberSequenceKeypoint.new(0, VfxConfig.SWORD_WAVE_TRAIL_WIDTH * taper),
				NumberSequenceKeypoint.new(1, 0.15 * taper),
			})
		end
	end

	local glow = projectile.part:FindFirstChild("SwordWaveGlow")
	if glow and glow:IsA("PointLight") then
		glow.Color = inner
		glow.Brightness = 0
	end
	local highlight = model:FindFirstChild("SwordWaveRim")
	if highlight and highlight:IsA("Highlight") then
		highlight.FillColor = inner
		highlight.FillTransparency = 1
		highlight.OutlineColor = ink
		highlight.OutlineTransparency = 0.12 + 0.88 * fade
	end
end

local function makePillarCylinder(name: string, height: number, diameter: number, transparency: number): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(height, diameter, diameter)
	part.Material = Enum.Material.Neon
	part.Color = VfxConfig.SWORD_WAVE_COLOR_INNER
	part.Transparency = transparency
	hardenRoot(part)
	return part
end

type PillarSpiralSeg = {
	part: BasePart,
	t: number,
}

local function addPillarSpiralSeg(parent: Instance): BasePart
	local part = Instance.new("Part")
	part.Name = "PillarSpiral"
	part.Size = Vector3.new(VfxConfig.SWORD_WAVE_PILLAR_SPIRAL_THICKNESS, VfxConfig.SWORD_WAVE_PILLAR_SPIRAL_THICKNESS, 0.2)
	part.Material = Enum.Material.SmoothPlastic
	part.Color = VfxConfig.SWORD_WAVE_COLOR
	part.Transparency = 0
	hardenRoot(part)
	part.Parent = parent
	return part
end

local function posePillarSpiral(
	segs: { PillarSpiralSeg },
	origin: Vector3,
	diameter: number,
	rise: number,
	fullHeight: number,
	climb: number,
	transparency: number
)
	local radius = diameter * 0.5 * VfxConfig.SWORD_WAVE_PILLAR_SPIRAL_RADIUS
	local visibleHeight = fullHeight * math.clamp(rise, 0.08, 1)
	local twist = VfxConfig.SWORD_WAVE_PILLAR_SPIRAL_TURNS * math.pi * 2
	local thickness = VfxConfig.SWORD_WAVE_PILLAR_SPIRAL_THICKNESS
	local count = math.max(#segs, 1)
	local step = 1 / count
	local base = CFrame.new(origin)

	local function point(u: number): Vector3
		local wrapped = u % 1
		local angle = wrapped * twist
		return Vector3.new(math.cos(angle) * radius, wrapped * visibleHeight, math.sin(angle) * radius)
	end

	for _, seg in segs do
		local a = point(seg.t + climb)
		local b = point(seg.t + climb + step)
		local len = (b - a).Magnitude
		if len > visibleHeight * 0.45 or len < 0.02 then
			seg.part.Transparency = 1
		else
			seg.part.Transparency = transparency
			seg.part.Size = Vector3.new(thickness, thickness, len)
			seg.part.CFrame = base * CFrame.lookAt((a + b) * 0.5, b)
		end
	end
end

function Projectile.playSwordWaveFinale(plotModel: Model, worldPos: Vector3)
	local quality, release = VfxLoad.acquire(VfxConfig.HEAVY_VFX_PILLAR)
	local folder = projectilesFolder(plotModel)
	local height = VfxConfig.SWORD_WAVE_PILLAR_HEIGHT
	local startDiam = VfxConfig.SWORD_WAVE_PILLAR_START_RADIUS * 2
	local endDiam = VfxConfig.SWORD_WAVE_PILLAR_END_RADIUS * 2
	local coreRatio = VfxConfig.SWORD_WAVE_PILLAR_CORE_RATIO
	local expandTime = CombatConfig.SWORD_WAVE_PILLAR_EXPAND
	local fadeTime = CombatConfig.SWORD_WAVE_PILLAR_FADE

	local model = Instance.new("Model")
	model.Name = "SwordWavePillar"

	local stand = CFrame.new(worldPos + Vector3.new(0, height * 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local halo = makePillarCylinder("PillarHalo", height, startDiam, 0.55)
	halo.CFrame = stand
	halo.Parent = model

	local core = makePillarCylinder("PillarCore", height * 0.98, startDiam * coreRatio, VfxConfig.SWORD_WAVE_PILLAR_TRANSPARENCY)
	core.CFrame = stand
	core.Parent = model
	model.PrimaryPart = core

	local glow = Instance.new("PointLight")
	glow.Name = "PillarGlow"
	glow.Brightness = VfxConfig.SWORD_WAVE_PILLAR_GLOW_BRIGHTNESS
	glow.Range = VfxConfig.SWORD_WAVE_PILLAR_GLOW_RANGE
	glow.Color = VfxConfig.SWORD_WAVE_COLOR_INNER
	glow.Parent = core

	local segs: { PillarSpiralSeg } = {}
	local showSpiral = quality ~= "Minimal"
	if showSpiral then
		local count = math.max(8, VfxConfig.SWORD_WAVE_PILLAR_SPIRAL_SEGMENTS)
		if quality == "Reduced" then
			count = math.max(8, math.ceil(count * 0.5))
		end
		for i = 0, count - 1 do
			table.insert(segs, {
				part = addPillarSpiralSeg(model),
				t = i / count,
			})
		end
	end

	local currentDiam = startDiam
	local rise = 0.12
	local spiralTransparency = 0
	local spawnedAt = os.clock()
	if showSpiral then
		posePillarSpiral(segs, worldPos, currentDiam, rise, height, 0, spiralTransparency)
	end

	model.Parent = folder
	model.Destroying:Connect(function()
		release()
	end)

	if showSpiral then
		local spinConn = RunService.Heartbeat:Connect(function()
			if not model.Parent then
				return
			end
			local climb = (os.clock() - spawnedAt) * VfxConfig.SWORD_WAVE_PILLAR_SPIRAL_CLIMB
			posePillarSpiral(segs, worldPos, currentDiam, rise, height, climb, spiralTransparency)
		end)
		model.Destroying:Connect(function()
			spinConn:Disconnect()
		end)
	end

	local function applyDiameter(diameter: number)
		if not model.Parent then
			return
		end
		currentDiam = diameter
		halo.Size = Vector3.new(height, diameter, diameter)
		halo.CFrame = stand
		core.Size = Vector3.new(height * 0.98, diameter * coreRatio, diameter * coreRatio)
		core.CFrame = stand
		local grow = 0
		if endDiam > startDiam then
			grow = math.clamp((diameter - startDiam) / (endDiam - startDiam), 0, 1)
		end
		glow.Range = VfxConfig.SWORD_WAVE_PILLAR_GLOW_RANGE
			+ (VfxConfig.SWORD_WAVE_PILLAR_GLOW_RANGE_MAX - VfxConfig.SWORD_WAVE_PILLAR_GLOW_RANGE) * grow
	end

	local function startFade()
		if not model.Parent then
			return
		end
		local fadeInfo = TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(halo, fadeInfo, { Transparency = 1 }):Play()
		TweenService:Create(core, fadeInfo, { Transparency = 1 }):Play()
		TweenService:Create(glow, fadeInfo, { Brightness = 0 }):Play()
		local fadeValue = Instance.new("NumberValue")
		fadeValue.Name = "SpiralFade"
		fadeValue.Value = 0
		fadeValue.Parent = model
		fadeValue.Changed:Connect(function(alpha)
			spiralTransparency = alpha
		end)
		TweenService:Create(fadeValue, fadeInfo, { Value = 1 }):Play()
		task.delay(fadeTime + 0.25, function()
			if model.Parent then
				model:Destroy()
			end
		end)
	end

	local progress = Instance.new("NumberValue")
	progress.Name = "Expand"
	progress.Value = 0
	progress.Parent = model
	progress.Changed:Connect(function(alpha)
		rise = math.max(alpha, 0.12)
		applyDiameter(startDiam + (endDiam - startDiam) * alpha)
	end)

	local expandInfo = TweenInfo.new(expandTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local expandTween = TweenService:Create(progress, expandInfo, { Value = 1 })
	expandTween.Completed:Connect(function(playback)
		if playback ~= Enum.PlaybackState.Completed then
			return
		end
		rise = 1
		applyDiameter(endDiam)
		startFade()
	end)
	expandTween:Play()
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

local function createBubbleModel(isSeed: boolean, isBarrage: boolean): (Model, BasePart)
	local size = if isSeed then CombatConfig.BUBBLE_PROJECTILE_SEED_SIZE else CombatConfig.BUBBLE_PROJECTILE_SIZE
	local shell = if isBarrage then VfxConfig.BUBBLE_BARRAGE_COLOR else VfxConfig.BUBBLE_PROJECTILE_COLOR
	local innerColor = if isBarrage then VfxConfig.BUBBLE_BARRAGE_INNER_COLOR else VfxConfig.BUBBLE_PROJECTILE_INNER_COLOR

	local model = Instance.new("Model")
	model.Name = if isSeed then "BubbleSeed" else "BubbleProjectile"

	local hub = Instance.new("Part")
	hub.Name = "Bubble"
	hub.Shape = Enum.PartType.Ball
	hub.Size = size
	hub.Material = Enum.Material.ForceField
	hub.Color = shell
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
	highlight.FillColor = shell
	highlight.FillTransparency = 0.82
	highlight.OutlineColor = shell:Lerp(Color3.fromRGB(255, 255, 255), 0.35)
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
	trail.LightEmission = VfxConfig.BUBBLE_BARRAGE_STREAK_LIGHT_EMISSION
	trail.Transparency = NumberSequence.new(0.05, 1)
	trail.FaceCamera = true
	trail.MinLength = 0.5
	trail.MaxLength = 36
	trail.Parent = hub
end

local function destroyProjectile(projectile: ActiveProjectile)
	if projectile.releaseVfx then
		projectile.releaseVfx()
		projectile.releaseVfx = nil
	end
	if projectile.model then
		projectile.model:Destroy()
	elseif projectile.part.Parent then
		projectile.part:Destroy()
	end
end

local function shurikenStandCFrame(part: BasePart): CFrame
	local sx = part:GetAttribute("ShurikenStandX")
	local sy = part:GetAttribute("ShurikenStandY")
	local sz = part:GetAttribute("ShurikenStandZ")
	return CFrame.Angles(
		math.rad(if type(sx) == "number" then sx else 90),
		math.rad(if type(sy) == "number" then sy else 0),
		math.rad(if type(sz) == "number" then sz else 0)
	)
end

local function shurikenFlightCFrame(part: BasePart, position: Vector3, spinRadians: number): CFrame
	local o = CombatConfig.SHURIKEN_MODEL_ORIENTATION_DEGREES
	local orient = CFrame.Angles(math.rad(o.X), math.rad(o.Y), math.rad(o.Z))
	return CFrame.new(position)
		* CFrame.fromAxisAngle(Vector3.zAxis, spinRadians)
		* shurikenStandCFrame(part)
		* orient
end

local function applyHeldZ(part: BasePart, worldY: number, worldZ: number?): Vector3
	local pos = part.Position
	if worldZ == nil then
		return Vector3.new(pos.X, worldY, pos.Z)
	end
	return Vector3.new(pos.X, worldY, worldZ)
end

local function applyModelScale(model: Model, scale: number?)
	if type(scale) ~= "number" or scale <= 1.01 then
		return
	end
	model:ScaleTo(model:GetScale() * scale)
end

local function createPineappleModel(scale: number?): (Model, BasePart)
	local template = ModelUtil.findProjectileTemplate(CombatConfig.PINEAPPLE_MODEL_ID)
	if template then
		local model = template:Clone()
		stripScripts(model)
		local primary = pickPrimary(model)
		if primary then
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
			local extent = math.max(size.X, size.Y, size.Z)
			local target = CombatConfig.PINEAPPLE_TARGET_EXTENT
			if extent > 0.01 and target > 0.01 then
				model:ScaleTo(model:GetScale() * math.clamp(target / extent, 0.05, 20))
			end
			model.Name = "PineappleProjectile"
			model:SetAttribute("ProjectileKind", "Pineapple")
			primary:SetAttribute("ProjectileKind", "Pineapple")
			applyModelScale(model, scale)
			return model, primary
		end
		model:Destroy()
	elseif not missingPineappleLogged then
		missingPineappleLogged = true
		log:warn(string.format(
			"missing Assets.Projectiles.%s — using procedural pineapple",
			CombatConfig.PINEAPPLE_MODEL_ID
		))
	end

	local model = Instance.new("Model")
	model.Name = "PineappleProjectile"
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(2.4, 3.2, 2.4)
	body.Color = CombatConfig.PINEAPPLE_COLOR
	body.Material = Enum.Material.SmoothPlastic
	body.Parent = model
	hardenRoot(body)
	local leaf = Instance.new("Part")
	leaf.Name = "Leaf"
	leaf.Size = Vector3.new(0.4, 1.4, 1.2)
	leaf.Color = CombatConfig.PINEAPPLE_LEAF_COLOR
	leaf.Material = Enum.Material.Grass
	leaf.CFrame = CFrame.new(0, 1.8, 0)
	leaf.Parent = model
	weldAccessory(body, leaf)
	model.PrimaryPart = body
	model:SetAttribute("ProjectileKind", "Pineapple")
	applyModelScale(model, scale)
	return model, body
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
	local releaseVfx: (() -> ())? = nil

	if kind == "Shuriken" then
		local shurikenModel, hub = createShurikenModel()
		model = shurikenModel
		part = hub
		local pierceCount = if spec.impact then spec.impact.pierceCount else nil
		local pierceGraves = spec.impact and spec.impact.pierceGraves == true
		if pierceGraves or (type(pierceCount) == "number" and pierceCount > 0) then
			applyPierceAura(shurikenModel, hub)
		end
		shurikenModel.Parent = folder
	elseif kind == "Bat" then
		local batModel, hub = createBatModel()
		model = batModel
		part = hub
		batModel.Parent = folder
	elseif kind == "Arrow" then
		local arrowModel, hub = createArrowModel()
		model = arrowModel
		part = hub
		arrowModel.Parent = folder
	elseif kind == "Bubble" then
		local isSeed = spec.targetKind == "Split"
		local isBarrage = spec.streak == true
		local bubbleModel, hub = createBubbleModel(isSeed, isBarrage)
		model = bubbleModel
		part = hub
		if isBarrage then
			applyBarrageStreak(bubbleModel, hub)
		end
		bubbleModel.Parent = folder
	elseif kind == "Pineapple" then
		local pineappleModel, hub = createPineappleModel(spec.modelScale)
		model = pineappleModel
		part = hub
		pineappleModel.Parent = folder
	elseif kind == "SwordWave" then
		local quality, release = VfxLoad.acquire(VfxConfig.HEAVY_VFX_SWORD_WAVE)
		local waveModel, hub = createSwordWaveModel(quality)
		model = waveModel
		part = hub
		waveModel.Parent = folder
		releaseVfx = release
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
		elseif kind == "Bat" then
			part.CFrame = batFlightCFrame(if spec.originWorld then spec.originWorld else held, 0)
		elseif kind == "SwordWave" then
			part.CFrame = swordWaveCFrame(if spec.originWorld then spec.originWorld else held)
		elseif kind == "Pineapple" then
			part.CFrame = CFrame.new(if spec.originWorld then spec.originWorld else held)
		else
			part.CFrame = shurikenFlightCFrame(part, held, 0)
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
		waveHue = if kind == "SwordWave" then 0 else nil,
		releaseVfx = releaseVfx,
	}
	if kind == "SwordWave" then
		applySwordWaveLook(active[id], 0)
	end
	return id
end

function Projectile.tick(
	dt: number,
	getColumn: GetColumnCallback,
	setWorldPosition: SetPositionCallback,
	onImpact: ImpactCallback,
	onSweep: SweepCallback?
)
	for id, projectile in active do
		if BattleClock.isPaused(projectile.spec.ownerUserId) then continue end
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
		local speed = projectile.spec.columnsPerSecond or CombatConfig.PROJECTILE_COLUMNS_PER_SECOND
		local prevColumn = projectile.column
		local holdingFinale = type(projectile.finaleAt) == "number"
		if holdingFinale then
			projectile.column = liveColumn
		else
			projectile.column += speed * dt * dir
			local wouldReach = if dir < 0
				then projectile.column <= liveColumn
				else projectile.column >= liveColumn
			if wouldReach
				and (projectile.spec.kind or "Knife") == "SwordWave"
				and projectile.spec.targetKind == "LaneEnd"
			then
				projectile.column = liveColumn
			end
		end
		local flightY = projectile.worldY
		local arc = projectile.spec.arcHeight
		if type(arc) == "number" and arc > 0 then
			local span = math.max(math.abs(liveColumn - projectile.spec.startColumn), 0.05)
			local along = math.clamp(math.abs(projectile.column - projectile.spec.startColumn) / span, 0, 1)
			flightY += math.sin(along * math.pi) * arc
		end
		setWorldPosition(
			projectile.part,
			projectile.spec.plotModel,
			projectile.spec.row,
			projectile.column,
			flightY
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
		local held = applyHeldZ(projectile.part, flightY, travelZ)
		local kind = projectile.spec.kind or "Knife"
		if projectile.model then
			if kind == "Arrow" then
				projectile.part.CFrame = arrowFlightCFrame(held, dir)
			elseif kind == "Bubble" then
				projectile.part.CFrame = CFrame.new(held)
			elseif kind == "Bat" then
				projectile.spinRadians += CombatConfig.BAT_SPIN_RADIANS_PER_SECOND * dt
				projectile.part.CFrame = batFlightCFrame(held, projectile.spinRadians)
			elseif kind == "SwordWave" then
				projectile.part.CFrame = swordWaveCFrame(held)
				applySwordWaveLook(projectile, dt)
			elseif kind == "Pineapple" then
				projectile.spinRadians += CombatConfig.PINEAPPLE_SPIN_RADIANS_PER_SECOND * dt
				projectile.part.CFrame = CFrame.new(held) * CFrame.Angles(projectile.spinRadians, 0, 0)
			else
				projectile.spinRadians += CombatConfig.SHURIKEN_SPIN_RADIANS_PER_SECOND * dt
				projectile.part.CFrame = shurikenFlightCFrame(projectile.part, held, projectile.spinRadians)
			end
		elseif travelZ ~= nil then
			projectile.part.CFrame = CFrame.new(held)
		end

		if onSweep and not holdingFinale and impactPiercesAll(projectile.spec.impact) then
			onSweep(
				projectile.spec.plotModel,
				projectile.spec.row,
				prevColumn,
				projectile.column,
				projectile.spec.damage,
				projectile.spec.ownerUserId,
				projectile.spec.impact
			)
		end

		local reached = if dir < 0
			then projectile.column <= liveColumn
			else projectile.column >= liveColumn
		if reached then
			local isWaveFinale = kind == "SwordWave" and projectile.spec.targetKind == "LaneEnd"
			local hold = CombatConfig.SWORD_WAVE_PILLAR_HOLD
			if isWaveFinale and hold > 0 then
				projectile.column = liveColumn
				if type(projectile.finaleAt) ~= "number" then
					projectile.finaleAt = os.clock() + hold
					continue
				end
				if os.clock() < projectile.finaleAt then
					continue
				end
			end
			local _killed, pierceNextId = onImpact(
				projectile.spec.targetInstanceId,
				projectile.spec.damage,
				projectile.spec.ownerUserId,
				projectile.spec.impact,
				projectile.spec.targetKind,
				projectile.spec.plotModel,
				projectile.spec.row,
				projectile.spec.targetColumn
			)
			if type(pierceNextId) == "string" and pierceNextId ~= "" then
				if pierceNextId == LANE_END_ID then
					projectile.spec.targetInstanceId = LANE_END_ID
					projectile.spec.targetKind = "LaneEnd"
					projectile.spec.targetColumn = swordWaveLaneEndColumn()
					continue
				end
				local nextColumn = getColumn(pierceNextId, nil)
				if type(nextColumn) == "number" then
					projectile.spec.targetInstanceId = pierceNextId
					projectile.spec.targetKind = nil
					projectile.spec.targetColumn = nextColumn
					local impact = projectile.spec.impact
					if impact and impact.pierceAll ~= true and type(impact.pierceCount) == "number" then
						impact.pierceCount = math.max(0, impact.pierceCount - 1)
					end
					continue
				end
				if impactPiercesAll(projectile.spec.impact) then
					projectile.spec.targetInstanceId = LANE_END_ID
					projectile.spec.targetKind = "LaneEnd"
					projectile.spec.targetColumn = swordWaveLaneEndColumn()
					continue
				end
			end
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

-- Standalone Tung Bat clone (Ranged Rampage mesh / procedural fallback). Caller
-- parents it and drives CFrame / Size — not ticked as a flying projectile.
function Projectile.createBatVisual(): Model
	local model, _ = createBatModel()
	return model
end

return Projectile
