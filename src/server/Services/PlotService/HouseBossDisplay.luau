--!strict
--[[
	HouseBossDisplay
	Interior pedestals + CollectedBosses folder for Milestone 25 trophies.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HouseConfig = require(ReplicatedStorage.Shared.Config.HouseConfig)
local HouseSlot = require(script.Parent.HouseSlot)

local HouseBossDisplay = {}

local function harden(part: BasePart, canCollide: boolean)
	part.Anchored = true
	part.Locked = true
	part.CanCollide = canCollide
	part.CanTouch = false
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

function HouseBossDisplay.attach(model: Model, slot: HouseSlot.Slot, backX: number, floorTop: number)
	local cfg = HouseConfig
	local display = Instance.new("Folder")
	display.Name = "BossDisplay"
	display.Parent = model

	local slotCount = cfg.BOSS_SLOT_COUNT
	local spacing = cfg.BOSS_SLOT_SPACING
	local totalSpan = (slotCount - 1) * spacing
	local firstZ = slot.centerZ - totalSpan / 2
	local pedestalX = backX + cfg.BOSS_PEDESTAL_INSET
	local pedestalTopY = floorTop + cfg.BOSS_PEDESTAL_HEIGHT

	for i = 1, slotCount do
		local bossSlot = Instance.new("Model")
		bossSlot.Name = string.format("BossSlot_%d", i)
		bossSlot.Parent = display

		local z = firstZ + (i - 1) * spacing
		local base = Instance.new("Part")
		base.Name = "Pedestal"
		base.Shape = Enum.PartType.Cylinder
		base.Size = Vector3.new(
			cfg.BOSS_PEDESTAL_HEIGHT,
			cfg.BOSS_PEDESTAL_RADIUS * 2,
			cfg.BOSS_PEDESTAL_RADIUS * 2
		)
		base.CFrame = CFrame.new(pedestalX, floorTop + cfg.BOSS_PEDESTAL_HEIGHT / 2, z)
			* CFrame.Angles(0, 0, math.rad(90))
		base.Color = cfg.PEDESTAL_COLOR
		base.Material = Enum.Material.Rock
		harden(base, true)
		base.Parent = bossSlot

		local top = Instance.new("Part")
		top.Name = "PedestalTop"
		top.Shape = Enum.PartType.Cylinder
		top.Size = Vector3.new(0.25, cfg.BOSS_PEDESTAL_RADIUS * 2.2, cfg.BOSS_PEDESTAL_RADIUS * 2.2)
		top.CFrame = CFrame.new(pedestalX, pedestalTopY + 0.12, z) * CFrame.Angles(0, 0, math.rad(90))
		top.Color = cfg.PEDESTAL_TOP_COLOR
		top.Material = Enum.Material.Marble
		harden(top, true)
		top.Parent = bossSlot

		local stand = Instance.new("Attachment")
		stand.Name = "BossStand"
		stand.Parent = top
		stand.WorldPosition = Vector3.new(pedestalX, pedestalTopY + cfg.BOSS_DISPLAY_HEIGHT, z)

		bossSlot:SetAttribute("SlotIndex", i)
		bossSlot:SetAttribute("OccupiedMonsterId", "")
	end

	local collected = Instance.new("Folder")
	collected.Name = "CollectedBosses"
	collected.Parent = model
end

return HouseBossDisplay
