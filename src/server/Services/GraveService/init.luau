--!strict
local BattleClock = require(game:GetService("ReplicatedStorage").Shared.Utilities.BattleClock)
--[[
	GraveService
	Places graves on random fog tiles at day start. Occupies the tile (no
	Brainrot id) so plants cannot sit there, but monsters phase through.
	Each grave keeps spawning from a weather pool (Zombie/Skeleton on fog;
	Small Mummy on desert) until authored waves are done.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GraveConfig = require(ReplicatedStorage.Shared.Config.GraveConfig)
local PlotConfig = require(ReplicatedStorage.Shared.Config.PlotConfig)
local Types = require(ReplicatedStorage.Shared.Types)
local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)
local ModelUtil = require(ReplicatedStorage.Shared.Utilities.ModelUtil)
local WeatherUtil = require(ReplicatedStorage.Shared.Utilities.WeatherUtil)

local GridService = require(script.Parent.GridService)

local GraveService = {}
GraveService.Name = "GraveService"

local log = Logger.new(GraveService.Name)

local GRAVES_FOLDER = "Graves"

type GraveRuntime = {
	plotModel: Model,
	position: Types.GridPosition,
	model: Model,
	nextSpawnAt: number,
	monsterPool: { string },
	busting: boolean,
	hitsRemaining: number,
	restPivot: CFrame?,
	collapsing: boolean,
}

local gravesByPlot: { [Model]: { GraveRuntime } } = {}
local spawningClosed: { [Model]: boolean } = {}

local function randomInterval(minSeconds: number, maxSeconds: number): number
	local lo = math.min(minSeconds, maxSeconds)
	local hi = math.max(minSeconds, maxSeconds)
	return lo + math.random() * (hi - lo)
end

local function gravesFolder(plotModel: Model): Folder
	local folder = plotModel:FindFirstChild(GRAVES_FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = GRAVES_FOLDER
		folder.Parent = plotModel
	end
	return folder :: Folder
end

local function shuffle(list: { any })
	for index = #list, 2, -1 do
		local swap = math.random(index)
		list[index], list[swap] = list[swap], list[index]
	end
end

local function pickMonsterId(pool: { string }): string
	return pool[math.random(1, #pool)]
end

local function createProceduralGrave(): Model
	local model = Instance.new("Model")
	model.Name = "Grave"

	local slab = Instance.new("Part")
	slab.Name = "Body"
	slab.Size = Vector3.new(1.4, 2.4, 0.45)
	slab.Material = Enum.Material.Slate
	slab.Color = Color3.fromRGB(72, 74, 68)
	slab.Anchored = true
	slab.CanCollide = false
	slab.CastShadow = false
	slab.Parent = model
	model.PrimaryPart = slab
	return model
end

local function createGraveModel(): Model
	local folder = ModelUtil.getGraveTemplatesFolder()
	local child = if folder then folder:FindFirstChild(GraveConfig.MODEL_ID) else nil
	local footprint = PlotConfig.TILE_SIZE * GraveConfig.FOOTPRINT_RATIO * GraveConfig.MODEL_SCALE
	local cloneOptions = {
		targetFootprint = footprint,
		skipBodyAlias = true,
		faceDirection = GraveConfig.FACE_DIRECTION,
	}

	if child and child:IsA("Model") then
		local model = ModelUtil.cloneTemplate(child, cloneOptions)
		model.Name = "Grave"
		return model
	end

	if child and child:IsA("BasePart") then
		local wrapper = Instance.new("Model")
		wrapper.Name = "Grave"
		local part = child:Clone()
		part.Parent = wrapper
		wrapper.PrimaryPart = part
		local model = ModelUtil.cloneTemplate(wrapper, cloneOptions)
		wrapper:Destroy()
		model.Name = "Grave"
		return model
	end

	log:warn("missing Assets.Graves." .. GraveConfig.MODEL_ID .. " — using procedural tombstone")
	return createProceduralGrave()
end

local function tweenPivot(
	model: Model,
	start: CFrame,
	goal: CFrame,
	duration: number,
	easing: Enum.EasingDirection,
	onDone: (() -> ())?
)
	local alpha = Instance.new("NumberValue")
	alpha.Value = 0
	local conn: RBXScriptConnection
	conn = alpha.Changed:Connect(function(value)
		if model.Parent then
			model:PivotTo(start:Lerp(goal, value))
		end
	end)
	local tween = BattleClock.tween(model,
		alpha,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, easing),
		{ Value = 1 }
	)
	tween.Completed:Connect(function()
		conn:Disconnect()
		alpha:Destroy()
		if model.Parent then
			model:PivotTo(goal)
		end
		if onDone then
			onDone()
		end
	end)
	tween:Play()
end

local function buryDepth(model: Model): number
	local size = select(1, ModelUtil.getVisualSizeAndCenter(model))
	return size.Y + GraveConfig.RISE_EXTRA_STUDS
end

local function playRiseFromTile(model: Model, restPivot: CFrame, delay: number, duration: number?, onDone: (() -> ())?)
	local buried = restPivot - Vector3.new(0, buryDepth(model), 0)
	model:PivotTo(buried)
	local riseTime = duration or GraveConfig.RISE_DURATION

	BattleClock.delay(model, delay, function()
		if not model.Parent then
			if onDone then
				onDone()
			end
			return
		end
		tweenPivot(model, buried, restPivot, riseTime, Enum.EasingDirection.Out, onDone)
	end)
end

local function destroyGraveModel(model: Model)
	if model.Parent then
		model:Destroy()
	end
end

local function emerge(runtime: GraveRuntime)
	if spawningClosed[runtime.plotModel] then
		return
	end
	if runtime.busting or runtime.collapsing then
		return
	end
	if not runtime.model.Parent then
		return
	end

	local monsterId = pickMonsterId(runtime.monsterPool)
	local EnemyService = require(script.Parent.EnemyService)
	local instanceId = EnemyService.spawnAt(
		runtime.plotModel,
		monsterId,
		runtime.position.row,
		runtime.position.column
	)
	if instanceId then
		local duration = GraveConfig.MONSTER_RISE_DURATION
		EnemyService.suspendLocomotion(instanceId, duration)
		local monsterModel = EnemyService.getModel(instanceId)
		if monsterModel then
			playRiseFromTile(monsterModel, monsterModel:GetPivot(), 0, duration, function()
				EnemyService.resumeLocomotion(instanceId)
			end)
		else
			EnemyService.resumeLocomotion(instanceId)
		end
	end
	runtime.nextSpawnAt = BattleClock.now(runtime.plotModel) + randomInterval(GraveConfig.RESPAWN_MIN, GraveConfig.RESPAWN_MAX)
	log:info(string.format(
		"emerged %s from grave r%d c%d",
		monsterId,
		runtime.position.row,
		runtime.position.column
	))
end

local function findGrave(plotModel: Model, position: Types.GridPosition): GraveRuntime?
	local list = gravesByPlot[plotModel]
	if not list then
		return nil
	end
	for _, runtime in list do
		if runtime.position.row == position.row and runtime.position.column == position.column then
			return runtime
		end
	end
	return nil
end

local function shakeGrave(runtime: GraveRuntime)
	if runtime.collapsing or not runtime.model.Parent then
		return
	end
	local rest = runtime.restPivot or runtime.model:GetPivot()
	runtime.restPivot = rest
	local amplitude = GraveConfig.SHAKE_STUDS
	local offset = Vector3.new((math.random() - 0.5) * 2 * amplitude, 0, (math.random() - 0.5) * 2 * amplitude)
	tweenPivot(runtime.model, rest, rest + offset, GraveConfig.SHAKE_OUT_DURATION, Enum.EasingDirection.Out, function()
		if not runtime.model.Parent or runtime.collapsing then
			return
		end
		tweenPivot(runtime.model, runtime.model:GetPivot(), rest, GraveConfig.SHAKE_BACK_DURATION, Enum.EasingDirection.Out)
	end)
end

local function collapseGrave(runtime: GraveRuntime)
	if runtime.collapsing then
		return
	end
	runtime.collapsing = true
	runtime.busting = true
	GridService.setGraveFlag(runtime.plotModel, runtime.position, false)

	local list = gravesByPlot[runtime.plotModel]
	if list then
		for index, entry in list do
			if entry == runtime then
				table.remove(list, index)
				break
			end
		end
	end

	local model = runtime.model
	local MonsterDeath = require(script.Parent.EnemyService.MonsterDeath)
	MonsterDeath.playFadeInPlace(model)
	BattleClock.delay(runtime.plotModel, MonsterDeath.totalLifetime(), function()
		destroyGraveModel(model)
	end)
end

local function graveColumn(runtime: GraveRuntime): number
	return runtime.position.column
end

-- True when a shot from `fromColumn` at `targetColumn` hits this grave first.
local function graveBlocksTarget(runtime: GraveRuntime, row: number, fromColumn: number, targetColumn: number): boolean
	if runtime.collapsing or runtime.position.row ~= row then
		return false
	end
	local column = graveColumn(runtime)
	return fromColumn < column and column < targetColumn
end

function GraveService.hasGrave(plotModel: Model, position: Types.GridPosition): boolean
	local runtime = findGrave(plotModel, position)
	return runtime ~= nil and not runtime.collapsing
end

-- Lane block: a living grave sits strictly between the shooter and the target.
function GraveService.isMonsterBehindGrave(
	plotModel: Model,
	row: number,
	fromColumn: number,
	targetColumn: number
): boolean
	local list = gravesByPlot[plotModel]
	if not list then
		return false
	end
	for _, runtime in list do
		if graveBlocksTarget(runtime, row, fromColumn, targetColumn) then
			return true
		end
	end
	return false
end

local function findBlockingGrave(plotModel: Model, row: number, fromColumn: number, targetColumn: number): GraveRuntime?
	local list = gravesByPlot[plotModel]
	if not list then
		return nil
	end
	local best: GraveRuntime? = nil
	local bestColumn = math.huge
	for _, runtime in list do
		if graveBlocksTarget(runtime, row, fromColumn, targetColumn) then
			local column = graveColumn(runtime)
			if column < bestColumn then
				bestColumn = column
				best = runtime
			end
		end
	end
	return best
end

function GraveService.getBlockingColumn(
	plotModel: Model,
	row: number,
	fromColumn: number,
	targetColumn: number
): number?
	local runtime = findBlockingGrave(plotModel, row, fromColumn, targetColumn)
	if not runtime then
		return nil
	end
	return graveColumn(runtime)
end

-- Shake the nearest blocking grave (no HP). Returns true if a grave ate the hit.
function GraveService.absorbLaneHit(
	plotModel: Model,
	row: number,
	fromColumn: number,
	targetColumn: number
): boolean
	local runtime = findBlockingGrave(plotModel, row, fromColumn, targetColumn)
	if not runtime then
		return false
	end
	return true
end

function GraveService.shakeAt(plotModel: Model, row: number, column: number)
	local runtime = findGrave(plotModel, { row = row, column = column })
	if runtime then
		shakeGrave(runtime)
	end
end

-- One smash from Patapim. Returns true if the grave collapsed.
function GraveService.hitFromPatapim(plotModel: Model, position: Types.GridPosition): boolean
	local runtime = findGrave(plotModel, position)
	if not runtime or runtime.collapsing then
		return false
	end
	runtime.hitsRemaining -= 1
	if runtime.hitsRemaining <= 0 then
		collapseGrave(runtime)
		return true
	end
	shakeGrave(runtime)
	return false
end

function GraveService.beginBust(plotModel: Model, position: Types.GridPosition): boolean
	local runtime = findGrave(plotModel, position)
	if not runtime then
		return false
	end
	runtime.busting = true
	return true
end

function GraveService.cancelBust(plotModel: Model, position: Types.GridPosition)
	local runtime = findGrave(plotModel, position)
	if runtime then
		runtime.busting = false
	end
end

function GraveService.finishBust(plotModel: Model, position: Types.GridPosition): boolean
	local runtime = findGrave(plotModel, position)
	if not runtime then
		return false
	end
	collapseGrave(runtime)
	return true
end

function GraveService.hasPending(plotModel: Model): boolean
	-- Repeat grave spawns stop when authored waves complete; victory does not
	-- wait on graves after that.
	return false
end

function GraveService.clearPlot(plotModel: Model)
	local list = gravesByPlot[plotModel]
	if not list then
		return
	end
	for _, runtime in list do
		GridService.release(plotModel, runtime.position)
		destroyGraveModel(runtime.model)
	end
	gravesByPlot[plotModel] = nil
	spawningClosed[plotModel] = nil
	local folder = plotModel:FindFirstChild(GRAVES_FOLDER)
	if folder then
		folder:Destroy()
	end
end

function GraveService.notifyWavesComplete(plotModel: Model)
	-- Day's authored spawns are done — stop further grave production so the
	-- lawn can clear and victory can fire.
	spawningClosed[plotModel] = true
end

function GraveService.spawnForDay(plotModel: Model, definition: Types.LevelDefinition)
	GraveService.clearPlot(plotModel)

	if definition.graves ~= true then
		return
	end
	local candidates = WeatherUtil.graveCandidatePositions(definition.weather)
	if #candidates == 0 then
		log:warn(string.format("%s authored graves but weather has no grave tiles", definition.id))
		return
	end

	local graveCount = math.random(GraveConfig.COUNT_MIN, GraveConfig.COUNT_MAX)
	shuffle(candidates)

	local list: { GraveRuntime } = {}
	local now = BattleClock.now(plotModel)
	local emergeMin = GraveConfig.EMERGE_MIN
	local emergeMax = math.max(emergeMin, GraveConfig.EMERGE_MAX)

	local pool = if WeatherUtil.isDesert(definition.weather)
		then GraveConfig.DESERT_MONSTER_POOL
		else GraveConfig.MONSTER_POOL

	for _, position in candidates do
		if #list >= graveCount then
			break
		end
		if GridService.isOccupied(plotModel, position) then
			continue
		end
		if not GridService.tryOccupy(plotModel, position, nil) then
			continue
		end
		GridService.setGraveFlag(plotModel, position, true)

		local worldPos = GridService.getWorldPosition(plotModel, position)
		if not worldPos then
			GridService.release(plotModel, position)
			continue
		end

		local model = createGraveModel()
		model.Parent = gravesFolder(plotModel)
		ModelUtil.snapFeetToTileTop(model, worldPos)
		local restPivot = model:GetPivot()
		playRiseFromTile(model, restPivot, #list * GraveConfig.RISE_STAGGER, nil, function()
			-- Rise finished — keep this as the shake rest pose.
		end)

		table.insert(list, {
			plotModel = plotModel,
			position = position,
			model = model,
			nextSpawnAt = now + randomInterval(emergeMin, emergeMax),
			monsterPool = pool,
			busting = false,
			hitsRemaining = GraveConfig.PATAPIM_HITS,
			restPivot = restPivot,
			collapsing = false,
		})
	end

	gravesByPlot[plotModel] = list
	spawningClosed[plotModel] = false
	log:info(string.format("placed %d grave(s) on %s", #list, plotModel.Name))
end

function GraveService.init()
end

function GraveService.start()
	if (GraveService :: any)._started then
		return
	end
	(GraveService :: any)._started = true

	task.spawn(function()
		while true do
			task.wait(GraveConfig.TICK)
			for plotModel, list in gravesByPlot do
				if BattleClock.isPaused(plotModel) then continue end
				local now = BattleClock.now(plotModel)
				if spawningClosed[plotModel] then
					continue
				end
				for _, runtime in list do
					if not runtime.busting and now >= runtime.nextSpawnAt then
						emerge(runtime)
					end
				end
			end
		end
	end)

	log:info("started")
end

return GraveService
