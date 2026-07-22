--!strict
--[[
	HouseSlot
	Shared placement math for the plot house zone (west of the lawn).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HouseConfig = require(ReplicatedStorage.Shared.Config.HouseConfig)

local HouseSlot = {}

export type Slot = {
	grassY: number,
	floorTop: number,
	centerX: number,
	centerZ: number,
	frontX: number,
	backX: number,
	originX: number,
}

function HouseSlot.compute(
	originPosition: Vector3,
	houseZoneWestX: number,
	playLeftX: number
): Slot
	local cfg = HouseConfig
	local grassY = originPosition.Y
	local backX = originPosition.X + houseZoneWestX + 4
	local frontX = backX + cfg.DEPTH
	local maxFront = originPosition.X + playLeftX - cfg.YARD_GAP
	if frontX > maxFront then
		frontX = maxFront
		backX = frontX - cfg.DEPTH
	end
	return {
		grassY = grassY,
		floorTop = grassY + cfg.FLOOR_THICKNESS,
		centerX = (frontX + backX) / 2,
		centerZ = originPosition.Z,
		frontX = frontX,
		backX = backX,
		originX = originPosition.X,
	}
end

return HouseSlot
