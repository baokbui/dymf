--!strict
--[[
	MonsterPreview
	Client-only ViewportFrame previews of Assets.Monsters templates for intro
	popups (and similar UI). Display-only — no gameplay authority.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonsterConfig = require(Shared.Config.MonsterConfig)
local Types = require(Shared.Types)
local ModelUtil = require(Shared.Utilities.ModelUtil)

local MonsterPreview = {}

local PREVIEW_FOOTPRINT = 2.4

local PREVIEW_FACE = MonsterConfig.MODEL_FACE_DIRECTION

local function centerAtOrigin(model: Model)
	local cf = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() - cf.Position)
end

local function frameModel(camera: Camera, model: Model)
	local cf, size = model:GetBoundingBox()
	local extent = math.max(size.X, size.Y, size.Z)
	local distance = math.max(extent * 2.1, 3.6)

	local face = PREVIEW_FACE
	if face.Magnitude < 1e-4 then
		face = Vector3.new(-1, 0, 0)
	else
		face = Vector3.new(face.X, 0, face.Z).Unit
	end
	local right = face:Cross(Vector3.yAxis)
	if right.Magnitude < 1e-4 then
		right = Vector3.zAxis
	else
		right = right.Unit
	end

	-- Look toward the monster's front (it faces −X / the house).
	local lookFrom = cf.Position
		+ face * (distance * 0.95)
		+ right * (distance * 0.32)
		+ Vector3.yAxis * (distance * 0.38)
	camera.FieldOfView = 28
	camera.CFrame = CFrame.lookAt(lookFrom, cf.Position)
end

function MonsterPreview.mount(
	parent: GuiObject,
	definition: Types.MonsterDefinition,
	size: UDim2,
	position: UDim2
): GuiObject
	local modelId = definition.modelId or definition.id
	local template = ModelUtil.findMonsterTemplate(modelId)

	if not template then
		local swatch = Instance.new("Frame")
		swatch.Name = "Swatch"
		swatch.AnchorPoint = Vector2.new(0.5, 0)
		swatch.Position = position
		swatch.Size = size
		swatch.BackgroundColor3 = definition.color or Color3.fromRGB(120, 80, 140)
		swatch.BorderSizePixel = 0
		swatch.Active = false
		swatch.Parent = parent
		return swatch
	end

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Preview"
	viewport.AnchorPoint = Vector2.new(0.5, 0)
	viewport.Position = position
	viewport.Size = size
	viewport.BackgroundColor3 = Color3.fromRGB(55, 70, 95)
	viewport.BackgroundTransparency = 0.35
	viewport.BorderSizePixel = 0
	viewport.Active = false
	viewport.Ambient = Color3.fromRGB(200, 200, 210)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(0.85, -0.45, -0.3)
	viewport.Parent = parent

	local world = Instance.new("WorldModel")
	world.Parent = viewport

	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local span = math.max(1, math.floor(definition.laneSpan or 1))
	local footprint = PREVIEW_FOOTPRINT * (if span > 1 then 1.35 else if definition.isBoss then 1.15 else 1)
	local model = ModelUtil.cloneTemplate(template, {
		targetFootprint = footprint,
		faceDirection = PREVIEW_FACE,
		orientationDegrees = definition.modelOrientationDegrees,
		preserveAnimationRig = true,
		skipBodyAlias = true,
	})
	model.Name = "PreviewModel"
	centerAtOrigin(model)
	model.Parent = world

	frameModel(camera, model)
	return viewport
end

return MonsterPreview
