--!strict
--[[
	StoreController
	Hides Talk prompts on other players' (and unowned) stalls. Opening and
	buys are still validated on the server — this is display-only.
]]

local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local StoreConfig = require(Shared.Config.StoreConfig)
local Logger = require(Shared.Utilities.Logger)

local PlotUtil = require(script.Parent.Parent.Utilities.PlotUtil)

local StoreController = {}
StoreController.Name = "StoreController"

local log = Logger.new(StoreController.Name)

local function applyPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	prompt.Enabled = PlotUtil.isOnLocalPlot(prompt)
	if prompt.Enabled then
		prompt.MaxActivationDistance = StoreConfig.PROMPT_DISTANCE
	else
		prompt.MaxActivationDistance = 0
	end
end

local function applyAllPrompts()
	for _, prompt in CollectionService:GetTagged(Constants.TAGS.StorePrompt) do
		applyPrompt(prompt)
	end
end

local function bindPlot(plotModel: Model)
	plotModel:GetAttributeChangedSignal("OwnerUserId"):Connect(applyAllPrompts)
end

function StoreController.init()
end

function StoreController.start()
	for _, prompt in CollectionService:GetTagged(Constants.TAGS.StorePrompt) do
		applyPrompt(prompt)
	end
	CollectionService:GetInstanceAddedSignal(Constants.TAGS.StorePrompt):Connect(applyPrompt)

	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		if CollectionService:HasTag(prompt, Constants.TAGS.StorePrompt) then
			applyPrompt(prompt)
		end
	end)

	local plotsFolder = Workspace:WaitForChild(Constants.WORKSPACE_FOLDERS.Plots, 10)
	if plotsFolder then
		for _, child in plotsFolder:GetChildren() do
			if child:IsA("Model") then
				bindPlot(child)
			end
		end
		plotsFolder.ChildAdded:Connect(function(child)
			if child:IsA("Model") then
				bindPlot(child)
				applyAllPrompts()
			end
		end)
	end

	applyAllPrompts()
	log:info("started")
end

return StoreController
