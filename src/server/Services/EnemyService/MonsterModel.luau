--!strict
--[[
	MonsterModel
	Builds the physical model for a spawned monster. Clones an authored template
	from ReplicatedStorage.Assets.Monsters when present; otherwise falls back to
	a colored Part placeholder.

	Identity via attributes + Monster tag. Appearance is data-driven via
	MonsterDefinition.modelId (defaults to definition.id) — never branch on names.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local MonsterConfig = require(Shared.Config.MonsterConfig)
local PlotConfig = require(Shared.Config.PlotConfig)
local Types = require(Shared.Types)
local Logger = require(Shared.Utilities.Logger)
local ModelUtil = require(Shared.Utilities.ModelUtil)

local MonsterModel = {}

local log = Logger.new("MonsterModel")
local missingTemplateLogged: { [string]: boolean } = {}

local function bodyHeightFor(definition: Types.MonsterDefinition): number
	local height = MonsterConfig.BODY_HEIGHT
	if definition.isBoss then
		return height * 1.25
	end
	return height
end

local function footprintFor(definition: Types.MonsterDefinition): number
	local footprint = PlotConfig.TILE_SIZE * MonsterConfig.FOOTPRINT_RATIO
	if definition.isBoss then
		return footprint * 1.15
	end
	return footprint
end

local function applyIdentity(
	model: Model,
	instanceId: string,
	definition: Types.MonsterDefinition,
	plotModel: Model,
	row: number
)
	model:SetAttribute("InstanceId", instanceId)
	model:SetAttribute("MonsterId", definition.id)
	model:SetAttribute("PlotName", plotModel.Name)
	model:SetAttribute("Row", row)
	model:SetAttribute("Health", definition.health)
	model:SetAttribute("MaxHealth", definition.health)
	model:SetAttribute("IsBoss", definition.isBoss == true)
	CollectionService:AddTag(model, Constants.TAGS.Monster)
end

local function createPlaceholder(
	instanceId: string,
	definition: Types.MonsterDefinition,
	plotModel: Model,
	row: number,
	worldPosition: Vector3,
	parent: Instance
): Model
	local footprint = footprintFor(definition)
	local bodyHeight = MonsterConfig.BODY_HEIGHT
	if definition.isBoss then
		bodyHeight *= 1.25
	end

	local model = Instance.new("Model")
	model.Name = string.format("%s_%s", definition.id, instanceId)

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(footprint, bodyHeight, footprint)
	body.Position = worldPosition + Vector3.new(0, bodyHeight / 2, 0)
	body.Anchored = true
	body.Locked = true
	body.CanCollide = false
	body.CastShadow = true
	body.Material = Enum.Material.SmoothPlastic
	body.Color = definition.color or MonsterConfig.DEFAULT_COLOR
	body.Parent = model
	model.PrimaryPart = body

	-- Face the house (−X) like authored templates.
	body.CFrame = CFrame.lookAt(body.Position, body.Position + MonsterConfig.MODEL_FACE_DIRECTION)

	applyIdentity(model, instanceId, definition, plotModel, row)
	model.Parent = parent
	return model
end

function MonsterModel.create(
	instanceId: string,
	definition: Types.MonsterDefinition,
	plotModel: Model,
	row: number,
	worldPosition: Vector3,
	parent: Instance
): Model
	local modelId = definition.modelId or definition.id
	local template = ModelUtil.findMonsterTemplate(modelId)
	if not template then
		if not missingTemplateLogged[modelId] then
			missingTemplateLogged[modelId] = true
			log:warn(string.format(
				"missing Assets.Monsters.%s — using placeholder Part (insert Toolbox model in Studio)",
				modelId
			))
		end
		return createPlaceholder(instanceId, definition, plotModel, row, worldPosition, parent)
	end

	local model = ModelUtil.cloneTemplate(template, {
		targetFootprint = footprintFor(definition),
		targetHeight = bodyHeightFor(definition),
		faceDirection = MonsterConfig.MODEL_FACE_DIRECTION,
		orientationDegrees = definition.modelOrientationDegrees,
	})
	model.Name = string.format("%s_%s", definition.id, instanceId)
	ModelUtil.pivotToTileTop(
		model,
		worldPosition,
		definition.modelOrientationDegrees,
		MonsterConfig.MODEL_FACE_DIRECTION
	)
	applyIdentity(model, instanceId, definition, plotModel, row)
	-- Toolbox parts must never block other monsters on the same lane.
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.Massless = true
			descendant.Anchored = true
		end
	end
	model.Parent = parent
	return model
end

function MonsterModel.setColumn(model: Model, column: number)
	model:SetAttribute("Column", column)
end

function MonsterModel.setHealth(model: Model, health: number, maxHealth: number)
	model:SetAttribute("Health", health)
	model:SetAttribute("MaxHealth", maxHealth)
end

return MonsterModel
