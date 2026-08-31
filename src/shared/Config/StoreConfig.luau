--!strict
--[[
	StoreConfig
	Per-plot mini stores cloned beside each house. Templates live under
	ReplicatedStorage.Assets.Stores (Studio). Catalog prices in ProgressConfig.
]]

local StoreConfig = {
	ASSETS_FOLDER = "Stores",
	-- Fallback if templates are still in Workspace (moved into Assets at runtime).
	WORKSPACE_FOLDER = "Progression Stores",

	BRAINROT_STORE_MODEL_ID = "Blue Mini Store",
	UPGRADE_STORE_MODEL_ID = "Red Mini Store",

	BRAINROT_MASCOT_NAME = "Tung Mascot",
	UPGRADE_MASCOT_NAME = "67 Mascot",

	BRAINROT_PROMPT_OBJECT = "Brainrot Shop",
	UPGRADE_PROMPT_OBJECT = "Upgrade Shop",
	PROMPT_ACTION = "Talk",
	PROMPT_DISTANCE = 14,
	PROMPT_HOLD = 0,

	SHOP_BRAINROTS = "Brainrots",
	SHOP_UPGRADES = "Upgrades",

	PLOT_FOLDER_NAME = "ProgressionStores",

	-- Open stall faces the yard on a diagonal toward the outer sand (lawn +X, −Z).
	FACE_DIRECTION = Vector3.new(1, 0, -1),
	MODEL_ORIENTATION_DEGREES = Vector3.new(0, -90, 0),

	-- Origin is the Brainrots stall (closer to the door). Upgrades is offset
	-- along FACE: after template yaw −90 that axis is stall *width*, so the
	-- pair sits side by side instead of one behind the other.
	-- Smaller STORE_SPACING = closer together. More negative DOOR_RIGHT_Z =
	-- further back along the house (away from the door / walk-up).
	YARD_OFFSET_X = 16,
	STORE_SPACING = 16,
	DOOR_RIGHT_Z = -32,
}

table.freeze(StoreConfig)

return StoreConfig
