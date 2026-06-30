--!strict
--[[
	BrainrotModel
	Builds the physical model for a placed Brainrot. Kept separate from
	BrainrotService so the service stays focused on placement logic and state
	(mirrors the CoinService/GroundCoin split).

	The model is data-driven: its tint comes from the Brainrot definition's
	optional `color`, and its footprint is sized relative to the battlefield tile
	so it always fits one cell. Identity travels as attributes (InstanceId /
	BrainrotId / OwnerUserId / Row / Column / Health) and the Brainrot tag, so
	clients and later combat/save systems can resolve it without extra remotes.

	Milestone 4 (visual + identity only; attack/coin behavior arrives M5-7).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local PlotConfig = require(Shared.Config.PlotConfig)
local Types = require(Shared.Types)

local BrainrotModel = {}

-- Body footprint as a fraction of a tile, and how tall the unit stands.
local FOOTPRINT_RATIO = 0.72
local BODY_HEIGHT = 6
local DEFAULT_COLOR = Color3.fromRGB(180, 140, 220)

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
	local footprint = PlotConfig.TILE_SIZE * FOOTPRINT_RATIO

	local model = Instance.new("Model")
	model.Name = string.format("%s_%s", definition.id, instanceId)

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(footprint, BODY_HEIGHT, footprint)
	body.Position = topCenter + Vector3.new(0, BODY_HEIGHT / 2, 0)
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

	model:SetAttribute("InstanceId", instanceId)
	model:SetAttribute("BrainrotId", definition.id)
	model:SetAttribute("OwnerUserId", ownerUserId)
	model:SetAttribute("Row", position.row)
	model:SetAttribute("Column", position.column)
	model:SetAttribute("Health", definition.health)
	CollectionService:AddTag(model, Constants.TAGS.Brainrot)

	model.Parent = parent
	return model
end

return BrainrotModel
