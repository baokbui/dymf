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
local PlotConfig = require(Shared.Config.PlotConfig)
local Remotes = require(Shared.Remotes)
local Logger = require(Shared.Utilities.Logger)

local GroundCoin = require(script.GroundCoin)
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

local function fireBalance(player: Player)
	Remotes.getEvent("CoinsUpdated"):FireClient(player, balances[player.UserId] or 0)
end

-- ===== Public API (used by other services) =====

function CoinService.getBalance(player: Player): number
	return balances[player.UserId] or 0
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

-- ===== Ground coins =====

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

-- Spawns one collectible coin somewhere on the player's play area.
local function dropCoin(player: Player)
	local plot = PlotService.getPlot(player)
	if not plot then
		return
	end

	local spawner = plot.base:FindFirstChild("CoinSpawner")
	if not spawner or not spawner:IsA("Attachment") then
		return
	end

	-- Random point within the grid footprint (kept slightly inside the edges).
	local origin = spawner.WorldPosition
	local spreadX = (PlotConfig.GRID_WIDTH / 2) * 0.85
	local spreadZ = (PlotConfig.GRID_DEPTH / 2) * 0.85
	local offsetX = (math.random() * 2 - 1) * spreadX
	local offsetZ = (math.random() * 2 - 1) * spreadZ
	local position = origin + Vector3.new(offsetX, 0, offsetZ)

	nextCoinId += 1
	local coinId = string.format("Coin_%d", nextCoinId)
	local part = GroundCoin.create(
		coinId,
		player.UserId,
		EconomyConfig.PASSIVE_DROP_AMOUNT,
		position,
		coinsFolder(plot.model)
	)

	groundCoins[coinId] = {
		part = part,
		ownerUserId = player.UserId,
		value = EconomyConfig.PASSIVE_DROP_AMOUNT,
	}

	-- Despawn if left uncollected.
	task.delay(EconomyConfig.GROUND_COIN_LIFETIME, function()
		removeCoin(coinId)
	end)
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
	-- Answer the initial state pull so a freshly loaded client gets its balance
	-- without racing the join-time CoinsUpdated push.
	Remotes.getFunction("RequestState").OnServerInvoke = function(player: Player)
		return { coins = CoinService.getBalance(player) }
	end
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
