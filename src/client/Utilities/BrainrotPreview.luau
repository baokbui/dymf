--!strict
--[[
	BrainrotPreview
	Client-only ViewportFrame previews of Assets.Brainrots templates for Shop
	(and similar UI). Display-only — no gameplay authority.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrainrotConfig = require(Shared.Config.BrainrotConfig)
local Types = require(Shared.Types)
local ModelUtil = require(Shared.Utilities.ModelUtil)

local BrainrotPreview = {}

local PREVIEW_FOOTPRINT = 2.2

-- Same upright facing as battlefield placement; camera looks at the front.
local PREVIEW_FACE = BrainrotConfig.MODEL_FACE_DIRECTION

-- Center on visible meshes only (ignore invisible RootPart / FakeRootPart).
local function centerAtOrigin(model: Model)
	local _, center = ModelUtil.getVisualSizeAndCenter(model)
	model:PivotTo(model:GetPivot() - center)
end

local function frameModel(camera: Camera, model: Model, focusOffset: Vector3?)
	local size, center = ModelUtil.getVisualSizeAndCenter(model)
	if focusOffset then
		center = center + focusOffset
	end
	local extent = math.max(size.X, size.Y, size.Z)
	-- Pull back so models sit inside the card with padding (not edge-to-edge).
	local distance = math.max(extent * 2.05, 3.4)

	local face = PREVIEW_FACE
	if face.Magnitude < 1e-4 then
		face = Vector3.new(1, 0, 0)
	else
		face = Vector3.new(face.X, 0, face.Z).Unit
	end
	local right = face:Cross(Vector3.yAxis)
	if right.Magnitude < 1e-4 then
		right = Vector3.zAxis
	else
		right = right.Unit
	end

	-- 3/4 front view: along face (+X toward enemy), slight side + elevated.
	local lookFrom = center
		+ face * (distance * 0.95)
		+ right * (distance * 0.32)
		+ Vector3.yAxis * (distance * 0.38)
	camera.FieldOfView = 28
	camera.CFrame = CFrame.lookAt(lookFrom, center)
end

--[[
	Fills `parent` with a ViewportFrame preview for `definition`.
	Falls back to a colored Frame swatch when the Assets template is missing.
	Returns the preview GuiObject (ViewportFrame or Frame).
]]
function BrainrotPreview.mount(
	parent: GuiObject,
	definition: Types.BrainrotDefinition,
	size: UDim2?,
	position: UDim2?
): GuiObject
	local resolvedSize = size or UDim2.fromScale(1, 1)
	local resolvedPosition = position or UDim2.new(0.5, 0, 0, 0)
	local modelId = definition.modelId or definition.id
	local template = ModelUtil.findBrainrotTemplate(modelId)

	if not template then
		local swatch = Instance.new("Frame")
		swatch.Name = "Swatch"
		swatch.AnchorPoint = Vector2.new(0.5, 0)
		swatch.Position = resolvedPosition
		swatch.Size = resolvedSize
		swatch.BackgroundColor3 = definition.color or Color3.fromRGB(180, 140, 220)
		swatch.BorderSizePixel = 0
		swatch.Active = false
		swatch.Parent = parent
		return swatch
	end

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Preview"
	viewport.AnchorPoint = Vector2.new(0.5, 0)
	viewport.Position = resolvedPosition
	viewport.Size = resolvedSize
	viewport.BackgroundColor3 = Color3.fromRGB(75, 155, 220)
	viewport.BackgroundTransparency = 0.4
	viewport.BorderSizePixel = 0
	viewport.Active = false
	viewport.Ambient = Color3.fromRGB(200, 200, 210)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	-- Match the 3/4 front camera so faces are lit, not backlit.
	viewport.LightDirection = Vector3.new(-0.85, -0.45, -0.3)
	viewport.Parent = parent

	local world = Instance.new("WorldModel")
	world.Parent = viewport

	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local animated = definition.animated == true
	local model = ModelUtil.cloneBrainrotTemplate(template, {
		targetFootprint = PREVIEW_FOOTPRINT * (definition.modelScale or 1),
		faceDirection = PREVIEW_FACE,
		orientationDegrees = definition.modelOrientationDegrees,
		preserveAnimationRig = animated,
		skipBodyAlias = animated,
		anchorAllParts = definition.anchorAllParts == true,
	})
	model.Name = "PreviewModel"
	model.Parent = world
	centerAtOrigin(model)
	frameModel(camera, model, definition.previewFocusOffset)
	return viewport
end

return BrainrotPreview
