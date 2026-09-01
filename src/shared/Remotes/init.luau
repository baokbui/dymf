--!strict
--[[
	Remotes
	Single source of truth for the client/server network boundary.

	Remote names are declared here once. The server creates the instances on
	first access; the client waits for them. This keeps the rule "Never trust
	RemoteEvents" enforceable in one place — all traffic flows through here and
	is validated server-side by the owning Service.

	Usage:
		local Remotes = require(ReplicatedStorage.Shared.Remotes)
		local placeRemote = Remotes.getEvent("PlaceBrainrot")
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
local WAIT_TIMEOUT = 10

-- Declare every RemoteEvent name the game uses. Adding a name here is the only
-- step needed to register a new event.
local EVENT_NAMES = {
	-- Placement (Milestone 4)
	"PlaceBrainrot",
	"RemoveBrainrot",
	"PlaceBrainrotFailed",
	"PlantCooldownsUpdated", -- brainrotId → readyAt (Workspace:GetServerTimeNow)
	-- Coins (Milestone 3)
	"CollectCoin",
	"CoinsUpdated",
	-- Levels (Milestone 8)
	"StartLevel",
	"LevelStateChanged",
	"SelectLevel",
	"RewindDay", -- Defeat → Preparation on the failed day (Game Over rewind)
	"ContinueVictory", -- Victory overlay Continue → Preparation on the next day
	-- Settings / progression (Milestone 13)
	"ResetProgress",
	"ProfileUpdated",
	"SetEquipped",
	"OpenProgressionStore",
	"BuyStoreItem",
	"StorePurchaseFailed",
	"StorePurchaseSucceeded",
	-- Brainrots (Milestone 5)
	"BrainrotAction",
	-- Fog-cleared lawn rows (Giraffa Celeste) — owner-only
	"FogRowsChanged",
	-- Combat visuals (Milestone 7)
	"CombatVisual",
}

-- Declare every RemoteFunction name the game uses.
local FUNCTION_NAMES = {
	"RequestState",
}

local Remotes = {}

local isServer = RunService:IsServer()

local function getFolder(): Instance
	if isServer then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME, WAIT_TIMEOUT) :: Instance
end

local function getRemote(className: string, name: string): Instance
	local folder = getFolder()
	if isServer then
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
		return remote
	end
	return folder:WaitForChild(name, WAIT_TIMEOUT) :: Instance
end

function Remotes.getEvent(name: string): RemoteEvent
	return getRemote("RemoteEvent", name) :: RemoteEvent
end

function Remotes.getFunction(name: string): RemoteFunction
	return getRemote("RemoteFunction", name) :: RemoteFunction
end

-- Eagerly creates every declared remote. Call once on the server during
-- bootstrap so clients never race ahead of instance creation.
function Remotes.initServer()
	assert(isServer, "Remotes.initServer must run on the server")
	for _, name in EVENT_NAMES do
		Remotes.getEvent(name)
	end
	for _, name in FUNCTION_NAMES do
		Remotes.getFunction(name)
	end
end

return Remotes
