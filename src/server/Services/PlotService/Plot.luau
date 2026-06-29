--!strict
--[[
	Plot
	Lightweight wrapper around a built plot model. Tracks ownership and provides
	reuse cleanup so a freed plot can be handed to the next player. Plots are
	never destroyed at runtime (reuse over re-allocation).
]]

-- Folders whose children are per-owner and wiped on release. The "Grid" folder
-- is intentionally excluded: its tiles are static and reused across owners
-- (GridService resets their occupancy instead of rebuilding them).
local DYNAMIC_FOLDERS = { "Path", "Decorations" }

local Plot = {}
Plot.__index = Plot

export type Plot = typeof(setmetatable(
	{} :: {
		index: number,
		model: Model,
		base: BasePart,
		spawnLocation: SpawnLocation,
		ownerUserId: number?,
	},
	Plot
))

function Plot.new(
	index: number,
	model: Model,
	base: BasePart,
	spawnLocation: SpawnLocation
): Plot
	return setmetatable({
		index = index,
		model = model,
		base = base,
		spawnLocation = spawnLocation,
		ownerUserId = nil,
	}, Plot)
end

function Plot.isOccupied(self: Plot): boolean
	return self.ownerUserId ~= nil
end

function Plot.assign(self: Plot, userId: number)
	self.ownerUserId = userId
	self.model:SetAttribute("OwnerUserId", userId)
end

-- Releases ownership and clears per-owner contents so the plot can be reused.
function Plot.release(self: Plot)
	self.ownerUserId = nil
	self.model:SetAttribute("OwnerUserId", nil)
	for _, folderName in DYNAMIC_FOLDERS do
		local folder = self.model:FindFirstChild(folderName)
		if folder then
			folder:ClearAllChildren()
		end
	end
end

-- Center of the base's top surface (battlefield origin for future grid math).
function Plot.getOriginCFrame(self: Plot): CFrame
	return self.base.CFrame * CFrame.new(0, self.base.Size.Y / 2, 0)
end

return Plot
