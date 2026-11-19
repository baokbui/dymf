--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local HouseConfig = require(Shared.Config.HouseConfig)
local ModelUtil = require(Shared.Utilities.ModelUtil)
local SanctuaryConfig = require(Shared.Config.SanctuaryConfig)
local Decor = require(script.Parent.ForestDecor)
local HouseSlot = require(script.Parent.HouseSlot)
local SanctuaryBuilder = {}

function SanctuaryBuilder.build(origin: Vector3, westX: number, playLeftX: number): Model
	local slot = HouseSlot.compute(origin, westX, playLeftX)
	local house = Instance.new("Model")
	house.Name = "House"
	local width, depth = HouseConfig.WIDTH, HouseConfig.DEPTH
	local center = Vector3.new(slot.centerX, slot.grassY, slot.centerZ)
	local function part(name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material): Part
		return Decor.part(house, name, size, CFrame.new(center + offset), color, material)
	end
	local cream = Color3.fromRGB(241, 219, 169)
	local signX = -depth / 2 - 2
	local signY = 8
	local template = ModelUtil.findHouseTemplate(HouseConfig.FARM_MODEL_ID)
	if template then
		local appearance = ModelUtil.cloneTemplate(template, {
			targetFootprint = math.min(width, depth),
			anchorAllParts = true,
			skipBodyAlias = true,
		})
		appearance.Name = "FarmAppearance"
		local rotation = HouseConfig.FARM_ORIENTATION_DEGREES
		appearance:PivotTo(appearance:GetPivot() * CFrame.Angles(
			math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z)))
		ModelUtil.snapFeetToTileTop(appearance, center)
		local appearanceBounds, size = appearance:GetBoundingBox()
		signX = appearanceBounds.Position.X - center.X - size.X / 2 - 2
		signY = size.Y + 3.5
		local floor: BasePart? = nil
		for _, item in appearance:GetDescendants() do
			if item:IsA("BasePart") then
				item.CanCollide, item.CanTouch, item.CanQuery = false, false, false
				if not floor or item.Size.X * item.Size.Z > floor.Size.X * floor.Size.Z then
					floor = item
				end
			end
		end
		house:SetAttribute("ResidentHalfWidth", size.X / 2 - SanctuaryConfig.EDGE_INSET)
		house:SetAttribute("ResidentHalfDepth", size.Z / 2 - SanctuaryConfig.EDGE_INSET)
		if floor then
			house:SetAttribute("ResidentGroundY", floor.Position.Y + floor.Size.Y / 2)
		end
		appearance.Parent = house
	else
		local floor = part("HabitatGrass", Vector3.new(depth, 0.2, width), Vector3.zero, Color3.fromRGB(103, 147, 78), Enum.Material.Grass)
		floor.CastShadow = false
		house.PrimaryPart = floor
		-- Open entrance on the lawn side. Low rails preserve views of residents.
		for _, side in { -1, 1 } do
			part("SideRail", Vector3.new(depth, 0.5, 0.5), Vector3.new(0, 3, side * width / 2), HouseConfig.TRIM_COLOR, Enum.Material.Wood)
			part("FrontRail", Vector3.new(0.5, 0.5, width / 2 - HouseConfig.DOOR_WIDTH / 2),
				Vector3.new(depth / 2, 3, side * (width / 4 + HouseConfig.DOOR_WIDTH / 4)), HouseConfig.TRIM_COLOR, Enum.Material.Wood)
			for x = -depth / 2, depth / 2, depth / 4 do
				part("FencePost", Vector3.new(1, 4, 1), Vector3.new(x, 2, side * width / 2), HouseConfig.TRIM_COLOR, Enum.Material.Wood)
			end
		end
		part("BackRail", Vector3.new(0.5, 0.5, width), Vector3.new(-depth / 2, 3, 0), HouseConfig.TRIM_COLOR, Enum.Material.Wood)
		-- Edge planting leaves the central wandering rectangle open.
		for _, side in { -1, 1 } do
			for _, x in { -depth / 2 + 5, 0, depth / 2 - 5 } do
				local shrub = part("HabitatShrub", Vector3.new(7, 4, 6),
					Vector3.new(x, 2, side * (width / 2 - 3)), Color3.fromRGB(65, 116, 75), Enum.Material.Grass)
				shrub.Shape = Enum.PartType.Ball
			end
		end
		local water = part("WaterBowl", Vector3.new(0.6, 7, 7), Vector3.new(-depth / 2 + 4, 0.6, 17),
			Color3.fromRGB(107, 168, 183), Enum.Material.SmoothPlastic)
		water.Shape = Enum.PartType.Cylinder
		water.CFrame *= CFrame.Angles(0, 0, math.pi / 2)
		-- A covered timber shelter along the edge of the pasture.
		local shelterZ = -width / 2 + 5
		local barnRed = Color3.fromRGB(154, 62, 48)
		for _, x in { -24, -8 } do
			for _, dz in { -3, 3 } do
				part("BarnPost", Vector3.new(1, 8, 1), Vector3.new(x, 4, shelterZ + dz), cream, Enum.Material.Wood)
			end
		end
		part("BarnWall", Vector3.new(17, 7, 0.7), Vector3.new(-16, 3.6, shelterZ - 3), barnRed, Enum.Material.WoodPlanks)
		for _, side in { -1, 1 } do
			local roof = part("BarnRoof", Vector3.new(19, 0.6, 5), Vector3.new(-16, 8.5, shelterZ + side * 2.2),
				barnRed, Enum.Material.WoodPlanks)
			roof.CFrame *= CFrame.Angles(math.rad(24 * side), 0, 0)
			part("GatePost", Vector3.new(1.4, 12, 1.4), Vector3.new(depth / 2 - 1, 6, side * 8), cream, Enum.Material.Wood)
		end
		part("GateBeam", Vector3.new(1.6, 1, 19), Vector3.new(depth / 2 - 1, 12, 0), barnRed, Enum.Material.Wood)
		for bale = 0, 2 do
			local x = -22 + bale * 4
			part("HayBale", Vector3.new(3.8, 2.4, 3), Vector3.new(x, 1.3, shelterZ), Color3.fromRGB(218, 174, 78), Enum.Material.Grass)
			part("BaleTwine", Vector3.new(0.25, 2.5, 3.1), Vector3.new(x, 1.3, shelterZ), HouseConfig.TRIM_COLOR, Enum.Material.Fabric)
		end
	end
	local sign = part("Sign", Vector3.new(0.5, 7, 34), Vector3.new(signX, signY, 0),
		Color3.fromRGB(39, 68, 51), Enum.Material.Wood)
	local postSize = Vector3.new(1, signY, 1)
	-- The label faces +X. Mount supports flush against the opposite (-X) face.
	local postX = signX - (sign.Size.X + postSize.X) / 2
	for _, side in { -1, 1 } do
		part("SignPost", postSize, Vector3.new(postX, signY / 2, side * 14),
			HouseConfig.TRIM_COLOR, Enum.Material.Wood)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right
	gui.CanvasSize = Vector2.new(700, 240)
	gui.Parent = sign
	local owner = Instance.new("TextLabel")
	owner.Name = "Owner"
	owner.Position = UDim2.fromScale(0.04, 0.08)
	owner.Size = UDim2.fromScale(0.92, 0.84)
	owner.BackgroundTransparency = 1
	owner.Text = HouseConfig.EMPTY_SIGN_TEXT
	owner.TextColor3 = Color3.new(1, 1, 1)
	owner.TextScaled = true
	owner.Font = Enum.Font.GothamBold
	owner.Parent = gui
	local residents = Instance.new("Folder")
	residents.Name = "Residents"
	residents.Parent = house
	house:SetAttribute("HouseFrontX", slot.frontX - origin.X)
	house:SetAttribute("HouseSource", "Sanctuary")
	house.WorldPivot = CFrame.new(center)
	return house
end

return SanctuaryBuilder
