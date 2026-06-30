--!strict
--[[
	PlacementController
	Owns the client-side placement experience: which Brainrot is selected, the
	translucent ghost preview that follows the cursor, and forwarding place /
	remove *intent* to the server. The server (BrainrotService) validates and is
	the source of truth — the ghost is purely cosmetic.

	Flow:
		UIController's Shop calls select(id) -> placement mode begins.
		The ghost follows the hovered own-plot tile (via GridController), tinted
		green when the tile looks placeable (free + affordable) and red when not.
		InputController.primaryAction places at the tile under the cursor; the
		mode stays active so several can be placed in a row.
		InputController.secondaryAction cancels placement, or — when not placing —
		removes the Brainrot on the targeted own tile.

	Affordability is tracked locally from CoinsUpdated only to color the ghost;
	the authoritative cost check still happens on the server.

	Milestone 4.
]]

local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared.Brainrots)
local PlotConfig = require(Shared.Config.PlotConfig)
local Remotes = require(Shared.Remotes)
local Logger = require(Shared.Utilities.Logger)

local GridController = require(script.Parent.GridController)
local InputController = require(script.Parent.InputController)

local PlacementController = {}
PlacementController.Name = "PlacementController"

local log = Logger.new(PlacementController.Name)

local GHOST_HEIGHT = 6
local FOOTPRINT_RATIO = 0.72
local GHOST_TRANSPARENCY = 0.45
local VALID_COLOR = Color3.fromRGB(120, 220, 120)
local BLOCKED_COLOR = Color3.fromRGB(220, 110, 110)

local selectedId: string? = nil
local balance = 0
local ghost: BasePart? = nil
local placeRemote: RemoteEvent
local removeRemote: RemoteEvent

-- Fires the selected Brainrot id (or nil when cleared) so UIController can keep
-- the Shop highlight in sync with placement mode.
local selectionChangedBindable = Instance.new("BindableEvent")
PlacementController.selectionChanged = selectionChangedBindable.Event

local function ensureGhost(): BasePart
	local existing = ghost
	if existing then
		return existing
	end
	local part = Instance.new("Part")
	part.Name = "PlacementGhost"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false -- never block the placement raycast
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.ForceField
	part.Transparency = GHOST_TRANSPARENCY
	part.Size = Vector3.new(1, GHOST_HEIGHT, 1)
	part.Parent = Workspace
	ghost = part
	return part
end

local function hideGhost()
	if ghost then
		ghost.Transparency = 1
	end
end

local function canAfford(): boolean
	local id = selectedId
	if not id then
		return false
	end
	local definition = Brainrots.get(id)
	return definition ~= nil and balance >= definition.cost
end

-- Repositions/recolors the ghost over `tile` (or hides it when tile is nil).
local function updateGhost(tile: BasePart?)
	if not selectedId then
		hideGhost()
		return
	end
	if not tile then
		hideGhost()
		return
	end

	local part = ensureGhost()
	local footprint = PlotConfig.TILE_SIZE * FOOTPRINT_RATIO
	part.Size = Vector3.new(footprint, GHOST_HEIGHT, footprint)
	part.Position = tile.Position + Vector3.new(0, tile.Size.Y / 2 + GHOST_HEIGHT / 2, 0)
	part.Transparency = GHOST_TRANSPARENCY

	local occupied = tile:GetAttribute("Occupied") == true
	local placeable = not occupied and canAfford()
	part.Color = if placeable then VALID_COLOR else BLOCKED_COLOR
end

local function refreshGhostAt(position: Vector2)
	if not selectedId then
		return
	end
	updateGhost(GridController.resolveTileAt(position.X, position.Y))
end

local function setSelected(id: string?)
	selectedId = id
	if not id then
		hideGhost()
	end
	selectionChangedBindable:Fire(id)
end

-- ===== Public API (called by UIController) =====

function PlacementController.select(brainrotId: string)
	if not Brainrots.exists(brainrotId) then
		return
	end
	setSelected(brainrotId)
end

function PlacementController.cancel()
	setSelected(nil)
end

function PlacementController.isPlacing(): boolean
	return selectedId ~= nil
end

-- ===== Intent handlers =====

local function onPrimaryAction(position: Vector2)
	local id = selectedId
	if not id then
		return
	end
	local tile = GridController.resolveTileAt(position.X, position.Y)
	if not tile then
		return
	end
	-- The server re-validates ownership, occupancy, and cost. Keep placement
	-- mode active so the player can place several without re-selecting.
	placeRemote:FireServer(id, {
		row = tile:GetAttribute("Row"),
		column = tile:GetAttribute("Column"),
	})
end

local function onSecondaryAction(position: Vector2)
	if selectedId then
		PlacementController.cancel()
		return
	end
	-- Not placing: a secondary action on an own occupied tile removes it.
	local tile = GridController.resolveTileAt(position.X, position.Y)
	if not tile or tile:GetAttribute("Occupied") ~= true then
		return
	end
	removeRemote:FireServer({
		row = tile:GetAttribute("Row"),
		column = tile:GetAttribute("Column"),
	})
end

function PlacementController.init()
	placeRemote = Remotes.getEvent("PlaceBrainrot")
	removeRemote = Remotes.getEvent("RemoveBrainrot")
	ensureGhost()
	hideGhost()
end

function PlacementController.start()
	InputController.primaryAction:Connect(onPrimaryAction)
	InputController.secondaryAction:Connect(onSecondaryAction)

	-- Follow the cursor while placing (event-driven, no per-frame polling).
	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if processed or not selectedId then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			refreshGhostAt(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)

	-- Track balance only to tint the ghost; the server owns the real check.
	Remotes.getEvent("CoinsUpdated").OnClientEvent:Connect(function(amount: number)
		balance = amount
	end)

	log:info("started")
end

return PlacementController
