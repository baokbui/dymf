--!strict
--[[
	OtherPlotVfx
	Local-only hide for Brainrot auras (AuraQuality) and Brainrot projectiles
	on plots this player does not own. Monster arrows stay visible.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local VfxLoad = require(Shared.Utilities.VfxLoad)

local PlotUtil = require(script.Parent.Parent.Parent.Utilities.PlotUtil)
local VfxUtil = require(script.Parent.Parent.Parent.Utilities.VfxUtil)

local OtherPlotVfx = {}

local BRAINROT_NAMES: { [string]: boolean } = {
	SwordWaveProjectile = true,
	SwordWavePillar = true,
	AbyssalTorrent = true,
	BombardinoBomb = true,
	BombardinoFlight = true,
}

local BRAINROT_KINDS: { [string]: boolean } = {
	Shuriken = true,
	Bat = true,
	SwordWave = true,
	Knife = true,
	Bubble = true,
	Pineapple = true,
}

local watched: { [Instance]: boolean } = {}

local function isBrainrotVfx(instance: Instance): boolean
	if BRAINROT_NAMES[instance.Name] then
		return true
	end
	local kind = instance:GetAttribute("ProjectileKind")
	return type(kind) == "string" and BRAINROT_KINDS[kind] == true
end

local function conceal(root: Instance, hidden: boolean)
	local function apply(inst: Instance)
		if inst:IsA("BasePart") then
			inst.LocalTransparencyModifier = if hidden then 1 else 0
		elseif inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") or inst:IsA("Light") then
			inst.Enabled = not hidden
		elseif inst:IsA("Highlight") then
			inst.Enabled = not hidden
		end
	end
	apply(root)
	for _, descendant in root:GetDescendants() do
		apply(descendant)
	end
	if not hidden and (root.Name == "SwordWaveProjectile" or root.Name == "SwordWavePillar" or root.Name == "AbyssalTorrent") then
		VfxUtil.applyHeavyQuality(root, VfxLoad.quality() ~= "Minimal")
	end
end

local function refresh(instance: Instance)
	if not isBrainrotVfx(instance) then
		return
	end
	local hide = not VfxLoad.showsOtherPlots() and not PlotUtil.isOnLocalPlot(instance)
	conceal(instance, hide)
end

local function watchFolder(folder: Instance)
	if watched[folder] then
		return
	end
	watched[folder] = true
	for _, child in folder:GetChildren() do
		refresh(child)
	end
	folder.ChildAdded:Connect(refresh)
end

local function watchPlot(plot: Instance)
	if not plot:IsA("Model") then
		return
	end
	local folder = plot:FindFirstChild("Projectiles")
	if folder then
		watchFolder(folder)
	end
	plot.ChildAdded:Connect(function(child)
		if child.Name == "Projectiles" then
			watchFolder(child)
		end
	end)
end

function OtherPlotVfx.start()
	local plots = Workspace:FindFirstChild(Constants.WORKSPACE_FOLDERS.Plots)
	if plots then
		for _, plot in plots:GetChildren() do
			watchPlot(plot)
		end
		plots.ChildAdded:Connect(watchPlot)
	end
	VfxLoad.onOtherPlotsChanged(function()
		for folder in watched do
			for _, child in folder:GetChildren() do
				refresh(child)
			end
		end
	end)
end

return OtherPlotVfx
