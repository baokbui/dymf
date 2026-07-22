--!strict
--[[
	PlacementController
	Owns the client-side placement experience: which Brainrot is selected, the
	translucent ghost preview that follows the cursor, shovel removal mode, and
	forwarding place / remove *intent* to the server. The server (BrainrotService)
	validates and is the source of truth — the ghost is purely cosmetic.

	Ghost prefers an Assets.Brainrots template clone when available; otherwise a
	ForceField Part placeholder (same as pre-M15).
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioConfig = require(Shared.Config.AudioConfig)
local Brainrots = require(Shared.Brainrots)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Logger = require(Shared.Utilities.Logger)
local ModelUtil = require(Shared.Utilities.ModelUtil)

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
local selectionAllowed = false
local shovelMode = false
local ghostModel: Model? = nil
local ghostPart: BasePart? = nil
local ghostBrainrotId: string? = nil
local shovelCursor: Frame? = nil
local placeRemote: RemoteEvent
local removeRemote: RemoteEvent

local selectionChangedBindable = Instance.new("BindableEvent")
PlacementController.selectionChanged = selectionChangedBindable.Event

local shovelModeChangedBindable = Instance.new("BindableEvent")
PlacementController.shovelModeChanged = shovelModeChangedBindable.Event

local function footprintFor(definition: Types.BrainrotDefinition): number
	return ModelUtil.brainrotFootprintStuds(definition)
end

local function destroyGhostVisuals()
	if ghostModel then
		ghostModel:Destroy()
		ghostModel = nil
	end
	if ghostPart then
		ghostPart:Destroy()
		ghostPart = nil
	end
	ghostBrainrotId = nil
end

local function hideGhost()
	if ghostModel then
		for _, descendant in ghostModel:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Transparency = 1
			end
		end
	end
	if ghostPart then
		ghostPart.Transparency = 1
	end
end

local function tintGhost(placeable: boolean)
	local color = if placeable then VALID_COLOR else BLOCKED_COLOR
	if ghostModel then
		for _, descendant in ghostModel:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Color = color
				descendant.Transparency = GHOST_TRANSPARENCY
				descendant.Material = Enum.Material.ForceField
			end
		end
	elseif ghostPart then
		ghostPart.Color = color
		ghostPart.Transparency = GHOST_TRANSPARENCY
	end
end

local function ensureGhostFor(definition: Types.BrainrotDefinition)
	if ghostBrainrotId == definition.id and (ghostModel or ghostPart) then
		return
	end
	destroyGhostVisuals()
	ghostBrainrotId = definition.id

	local modelId = definition.modelId or definition.id
	local template = ModelUtil.findBrainrotTemplate(modelId)
	if template then
		local model = ModelUtil.cloneBrainrotTemplate(template, {
			targetFootprint = footprintFor(definition),
			ghost = true,
			ghostTransparency = GHOST_TRANSPARENCY,
			tintColor = VALID_COLOR,
			orientationDegrees = definition.modelOrientationDegrees,
		})
		model.Name = "PlacementGhost"
		model.Parent = Workspace
		ghostModel = model
		return
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
	ghostPart = part
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

	local definition = Brainrots.get(selectedId)
	if not definition then
		hideGhost()
		return
	end

	ensureGhostFor(definition)
	local topCenter = tile.Position + Vector3.new(0, tile.Size.Y / 2, 0)
	local occupied = tile:GetAttribute("Occupied") == true
	local placeable = placementAllowed and not occupied and canAfford()

	if ghostModel then
		ModelUtil.pivotToTileTop(ghostModel, topCenter, definition.modelOrientationDegrees)
	elseif ghostPart then
		local footprint = footprintFor(definition)
		local height = if definition.ability == "Wall" then 10 else GHOST_HEIGHT
		ghostPart.Size = Vector3.new(footprint, height, footprint)
		ghostPart.Position = topCenter + Vector3.new(0, height / 2, 0)
	end

	tintGhost(placeable)
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
		destroyGhostVisuals()
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

function PlacementController.setBalance(amount: number)
	balance = amount
end

function PlacementController.select(brainrotId: string)
	if not selectionAllowed then
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
end

-- Shop selection (ghost) may still enable during legacy Countdown; planting is Active-only.
function PlacementController.setSelectionAllowed(allowed: boolean)
	selectionAllowed = allowed
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
	if not id then
		return
	end
	if not placementAllowed then
		UIEvents.firePlantFailed("Unable to plant — start the day first")
		return
	end

	local tile = GridController.resolveTileAt(position.X, position.Y)
	if not tile then
		return
	end

	local definition = Brainrots.get(id)
	if not definition then
		return
	end

	if tile:GetAttribute("Occupied") == true then
		UIEvents.firePlantFailed("Unable to plant — that spot is already taken")
		return
	end
	if not canAfford() then
		UIEvents.firePlantFailed("Unable to plant — not enough coins")
		return
	end

	UIEvents.markPendingSpend()
	placeRemote:FireServer(id, {
		row = tile:GetAttribute("Row"),
		column = tile:GetAttribute("Column"),
	})
	local placeKey = "PlaceBrainrot_" .. id
	if AudioConfig.SFX[placeKey] then
		AudioController.play(placeKey)
	else
		AudioController.play("PlaceBrainrot")
	end
	PlacementController.cancel()
end

function PlacementController.init()
	placeRemote = Remotes.getEvent("PlaceBrainrot")
	removeRemote = Remotes.getEvent("RemoveBrainrot")
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

	log:info("started")
end

return PlacementController
