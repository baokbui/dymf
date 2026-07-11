--!strict
--[[
	PlacementController
	Owns the client-side placement experience: which Brainrot is selected, the
	translucent ghost preview that follows the cursor, shovel removal mode, and
	forwarding place / remove *intent* to the server. The server (BrainrotService)
	validates and is the source of truth — the ghost is purely cosmetic.

	Milestone 4.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared.Brainrots)
local PlotConfig = require(Shared.Config.PlotConfig)
local Remotes = require(Shared.Remotes)
local Logger = require(Shared.Utilities.Logger)

local UIEvents = require(script.Parent.Parent.UIEvents)
local GridController = require(script.Parent.GridController)
local InputController = require(script.Parent.InputController)
local AudioController = require(script.Parent.AudioController)

local PlacementController = {}
PlacementController.Name = "PlacementController"

local log = Logger.new(PlacementController.Name)

local localPlayer = Players.LocalPlayer

local GHOST_HEIGHT = 6
local GHOST_TRANSPARENCY = 0.45
local VALID_COLOR = Color3.fromRGB(120, 220, 120)
local BLOCKED_COLOR = Color3.fromRGB(220, 110, 110)

local selectedId: string? = nil
local balance = 0
local placementAllowed = false
local shovelMode = false
local ghost: BasePart? = nil
local shovelCursor: Frame? = nil
local placeRemote: RemoteEvent
local removeRemote: RemoteEvent

local selectionChangedBindable = Instance.new("BindableEvent")
PlacementController.selectionChanged = selectionChangedBindable.Event

local shovelModeChangedBindable = Instance.new("BindableEvent")
PlacementController.shovelModeChanged = shovelModeChangedBindable.Event

local function ensureGhost(): BasePart
	local existing = ghost
	if existing then
		return existing
	end
	local part = Instance.new("Part")
	part.Name = "PlacementGhost"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
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
	local footprint = PlotConfig.TILE_SIZE * PlotConfig.BRAINROT_FOOTPRINT_RATIO
	part.Size = Vector3.new(footprint, GHOST_HEIGHT, footprint)
	part.Position = tile.Position + Vector3.new(0, tile.Size.Y / 2 + GHOST_HEIGHT / 2, 0)
	part.Transparency = GHOST_TRANSPARENCY

	local occupied = tile:GetAttribute("Occupied") == true
	local placeable = placementAllowed and not occupied and canAfford()
	part.Color = if placeable then VALID_COLOR else BLOCKED_COLOR
end

local function refreshGhostAt(position: Vector2)
	if not selectedId then
		return
	end
	updateGhost(GridController.resolveTileAt(position.X, position.Y))
end

local function ensureShovelCursor(): Frame
	local existing = shovelCursor
	if existing then
		return existing
	end

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local cursor = Instance.new("Frame")
	cursor.Name = "ShovelCursor"
	cursor.Size = UDim2.fromOffset(28, 28)
	cursor.BackgroundTransparency = 1
	cursor.Visible = false
	cursor.ZIndex = 1000
	cursor.Parent = playerGui:WaitForChild("MainUI")

	local handle = Instance.new("Frame")
	handle.Name = "Handle"
	handle.AnchorPoint = Vector2.new(0.5, 0)
	handle.Position = UDim2.new(0.5, 0, 0, 2)
	handle.Size = UDim2.fromOffset(6, 14)
	handle.BackgroundColor3 = Color3.fromRGB(120, 80, 40)
	handle.BorderSizePixel = 0
	handle.Parent = cursor
	local handleCorner = Instance.new("UICorner")
	handleCorner.CornerRadius = UDim.new(0, 2)
	handleCorner.Parent = handle

	local blade = Instance.new("Frame")
	blade.Name = "Blade"
	blade.AnchorPoint = Vector2.new(0.5, 1)
	blade.Position = UDim2.new(0.5, 0, 1, -2)
	blade.Size = UDim2.fromOffset(18, 10)
	blade.BackgroundColor3 = Color3.fromRGB(180, 180, 190)
	blade.BorderSizePixel = 0
	blade.Parent = cursor
	local bladeCorner = Instance.new("UICorner")
	bladeCorner.CornerRadius = UDim.new(0, 3)
	bladeCorner.Parent = blade

	shovelCursor = cursor
	return cursor
end

local function setShovelCursorVisible(visible: boolean)
	local cursor = ensureShovelCursor()
	cursor.Visible = visible
	UserInputService.MouseIconEnabled = not visible
end

local function updateShovelCursorPosition(position: Vector2)
	local cursor = shovelCursor
	if not cursor or not cursor.Visible then
		return
	end
	cursor.Position = UDim2.fromOffset(position.X + 12, position.Y + 12)
end

local function fireShovelModeChanged()
	shovelModeChangedBindable:Fire(shovelMode)
end

local function setSelected(id: string?)
	selectedId = id
	if not id then
		hideGhost()
	end
	selectionChangedBindable:Fire(id)
end

local function tryRemoveAt(position: Vector2)
	local tile = GridController.resolveTileAt(position.X, position.Y)
	if not tile or tile:GetAttribute("Occupied") ~= true then
		return
	end
	removeRemote:FireServer({
		row = tile:GetAttribute("Row"),
		column = tile:GetAttribute("Column"),
	})
	AudioController.play("RemoveBrainrot")
end

function PlacementController.select(brainrotId: string)
	if not placementAllowed then
		return
	end
	if not Brainrots.exists(brainrotId) then
		return
	end
	if shovelMode then
		PlacementController.setShovelMode(false)
	end
	setSelected(brainrotId)
	AudioController.play("UiSelect")
end

function PlacementController.setPlacementAllowed(allowed: boolean)
	placementAllowed = allowed
	if not allowed then
		PlacementController.cancel()
		PlacementController.setShovelMode(false)
	end
end

function PlacementController.cancel()
	setSelected(nil)
end

function PlacementController.isPlacing(): boolean
	return selectedId ~= nil
end

function PlacementController.isShovelMode(): boolean
	return shovelMode
end

function PlacementController.setShovelMode(enabled: boolean)
	if enabled and not placementAllowed then
		return
	end
	if enabled and selectedId then
		PlacementController.cancel()
	end
	if shovelMode == enabled then
		return
	end
	shovelMode = enabled
	setShovelCursorVisible(enabled)
	if enabled then
		local mouse = localPlayer:GetMouse()
		updateShovelCursorPosition(Vector2.new(mouse.X, mouse.Y))
		AudioController.play("UiClick")
	end
	fireShovelModeChanged()
end

function PlacementController.toggleShovelMode()
	PlacementController.setShovelMode(not shovelMode)
end

local function onPrimaryAction(position: Vector2)
	if shovelMode then
		if placementAllowed then
			tryRemoveAt(position)
		end
		return
	end

	local id = selectedId
	if not id or not placementAllowed then
		return
	end
	local tile = GridController.resolveTileAt(position.X, position.Y)
	if not tile then
		return
	end

	local definition = Brainrots.get(id)
	if definition then
		UIEvents.markPendingSpend()
	end

	placeRemote:FireServer(id, {
		row = tile:GetAttribute("Row"),
		column = tile:GetAttribute("Column"),
	})
	AudioController.play("PlaceBrainrot")
	PlacementController.cancel()
end

function PlacementController.init()
	placeRemote = Remotes.getEvent("PlaceBrainrot")
	removeRemote = Remotes.getEvent("RemoveBrainrot")
	ensureGhost()
	hideGhost()
end

function PlacementController.start()
	InputController.primaryAction:Connect(onPrimaryAction)

	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			local position = Vector2.new(input.Position.X, input.Position.Y)
			if shovelMode then
				updateShovelCursorPosition(position)
			end
			if processed or not selectedId then
				return
			end
			refreshGhostAt(position)
		end
	end)

	Remotes.getEvent("CoinsUpdated").OnClientEvent:Connect(function(amount: number)
		balance = amount
	end)

	log:info("started")
end

return PlacementController
