--!strict
--[[
	PullToLane (La Vacca Saturno Saturnita)
	One-shot on place. Hovers and bobs above the tile, then pulls the closest
	1-tile monster on each adjacent row onto her tile. Units two or more
	tiles wide are skipped. An edge row pulls one. A middle row pulls one
	from each side, two at most. Then she despawns.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GridConfig = require(ReplicatedStorage.Shared.Config.GridConfig)
local CombatService = require(script.Parent.Parent.Parent.CombatService)
local EnemyService = require(script.Parent.Parent.Parent.EnemyService)

local PullToLane = {}

local BOB_HEIGHT = 0.55
local BOB_SPEED = 4
local PULL_DELAY = 0.45
local DESPAWN_AFTER = 2

local function neighborRows(row: number): { number }
	local rows: { number } = {}
	if row > 1 then
		table.insert(rows, row - 1)
	end
	if row < GridConfig.ROWS then
		table.insert(rows, row + 1)
	end
	return rows
end

local function closestOnRow(plotModel: Model, row: number): string?
	local bestId: string? = nil
	local bestColumn = math.huge
	for _, instanceId in CombatService.getAllMonstersInRow(plotModel, row) do
		if EnemyService.getMonsterLaneSpan(instanceId) > 1 then
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

function PullToLane.onPlaced(ctx, callbacks)
	local model = ctx.model
	local plotModel = ctx.plotModel
	local row = ctx.position.row
	local base = model:GetPivot()

	local bobbing = true
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		if not bobbing or not model.Parent then
			conn:Disconnect()
			return
		end
		local bob = math.sin(os.clock() * BOB_SPEED) * BOB_HEIGHT
		model:PivotTo(base + Vector3.new(0, bob, 0))
	end)

	task.delay(PULL_DELAY, function()
		if not plotModel.Parent or not model.Parent then
			return
		end
		local origins: { Vector3 } = {}
		for _, neighbor in neighborRows(row) do
			local targetId = closestOnRow(plotModel, neighbor)
			if targetId then
				local monster = EnemyService.getModel(targetId)
				if monster then
					table.insert(origins, monster:GetPivot().Position)
				end
				EnemyService.pullToRow(targetId, row, ctx.position.column)
			end
		end
		CombatService.notifyGravityPull(ctx.ownerUserId, model:GetPivot().Position, origins)
	end)

	task.delay(DESPAWN_AFTER, function()
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
