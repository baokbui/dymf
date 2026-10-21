--!strict
--[[
	ShadowRequiem (Cappuccino GOD)
	Plays the dual-slash clip, then at the end of that animation one
	sword wave leaves Cappuccino (white fill, black outline and streaks).
	It starts small, grows with distance, stops on the last lawn tile, and
	explodes into a white light pillar. Pierce every monster and grave.
	Crescent damage is 2000% at 1 tile, plus 100% per extra tile of travel.
	The last-tile pillar bonus stays a flat extra 1000%.
	Needs 3+ enemies still in front of him, or a boss still in front.
	The wave does not hit monsters that have already walked past him.
	If several GOD Cappuccinos in the
	same row are ready, the easternmost (closest to incoming monsters) fires first.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local ModelUtil = require(ReplicatedStorage.Shared.Utilities.ModelUtil)
local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)

local CombatService = require(script.Parent.Parent.Parent.CombatService)

local ShadowRequiem = {}

local log = Logger.new("ShadowRequiem")

local ABILITY_ID = "ShadowRequiem"

-- One Requiem at a time per plot row so two ready Cappuccinos cannot overlap.
local rowBusy: { [Model]: { [number]: boolean } } = {}

local function setRowBusy(plotModel: Model, row: number, busy: boolean)
	local rows = rowBusy[plotModel]
	if busy then
		if not rows then
			rows = {}
			rowBusy[plotModel] = rows
		end
		rows[row] = true
		return
	end
	if not rows then
		return
	end
	rows[row] = nil
	if next(rows) == nil then
		rowBusy[plotModel] = nil
	end
end

local function isRowBusy(plotModel: Model, row: number): boolean
	local rows = rowBusy[plotModel]
	return rows ~= nil and rows[row] == true
end

local function rowQualifies(plotModel: Model, row: number, originColumn: number, minEnemies: number): boolean
	local count, boss = CombatService.frontLaneThreat(plotModel, row, originColumn)
	return boss or count >= minEnemies
end

local SWORD_KEYS = { "sword", "blade", "katana", "saber", "scimitar", "ninjato", "wakizashi" }
local IGNORE_PARTS: { [string]: boolean } = {
	humanoidrootpart = true,
	rootpart = true,
	head = true,
	torso = true,
	uppertorso = true,
	lowertorso = true,
	humanoidroot = true,
}

local function looksLikeSword(part: BasePart): boolean
	local lower = string.lower(part.Name)
	if IGNORE_PARTS[lower] then
		return false
	end
	for _, key in SWORD_KEYS do
		if string.find(lower, key, 1, true) then
			return true
		end
	end
	return false
end

local function collectSwords(model: Model): { BasePart }
	local swords: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and looksLikeSword(descendant) then
			table.insert(swords, descendant)
		end
	end
	return swords
end

local function waveOrigin(model: Model): Vector3
	local _, center = ModelUtil.getVisualSizeAndCenter(model)
	local fallback = center + Vector3.new(
		CombatConfig.SWORD_WAVE_FALLBACK_EAST,
		CombatConfig.SWORD_WAVE_FALLBACK_UP,
		0
	)

	local swords = collectSwords(model)
	if #swords >= 2 then
		table.sort(swords, function(a, b)
			return a.Position.Z < b.Position.Z
		end)
		local a = swords[1].Position
		local b = swords[#swords].Position
		return (a + b) * 0.5
	end
	if #swords == 1 then
		return swords[1].Position
	end
	return fallback
end

local function clipWait(callbacks): number
	local deadline = os.clock() + 0.4
	local length: number? = nil
	while os.clock() < deadline do
		length = callbacks.getAbilityLength(ABILITY_ID)
		if type(length) == "number" and length > 0 then
			break
		end
		task.wait(0.05)
	end
	if type(length) == "number" and length > 0 then
		return math.max(0, length - CombatConfig.SWORD_WAVE_RELEASE_LEAD)
	end
	return CombatConfig.SWORD_WAVE_ANIM_FALLBACK
end

local function fireWaves(ctx, damage: number, laneEndBonus: number, travelBonus: number)
	if not ctx.plotModel.Parent or not ctx.model.Parent then
		return
	end

	local origin = waveOrigin(ctx.model)
	local waveGroupId = string.format("%s_%.3f", ctx.instanceId, os.clock())
	local options = {
		sourceBrainrotId = ctx.definition.id,
		sourceInstanceId = ctx.instanceId,
		pierceCount = CombatConfig.SWORD_WAVE_PIERCE_COUNT,
		pierceGraves = true,
		pierceAll = true,
		waveGroupId = waveGroupId,
		laneEndBonus = laneEndBonus,
		waveOriginColumn = ctx.position.column,
		waveTravelBonus = travelBonus,
	}

	CombatService.launchSwordWave(ctx.plotModel, ctx.position, damage, ctx.ownerUserId, origin, options)
end

function ShadowRequiem.tryAct(ctx, callbacks)
	local minEnemies = CombatConfig.SWORD_WAVE_MIN_ENEMIES
	local params = ctx.extraParams
	if type(params) == "table" and type(params.minEnemies) == "number" then
		minEnemies = params.minEnemies
	end

	if isRowBusy(ctx.plotModel, ctx.position.row) then
		return false
	end
	if not rowQualifies(ctx.plotModel, ctx.position.row, ctx.position.column, minEnemies) then
		return false
	end

	local BrainrotBehavior = require(script.Parent.Parent.BrainrotBehavior)
	if BrainrotBehavior.hasCloserReadyAlly(ctx.instanceId, ABILITY_ID) then
		return false
	end

	local percent = 2000
	local finisherPercent = 1000
	local travelPercent = 100
	if type(params) == "table" then
		if type(params.damagePercent) == "number" then
			percent = params.damagePercent
		end
		if type(params.finisherPercent) == "number" then
			finisherPercent = params.finisherPercent
		end
		if type(params.travelPercent) == "number" then
			travelPercent = params.travelPercent
		end
	end
	local damage = math.max(1, math.floor(ctx.definition.damage * percent / 100))
	local laneEndBonus = math.max(0, math.floor(ctx.definition.damage * finisherPercent / 100))
	local travelBonus = math.max(0, math.floor(ctx.definition.damage * travelPercent / 100))

	callbacks.playAbility(ABILITY_ID)
	local length = callbacks.getAbilityLength(ABILITY_ID)
	local lockFor = CombatConfig.SWORD_WAVE_ANIM_FALLBACK
	if type(length) == "number" and length > 0 then
		lockFor = length
	end
	callbacks.lockExclusive(lockFor)
	callbacks.lockCore(lockFor)
	setRowBusy(ctx.plotModel, ctx.position.row, true)
	task.spawn(function()
		local ok, err = pcall(function()
			local untilWave = clipWait(callbacks)
			local lead = math.max(0, CombatConfig.SWORD_WAVE_SOUND_LEAD)
			if untilWave > lead then
				task.wait(untilWave - lead)
			end
			if not ctx.plotModel.Parent or not ctx.model.Parent then
				return
			end
			callbacks.playSound("SwordWave")
			if untilWave > lead then
				task.wait(lead)
			elseif untilWave > 0 then
				task.wait(untilWave)
			end
			if not ctx.plotModel.Parent or not ctx.model.Parent then
				return
			end
			fireWaves(ctx, damage, laneEndBonus, travelBonus)
		end)
		setRowBusy(ctx.plotModel, ctx.position.row, false)
		if not ok then
			log:warn(err)
		end
	end)
	return true
end

return ShadowRequiem
