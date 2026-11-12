--!strict
local BattleClock = require(game:GetService("ReplicatedStorage").Shared.Utilities.BattleClock)
--[[
	FogRows
	Tracks lawn rows whose NightFog plant-block is lifted. Giraffa applies a
	timed clear (not tied to the plant staying alive). Owner client gets
	FogRowsChanged for visuals.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GridConfig = require(ReplicatedStorage.Shared.Config.GridConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PlotService = require(script.Parent.Parent.PlotService)

local FogRows = {}

local active: { [Model]: { [number]: boolean } } = {}
local generation: { [Model]: { [number]: number } } = {}

local plotWideOn: { [Model]: boolean } = {}
local plotWideGen: { [Model]: number } = {}

local function rowList(plotModel: Model): { number }
	if plotWideOn[plotModel] == true then
		local rows: { number } = {}
		for row = 1, GridConfig.ROWS do
			table.insert(rows, row)
		end
		return rows
	end
	local plotActive = active[plotModel]
	if not plotActive then
		return {}
	end
	local rows: { number } = {}
	for row, isOn in plotActive do
		if isOn then
			table.insert(rows, row)
		end
	end
	table.sort(rows)
	return rows
end

local function ownerOf(plotModel: Model): Player?
	for _, player in Players:GetPlayers() do
		local assigned = PlotService.getPlot(player)
		if assigned and assigned.model == plotModel then
			return player
		end
	end
	return nil
end

local function broadcast(plotModel: Model)
	local owner = ownerOf(plotModel)
	if not owner then
		return
	end
	Remotes.getEvent("FogRowsChanged"):FireClient(owner, {
		rows = rowList(plotModel),
		plotCleared = plotWideOn[plotModel] == true,
	})
end

function FogRows.isRowCleared(plotModel: Model, row: number): boolean
	if plotWideOn[plotModel] == true then
		return true
	end
	local plotActive = active[plotModel]
	return plotActive ~= nil and plotActive[row] == true
end

-- Lift fog on `row` for `duration` seconds. A later cast on the same row
-- restarts the timer.
function FogRows.applyTimed(plotModel: Model, row: number, duration: number)
	local seconds = math.max(0, duration)
	local plotGen = generation[plotModel]
	if not plotGen then
		plotGen = {}
		generation[plotModel] = plotGen
	end
	plotGen[row] = (plotGen[row] or 0) + 1
	local token = plotGen[row]

	local plotActive = active[plotModel]
	if not plotActive then
		plotActive = {}
		active[plotModel] = plotActive
	end
	local already = plotActive[row] == true
	plotActive[row] = true
	if not already then
		broadcast(plotModel)
	end

	if seconds <= 0 then
		return
	end

	BattleClock.delay(plotModel, seconds, function()
		if not plotModel.Parent then
			return
		end
		local gens = generation[plotModel]
		if not gens or gens[row] ~= token then
			return
		end
		local act = active[plotModel]
		if act then
			act[row] = nil
		end
		broadcast(plotModel)
	end)
end

-- Lift Night Fog on every lawn row for `duration` seconds (Giraffa gust).
function FogRows.applyPlotTimed(plotModel: Model, duration: number)
	local seconds = math.max(0.05, duration)
	plotWideGen[plotModel] = (plotWideGen[plotModel] or 0) + 1
	local token = plotWideGen[plotModel]
	plotWideOn[plotModel] = true
	broadcast(plotModel)

	BattleClock.delay(plotModel, seconds, function()
		if not plotModel.Parent then
			return
		end
		if plotWideGen[plotModel] ~= token then
			return
		end
		plotWideOn[plotModel] = nil
		broadcast(plotModel)
	end)
end

function FogRows.clearPlot(plotModel: Model)
	plotWideOn[plotModel] = nil
	plotWideGen[plotModel] = nil
	if active[plotModel] or generation[plotModel] then
		active[plotModel] = nil
		generation[plotModel] = nil
	end
	broadcast(plotModel)
end

return FogRows
