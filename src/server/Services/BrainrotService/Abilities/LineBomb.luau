--!strict
--[[
	LineBomb (Bombardino Crocodilo)
	On place: detach the plant and fly it house → enemy while dropping one
	Assets.Projectiles.Bomb onto each tile. Fly duration is
	(COLUMNS - 1) * DROP_STAGGER so the croc reaches each column as that bomb
	is released. Bombs fall nose-down; on impact they despawn into a tile
	explosion + column damage.
]]

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotConfig = require(ReplicatedStorage.Shared.Config.BrainrotConfig)
local Constants = require(ReplicatedStorage.Shared.Constants)
local GridConfig = require(ReplicatedStorage.Shared.Config.GridConfig)
local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)
local ModelUtil = require(ReplicatedStorage.Shared.Utilities.ModelUtil)

local CombatService = require(script.Parent.Parent.Parent.CombatService)
local GridService = require(script.Parent.Parent.Parent.GridService)

local LineBomb = {}

local log = Logger.new("LineBomb")
local missingBombLogged = false
local activeModels: { [Model]: boolean } = {}

local SCRIPT_CLASSES: { [string]: boolean } = {
	Script = true,
	LocalScript = true,
	ModuleScript = true,
}

local function projectilesFolder(plotModel: Model): Folder
	local folder = plotModel:FindFirstChild("Projectiles")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Projectiles"
		folder.Parent = plotModel
	end
	return folder :: Folder
end

local function dropOrientation(): CFrame
	local o = BrainrotConfig.LINE_BOMB_DROP_ORIENTATION_DEGREES
	return CFrame.Angles(math.rad(o.X), math.rad(o.Y), math.rad(o.Z))
end

local function hardenModel(model: Model): BasePart?
	for _, descendant in model:GetDescendants() do
		if SCRIPT_CLASSES[descendant.ClassName] or descendant:IsA("Tool") or descendant:IsA("Sound") then
			descendant:Destroy()
		end
	end

	local primary = model.PrimaryPart
	if not primary then
		local best: BasePart? = nil
		local bestVolume = 0
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.Transparency < 0.95 then
				local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
				if volume > bestVolume then
					bestVolume = volume
					best = descendant
				end
			end
		end
		primary = best
	end
	if not primary then
		return nil
	end
	model.PrimaryPart = primary

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
	return primary
end

local function scaleToExtent(model: Model, targetExtent: number)
	local size = select(1, ModelUtil.getVisualSizeAndCenter(model))
	local extent = math.max(size.X, size.Y, size.Z)
	if extent < 0.01 or targetExtent < 0.01 then
		return
	end
	model:ScaleTo(model:GetScale() * math.clamp(targetExtent / extent, 0.05, 20))
	hardenModel(model)
end

local function createBombModel(): Model?
	local template = ModelUtil.findProjectileTemplate(BrainrotConfig.LINE_BOMB_MODEL_ID)
	if template then
		local bomb = template:Clone()
		bomb.Name = "BombardinoBomb"
		if not hardenModel(bomb) then
			bomb:Destroy()
			return nil
		end
		scaleToExtent(bomb, BrainrotConfig.LINE_BOMB_TARGET_EXTENT)
		return bomb
	end

	if not missingBombLogged then
		missingBombLogged = true
		log:warn(string.format(
			"missing Assets.Projectiles.%s — using procedural bomb Part",
			BrainrotConfig.LINE_BOMB_MODEL_ID
		))
	end

	local model = Instance.new("Model")
	model.Name = "BombardinoBomb"
	local part = Instance.new("Part")
	part.Name = "Body"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(2.4, 2.4, 2.4)
	part.Color = Color3.fromRGB(40, 40, 40)
	part.Material = Enum.Material.Metal
	part.Parent = model
	model.PrimaryPart = part
	hardenModel(model)
	return model
end

local function tweenPivot(
	model: Model,
	startPivot: CFrame,
	endPivot: CFrame,
	duration: number,
	easing: Enum.EasingStyle,
	direction: Enum.EasingDirection
)
	if duration <= 0 then
		model:PivotTo(endPivot)
		return
	end
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
		TweenInfo.new(duration, easing, direction),
		{ Value = 1 }
	)
	tween:Play()
	tween.Completed:Wait()
	connection:Disconnect()
	alpha:Destroy()
	if model.Parent then
		model:PivotTo(endPivot)
	end
end

local function flyerWorldPosition(plotModel: Model, row: number, column: number, model: Model): Vector3?
	local tileTop = GridService.getWorldPositionAtColumn(plotModel, row, column)
	if not tileTop then
		return nil
	end
	local halfHeight = model:GetExtentsSize().Y * 0.5
	return tileTop + Vector3.new(0, BrainrotConfig.LINE_BOMB_FLY_HEIGHT + halfHeight, 0)
end

local function dropBombOnTile(ctx, column: number, muteExplosionSound: boolean)
	local tileTop = GridService.getWorldPositionAtColumn(ctx.plotModel, ctx.position.row, column)
	if not tileTop then
		return
	end

	local bomb = createBombModel()
	if not bomb then
		CombatService.dealColumnDamage(
			ctx.plotModel,
			ctx.position.row,
			column,
			ctx.definition.damage,
			ctx.ownerUserId,
			ctx.definition.id
		)
		CombatService.fireTileExplosion(ctx.ownerUserId, ctx.position.row, column, muteExplosionSound)
		return
	end

	local halfHeight = bomb:GetExtentsSize().Y * 0.5
	local orient = dropOrientation()
	local startPos = tileTop + Vector3.new(0, BrainrotConfig.LINE_BOMB_DROP_HEIGHT + halfHeight, 0)
	local landPos = tileTop + Vector3.new(0, halfHeight, 0)
	local startPivot = CFrame.new(startPos) * orient
	local landPivot = CFrame.new(landPos) * orient

	activeModels[bomb] = true
	bomb.Parent = projectilesFolder(ctx.plotModel)
	bomb:PivotTo(startPivot)

	tweenPivot(
		bomb,
		startPivot,
		landPivot,
		BrainrotConfig.LINE_BOMB_FALL_DURATION,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)

	activeModels[bomb] = nil
	if bomb.Parent then
		bomb:Destroy()
	end

	CombatService.dealColumnDamage(
		ctx.plotModel,
		ctx.position.row,
		column,
		ctx.definition.damage,
		ctx.ownerUserId,
		ctx.definition.id
	)
	CombatService.fireTileExplosion(ctx.ownerUserId, ctx.position.row, column, muteExplosionSound)
end

local function flyPlant(ctx, plantModel: Model, travelTime: number)
	if not hardenModel(plantModel) then
		plantModel:Destroy()
		return
	end

	CollectionService:RemoveTag(plantModel, Constants.TAGS.Brainrot)
	plantModel.Name = "BombardinoFlight"
	activeModels[plantModel] = true
	plantModel.Parent = projectilesFolder(ctx.plotModel)

	local startPos = flyerWorldPosition(ctx.plotModel, ctx.position.row, 1, plantModel)
	local endPos = flyerWorldPosition(ctx.plotModel, ctx.position.row, GridConfig.COLUMNS, plantModel)
	if not startPos or not endPos then
		activeModels[plantModel] = nil
		plantModel:Destroy()
		return
	end

	local rotationOnly = plantModel:GetPivot() - plantModel:GetPivot().Position
	local startPivot = CFrame.new(startPos) * rotationOnly
	local endPivot = CFrame.new(endPos) * rotationOnly
	plantModel:PivotTo(startPivot)

	tweenPivot(
		plantModel,
		startPivot,
		endPivot,
		travelTime,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.InOut
	)

	activeModels[plantModel] = nil
	if plantModel.Parent then
		plantModel:Destroy()
	end
end

local function runBombardment(ctx, plantModel: Model)
	local columns = GridConfig.COLUMNS
	local stagger = BrainrotConfig.LINE_BOMB_DROP_STAGGER
	-- Reach column N at the same moment that column's bomb is released.
	local travelTime = math.max(0, (columns - 1) * stagger)

	task.spawn(function()
		flyPlant(ctx, plantModel, travelTime)
	end)

	for column = 1, columns do
		if not ctx.plotModel.Parent then
			return
		end
		task.spawn(function()
			dropBombOnTile(ctx, column, column > 1)
		end)
		if column < columns then
			task.wait(stagger)
		end
	end
end

function LineBomb.onPlaced(ctx, callbacks)
	local plantModel = callbacks.detachSelf()
	if not plantModel then
		return
	end

	callbacks.playSound("LineBomb")
	task.spawn(function()
		runBombardment(ctx, plantModel)
	end)
end

function LineBomb.clearPlot(plotModel: Model)
	local toDestroy: { Model } = {}
	for model in activeModels do
		if model.Parent and model:IsDescendantOf(plotModel) then
			table.insert(toDestroy, model)
		end
		activeModels[model] = nil
	end
	for _, model in toDestroy do
		model:Destroy()
	end
end

return LineBomb
