--!strict
local BattleClock = require(game:GetService("ReplicatedStorage").Shared.Utilities.BattleClock)
--[[
	PullToLane (La Vacca Saturno Saturnita)
	One-shot on place. Hovers, then pulls the closest legal monster on each
	row within pullReach onto her tile. maxLaneSpan skips wider units (1, or
	2 with Heavier Bodies). landingStun applies when the slide finishes.
	An edge row pulls fewer rows than a middle row. Then she despawns.

	Black Hole (GOD, blackHole = 1) replaces that pull. She becomes a hole,
	holds for BLACK_HOLE_HOLD_SECONDS while the closest blackHoleCount
	monsters on the lawn shrink into it, then the hole collapses. Monsters
	that have already walked past her are still swallowed. Bosses are never
	swallowed. Heavier Bodies still sets who else is legal.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GridConfig = require(ReplicatedStorage.Shared.Config.GridConfig)
local VfxConfig = require(ReplicatedStorage.Shared.Config.VfxConfig)

local CombatService = require(script.Parent.Parent.Parent.CombatService)
local EnemyService = require(script.Parent.Parent.Parent.EnemyService)

local PullToLane = {}

local BOB_HEIGHT = 0.55
local BOB_SPEED = 4
local PULL_DELAY = 0.45
local DESPAWN_AFTER = 2
local PULL_SLIDE_SECONDS = 0.85

local function param(params: { [string]: number }?, key: string, fallback: number): number
	if params and type(params[key]) == "number" then
		return params[key]
	end
	return fallback
end

local function rowsWithin(row: number, reach: number): { number }
	local rows: { number } = {}
	local first = math.max(1, row - reach)
	local last = math.min(GridConfig.ROWS, row + reach)
	for other = first, last do
		if other ~= row then
			table.insert(rows, other)
		end
	end
	return rows
end

local function isLegal(instanceId: string, maxSpan: number, skipBosses: boolean): boolean
	if skipBosses and EnemyService.isBoss(instanceId) then
		return false
	end
	return EnemyService.getMonsterLaneSpan(instanceId) <= maxSpan
end

local function closestOnRow(plotModel: Model, row: number, maxSpan: number): string?
	local bestId: string? = nil
	local bestColumn = math.huge
	for _, instanceId in CombatService.getAllMonstersInRow(plotModel, row) do
		if not isLegal(instanceId, maxSpan, false) then
			continue
		end
		local column = CombatService.getMonsterColumn(instanceId)
		if type(column) == "number" and column < bestColumn then
			bestColumn = column
			bestId = instanceId
		end
	end
	return bestId
end

-- Closest legal monsters anywhere on the lawn, nearest to her tile first.
local function closestOnLawn(ctx, maxSpan: number, count: number): { string }
	local found: { { id: string, distance: number } } = {}
	local herRow = ctx.position.row
	local herColumn = ctx.position.column
	for row = 1, GridConfig.ROWS do
		for _, instanceId in CombatService.getAllMonstersInRow(ctx.plotModel, row) do
			if not isLegal(instanceId, maxSpan, true) then
				continue
			end
			local column = CombatService.getMonsterColumn(instanceId)
			if type(column) ~= "number" then
				continue
			end
			local dRow = row - herRow
			local dColumn = column - herColumn
			table.insert(found, { id = instanceId, distance = dRow * dRow + dColumn * dColumn })
		end
	end
	table.sort(found, function(a, b)
		return a.distance < b.distance
	end)
	local ids: { string } = {}
	for index = 1, math.min(count, #found) do
		table.insert(ids, found[index].id)
	end
	return ids
end

local function hideParts(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
		end
	end
end

-- She rises into the floating hole and shrinks, then stays invisible so the tile is still hers.
local function foldIntoHole(model: Model, seconds: number, goal: Vector3)
	local startScale = model:GetScale()
	local start = model:GetPivot()
	local rotation = start - start.Position
	local started = BattleClock.now(model)
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		if not model.Parent then
			conn:Disconnect()
			return
		end
		local alpha = math.clamp((BattleClock.now(model) - started) / seconds, 0, 1)
		model:ScaleTo(math.max(0.05, startScale * (1 - alpha)))
		model:PivotTo(CFrame.new(start.Position:Lerp(goal, alpha)) * rotation)
		if alpha >= 1 then
			conn:Disconnect()
			hideParts(model)
		end
	end)
end

-- Slide into the hole while shrinking to nothing, then remove the monster.
local function suckTo(instanceId: string, goal: Vector3, seconds: number, brainrotId: string): boolean
	local model = EnemyService.getModel(instanceId)
	if not model then
		return false
	end
	EnemyService.suspendLocomotion(instanceId, seconds + 0.25)
	local start = model:GetPivot()
	local rotation = start - start.Position
	local startScale = model:GetScale()
	local started = BattleClock.now(model)
	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		if not EnemyService.consumeMonster(instanceId, brainrotId) and model.Parent then
			model:ScaleTo(startScale)
		end
	end
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		if done then
			conn:Disconnect()
			return
		end
		if not model.Parent then
			conn:Disconnect()
			finish()
			return
		end
		local alpha = math.clamp((BattleClock.now(model) - started) / seconds, 0, 1)
		local eased = alpha * alpha
		model:ScaleTo(math.max(0.02, startScale * (1 - eased)))
		model:PivotTo(CFrame.new(start.Position:Lerp(goal, eased)) * rotation)
		if alpha >= 1 then
			conn:Disconnect()
			finish()
		end
	end)
	return true
end

local function collapse(ctx, callbacks)
	local params = ctx.definition.abilityParams
	local maxSpan = param(params, "maxLaneSpan", 1)
	local count = math.max(1, math.floor(param(params, "blackHoleCount", 3)))
	local victims = closestOnLawn(ctx, maxSpan, count)
	local model = ctx.model
	local openSeconds = VfxConfig.BLACK_HOLE_OPEN_SECONDS
	local holdSeconds = VfxConfig.BLACK_HOLE_HOLD_SECONDS
	local closeSeconds = VfxConfig.BLACK_HOLE_CLOSE_SECONDS
	local suckSeconds = VfxConfig.BLACK_HOLE_SUCK_SECONDS
	local stagger = VfxConfig.BLACK_HOLE_SUCK_STAGGER
	local center = model:GetPivot().Position + Vector3.new(0, VfxConfig.BLACK_HOLE_HOVER, 0)
	local brainrotId = ctx.definition.id

	foldIntoHole(model, openSeconds, center)
	CombatService.notifyBlackHole(ctx.ownerUserId, center, openSeconds + holdSeconds + closeSeconds)

	BattleClock.delay(ctx.plotModel, openSeconds, function()
		if not model.Parent then
			return
		end
		for index, instanceId in victims do
			BattleClock.delay(ctx.plotModel, (index - 1) * stagger, function()
				if model.Parent then
					suckTo(instanceId, center, suckSeconds, brainrotId)
				end
			end)
		end
	end)

	BattleClock.delay(ctx.plotModel, openSeconds + holdSeconds + closeSeconds, function()
		if model.Parent then
			callbacks.destroySelf()
		end
	end)
end

function PullToLane.onPlaced(ctx, callbacks)
	local params = ctx.definition.abilityParams
	if params and params.blackHole == 1 then
		collapse(ctx, callbacks)
		return
	end

	local model = ctx.model
	local plotModel = ctx.plotModel
	local row = ctx.position.row
	local reach = math.max(1, math.floor(param(params, "pullReach", 1)))
	local maxSpan = param(params, "maxLaneSpan", 1)
	local stun = param(params, "landingStun", 0)
	local base = model:GetPivot()

	local bobbing = true
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		if not bobbing or not model.Parent then
			conn:Disconnect()
			return
		end
		local bob = math.sin(BattleClock.now(ctx.plotModel) * BOB_SPEED) * BOB_HEIGHT
		model:PivotTo(base + Vector3.new(0, bob, 0))
	end)

	BattleClock.delay(ctx.plotModel, PULL_DELAY, function()
		if not plotModel.Parent or not model.Parent then
			return
		end
		local origins: { Vector3 } = {}
		for _, neighbor in rowsWithin(row, reach) do
			local targetId = closestOnRow(plotModel, neighbor, maxSpan)
			if not targetId then
				continue
			end
			local monster = EnemyService.getModel(targetId)
			if monster then
				table.insert(origins, monster:GetPivot().Position)
			end
			if EnemyService.pullToRow(targetId, row, ctx.position.column) and stun > 0 then
				BattleClock.delay(ctx.plotModel, PULL_SLIDE_SECONDS, function()
					CombatService.applyStatusToMonster(targetId, "Stun", stun)
				end)
			end
		end
		CombatService.notifyGravityPull(ctx.ownerUserId, model:GetPivot().Position, origins)
	end)

	BattleClock.delay(ctx.plotModel, DESPAWN_AFTER, function()
		bobbing = false
		if conn.Connected then
			conn:Disconnect()
		end
		if model.Parent then
			callbacks.destroySelf()
		end
	end)
end

return PullToLane
