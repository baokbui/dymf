--!strict
	--[[
	HouseMascot
	Post-process optional roof mascot under Assets.Houses (e.g. "Tung Mascot"
	nested under Cottage → Second Floor): scale up, optionally strip leg meshes,
	re-seat on the roof, no collision.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HouseConfig = require(ReplicatedStorage.Shared.Config.HouseConfig)
local ModelUtil = require(ReplicatedStorage.Shared.Utilities.ModelUtil)

local HouseMascot = {}

local function looksLikeLeg(name: string): boolean
	local lower = string.lower(name)
	return string.find(lower, "leg", 1, true) ~= nil
		or string.find(lower, "foot", 1, true) ~= nil
		or string.find(lower, "shoe", 1, true) ~= nil
		or string.find(lower, "thigh", 1, true) ~= nil
		or string.find(lower, "calf", 1, true) ~= nil
		or string.find(lower, "ankle", 1, true) ~= nil
		or string.find(lower, "boot", 1, true) ~= nil
end

local function countVisualParts(root: Instance): number
	local count = 0
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Transparency < 0.95 then
			count += 1
		end
	end
	return count
end

local function stripLegs(mascot: Model): boolean
	local before = countVisualParts(mascot)
	if before < 2 then
		return false
	end

	local toDestroy: { Instance } = {}
	for _, descendant in mascot:GetDescendants() do
		if looksLikeLeg(descendant.Name) then
			table.insert(toDestroy, descendant)
		end
	end
	if #toDestroy == 0 then
		return false
	end

	for _, inst in toDestroy do
		if inst.Parent then
			inst:Destroy()
		end
	end

	-- Bail out if naming wiped the whole mascot (restore isn't possible; avoid empty prop).
	local after = countVisualParts(mascot)
	return after >= 1 and after < before
end

local function hardenMascot(mascot: Model)
	for _, descendant in mascot:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Anchored = true
			descendant.Massless = true
		end
	end
end

local function seatBottomAt(mascot: Model, bottomY: number)
	local size, center = ModelUtil.getVisualSizeAndCenter(mascot)
	local currentBottom = center.Y - size.Y * 0.5
	mascot:PivotTo(mascot:GetPivot() + Vector3.new(0, bottomY - currentBottom, 0))
end

--[[
	Hide mascot meshes from visual AABB (Transparency) so house fit ignores them.
	Returns a restore function.
]]
function HouseMascot.beginExcludeFromFit(house: Model): () -> ()
	local name = HouseConfig.MASCOT_NAME
	local mascot = house:FindFirstChild(name, true)
	if not mascot or not mascot:IsA("Model") then
		return function() end
	end

	local saved: { { part: BasePart, transparency: number } } = {}
	for _, descendant in mascot:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(saved, { part = descendant, transparency = descendant.Transparency })
			descendant.Transparency = 1
		end
	end

	return function()
		for _, entry in saved do
			if entry.part.Parent then
				entry.part.Transparency = entry.transparency
			end
		end
	end
end

function HouseMascot.dress(house: Model)
	local cfg = HouseConfig
	local mascot = house:FindFirstChild(cfg.MASCOT_NAME, true)
	if not mascot or not mascot:IsA("Model") then
		return
	end

	if cfg.MASCOT_STRIP_LEGS then
		stripLegs(mascot)
	end

	local size, center = ModelUtil.getVisualSizeAndCenter(mascot)
	local roofY = center.Y - size.Y * 0.5

	local factor = cfg.MASCOT_SCALE
	if factor > 0.01 and math.abs(factor - 1) > 1e-3 then
		mascot:ScaleTo(mascot:GetScale() * factor)
	end

	seatBottomAt(mascot, roofY)
	hardenMascot(mascot)
end

return HouseMascot
