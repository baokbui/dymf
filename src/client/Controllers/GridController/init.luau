--!strict
--[[
	GridController
	Client-side grid visualization. Highlights the battlefield tile under the
	cursor on the local player's own plot, coloring it by validity (free vs.
	occupied, read from the tile's replicated "Occupied" attribute).

	Purely visual — the server (GridService) owns tile state. A later milestone's
	PlacementController can read getHoveredTile() to drive placement previews.

	Milestone 2.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local GridConfig = require(Shared.Config.GridConfig)
local Logger = require(Shared.Utilities.Logger)

local GridController = {}
GridController.Name = "GridController"

local log = Logger.new(GridController.Name)

local RAY_DISTANCE = 1000
local localPlayer = Players.LocalPlayer

local highlight: BasePart? = nil
local rayParams = RaycastParams.new()
local hoveredTile: BasePart? = nil

local function createHighlight(): BasePart
	local part = Instance.new("Part")
	part.Name = "GridHoverHighlight"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false -- never block raycasts (including its own)
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Transparency = GridConfig.HIGHLIGHT_TRANSPARENCY
	part.Size = Vector3.new(1, 0.2, 1)
	part.Parent = Workspace
	return part
end

-- A tile belongs to this client if it sits under a plot model owned by them.
local function isOwnTile(tile: BasePart): boolean
	local plotModel = tile:FindFirstAncestorWhichIsA("Model")
	if not plotModel then
		return false
	end
	return plotModel:GetAttribute("OwnerUserId") == localPlayer.UserId
end

local function hideHighlight()
	hoveredTile = nil
	if highlight then
		highlight.Transparency = 1
	end
end

local function showHighlight(tile: BasePart)
	local hl = highlight
	if not hl then
		return
	end
	hoveredTile = tile
	hl.Size = Vector3.new(tile.Size.X, 0.2, tile.Size.Z)
	hl.Position = tile.Position + Vector3.new(0, tile.Size.Y / 2 + GridConfig.HIGHLIGHT_Y_OFFSET, 0)
	hl.Transparency = GridConfig.HIGHLIGHT_TRANSPARENCY

	local occupied = tile:GetAttribute("Occupied") == true
	hl.Color = if occupied then GridConfig.HIGHLIGHT_BLOCKED_COLOR else GridConfig.HIGHLIGHT_VALID_COLOR
end

local function updateFromScreenPoint(x: number, y: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		hideHighlight()
		return
	end

	local ray = camera:ScreenPointToRay(x, y)
	local result = Workspace:Raycast(ray.Origin, ray.Direction * RAY_DISTANCE, rayParams)
	if not result then
		hideHighlight()
		return
	end

	local hit = result.Instance
	if not CollectionService:HasTag(hit, Constants.TAGS.GridTile) or not isOwnTile(hit) then
		hideHighlight()
		return
	end

	showHighlight(hit)
end

local function refreshRayFilter()
	local exclude: { Instance } = {}
	if highlight then
		table.insert(exclude, highlight)
	end
	local character = localPlayer.Character
	if character then
		table.insert(exclude, character)
	end
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = exclude
end

function GridController.init()
	highlight = createHighlight()
	hideHighlight()
	refreshRayFilter()
end

function GridController.start()
	localPlayer.CharacterAdded:Connect(refreshRayFilter)

	-- Event-driven (no per-frame polling): update on cursor movement.
	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			updateFromScreenPoint(input.Position.X, input.Position.Y)
		end
	end)

	log:info("started")
end

-- The tile currently under the cursor on the player's own plot (or nil).
-- Returns the tile's grid coordinates for later placement logic (Milestone 4).
function GridController.getHoveredTile(): { row: number, column: number }?
	local tile = hoveredTile
	if not tile then
		return nil
	end
	return {
		row = tile:GetAttribute("Row") :: number,
		column = tile:GetAttribute("Column") :: number,
	}
end

return GridController
