--!strict
--[[
	MonsterModel
	Builds the physical model for a spawned monster. Data-driven tint from the
	registry definition; identity via attributes + Monster tag.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local MonsterConfig = require(Shared.Config.MonsterConfig)
local PlotConfig = require(Shared.Config.PlotConfig)
local Types = require(Shared.Types)

local MonsterModel = {}

function MonsterModel.create(
	instanceId: string,
	definition: Types.MonsterDefinition,
	plotModel: Model,
	row: number,
	worldPosition: Vector3,
	parent: Instance
): Model
	local footprint = PlotConfig.TILE_SIZE * MonsterConfig.FOOTPRINT_RATIO
	local bodyHeight = MonsterConfig.BODY_HEIGHT
	if definition.isBoss then
		bodyHeight *= 1.25
		footprint *= 1.15
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

	model:SetAttribute("InstanceId", instanceId)
	model:SetAttribute("MonsterId", definition.id)
	model:SetAttribute("PlotName", plotModel.Name)
	model:SetAttribute("Row", row)
	model:SetAttribute("Health", definition.health)
	model:SetAttribute("MaxHealth", definition.health)
	model:SetAttribute("IsBoss", definition.isBoss == true)
	CollectionService:AddTag(model, Constants.TAGS.Monster)

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
