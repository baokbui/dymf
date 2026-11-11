--!strict
-- Retains the existing house/plot API while building an open sanctuary.
local SanctuaryBuilder = require(script.Parent.SanctuaryBuilder)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config.HouseConfig)
local HouseSanitize = require(script.Parent.HouseSanitize)
local HouseBuilder = {}

function HouseBuilder.sanitize(house: Model)
	HouseSanitize.stripLockBase(house)
end

function HouseBuilder.setOwnerLabel(house: Model, ownerName: string?)
	local label = house:FindFirstChild("Owner", true)
	if label and label:IsA("TextLabel") then
		label.Text = if ownerName then string.format(Config.OWNER_SIGN_FORMAT, ownerName) else Config.EMPTY_SIGN_TEXT
	end
end

function HouseBuilder.build(originPosition: Vector3, houseZoneWestX: number, playLeftX: number): Model
	return SanctuaryBuilder.build(originPosition, houseZoneWestX, playLeftX)
end

return HouseBuilder
