--!strict
--[[
	MonsterPreview
	Client-only ViewportFrame previews of Assets.Monsters templates for intro
	popups (and similar UI). Display-only — no gameplay authority.

	VFX Off uses a flat color swatch instead of a ViewportFrame, except inspect
	portraits (`keepModel`), which stay 3D on every setting.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonsterConfig = require(Shared.Config.MonsterConfig)
local Types = require(Shared.Types)
local ModelUtil = require(Shared.Utilities.ModelUtil)
local VfxLoad = require(Shared.Utilities.VfxLoad)

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

local SILHOUETTE = Color3.fromRGB(10, 10, 14)

type Layout = {
	size: UDim2,
	position: UDim2,
	anchor: Vector2,
	zindex: number,
	corner: UICorner?,
}

type Mount = {
	gui: GuiObject,
	definition: Types.MonsterDefinition,
	viewportTransparency: number?,
	silhouette: boolean,
	keepModel: boolean,
}

local mounts: { Mount } = {}

local function paintSilhouette(root: Instance)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("SurfaceAppearance") or descendant:IsA("Texture") or descendant:IsA("Decal") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Color = SILHOUETTE
			descendant.Material = Enum.Material.SmoothPlastic
		elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Fire") or descendant:IsA("Smoke") or descendant:IsA("Highlight") then
			descendant.Enabled = false
		end
	end
end

local function takeLayout(gui: GuiObject): Layout
	local corner = gui:FindFirstChildOfClass("UICorner")
	return {
		size = gui.Size,
		position = gui.Position,
		anchor = gui.AnchorPoint,
		zindex = gui.ZIndex,
		corner = if corner then corner:Clone() else nil,
	}
end

local function applyLayout(gui: GuiObject, layout: Layout)
	gui.Size = layout.size
	gui.Position = layout.position
	gui.AnchorPoint = layout.anchor
	gui.ZIndex = layout.zindex
	if layout.corner then
		layout.corner.Parent = gui
	end
end

local function makeSwatch(definition: Types.MonsterDefinition, silhouette: boolean): Frame
	local swatch = Instance.new("Frame")
	swatch.Name = "Swatch"
	swatch.BackgroundColor3 = if silhouette
		then SILHOUETTE
		else (definition.color or Color3.fromRGB(120, 80, 140))
	swatch.BackgroundTransparency = 0
	swatch.BorderSizePixel = 0
	swatch.Active = false
	if silhouette then
		swatch:SetAttribute("PreviewSilhouette", true)
	end
	return swatch
end

local function makeViewport(definition: Types.MonsterDefinition, silhouette: boolean): GuiObject
	local modelId = definition.modelId or definition.id
	local template = ModelUtil.findMonsterTemplate(modelId)
	if not template then
		return makeSwatch(definition, silhouette)
	end

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Preview"
	viewport.BackgroundColor3 = Color3.fromRGB(55, 70, 95)
	viewport.BackgroundTransparency = 0.35
	viewport.BorderSizePixel = 0
	viewport.Active = false
	viewport.Ambient = Color3.fromRGB(200, 200, 210)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(0.85, -0.45, -0.3)
	if silhouette then
		viewport.Ambient = Color3.new(0, 0, 0)
		viewport.LightColor = Color3.fromRGB(28, 28, 32)
		viewport.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
		viewport:SetAttribute("PreviewSilhouette", true)
	end

	local world = Instance.new("WorldModel")
	world.Parent = viewport

	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local span = math.max(1, math.floor(definition.laneSpan or 1))
	local scale = definition.modelScale
	if type(scale) ~= "number" or scale <= 0 then
		scale = 1
	end
	local footprint = PREVIEW_FOOTPRINT
		* (if span > 1 then 1.35 else if definition.isBoss then 1.15 else 1)
		* scale
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
	if silhouette then
		paintSilhouette(model)
	end
	return viewport
end

local function realize(mount: Mount, layout: Layout): GuiObject
	local gui = if VfxLoad.usesModelPortrait(mount.keepModel)
		then makeViewport(mount.definition, mount.silhouette)
		else makeSwatch(mount.definition, mount.silhouette)
	applyLayout(gui, layout)
	if gui:IsA("ViewportFrame") then
		gui.BackgroundTransparency = mount.viewportTransparency or gui.BackgroundTransparency
	end
	return gui
end

local function refreshMounts()
	local alive: { Mount } = {}
	for _, mount in mounts do
		local gui = mount.gui
		local parent = gui.Parent
		if not parent then
			continue
		end
		if gui:GetAttribute("PreviewSilhouette") == true then
			mount.silhouette = true
		end
		local wantModel = VfxLoad.usesModelPortrait(mount.keepModel)
		if wantModel == gui:IsA("ViewportFrame") then
			table.insert(alive, mount)
			continue
		end
		if gui:IsA("ViewportFrame") then
			mount.viewportTransparency = gui.BackgroundTransparency
		end
		local layout = takeLayout(gui)
		gui:Destroy()
		local nextGui = realize(mount, layout)
		nextGui.Parent = parent
		mount.gui = nextGui
		table.insert(alive, mount)
	end
	mounts = alive
end

function MonsterPreview.mount(
	parent: GuiObject,
	definition: Types.MonsterDefinition,
	size: UDim2,
	position: UDim2,
	keepModel: boolean?
): GuiObject
	local mount: Mount = {
		gui = nil :: any,
		definition = definition,
		viewportTransparency = nil,
		silhouette = false,
		keepModel = keepModel == true,
	}
	local gui = realize(mount, {
		size = size,
		position = position,
		anchor = Vector2.new(0.5, 0),
		zindex = 1,
		corner = nil,
	})
	gui.Parent = parent
	mount.gui = gui
	table.insert(mounts, mount)
	return gui
end

VfxLoad.onChanged(function()
	refreshMounts()
end)

return MonsterPreview
