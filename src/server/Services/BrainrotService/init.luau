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
		5. Reject if `maxOnPlot` is set and that many of this id are already
		   living on the plot.
		6. Pre-check affordability against the authoritative balance.
		7. Reserve the tile (GridService.tryOccupy) — rejects occupied/unknown.
		8. Charge coins (CoinService.trySpend); release the tile if the charge
		   fails (guards against a balance race between steps 6 and 8).
		9. Build the model, record the instance, start plant cooldown.

	Removal (RemoveBrainrot) verifies the caller owns the Brainrot on the tile,
	frees the tile, and destroys the model. Digging up a Brainrot is NOT
	refunded — the coins spent placing it are lost.

	Milestone 5 (placement, lifecycle, and behavior tick).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Brainrots = require(Shared.Brainrots)
local Evolutions = require(Shared.Evolutions)
local BrainrotConfig = require(Shared.Config.BrainrotConfig)
local EvolutionConfig = require(Shared.Config.EvolutionConfig)
local Constants = require(Shared.Constants)
local Remotes = require(Shared.Remotes)
local GridUtil = require(Shared.Utilities.GridUtil)
local PlantCost = require(Shared.Utilities.PlantCost)
local WeatherUtil = require(Shared.Utilities.WeatherUtil)
local Logger = require(Shared.Utilities.Logger)
local Types = require(Shared.Types)

local BrainrotModel = require(script.BrainrotModel)
local BrainrotBehavior = require(script.BrainrotBehavior)
local BrainrotAnimation = require(script.BrainrotAnimation)
local BrainrotFeedback = require(script.BrainrotFeedback)
local Abilities = require(script.Abilities)
local FogRows = require(script.FogRows)
local PlotService = require(script.Parent.PlotService)
local GridService = require(script.Parent.GridService)
local CoinService = require(script.Parent.CoinService)
local CombatService = require(script.Parent.CombatService)
local GraveService = require(script.Parent.GraveService)

local BrainrotService = {}
BrainrotService.Name = "BrainrotService"

local log = Logger.new(BrainrotService.Name)

local BRAINROTS_FOLDER = "Brainrots"

type Placement = BrainrotBehavior.RuntimePlacement

-- instanceId -> placement (single source of runtime placement state).
local placements: { [string]: Placement } = {}
-- In-flight PlaceBrainrot reservations so two clicks cannot exceed maxOnPlot.
local pendingPlotCaps: { [Model]: { [string]: number } } = {}
-- Plot-wide Golden Discount: next grant allowed at this os.clock().
local plantDiscountReadyAt: { [Model]: number } = {}
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

local function claimedForOwner(userId: number, brainrotId: string): { string }
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return {}
	end
	local ProgressService = require(script.Parent.ProgressService)
	return ProgressService.getClaimedEvolutions(player, brainrotId)
end

local function evolvedDefinition(userId: number, definition: Types.BrainrotDefinition): Types.BrainrotDefinition
	return Evolutions.applyStats(definition, claimedForOwner(userId, definition.id))
end

local function applyEvolutionAura(model: Model, userId: number, brainrotId: string)
	local rarity = Evolutions.highestClaimedRarity(claimedForOwner(userId, brainrotId))
	if not rarity then
		BrainrotFeedback.clearAura(model)
		return
	end
	BrainrotFeedback.applyAura(
		model,
		EvolutionConfig.worldAura(rarity),
		EvolutionConfig.BRAINROT_AURA_SCALE,
		EvolutionConfig.isRainbow(rarity)
	)
end

local function applyNameplateAttributes(placement: Placement)
	local player = Players:GetPlayerByUserId(placement.ownerUserId)
	local rarity = Evolutions.highestClaimedRarity(claimedForOwner(placement.ownerUserId, placement.brainrotId))
		or "Common"
	local level = 1
	if player then
		local ProgressService = require(script.Parent.ProgressService)
		level = ProgressService.getBrainrotLevel(player, placement.brainrotId)
	end
	placement.model:SetAttribute("EvolutionRarity", rarity)
	placement.model:SetAttribute("BrainrotLevel", level)
end

local function syncHealthDisplay(placement: Placement)
	local definition = placement.definition
	local maxHits = definition.health
	local shield = math.floor(placement.buffs.shieldHp)
	placement.model:SetAttribute("HitsRemaining", placement.health)
	local body = 0
	if maxHits > 0 then
		body = math.floor(definition.maxHealth * placement.health / maxHits)
	end
	placement.model:SetAttribute("Health", body)
	placement.model:SetAttribute("MaxHealth", definition.maxHealth)
	placement.model:SetAttribute("ShieldHp", shield)
	BrainrotFeedback.setShield(placement.model, shield > 0)
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
	randomizeCooldown: boolean?,
	savedCharges: number?
): Placement?
	local topCenter = GridService.getWorldPosition(plotModel, position)
	if not topCenter then
		return nil
	end

	local clampedHealth: number
	if definition.ignoreMonsterChew then
		clampedHealth = 0
	else
		clampedHealth = math.clamp(math.floor(health), 1, definition.health)
	end
	local model = BrainrotModel.create(
		instanceId,
		definition,
		ownerUserId,
		position,
		topCenter,
		brainrotsFolder(plotModel)
	)

	local charges: number? = nil
	if type(definition.charges) == "number" and definition.charges > 0 then
		charges = if type(savedCharges) == "number"
			then math.clamp(math.floor(savedCharges), 1, definition.charges)
			else definition.charges
		model:SetAttribute("Charges", charges)
	end

	model:SetAttribute("HitsRemaining", clampedHealth)
	local displayHealth = 0
	if definition.health > 0 then
		displayHealth = math.floor(definition.maxHealth * clampedHealth / definition.health)
	end
	model:SetAttribute("Health", displayHealth)
	model:SetAttribute("ShieldHp", 0)

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
			elseif definition.plantOnGrave == true
			then 0
			else definition.attackInterval,
		frozenUntil = 0,
		poisonUntil = 0,
		poisonHitsPerTick = 0,
		poisonNextTick = 0,
		poisonTintActive = false,
		burnUntil = 0,
		burnHitsPerTick = 0,
		burnNextTick = 0,
		venomUntil = 0,
		venomHitsPerTick = 0,
		venomNextTick = 0,
		venomTintActive = false,
		weakenUntil = 0,
		weakenFactor = 0,
		extraCooldowns = {},
		buffs = Abilities.defaultBuffs(),
		charges = charges,
	}

	placements[instanceId] = placement
	BrainrotBehavior.register(placement)
	applyEvolutionAura(model, ownerUserId, definition.id)
	applyNameplateAttributes(placement)
	return placement
end

-- Tears down a placement: destroys the model, frees its tile, drops state.
local function destroyPlacement(placement: Placement)
	local plotModel = placement.plotModel
	local position = placement.position
	local restoreGrave = placement.definition.plantOnGrave == true and GraveService.hasGrave(plotModel, position)

	BrainrotBehavior.unregister(placement)
	placements[placement.instanceId] = nil
	if restoreGrave then
		GridService.revertToGrave(plotModel, position)
	else
		GridService.release(plotModel, position)
	end
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

local function applyBrainrotDamage(instanceId: string, hits: number, sourceMonsterId: string?): boolean
	local placement = placements[instanceId]
	if not placement then
		return false
	end
	if placement.definition.ignoreMonsterChew then
		return false
	end

	if placement.buffs.stoneUntil > os.clock() then
		return false
	end

	if hits > 0 and type(sourceMonsterId) == "string" then
		local maxHits = placement.definition.health
		if maxHits > 0 then
			local incomingHp = hits * (placement.definition.maxHealth / maxHits)
			-- Chew/arrow `sourceMonsterId` is the runtime instance. The meter
			-- ranks by registry species id.
			local speciesId = CombatService.getMonsterRegistryId(sourceMonsterId) or sourceMonsterId
			local DamageMeterService = require(script.Parent.DamageMeterService)
			DamageMeterService.recordMonster(placement.ownerUserId, speciesId, incomingHp)
			if os.clock() < placement.buffs.reflectUntil and placement.buffs.reflectPercent > 0 then
				local reflected = math.max(1, math.floor(incomingHp * placement.buffs.reflectPercent / 100 + 0.5))
				CombatService.damageMonster(sourceMonsterId, reflected, placement.brainrotId)
				CombatService.notifyHitVisual(placement.ownerUserId, sourceMonsterId)
			end
		end
	end

	if hits > 0 and placement.definition.ability == "Wall" then
		local ProgressService = require(script.Parent.ProgressService)
		ProgressService.grantBrainrotXpForUser(
			placement.ownerUserId,
			placement.definition.id,
			EvolutionConfig.SOAK_XP
		)
	end

	local maxHits = placement.definition.health
	if hits > 0 and maxHits > 0 and placement.buffs.shieldHp > 0 then
		local hpPerHit = placement.definition.maxHealth / maxHits
		local incomingHp = hits * hpPerHit
		local absorbed = math.min(placement.buffs.shieldHp, incomingHp)
		placement.buffs.shieldHp -= absorbed
		local leftoverHp = incomingHp - absorbed
		hits = if leftoverHp > 0 then math.ceil(leftoverHp / hpPerHit) else 0
		if placement.buffs.shieldHp <= 0 then
			placement.buffs.shieldStunImmune = false
			placement.buffs.tenfoldShield = false
			placement.buffs.shieldUntil = 0
		end
	end

	if hits > 0 then
		placement.health = math.max(0, placement.health - hits)
	end
	syncHealthDisplay(placement)

	local isFatal = placement.health <= 0
	-- Server-owned Color replicates (same pattern as MonsterFeedback.flashHit).
	BrainrotFeedback.flashHit(placement.model, isFatal)
	BrainrotAnimation.playHit(placement.model)

	if isFatal then
		destroyPlacement(placement)
		return true
	end
	return false
end

local function applyBrainrotHeal(instanceId: string, hits: number)
	local placement = placements[instanceId]
	if not placement then
		return
	end
	if hits <= 0 then
		return
	end
	local maxHits = placement.definition.health
	if maxHits <= 0 then
		return
	end
	local before = placement.health
	placement.health = math.min(maxHits, placement.health + hits)
	syncHealthDisplay(placement)
	if placement.health > before then
		CombatService.notifyHeal(placement.ownerUserId, instanceId)
	end
end

-- ===== Remote handlers (untrusted input) =====

local function countLivingOnPlot(plotModel: Model, brainrotId: string): number
	local n = 0
	for _, placement in placements do
		if placement.plotModel == plotModel
			and placement.brainrotId == brainrotId
			and placement.health > 0
		then
			n += 1
		end
	end
	return n
end

local function plotCapReason(definition: Types.BrainrotDefinition): string
	local cap = definition.maxOnPlot
	if type(cap) ~= "number" then
		return "You've placed as many as you can."
	end
	return string.format("You can only place %d %s.", cap, definition.name)
end

local function tryReservePlotCap(plotModel: Model, brainrotId: string, cap: number): boolean
	local byId = pendingPlotCaps[plotModel]
	if not byId then
		byId = {}
		pendingPlotCaps[plotModel] = byId
	end
	local pending = byId[brainrotId] or 0
	if countLivingOnPlot(plotModel, brainrotId) + pending >= cap then
		return false
	end
	byId[brainrotId] = pending + 1
	return true
end

local function releasePlotCap(plotModel: Model, brainrotId: string)
	local byId = pendingPlotCaps[plotModel]
	if not byId then
		return
	end
	local pending = byId[brainrotId]
	if type(pending) ~= "number" then
		return
	end
	if pending <= 1 then
		byId[brainrotId] = nil
		if next(byId) == nil then
			pendingPlotCaps[plotModel] = nil
		end
	else
		byId[brainrotId] = pending - 1
	end
end

local function notifyPlaceFailed(player: Player, reason: string)
	Remotes.getEvent("PlaceBrainrotFailed"):FireClient(player, reason)
end

local function onPlaceBrainrot(player: Player, brainrotId: unknown, rawPosition: unknown)
	local LevelService = require(script.Parent.LevelService)
	if not LevelService.isLevelActive(player) then
		notifyPlaceFailed(player, "Start the day first.")
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
		notifyPlaceFailed(player, "That Brainrot isn't unlocked.")
		return
	end
	definition = evolvedDefinition(player.UserId, definition)

	if isPlantOnCooldown(player, brainrotId) then
		notifyPlaceFailed(player, "Still recharging.")
		return
	end

	local weather = LevelService.getWeather(player)
	local plot = PlotService.getPlot(player)
	if not plot then
		return
	end
	local plotModel = plot.model
	local maxOnPlot = definition.maxOnPlot
	local reservedCap = false
	if type(maxOnPlot) == "number" and maxOnPlot > 0 then
		if not tryReservePlotCap(plotModel, definition.id, maxOnPlot) then
			notifyPlaceFailed(player, plotCapReason(definition))
			return
		end
		reservedCap = true
	end
	local function releaseCap()
		if reservedCap then
			releasePlotCap(plotModel, definition.id)
			reservedCap = false
		end
	end
	local rowCleared = FogRows.isRowCleared(plotModel, position.row)
	if WeatherUtil.fogBlocksPlanting(
		position.column,
		weather,
		rowCleared,
		definition.plantsOnFog,
		definition.triggersOnPlace,
		definition.plantOnGrave
	) then
		releaseCap()
		notifyPlaceFailed(player, "That tile is covered in fog.")
		return
	end

	local hasGrave = GraveService.hasGrave(plotModel, position)
	if definition.plantOnGrave == true then
		if not hasGrave then
			releaseCap()
			notifyPlaceFailed(player, "Plant this one on a grave.")
			return
		end
	elseif hasGrave then
		releaseCap()
		notifyPlaceFailed(player, "That spot is taken.")
		return
	end

	-- Affordability pre-check (cheap reject before reserving the tile).
	local cost = PlantCost.coins(definition.cost, plotModel)
	if CoinService.getBalance(player) < cost then
		releaseCap()
		notifyPlaceFailed(player, "Not enough coins.")
		return
	end

	nextInstanceId += 1
	local instanceId = string.format("Brainrot_%d", nextInstanceId)

	-- Reserve first so two requests can't claim the same tile, then charge.
	local occupied = if definition.plantOnGrave == true
		then GridService.tryOccupyOverGrave(plotModel, position, instanceId)
		else GridService.tryOccupy(plotModel, position, instanceId)
	if not occupied then
		releaseCap()
		notifyPlaceFailed(player, "That spot is taken.")
		return
	end
	if not CoinService.trySpend(player, cost) then
		if definition.plantOnGrave == true then
			GridService.revertToGrave(plotModel, position)
		else
			GridService.release(plotModel, position)
		end
		releaseCap()
		notifyPlaceFailed(player, "Not enough coins.")
		return
	end

	if not createPlacement(instanceId, definition, player.UserId, plotModel, position, definition.health) then
		if definition.plantOnGrave == true then
			GridService.revertToGrave(plotModel, position)
		else
			GridService.release(plotModel, position)
		end
		CoinService.addCoins(player, cost)
		releaseCap()
		return
	end

	if cost < definition.cost then
		plotModel:SetAttribute(PlantCost.DISCOUNT_ATTRIBUTE, nil)
	end

	releaseCap()
	local ProgressConfig = require(ReplicatedStorage.Shared.Config.ProgressConfig)
	if not LevelService.isChallengeActiveForUser(player.UserId) then
		ProgressService.incrementStat(player, ProgressConfig.STAT_BRAINROTS_PLACED)
	end
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

function BrainrotService.noteLandedAttack(instanceId: string)
	BrainrotBehavior.noteLandedAttack(instanceId)
end

-- Removes a living Brainrot from the lawn (Pharaoh steal and any later
-- displacement). Immovable plants stay on their tile.
function BrainrotService.isImmovable(instanceId: string): boolean
	local placement = placements[instanceId]
	return placement ~= nil and placement.definition.immovable == true
end

function BrainrotService.stealPlacement(instanceId: string, destination: Vector3?): boolean
	local placement = placements[instanceId]
	if not placement or placement.health <= 0 or placement.definition.immovable == true then
		return false
	end

	local model = detachPlacement(placement)
	if not model then
		return false
	end

	if not destination then
		model:Destroy()
		return true
	end

	local startPivot = model:GetPivot()
	local goal = CFrame.new(destination) * (startPivot - startPivot.Position)
	local alpha = Instance.new("NumberValue")
	alpha.Value = 0
	local conn: RBXScriptConnection
	conn = alpha.Changed:Connect(function(value)
		if model.Parent then
			model:PivotTo(startPivot:Lerp(goal, value))
		end
	end)
	local tween = TweenService:Create(
		alpha,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Value = 1 }
	)
	tween.Completed:Connect(function()
		conn:Disconnect()
		alpha:Destroy()
		if model.Parent then
			model:Destroy()
		end
	end)
	tween:Play()
	return true
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
				charges = placement.charges,
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
		if not definition or definition.hidden == true then
			continue
		end
		definition = evolvedDefinition(player.UserId, definition)

		local instanceId = if type(saved.instanceId) == "string" and saved.instanceId ~= ""
			then saved.instanceId
			else string.format("Brainrot_%d", nextInstanceId + 1)
		local health = if type(saved.health) == "number" then saved.health else definition.health
		local savedCharges = if type(saved.charges) == "number" then saved.charges else nil
		if type(definition.charges) == "number" and definition.charges > 0 then
			-- Immune charge plants (Boneca) save 0 HP; their uses decide if they return.
			if savedCharges ~= nil and savedCharges <= 0 then
				continue
			end
		elseif health <= 0 then
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

		if not createPlacement(instanceId, definition, player.UserId, plot.model, position, health, true, savedCharges) then
			GridService.release(plot.model, position)
		end
	end
end

-- Re-compose Epic (and later) stats + aura on every living plant of this id.
function BrainrotService.applyEvolutionStats(player: Player, brainrotId: string)
	local base = Brainrots.get(brainrotId)
	if not base then
		return
	end
	local composed = Evolutions.applyStats(base, claimedForOwner(player.UserId, brainrotId))
	for _, placement in placements do
		if placement.ownerUserId ~= player.UserId or placement.brainrotId ~= brainrotId then
			continue
		end
		-- A newly claimed tier that raises the use cap tops up plants already out.
		local chargeGain = (composed.charges or 0) - (placement.definition.charges or 0)
		if chargeGain > 0 and type(placement.charges) == "number" and placement.charges > 0 then
			placement.charges += chargeGain
			placement.model:SetAttribute("Charges", placement.charges)
		end
		placement.definition = composed
		if composed.attackInterval > 0 then
			placement.cooldownRemaining = math.min(placement.cooldownRemaining, composed.attackInterval)
		end
		syncHealthDisplay(placement)
		applyEvolutionAura(placement.model, player.UserId, brainrotId)
		applyNameplateAttributes(placement)
	end
end

function BrainrotService.syncNameplates(player: Player, brainrotId: string?)
	for _, placement in placements do
		if placement.ownerUserId ~= player.UserId then
			continue
		end
		if brainrotId and placement.brainrotId ~= brainrotId then
			continue
		end
		applyNameplateAttributes(placement)
	end
end

function BrainrotService.setPlantDiscount(plotModel: Model, percent: number, cooldown: number?)
	if percent <= 0 then
		return
	end
	local now = os.clock()
	local readyAt = plantDiscountReadyAt[plotModel]
	if type(readyAt) == "number" and now < readyAt then
		return
	end
	local factor = math.clamp(1 - percent / 100, 0.01, 0.99)
	local current = plotModel:GetAttribute(PlantCost.DISCOUNT_ATTRIBUTE)
	-- Keep the stronger (lower) factor; a matching 50% charge just refreshes.
	if type(current) == "number" and current < factor then
		return
	end
	plotModel:SetAttribute(PlantCost.DISCOUNT_ATTRIBUTE, factor)
	local cd = cooldown
	if type(cd) ~= "number" then
		cd = EvolutionConfig.PLANT_DISCOUNT_COOLDOWN
	end
	if cd > 0 then
		plantDiscountReadyAt[plotModel] = now + cd
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
	FogRows.clearPlot(plotModel)

	Abilities.clearPlot(plotModel)
	plotModel:SetAttribute(PlantCost.DISCOUNT_ATTRIBUTE, nil)
	plantDiscountReadyAt[plotModel] = nil
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
			and placement.definition.triggersOnPlace ~= true
			and placement.definition.plantsOnFog ~= true
			and not FogRows.isRowCleared(plot.model, placement.position.row)
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
	if placement.definition.ignoreMonsterChew then
		return
	end

	local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
	local now = os.clock()
	if placement.buffs.stoneUntil > now then
		return
	end
	if kind == "Stun" or kind == "Freeze" then
		if kind == "Stun"
			and placement.buffs.shieldStunImmune
			and placement.buffs.shieldHp > 0
		then
			return
		end
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
		return
	end

	if kind == "Venom" then
		local percent = magnitude or 3
		local tickDamage = math.max(1, math.ceil(placement.definition.maxHealth * percent / 100))
		local hitsPerTick = math.max(
			1,
			math.ceil(tickDamage / (placement.definition.maxHealth / placement.definition.health))
		)
		placement.venomUntil = math.max(placement.venomUntil, now + duration)
		placement.venomHitsPerTick = hitsPerTick
		placement.venomNextTick = now + CombatConfig.VENOM_TICK_INTERVAL
		placement.venomTintActive = true
		BrainrotFeedback.setVenomed(placement.model, true)
		local remain = placement.venomUntil - now
		if remain > 0 then
			CombatService.notifyVenom(placement.ownerUserId, instanceId, remain)
		end
	end
end

function BrainrotService.init()
	BrainrotBehavior.setDestroyHandler(destroyPlacement)
	BrainrotBehavior.setDetachHandler(detachPlacement)
	CombatService.setBrainrotDamageHandler(applyBrainrotDamage)
	CombatService.setBrainrotHealHandler(applyBrainrotHeal)
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
