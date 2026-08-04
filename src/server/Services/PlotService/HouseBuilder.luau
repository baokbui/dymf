--!strict
--[[
	HouseBuilder
	Places a house in each plot's HOUSE_ZONE. Prefers Assets.Houses[MODEL_ID];
	falls back to ProceduralHouse. Pedestals + owner sign via focused modules.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HouseConfig = require(ReplicatedStorage.Shared.Config.HouseConfig)
local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)
local ModelUtil = require(ReplicatedStorage.Shared.Utilities.ModelUtil)

local HouseBossDisplay = require(script.Parent.HouseBossDisplay)
local HouseMascot = require(script.Parent.HouseMascot)
local HouseSanitize = require(script.Parent.HouseSanitize)
local HouseSlot = require(script.Parent.HouseSlot)
local ProceduralHouse = require(script.Parent.ProceduralHouse)

local HouseBuilder = {}

local log = Logger.new("HouseBuilder")
local missingTemplateLogged = false

function HouseBuilder.sanitize(house: Model)
	HouseSanitize.stripLockBase(house)
end

function HouseBuilder.setOwnerLabel(house: Model, ownerName: string?)
	HouseSanitize.setOwnerLabel(house, ownerName)
end

local function buildFromTemplate(template: Model, slot: HouseSlot.Slot): Model
	local cfg = HouseConfig
	local model = ModelUtil.cloneTemplate(template, {
		faceDirection = cfg.FACE_DIRECTION,
		orientationDegrees = cfg.MODEL_ORIENTATION_DEGREES,
		keepCollision = true,
		skipBodyAlias = true,
	})
	model.Name = "House"
	HouseSanitize.stripLockBase(model)

	local restoreMascot = HouseMascot.beginExcludeFromFit(model)

	local size = select(1, ModelUtil.getVisualSizeAndCenter(model))
	local scaleCandidates: { number } = {}
	if size.X > 0.01 then
		table.insert(scaleCandidates, cfg.DEPTH / size.X)
	end
	if size.Z > 0.01 then
		table.insert(scaleCandidates, cfg.WIDTH / size.Z)
	end
	if size.Y > 0.01 and cfg.MAX_HEIGHT > 0 then
		table.insert(scaleCandidates, cfg.MAX_HEIGHT / size.Y)
	end
	if #scaleCandidates > 0 then
		local scale = scaleCandidates[1]
		for i = 2, #scaleCandidates do
			scale = math.min(scale, scaleCandidates[i])
		end
		scale = math.clamp(scale, 0.05, 20)
		model:ScaleTo(model:GetScale() * scale)
	end

	restoreMascot()

	ModelUtil.snapFeetToTileTop(model, Vector3.new(slot.centerX, slot.grassY, slot.centerZ))

	local fittedSize, fittedCenter = ModelUtil.getVisualSizeAndCenter(model)
	local front = fittedCenter.X + fittedSize.X * 0.5
	local delta = Vector3.new(slot.frontX - front, 0, slot.centerZ - fittedCenter.Z)
	model:PivotTo(model:GetPivot() + delta)

	local finalSize, finalCenter = ModelUtil.getVisualSizeAndCenter(model)
	HouseBossDisplay.attach(model, slot, 0, slot.grassY)
	HouseSanitize.setOwnerLabel(model, nil)
	HouseMascot.dress(model)

	model:SetAttribute("HouseFrontX", slot.frontX - slot.originX)
	model:SetAttribute("HouseSource", "Template")
	model:SetAttribute("HouseModelId", cfg.MODEL_ID)
	model.WorldPivot = CFrame.new(finalCenter.X, slot.grassY, finalCenter.Z)
	return model
end

function HouseBuilder.build(
	originPosition: Vector3,
	houseZoneWestX: number,
	playLeftX: number
): Model
	local slot = HouseSlot.compute(originPosition, houseZoneWestX, playLeftX)
	local template = ModelUtil.findHouseTemplate(HouseConfig.MODEL_ID)
	if template then
		return buildFromTemplate(template, slot)
	end

	if not missingTemplateLogged then
		missingTemplateLogged = true
		log:warn(string.format(
			"missing Assets.Houses.%s — using procedural house (insert Toolbox model in Studio)",
			HouseConfig.MODEL_ID
		))
	end
	return ProceduralHouse.build(slot)
end

return HouseBuilder
