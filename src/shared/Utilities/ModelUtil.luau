--!strict
--[[
	ModelUtil
	Shared helpers for cloning and placing authored Model templates
	(ReplicatedStorage.Assets). Used by BrainrotModel (server) and the
	placement ghost (client). No gameplay authority.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotConfig = require(script.Parent.Parent.Config.BrainrotConfig)

local ModelUtil = {}

local SCRIPT_CLASSES: { [string]: boolean } = {
	Script = true,
	LocalScript = true,
	ModuleScript = true,
}

local STRIP_CLASSES: { [string]: boolean } = {
	Humanoid = true,
	AnimationController = true,
	Animator = true,
	ControllerManager = true,
}

local INVISIBLE_TRANSPARENCY = 0.95

function ModelUtil.getBrainrotTemplatesFolder(): Folder?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		return nil
	end
	local brainrots = assets:FindFirstChild("Brainrots")
	if brainrots and brainrots:IsA("Folder") then
		return brainrots
	end
	return nil
end

function ModelUtil.findBrainrotTemplate(modelId: string): Model?
	local folder = ModelUtil.getBrainrotTemplatesFolder()
	if not folder then
		return nil
	end
	local child = folder:FindFirstChild(modelId)
	if child and child:IsA("Model") then
		return child
	end
	return nil
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
			descendant:Destroy()
		end
	end
end

local function isVisualPart(part: BasePart): boolean
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

local function pickPrimaryPart(model: Model): BasePart?
	if model.PrimaryPart and isVisualPart(model.PrimaryPart) then
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
	local existing = model:FindFirstChild("Body")
	if existing and existing:IsA("BasePart") then
		return
	end
	primary.Name = "Body"
end

local function hardenParts(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
end

local function visualHorizontalExtent(model: Model): number
	local size = visualSize(model)
	return math.max(size.X, size.Z)
end

-- Apply Euler degrees in the model's current local space (from definition).
local function applyOrientationDegrees(model: Model, degrees: Vector3?)
	if not degrees then
		return
	end
	model:PivotTo(
		model:GetPivot()
			* CFrame.Angles(math.rad(degrees.X), math.rad(degrees.Y), math.rad(degrees.Z))
	)
end

-- Face a horizontal direction with zero pitch/roll.
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

export type PrepareOptions = {
	targetFootprint: number,
	ghost: boolean?,
	ghostTransparency: number?,
	tintColor: Color3?,
	-- Local Euler degrees applied AFTER facing (pitch/yaw/roll on the upright pivot).
	orientationDegrees: Vector3?,
}

--[[
	Place on tile:
	1. Clear Assets shelf rotation
	2. Face enemy (+X) upright (sets World pivot axes)
	3. Apply definition orientation in local space (must be AFTER face — otherwise face wipes it)
	4. Snap visible AABB bottom onto the tile
]]
function ModelUtil.pivotToTileTop(model: Model, topCenter: Vector3, orientationDegrees: Vector3?)
	local pos = model:GetPivot().Position
	model:PivotTo(CFrame.new(pos))

	faceDirectionUpright(model, BrainrotConfig.MODEL_FACE_DIRECTION)
	applyOrientationDegrees(model, orientationDegrees)

	local minV, maxV = getVisualWorldAABB(model)
	local center = (minV + maxV) * 0.5
	local delta = Vector3.new(topCenter.X - center.X, topCenter.Y - minV.Y, topCenter.Z - center.Z)
	model:PivotTo(model:GetPivot() + delta)
end

function ModelUtil.cloneBrainrotTemplate(template: Model, options: PrepareOptions): Model
	local model = template:Clone()
	destroyByClass(model, SCRIPT_CLASSES)
	destroyByClass(model, STRIP_CLASSES)
	destroyInvisibleParts(model)
	hardenParts(model)

	local primary = pickPrimaryPart(model)
	if primary then
		model.PrimaryPart = primary
		ensureBodyAlias(model, primary)
	end

	-- Match placement orientation before measuring footprint.
	local pos = model:GetPivot().Position
	model:PivotTo(CFrame.new(pos))
	faceDirectionUpright(model, BrainrotConfig.MODEL_FACE_DIRECTION)
	applyOrientationDegrees(model, options.orientationDegrees)

	local extent = visualHorizontalExtent(model)
	if extent > 0.01 and options.targetFootprint > 0 then
		local scale = options.targetFootprint / extent
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

return ModelUtil
