--!strict
--[[
	InkPuddle (Blueberrinni Octopusini)
	Every attackInterval, lobs ink from the head onto the nearest tile east
	of her that has no Brainrot. The puddle lasts puddleDuration. Monsters
	on that tile are Slow until they step off.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local GridConfig = require(ReplicatedStorage.Shared.Config.GridConfig)
local VfxConfig = require(ReplicatedStorage.Shared.Config.VfxConfig)
local GridUtil = require(ReplicatedStorage.Shared.Utilities.GridUtil)

local BubbleShot = require(script.Parent.BubbleShot)
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

local function hasBrainrot(plotModel: Model, row: number, column: number): boolean
	local tile = GridService.getTile(plotModel, { row = row, column = column })
	return tile ~= nil and type(tile.brainrotInstanceId) == "string"
end

local function nextOpenColumn(plotModel: Model, row: number, fromColumn: number): number?
	local startTile = math.floor(fromColumn) + 1
	for column = startTile, GridConfig.COLUMNS do
		if column ~= math.floor(fromColumn) and not hasBrainrot(plotModel, row, column) then
			return column
		end
	end
	return nil
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
	local column = nextOpenColumn(ctx.plotModel, ctx.position.row, ctx.position.column)
	if not column then
		return false
	end
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
	local row = ctx.position.row
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
		local head = BubbleShot.mouthWorld(model)
		local headPart = model:FindFirstChild("Head", true)
		if headPart and headPart:IsA("BasePart") then
			head = headPart.Position
		elseif headPart and (headPart:IsA("Bone") or headPart:IsA("Attachment")) then
			head = headPart.WorldPosition
		end
		local goal = landing + Vector3.new(0, 0.2, 0)
		CombatService.notifyInkDrop(ownerUserId, head, goal)
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

return InkPuddle
