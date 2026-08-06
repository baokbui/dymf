--!strict
--[[
	Server Bootstrap
	Entry point for the server. Discovers every Service under Services/, then
	runs a two-phase lifecycle so cross-service references are safe:

		1. init()  — one-time setup for all services
		2. start() — begin runtime behavior for all services

	Adding a new Service requires no changes here: drop it under Services/.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Logger = require(Shared.Utilities.Logger)

local log = Logger.new("ServerBootstrap")

-- Studio soft-reload can re-run this Script while old tick loops still live.
-- Bail so we don't double-connect remotes / double-spawn bosses.
if _G.__BVM_SERVER_BOOTSTRAPPED then
	log:warn("duplicate server bootstrap ignored (soft-reload?)")
	return
end
_G.__BVM_SERVER_BOOTSTRAPPED = true

-- Create all network remotes before any client can request them.
Remotes.initServer()

local servicesFolder = script:WaitForChild("Services")

type Service = {
	Name: string,
	init: (() -> ())?,
	start: (() -> ())?,
}

local services: { Service } = {}

for _, child in servicesFolder:GetChildren() do
	if child:IsA("ModuleScript") then
		local ok, result = pcall(require, child)
		if ok and type(result) == "table" then
			table.insert(services, result :: Service)
		else
			log:warn("failed to require service", child.Name, result)
		end
	end
end

for _, service in services do
	if service.init then
		service.init()
	end
end

for _, service in services do
	if service.start then
		service.start()
	end
end

log:info(string.format("online — %d service(s) started", #services))
