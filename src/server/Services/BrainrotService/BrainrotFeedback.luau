--!strict
local BattleClock = require(game:GetService("ReplicatedStorage").Shared.Utilities.BattleClock)
--[[
	BrainrotFeedback
	Lightweight server-side visual feedback for Brainrot actions (replicated on
	the model). Sound playback is routed to the owning client via BrainrotAction.

	Attack pulse uses Model:ScaleTo so authored MeshParts are not Size-warped.
	Hit flash tints visible BaseParts (replicated Color), matching MonsterFeedback.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotConfig = require(ReplicatedStorage.Shared.Config.BrainrotConfig)
local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local EvolutionConfig = require(ReplicatedStorage.Shared.Config.EvolutionConfig)
local VfxConfig = require(ReplicatedStorage.Shared.Config.VfxConfig)
local ModelUtil = require(ReplicatedStorage.Shared.Utilities.ModelUtil)

local BrainrotFeedback = {}

local baseScales: { [Model]: number } = {}
local pulseTokens: { [Model]: number } = {}

local activeHitFlashTweens: { [Model]: { Tween } } = {}
local hitFlashBaseColors: { [Model]: { [BasePart]: Color3 } } = {}
local washOriginals: { [Model]: { [BasePart]: Color3 } } = {}
local washPoison: { [Model]: boolean } = {}
local washVenom: { [Model]: boolean } = {}
type StoneLook = {
	colors: { [BasePart]: Color3 },
	materials: { [BasePart]: Enum.Material },
	surfaceAppearanceParents: { [SurfaceAppearance]: Instance },
	meshTextures: { [MeshPart]: string },
	specialMeshTextures: { [SpecialMesh]: string },
	decalParents: { [Instance]: Instance },
	auraFillColor: Color3?,
	auraFillTransparency: number?,
	auraOutlineColor: Color3?,
	auraOutlineTransparency: number?,
	createdHighlight: boolean,
	disabledEmitters: { ParticleEmitter },
}
local stoneLooks: { [Model]: StoneLook } = {}
local orbitConnections: { [Model]: { [string]: RBXScriptConnection } } = {}
local orbitTweens: { [Model]: { [string]: Tween } } = {}

local function visibleParts(model: Model): { BasePart }
	local parts: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Transparency < 0.95 then
			if descendant.Name == "ShieldVfx" or descendant.Name == "AuraVfx" or descendant.Name == "RetaliationVfx" then
				continue
			end
			if descendant:FindFirstAncestor("ShieldVfx")
				or descendant:FindFirstAncestor("RetaliationVfx")
				or descendant:FindFirstAncestor("AuraVfx")
			then
				continue
			end
			table.insert(parts, descendant)
		end
	end
	if #parts == 0 then
		local body = model.PrimaryPart or model:FindFirstChild("Body")
		if body and body:IsA("BasePart") then
			table.insert(parts, body)
		end
	end
	return parts
end

local function cancelHitFlash(model: Model)
	local tweens = activeHitFlashTweens[model]
	if tweens then
		for _, tween in tweens do
			tween:Cancel()
		end
		activeHitFlashTweens[model] = nil
	end
end

function BrainrotFeedback.pulseAttack(model: Model)
	local token = (pulseTokens[model] or 0) + 1
	pulseTokens[model] = token

	local base = baseScales[model]
	if not base then
		base = model:GetScale()
		baseScales[model] = base
	else
		model:ScaleTo(base)
	end

	model:ScaleTo(base * BrainrotConfig.ATTACK_PULSE_SCALE)
	local half = BrainrotConfig.ATTACK_PULSE_DURATION / 2
	BattleClock.delay(model, half, function()
		if pulseTokens[model] ~= token or not model.Parent then
			return
		end
		model:ScaleTo(base)
		BattleClock.delay(model, half, function()
			if pulseTokens[model] == token then
				pulseTokens[model] = nil
			end
		end)
	end)
end

-- Red tint on damage. Fatal keeps the tint until the model is destroyed.
function BrainrotFeedback.flashHit(model: Model, isFatal: boolean?)
	local parts = visibleParts(model)
	if #parts == 0 then
		return
	end

	cancelHitFlash(model)

	local bases = hitFlashBaseColors[model]
	if not bases then
		bases = {}
		hitFlashBaseColors[model] = bases
		for _, part in parts do
			bases[part] = part.Color
		end
	end

	for _, part in parts do
		if not bases[part] then
			bases[part] = part.Color
		end
		part.Color = BrainrotConfig.HIT_FLASH_COLOR
	end

	if isFatal then
		return
	end

	local tweens: { Tween } = {}
	local remaining = 0
	for _, part in parts do
		local baseColor = bases[part]
		if baseColor then
			remaining += 1
			local tween = BattleClock.tween(model,
				part,
				TweenInfo.new(BrainrotConfig.HIT_FLASH_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Color = baseColor }
			)
			table.insert(tweens, tween)
			tween.Completed:Connect(function()
				remaining -= 1
				if remaining <= 0 and activeHitFlashTweens[model] == tweens then
					activeHitFlashTweens[model] = nil
				end
			end)
			tween:Play()
		end
	end
	activeHitFlashTweens[model] = tweens
end

-- Poison (purple) and Venom (green) share one stored base color so they can
-- stack. Hit-flash bases follow the wash so damage flashes return to it.
local function captureWashOriginals(model: Model)
	if washOriginals[model] then
		return
	end
	local colors: { [BasePart]: Color3 } = {}
	local flashBases = hitFlashBaseColors[model]
	for _, part in visibleParts(model) do
		colors[part] = (flashBases and flashBases[part]) or part.Color
	end
	washOriginals[model] = colors
end

local function paintStatusWash(model: Model)
	local originals = washOriginals[model]
	if not originals then
		return
	end
	local poisoned = washPoison[model] == true
	local venomed = washVenom[model] == true
	if not poisoned and not venomed then
		for part, color in originals do
			if part.Parent then
				part.Color = color
			end
		end
		hitFlashBaseColors[model] = originals
		washOriginals[model] = nil
		model:SetAttribute("Poisoned", false)
		model:SetAttribute("Venomed", false)
		return
	end

	local tinted: { [BasePart]: Color3 } = {}
	for part, base in originals do
		if part.Parent then
			local color = base
			if poisoned then
				color = color:Lerp(BrainrotConfig.POISON_TINT_COLOR, BrainrotConfig.POISON_TINT_BLEND)
			end
			if venomed then
				color = color:Lerp(BrainrotConfig.VENOM_TINT_COLOR, BrainrotConfig.VENOM_TINT_BLEND)
			end
			part.Color = color
			tinted[part] = color
		end
	end
	hitFlashBaseColors[model] = tinted
	model:SetAttribute("Poisoned", poisoned)
	model:SetAttribute("Venomed", venomed)
end

function BrainrotFeedback.setPoisoned(model: Model, poisoned: boolean)
	if poisoned then
		cancelHitFlash(model)
		captureWashOriginals(model)
		washPoison[model] = true
	else
		washPoison[model] = nil
	end
	paintStatusWash(model)
end

function BrainrotFeedback.setVenomed(model: Model, venomed: boolean)
	if venomed then
		cancelHitFlash(model)
		captureWashOriginals(model)
		washVenom[model] = true
	else
		washVenom[model] = nil
	end
	paintStatusWash(model)
end

local STONE_HIGHLIGHT_NAME = "StoneHighlight"

local function hideAuraEmitters(model: Model, look: StoneLook)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ParticleEmitter") and descendant.Enabled then
			local parent = descendant.Parent
			if parent and (parent.Name == "AuraVfx" or parent:FindFirstAncestor("AuraVfx") ~= nil) then
				descendant.Enabled = false
				table.insert(look.disabledEmitters, descendant)
			end
		end
	end
end

local function restoreAuraEmitters(look: StoneLook)
	for _, emitter in look.disabledEmitters do
		if emitter.Parent then
			emitter.Enabled = true
		end
	end
	table.clear(look.disabledEmitters)
end

local function applyStoneHighlight(model: Model, look: StoneLook)
	local fill = BrainrotConfig.STONE_TINT_COLOR
	local outline = BrainrotConfig.STONE_OUTLINE_COLOR
	-- One Highlight per model: evolved plants already have AuraHighlight
	-- (fill fully transparent). Reuse it so the stone wash actually renders.
	local existing = model:FindFirstChild("AuraHighlight")
	if existing and existing:IsA("Highlight") then
		if look.auraFillColor == nil then
			look.auraFillColor = existing.FillColor
			look.auraFillTransparency = existing.FillTransparency
			look.auraOutlineColor = existing.OutlineColor
			look.auraOutlineTransparency = existing.OutlineTransparency
		end
		existing.Enabled = true
		existing.FillColor = fill
		existing.FillTransparency = BrainrotConfig.STONE_HIGHLIGHT_FILL
		existing.OutlineColor = outline
		existing.OutlineTransparency = BrainrotConfig.STONE_HIGHLIGHT_OUTLINE
		existing.Adornee = model
	else
		local created = model:FindFirstChild(STONE_HIGHLIGHT_NAME)
		if not (created and created:IsA("Highlight")) then
			if created then
				created:Destroy()
			end
			local highlight = Instance.new("Highlight")
			highlight.Name = STONE_HIGHLIGHT_NAME
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			highlight.Adornee = model
			highlight.Parent = model
			created = highlight
			look.createdHighlight = true
		end
		local stoneHighlight = created :: Highlight
		stoneHighlight.Enabled = true
		stoneHighlight.FillColor = fill
		stoneHighlight.FillTransparency = BrainrotConfig.STONE_HIGHLIGHT_FILL
		stoneHighlight.OutlineColor = outline
		stoneHighlight.OutlineTransparency = BrainrotConfig.STONE_HIGHLIGHT_OUTLINE
	end
	hideAuraEmitters(model, look)
end

local function clearStoneHighlight(model: Model, look: StoneLook)
	restoreAuraEmitters(look)
	if look.createdHighlight then
		local created = model:FindFirstChild(STONE_HIGHLIGHT_NAME)
		if created then
			created:Destroy()
		end
		look.createdHighlight = false
	end
	local existing = model:FindFirstChild("AuraHighlight")
	if existing and existing:IsA("Highlight") and look.auraFillColor then
		existing.FillColor = look.auraFillColor
		existing.FillTransparency = look.auraFillTransparency or 1
		existing.OutlineColor = look.auraOutlineColor or look.auraFillColor
		existing.OutlineTransparency = look.auraOutlineTransparency or 0.15
	end
end

function BrainrotFeedback.setStoned(model: Model, stoned: boolean)
	local parts = visibleParts(model)
	if stoned and #parts == 0 then
		return
	end

	if stoned then
		cancelHitFlash(model)
		if not stoneLooks[model] then
			local colors: { [BasePart]: Color3 } = {}
			local materials: { [BasePart]: Enum.Material } = {}
			local surfaceAppearanceParents: { [SurfaceAppearance]: Instance } = {}
			local meshTextures: { [MeshPart]: string } = {}
			local specialMeshTextures: { [SpecialMesh]: string } = {}
			local decalParents: { [Instance]: Instance } = {}
			local flashBases = hitFlashBaseColors[model]

			for _, part in parts do
				colors[part] = (flashBases and flashBases[part]) or part.Color
				materials[part] = part.Material
				if part:IsA("MeshPart") and part.TextureID ~= "" then
					meshTextures[part] = part.TextureID
					part.TextureID = ""
				end
				for _, child in part:GetChildren() do
					if child:IsA("SurfaceAppearance") and child.Parent then
						surfaceAppearanceParents[child] = child.Parent
						child.Parent = nil
					elseif child:IsA("SpecialMesh") and child.TextureId ~= "" then
						specialMeshTextures[child] = child.TextureId
						child.TextureId = ""
					elseif (child:IsA("Decal") or child:IsA("Texture")) and child.Parent then
						decalParents[child] = child.Parent
						child.Parent = nil
					end
				end
			end
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("SurfaceAppearance")
					and descendant.Parent
					and surfaceAppearanceParents[descendant] == nil
				then
					surfaceAppearanceParents[descendant] = descendant.Parent
					descendant.Parent = nil
				elseif (descendant:IsA("Decal") or descendant:IsA("Texture"))
					and descendant.Parent
					and decalParents[descendant] == nil
					and descendant.Name ~= "AuraVfx"
					and descendant:FindFirstAncestor("AuraVfx") == nil
				then
					decalParents[descendant] = descendant.Parent
					descendant.Parent = nil
				end
			end

			stoneLooks[model] = {
				colors = colors,
				materials = materials,
				surfaceAppearanceParents = surfaceAppearanceParents,
				meshTextures = meshTextures,
				specialMeshTextures = specialMeshTextures,
				decalParents = decalParents,
				createdHighlight = false,
				disabledEmitters = {},
			}
		end

		local originals = stoneLooks[model]
		if not originals then
			return
		end

		local tint = BrainrotConfig.STONE_TINT_COLOR
		local blend = BrainrotConfig.STONE_TINT_BLEND
		local stoneMaterial = BrainrotConfig.STONE_MATERIAL
		local tinted: { [BasePart]: Color3 } = {}
		for _, part in parts do
			local base = originals.colors[part] or part.Color
			local washed = base:Lerp(tint, blend)
			part.Color = washed
			part.Material = stoneMaterial
			tinted[part] = washed
		end
		hitFlashBaseColors[model] = tinted
		applyStoneHighlight(model, originals)
		model:SetAttribute("Stoned", true)
	else
		local look = stoneLooks[model]
		if look then
			for part, color in look.colors do
				if part.Parent then
					part.Color = color
					part.Material = look.materials[part] or Enum.Material.SmoothPlastic
				end
			end
			for appearance, parent in look.surfaceAppearanceParents do
				if parent.Parent and appearance.Parent == nil then
					appearance.Parent = parent
				end
			end
			for mesh, textureId in look.meshTextures do
				if mesh.Parent then
					mesh.TextureID = textureId
				end
			end
			for mesh, textureId in look.specialMeshTextures do
				if mesh.Parent then
					mesh.TextureId = textureId
				end
			end
			for decal, parent in look.decalParents do
				if parent.Parent and decal.Parent == nil then
					decal.Parent = parent
				end
			end
			clearStoneHighlight(model, look)
			hitFlashBaseColors[model] = look.colors
			stoneLooks[model] = nil
		end
		model:SetAttribute("Stoned", false)
	end
end

local function resolveBody(model: Model): BasePart?
	local body = model:FindFirstChild("Body", true)
	if body and body:IsA("BasePart") then
		return body
	end
	local primary = model.PrimaryPart
	if primary then
		return primary
	end
	local hrp = model:FindFirstChild("HumanoidRootPart", true)
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function stopOrbit(model: Model, vfxName: string)
	local tweens = orbitTweens[model]
	if tweens then
		local tween = tweens[vfxName]
		if tween then
			tween:Cancel()
			tweens[vfxName] = nil
		end
		if next(tweens) == nil then
			orbitTweens[model] = nil
		end
	end
	local conns = orbitConnections[model]
	if conns then
		local conn = conns[vfxName]
		if conn then
			conn:Disconnect()
			conns[vfxName] = nil
		end
		if next(conns) == nil then
			orbitConnections[model] = nil
		end
	end
	local vfx = model:FindFirstChild(vfxName)
	if vfx then
		vfx:Destroy()
	end
end

function BrainrotFeedback.clearAura(model: Model)
	while true do
		local existing = model:FindFirstChild("AuraVfx", true)
		if not existing then
			break
		end
		existing:Destroy()
	end
	local highlight = model:FindFirstChild("AuraHighlight")
	if highlight then
		highlight:Destroy()
	end
end

function BrainrotFeedback.clearShield(model: Model)
	stopOrbit(model, "ShieldVfx")
end

local function weldToPrimary(primary: BasePart, part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	if part == primary then
		return
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = primary
	weld.Part1 = part
	weld.Parent = part
end

local function createProceduralOrbitShield(): Model
	local model = Instance.new("Model")
	model.Name = "ShieldVfx"
	local part = Instance.new("Part")
	part.Name = "Shield"
	part.Size = Vector3.new(0.28, 2.1, 1.5)
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Color3.fromRGB(80, 170, 255)
	part.Parent = model
	model.PrimaryPart = part
	return model
end

local function createProceduralOrbitMirror(): Model
	local model = Instance.new("Model")
	model.Name = "RetaliationVfx"
	local part = Instance.new("Part")
	part.Name = "Mirror"
	part.Size = Vector3.new(0.12, 1.9, 1.4)
	part.Material = Enum.Material.Glass
	part.Color = Color3.fromRGB(210, 230, 255)
	part.Reflectance = 0.55
	part.Parent = model
	model.PrimaryPart = part
	return model
end

local function cloneAuthoredOrbitProp(templateId: string, orientationDegrees: Vector3, fallbackName: string): Model?
	local folder = ModelUtil.getProjectileTemplatesFolder()
	local child = if folder then folder:FindFirstChild(templateId) else nil
	if child and child:IsA("Model") then
		return ModelUtil.cloneTemplate(child, {
			skipBodyAlias = true,
			orientationDegrees = orientationDegrees,
		})
	end
	if child and child:IsA("BasePart") then
		local model = Instance.new("Model")
		local part = child:Clone()
		part.Name = fallbackName
		part.Parent = model
		model.PrimaryPart = part
		return model
	end
	return nil
end

local function rememberOrbit(model: Model, vfxName: string, tween: Tween, conn: RBXScriptConnection)
	local tweens = orbitTweens[model]
	if not tweens then
		tweens = {}
		orbitTweens[model] = tweens
	end
	tweens[vfxName] = tween
	local conns = orbitConnections[model]
	if not conns then
		conns = {}
		orbitConnections[model] = conns
	end
	conns[vfxName] = conn
end

local function attachOrbitProp(
	model: Model,
	body: BasePart,
	vfxName: string,
	prop: Model,
	size: number,
	radius: number,
	lift: number,
	period: number,
	orientationDegrees: Vector3
)
	prop.Name = vfxName
	prop.Parent = model

	local extents = prop:GetExtentsSize()
	local longest = math.max(extents.X, extents.Y, extents.Z, 0.05)
	if longest > 0.05 then
		prop:ScaleTo(prop:GetScale() * (size / longest))
	end

	local primary = prop.PrimaryPart or prop:FindFirstChildWhichIsA("BasePart", true)
	if not primary then
		prop:Destroy()
		return
	end
	prop.PrimaryPart = primary
	primary.Anchored = false
	primary.CanCollide = false
	primary.CanQuery = false
	primary.CanTouch = false
	primary.Massless = true
	primary.CastShadow = false
	for _, descendant in prop:GetDescendants() do
		if descendant:IsA("BasePart") then
			weldToPrimary(primary, descendant)
		end
	end

	local o = orientationDegrees
	local orient = CFrame.Angles(math.rad(o.X), math.rad(o.Y), math.rad(o.Z))
	local function pose(alpha: number): CFrame
		return CFrame.new(0, lift, 0) * CFrame.Angles(0, alpha, 0) * CFrame.new(radius, 0, 0) * orient
	end

	local motor = Instance.new("Motor6D")
	motor.Name = "OrbitMotor"
	motor.Part0 = body
	motor.Part1 = primary
	motor.C0 = pose(0)
	motor.C1 = CFrame.new()
	motor.Parent = primary

	local spin = Instance.new("NumberValue")
	spin.Name = "OrbitSpin"
	spin.Value = 0
	spin.Parent = prop

	local conn = spin:GetPropertyChangedSignal("Value"):Connect(function()
		if not motor.Parent then
			return
		end
		motor.C0 = pose(spin.Value)
	end)

	local tween = BattleClock.tween(model,
		spin,
		TweenInfo.new(period, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
		{ Value = math.pi * 2 }
	)
	rememberOrbit(model, vfxName, tween, conn)
	tween:Play()
end

local function attachOrbitShield(model: Model, body: BasePart)
	local shield = cloneAuthoredOrbitProp(
		CombatConfig.SHIELD_MODEL_ID,
		CombatConfig.SHIELD_ORBIT_ORIENTATION_DEGREES,
		"Shield"
	) or createProceduralOrbitShield()
	attachOrbitProp(
		model,
		body,
		"ShieldVfx",
		shield,
		VfxConfig.SHIELD_ORBIT_SIZE,
		VfxConfig.SHIELD_ORBIT_RADIUS,
		VfxConfig.SHIELD_ORBIT_LIFT,
		VfxConfig.SHIELD_ORBIT_PERIOD,
		CombatConfig.SHIELD_ORBIT_ORIENTATION_DEGREES
	)
end

local function attachBubbleShield(model: Model, body: BasePart)
	local visualSize, center = ModelUtil.getVisualSizeAndCenter(model)
	local diameter = math.max(visualSize.X, visualSize.Y, visualSize.Z, 2) * VfxConfig.SHIELD_BUBBLE_PADDING
	local bubble = Instance.new("Part")
	bubble.Name = "ShieldVfx"
	bubble.Shape = Enum.PartType.Ball
	bubble.Size = Vector3.new(diameter, diameter, diameter)
	bubble.CFrame = CFrame.new(center)
	bubble.Material = Enum.Material.ForceField
	bubble.Color = VfxConfig.SHIELD_BUBBLE_COLOR
	bubble.Transparency = VfxConfig.SHIELD_BUBBLE_TRANSPARENCY
	bubble.Anchored = false
	bubble.CanCollide = false
	bubble.CanQuery = false
	bubble.CanTouch = false
	bubble.Massless = true
	bubble.CastShadow = false
	bubble.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = bubble
	weld.Parent = bubble
end

function BrainrotFeedback.setShield(model: Model, active: boolean)
	if not active then
		BrainrotFeedback.clearShield(model)
		return
	end
	if model:FindFirstChild("ShieldVfx") then
		return
	end

	local body = resolveBody(model)
	if not body then
		return
	end

	if model:GetAttribute("ShieldOrbit") == true then
		local root = model:FindFirstChild("RootPart", true) or model:FindFirstChild("HumanoidRootPart", true)
		local hub = if root and root:IsA("BasePart") then root else body
		attachOrbitShield(model, hub)
	else
		attachBubbleShield(model, body)
	end
end

function BrainrotFeedback.clearRetaliation(model: Model)
	stopOrbit(model, "RetaliationVfx")
end

function BrainrotFeedback.setRetaliation(model: Model, active: boolean)
	if not active then
		BrainrotFeedback.clearRetaliation(model)
		return
	end
	if model:FindFirstChild("RetaliationVfx") then
		return
	end

	local body = resolveBody(model)
	if not body then
		return
	end

	local root = model:FindFirstChild("RootPart", true) or model:FindFirstChild("HumanoidRootPart", true)
	local hub = if root and root:IsA("BasePart") then root else body
	local mirror = cloneAuthoredOrbitProp(
		CombatConfig.MIRROR_MODEL_ID,
		CombatConfig.MIRROR_ORBIT_ORIENTATION_DEGREES,
		"Mirror"
	) or createProceduralOrbitMirror()
	attachOrbitProp(
		model,
		hub,
		"RetaliationVfx",
		mirror,
		VfxConfig.MIRROR_ORBIT_SIZE,
		VfxConfig.MIRROR_ORBIT_RADIUS,
		VfxConfig.MIRROR_ORBIT_LIFT,
		VfxConfig.MIRROR_ORBIT_PERIOD,
		CombatConfig.MIRROR_ORBIT_ORIENTATION_DEGREES
	)
end

local function discEmitter(parent: BasePart, name: string): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.LightInfluence = 0
	emitter.LockedToPart = false
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Shape = Enum.ParticleEmitterShape.Disc
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	emitter.Parent = parent
	return emitter
end

-- Super Saiyan column: stretched flame spikes + thin rarity silhouette.
-- Flames only — no sparkles or speed lines. The server authors the dense
-- column (core + extra layer). Clients thin or clear the flames by VFX
-- setting; the Highlight outline always stays. Size and speed stay fixed
-- so the column does not grow taller or thicker.
function BrainrotFeedback.applyAura(model: Model, auraColor: Color3?, auraScale: number?, rainbow: boolean?)
	BrainrotFeedback.clearAura(model)
	if not auraColor then
		return
	end

	local body = resolveBody(model)
	if not body then
		return
	end

	local scale = auraScale or 1
	local visualSize, center = ModelUtil.getVisualSizeAndCenter(model)
	local width = math.max(visualSize.X, visualSize.Z, 1.8)
	local feetY = center.Y - visualSize.Y * 0.48

	local disc = Instance.new("Part")
	disc.Name = "AuraVfx"
	disc.Size = Vector3.new(width * 1.55, 0.3, width * 1.55)
	disc.CFrame = CFrame.new(center.X, feetY, center.Z)
	disc.Transparency = 1
	disc.Anchored = false
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.Massless = true
	disc.CastShadow = false
	disc.Parent = model

	local discWeld = Instance.new("WeldConstraint")
	discWeld.Part0 = body
	discWeld.Part1 = disc
	discWeld.Parent = disc

	local hot = auraColor:Lerp(Color3.fromRGB(255, 255, 255), 0.55)
	local spikeColor = if rainbow
		then EvolutionConfig.rainbowSequence()
		else ColorSequence.new({
			ColorSequenceKeypoint.new(0, hot),
			ColorSequenceKeypoint.new(0.4, auraColor),
			ColorSequenceKeypoint.new(1, auraColor:Lerp(Color3.fromRGB(20, 10, 5), 0.28)),
		})

	local function styleFlames(emitter: ParticleEmitter, layer: string, rate: number)
		emitter.Color = spikeColor
		emitter.Texture = "rbxasset://textures/particles/fire_main.dds"
		emitter.LightEmission = 1
		emitter.Brightness = 6.5
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.95 * scale),
			NumberSequenceKeypoint.new(0.45, 1.55 * scale),
			NumberSequenceKeypoint.new(1, 0.4 * scale),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.02),
			NumberSequenceKeypoint.new(0.55, 0.22),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Lifetime = NumberRange.new(0.35, 0.7)
		emitter.Speed = NumberRange.new(7 * scale, 13 * scale)
		emitter.SpreadAngle = Vector2.new(40, 52)
		emitter.Rate = rate
		emitter.Acceleration = Vector3.new(0, 26 * scale, 0)
		emitter.Drag = 0.5
		emitter.Squash = NumberSequence.new(-1.35)
		emitter.ZOffset = 2
		emitter:SetAttribute("AuraLayer", layer)
		emitter:SetAttribute("AuraFullRate", rate)
	end

	-- Core stays on Low (thinned by the client). Extra is High only.
	styleFlames(discEmitter(disc, "AuraSpikes"), "Core", VfxConfig.BRAINROT_AURA_SPIKES_RATE)
	styleFlames(discEmitter(disc, "AuraFlames"), "High", VfxConfig.BRAINROT_AURA_EXTRA_RATE)

	local highlight = Instance.new("Highlight")
	highlight.Name = "AuraHighlight"
	highlight.Adornee = model
	highlight.FillColor = auraColor
	highlight.FillTransparency = 1
	highlight.OutlineColor = if rainbow
		then Color3.fromRGB(255, 255, 255)
		else auraColor:Lerp(Color3.fromRGB(255, 255, 255), 0.2)
	highlight.OutlineTransparency = 0.15
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model

	local look = stoneLooks[model]
	if look and model:GetAttribute("Stoned") == true then
		look.auraFillColor = nil
		look.auraFillTransparency = nil
		look.auraOutlineColor = nil
		look.auraOutlineTransparency = nil
		applyStoneHighlight(model, look)
	end
end

function BrainrotFeedback.cleanup(model: Model)
	cancelHitFlash(model)
	washPoison[model] = nil
	washVenom[model] = nil
	if washOriginals[model] then
		BrainrotFeedback.setPoisoned(model, false)
	end
	if stoneLooks[model] then
		BrainrotFeedback.setStoned(model, false)
	end
	hitFlashBaseColors[model] = nil
	washOriginals[model] = nil
	washPoison[model] = nil
	washVenom[model] = nil
	stoneLooks[model] = nil
	BrainrotFeedback.clearAura(model)
	BrainrotFeedback.clearShield(model)
	BrainrotFeedback.clearRetaliation(model)

	local base = baseScales[model]
	if base and model.Parent then
		model:ScaleTo(base)
	end
	baseScales[model] = nil
	pulseTokens[model] = nil
end

return BrainrotFeedback
