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
local CollisionUtil = require(Shared.Utilities.CollisionUtil)

local WorldStyle = require(Shared.Utilities.WorldStyle)
local MonsterModel = {}

local log = Logger.new("MonsterModel")
local missingTemplateLogged: { [string]: boolean } = {}

local function laneSpanFor(definition: Types.MonsterDefinition): number
	local span = definition.laneSpan or 1
	return math.max(1, math.floor(span))
end

local function modelScaleFor(definition: Types.MonsterDefinition): number
	local scale = definition.modelScale
	if type(scale) ~= "number" or scale <= 0 then
		return 1
	end
	return scale
end

local function hasAuthoredClip(definition: Types.MonsterDefinition): boolean
	if type(definition.walkAnimationId) == "string" and definition.walkAnimationId ~= "" then
		return true
	end
	if type(definition.attackAnimationId) == "string" and definition.attackAnimationId ~= "" then
		return true
	end
	local abilityIds = definition.abilityAnimationIds
	if abilityIds then
		for _, animationId in abilityIds do
			if animationId ~= "" then
				return true
			end
		end
	end
	return false
end

local function bodyHeightFor(definition: Types.MonsterDefinition): number
	local height = MonsterConfig.BODY_HEIGHT
	local span = laneSpanFor(definition)
	if span >= 2 then
		-- Tall enough to match the wide multi-lane footprint without looking squat.
		height *= 2.15
	elseif definition.isBoss then
		height *= 1.25
	end
	local heightScale = definition.modelHeightScale
	if type(heightScale) == "number" and heightScale > 0 then
		height *= heightScale
	end
	return height * modelScaleFor(definition)
end

local function footprintFor(definition: Types.MonsterDefinition): number
	local span = laneSpanFor(definition)
	local footprint: number
	if span > 1 then
		-- Cover ~span tiles across the lawn (Z).
		footprint = PlotConfig.TILE_SIZE * span * MonsterConfig.LANE_SPAN_FOOTPRINT_RATIO
	else
		footprint = PlotConfig.TILE_SIZE * MonsterConfig.FOOTPRINT_RATIO
		if definition.isBoss then
			footprint *= 1.15
		end
	end
	return footprint * modelScaleFor(definition)
end

local function applyIdentity(
	model: Model,
	instanceId: string,
	definition: Types.MonsterDefinition,
	plotModel: Model,
	row: number,
	level: number
)
	model:SetAttribute("InstanceId", instanceId)
	model:SetAttribute("MonsterId", definition.id)
	model:SetAttribute("PlotName", plotModel.Name)
	model:SetAttribute("OwnerUserId", plotModel:GetAttribute("OwnerUserId"))
	model:SetAttribute("Row", row)
	model:SetAttribute("LaneSpan", laneSpanFor(definition))
	model:SetAttribute("Health", definition.health)
	model:SetAttribute("MaxHealth", definition.health)
	model:SetAttribute("IsBoss", definition.isBoss == true)
	model:SetAttribute("MonsterLevel", level)
	CollectionService:AddTag(model, Constants.TAGS.Monster)
end

local function createPlaceholder(
	instanceId: string,
	definition: Types.MonsterDefinition,
	plotModel: Model,
	row: number,
	worldPosition: Vector3,
	parent: Instance,
	level: number
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
	WorldStyle.applyPart(body, "Unit")
	body.Parent = model
	model.PrimaryPart = body

	-- Face the house (−X) like authored templates.
	body.CFrame = CFrame.lookAt(body.Position, body.Position + MonsterConfig.MODEL_FACE_DIRECTION)

	applyIdentity(model, instanceId, definition, plotModel, row, level)
	CollisionUtil.applyMonster(model)
	model.Parent = parent
	return model
end

function MonsterModel.create(
	instanceId: string,
	definition: Types.MonsterDefinition,
	plotModel: Model,
	row: number,
	worldPosition: Vector3,
	parent: Instance,
	level: number
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
		return createPlaceholder(instanceId, definition, plotModel, row, worldPosition, parent, level)
	end

	local span = laneSpanFor(definition)
	local cloneOptions: ModelUtil.PrepareOptions = {
		targetFootprint = footprintFor(definition),
		faceDirection = MonsterConfig.MODEL_FACE_DIRECTION,
		orientationDegrees = definition.modelOrientationDegrees,
		preserveAnimationRig = true,
		skipBodyAlias = true,
		heightScale = definition.modelHeightScale,
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
	applyIdentity(model, instanceId, definition, plotModel, row, level)
	-- Root stays anchored so grid movement can pivot the model. Authored clips
	-- free every other part for the whole life of the unit, including welds,
	-- so nothing sits still while walk / attack / ability tracks play.
	-- Without an authored clip, only Motor6D limbs stay free. Bones do not
	-- hold a mesh, so those skinned parts stay anchored.
	local root = model.PrimaryPart
	local motored = ModelUtil.motorParts(model)
	local authoredClip = hasAuthoredClip(definition)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.Massless = true
			if authoredClip then
				descendant.Anchored = descendant == root
			else
				descendant.Anchored = descendant == root or motored[descendant] ~= true
			end
		end
	end
	if authoredClip or definition.keepWeldConstraints == true then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("WeldConstraint") or descendant:IsA("Weld") then
				descendant.Enabled = true
				if not authoredClip then
					local part0 = descendant.Part0
					local part1 = descendant.Part1
					if part0 and part0 ~= root then
						part0.Anchored = false
					end
					if part1 and part1 ~= root then
						part1.Anchored = false
					end
				end
			end
		end
	end
	CollisionUtil.applyMonster(model)
	model.Parent = parent
	return model
end

local function partWestX(part: BasePart): number
	local cf = part.CFrame
	local size = part.Size
	local half = size.X * 0.5 * math.abs(cf.RightVector.X)
		+ size.Y * 0.5 * math.abs(cf.UpVector.X)
		+ size.Z * 0.5 * math.abs(cf.LookVector.X)
	return cf.Position.X - half
end

local function headScore(name: string): number
	local lower = string.lower(name)
	if lower == "head" then
		return 3
	end
	if string.find(lower, "head", 1, true) then
		return 2
	end
	if string.find(lower, "cephalothorax", 1, true) then
		return 1
	end
	return 0
end

-- Columns from the pivot to the head's west edge (the side that reaches the
-- lawn first). Positive means the head is still east of the pivot. Nil when
-- the rig has no head part.
function MonsterModel.measureHeadLeadColumns(model: Model): number?
	local best: BasePart? = nil
	local bestScore = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local score = headScore(descendant.Name)
			if score > bestScore or (score > 0 and score == bestScore and best ~= nil and descendant.Size.Magnitude > best.Size.Magnitude) then
				best = descendant
				bestScore = score
			end
		end
	end
	if not best then
		return nil
	end
	local tile = PlotConfig.TILE_SIZE
	if tile <= 0 then
		return nil
	end
	return (partWestX(best) - model:GetPivot().Position.X) / tile
end

function MonsterModel.setColumn(model: Model, column: number)
	model:SetAttribute("Column", column)
end

function MonsterModel.setHealth(model: Model, health: number, maxHealth: number)
	model:SetAttribute("Health", health)
	model:SetAttribute("MaxHealth", maxHealth)
end

return MonsterModel
