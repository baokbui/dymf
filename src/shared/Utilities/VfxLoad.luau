--!strict
--[[
	VfxLoad
	Server- and client-local budget for heavy combat VFX (GOD ultimates).
	Full quality until the live load hits HEAVY_VFX_FULL_UNTIL; then new
	effects spawn Reduced, then Minimal. Damage is never throttled.
	Each VM has its own counter (server replication vs local CombatVisual).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxConfig = require(ReplicatedStorage.Shared.Config.VfxConfig)

local VfxLoad = {}

export type Quality = "Full" | "Reduced" | "Minimal"

local load = 0

function VfxLoad.qualityAt(loadNow: number): Quality
	if loadNow < VfxConfig.HEAVY_VFX_FULL_UNTIL then
		return "Full"
	end
	if loadNow < VfxConfig.HEAVY_VFX_REDUCED_UNTIL then
		return "Reduced"
	end
	return "Minimal"
end

function VfxLoad.current(): number
	return load
end

function VfxLoad.acquire(cost: number): (Quality, () -> ())
	local amount = math.max(1, math.floor(cost))
	local quality = VfxLoad.qualityAt(load)
	load += amount
	local released = false
	return quality, function()
		if released then
			return
		end
		released = true
		load = math.max(0, load - amount)
	end
end

return VfxLoad
