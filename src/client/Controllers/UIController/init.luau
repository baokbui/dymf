--!strict
--[[
	UIController
	Owns the main UI: Shop, Coins, Wave display, Settings. UI only displays
	server-provided state and forwards intent via Remotes — it performs no
	gameplay logic.

	Milestones 3-4, 15. Stub: lifecycle only, no behavior yet.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)

local UIController = {}
UIController.Name = "UIController"

local log = Logger.new(UIController.Name)

function UIController.init()
end

function UIController.start()
	log:info("started (stub)")
end

return UIController
