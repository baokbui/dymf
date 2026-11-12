--!strict
-- Local shard particle density. Pickup rules and rewards stay on the server.
local CollectionService = game:GetService("CollectionService")
local Shared = game.ReplicatedStorage.Shared
local Quality = require(Shared.Utilities.VfxLoad)
local Tag = require(Shared.Constants).TAGS.MonsterShard
local Controller = { Name = "ShardController" }
local watched: { [Instance]: RBXScriptConnection } = {}

local function tune(item: Instance)
	if not item:IsA("ParticleEmitter") or item.Name ~= "ShardSparkles" then return end
	local full = item:GetAttribute("FullRate")
	if type(full) ~= "number" then return end
	local quality = Quality.quality()
	item.Rate = if quality == "Minimal" then 0 elseif quality == "Reduced" then full * 0.4 else full
	if quality == "Minimal" then item:Clear() end
end

local function refresh(model: Instance)
	for _, item in model:GetDescendants() do tune(item) end
end

local function watch(model: Instance)
	if watched[model] then return end
	refresh(model)
	watched[model] = model.DescendantAdded:Connect(tune)
end

local function remove(model: Instance)
	local connection = watched[model]
	if connection then connection:Disconnect(); watched[model] = nil end
end

function Controller.start()
	CollectionService:GetInstanceAddedSignal(Tag):Connect(watch)
	CollectionService:GetInstanceRemovedSignal(Tag):Connect(remove)
	for _, model in CollectionService:GetTagged(Tag) do watch(model) end
	Quality.onChanged(function() for model in watched do refresh(model) end end)
end

return Controller
