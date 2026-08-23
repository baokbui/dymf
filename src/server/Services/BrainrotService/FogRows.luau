--!strict
--[[
	FogRows
	Tracks lawn rows whose NightFog plant-block is lifted by a living
	ClearFogRow Brainrot. Owner client gets FogRowsChanged for visuals.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PlotService = require(script.Parent.Parent.PlotService)

local FogRows = {}

local counts: { [Model]: { [number]: number } } = {}

local function rowList(plotModel: Model): { number }
	local plotCounts = counts[plotModel]
	if not plotCounts then
		return {}
	end
	local rows: { number } = {}
	for row, n in plotCounts do
		if n > 0 then
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
	Remotes.getEvent("FogRowsChanged"):FireClient(owner, { rows = rowList(plotModel) })
end

function FogRows.isRowCleared(plotModel: Model, row: number): boolean
	local plotCounts = counts[plotModel]
	return plotCounts ~= nil and (plotCounts[row] or 0) > 0
end

function FogRows.add(plotModel: Model, row: number)
	local plotCounts = counts[plotModel]
	if not plotCounts then
		plotCounts = {}
		counts[plotModel] = plotCounts
	end
	plotCounts[row] = (plotCounts[row] or 0) + 1
	if plotCounts[row] == 1 then
		broadcast(plotModel)
	end
end

function FogRows.remove(plotModel: Model, row: number)
	local plotCounts = counts[plotModel]
	if not plotCounts then
		return
	end
	local nextCount = (plotCounts[row] or 0) - 1
	if nextCount <= 0 then
		plotCounts[row] = nil
		broadcast(plotModel)
	else
		plotCounts[row] = nextCount
	end
end

function FogRows.clearPlot(plotModel: Model)
	if counts[plotModel] then
		counts[plotModel] = nil
		broadcast(plotModel)
	end
end

return FogRows
