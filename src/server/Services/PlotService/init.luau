--!strict
--[[
	PlotService
	Owns player battlefields (plots): builds a fixed pool at startup, assigns a
	unique plot per player, spawns the player onto it, isolates plots with
	invisible barriers, and releases/cleans plots on leave for reuse.

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
local Logger = require(Shared.Utilities.Logger)

local Plot = require(script.Plot)
local PlotBuilder = require(script.PlotBuilder)
local EnemySpawnBuilder = require(script.EnemySpawnBuilder)
local GridService = require(script.Parent.GridService)

local PlotService = {}
PlotService.Name = "PlotService"

local log = Logger.new(PlotService.Name)

local plots: { Plot.Plot } = {}
local plotsByUserId: { [number]: Plot.Plot } = {}
local enemyLanesByRow: { [number]: Model } = {}

local function findFreePlot(): Plot.Plot?
	for _, plot in plots do
		if not plot:isOccupied() then
			return plot
		end
	end
	return nil
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
	log:info(string.format("assigned Plot%d to %s", plot.index, player.Name))

	-- Direct every spawn/respawn to this plot's SpawnLocation, then (re)spawn
	-- the character there. This avoids teleport-on-spawn override races.
	player.RespawnLocation = plot.spawnLocation
	player:LoadCharacter()
end

local function releasePlot(player: Player)
	local plot = plotsByUserId[player.UserId]
	if plot then
		plot:release()
		GridService.resetPlot(plot.model)
		require(script.Parent.EnemyService).clearPlot(plot.model)
		plotsByUserId[player.UserId] = nil
		log:info(string.format("released Plot%d from %s", plot.index, player.Name))
	end
end

function PlotService.init()
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

	log:info(string.format("built %d plots and %d enemy lanes", PlotConfig.MAX_PLOTS, PlotConfig.LANE_ROWS))
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
