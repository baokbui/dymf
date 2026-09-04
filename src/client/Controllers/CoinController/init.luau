--!strict
--[[
	CoinController
	Detects when the local player walks over one of their own ground coins and
	sends a CollectCoin intent to the server. The server is the authority: it
	re-validates ownership, existence, and distance before crediting, so this
	controller only signals "I touched my coin" — it never changes balances.

	Milestone 3. Milestone 11 adds pickup sparkle VFX.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Remotes = require(Shared.Remotes)
local Logger = require(Shared.Utilities.Logger)

local UIEvents = require(script.Parent.Parent.UIEvents)
local VfxUtil = require(script.Parent.Parent.Utilities.VfxUtil)
local AudioController = require(script.Parent.AudioController)

local CoinController = {}
CoinController.Name = "CoinController"

local log = Logger.new(CoinController.Name)

local REQUEST_DEBOUNCE = 0.5 -- seconds between collect attempts per coin
local localPlayer = Players.LocalPlayer

local lastRequest: { [Instance]: number } = {}
local pendingPickup: { [Instance]: boolean } = {}
local collectEvent: RemoteEvent

local function tryCollect(coin: BasePart, otherPart: BasePart)
	local character = localPlayer.Character
	if not character or not otherPart:IsDescendantOf(character) then
		return
	end
	if coin:GetAttribute("Landed") ~= true then
		return
	end

	local now = os.clock()
	local last = lastRequest[coin]
	if last and now - last < REQUEST_DEBOUNCE then
		return
	end
	lastRequest[coin] = now
	pendingPickup[coin] = true

	collectEvent:FireServer(coin:GetAttribute("CoinId"))
end

local function onCoinRemoved(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	if instance:GetAttribute("OwnerUserId") ~= localPlayer.UserId then
		return
	end

	if pendingPickup[instance] or instance:GetAttribute("Collected") == true then
		VfxUtil.playCoinPickup(instance.Position)
		AudioController.play("CoinCollect")
		local value = instance:GetAttribute("Value")
		if type(value) == "number" and value > 0 then
			UIEvents.fireCoinDelta(value)
		end
	end

	lastRequest[instance] = nil
	pendingPickup[instance] = nil
end

local function onCoinAdded(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	-- Only react to our own coins; other players' coins replicate too.
	if instance:GetAttribute("OwnerUserId") ~= localPlayer.UserId then
		return
	end
	instance.Touched:Connect(function(otherPart)
		tryCollect(instance, otherPart)
	end)
end

function CoinController.init()
	collectEvent = Remotes.getEvent("CollectCoin")
end

function CoinController.start()
	for _, coin in CollectionService:GetTagged(Constants.TAGS.Coin) do
		onCoinAdded(coin)
	end
	CollectionService:GetInstanceAddedSignal(Constants.TAGS.Coin):Connect(onCoinAdded)
	CollectionService:GetInstanceRemovedSignal(Constants.TAGS.Coin):Connect(onCoinRemoved)

	log:info("started")
end

return CoinController
