--!strict
--[[
	GraveConfig
	Fog-tile graves that spawn Zombies / Skeletons throughout the day.
	Per-day enable flag is `LevelDefinition.graves`; count is rolled here.
]]

local GraveConfig = {
	MODEL_ID = "Grave",
	-- Target horizontal size vs tile (studs) when cloning Assets.Graves.
	FOOTPRINT_RATIO = 0.72,
	MODEL_SCALE = 1,
	-- Local look after clone. −X faces the house; flip if the mesh is authored the other way.
	FACE_DIRECTION = Vector3.new(-1, 0, 0),

	-- How many graves to place at Start Day (inclusive).
	COUNT_MIN = 1,
	COUNT_MAX = 5,
	EMERGE_MIN = 8,
	EMERGE_MAX = 52,
	-- Seconds between later spawns from the same grave (while the day is Active
	-- and authored waves are still running).
	RESPAWN_MIN = 12,
	RESPAWN_MAX = 24,

	-- Equal chance per emerge. Both ids must exist in Shared.Monsters.
	MONSTER_POOL = { "Zombie", "Skeleton" },
	-- Desert days (41–50): mummy-only until later desert species are authored.
	DESERT_MONSTER_POOL = { "SmallMummy" },

	TICK = 0.1,

	-- Start-of-day rise from under the tile (fully buried, then tween up).
	RISE_DURATION = 0.9,
	RISE_STAGGER = 0.15,
	-- Extra studs below visual height so the mesh starts fully underground.
	RISE_EXTRA_STUDS = 0.5,
	-- Zombie/Skeleton climb out of the grave.
	MONSTER_RISE_DURATION = 0.85,
}

table.freeze(GraveConfig)

return GraveConfig
