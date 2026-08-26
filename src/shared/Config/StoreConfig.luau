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

	-- Open stall faces the lawn / spawn (+X), where the player stands.
	FACE_DIRECTION = Vector3.new(1, 0, 0),
	MODEL_ORIENTATION_DEGREES = Vector3.new(0, -90, 0),

	-- Same Z (right of the door). Spread along X (house ↔ lawn) so they sit
	-- side by side after the −90° yaw (Z is now stall depth, not width).
	YARD_OFFSET_X = 18,
	STORE_SPACING_X = 16,
	DOOR_RIGHT_Z = -18,
}

table.freeze(StoreConfig)

return StoreConfig
