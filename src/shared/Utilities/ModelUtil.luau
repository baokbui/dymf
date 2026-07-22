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

local STRIP_CLASSES: { [string]: boolean } = {
	Humanoid = true,
	AnimationController = true,
	Animator = true,
	ControllerManager = true,
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
	return findTemplate(ModelUtil.getMonsterTemplatesFolder(), modelId)
end

function ModelUtil.findHouseTemplate(modelId: string): Model?
	return findTemplate(ModelUtil.getHouseTemplatesFolder(), modelId)
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
			-- Keep rig roots so Motor6D chains stay intact (R6/R15 Toolbox monsters).
			if descendant.Name == "HumanoidRootPart" then
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
	-- Prefer rig root even when invisible so PivotTo moves the whole Motor6D tree.
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
	primary.Name = "Body"
end

local function hardenParts(model: Model, keepCollision: boolean?)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.Massless = true
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
	faceDirection: Vector3?
)
	local pos = model:GetPivot().Position
	model:PivotTo(CFrame.new(pos))

	faceDirectionUpright(model, resolveFace(faceDirection))
	applyOrientationDegrees(model, orientationDegrees)

	local minV, maxV = getVisualWorldAABB(model)
	local center = (minV + maxV) * 0.5
	local delta = Vector3.new(topCenter.X - center.X, topCenter.Y - minV.Y, topCenter.Z - center.Z)
	model:PivotTo(model:GetPivot() + delta)
end

-- Translate only: keep current rotation, put visible feet on tile (+ optional float).
function ModelUtil.snapFeetToTileTop(model: Model, topCenter: Vector3, floatY: number?)
	local minV, maxV = getVisualWorldAABB(model)
	local center = (minV + maxV) * 0.5
	local lift = floatY or 0
	local delta = Vector3.new(topCenter.X - center.X, topCenter.Y + lift - minV.Y, topCenter.Z - center.Z)
	model:PivotTo(model:GetPivot() + delta)
end

function ModelUtil.cloneTemplate(template: Model, options: PrepareOptions): Model
	local model = template:Clone()
	destroyByClass(model, SCRIPT_CLASSES)
	destroyByClass(model, AUDIO_CLASSES)
	destroyByClass(model, STRIP_CLASSES)
	destroyInvisibleParts(model)
	hardenParts(model, options.keepCollision)

	local primary = pickPrimaryPart(model)
	if primary then
		model.PrimaryPart = primary
		if not options.skipBodyAlias then
			ensureBodyAlias(model, primary)
		end
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

	if options.ghost then
		local transparency = options.ghostTransparency or 0.45
		local tint = options.tintColor
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Material = Enum.Material.ForceField
				descendant.Transparency = transparency
				descendant.CastShadow = false
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
