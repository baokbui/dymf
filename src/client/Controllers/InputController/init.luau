--!strict
--[[
	InputController
	Centralizes raw input (mouse/touch/keyboard) and exposes intent to other
	controllers, so input handling is not duplicated across the client.

	Milestone 4. Stub: lifecycle only, no behavior yet.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)

local InputController = {}
InputController.Name = "InputController"

local log = Logger.new(InputController.Name)

function InputController.init()
end

function InputController.start()
	log:info("started (stub)")
end

return InputController
