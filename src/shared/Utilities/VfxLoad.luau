--!strict
--[[
	VfxLoad
	Heavy combat VFX quality for GOD ultimates (sword waves, pillars, slams,
	jackpot). Quality is a client Settings toggle — never auto-throttled by
	how many effects are alive. Damage is never throttled.

	Server always authors Full visuals so every plot sees the same geometry.
	Performance-mode clients strip particles/trails locally.
]]

local RunService = game:GetService("RunService")

local VfxLoad = {}

export type Quality = "Full" | "Reduced" | "Minimal"

local highQuality = true
local listeners: { (boolean) -> () } = {}

function VfxLoad.isHighQuality(): boolean
	if not RunService:IsClient() then
		return true
	end
	return highQuality
end

function VfxLoad.quality(): Quality
	return if VfxLoad.isHighQuality() then "Full" else "Minimal"
end

function VfxLoad.setHighQuality(enabled: boolean)
	if not RunService:IsClient() then
		return
	end
	if highQuality == enabled then
		return
	end
	highQuality = enabled
	for _, listener in listeners do
		listener(enabled)
	end
end

function VfxLoad.onHighQualityChanged(listener: (boolean) -> ())
	table.insert(listeners, listener)
end

function VfxLoad.acquire(_cost: number): (Quality, () -> ())
	return VfxLoad.quality(), function() end
end

return VfxLoad
