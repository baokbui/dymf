--!strict
--[[
	BrainrotService
	Server-authoritative owner of Brainrot placement, instance lifecycle, and
	per-instance state on a plot. The client only sends placement/removal
	*intent*; this service validates everything and is the source of truth.

	Placement pipeline (PlaceBrainrot), every step server-side:
		1. Validate argument shapes and that the position is in-bounds.
		2. Resolve the definition from the data-driven Brainrots registry
		   (never branch on Brainrot names).
		3. Resolve the caller's owned plot (PlotService).
		4. Pre-check affordability against the authoritative balance.
		5. Reserve the tile (GridService.tryOccupy) — rejects occupied/unknown.
		6. Charge coins (CoinService.trySpend); release the tile if the charge
		   fails (guards against a balance race between steps 4 and 6).
		7. Build the model and record the instance.

	Removal (RemoveBrainrot) verifies the caller owns the Brainrot on the tile,
	frees the tile, and destroys the model. Digging up a Brainrot is NOT
	refunded — the coins spent placing it are lost.

	Milestone 4 (placement + lifecycle). Attack / coin-generation behavior is
	added in Milestones 5-7; placed instances currently just hold state.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Brainrots = require(Shared.Brainrots)
local Remotes = require(Shared.Remotes)
local GridUtil = require(Shared.Utilities.GridUtil)
local Logger = require(Shared.Utilities.Logger)
local Types = require(Shared.Types)

local BrainrotModel = require(script.BrainrotModel)
local PlotService = require(script.Parent.PlotService)
local GridService = require(script.Parent.GridService)
local CoinService = require(script.Parent.CoinService)

local BrainrotService = {}
BrainrotService.Name = "BrainrotService"

local log = Logger.new(BrainrotService.Name)

local BRAINROTS_FOLDER = "Brainrots"

type Placement = {
	instanceId: string,
	brainrotId: string,
	ownerUserId: number,
	plotModel: Model,
	position: Types.GridPosition,
	model: Model,
	health: number,
}

-- instanceId -> placement (single source of runtime placement state).
local placements: { [string]: Placement } = {}
local nextInstanceId = 0

-- Coerces untrusted client input into a clean integer grid position, or nil.
local function toGridPosition(raw: unknown): Types.GridPosition?
	if type(raw) ~= "table" then
		return nil
	end
	local row = (raw :: any).row
	local column = (raw :: any).column
	if type(row) ~= "number" or type(column) ~= "number" then
		return nil
	end
	if row ~= math.floor(row) or column ~= math.floor(column) then
		return nil
	end
	local position = { row = row, column = column }
	if not GridUtil.isInBounds(position) then
		return nil
	end
	return position
end

local function brainrotsFolder(plotModel: Model): Folder
	local folder = plotModel:FindFirstChild(BRAINROTS_FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = BRAINROTS_FOLDER
		folder.Parent = plotModel
	end
	return folder :: Folder
end

-- Tears down a placement: destroys the model, frees its tile, drops state.
local function destroyPlacement(placement: Placement)
	placements[placement.instanceId] = nil
	GridService.release(placement.plotModel, placement.position)
	placement.model:Destroy()
end

-- ===== Remote handlers (untrusted input) =====

local function onPlaceBrainrot(player: Player, brainrotId: unknown, rawPosition: unknown)
	if type(brainrotId) ~= "string" then
		return
	end
	local position = toGridPosition(rawPosition)
	if not position then
		return
	end

	local definition = Brainrots.get(brainrotId)
	if not definition then
		return
	end

	local plot = PlotService.getPlot(player)
	if not plot then
		return
	end
	local plotModel = plot.model

	-- Affordability pre-check (cheap reject before reserving the tile).
	if CoinService.getBalance(player) < definition.cost then
		return
	end

	nextInstanceId += 1
	local instanceId = string.format("Brainrot_%d", nextInstanceId)

	-- Reserve first so two requests can't claim the same tile, then charge.
	if not GridService.tryOccupy(plotModel, position, instanceId) then
		return -- tile occupied / unknown / out of bounds
	end
	if not CoinService.trySpend(player, definition.cost) then
		GridService.release(plotModel, position) -- balance changed mid-flight
		return
	end

	local topCenter = GridService.getWorldPosition(plotModel, position)
	if not topCenter then
		-- Should not happen (tile just reserved); roll everything back.
		GridService.release(plotModel, position)
		CoinService.addCoins(player, definition.cost)
		return
	end

	local model = BrainrotModel.create(
		instanceId,
		definition,
		player.UserId,
		position,
		topCenter,
		brainrotsFolder(plotModel)
	)

	placements[instanceId] = {
		instanceId = instanceId,
		brainrotId = definition.id,
		ownerUserId = player.UserId,
		plotModel = plotModel,
		position = position,
		model = model,
		health = definition.health,
	}
end

local function onRemoveBrainrot(player: Player, rawPosition: unknown)
	local position = toGridPosition(rawPosition)
	if not position then
		return
	end

	local plot = PlotService.getPlot(player)
	if not plot then
		return
	end

	local tile = GridService.getTile(plot.model, position)
	if not tile or not tile.occupied or not tile.brainrotInstanceId then
		return
	end

	local placement = placements[tile.brainrotInstanceId]
	if not placement or placement.ownerUserId ~= player.UserId then
		return -- defensive: only the owner may remove their Brainrot
	end

	-- Digging up a Brainrot frees the tile but is NOT refunded: removal is a
	-- permanent loss of the coins spent placing it.
	destroyPlacement(placement)
end

-- ===== Player lifecycle =====

-- BrainrotService owns Brainrot model lifecycle, so it clears a leaving
-- player's instances itself (PlotService independently resets tile occupancy).
local function onPlayerRemoving(player: Player)
	for _, placement in placements do
		if placement.ownerUserId == player.UserId then
			destroyPlacement(placement)
		end
	end
end

-- ===== Public API (for other services) =====

-- Read-only list of a plot's current placements (used by combat/save later).
function BrainrotService.getPlacements(plotModel: Model): { Placement }
	local result: { Placement } = {}
	for _, placement in placements do
		if placement.plotModel == plotModel then
			table.insert(result, placement)
		end
	end
	return result
end

function BrainrotService.init()
end

function BrainrotService.start()
	Remotes.getEvent("PlaceBrainrot").OnServerEvent:Connect(onPlaceBrainrot)
	Remotes.getEvent("RemoveBrainrot").OnServerEvent:Connect(onRemoveBrainrot)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	log:info("started")
end

return BrainrotService
