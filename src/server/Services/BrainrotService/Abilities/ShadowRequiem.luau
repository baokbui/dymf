--!strict
--[[
	ShadowRequiem (Cappuccino GOD)
	Plays the dual-slash clip, then at the end of that animation two black
	sword waves leave Cappuccino's blades. They start small, grow with
	distance, fade off the east plot edge, and pierce every monster and grave.
	Both waves share one hit group so each monster takes 2000% once.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotConfig = require(ReplicatedStorage.Shared.Config.BrainrotConfig)
local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local ModelUtil = require(ReplicatedStorage.Shared.Utilities.ModelUtil)
local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)

local CombatService = require(script.Parent.Parent.Parent.CombatService)

local ShadowRequiem = {}

local log = Logger.new("ShadowRequiem")

local ABILITY_ID = "ShadowRequiem"
local FULL_LINE = BrainrotConfig.FULL_LINE_RANGE

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

local function waveOrigins(model: Model): (Vector3, Vector3)
	local _, center = ModelUtil.getVisualSizeAndCenter(model)
	local fallbackA = center + Vector3.new(
		CombatConfig.SWORD_WAVE_FALLBACK_EAST,
		CombatConfig.SWORD_WAVE_FALLBACK_UP,
		CombatConfig.SWORD_WAVE_FALLBACK_Z
	)
	local fallbackB = center + Vector3.new(
		CombatConfig.SWORD_WAVE_FALLBACK_EAST,
		CombatConfig.SWORD_WAVE_FALLBACK_UP,
		-CombatConfig.SWORD_WAVE_FALLBACK_Z
	)

	local swords = collectSwords(model)
	if #swords >= 2 then
		table.sort(swords, function(a, b)
			return a.Position.Z < b.Position.Z
		end)
		return swords[1].Position, swords[#swords].Position
	end
	if #swords == 1 then
		local p = swords[1].Position
		local mirrored = Vector3.new(p.X, p.Y, center.Z - (p.Z - center.Z))
		return p, mirrored
	end
	return fallbackA, fallbackB
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

local function fireWaves(ctx, damage: number)
	if not ctx.plotModel.Parent or not ctx.model.Parent then
		return
	end

	local originA, originB = waveOrigins(ctx.model)
	local waveGroupId = string.format("%s_%.3f", ctx.instanceId, os.clock())
	local options = {
		sourceBrainrotId = ctx.definition.id,
		sourceInstanceId = ctx.instanceId,
		pierceCount = CombatConfig.SWORD_WAVE_PIERCE_COUNT,
		pierceGraves = true,
		pierceAll = true,
		waveGroupId = waveGroupId,
	}

	CombatService.launchSwordWave(ctx.plotModel, ctx.position, damage, ctx.ownerUserId, originA, options)
	CombatService.launchSwordWave(ctx.plotModel, ctx.position, damage, ctx.ownerUserId, originB, options)
end

function ShadowRequiem.tryAct(ctx, callbacks)
	local target = CombatService.getFirstMonsterInRow(
		ctx.plotModel,
		ctx.position.row,
		ctx.position.column,
		FULL_LINE
	)
	if not target then
		return false
	end

	local percent = 2000
	local params = ctx.extraParams
	if type(params) == "table" and type(params.damagePercent) == "number" then
		percent = params.damagePercent
	end
	local damage = math.max(1, math.floor(ctx.definition.damage * percent / 100))

	callbacks.playAbility(ABILITY_ID)
	task.spawn(function()
		local ok, err = pcall(function()
			task.wait(clipWait(callbacks))
			if not ctx.plotModel.Parent or not ctx.model.Parent then
				return
			end
			callbacks.playSound("ThrowKnifeHit")
			fireWaves(ctx, damage)
		end)
		if not ok then
			log:warn(err)
		end
	end)
	return true
end

return ShadowRequiem
