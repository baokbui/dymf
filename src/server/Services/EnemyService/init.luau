--!strict
--[[
	EnemyService
	Owns monster spawning, pathfinding, and per-instance state. All monsters
	derive from one base; types (zombie, vampire, slime, ...) are data entries in
	Shared.Monsters. Spawning is driven by LevelService, never advanced here.

	Milestones 6 & 10. Stub: lifecycle only, no behavior yet.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)

local EnemyService = {}
EnemyService.Name = "EnemyService"

local log = Logger.new(EnemyService.Name)

function EnemyService.init()
end

function EnemyService.start()
	log:info("started (stub)")
end

return EnemyService
