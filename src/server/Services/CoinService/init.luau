--!strict
--[[
	CoinService
	Sole authority over player currency. Holds each player's balance, grants
	passive drops as collectible ground coins, validates collection requests, and
	pushes balances to clients via CoinsUpdated. Other services credit/charge
	coins through this module's API (never by touching balances directly).

	Drop motions:
	- Passive: rain slowly from the sky onto a random grid tile.
	- Producers (Ballerina): spit from the unit onto a random grid tile.

	Server authority: the client only sends a CollectCoin *intent* for a coin id;
	this service re-checks ownership, existence, distance, and Landed before
	crediting. Walking only collects landed coins. Magnet pulls
	(`pullCoinsInRange`) also catch coins still raining or mid-spit when they
	are within the player's level-scaled Chebyshev range. Balances are never set from client input.

	Milestone 3.
]]

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local EconomyConfig = require(Shared.Config.EconomyConfig)
local PlotConfig = require(Shared.Config.PlotConfig)
local DevConfig = require(Shared.Config.DevConfig)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Logger = require(Shared.Utilities.Logger)
local GridUtil = require(Shared.Utilities.GridUtil)
local WeatherUtil = require(Shared.Utilities.WeatherUtil)

local CoinMotion = require(script.CoinMotion)
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
	gridPosition: Types.GridPosition,
	pulling: boolean,
}

export type DropStyle = "Rain" | "Spit"

local balances: { [number]: number } = {}
local groundCoins: { [string]: GroundCoinEntry } = {}
local nextCoinId = 0

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

local function spawnGroundCoin(
	plotModel: Model,
	ownerUserId: number,
	gridPosition: Types.GridPosition,
	landTopCenter: Vector3,
	value: number,
	style: DropStyle,
	spitFrom: Vector3?
)
	nextCoinId += 1
	local coinId = string.format("Coin_%d", nextCoinId)
	local landPosition = landTopCenter + Vector3.new(0, GroundCoin.LAND_Y_OFFSET, 0)

	-- Spawn at the final tile first; CoinMotion repositions for the animation.
	local part = GroundCoin.create(coinId, ownerUserId, value, landPosition, coinsFolder(plotModel))
	part.CanTouch = false
	part:SetAttribute("Landed", false)

	groundCoins[coinId] = {
		part = part,
		ownerUserId = ownerUserId,
		value = value,
		gridPosition = gridPosition,
		pulling = false,
	}

	if style == "Spit" and spitFrom then
		CoinMotion.spitFromOrigin(part, spitFrom, landPosition)
	else
		CoinMotion.rainFromSky(part, landPosition)
	end

	task.delay(EconomyConfig.GROUND_COIN_LIFETIME, function()
		removeCoin(coinId)
	end)
end

local function resolveActivePlot(ownerUserId: number): (Player?, Model?)
	local player = Players:GetPlayerByUserId(ownerUserId)
	if not player then
		return nil, nil
	end

	local LevelService = require(script.Parent.LevelService)
	if not LevelService.isLevelActive(player) then
		return nil, nil
	end

	local plot = PlotService.getPlot(player)
	if not plot then
		return nil, nil
	end

	return player, plot.model
end

-- ===== Public API (used by other services) =====

function CoinService.getBalance(player: Player): number
	return balances[player.UserId] or 0
end

function CoinService.setBalance(player: Player, amount: number)
	balances[player.UserId] = math.max(0, math.floor(amount))
	fireBalance(player)
end

function CoinService.addCoins(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	balances[player.UserId] = (balances[player.UserId] or 0) + amount
	fireBalance(player)
end

function CoinService.trySpend(player: Player, amount: number): boolean
	local current = balances[player.UserId] or 0
	if amount < 0 or current < amount then
		return false
	end
	balances[player.UserId] = current - amount
	fireBalance(player)
	return true
end

function CoinService.resetBalance(player: Player)
	balances[player.UserId] = EconomyConfig.STARTING_COINS
	fireBalance(player)
end

-- Day 1 opens with STARTING_COINS; later days start the purse at 0 (earn in-match).
function CoinService.applyDayPurse(player: Player, levelNumber: number)
	local amount = if levelNumber <= 1 then EconomyConfig.STARTING_COINS else 0
	CoinService.setBalance(player, amount)
	if DevConfig.isActive() then
		CoinService.setBalance(player, DevConfig.COINS)
	end
end

-- Game Over → Rewind: retry the failed day with a fixed purse.
function CoinService.applyRewindPurse(player: Player)
	CoinService.setBalance(player, EconomyConfig.REWIND_COINS)
	if DevConfig.isActive() then
		CoinService.setBalance(player, DevConfig.COINS)
	end
end

-- TEMP Studio cheat: force the playtest purse (see DevConfig).
function CoinService.applyDevPurse(player: Player)
	if not DevConfig.isActive() then
		return
	end
	CoinService.setBalance(player, DevConfig.COINS)
end

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

-- Spawns a collectible ground coin on a specific grid tile (instant land).
local function weatherForOwner(ownerUserId: number): string?
	local player = Players:GetPlayerByUserId(ownerUserId)
	if not player then
		return nil
	end
	local LevelService = require(script.Parent.LevelService)
	return LevelService.getWeather(player)
end

function CoinService.dropCoinForOwner(
	ownerUserId: number,
	gridPosition: Types.GridPosition,
	value: number
)
	if value <= 0 or not GridUtil.isInBounds(gridPosition) then
		return
	end
	if WeatherUtil.isFogPlotColumn(gridPosition.column, weatherForOwner(ownerUserId)) then
		return
	end

	local _, plotModel = resolveActivePlot(ownerUserId)
	if not plotModel then
		return
	end

	local topCenter = GridService.getWorldPosition(plotModel, gridPosition)
	if not topCenter then
		return
	end

	spawnGroundCoin(plotModel, ownerUserId, gridPosition, topCenter, value, "Rain", nil)
end

--[[
	Spawns a coin on a random grid tile.
	- Without `spitFrom`: passive-style rain from the sky.
	- With `spitFrom`: producer spit arc from that world position.
	NightFog days skip fog-blocked east columns (coins land on clear lawn only).
]]
function CoinService.dropRandomCoinForOwner(ownerUserId: number, value: number, spitFrom: Vector3?): boolean
	if value <= 0 then
		return false
	end

	local _, plotModel = resolveActivePlot(ownerUserId)
	if not plotModel then
		return false
	end

	local position = WeatherUtil.randomClearPlotPosition(weatherForOwner(ownerUserId))
	local topCenter = GridService.getWorldPosition(plotModel, position)
	if not topCenter then
		return false
	end

	if spitFrom then
		spawnGroundCoin(plotModel, ownerUserId, position, topCenter, value, "Spit", spitFrom)
	else
		spawnGroundCoin(plotModel, ownerUserId, position, topCenter, value, "Rain", nil)
	end
	return true
end

local function dropPassiveCoin(player: Player)
	CoinService.dropRandomCoinForOwner(player.UserId, EconomyConfig.PASSIVE_DROP_AMOUNT)
end

local function creditCoin(player: Player, coinId: string)
	local entry = groundCoins[coinId]
	if not entry then
		return
	end
	entry.part:SetAttribute("Collected", true)
	local value = entry.value
	removeCoin(coinId)
	CoinService.addCoins(player, value)
end

local function onCollectCoin(player: Player, coinId: unknown)
	if type(coinId) ~= "string" then
		return
	end

	local entry = groundCoins[coinId]
	if not entry then
		return
	end
	if entry.ownerUserId ~= player.UserId then
		return
	end
	if entry.pulling then
		return
	end
	if entry.part:GetAttribute("Landed") ~= true then
		return -- still falling / mid-spit
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	if (root.Position - entry.part.Position).Magnitude > EconomyConfig.COIN_COLLECT_RADIUS then
		return
	end

	creditCoin(player, coinId)
end

-- World-space Chebyshev from the player, in tiles (`rangeTiles`).
-- Level 1 reaches a bit past the adjacent ring; max level reaches 2 tiles.
function CoinService.pullCoinsInRange(player: Player, originWorld: Vector3, rangeTiles: number)
	local MagnetConfig = require(ReplicatedStorage.Shared.Config.MagnetConfig)
	local range = math.max(0, rangeTiles)
	local rangeStuds = range * PlotConfig.TILE_SIZE
	for coinId, entry in groundCoins do
		if entry.ownerUserId ~= player.UserId then
			continue
		end
		if entry.pulling then
			continue
		end
		local delta = entry.part.Position - originWorld
		if math.max(math.abs(delta.X), math.abs(delta.Z)) > rangeStuds then
			continue
		end

		entry.pulling = true
		local part = entry.part
		CoinMotion.pullToward(part, function()
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				return root.Position
			end
			return nil
		end, MagnetConfig.PULL_DURATION, function()
			if groundCoins[coinId] ~= entry then
				return
			end
			creditCoin(player, coinId)
		end)
	end
end

local function onPlayerAdded(player: Player)
	-- SaveService.hydrateProgression owns the match purse via applyDayPurse
	-- (Day 1 → STARTING_COINS, later days → 0). Never default to STARTING_COINS
	-- here — service start / PlayerAdded order is not guaranteed, so this
	-- handler can run *after* hydrate and incorrectly grant 125 on rejoin.
	if balances[player.UserId] == nil then
		balances[player.UserId] = 0
		fireBalance(player)
	end
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

	task.spawn(function()
		while true do
			task.wait(EconomyConfig.PASSIVE_DROP_INTERVAL)
			for _, player in Players:GetPlayers() do
				dropPassiveCoin(player)
			end
		end
	end)

	log:info("started")
end

return CoinService
