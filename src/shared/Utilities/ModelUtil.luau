--!strict
--[[
	ModelUtil
	Shared helpers for cloning and placing authored Model templates
	(ReplicatedStorage.Assets). Used by BrainrotModel, MonsterModel,
	HouseBuilder, and the placement ghost. No gameplay authority.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotConfig = require(script.Parent.Parent.Config.BrainrotConfig)
local PlotConfig = require(script.Parent.Parent.Config.PlotConfig)
local Types = require(script.Parent.Parent.Types)

local ModelUtil = {}

local SCRIPT_CLASSES: { [string]: boolean } = {
	Script = true,
	LocalScript = true,
	ModuleScript = true,
}

-- Embedded Toolbox audio must not replicate — plot SFX are client-owner-only.
local AUDIO_CLASSES: { [string]: boolean } = {
	Sound = true,
	SoundGroup = true,
	AudioPlayer = true,
	AudioEmitter = true,
	AudioListener = true,
}

-- Humanoid is intentionally NOT stripped: Shirt/Pants and layered clothing
-- only render on a rig that still has one. It's neutralized instead (see
-- `neutralizeHumanoid`) so it can't drive its own movement/ragdoll/UI.
local STRIP_ALWAYS: { [string]: boolean } = {
	ControllerManager = true,
}

local STRIP_ANIMATION: { [string]: boolean } = {
	AnimationController = true,
	Animator = true,
}

local TOOL_CLASSES: { [string]: boolean } = {
	Tool = true,
	HopperBin = true,
}

-- Classic Toolbox free-model junk (e.g. purple Sparkles on the Spider pack).
local DECOR_FX_CLASSES: { [string]: boolean } = {
	Sparkles = true,
	Fire = true,
	Smoke = true,
}

local INVISIBLE_TRANSPARENCY = 0.95

local function assetsFolder(): Folder?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets and assets:IsA("Folder") then
		return assets
	end
	return nil
end

local function templatesFolder(name: string): Folder?
	local assets = assetsFolder()
	if not assets then
		return nil
	end
	local folder = assets:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end
	return nil
end

function ModelUtil.getBrainrotTemplatesFolder(): Folder?
	return templatesFolder("Brainrots")
end

function ModelUtil.getMonsterTemplatesFolder(): Folder?
	return templatesFolder("Monsters")
end

function ModelUtil.getHouseTemplatesFolder(): Folder?
	return templatesFolder("Houses")
end

function ModelUtil.getProjectileTemplatesFolder(): Folder?
	return templatesFolder("Projectiles")
end

function ModelUtil.getGraveTemplatesFolder(): Folder?
	return templatesFolder("Graves") or templatesFolder("Props")
end

function ModelUtil.getDecorTemplatesFolder(): Folder?
	return templatesFolder("Decor")
end

-- Target horizontal size (studs) for a Brainrot clone / placement ghost.
function ModelUtil.brainrotFootprintStuds(definition: Types.BrainrotDefinition): number
	local footprint = PlotConfig.TILE_SIZE * PlotConfig.BRAINROT_FOOTPRINT_RATIO
	if definition.ability == "Wall" then
		footprint *= 1.05
	end
	return footprint * (definition.modelScale or 1)
end

local function findTemplate(folder: Folder?, modelId: string): Model?
	if not folder then
		return nil
	end
	local child = folder:FindFirstChild(modelId)
	if child and child:IsA("Model") then
		return child
	end
	return nil
end

function ModelUtil.findBrainrotTemplate(modelId: string): Model?
	return findTemplate(ModelUtil.getBrainrotTemplatesFolder(), modelId)
end

function ModelUtil.findMonsterTemplate(modelId: string): Model?
	local fromMonsters = findTemplate(ModelUtil.getMonsterTemplatesFolder(), modelId)
	if fromMonsters then
		return fromMonsters
	end
	-- Fallback: some monster meshes (e.g. Werewolf) currently sit under
	-- Assets.Brainrots in Studio until moved into Assets.Monsters.
	return findTemplate(ModelUtil.getBrainrotTemplatesFolder(), modelId)
end

function ModelUtil.findHouseTemplate(modelId: string): Model?
	return findTemplate(ModelUtil.getHouseTemplatesFolder(), modelId)
end

function ModelUtil.findProjectileTemplate(modelId: string): Model?
	return findTemplate(ModelUtil.getProjectileTemplatesFolder(), modelId)
end

function ModelUtil.findGraveTemplate(modelId: string): Model?
	local fromGraves = findTemplate(ModelUtil.getGraveTemplatesFolder(), modelId)
	if fromGraves then
		return fromGraves
	end
	return findTemplate(ModelUtil.getMonsterTemplatesFolder(), modelId)
		or findTemplate(ModelUtil.getHouseTemplatesFolder(), modelId)
end

function ModelUtil.findDecorTemplate(modelId: string): Model?
	return findTemplate(ModelUtil.getDecorTemplatesFolder(), modelId)
end

local function destroyByClass(root: Instance, classSet: { [string]: boolean })
	for _, descendant in root:GetDescendants() do
		if classSet[descendant.ClassName] then
			descendant:Destroy()
		end
	end
end

local function destroyInvisibleParts(root: Instance)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Transparency >= INVISIBLE_TRANSPARENCY then
			-- Keep rig roots so Motor6D chains stay intact (R6/R15 / custom RootPart).
			local name = descendant.Name
			if name == "HumanoidRootPart" or name == "RootPart" or name == "FakeRootPart" then
				continue
			end
			descendant:Destroy()
		end
	end
end

local function isVisualPart(part: BasePart): boolean
	-- VFX shells parented under the model must not affect feet-snap / scale AABB.
	if part.Name == "BubbleShell" then
		return false
	end
	return part.Transparency < INVISIBLE_TRANSPARENCY
end

local function getVisualWorldAABB(model: Model): (Vector3, Vector3)
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
	local found = false

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and isVisualPart(descendant) then
			found = true
			local cf = descendant.CFrame
			local half = descendant.Size * 0.5
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local world = cf:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
						minV = Vector3.new(math.min(minV.X, world.X), math.min(minV.Y, world.Y), math.min(minV.Z, world.Z))
						maxV = Vector3.new(math.max(maxV.X, world.X), math.max(maxV.Y, world.Y), math.max(maxV.Z, world.Z))
					end
				end
			end
		end
	end

	if not found then
		local cf, size = model:GetBoundingBox()
		local half = size * 0.5
		return cf.Position - half, cf.Position + half
	end

	return minV, maxV
end

local function visualSize(model: Model): Vector3
	local minV, maxV = getVisualWorldAABB(model)
	return maxV - minV
end

-- Character bounds excluding VFX (BubbleShell) and invisible rig roots.
function ModelUtil.getVisualSizeAndCenter(model: Model): (Vector3, Vector3)
	local minV, maxV = getVisualWorldAABB(model)
	return maxV - minV, (minV + maxV) * 0.5
end

local function pickPrimaryPart(model: Model): BasePart?
	-- Prefer custom RootPart (Tung Tung) then HRP so PivotTo moves the Motor6D tree.
	local root = model:FindFirstChild("RootPart", true)
	if root and root:IsA("BasePart") then
		return root
	end
	local hrp = model:FindFirstChild("HumanoidRootPart", true)
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	local best: BasePart? = nil
	local bestVolume = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and isVisualPart(descendant) then
			local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
			if volume > bestVolume then
				bestVolume = volume
				best = descendant
			end
		end
	end
	return best
end

local function ensureBodyAlias(model: Model, primary: BasePart)
	local existing = model:FindFirstChild("Body", true)
	if existing and existing:IsA("BasePart") then
		if model.PrimaryPart == nil then
			model.PrimaryPart = existing
		end
		return
	end

	local function isRigRootName(name: string): boolean
		return name == "HumanoidRootPart" or name == "RootPart" or name == "FakeRootPart"
	end

	-- Never rename invisible rig roots to Body — ghost tint / feet-snap treat them
	-- as non-visual; renaming to Body made PlacementController silhouette them.
	if isRigRootName(primary.Name) or not isVisualPart(primary) then
		local best: BasePart? = nil
		local bestVolume = 0
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") and isVisualPart(descendant) and not isRigRootName(descendant.Name) then
				local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
				if volume > bestVolume then
					bestVolume = volume
					best = descendant
				end
			end
		end
		if best then
			best.Name = "Body"
		end
		model.PrimaryPart = primary
		return
	end

	primary.Name = "Body"
end

local function hardenParts(model: Model, keepCollision: boolean?, animationRig: boolean?)
	local root = model.PrimaryPart
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Massless = true
			if animationRig then
				-- Root stays anchored for grid moves; Motor6D limbs must be free.
				descendant.Anchored = descendant == root
			else
				descendant.Anchored = true
			end
			if keepCollision then
				descendant.CanTouch = false
			else
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
			end
		end
	end
end

--[[
	Keep the Humanoid (required for Shirt/Pants + layered clothing to render)
	but strip everything that would fight our own grid-driven movement/combat
	or draw Roblox's built-in floating name/health UI — HealthBarController was
	intentionally removed, so no default nameplate should reappear via Humanoid.
]]
local function neutralizeHumanoid(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 0
	humanoid.HealthDisplayDistance = 0
	humanoid.WalkSpeed = 0
	humanoid.JumpHeight = 0
	humanoid.JumpPower = 0
	humanoid.PlatformStand = true
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.AutoRotate = false
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
end

-- Prefer Humanoid.Animator (Toolbox R15 / spider packs); fall back to
-- AnimationController for non-humanoid Motor6D props.
local function ensureAnimator(model: Model): Animator
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Name = "Animator"
			animator.Parent = humanoid
		end
		return animator
	end

	local controller = model:FindFirstChildOfClass("AnimationController")
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Name = "AnimationController"
		controller.Parent = model
	end
	local animator = controller:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Name = "Animator"
		animator.Parent = controller
	end
	return animator
end

-- Toolbox packs often nest the real Animation under a Script named "Animation".
-- We strip Scripts, so reparent those Animation instances onto the model first
-- (rename generic "Animation" → WalkAnimation for MonsterAnimation lookup).
local function salvageAnimationsFromScripts(model: Model)
	local salvaged: { Animation } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Animation") and descendant.AnimationId ~= "" then
			local parent = descendant.Parent
			if parent
				and (parent:IsA("LuaSourceContainer"))
			then
				table.insert(salvaged, descendant)
			end
		end
	end
	for _, animation in salvaged do
		if animation.Name == "Animation" or animation.Name == "Animate" then
			animation.Name = "WalkAnimation"
		end
		animation.Parent = model
	end
end

local function applyOrientationDegrees(model: Model, degrees: Vector3?)
	if not degrees then
		return
	end
	model:PivotTo(
		model:GetPivot()
			* CFrame.Angles(math.rad(degrees.X), math.rad(degrees.Y), math.rad(degrees.Z))
	)
end

local function faceDirectionUpright(model: Model, face: Vector3)
	local flat = Vector3.new(face.X, 0, face.Z)
	if flat.Magnitude < 1e-4 then
		flat = Vector3.new(1, 0, 0)
	else
		flat = flat.Unit
	end
	local pos = model:GetPivot().Position
	local right = flat:Cross(Vector3.yAxis)
	if right.Magnitude < 1e-4 then
		right = Vector3.zAxis
	else
		right = right.Unit
	end
	model:PivotTo(CFrame.fromMatrix(pos, right, Vector3.yAxis))
end

local function resolveFace(faceDirection: Vector3?): Vector3
	if faceDirection and faceDirection.Magnitude > 1e-4 then
		return faceDirection
	end
	return BrainrotConfig.MODEL_FACE_DIRECTION
end

export type PrepareOptions = {
	-- Fit horizontal AABB into this size (Brainrots). When both height + footprint
	-- are set, scale = min of the two so the model fits inside either box.
	targetFootprint: number?,
	-- Fit vertical AABB into this size (Monsters / humanoids). Prefer this over
	-- footprint-only scaling so R6 templates don't become tile-wide giants.
	targetHeight: number?,
	faceDirection: Vector3?,
	ghost: boolean?,
	ghostTransparency: number?,
	tintColor: Color3?,
	orientationDegrees: Vector3?,
	-- Houses / props: keep authored CanCollide (units stay non-colliding).
	keepCollision: boolean?,
	-- Houses / props: don't rename PrimaryPart to "Body".
	skipBodyAlias: boolean?,
	-- Monsters: keep Motor6D rig + Animator; only root part stays anchored.
	preserveAnimationRig: boolean?,
}

--[[
	Place on tile:
	1. Clear Assets shelf rotation
	2. Face direction upright (Brainrots +X / Monsters −X by default)
	3. Apply definition orientation in local space
	4. Snap visible AABB bottom onto the tile
]]
function ModelUtil.pivotToTileTop(
	model: Model,
	topCenter: Vector3,
	orientationDegrees: Vector3?,
	faceDirection: Vector3?,
	yOffset: number?
)
	local pos = model:GetPivot().Position
	model:PivotTo(CFrame.new(pos))

	faceDirectionUpright(model, resolveFace(faceDirection))
	applyOrientationDegrees(model, orientationDegrees)

	local minV, maxV = getVisualWorldAABB(model)
	local center = (minV + maxV) * 0.5
	local lift = yOffset or 0
	local delta = Vector3.new(topCenter.X - center.X, topCenter.Y + lift - minV.Y, topCenter.Z - center.Z)
	model:PivotTo(model:GetPivot() + delta)
end

-- Translate only: keep current rotation, put visible feet on tile (+ optional float).
-- When `pivotToBottom` is provided (rest-pose cache), XZ/Y use the model pivot
-- instead of the live visual AABB — animated limbs (procedural spider legs)
-- must not change minY every frame or the body sinks underground.
function ModelUtil.snapFeetToTileTop(model: Model, topCenter: Vector3, floatY: number?, pivotToBottom: number?)
	local lift = floatY or 0
	if type(pivotToBottom) == "number" then
		local pivot = model:GetPivot()
		local targetY = topCenter.Y + lift + pivotToBottom
		model:PivotTo(CFrame.new(topCenter.X, targetY, topCenter.Z) * (pivot - pivot.Position))
		return
	end

	local minV, maxV = getVisualWorldAABB(model)
	local center = (minV + maxV) * 0.5
	local delta = Vector3.new(topCenter.X - center.X, topCenter.Y + lift - minV.Y, topCenter.Z - center.Z)
	model:PivotTo(model:GetPivot() + delta)
end

-- Pivot.Y − visual AABB minY at rest (cache once; reuse with snapFeetToTileTop).
function ModelUtil.getPivotToVisualBottom(model: Model): number
	local minV = getVisualWorldAABB(model)
	return model:GetPivot().Position.Y - minV.Y
end

--[[
	Strip Scripts / Tools / Sounds from an Assets.Monsters template in-place
	(Studio shelf). Keeps Animation instances and Motor6D rigs; the Humanoid is
	kept too (neutralized) so Shirt/Pants / layered clothing still render.
]]
function ModelUtil.sanitizeMonsterAsset(template: Model)
	salvageAnimationsFromScripts(template)
	destroyByClass(template, SCRIPT_CLASSES)
	destroyByClass(template, AUDIO_CLASSES)
	destroyByClass(template, STRIP_ALWAYS)
	destroyByClass(template, TOOL_CLASSES)
	destroyByClass(template, DECOR_FX_CLASSES)
	neutralizeHumanoid(template)

	-- Prefer HRP as PrimaryPart for animation rigs.
	local hrp = template:FindFirstChild("HumanoidRootPart", true)
	if hrp and hrp:IsA("BasePart") then
		template.PrimaryPart = hrp
	elseif not template.PrimaryPart then
		local primary = pickPrimaryPart(template)
		if primary then
			template.PrimaryPart = primary
		end
	end
end

function ModelUtil.sanitizeAllMonsterAssets()
	local folder = ModelUtil.getMonsterTemplatesFolder()
	if not folder then
		return
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			ModelUtil.sanitizeMonsterAsset(child)
		end
	end
end

function ModelUtil.cloneTemplate(template: Model, options: PrepareOptions): Model
	local model = template:Clone()
	local preserveAnim = options.preserveAnimationRig == true

	salvageAnimationsFromScripts(model)
	destroyByClass(model, SCRIPT_CLASSES)
	destroyByClass(model, AUDIO_CLASSES)
	destroyByClass(model, STRIP_ALWAYS)
	destroyByClass(model, TOOL_CLASSES)
	destroyByClass(model, DECOR_FX_CLASSES)
	if not preserveAnim then
		destroyByClass(model, STRIP_ANIMATION)
	end
	neutralizeHumanoid(model)
	destroyInvisibleParts(model)

	local primary = pickPrimaryPart(model)
	if primary then
		model.PrimaryPart = primary
		if not options.skipBodyAlias and not preserveAnim then
			ensureBodyAlias(model, primary)
		end
	end

	hardenParts(model, options.keepCollision, preserveAnim)
	if preserveAnim then
		ensureAnimator(model)
	end

	local pos = model:GetPivot().Position
	model:PivotTo(CFrame.new(pos))
	faceDirectionUpright(model, resolveFace(options.faceDirection))
	applyOrientationDegrees(model, options.orientationDegrees)

	local size = visualSize(model)
	local scaleCandidates: { number } = {}
	if options.targetHeight and options.targetHeight > 0 and size.Y > 0.01 then
		table.insert(scaleCandidates, options.targetHeight / size.Y)
	end
	local extent = math.max(size.X, size.Z)
	if options.targetFootprint and options.targetFootprint > 0 and extent > 0.01 then
		table.insert(scaleCandidates, options.targetFootprint / extent)
	end
	if #scaleCandidates > 0 then
		local scale = scaleCandidates[1]
		for i = 2, #scaleCandidates do
			scale = math.min(scale, scaleCandidates[i])
		end
		scale = math.clamp(scale, 0.05, 20)
		model:ScaleTo(model:GetScale() * scale)
	end

	-- Re-apply rig harden after ScaleTo (ScaleTo can leave anchors inconsistent).
	if preserveAnim then
		hardenParts(model, options.keepCollision, true)
		ensureAnimator(model)
	end

	if options.ghost then
		local transparency = options.ghostTransparency or 0.45
		local tint = options.tintColor
		for _, descendant in model:GetDescendants() do
			-- Only silhouette authored meshes — keep invisible rig roots out of
			-- feet-snap AABB so ghost Y matches the placed model.
			if descendant:IsA("BasePart") and isVisualPart(descendant) then
				descendant.Material = Enum.Material.ForceField
				descendant.Transparency = transparency
				descendant.CastShadow = false
				descendant:SetAttribute("GhostSilhouette", true)
				if tint then
					descendant.Color = tint
				end
			end
		end
	end

	return model
end

-- Back-compat alias used by Brainrot placement / ghost.
function ModelUtil.cloneBrainrotTemplate(template: Model, options: PrepareOptions): Model
	return ModelUtil.cloneTemplate(template, options)
end

return ModelUtil
