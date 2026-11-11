--!strict
-- Isolated client visibility checks with real Instances and a fake local player.
return function(source: string): string
	local folder = Instance.new("Folder")
	folder.Parent = game.ServerStorage
	local realGame = game
	local chunk = assert(loadstring(source))
	setfenv(chunk, setmetatable({ game = { GetService = function(_, name)
		if name == "Players" then return { LocalPlayer = { UserId = 11 } } end
		if name == "Workspace" then return { WaitForChild = function() return folder end } end
		return realGame:GetService(name)
	end } }, { __index = getfenv() }))
	local function plot(owner)
		local model = Instance.new("Model")
		model:SetAttribute("OwnerUserId", owner)
		local house = Instance.new("Model")
		house.Name, house.Parent = "House", model
		local residents = Instance.new("Folder")
		residents.Name, residents.Parent = "Residents", house
		model.Parent = folder
		return model, residents
	end
	local function resident(parent)
		local model = Instance.new("Model")
		local part = Instance.new("Part")
		part.LocalTransparencyModifier, part.CastShadow = 0.25, true
		part.Parent = model
		local plate = Instance.new("BillboardGui")
		plate.Enabled, plate.Parent = true, model
		local decal = Instance.new("Decal")
		decal.Transparency, decal.Parent = 0.3, part
		model.Parent = parent
		return model, part, plate, decal
	end
	local own, ownFolder = plot(11)
	local other, otherFolder = plot(22)
	local _, ownPart, ownLabel = resident(ownFolder)
	local model, part, plate, decal = resident(otherFolder)
	local controller = chunk()
	controller.start()
	controller.start()
	controller.setHideOtherFarms(true)
	assert(ownPart.LocalTransparencyModifier == 0.25 and ownLabel.Enabled, "own farm was hidden")
	assert(part.LocalTransparencyModifier == 1 and not part.CastShadow and not plate.Enabled and decal.Transparency == 1)
	local _, newPart, newLabel = resident(otherFolder)
	task.wait()
	assert(newPart.LocalTransparencyModifier == 1 and not newLabel.Enabled, "new resident escaped hide")
	local extra = Instance.new("Part")
	extra.Parent = model
	task.wait()
	assert(extra.LocalTransparencyModifier == 1, "new geometry escaped hide")
	other:SetAttribute("OwnerUserId", 11)
	task.wait()
	assert(part.LocalTransparencyModifier == 0.25 and part.CastShadow and plate.Enabled, "ownership change did not restore own farm")
	other:SetAttribute("OwnerUserId", 22)
	task.wait()
	assert(part.LocalTransparencyModifier == 1)
	controller.setHideOtherFarms(false)
	assert(part.LocalTransparencyModifier == 0.25 and math.abs(decal.Transparency - 0.3) < 0.001 and plate.Enabled)
	controller.setHideOtherFarms(true)
	other.Parent = nil
	task.wait()
	assert(part.LocalTransparencyModifier == 0.25 and plate.Enabled, "removed plot retained local hiding")
	other:Destroy()
	folder:Destroy()
	return "Other-farm hiding, own-farm visibility, new residents/parts, ownership changes, restoration and cleanup passed"
end
