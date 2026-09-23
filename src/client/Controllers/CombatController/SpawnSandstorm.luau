--!strict
--[[
	SpawnSandstorm
	The Pharaoh-steal sand tornado, stood upright and sized to hide his whole
	body. High is dense enough that he cannot be seen inside it. Low thins it
	so he is only partly visible. Off spawns nothing. Fades when he takes his
	first step.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local VfxLoad = require(Shared.Utilities.VfxLoad)

local VfxUtil = require(script.Parent.Parent.Parent.Utilities.VfxUtil)

local SpawnSandstorm = {}

local stops: { [Model]: () -> () } = {}

local function groundOf(model: Model): Vector3?
	local x = model:GetAttribute("SandstormX")
	local y = model:GetAttribute("SandstormY")
	local z = model:GetAttribute("SandstormZ")
	if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
		return nil
	end
	return Vector3.new(x, y, z)
end

local function stop(model: Model)
	local cancel = stops[model]
	if not cancel then
		return
	end
	stops[model] = nil
	cancel()
end

local function sync(model: Model)
	if not model:IsA("Model") or model:GetAttribute("SpawnSandstorm") ~= true then
		stop(model)
		return
	end
	if stops[model] then
		return
	end
	if VfxLoad.quality() == "Minimal" then
		return
	end
	local ground = groundOf(model)
	if not ground then
		return
	end
	local _, size = model:GetBoundingBox()
	stops[model] = VfxUtil.playSpawnSandstorm(ground, math.max(size.X, size.Z), size.Y)
end

function SpawnSandstorm.start()
	local tag = Constants.TAGS.Monster
	local function watch(instance: Instance)
		if not instance:IsA("Model") then
			return
		end
		local model = instance :: Model
		local function onSandstormChanged()
			sync(model)
		end
		model:GetAttributeChangedSignal("SpawnSandstorm"):Connect(onSandstormChanged)
		model:GetAttributeChangedSignal("SandstormY"):Connect(onSandstormChanged)
		model.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				stop(model)
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
			stop(instance)
		end
	end)
	VfxLoad.onChanged(function()
		if VfxLoad.quality() == "Minimal" then
			for _, instance in CollectionService:GetTagged(tag) do
				if instance:IsA("Model") then
					stop(instance)
				end
			end
			return
		end
		local folder = workspace:FindFirstChild("ClientVfx")
		if folder then
			for _, child in folder:GetChildren() do
				if child.Name == "SpawnSandstorm" then
					VfxUtil.refreshSpawnSandstorm(child)
				end
			end
		end
		for _, instance in CollectionService:GetTagged(tag) do
			if instance:IsA("Model") then
				sync(instance)
			end
		end
	end)
end

return SpawnSandstorm
