--!strict
-- Temporary challenge state never enters the campaign save snapshot.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.DailyChallengeConfig)
local Types = require(Shared.Types)
local Services = script.Parent.Parent
local BrainrotService = require(Services.BrainrotService)
local CoinService = require(Services.CoinService)

export type Run = {
	health: number,
	coins: number,
	lawn: { Types.PlantedBrainrot },
	settling: boolean,
}

local ChallengeRun = {}

function ChallengeRun.begin(player: Player, plot: Model): Run
	local run = {
		health = Config.HEARTS,
		coins = CoinService.getBalance(player),
		lawn = BrainrotService.getSavePlacements(plot),
		settling = false,
	}
	BrainrotService.clearPlot(plot)
	CoinService.setBalance(player, Config.STARTING_COINS)
	return run
end

function ChallengeRun.restore(player: Player, plot: Model, run: Run)
	require(Services.CombatService).clearPlot(plot)
	BrainrotService.clearPlot(plot)
	BrainrotService.clearPlantCooldowns(player)
	BrainrotService.restorePlacements(player, run.lawn)
	CoinService.setBalance(player, run.coins)
end

return ChallengeRun
