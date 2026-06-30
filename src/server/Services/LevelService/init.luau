--!strict
--[[
	LevelService
	The ONLY system that advances campaign levels (PvZ-style). It owns the
	per-level lifecycle: preparation, countdown, playing a level's authored spawn
	groups (the internal "waves" ending in a big wave), tracking progress,
	detecting victory (all groups cleared) / defeat (the house is breached),
	granting the completion reward via CoinService, and unlocking the next level.

	It decides *what* spawns and *when* by reading the data-driven Shared.Levels
	registry (never branching on level numbers) and drives EnemyService to spawn;
	EnemyService handles *how* monsters move and fight. State is broadcast to
	clients via the LevelStateChanged remote.

	Milestone 8. Stub: lifecycle only, no behavior yet.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)

local LevelService = {}
LevelService.Name = "LevelService"

local log = Logger.new(LevelService.Name)

function LevelService.init()
end

function LevelService.start()
	log:info("started (stub)")
end

return LevelService
