--!strict
--[[
	AuraQuality
	Local Brainrot evolution-aura density. The server always authors the full
	flame column plus the rarity Highlight. This module only changes particle
	Rate so High is dense, Low is a thin core, and Off has no flames.
	The AuraHighlight outline is left alone.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local VfxConfig = require(Shared.Config.VfxConfig)
local VfxLoad = require(Shared.Utilities.VfxLoad)

local AuraQuality = {}

local watched: { [ParticleEmitter]: RBXScriptConnection } = {}
local authoredRate: { [ParticleEmitter]: number } = {}

local function isAuraEmitter(descendant: Instance): boolean
	if not descendant:IsA("ParticleEmitter") then
		return false
	end
	local parent = descendant.Parent
	if not parent then
		return false
	end
	return parent.Name == "AuraVfx" or parent:FindFirstAncestor("AuraVfx") ~= nil
end

local function fullRate(emitter: ParticleEmitter): number
	local stored = emitter:GetAttribute("AuraFullRate")
	if type(stored) == "number" and stored > 0 then
		return stored
	end
	local remembered = authoredRate[emitter]
	if remembered then
		return remembered
	end
	local current = emitter.Rate
	local fallback = if current > 0 then current else VfxConfig.BRAINROT_AURA_SPIKES_RATE
	authoredRate[emitter] = fallback
	return fallback
end

local function layerOf(emitter: ParticleEmitter): string
	local layer = emitter:GetAttribute("AuraLayer")
	if type(layer) == "string" and layer ~= "" then
		return layer
	end
	return "Core"
end

local function hidden(emitter: ParticleEmitter, quality: VfxLoad.Quality): boolean
	if quality == "Minimal" then
		return true
	end
	return quality == "Reduced" and layerOf(emitter) == "High"
end

local function tune(emitter: ParticleEmitter)
	if not emitter.Parent then
		return
	end
	local quality = VfxLoad.quality()
	if hidden(emitter, quality) then
		if emitter.Rate ~= 0 then
			emitter.Rate = 0
		end
		emitter:Clear()
		return
	end
	local target = if quality == "Reduced" then VfxConfig.BRAINROT_AURA_SPIKES_RATE_LOW else fullRate(emitter)
	if emitter.Rate ~= target then
		emitter.Rate = target
	end
end

local function watchEmitter(emitter: ParticleEmitter)
	if watched[emitter] then
		tune(emitter)
		return
	end
	fullRate(emitter)
	tune(emitter)
	watched[emitter] = emitter:GetPropertyChangedSignal("Rate"):Connect(function()
		tune(emitter)
	end)
	emitter.Destroying:Connect(function()
		local conn = watched[emitter]
		if conn then
			conn:Disconnect()
			watched[emitter] = nil
		end
		authoredRate[emitter] = nil
	end)
end

local function scan(root: Instance)
	if isAuraEmitter(root) and root:IsA("ParticleEmitter") then
		watchEmitter(root)
	end
	for _, descendant in root:GetDescendants() do
		if isAuraEmitter(descendant) and descendant:IsA("ParticleEmitter") then
			watchEmitter(descendant)
		end
	end
end

local function watchModel(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	scan(instance)
	instance.DescendantAdded:Connect(function(descendant)
		if isAuraEmitter(descendant) and descendant:IsA("ParticleEmitter") then
			watchEmitter(descendant)
		end
	end)
end

function AuraQuality.start()
	local tag = Constants.TAGS.Brainrot
	for _, instance in CollectionService:GetTagged(tag) do
		watchModel(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(watchModel)
	VfxLoad.onChanged(function()
		for _, instance in CollectionService:GetTagged(tag) do
			scan(instance)
		end
	end)
end

return AuraQuality
