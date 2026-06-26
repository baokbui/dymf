--!strict
--[[
	WaveService
	The ONLY system that advances waves. Owns preparation, countdown, wave
	start, enemy spawn orchestration, wave completion, rewards, and difficulty
	scaling. Drives EnemyService to spawn; grants rewards via CoinService.

	Milestone 8. Stub: lifecycle only, no behavior yet.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)

local WaveService = {}
WaveService.Name = "WaveService"

local log = Logger.new(WaveService.Name)

function WaveService.init()
end

function WaveService.start()
	log:info("started (stub)")
end

return WaveService
