--!strict
--[[
	ProceduralHouse
	Fallback cottage when Assets.Houses[MODEL_ID] is missing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HouseConfig = require(ReplicatedStorage.Shared.Config.HouseConfig)
local HouseBossDisplay = require(script.Parent.HouseBossDisplay)
local HouseSlot = require(script.Parent.HouseSlot)

local ProceduralHouse = {}

local function harden(part: BasePart, canCollide: boolean)
	part.Anchored = true
	part.Locked = true
	part.CanCollide = canCollide
	part.CanTouch = false
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function part(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance,
	canCollide: boolean
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	harden(p, canCollide)
	p.Parent = parent
	return p
end

function ProceduralHouse.build(slot: HouseSlot.Slot): Model
	local model = Instance.new("Model")
	model.Name = "House"

	local cfg = HouseConfig
	local centerX = slot.centerX
	local centerZ = slot.centerZ
	local frontX = slot.frontX
	local backX = slot.backX
	local grassY = slot.grassY
	local floorTop = slot.floorTop
	local halfW = cfg.WIDTH / 2
	local wallT = cfg.WALL_THICKNESS
	local wallCenterY = floorTop + cfg.HEIGHT / 2

	part(
		"Floor",
		Vector3.new(cfg.DEPTH, cfg.FLOOR_THICKNESS, cfg.WIDTH),
		CFrame.new(centerX, grassY + cfg.FLOOR_THICKNESS / 2, centerZ),
		cfg.FLOOR_COLOR,
		Enum.Material.WoodPlanks,
		model,
		true
	)
	part(
		"Porch",
		Vector3.new(6, cfg.FLOOR_THICKNESS, cfg.DOOR_WIDTH + 4),
		CFrame.new(frontX + 3, grassY + cfg.FLOOR_THICKNESS / 2, centerZ),
		cfg.TRIM_COLOR,
		Enum.Material.WoodPlanks,
		model,
		true
	)

	local wallH = cfg.HEIGHT
	part(
		"WallNorth",
		Vector3.new(cfg.DEPTH, wallH, wallT),
		CFrame.new(centerX, wallCenterY, centerZ - halfW + wallT / 2),
		cfg.WALL_COLOR,
		Enum.Material.Brick,
		model,
		true
	)
	part(
		"WallSouth",
		Vector3.new(cfg.DEPTH, wallH, wallT),
		CFrame.new(centerX, wallCenterY, centerZ + halfW - wallT / 2),
		cfg.WALL_COLOR,
		Enum.Material.Brick,
		model,
		true
	)
	part(
		"WallWest",
		Vector3.new(wallT, wallH, cfg.WIDTH),
		CFrame.new(backX + wallT / 2, wallCenterY, centerZ),
		cfg.WALL_COLOR,
		Enum.Material.Brick,
		model,
		true
	)

	local doorHalf = cfg.DOOR_WIDTH / 2
	local sideWidth = (cfg.WIDTH - cfg.DOOR_WIDTH) / 2
	local frontPanelZOff = doorHalf + sideWidth / 2
	part(
		"WallEastNorth",
		Vector3.new(wallT, wallH, sideWidth),
		CFrame.new(frontX - wallT / 2, wallCenterY, centerZ - frontPanelZOff),
		cfg.WALL_COLOR,
		Enum.Material.Brick,
		model,
		true
	)
	part(
		"WallEastSouth",
		Vector3.new(wallT, wallH, sideWidth),
		CFrame.new(frontX - wallT / 2, wallCenterY, centerZ + frontPanelZOff),
		cfg.WALL_COLOR,
		Enum.Material.Brick,
		model,
		true
	)
	local lintelH = wallH - cfg.DOOR_HEIGHT
	if lintelH > 0.5 then
		part(
			"DoorLintel",
			Vector3.new(wallT, lintelH, cfg.DOOR_WIDTH),
			CFrame.new(frontX - wallT / 2, floorTop + cfg.DOOR_HEIGHT + lintelH / 2, centerZ),
			cfg.TRIM_COLOR,
			Enum.Material.Wood,
			model,
			true
		)
	end

	part(
		"DoorFrameLeft",
		Vector3.new(0.4, cfg.DOOR_HEIGHT, 0.5),
		CFrame.new(frontX, floorTop + cfg.DOOR_HEIGHT / 2, centerZ - doorHalf),
		cfg.DOOR_FRAME_COLOR,
		Enum.Material.Wood,
		model,
		false
	)
	part(
		"DoorFrameRight",
		Vector3.new(0.4, cfg.DOOR_HEIGHT, 0.5),
		CFrame.new(frontX, floorTop + cfg.DOOR_HEIGHT / 2, centerZ + doorHalf),
		cfg.DOOR_FRAME_COLOR,
		Enum.Material.Wood,
		model,
		false
	)

	local windowY = floorTop + cfg.HEIGHT * 0.45
	for _, zSign in { -1, 1 } do
		local wz = centerZ + zSign * (halfW - wallT / 2)
		part(
			if zSign < 0 then "WindowNorth" else "WindowSouth",
			Vector3.new(cfg.WINDOW_WIDTH, cfg.WINDOW_HEIGHT, 0.35),
			CFrame.new(centerX + cfg.DEPTH * 0.1, windowY, wz),
			cfg.WINDOW_GLOW,
			Enum.Material.Neon,
			model,
			false
		)
	end

	local roofLen = cfg.DEPTH + cfg.ROOF_OVERHANG * 2
	local roofWidth = halfW + cfg.ROOF_OVERHANG
	local roofY = floorTop + cfg.HEIGHT + cfg.ROOF_HEIGHT * 0.35
	local pitch = math.rad(28)
	part(
		"RoofNorth",
		Vector3.new(roofLen, 1.2, roofWidth),
		CFrame.new(centerX, roofY, centerZ - roofWidth * 0.45) * CFrame.Angles(pitch, 0, 0),
		cfg.ROOF_COLOR,
		Enum.Material.Slate,
		model,
		false
	)
	part(
		"RoofSouth",
		Vector3.new(roofLen, 1.2, roofWidth),
		CFrame.new(centerX, roofY, centerZ + roofWidth * 0.45) * CFrame.Angles(-pitch, 0, 0),
		cfg.ROOF_COLOR,
		Enum.Material.Slate,
		model,
		false
	)
	part(
		"Chimney",
		Vector3.new(4, 10, 4),
		CFrame.new(backX + 8, floorTop + cfg.HEIGHT + 4, centerZ - halfW * 0.35),
		cfg.TRIM_COLOR,
		Enum.Material.Brick,
		model,
		false
	)

	HouseBossDisplay.attach(model, slot, backX + wallT, floorTop)
	model:SetAttribute("HouseFrontX", frontX - slot.originX)
	model:SetAttribute("HouseSource", "Procedural")
	model.WorldPivot = CFrame.new(centerX, floorTop, centerZ)
	return model
end

return ProceduralHouse
