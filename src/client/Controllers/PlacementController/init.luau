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
local GridConfig = require(Shared.Config.GridConfig)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Logger = require(Shared.Utilities.Logger)
local ModelUtil = require(Shared.Utilities.ModelUtil)
local PlantCost = require(Shared.Utilities.PlantCost)
local WeatherUtil = require(Shared.Utilities.WeatherUtil)

local UIEvents = require(script.Parent.Parent.UIEvents)
local GridController = require(script.Parent.GridController)
local InputController = require(script.Parent.InputController)
local AudioController = require(script.Parent.AudioController)
local PlotUtil = require(script.Parent.Parent.Utilities.PlotUtil)

local PlacementController = {}
PlacementController.Name = "PlacementController"

local log = Logger.new(PlacementController.Name)

local localPlayer = Players.LocalPlayer

local GHOST_HEIGHT = 6
local GHOST_TRANSPARENCY = 0.45
local VALID_COLOR = Color3.fromRGB(120, 220, 120)
local BLOCKED_COLOR = Color3.fromRGB(220, 110, 110)

-- Only parts tagged at ghost clone time (visual meshes, not rig roots).
local function isGhostSilhouettePart(part: BasePart): boolean
	return part:GetAttribute("GhostSilhouette") == true
end

local selectedId: string? = nil
local balance = 0
-- brainrotId → readyAt (Workspace:GetServerTimeNow); mirrored from server.
local plantReadyAt: { [string]: number } = {}
local placementAllowed = false
local selectionAllowed = false
local currentWeather: string? = nil
local fogClearedRows: { [number]: boolean } = {}
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

local function isFogClearedRow(row: number): boolean
	return fogClearedRows[row] == true
end

local function fogBlockedFor(definition: Types.BrainrotDefinition, column: number, row: number): boolean
	return WeatherUtil.fogBlocksPlanting(
		column,
		currentWeather,
		isFogClearedRow(row),
		definition.plantsOnFog,
		definition.triggersOnPlace,
		definition.plantOnGrave
	)
end

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
			if descendant:IsA("BasePart") and isGhostSilhouettePart(descendant) then
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
			if descendant:IsA("BasePart") and isGhostSilhouettePart(descendant) then
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
		local animated = definition.animated == true
		local model = ModelUtil.cloneBrainrotTemplate(template, {
			targetFootprint = footprintFor(definition),
			ghost = true,
			ghostTransparency = GHOST_TRANSPARENCY,
			tintColor = VALID_COLOR,
			orientationDegrees = definition.modelOrientationDegrees,
			preserveAnimationRig = animated,
			skipBodyAlias = animated,
			anchorAllParts = definition.anchorAllParts == true,
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
	return definition ~= nil and balance >= PlantCost.coins(definition.cost, PlotUtil.getLocalPlotModel())
end

local function countLivingOnPlot(brainrotId: string): number
	return PlotUtil.countOnLocalPlot(brainrotId)
end

local function plotCapReached(definition: Types.BrainrotDefinition): boolean
	local cap = definition.maxOnPlot
	if type(cap) ~= "number" or cap <= 0 then
		return false
	end
	return countLivingOnPlot(definition.id) >= cap
end

local function plotCapReason(definition: Types.BrainrotDefinition): string
	local cap = definition.maxOnPlot
	if type(cap) ~= "number" then
		return "You've placed as many as you can."
	end
	return string.format("You can only place %d %s.", cap, definition.name)
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
	local isGrave = tile:GetAttribute("Grave") == true
	local column = tile:GetAttribute("Column")
	local row = tile:GetAttribute("Row")
	local fogBlocked = type(column) == "number"
		and type(row) == "number"
		and fogBlockedFor(definition, column, row)
	local tileTaken = if definition.plantOnGrave == true then not isGrave else occupied
	local placeable = placementAllowed
		and not tileTaken
		and not fogBlocked
		and canAfford()
		and not plotCapReached(definition)

	if ghostModel then
		ModelUtil.pivotToTileTop(ghostModel, topCenter, definition.modelOrientationDegrees, nil, definition.modelYOffset)
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
	-- Never steal clicks from Shop cancel / other HUD.
	cursor.Active = false
	cursor.Parent = playerGui:WaitForChild("MainUI")

	local handle = Instance.new("Frame")
	handle.Name = "Handle"
	handle.AnchorPoint = Vector2.new(0.5, 0)
	handle.Position = UDim2.new(0.5, 0, 0, 2)
	handle.Size = UDim2.fromOffset(6, 14)
	handle.BackgroundColor3 = Color3.fromRGB(120, 80, 40)
	handle.BorderSizePixel = 0
	handle.Active = false
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
	blade.Active = false
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

local function tryInspectAt(position: Vector2)
	local hit = GridController.raycastAt(position.X, position.Y)
	if hit then
		local monster = PlotUtil.getLocalMonsterFromInstance(hit.Instance)
		if monster then
			UIEvents.fireFieldInspect(monster)
			AudioController.play("UiClick")
			return
		end
	end
	local tile = GridController.resolveTileAt(position.X, position.Y)
	if not tile then
		UIEvents.fireFieldInspect(nil)
		return
	end
	if tile:GetAttribute("Occupied") ~= true then
		UIEvents.fireFieldInspect(nil)
		return
	end
	local row = tile:GetAttribute("Row")
	local column = tile:GetAttribute("Column")
	if type(row) ~= "number" or type(column) ~= "number" then
		return
	end
	local model = PlotUtil.getLocalBrainrotAt(row, column)
	if model then
		UIEvents.fireFieldInspect(model)
		AudioController.play("UiClick")
	else
		UIEvents.fireFieldInspect(nil)
	end
end

function PlacementController.setBalance(amount: number)
	balance = amount
end

function PlacementController.setPlantCooldowns(readyAtById: { [string]: number }?)
	plantReadyAt = {}
	if type(readyAtById) == "table" then
		for id, readyAt in readyAtById do
			if type(id) == "string" and type(readyAt) == "number" then
				plantReadyAt[id] = readyAt
			end
		end
	end
end

function PlacementController.isOnCooldown(brainrotId: string): boolean
	local readyAt = plantReadyAt[brainrotId]
	return type(readyAt) == "number" and readyAt > workspace:GetServerTimeNow()
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
	UIEvents.fireFieldInspect(nil)
	setSelected(brainrotId)
	AudioController.play("UiSelect")
end

function PlacementController.setPlacementAllowed(allowed: boolean)
	placementAllowed = allowed
end

function PlacementController.setWeather(weather: string?)
	currentWeather = weather
end

function PlacementController.setFogClearedRows(rows: { number })
	fogClearedRows = {}
	for _, row in rows do
		fogClearedRows[row] = true
	end
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
		UIEvents.fireFieldInspect(nil)
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
		tryInspectAt(position)
		return
	end
	if not placementAllowed then
		UIEvents.firePlantFailed("Start the day first.")
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

	local isGrave = tile:GetAttribute("Grave") == true
	local occupied = tile:GetAttribute("Occupied") == true
	if definition.plantOnGrave == true then
		if not isGrave then
			UIEvents.firePlantFailed("Plant this one on a grave.")
			return
		end
	elseif occupied then
		UIEvents.firePlantFailed("That spot is taken.")
		return
	end
	local column = tile:GetAttribute("Column")
	local row = tile:GetAttribute("Row")
	if type(column) == "number"
		and type(row) == "number"
		and fogBlockedFor(definition, column, row)
	then
		UIEvents.firePlantFailed("That tile is covered in fog.")
		return
	end
	if not canAfford() then
		UIEvents.firePlantFailed("Not enough coins.")
		return
	end
	if PlacementController.isOnCooldown(id) then
		UIEvents.firePlantFailed("Still recharging.")
		return
	end
	if plotCapReached(definition) then
		UIEvents.firePlantFailed(plotCapReason(definition))
		return
	end

	UIEvents.markPendingSpend()
	placeRemote:FireServer(id, {
		row = tile:GetAttribute("Row"),
		column = column,
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

	Remotes.getEvent("FogRowsChanged").OnClientEvent:Connect(function(payload: unknown)
		if type(payload) ~= "table" then
			return
		end
		local data = payload :: { [string]: any }
		if data.plotCleared == true then
			local list: { number } = {}
			for row = 1, GridConfig.ROWS do
				table.insert(list, row)
			end
			PlacementController.setFogClearedRows(list)
			return
		end
		local rows = data.rows
		if type(rows) == "table" then
			local list: { number } = {}
			for _, row in rows do
				if type(row) == "number" then
					table.insert(list, row)
				end
			end
			PlacementController.setFogClearedRows(list)
		end
	end)

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
