--!strict
--[[
	CoinService
	Sole authority over player currency: passive drops, money-Brainrot income,
	wave rewards, and coin collection. Validates every coin change server-side.

	Milestone 3. Stub: lifecycle only, no behavior yet.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)

local CoinService = {}
CoinService.Name = "CoinService"

local log = Logger.new(CoinService.Name)

function CoinService.init()
end

function CoinService.start()
	log:info("started (stub)")
end

return CoinService
