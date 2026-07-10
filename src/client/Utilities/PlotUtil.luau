--!strict
--[[
	PlotUtil
	Client helpers for resolving the local player's plot model.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local PlotUtil = {}

local localPlayer = Players.LocalPlayer

function PlotUtil.getLocalPlotModel(): Model?
	local plotsFolder = workspace:FindFirstChild(Constants.WORKSPACE_FOLDERS.Plots)
	if not plotsFolder then
		return nil
	end
	for _, child in plotsFolder:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("OwnerUserId") == localPlayer.UserId then
			return child
		end
	end
	return nil
end

function PlotUtil.getTileTopCenter(plotModel: Model, row: number, column: number): Vector3?
	local grid = plotModel:FindFirstChild("Grid")
	if not grid then
		return nil
	end
	for _, child in grid:GetChildren() do
		if child:IsA("BasePart")
			and child:GetAttribute("Row") == row
			and child:GetAttribute("Column") == column
		then
			return child.Position + Vector3.new(0, child.Size.Y / 2 + 1, 0)
		end
	end
	return nil
end

function PlotUtil.getModelBodyCenter(model: Model): Vector3?
	local body = model:FindFirstChild("Body")
	if body and body:IsA("BasePart") then
		return body.Position + Vector3.new(0, body.Size.Y / 2, 0)
	end
	return nil
end

return PlotUtil
