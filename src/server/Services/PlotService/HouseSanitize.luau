--!strict
--[[
	HouseSanitize
	Toolbox house cleanup: strip Lock Base UI, rewrite Empty Base owner sign.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HouseConfig = require(ReplicatedStorage.Shared.Config.HouseConfig)

local HouseSanitize = {}

local function nameLooksLikeLock(name: string): boolean
	local lower = string.lower(name)
	return string.find(lower, "lockbase", 1, true) ~= nil
		or string.find(lower, "lock base", 1, true) ~= nil
		or string.find(lower, "lock_base", 1, true) ~= nil
end

local function textLooksLikeLock(text: string): boolean
	return string.find(string.lower(text), "lock base", 1, true) ~= nil
end

function HouseSanitize.stripLockBase(house: Model)
	local toDestroy: { Instance } = {}

	for _, inst in house:GetDescendants() do
		if nameLooksLikeLock(inst.Name) then
			table.insert(toDestroy, inst)
			continue
		end
		if inst:IsA("ProximityPrompt") then
			local label = string.lower(inst.ActionText .. " " .. inst.ObjectText)
			if string.find(label, "lock", 1, true) then
				table.insert(toDestroy, inst)
			end
			continue
		end
		if inst:IsA("BillboardGui") or inst:IsA("SurfaceGui") then
			local hasLockText = false
			for _, child in inst:GetDescendants() do
				if (child:IsA("TextLabel") or child:IsA("TextButton")) and textLooksLikeLock(child.Text) then
					hasLockText = true
					break
				end
			end
			if hasLockText then
				table.insert(toDestroy, inst)
				local pad: Instance? = inst.Parent
				if inst:IsA("BillboardGui") and inst.Adornee then
					pad = inst.Adornee
				end
				if pad and pad:IsA("BasePart") then
					table.insert(toDestroy, pad)
				end
			end
		end
	end

	for _, inst in toDestroy do
		if inst.Parent then
			inst:Destroy()
		end
	end
end

function HouseSanitize.setOwnerLabel(house: Model, ownerName: string?)
	local cfg = HouseConfig
	local text = if ownerName and ownerName ~= ""
		then string.format(cfg.OWNER_SIGN_FORMAT, ownerName)
		else cfg.EMPTY_SIGN_TEXT

	for _, inst in house:GetDescendants() do
		if not (inst:IsA("TextLabel") or inst:IsA("TextButton")) then
			continue
		end
		local lower = string.lower(inst.Text)
		local underSign = false
		local walk: Instance? = inst.Parent
		while walk and walk ~= house do
			local parentName = string.lower(walk.Name)
			if parentName == "sign"
				or string.find(parentName, "owner sign", 1, true) ~= nil
				or string.find(parentName, "ownersign", 1, true) ~= nil
			then
				underSign = true
				break
			end
			walk = walk.Parent
		end
		local isSign = inst:GetAttribute("IsOwnerSign") == true
			or underSign
			or string.find(lower, "empty base", 1, true) ~= nil
			or string.find(lower, "'s base", 1, true) ~= nil
		if isSign then
			inst.Text = text
			inst:SetAttribute("IsOwnerSign", true)
		end
	end
end

return HouseSanitize
