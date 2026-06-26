--!strict
--[[
	SaveService
	The ONLY system that touches DataStore. Persists player-owned progression
	(wave, coins, health, planted Brainrots, merges, unlocks, upgrades, stats)
	using versioned save data. Never persists transient combat/zombie state.

	Milestone 9. Stub: lifecycle only, no behavior yet.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)

local SaveService = {}
SaveService.Name = "SaveService"

local log = Logger.new(SaveService.Name)

function SaveService.init()
end

function SaveService.start()
	log:info("started (stub)")
end

return SaveService
