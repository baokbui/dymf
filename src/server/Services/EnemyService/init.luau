--!strict
--[[
	EnemyService
	Owns zombie spawning, pathfinding, and per-instance state. All zombies
	derive from one base; types are data entries in Shared.Zombies. Spawning is
	driven by WaveService, never advanced here.

	Milestones 6 & 11. Stub: lifecycle only, no behavior yet.
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
