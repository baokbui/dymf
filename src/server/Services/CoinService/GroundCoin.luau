--!strict
--[[
	GroundCoin
	Builds a single collectible ground-coin part. Kept separate from CoinService
	so the service stays focused on currency logic. The coin carries its identity
	as attributes (CoinId / OwnerUserId / Value) and the Coin tag so the owning
	client can detect pickups; the server remains the authority on collection.

	Milestone 3.
]]

local CollectionService = game:GetService("CollectionService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)

local GroundCoin = {}

local DIAMETER = 3
local THICKNESS = 0.5
local COLOR = Color3.fromRGB(255, 200, 40)

function GroundCoin.create(
	coinId: string,
	ownerUserId: number,
	value: number,
	position: Vector3,
	parent: Instance
): BasePart
	local coin = Instance.new("Part")
	coin.Name = coinId
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(THICKNESS, DIAMETER, DIAMETER)
	-- Lay the cylinder flat (circular face up) and stand it slightly proud.
	coin.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	coin.Anchored = true
	coin.Locked = true
	coin.CanCollide = false
	coin.CanTouch = true
	coin.CastShadow = false
	coin.Material = Enum.Material.Neon
	coin.Color = COLOR

	coin:SetAttribute("CoinId", coinId)
	coin:SetAttribute("OwnerUserId", ownerUserId)
	coin:SetAttribute("Value", value)
	CollectionService:AddTag(coin, Constants.TAGS.Coin)

	coin.Parent = parent
	return coin
end

return GroundCoin
