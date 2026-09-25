--!strict
--[[
	VfxLoad
	Heavy combat VFX quality for GOD ultimates (sword waves, pillars, slams,
	jackpot) and the matching UI cost (3D portraits, moving evolution shine).
	Quality is a client Settings choice. Damage is never throttled. The server
	always authors the full ult. Low and Off only change what that client draws.
	`showsOtherPlots` (default on) hides Brainrot auras and Brainrot projectiles
	on plots the local player does not own. Monster attacks stay visible.

	High (Full): full combat effects, dense Brainrot aura, moving shine, 3D portraits.
	Low (Reduced): fewer client bursts, thin Brainrot aura, shine stays still,
	3D portraits stay.
	Off (Minimal): no heavy particles/trails and no Brainrot aura flames (the
	rarity outline stays). Shop, inventory, and index portraits become color
	swatches. Inspect portraits stay 3D.
]]

local RunService = game:GetService("RunService")

local VfxLoad = {}

export type Quality = "Full" | "Reduced" | "Minimal"

local ORDER: { Quality } = { "Full", "Reduced", "Minimal" }

local quality: Quality = "Full"
local showOtherPlots = true
local listeners: { (Quality) -> () } = {}
local otherPlotListeners: { (boolean) -> () } = {}

function VfxLoad.quality(): Quality
	if not RunService:IsClient() then
		return "Full"
	end
	return quality
end

function VfxLoad.isHighQuality(): boolean
	return VfxLoad.quality() == "Full"
end

-- Shop / inventory / index drop to swatches only when VFX is Off.
-- Inspect passes keepModel so its portrait stays 3D on every setting.
function VfxLoad.usesModelPortrait(keepModel: boolean?): boolean
	if keepModel == true then
		return true
	end
	return VfxLoad.quality() ~= "Minimal"
end

function VfxLoad.label(level: Quality?): string
	local current = level or VfxLoad.quality()
	if current == "Full" then
		return "High"
	end
	if current == "Reduced" then
		return "Low"
	end
	return "Off"
end

function VfxLoad.setQuality(nextQuality: Quality)
	if not RunService:IsClient() then
		return
	end
	if quality == nextQuality then
		return
	end
	quality = nextQuality
	for _, listener in listeners do
		listener(quality)
	end
end

function VfxLoad.cycle()
	local index = 1
	for i, level in ORDER do
		if level == quality then
			index = i
			break
		end
	end
	local nextQuality = ORDER[(index % #ORDER) + 1]
	VfxLoad.setQuality(nextQuality)
end

function VfxLoad.setHighQuality(enabled: boolean)
	VfxLoad.setQuality(if enabled then "Full" else "Minimal")
end

function VfxLoad.onChanged(listener: (Quality) -> ())
	table.insert(listeners, listener)
end

function VfxLoad.onHighQualityChanged(listener: (boolean) -> ())
	VfxLoad.onChanged(function(level)
		listener(level == "Full")
	end)
end

function VfxLoad.showsOtherPlots(): boolean
	return showOtherPlots
end

function VfxLoad.setShowOtherPlots(enabled: boolean)
	if not RunService:IsClient() then
		return
	end
	if showOtherPlots == enabled then
		return
	end
	showOtherPlots = enabled
	for _, listener in otherPlotListeners do
		listener(showOtherPlots)
	end
end

function VfxLoad.onOtherPlotsChanged(listener: (boolean) -> ())
	table.insert(otherPlotListeners, listener)
end

function VfxLoad.acquire(_cost: number): (Quality, () -> ())
	return VfxLoad.quality(), function() end
end

return VfxLoad
