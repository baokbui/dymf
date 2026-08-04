--!strict
--[[
	BrainrotModel
	Builds the physical model for a placed Brainrot. Clones an authored template
	from ReplicatedStorage.Assets.Brainrots when present; otherwise falls back to
	a colored Part placeholder (dev-safe until Toolbox models are inserted).

	Identity travels as attributes + the Brainrot tag. Appearance is data-driven
	via BrainrotDefinition.modelId (defaults to definition.id) — never branch on
	Brainrot names.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Types = require(Shared.Types)
local Logger = require(Shared.Utilities.Logger)
local ModelUtil = require(Shared.Utilities.ModelUtil)

local BrainrotModel = {}

local log = Logger.new("BrainrotModel")

local BODY_HEIGHT = 6
local WALL_HEIGHT = 10
local DEFAULT_COLOR = Color3.fromRGB(180, 140, 220)
local missingTemplateLogged: { [string]: boolean } = {}

local function footprintFor(definition: Types.BrainrotDefinition): number
	return ModelUtil.brainrotFootprintStuds(definition)
end

local function applyIdentity(
	model: Model,
	instanceId: string,
	definition: Types.BrainrotDefinition,
	ownerUserId: number,
	position: Types.GridPosition
)
	model:SetAttribute("InstanceId", instanceId)
	model:SetAttribute("BrainrotId", definition.id)
	model:SetAttribute("OwnerUserId", ownerUserId)
	model:SetAttribute("Row", position.row)
	model:SetAttribute("Column", position.column)
	model:SetAttribute("MaxHealth", definition.maxHealth)
	model:SetAttribute("HitsRemaining", definition.health)
	model:SetAttribute("Health", definition.maxHealth)
	CollectionService:AddTag(model, Constants.TAGS.Brainrot)
end

local function createPlaceholder(
	instanceId: string,
	definition: Types.BrainrotDefinition,
	ownerUserId: number,
	position: Types.GridPosition,
	topCenter: Vector3,
	parent: Instance
): Model
	local isWall = definition.ability == "Wall"
	local bodyHeight = if isWall then WALL_HEIGHT else BODY_HEIGHT
	local bodyFootprint = footprintFor(definition)

	local model = Instance.new("Model")
	model.Name = string.format("%s_%s", definition.id, instanceId)

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(bodyFootprint, bodyHeight, bodyFootprint)
	body.Position = topCenter + Vector3.new(0, bodyHeight / 2, 0)
	body.Anchored = true
	body.Locked = true
	body.CanCollide = false
	body.CastShadow = true
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Material = Enum.Material.SmoothPlastic
	body.Color = definition.color or DEFAULT_COLOR
	body.Parent = model
	model.PrimaryPart = body

	applyIdentity(model, instanceId, definition, ownerUserId, position)
	model.Parent = parent
	return model
end

-- Builds a placed Brainrot at `topCenter` (the top-center of its tile). Returns
-- the parented Model; the caller owns its lifecycle.
function BrainrotModel.create(
	instanceId: string,
	definition: Types.BrainrotDefinition,
	ownerUserId: number,
	position: Types.GridPosition,
	topCenter: Vector3,
	parent: Instance
): Model
	local modelId = definition.modelId or definition.id
	local template = ModelUtil.findBrainrotTemplate(modelId)
	if not template then
		if not missingTemplateLogged[modelId] then
			missingTemplateLogged[modelId] = true
			log:warn(string.format(
				"missing Assets.Brainrots.%s — using placeholder Part (insert Toolbox model in Studio)",
				modelId
			))
		end
		return createPlaceholder(instanceId, definition, ownerUserId, position, topCenter, parent)
	end

	local animated = definition.animated == true
	local model = ModelUtil.cloneBrainrotTemplate(template, {
		targetFootprint = footprintFor(definition),
		orientationDegrees = definition.modelOrientationDegrees,
		preserveAnimationRig = animated,
		-- Keep RootPart name for Motor6D chains; feedback uses PrimaryPart / Body.
		skipBodyAlias = animated,
	})
	model.Name = string.format("%s_%s", definition.id, instanceId)
	ModelUtil.pivotToTileTop(model, topCenter, definition.modelOrientationDegrees, nil, definition.modelYOffset)
	applyIdentity(model, instanceId, definition, ownerUserId, position)
	model.Parent = parent
	return model
end

return BrainrotModel
