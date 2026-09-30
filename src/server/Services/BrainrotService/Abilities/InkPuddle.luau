--!strict
--[[
	InkPuddle (Blueberrinni Octopusini)
	Every attackInterval, lobs ink from the head onto a random empty tile in
	her own row. Graves and her own tile are skipped. A nearer tile uses a
	lower arc; a farther tile arcs higher.
	The puddle lasts puddleDuration. Monsters on that tile are Slow until they
	step off.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local GridConfig = require(ReplicatedStorage.Shared.Config.GridConfig)
local VfxConfig = require(ReplicatedStorage.Shared.Config.VfxConfig)
local GridUtil = require(ReplicatedStorage.Shared.Utilities.GridUtil)
local ModelUtil = require(ReplicatedStorage.Shared.Utilities.ModelUtil)

local CombatService = require(script.Parent.Parent.Parent.CombatService)
local GridService = require(script.Parent.Parent.Parent.GridService)

local InkPuddle = {}

local SLOW_REFRESH = 0.35
local INK = VfxConfig.INK_COLOR

type Puddle = {
	plotModel: Model,
	row: number,
	column: number,
	expiresAt: number,
	slowFactor: number,
	part: BasePart,
}

local puddles: { Puddle } = {}

-- Head part pivots on these rigs sit in the chest. Leave from the crown of
-- the visible mesh so the lob starts in the head.
local function headOrigin(model: Model): Vector3
	local size, center = ModelUtil.getVisualSizeAndCenter(model)
	return Vector3.new(center.X, center.Y + size.Y * 0.5 - 0.35, center.Z)
end

local function hasBrainrot(plotModel: Model, row: number, column: number): boolean
	local tile = GridService.getTile(plotModel, { row = row, column = column })
	return tile ~= nil and type(tile.brainrotInstanceId) == "string"
end

local function openTiles(plotModel: Model, fromRow: number, fromColumn: number): { number }
	local columns: { number } = {}
	for column = 1, GridConfig.COLUMNS do
		if column == fromColumn then
			continue
		end
		if hasBrainrot(plotModel, fromRow, column) then
			continue
		end
		if GridService.isGraveTile(plotModel, { row = fromRow, column = column }) then
			continue
		end
		table.insert(columns, column)
	end
	return columns
end

local function arcForDistance(fromColumn: number, column: number): number
	local tilesAway = math.abs(column - fromColumn)
	local farthest = math.max(GridConfig.COLUMNS - 1, 1)
	local alpha = math.clamp(tilesAway / farthest, 0, 1)
	return VfxConfig.INK_ARC_HEIGHT_MIN + (VfxConfig.INK_ARC_HEIGHT_MAX - VfxConfig.INK_ARC_HEIGHT_MIN) * alpha
end

local function spawnPuddle(plotModel: Model, row: number, column: number, duration: number, slowFactor: number)
	local world = GridService.getWorldPosition(plotModel, { row = row, column = column })
	if not world then
		return
	end
	local disc = Instance.new("Part")
	disc.Name = "InkPuddle"
	disc.Shape = Enum.PartType.Cylinder
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	disc.Material = Enum.Material.SmoothPlastic
	disc.Color = INK
	disc.Transparency = 0.12
	disc.Size = Vector3.new(0.25, 10, 10)
	disc.CFrame = CFrame.new(world + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	disc.Parent = plotModel
	table.insert(puddles, {
		plotModel = plotModel,
		row = row,
		column = column,
		expiresAt = os.clock() + duration,
		slowFactor = slowFactor,
		part = disc,
	})
end

function InkPuddle.tryAct(ctx, callbacks): boolean
	local open = openTiles(ctx.plotModel, ctx.position.row, ctx.position.column)
	if #open == 0 then
		return false
	end
	local column = open[math.random(1, #open)]
	local row = ctx.position.row
	local arc = arcForDistance(ctx.position.column, column)
	local params = ctx.definition.abilityParams
	local duration = 7
	local slowFactor = CombatConfig.SLOW_SPEED_FACTOR
	if params then
		if type(params.puddleDuration) == "number" then
			duration = params.puddleDuration
		end
		if type(params.slowFactor) == "number" then
			slowFactor = params.slowFactor
		end
	end

	callbacks.pulseAttack()
	local hitDelay = if type(ctx.definition.attackHitDelay) == "number" then ctx.definition.attackHitDelay else 0
	local plotModel = ctx.plotModel
	local model = ctx.model
	local ownerUserId = ctx.ownerUserId

	task.delay(hitDelay, function()
		if not model.Parent or not plotModel.Parent then
			return
		end
		local landing = GridService.getWorldPosition(plotModel, { row = row, column = column })
		if not landing then
			return
		end
		local head = headOrigin(model)
		local goal = landing + Vector3.new(0, 0.2, 0)
		CombatService.notifyInkDrop(ownerUserId, head, goal, arc)
		task.delay(VfxConfig.INK_FLIGHT_SECONDS, function()
			if plotModel.Parent then
				spawnPuddle(plotModel, row, column, duration, slowFactor)
			end
		end)
	end)
	return true
end

function InkPuddle.tick()
	local now = os.clock()
	local index = 1
	while index <= #puddles do
		local puddle = puddles[index]
		if now >= puddle.expiresAt or not puddle.part.Parent then
			if puddle.part.Parent then
				puddle.part:Destroy()
			end
			table.remove(puddles, index)
			continue
		end
		for _, instanceId in CombatService.getAllMonstersInRow(puddle.plotModel, puddle.row) do
			local monsterColumn = CombatService.getMonsterColumn(instanceId)
			if type(monsterColumn) == "number" and GridUtil.tileAtColumn(monsterColumn) == puddle.column then
				CombatService.applyStatusToMonster(instanceId, "Slow", SLOW_REFRESH, puddle.slowFactor)
			end
		end
		index += 1
	end
end

function InkPuddle.clearPlot(plotModel: Model)
	for index = #puddles, 1, -1 do
		local puddle = puddles[index]
		if puddle.plotModel == plotModel then
			if puddle.part.Parent then
				puddle.part:Destroy()
			end
			table.remove(puddles, index)
		end
	end
end

return InkPuddle
