--!strict
--[[
	LifeVortex
	Red and white lines fly into a Vampire / Duke's right hand while
	LifeVortex is set. Off hides them.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local VfxLoad = require(Shared.Utilities.VfxLoad)

local VfxUtil = require(script.Parent.Parent.Parent.Utilities.VfxUtil)

local LifeVortex = {}

local function sync(model: Model)
	if model:GetAttribute("LifeVortex") == true and VfxLoad.quality() ~= "Minimal" then
		VfxUtil.startLifeVortex(model)
	else
		VfxUtil.stopLifeVortex(model)
	end
end

function LifeVortex.start()
	local tag = Constants.TAGS.Monster
	local function watch(instance: Instance)
		if not instance:IsA("Model") then
			return
		end
		local model = instance :: Model
		model:GetAttributeChangedSignal("LifeVortex"):Connect(function()
			sync(model)
		end)
		model.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				VfxUtil.stopLifeVortex(model)
			end
		end)
		sync(model)
	end

	for _, instance in CollectionService:GetTagged(tag) do
		watch(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(watch)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		if instance:IsA("Model") then
			VfxUtil.stopLifeVortex(instance)
		end
	end)
	VfxLoad.onChanged(function()
		for _, instance in CollectionService:GetTagged(tag) do
			if instance:IsA("Model") then
				sync(instance)
			end
		end
	end)
end

return LifeVortex
