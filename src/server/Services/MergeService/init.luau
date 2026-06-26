--!strict
--[[
	MergeService
	Owns Brainrot merging: validation against the merge registry, consuming
	source Brainrots, and producing the resulting variant. Merge rules are data
	(see Shared.Brainrots definitions), kept out of branching logic.

	Milestone 10. Stub: lifecycle only, no behavior yet.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)

local MergeService = {}
MergeService.Name = "MergeService"

local log = Logger.new(MergeService.Name)

function MergeService.init()
end

function MergeService.start()
	log:info("started (stub)")
end

return MergeService
