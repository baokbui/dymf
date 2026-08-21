--!strict
--[[
	HouseBossDisplay
	Placeholder for Milestone 21 trophies. Authored Cottage already includes
	pedestals — do not spawn procedural ones. Only ensures a CollectedBosses
	folder exists for future display models.
]]

local HouseBossDisplay = {}

function HouseBossDisplay.attach(model: Model, _slot: any, _backX: number, _floorTop: number)
	if model:FindFirstChild("CollectedBosses") then
		return
	end
	local collected = Instance.new("Folder")
	collected.Name = "CollectedBosses"
	collected.Parent = model
end

return HouseBossDisplay
