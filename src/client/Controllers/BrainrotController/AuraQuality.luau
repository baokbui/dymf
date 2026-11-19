--!strict
-- Per-viewer aura budget. Server-authored layers remain cosmetic, never combat state.
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Constants = require(Shared.Constants)
local Config = require(Shared.Config.EvolutionVfxConfig)
local VfxLoad = require(Shared.Utilities.VfxLoad)
local PlotUtil = require(script.Parent.Parent.Parent.Utilities.PlotUtil)
local AuraQuality = {}
type State = { emitters: { [ParticleEmitter]: boolean }, connections: { RBXScriptConnection }, band: string?, pendingBurst: number? }
local watched: { [Model]: State } = {}
local started, queued = false, false
local refresh: () -> ()
local function queueRefresh()
	if queued then return end
	queued = true
	task.defer(function() queued = false; refresh() end)
end

local function apply(model: Model, state: State, band: string)
	local paused = model:GetAttribute("DayPaused") == true
	for emitter in state.emitters do
		if not emitter:IsDescendantOf(model) then state.emitters[emitter] = nil; continue end
		local rate = if band == "Off" then 0 else emitter:GetAttribute("Aura" .. band .. "Rate")
		if type(rate) ~= "number" then rate = 0 end
		if emitter.Rate ~= rate then emitter.Rate = rate end
		if band == "Off" and state.band ~= "Off" then emitter:Clear() end
		local timeScale = if paused then 0 else 1
		if emitter.TimeScale ~= timeScale then emitter.TimeScale = timeScale end
	end
	state.band = band
end

local settings: any = nil
local function savedGraphics(): number
	if settings then return settings.SavedQualityLevel.Value end
	return 0
end

refresh = function()
	local band = Config.band(VfxLoad.quality(), savedGraphics())
	local camera = workspace.CurrentCamera
	local candidates, selected, bursts = {}, {}, {}
	for model, state in watched do
		if not model.Parent then continue end
		if next(state.emitters) == nil then continue end
		if band == "Off" or not camera or model:GetAttribute("Stoned") == true then continue end
		local localPlot = PlotUtil.isOnLocalPlot(model)
		if not VfxLoad.showsOtherPlots() and not localPlot then continue end
		local distance = (model:GetPivot().Position - camera.CFrame.Position).Magnitude
		if distance <= Config.MAX_DISTANCE then table.insert(candidates, { model = model, distance = distance, localPlot = localPlot }) end
	end
	table.sort(candidates, function(a, b) return a.distance < b.distance end)
	local detailed, burstCount = 0, 0
	for index, entry in candidates do
		if index > Config.MAX_VISIBLE[band] then break end
		local detail = "Low"
		if entry.localPlot and entry.distance <= Config.DETAIL_DISTANCE and detailed < Config.MAX_DETAILED[band] then
			detail = band
			detailed += 1
		end
		selected[entry.model] = detail
		local state = watched[entry.model]
		if state.pendingBurst and entry.model:GetAttribute("DayPaused") ~= true and burstCount < Config.MAX_BURSTS[band] then
			bursts[entry.model] = true
			burstCount += 1
		end
	end
	for model, state in watched do
		if not model.Parent then continue end
		local detail = selected[model] or "Off"
		apply(model, state, detail)
		local aura = model:FindFirstChild("AuraVfx")
		if state.pendingBurst and aura and aura:GetAttribute("BurstId") == state.pendingBurst then
			if bursts[model] and detail ~= "Off" then
				for emitter in state.emitters do
					local counts = Config.BURST[emitter.Name]
					if counts and emitter:IsDescendantOf(aura) and emitter.Enabled then emitter:Emit(math.floor((counts[detail] or 0) * (emitter:GetAttribute("AuraBurstShare") or 1))) end
				end
			end
			state.pendingBurst = nil -- Never replay after leaving the budget/turning effects back on.
		end
	end
end

local function watchModel(instance: Instance)
	if not instance:IsA("Model") or watched[instance] then return end
	local state: State = { emitters = {}, connections = {} }
	watched[instance] = state
	local function inspect(item: Instance)
		if not item:IsA("ParticleEmitter") or not item:FindFirstAncestor("AuraVfx") then return end
		state.emitters[item] = true
		item.Rate = 0; item:Clear()
		queueRefresh()
	end
	for _, item in instance:GetDescendants() do inspect(item) end
	table.insert(state.connections, instance.DescendantAdded:Connect(inspect))
	table.insert(state.connections, instance:GetAttributeChangedSignal("DayPaused"):Connect(queueRefresh))
	table.insert(state.connections, instance:GetAttributeChangedSignal("Stoned"):Connect(queueRefresh))
	table.insert(state.connections, instance:GetAttributeChangedSignal("EvolutionBurst"):Connect(function()
		local serial = instance:GetAttribute("EvolutionBurst")
		if type(serial) == "number" then state.pendingBurst = serial; queueRefresh() end
	end))
	table.insert(state.connections, instance.Destroying:Connect(function()
		for _, connection in state.connections do connection:Disconnect() end
		watched[instance] = nil
	end))
	queueRefresh()
end

function AuraQuality.start()
	if started then return end
	started = true
	pcall(function() settings = UserSettings():GetService("UserGameSettings") end)
	if settings then settings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(queueRefresh) end
	local tag = Constants.TAGS.Brainrot
	for _, model in CollectionService:GetTagged(tag) do watchModel(model) end
	CollectionService:GetInstanceAddedSignal(tag):Connect(watchModel)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		local state = watched[instance :: Model]
		if not state then return end
		apply(instance :: Model, state, "Off")
		for _, connection in state.connections do connection:Disconnect() end
		watched[instance :: Model] = nil
	end)
	VfxLoad.onChanged(queueRefresh)
	VfxLoad.onOtherPlotsChanged(queueRefresh)
	task.spawn(function()
		while true do task.wait(Config.UPDATE_INTERVAL); refresh() end
	end)
end

return AuraQuality
