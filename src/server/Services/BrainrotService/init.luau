--!strict
--[[
	BrainrotService
	Server-authoritative owner of Brainrot placement, instance lifecycle, and
	per-instance state on a plot. The client only sends placement/removal
	*intent*; this service validates everything and is the source of truth.

	Placement pipeline (PlaceBrainrot), every step server-side:
		1. Validate argument shapes and that the position is in-bounds.
		2. Resolve the definition from the data-driven Brainrots registry
		   (never branch on Brainrot names).
		3. Resolve the caller's owned plot (PlotService).
		4. Reject if that Brainrot id is still recharging (plant cooldown).
		5. Pre-check affordability against the authoritative balance.
		6. Reserve the tile (GridService.tryOccupy) — rejects occupied/unknown.
		7. Charge coins (CoinService.trySpend); release the tile if the charge
		   fails (guards against a balance race between steps 5 and 7).
		8. Build the model, record the instance, start plant cooldown.

	Removal (RemoveBrainrot) verifies the caller owns the Brainrot on the tile,
	frees the tile, and destroys the model. Digging up a Brainrot is NOT
	refunded — the coins spent placing it are lost.

	Milestone 5 (placement, lifecycle, and behavior tick).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Brainrots = require(Shared.Brainrots)
local BrainrotConfig = require(Shared.Config.BrainrotConfig)
local Constants = require(Shared.Constants)
local Remotes = require(Shared.Remotes)
local GridUtil = require(Shared.Utilities.GridUtil)
local WeatherUtil = require(Shared.Utilities.WeatherUtil)
local Logger = require(Shared.Utilities.Logger)
local Types = require(Shared.Types)

local BrainrotModel = require(script.BrainrotModel)
local BrainrotBehavior = require(script.BrainrotBehavior)
local BrainrotFeedback = require(script.BrainrotFeedback)
local Abilities = require(script.Abilities)
local PlotService = require(script.Parent.PlotService)
local GridService = require(script.Parent.GridService)
local CoinService = require(script.Parent.CoinService)
local CombatService = require(script.Parent.CombatService)

local BrainrotService = {}
BrainrotService.Name = "BrainrotService"

local log = Logger.new(BrainrotService.Name)

local BRAINROTS_FOLDER = "Brainrots"

type Placement = BrainrotBehavior.RuntimePlacement

-- instanceId -> placement (single source of runtime placement state).
local placements: { [string]: Placement } = {}
-- userId -> brainrotId -> readyAt (Workspace:GetServerTimeNow)
local plantReadyAt: { [number]: { [string]: number } } = {}
local nextInstanceId = 0

local function nowServer(): number
	return workspace:GetServerTimeNow()
end

local function getPlayerPlantReady(userId: number): { [string]: number }
	local map = plantReadyAt[userId]
	if not map then
		map = {}
		plantReadyAt[userId] = map
	end
	return map
end

local function pruneExpiredCooldowns(map: { [string]: number })
	local now = nowServer()
	for id, readyAt in map do
		if readyAt <= now then
			map[id] = nil
		end
	end
end

local function pushPlantCooldowns(player: Player)
	local map = plantReadyAt[player.UserId]
	if not map then
		Remotes.getEvent("PlantCooldownsUpdated"):FireClient(player, {})
		return
	end
	pruneExpiredCooldowns(map)
	local payload: { [string]: number } = {}
	for id, readyAt in map do
		payload[id] = readyAt
	end
	Remotes.getEvent("PlantCooldownsUpdated"):FireClient(player, payload)
end

local function isPlantOnCooldown(player: Player, brainrotId: string): boolean
	local map = plantReadyAt[player.UserId]
	if not map then
		return false
	end
	local readyAt = map[brainrotId]
	return type(readyAt) == "number" and readyAt > nowServer()
end

local function startPlantCooldown(player: Player, definition: Types.BrainrotDefinition)
	local duration = BrainrotConfig.plantCooldownFor(definition)
	if duration <= 0 then
		return
	end
	local map = getPlayerPlantReady(player.UserId)
	map[definition.id] = nowServer() + duration
	pushPlantCooldowns(player)
end

function BrainrotService.clearPlantCooldowns(player: Player)
	plantReadyAt[player.UserId] = nil
	pushPlantCooldowns(player)
end

-- brainrotId → readyAt server time (only entries still cooling down).
function BrainrotService.getPlantCooldowns(player: Player): { [string]: number }
	local map = plantReadyAt[player.UserId]
	if not map then
		return {}
	end
	pruneExpiredCooldowns(map)
	local payload: { [string]: number } = {}
	for id, readyAt in map do
		payload[id] = readyAt
	end
	return payload
end

-- Coerces untrusted client input into a clean integer grid position, or nil.
local function toGridPosition(raw: unknown): Types.GridPosition?
	if type(raw) ~= "table" then
		return nil
	end
	local row = (raw :: any).row
	local column = (raw :: any).column
	if type(row) ~= "number" or type(column) ~= "number" then
		return nil
	end
	if row ~= math.floor(row) or column ~= math.floor(column) then
		return nil
	end
	local position = { row = row, column = column }
	if not GridUtil.isInBounds(position) then
		return nil
	end
	return position
end

local function brainrotsFolder(plotModel: Model): Folder
	local folder = plotModel:FindFirstChild(BRAINROTS_FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = BRAINROTS_FOLDER
		folder.Parent = plotModel
	end
	return folder :: Folder
end

local function createPlacement(
	instanceId: string,
	definition: Types.BrainrotDefinition,
	ownerUserId: number,
	plotModel: Model,
	position: Types.GridPosition,
	health: number,
	randomizeCooldown: boolean?
): Placement?
	local topCenter = GridService.getWorldPosition(plotModel, position)
	if not topCenter then
		return nil
	end

	local clampedHealth = math.clamp(math.floor(health), 1, definition.health)
	local model = BrainrotModel.create(
		instanceId,
		definition,
		ownerUserId,
		position,
		topCenter,
		brainrotsFolder(plotModel)
	)

	model:SetAttribute("HitsRemaining", clampedHealth)
	model:SetAttribute("Health", math.floor(definition.maxHealth * clampedHealth / definition.health))

	local placement: Placement = {
		instanceId = instanceId,
		brainrotId = definition.id,
		ownerUserId = ownerUserId,
		plotModel = plotModel,
		position = position,
		model = model,
		health = clampedHealth,
		definition = definition,
		-- Multiple units restored together (rejoin / day restore) must not fire
		-- in lockstep — jitter their first cooldown instead of all starting at
		-- the same full `attackInterval` (fresh plants keep the full interval
		-- so the shop's "recharges, then acts" feel stays intact).
		cooldownRemaining = if randomizeCooldown
			then math.random() * definition.attackInterval
			else definition.attackInterval,
		frozenUntil = 0,
		poisonUntil = 0,
		poisonHitsPerTick = 0,
		poisonNextTick = 0,
		poisonTintActive = false,
		burnUntil = 0,
		burnHitsPerTick = 0,
		burnNextTick = 0,
		weakenUntil = 0,
		weakenFactor = 0,
	}

	placements[instanceId] = placement
	BrainrotBehavior.register(placement)
	return placement
end

-- Tears down a placement: destroys the model, frees its tile, drops state.
local function destroyPlacement(placement: Placement)
	BrainrotBehavior.unregister(placement)
	placements[placement.instanceId] = nil
	GridService.release(placement.plotModel, placement.position)
	placement.model:Destroy()
end

-- Unregisters + frees the tile but keeps the model for a fly-over visual.
local function detachPlacement(placement: Placement): Model?
	if placements[placement.instanceId] ~= placement then
		return nil
	end
	BrainrotBehavior.unregister(placement)
	placements[placement.instanceId] = nil
	GridService.release(placement.plotModel, placement.position)
	CollectionService:RemoveTag(placement.model, Constants.TAGS.Brainrot)
	return placement.model
end

local function applyBrainrotDamage(instanceId: string, hits: number): boolean
	local placement = placements[instanceId]
	if not placement then
		return false
	end

	placement.health = math.max(0, placement.health - hits)
	local maxHits = placement.definition.health
	placement.model:SetAttribute("HitsRemaining", placement.health)
	placement.model:SetAttribute(
		"Health",
		math.floor(placement.definition.maxHealth * placement.health / maxHits)
	)

	local isFatal = placement.health <= 0
	-- Server-owned Color replicates (same pattern as MonsterFeedback.flashHit).
	BrainrotFeedback.flashHit(placement.model, isFatal)

	if isFatal then
		destroyPlacement(placement)
		return true
	end
	return false
end

-- ===== Remote handlers (untrusted input) =====

local function notifyPlaceFailed(player: Player, reason: string)
	Remotes.getEvent("PlaceBrainrotFailed"):FireClient(player, reason)
end

local function onPlaceBrainrot(player: Player, brainrotId: unknown, rawPosition: unknown)
	local LevelService = require(script.Parent.LevelService)
	if not LevelService.isLevelActive(player) then
		notifyPlaceFailed(player, "Unable to plant — start the day first")
		return
	end

	if type(brainrotId) ~= "string" then
		return
	end
	local position = toGridPosition(rawPosition)
	if not position then
		return
	end

	local definition = Brainrots.get(brainrotId)
	if not definition then
		return
	end

	local ProgressService = require(script.Parent.ProgressService)
	if not ProgressService.canPlace(player, brainrotId) then
		notifyPlaceFailed(player, "Unable to plant — Brainrot not available")
		return
	end

	if isPlantOnCooldown(player, brainrotId) then
		notifyPlaceFailed(player, "Unable to plant — still recharging")
		return
	end

	local weather = LevelService.getWeather(player)
	if WeatherUtil.isFogPlotColumn(position.column, weather) then
		notifyPlaceFailed(player, "Unable to plant — that tile is covered in fog")
		return
	end

	local plot = PlotService.getPlot(player)
	if not plot then
		return
	end
	local plotModel = plot.model

	-- Affordability pre-check (cheap reject before reserving the tile).
	if CoinService.getBalance(player) < definition.cost then
		notifyPlaceFailed(player, "Unable to plant — not enough coins")
		return
	end

	nextInstanceId += 1
	local instanceId = string.format("Brainrot_%d", nextInstanceId)

	-- Reserve first so two requests can't claim the same tile, then charge.
	if not GridService.tryOccupy(plotModel, position, instanceId) then
		notifyPlaceFailed(player, "Unable to plant — that spot is already taken")
		return
	end
	if not CoinService.trySpend(player, definition.cost) then
		GridService.release(plotModel, position) -- balance changed mid-flight
		notifyPlaceFailed(player, "Unable to plant — not enough coins")
		return
	end

	if not createPlacement(instanceId, definition, player.UserId, plotModel, position, definition.health) then
		-- Should not happen (tile just reserved); roll everything back.
		GridService.release(plotModel, position)
		CoinService.addCoins(player, definition.cost)
		return
	end

	local ProgressService = require(script.Parent.ProgressService)
	local ProgressConfig = require(ReplicatedStorage.Shared.Config.ProgressConfig)
	ProgressService.incrementStat(player, ProgressConfig.STAT_BRAINROTS_PLACED)
	startPlantCooldown(player, definition)
end

local function onRemoveBrainrot(player: Player, rawPosition: unknown)
	local position = toGridPosition(rawPosition)
	if not position then
		return
	end

	local plot = PlotService.getPlot(player)
	if not plot then
		return
	end

	local tile = GridService.getTile(plot.model, position)
	if not tile or not tile.occupied or not tile.brainrotInstanceId then
		return
	end

	local placement = placements[tile.brainrotInstanceId]
	if not placement or placement.ownerUserId ~= player.UserId then
		return -- defensive: only the owner may remove their Brainrot
	end

	-- Digging up a Brainrot frees the tile but is NOT refunded: removal is a
	-- permanent loss of the coins spent placing it.
	destroyPlacement(placement)
end

-- ===== Player lifecycle =====

-- BrainrotService owns Brainrot model lifecycle, so it clears a leaving
-- player's instances itself (PlotService independently resets tile occupancy).
local function onPlayerRemoving(player: Player)
	for _, placement in placements do
		if placement.ownerUserId == player.UserId then
			destroyPlacement(placement)
		end
	end
	plantReadyAt[player.UserId] = nil
end

-- ===== Public API (for other services) =====

-- Read-only list of a plot's current placements (used by combat/save later).
function BrainrotService.getPlacements(plotModel: Model): { Placement }
	local result: { Placement } = {}
	for _, placement in placements do
		if placement.plotModel == plotModel then
			table.insert(result, placement)
		end
	end
	return result
end

function BrainrotService.getPlacement(instanceId: string): Placement?
	return placements[instanceId]
end

function BrainrotService.getSavePlacements(plotModel: Model): { Types.PlantedBrainrot }
	local snapshot: { Types.PlantedBrainrot } = {}
	for _, placement in placements do
		if placement.plotModel == plotModel then
			table.insert(snapshot, {
				instanceId = placement.instanceId,
				brainrotId = placement.brainrotId,
				position = {
					row = placement.position.row,
					column = placement.position.column,
				},
				health = placement.health,
			})
		end
	end
	return snapshot
end

function BrainrotService.restorePlacements(player: Player, brainrots: { Types.PlantedBrainrot })
	local plot = PlotService.getPlot(player)
	if not plot then
		return
	end

	for _, saved in brainrots do
		if type(saved) ~= "table" then
			continue
		end

		local position = toGridPosition(saved.position)
		if not position then
			continue
		end

		local definition = Brainrots.get(saved.brainrotId)
		if not definition then
			continue
		end

		local instanceId = if type(saved.instanceId) == "string" and saved.instanceId ~= ""
			then saved.instanceId
			else string.format("Brainrot_%d", nextInstanceId + 1)
		local health = if type(saved.health) == "number" then saved.health else definition.health
		if health <= 0 then
			continue
		end

		local numericSuffix = string.match(instanceId, "^Brainrot_(%d+)$")
		if numericSuffix then
			nextInstanceId = math.max(nextInstanceId, tonumber(numericSuffix) :: number)
		else
			nextInstanceId += 1
		end

		if not GridService.tryOccupy(plot.model, position, instanceId) then
			continue
		end

		if not createPlacement(instanceId, definition, player.UserId, plot.model, position, health, true) then
			GridService.release(plot.model, position)
		end
	end
end

-- Removes every Brainrot on a plot and frees its tiles (level end / reset).
function BrainrotService.clearPlot(plotModel: Model)
	local toRemove: { Placement } = {}
	for _, placement in placements do
		if placement.plotModel == plotModel then
			table.insert(toRemove, placement)
		end
	end
	for _, placement in toRemove do
		destroyPlacement(placement)
	end

	local lineBomb = Abilities.get("LineBomb")
	if lineBomb and (lineBomb :: any).clearPlot then
		(lineBomb :: any).clearPlot(plotModel)
	end
end

-- Remove Brainrots standing on NightFog-blocked lawn columns (east fog zone).
function BrainrotService.clearFogBlockedPlacements(player: Player, weather: string?)
	if not WeatherUtil.isNightFog(weather) then
		return
	end
	local plot = PlotService.getPlot(player)
	if not plot then
		return
	end
	local toRemove: { Placement } = {}
	for _, placement in placements do
		if placement.plotModel == plot.model
			and WeatherUtil.isFogPlotColumn(placement.position.column, weather)
		then
			table.insert(toRemove, placement)
		end
	end
	for _, placement in toRemove do
		destroyPlacement(placement)
	end
end

local function applyBrainrotStatus(
	instanceId: string,
	kind: Types.StatusEffectKind,
	duration: number,
	magnitude: number?
)
	local placement = placements[instanceId]
	if not placement then
		return
	end

	local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
	local now = os.clock()
	if kind == "Stun" or kind == "Freeze" then
		placement.frozenUntil = math.max(placement.frozenUntil, now + duration)
		-- Cartoon dizzy stars for the remaining stun/freeze window (Queen Spider,
		-- Duke Vampire Terrify, …).
		local remain = placement.frozenUntil - now
		if remain > 0 then
			CombatService.notifyDizzy(placement.ownerUserId, instanceId, remain)
		end
		return
	end

	if kind == "Weaken" then
		local percent = math.clamp(magnitude or 10, 0, 100)
		placement.weakenUntil = math.max(placement.weakenUntil, now + duration)
		placement.weakenFactor = percent / 100
		return
	end

	if kind == "Poison" or kind == "Burn" then
		local percent = magnitude or 2
		local tickDamage = math.max(1, math.ceil(placement.definition.maxHealth * percent / 100))
		local hitsPerTick = math.max(
			1,
			math.ceil(tickDamage / (placement.definition.maxHealth / placement.definition.health))
		)
		if kind == "Poison" then
			placement.poisonUntil = math.max(placement.poisonUntil, now + duration)
			placement.poisonHitsPerTick = hitsPerTick
			placement.poisonNextTick = now + CombatConfig.POISON_TICK_INTERVAL
			placement.poisonTintActive = true
			BrainrotFeedback.setPoisoned(placement.model, true)
			local remain = placement.poisonUntil - now
			if remain > 0 then
				CombatService.notifyPoison(placement.ownerUserId, instanceId, remain)
			end
		else
			placement.burnUntil = math.max(placement.burnUntil, now + duration)
			placement.burnHitsPerTick = hitsPerTick
			placement.burnNextTick = now + CombatConfig.BURN_TICK_INTERVAL
		end
	end
end

function BrainrotService.init()
	BrainrotBehavior.setDestroyHandler(destroyPlacement)
	BrainrotBehavior.setDetachHandler(detachPlacement)
	CombatService.setBrainrotDamageHandler(applyBrainrotDamage)
	CombatService.setBrainrotStatusHandler(applyBrainrotStatus)
end

function BrainrotService.start()
	Remotes.getEvent("PlaceBrainrot").OnServerEvent:Connect(onPlaceBrainrot)
	Remotes.getEvent("RemoveBrainrot").OnServerEvent:Connect(onRemoveBrainrot)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	BrainrotBehavior.start()

	log:info("started")
end

return BrainrotService
