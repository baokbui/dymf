--!strict
-- Event-driven, viewer-local visibility for other players' farm residents.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local FarmController = { Name = "FarmController" }
local hideOthers = false
local started = false
type Original = { transparency: number?, shadow: boolean?, enabled: boolean?, decal: number? }
type Resident = { plot: Model, originals: { [Instance]: Original }, connections: { RBXScriptConnection } }
local residents: { [Model]: Resident } = {}
local plots: { [Model]: { RBXScriptConnection } } = {}

local function hidden(state: Resident): boolean
	return hideOthers and state.plot:GetAttribute("OwnerUserId") ~= Players.LocalPlayer.UserId
end

local function apply(instance: Instance, original: Original, hide: boolean)
	if instance:IsA("BasePart") then
		instance.LocalTransparencyModifier = if hide then 1 else original.transparency :: number
		instance.CastShadow = if hide then false else original.shadow :: boolean
	elseif instance:IsA("Decal") then
		instance.Transparency = if hide then 1 else original.decal :: number
	elseif original.enabled ~= nil then
		(instance :: any).Enabled = if hide then false else original.enabled
	end
end

local function capture(state: Resident, instance: Instance)
	local original: Original = {}
	if instance:IsA("BasePart") then
		original.transparency, original.shadow = instance.LocalTransparencyModifier, instance.CastShadow
	elseif instance:IsA("Decal") then
		original.decal = instance.Transparency
	elseif instance:IsA("BillboardGui") or instance:IsA("SurfaceGui") or instance:IsA("ParticleEmitter")
		or instance:IsA("Trail") or instance:IsA("Beam") or instance:IsA("Light") or instance:IsA("Highlight") then
		original.enabled = (instance :: any).Enabled
	else return end
	state.originals[instance] = original
	apply(instance, original, hidden(state))
end

local function remove(model: Model)
	local state = residents[model]
	if not state then return end
	for _, connection in state.connections do connection:Disconnect() end
	for instance, original in state.originals do apply(instance, original, false) end
	residents[model] = nil
end

local function watchResident(instance: Instance, plot: Model)
	if not instance:IsA("Model") or residents[instance] then return end
	local folder = instance.Parent
	if not folder or folder.Name ~= "Residents" or not folder.Parent or folder.Parent.Name ~= "House" then return end
	local state: Resident = { plot = plot, originals = {}, connections = {} }
	residents[instance] = state
	for _, child in instance:GetDescendants() do capture(state, child) end
	table.insert(state.connections, instance.DescendantAdded:Connect(function(child) capture(state, child) end))
	table.insert(state.connections, instance.DescendantRemoving:Connect(function(child)
		local original = state.originals[child]
		if original then apply(child, original, false); state.originals[child] = nil end
	end))
	table.insert(state.connections, instance.AncestryChanged:Connect(function()
		if not instance:IsDescendantOf(plot) then remove(instance) end
	end))
end

local function removePlot(plot: Model)
	for model, state in residents do if state.plot == plot then remove(model) end end
	for _, connection in plots[plot] or {} do connection:Disconnect() end
	plots[plot] = nil
end

local function watchPlot(instance: Instance)
	if not instance:IsA("Model") or plots[instance] then return end
	local plot = instance
	local connections = {}
	plots[plot] = connections
	for _, child in plot:GetDescendants() do watchResident(child, plot) end
	table.insert(connections, plot.DescendantAdded:Connect(function(child) watchResident(child, plot) end))
	table.insert(connections, plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		for _, state in residents do
			if state.plot == plot then for child, original in state.originals do apply(child, original, hidden(state)) end end
		end
	end))
end

function FarmController.hidesOtherFarms(): boolean
	return hideOthers
end

function FarmController.setHideOtherFarms(enabled: boolean)
	hideOthers = enabled
	for _, state in residents do
		for child, original in state.originals do apply(child, original, hidden(state)) end
	end
end

function FarmController.start()
	if started then return end
	started = true
	local folder = Workspace:WaitForChild("Plots")
	for _, plot in folder:GetChildren() do watchPlot(plot) end
	folder.ChildAdded:Connect(watchPlot)
	folder.ChildRemoved:Connect(function(plot) if plot:IsA("Model") then removePlot(plot) end end)
end

return FarmController
