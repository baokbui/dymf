--!strict
--[[
	PlotService
	Owns player battlefields (plots): builds a fixed pool at startup, assigns a
	unique plot per player, spawns the player onto it, and releases/cleans plots
	on leave for reuse. Plots are open for walking/spectating; gameplay actions
	(plant, shovel, coin collect) stay owner-only via server validation.

	Server-authoritative: clients never choose or move their own plot. Spawning
	is driven entirely server-side via per-player RespawnLocation + LoadCharacter;
	the client uses Roblox's default camera (no handshake required).

	Milestone 1.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local PlotConfig = require(Shared.Config.PlotConfig)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local Logger = require(Shared.Utilities.Logger)
local CollisionUtil = require(Shared.Utilities.CollisionUtil)

local Plot = require(script.Plot)
local PlotBuilder = require(script.PlotBuilder)
local EnemySpawnBuilder = require(script.EnemySpawnBuilder)
local ForestBuilder = require(script.ForestBuilder)
local HouseBuilder = require(script.HouseBuilder)
local GridService = require(script.Parent.GridService)

local PlotService = {}
PlotService.Name = "PlotService"

local log = Logger.new(PlotService.Name)

local plots: { Plot.Plot } = {}
local plotsByUserId: { [number]: Plot.Plot } = {}
local enemyLanesByRow: { [number]: Model } = {}
local characterAddedConnections: { [number]: RBXScriptConnection } = {}

local function applyCharacterMovement(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = PlayerConfig.WALK_SPEED
	end
	CollisionUtil.applyCharacter(character)
end

-- CharacterAutoLoads is off (so join doesn't spawn before a plot exists). After
-- Reset Character / death, Roblox will not auto-respawn — we must LoadCharacter.
local function hookRespawn(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
		or character:WaitForChild("Humanoid", 5)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid.Died:Once(function()
		local delaySec = math.max(0, Players.RespawnTime)
		task.delay(delaySec, function()
			if not player.Parent then
				return
			end
			if not plotsByUserId[player.UserId] then
				return
			end
			-- Still dead / no character — respawn on the plot SpawnLocation.
			if player.Character == character or player.Character == nil then
				player:LoadCharacter()
			end
		end)
	end)
end

local function onCharacterAdded(player: Player, character: Model)
	applyCharacterMovement(character)
	hookRespawn(player, character)
end

local function findFreePlot(): Plot.Plot?
	for _, plot in plots do
		if not plot:isOccupied() then
			return plot
		end
	end
	return nil
end

local function applyHouseOwnerLabel(plotModel: Model, ownerName: string?)
	local house = plotModel:FindFirstChild("House")
	if house and house:IsA("Model") then
		HouseBuilder.setOwnerLabel(house, ownerName)
	end
end

local function assignPlot(player: Player)
	if plotsByUserId[player.UserId] then
		return -- already assigned (guards join/loop race)
	end

	local plot = findFreePlot()
	if not plot then
		log:warn("no free plot available for", player.Name)
		return
	end

	plot:assign(player.UserId)
	plotsByUserId[player.UserId] = plot
	applyHouseOwnerLabel(plot.model, player.DisplayName)
	log:info(string.format("assigned Plot%d to %s", plot.index, player.Name))

	-- Direct every spawn/respawn to this plot's SpawnLocation, then (re)spawn
	-- the character there. This avoids teleport-on-spawn override races.
	player.RespawnLocation = plot.spawnLocation
	local existingConnection = characterAddedConnections[player.UserId]
	if existingConnection then
		existingConnection:Disconnect()
	end
	characterAddedConnections[player.UserId] = player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	player:LoadCharacter()
end

local function releasePlot(player: Player)
	local plot = plotsByUserId[player.UserId]
	if plot then
		applyHouseOwnerLabel(plot.model, nil)
		-- Clear service-owned runtimes before wiping folders.
		-- SaveService already snapshotted the lawn on PlayerRemoving (connected in init).
		require(script.Parent.BrainrotService).clearPlot(plot.model)
		require(script.Parent.EnemyService).clearPlot(plot.model)
		require(script.Parent.CoinService).clearPlot(plot.model)
		require(script.Parent.GraveService).clearPlot(plot.model)
		plot:release()
		GridService.resetPlot(plot.model)
		plotsByUserId[player.UserId] = nil
		log:info(string.format("released Plot%d from %s", plot.index, player.Name))
	end
	local connection = characterAddedConnections[player.UserId]
	if connection then
		connection:Disconnect()
		characterAddedConnections[player.UserId] = nil
	end
end

function PlotService.init()
	CollisionUtil.init()

	-- We spawn players explicitly (after a plot is assigned), so disable the
	-- default auto-spawn to prevent appearing before/away from the plot.
	Players.CharacterAutoLoads = false

	local plotsFolder = Workspace:FindFirstChild(Constants.WORKSPACE_FOLDERS.Plots)
	if not plotsFolder then
		plotsFolder = Instance.new("Folder")
		plotsFolder.Name = Constants.WORKSPACE_FOLDERS.Plots
		plotsFolder.Parent = Workspace
	end

	-- West column: player plots. East column: enemy-spawn lanes (one per row).
	local mapColumns = PlotConfig.MAP_COLUMNS
	local startX = -((mapColumns - 1) / 2) * PlotConfig.BASE_WIDTH
	local startZ = -((PlotConfig.LANE_ROWS - 1) / 2) * PlotConfig.BASE_DEPTH

	local enemyPathsFolder = Workspace:FindFirstChild(Constants.WORKSPACE_FOLDERS.EnemyPaths)
	if not enemyPathsFolder then
		enemyPathsFolder = Instance.new("Folder")
		enemyPathsFolder.Name = Constants.WORKSPACE_FOLDERS.EnemyPaths
		enemyPathsFolder.Parent = Workspace
	end

	for i = 1, PlotConfig.MAX_PLOTS do
		local row = i - 1
		local originPosition = Vector3.new(
			startX + PlotConfig.PLAYER_MAP_COLUMN * PlotConfig.BASE_WIDTH,
			0,
			startZ + row * PlotConfig.BASE_DEPTH
		)
		local model, base, spawnLocation = PlotBuilder.build(i, originPosition)
		model.Parent = plotsFolder
		plots[i] = Plot.new(i, model, base, spawnLocation)
	end

	for row = 1, PlotConfig.LANE_ROWS do
		local originPosition = Vector3.new(
			startX + PlotConfig.ENEMY_MAP_COLUMN * PlotConfig.BASE_WIDTH,
			0,
			startZ + (row - 1) * PlotConfig.BASE_DEPTH
		)
		local enemyLane = EnemySpawnBuilder.build(row, originPosition)
		enemyLane.Parent = enemyPathsFolder
		enemyLanesByRow[row] = enemyLane
	end

	local mapsFolder = Workspace:FindFirstChild(Constants.WORKSPACE_FOLDERS.Maps)
	if not mapsFolder then
		mapsFolder = Instance.new("Folder")
		mapsFolder.Name = Constants.WORKSPACE_FOLDERS.Maps
		mapsFolder.Parent = Workspace
	end
	local existingForest = mapsFolder:FindFirstChild("DarkForest")
	if existingForest then
		existingForest:Destroy()
	end
	local enemyCenterX = startX + PlotConfig.ENEMY_MAP_COLUMN * PlotConfig.BASE_WIDTH
	local forest = ForestBuilder.build(enemyCenterX, startZ)
	forest.Parent = mapsFolder

	log:info(string.format("built %d plots, %d enemy lanes, and dark forest", PlotConfig.MAX_PLOTS, PlotConfig.LANE_ROWS))
end

function PlotService.start()
	Players.PlayerAdded:Connect(assignPlot)
	Players.PlayerRemoving:Connect(releasePlot)

	-- Handle players who joined before this service started (e.g. Studio solo).
	for _, player in Players:GetPlayers() do
		assignPlot(player)
	end

	log:info("started")
end

-- Public API for other services (read-only access to plot ownership).
function PlotService.getPlot(player: Player): Plot.Plot?
	return plotsByUserId[player.UserId]
end

function PlotService.getPlotModel(player: Player): Model?
	local plot = plotsByUserId[player.UserId]
	return if plot then plot.model else nil
end

-- Enemy-spawn lane aligned with a player plot row (1-based row index).
function PlotService.getEnemyLane(rowIndex: number): Model?
	return enemyLanesByRow[rowIndex]
end

-- Enemy-spawn lane for a specific player plot (same row as the plot index).
function PlotService.getEnemyLaneForPlot(plot: Plot.Plot): Model?
	return enemyLanesByRow[plot.index]
end

return PlotService
