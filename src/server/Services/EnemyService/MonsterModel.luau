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

local function laneSpanFor(definition: Types.MonsterDefinition): number
	local span = definition.laneSpan or 1
	return math.max(1, math.floor(span))
end

local function bodyHeightFor(definition: Types.MonsterDefinition): number
	local height = MonsterConfig.BODY_HEIGHT
	local span = laneSpanFor(definition)
	if span >= 2 then
		-- Tall enough to match the wide multi-lane footprint without looking squat.
		return height * 2.15
	end
	if definition.isBoss then
		return height * 1.25
	end
	return height
end

local function footprintFor(definition: Types.MonsterDefinition): number
	local span = laneSpanFor(definition)
	if span > 1 then
		-- Cover ~span tiles across the lawn (Z).
		return PlotConfig.TILE_SIZE * span * MonsterConfig.LANE_SPAN_FOOTPRINT_RATIO
	end
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
	model:SetAttribute("LaneSpan", laneSpanFor(definition))
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
	local bodyHeight = bodyHeightFor(definition)

	local model = Instance.new("Model")
	model.Name = string.format("%s_%s", definition.id, instanceId)

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(footprint * 0.55, bodyHeight, footprint)
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

	local span = laneSpanFor(definition)
	local cloneOptions: ModelUtil.PrepareOptions = {
		targetFootprint = footprintFor(definition),
		faceDirection = MonsterConfig.MODEL_FACE_DIRECTION,
		orientationDegrees = definition.modelOrientationDegrees,
		preserveAnimationRig = true,
		skipBodyAlias = true,
	}
	-- Multi-lane bosses size by footprint so they actually span the lawn rows;
	-- a tight height cap would shrink them back to a single-tile silhouette.
	if span <= 1 then
		cloneOptions.targetHeight = bodyHeightFor(definition)
	end

	local model = ModelUtil.cloneTemplate(template, cloneOptions)
	model.Name = string.format("%s_%s", definition.id, instanceId)
	ModelUtil.pivotToTileTop(
		model,
		worldPosition,
		definition.modelOrientationDegrees,
		MonsterConfig.MODEL_FACE_DIRECTION
	)
	applyIdentity(model, instanceId, definition, plotModel, row)
	-- Never block other monsters; keep only the root anchored so Motor6Ds animate.
	local root = model.PrimaryPart
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.Massless = true
			descendant.Anchored = descendant == root
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
