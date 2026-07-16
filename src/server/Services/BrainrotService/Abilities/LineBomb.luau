--!strict
--[[
	LineBomb (Bombardino Crocodilo)
	On place: detach from the tile, nuke the row, fly house → enemy while
	tile blasts track under the pass, then despawn.

	Flight uses Model:PivotTo so multi-part Toolbox templates move as one.
]]

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotConfig = require(ReplicatedStorage.Shared.Config.BrainrotConfig)
local Constants = require(ReplicatedStorage.Shared.Constants)
local GridConfig = require(ReplicatedStorage.Shared.Config.GridConfig)

local CombatService = require(script.Parent.Parent.Parent.CombatService)
local GridService = require(script.Parent.Parent.Parent.GridService)

local LineBomb = {}

local activeFlights: { [Model]: boolean } = {}

local function projectilesFolder(plotModel: Model): Folder
	local folder = plotModel:FindFirstChild("Projectiles")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Projectiles"
		folder.Parent = plotModel
	end
	return folder :: Folder
end

local function bodyWorldPosition(plotModel: Model, row: number, column: number, model: Model): Vector3?
	local tileTop = GridService.getWorldPositionAtColumn(plotModel, row, column)
	if not tileTop then
		return nil
	end
	local halfHeight = model:GetExtentsSize().Y / 2
	return tileTop + Vector3.new(0, BrainrotConfig.LINE_BOMB_FLY_HEIGHT + halfHeight, 0)
end

local function runFlight(ctx, model: Model)
	local body = model.PrimaryPart or model:FindFirstChild("Body")
	if not body or not body:IsA("BasePart") then
		model:Destroy()
		return
	end

	activeFlights[model] = true
	CollectionService:RemoveTag(model, Constants.TAGS.Brainrot)
	model.Name = "BombardinoFlight"
	model.Parent = projectilesFolder(ctx.plotModel)

	local startPos = bodyWorldPosition(ctx.plotModel, ctx.position.row, 1, model)
	local endPos = bodyWorldPosition(ctx.plotModel, ctx.position.row, GridConfig.COLUMNS, model)
	if not startPos or not endPos then
		activeFlights[model] = nil
		model:Destroy()
		return
	end

	-- Keep placement orientation (includes modelOrientationDegrees). lookAt wiped it
	-- and pitched Toolbox meshes nose-down along the flight path.
	local rotationOnly = model:GetPivot() - model:GetPivot().Position
	local startPivot = CFrame.new(startPos) * rotationOnly
	local endPivot = CFrame.new(endPos) * rotationOnly
	model:PivotTo(startPivot)

	local duration = BrainrotConfig.LINE_BOMB_FLIGHT_DURATION
	local stagger = duration / math.max(1, GridConfig.COLUMNS)
	CombatService.dealEntireRowDamage(
		ctx.plotModel,
		ctx.position.row,
		ctx.position.column,
		ctx.definition.damage,
		ctx.ownerUserId,
		{ explosionStagger = stagger, muteExplosionSound = true }
	)

	local alpha = Instance.new("NumberValue")
	alpha.Value = 0
	local connection = alpha:GetPropertyChangedSignal("Value"):Connect(function()
		if not model.Parent then
			return
		end
		model:PivotTo(startPivot:Lerp(endPivot, alpha.Value))
	end)

	local tween = TweenService:Create(
		alpha,
		TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
		{ Value = 1 }
	)
	tween:Play()
	tween.Completed:Wait()
	connection:Disconnect()
	alpha:Destroy()

	activeFlights[model] = nil
	if model.Parent then
		model:Destroy()
	end
end

function LineBomb.onPlaced(ctx, callbacks)
	local model = callbacks.detachSelf()
	if not model then
		return
	end

	callbacks.playSound("LineBomb")
	task.spawn(function()
		runFlight(ctx, model)
	end)
end

function LineBomb.clearPlot(plotModel: Model)
	local toDestroy: { Model } = {}
	for model in activeFlights do
		if model.Parent and model:IsDescendantOf(plotModel) then
			table.insert(toDestroy, model)
		end
		activeFlights[model] = nil
	end
	for _, model in toDestroy do
		model:Destroy()
	end
end

return LineBomb
