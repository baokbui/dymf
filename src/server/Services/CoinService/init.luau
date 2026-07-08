--!strict
--[[
	CoinService
	Sole authority over player currency. Holds each player's balance, grants
	passive drops as collectible ground coins, validates collection requests, and
	pushes balances to clients via CoinsUpdated. Other services credit/charge
	coins through this module's API (never by touching balances directly).

	Server authority: the client only sends a CollectCoin *intent* for a coin id;
	this service re-checks ownership, existence, and distance (against the
	authoritative character position) before crediting. Balances are never set
	from client input.

	Persistence (balance) arrives with SaveService in a later milestone; for now
	each player starts at EconomyConfig.STARTING_COINS.

	Milestone 3.
]]

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local EconomyConfig = require(Shared.Config.EconomyConfig)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Logger = require(Shared.Utilities.Logger)
local GridUtil = require(Shared.Utilities.GridUtil)

local GroundCoin = require(script.GroundCoin)
local GridService = require(script.Parent.GridService)
local PlotService = require(script.Parent.PlotService)

local CoinService = {}
CoinService.Name = "CoinService"

local log = Logger.new(CoinService.Name)

type GroundCoinEntry = {
	part: BasePart,
	ownerUserId: number,
	value: number,
}

local balances: { [number]: number } = {}
local groundCoins: { [string]: GroundCoinEntry } = {}
local nextCoinId = 0

local COIN_Y_OFFSET = 1.5

local function fireBalance(player: Player)
	Remotes.getEvent("CoinsUpdated"):FireClient(player, balances[player.UserId] or 0)
end

local function coinsFolder(plotModel: Model): Folder
	local folder = plotModel:FindFirstChild("Coins")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Coins"
		folder.Parent = plotModel
	end
	return folder :: Folder
end

local function removeCoin(coinId: string)
	local entry = groundCoins[coinId]
	if not entry then
		return
	end
	groundCoins[coinId] = nil
	entry.part:Destroy()
end

local function spawnGroundCoin(plotModel: Model, ownerUserId: number, topCenter: Vector3, value: number)
	nextCoinId += 1
	local coinId = string.format("Coin_%d", nextCoinId)
	local part = GroundCoin.create(
		coinId,
		ownerUserId,
		value,
		topCenter + Vector3.new(0, COIN_Y_OFFSET, 0),
		coinsFolder(plotModel)
	)

	groundCoins[coinId] = {
		part = part,
		ownerUserId = ownerUserId,
		value = value,
	}

	task.delay(EconomyConfig.GROUND_COIN_LIFETIME, function()
		removeCoin(coinId)
	end)
end

-- ===== Public API (used by other services) =====

function CoinService.getBalance(player: Player): number
	return balances[player.UserId] or 0
end

-- Sets an authoritative balance (used by SaveService restore).
function CoinService.setBalance(player: Player, amount: number)
	balances[player.UserId] = math.max(0, math.floor(amount))
	fireBalance(player)
end

-- Credits coins and notifies the client. Use for rewards/income.
function CoinService.addCoins(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	balances[player.UserId] = (balances[player.UserId] or 0) + amount
	fireBalance(player)
end

-- Attempts to spend coins. Returns false (and changes nothing) if the player
-- cannot afford it. Used by placement in later milestones.
function CoinService.trySpend(player: Player, amount: number): boolean
	local current = balances[player.UserId] or 0
	if amount < 0 or current < amount then
		return false
	end
	balances[player.UserId] = current - amount
	fireBalance(player)
	return true
end

-- Resets a player's balance to the campaign starting amount (e.g. after clearing
-- a level). Pushes CoinsUpdated.
function CoinService.resetBalance(player: Player)
	balances[player.UserId] = EconomyConfig.STARTING_COINS
	fireBalance(player)
end

-- Removes all uncollected ground coins on a plot.
function CoinService.clearPlot(plotModel: Model)
	local toRemove: { string } = {}
	for coinId, entry in groundCoins do
		if entry.part:IsDescendantOf(plotModel) then
			table.insert(toRemove, coinId)
		end
	end
	for _, coinId in toRemove do
		removeCoin(coinId)
	end
end

-- Spawns a collectible ground coin on a grid tile for a player (e.g. Brainrot
-- coin generation). Server-authoritative value; always resolves via GridService.
function CoinService.dropCoinForOwner(
	ownerUserId: number,
	gridPosition: Types.GridPosition,
	value: number
)
	if value <= 0 or not GridUtil.isInBounds(gridPosition) then
		return
	end

	local player = Players:GetPlayerByUserId(ownerUserId)
	if not player then
		return
	end

	local LevelService = require(script.Parent.LevelService)
	if not LevelService.isLevelActive(player) then
		return
	end

	local plot = PlotService.getPlot(player)
	if not plot then
		return
	end

	local topCenter = GridService.getWorldPosition(plot.model, gridPosition)
	if not topCenter then
		return
	end

	spawnGroundCoin(plot.model, ownerUserId, topCenter, value)
end

-- Spawns a coin on a random grid tile within the owner's plot.
function CoinService.dropRandomCoinForOwner(ownerUserId: number, value: number)
	if value <= 0 then
		return
	end

	local player = Players:GetPlayerByUserId(ownerUserId)
	if not player then
		return
	end

	local LevelService = require(script.Parent.LevelService)
	if not LevelService.isLevelActive(player) then
		return
	end

	local plot = PlotService.getPlot(player)
	if not plot then
		return
	end

	local topCenter = GridService.getRandomWorldPosition(plot.model)
	if not topCenter then
		return
	end

	spawnGroundCoin(plot.model, ownerUserId, topCenter, value)
end

-- Spawns one collectible coin on a random grid tile within the player's plot.
local function dropCoin(player: Player)
	local LevelService = require(script.Parent.LevelService)
	if not LevelService.isLevelActive(player) then
		return
	end

	local plot = PlotService.getPlot(player)
	if not plot then
		return
	end

	local topCenter = GridService.getRandomWorldPosition(plot.model)
	if not topCenter then
		return
	end

	spawnGroundCoin(plot.model, player.UserId, topCenter, EconomyConfig.PASSIVE_DROP_AMOUNT)
end

-- Validates a client collection intent before crediting. Untrusted input.
local function onCollectCoin(player: Player, coinId: unknown)
	if type(coinId) ~= "string" then
		return
	end

	local entry = groundCoins[coinId]
	if not entry then
		return -- already collected / despawned / never existed
	end
	if entry.ownerUserId ~= player.UserId then
		return -- not this player's coin
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	if (root.Position - entry.part.Position).Magnitude > EconomyConfig.COIN_COLLECT_RADIUS then
		return -- too far from the coin
	end

	removeCoin(coinId)
	CoinService.addCoins(player, entry.value)
end

-- ===== Player lifecycle =====

local function onPlayerAdded(player: Player)
	balances[player.UserId] = EconomyConfig.STARTING_COINS
	fireBalance(player)
end

local function onPlayerRemoving(player: Player)
	for coinId, entry in groundCoins do
		if entry.ownerUserId == player.UserId then
			removeCoin(coinId)
		end
	end
	balances[player.UserId] = nil
end

function CoinService.init()
end

function CoinService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Remotes.getEvent("CollectCoin").OnServerEvent:Connect(onCollectCoin)

	-- Passive drops: one coin per active player every interval.
	task.spawn(function()
		while true do
			task.wait(EconomyConfig.PASSIVE_DROP_INTERVAL)
			for _, player in Players:GetPlayers() do
				dropCoin(player)
			end
		end
	end)

	log:info("started")
end

return CoinService
