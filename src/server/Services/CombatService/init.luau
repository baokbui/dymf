--!strict
--[[
	CombatService
	The ONLY system that modifies health. Owns damage, healing, death, target
	acquisition, projectiles, and status effects (Slow/Freeze/Poison/Burn/
	Knockback). Brainrots and monsters route all health changes through here.

	Milestone 7. Stub: lifecycle only, no behavior yet.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)

local CombatService = {}
CombatService.Name = "CombatService"

local log = Logger.new(CombatService.Name)

function CombatService.init()
end

function CombatService.start()
	log:info("started (stub)")
end

return CombatService
