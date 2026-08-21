--!strict
--[[
	HouseConfig
	Per-plot house shell (west of the lawn) and boss-display pedestals.
	Prefer a Toolbox model under ReplicatedStorage.Assets.Houses; procedural
	cottage is the fallback. Boss collection / brains income is Milestone 21.
]]

local HouseConfig = {
	-- Child name under ReplicatedStorage.Assets.Houses (Studio / Toolbox insert).
	MODEL_ID = "Cottage",

	-- Door / front should face the lawn (+X). Many Toolbox houses face the
	-- opposite way of LookVector, so default yaw is 180°.
	FACE_DIRECTION = Vector3.new(1, 0, 0),
	MODEL_ORIENTATION_DEGREES = Vector3.new(0, 180, 0),

	-- Footprint target inside HOUSE_ZONE (scales the Toolbox model to fit).
	DEPTH = 85, -- along X (back → front)
	WIDTH = 74, -- along Z
	MAX_HEIGHT = 36, -- clamp tall Toolbox houses

	-- Procedural fallback shell (when Assets.Houses.Cottage is missing).
	HEIGHT = 22,
	WALL_THICKNESS = 1.4,
	FLOOR_THICKNESS = 0.6,

	-- Gap from house front face to the play-area (spawn yard).
	YARD_GAP = 20,

	DOOR_WIDTH = 12,
	DOOR_HEIGHT = 11,
	WINDOW_WIDTH = 5,
	WINDOW_HEIGHT = 4,

	ROOF_OVERHANG = 3,
	ROOF_HEIGHT = 10,

	-- Future boss trophies (M21). Empty pedestals + attachments are built now.
	BOSS_SLOT_COUNT = 5,
	BOSS_SLOT_SPACING = 11,
	BOSS_PEDESTAL_RADIUS = 3.2,
	BOSS_PEDESTAL_HEIGHT = 1.1,
	BOSS_DISPLAY_HEIGHT = 0.2,
	-- How far inside the back (−X) of the house AABB to place pedestals.
	BOSS_PEDESTAL_INSET = 8,

	-- Optional roof mascot under Assets.Houses.Cottage (exact child name).
	MASCOT_NAME = "Tung Mascot",
	MASCOT_SCALE = 4.5, -- multiplier after the house is fitted (very large on roof)
	MASCOT_STRIP_LEGS = true, -- destroy Leg/Foot-named parts when present

	FLOOR_COLOR = Color3.fromRGB(92, 72, 52),
	WALL_COLOR = Color3.fromRGB(168, 148, 118),
	TRIM_COLOR = Color3.fromRGB(72, 52, 36),
	ROOF_COLOR = Color3.fromRGB(58, 42, 36),
	DOOR_FRAME_COLOR = Color3.fromRGB(48, 34, 24),
	WINDOW_GLOW = Color3.fromRGB(255, 210, 120),
	PEDESTAL_COLOR = Color3.fromRGB(64, 58, 72),
	PEDESTAL_TOP_COLOR = Color3.fromRGB(110, 100, 88),

	EMPTY_SIGN_TEXT = "Empty Base",
	OWNER_SIGN_FORMAT = "%s's Base", -- %s = player DisplayName
}

table.freeze(HouseConfig)

return HouseConfig
