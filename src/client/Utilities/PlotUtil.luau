--!strict
--[[
	PlotUtil
	Client helpers for resolving the local player's plot model.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
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

function PlotUtil.isOnLocalPlot(instance: Instance): boolean
	local plot = PlotUtil.getLocalPlotModel()
	return plot ~= nil and instance:IsDescendantOf(plot)
end

function PlotUtil.countOnLocalPlot(brainrotId: string): number
	local plot = PlotUtil.getLocalPlotModel()
	if not plot then
		return 0
	end
	local n = 0
	for _, inst in CollectionService:GetTagged(Constants.TAGS.Brainrot) do
		if inst:IsA("Model")
			and inst:IsDescendantOf(plot)
			and inst:GetAttribute("BrainrotId") == brainrotId
		then
			n += 1
		end
	end
	return n
end

function PlotUtil.getLocalBrainrotAt(row: number, column: number): Model?
	for _, inst in CollectionService:GetTagged(Constants.TAGS.Brainrot) do
		if inst:IsA("Model")
			and inst:GetAttribute("OwnerUserId") == localPlayer.UserId
			and inst:GetAttribute("Row") == row
			and inst:GetAttribute("Column") == column
		then
			return inst
		end
	end
	return nil
end

function PlotUtil.getOwningPlotModel(instance: Instance): Model?
	local plotsFolder = workspace:FindFirstChild(Constants.WORKSPACE_FOLDERS.Plots)
	if not plotsFolder then
		return nil
	end
	local current: Instance? = instance
	while current and current ~= plotsFolder do
		if current:IsA("Model") and current.Parent == plotsFolder then
			return current
		end
		current = current.Parent
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

-- Best-effort "torso" part for VFX anchoring. Procedural placeholders always
-- have a direct "Body" child, but authored Toolbox rigs (monsters keep their
-- original animation rig — see `ModelUtil.PrepareOptions.preserveAnimationRig`
-- / `skipBodyAlias`) never get one, so fall back the same way the server's
-- `MonsterFeedback.resolveBody` does: recursive "Body", PrimaryPart, then
-- HumanoidRootPart.
local function resolveAnchorPart(model: Model): BasePart?
	local body = model:FindFirstChild("Body", true)
	if body and body:IsA("BasePart") then
		return body
	end
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	local hrp = model:FindFirstChild("HumanoidRootPart", true)
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

function PlotUtil.getModelBodyCenter(model: Model): Vector3?
	local body = resolveAnchorPart(model)
	if body then
		return body.Position + Vector3.new(0, body.Size.Y / 2, 0)
	end
	return nil
end

return PlotUtil
