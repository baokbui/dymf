--!strict
--[[
	Client Bootstrap
	Entry point for each player's client. Discovers every Controller under
	Controllers/ and runs the same two-phase lifecycle as the server:

		1. init()  — one-time setup for all controllers
		2. start() — begin runtime behavior for all controllers

	Adding a new Controller requires no changes here: drop it under Controllers/.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.Utilities.Logger)

local log = Logger.new("ClientBootstrap")

local controllersFolder = script:WaitForChild("Controllers")

type Controller = {
	Name: string,
	init: (() -> ())?,
	start: (() -> ())?,
}

local controllers: { Controller } = {}

for _, child in controllersFolder:GetChildren() do
	if child:IsA("ModuleScript") then
		local ok, result = pcall(require, child)
		if ok and type(result) == "table" then
			table.insert(controllers, result :: Controller)
		else
			log:warn("failed to require controller", child.Name, result)
		end
	end
end

for _, controller in controllers do
	if controller.init then
		controller.init()
	end
end

for _, controller in controllers do
	if controller.start then
		controller.start()
	end
end

log:info(string.format("online — %d controller(s) started", #controllers))
