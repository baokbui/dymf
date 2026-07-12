--!strict
--[[
	Constants
	Immutable, non-balancing values shared across the game.

	Balancing values (cost, health, damage, etc.) do NOT belong here.
	Those live in Config. Constants are structural identifiers and keys.
]]

local Constants = {}

-- Current save schema version. Increment when SaveData shape changes so
-- SaveService can migrate older payloads.
Constants.SAVE_VERSION = 2

-- DataStore name owned exclusively by SaveService.
Constants.SAVE_DATASTORE_NAME = "BVZ_PlayerData_v1"

-- Workspace folder names (see GAME_DESIGN folder structure).
Constants.WORKSPACE_FOLDERS = {
	Plots = "Plots",
	EnemyPaths = "EnemyPaths",
	Maps = "Maps",
}

-- CollectionService tags used to classify instances at runtime.
Constants.TAGS = {
	Brainrot = "Brainrot",
	Monster = "Monster",
	GridTile = "GridTile",
	Plot = "Plot",
	Coin = "Coin",
}

-- Per-level phase identifiers used by LevelService (PvZ-style campaign).
Constants.PHASE = {
	Preparation = "Preparation", -- waiting to start the level (no planting yet)
	Countdown = "Countdown", -- brief countdown after Start Level
	Active = "Active", -- spawn groups running / level in progress
	Victory = "Victory", -- all groups cleared — level won
	Defeat = "Defeat", -- monsters breached the house — level lost
}

table.freeze(Constants.WORKSPACE_FOLDERS)
table.freeze(Constants.TAGS)
table.freeze(Constants.PHASE)
table.freeze(Constants)

return Constants
