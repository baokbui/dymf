--!strict
local BattleClock = require(game:GetService("ReplicatedStorage").Shared.Utilities.BattleClock)
--[[
	MagnetService
	Server-owned magnet ability. Client sends ActivateMagnet; this service
	validates cooldown / plot / active day, then ticks CoinService pulls.
	Cooldown pauses when the day ends and resumes on Start Day.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local MagnetConfig = require(Shared.Config.MagnetConfig)
local Remotes = require(Shared.Remotes)
local Logger = require(Shared.Utilities.Logger)

local MagnetService = {}
MagnetService.Name = "MagnetService"

local log = Logger.new(MagnetService.Name)

type Runtime = {
	activeUntil: number,
	readyAt: number,
	-- Remaining cooldown seconds while the day is over. 0 = not paused.
	pausedRemaining: number,
}

local runtimes: { [number]: Runtime } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function getRuntime(userId: number): Runtime
	local runtime = runtimes[userId]
	if runtime then
		return runtime
	end
	runtime = {
		activeUntil = 0,
		readyAt = 0,
		pausedRemaining = 0,
	}
	runtimes[userId] = runtime
	return runtime
end

local function payload(player: Player, runtime: Runtime): { [string]: number }
	local ProgressService = require(script.Parent.ProgressService)
	return {
		level = ProgressService.getMagnetLevel(player),
		activeUntil = runtime.activeUntil,
		readyAt = runtime.readyAt,
		pausedRemaining = runtime.pausedRemaining,
	}
end

local function broadcast(player: Player)
	local runtime = getRuntime(player.UserId)
	Remotes.getEvent("MagnetStateChanged"):FireClient(player, payload(player, runtime))
end

function MagnetService.getClientState(player: Player): { [string]: number }
	return payload(player, getRuntime(player.UserId))
end

local function onActivate(player: Player)
	local LevelService = require(script.Parent.LevelService)
	if not LevelService.isLevelActive(player) or LevelService.isChallengeActiveForUser(player.UserId) then
		return
	end

	local PlotService = require(script.Parent.PlotService)
	if not PlotService.getPlotModel(player) then
		return
	end

	local clock = now()
	local runtime = getRuntime(player.UserId)
	if runtime.pausedRemaining > 0 then
		return
	end
	if clock < runtime.activeUntil or clock < runtime.readyAt then
		return
	end

	local ProgressService = require(script.Parent.ProgressService)
	local level = ProgressService.getMagnetLevel(player)
	local cooldown = MagnetConfig.cooldownFor(level)
	runtime.activeUntil = clock + MagnetConfig.DURATION
	runtime.readyAt = runtime.activeUntil + cooldown
	broadcast(player)
end

local function tickPlayer(player: Player, runtime: Runtime)
	if BattleClock.isPaused(player) then return end
	if runtime.pausedRemaining > 0 then
		return
	end
	local clock = now()
	if clock >= runtime.activeUntil then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local PlotService = require(script.Parent.PlotService)
	local plotModel = PlotService.getPlotModel(player)
	if not plotModel then
		return
	end

	local GridService = require(script.Parent.GridService)
	local origin = GridService.worldToGrid(plotModel, root.Position)
	if not origin then
		return
	end

	local ProgressService = require(script.Parent.ProgressService)
	local CoinService = require(script.Parent.CoinService)
	local rangeTiles = MagnetConfig.rangeTilesFor(ProgressService.getMagnetLevel(player))
	CoinService.pullCoinsInRange(player, root.Position, rangeTiles)
end

function MagnetService.pauseCooldown(player: Player)
	local runtime = getRuntime(player.UserId)
	if runtime.pausedRemaining > 0 then
		return
	end
	local clock = now()
	if clock < runtime.activeUntil then
		-- Day ended mid-pull: drop the active window, keep the post-use cooldown.
		runtime.pausedRemaining = math.max(0, runtime.readyAt - runtime.activeUntil)
	elseif clock < runtime.readyAt then
		runtime.pausedRemaining = runtime.readyAt - clock
	else
		return
	end
	runtime.activeUntil = 0
	runtime.readyAt = 0
	broadcast(player)
end

function MagnetService.resumeCooldown(player: Player)
	local runtime = getRuntime(player.UserId)
	if runtime.pausedRemaining <= 0 then
		return
	end
	runtime.readyAt = now() + runtime.pausedRemaining
	runtime.pausedRemaining = 0
	broadcast(player)
end

function MagnetService.resumeDayTimers(player: Player, duration: number)
	local runtime = getRuntime(player.UserId)
	if runtime.activeUntil > 0 then runtime.activeUntil += duration end
	if runtime.readyAt > 0 then runtime.readyAt += duration end
	broadcast(player)
end

function MagnetService.init()
end

function MagnetService.start()
	Remotes.getEvent("ActivateMagnet").OnServerEvent:Connect(function(player, ...) if not BattleClock.isPaused(player) then onActivate(player, ...) end end)
	Players.PlayerRemoving:Connect(function(player)
		runtimes[player.UserId] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(MagnetConfig.TICK)
			for _, player in Players:GetPlayers() do
				local runtime = runtimes[player.UserId]
				if runtime then
					tickPlayer(player, runtime)
				end
			end
		end
	end)

	log:info("started")
end

return MagnetService
