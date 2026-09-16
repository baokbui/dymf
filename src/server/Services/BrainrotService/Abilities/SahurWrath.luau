--!strict
--[[
	SahurWrath (Tung Tung GOD)
	Same Tung Bat as Ranged Rampage: grows vertically above the plant (wide
	club) to the remaining lane length, then Tung's melee swing arcs it
	onto the row so it covers every tile from him to the east plot edge.

	Gates: 4+ combat targets in the row, or a boss occupying the row.
	If several GOD Tungs in the same row are ready, the easternmost (closest
	to incoming monsters) slams first; others stay ready until it finishes.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local EvolutionConfig = require(ReplicatedStorage.Shared.Config.EvolutionConfig)
local GridConfig = require(ReplicatedStorage.Shared.Config.GridConfig)
local ModelUtil = require(ReplicatedStorage.Shared.Utilities.ModelUtil)
local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)

local CombatService = require(script.Parent.Parent.Parent.CombatService)
local GridService = require(script.Parent.Parent.Parent.GridService)
local Projectile = require(script.Parent.Parent.Parent.CombatService.Projectile)

type RestPart = {
	part: BasePart,
	size: Vector3,
	relPos: Vector3,
	relRot: CFrame,
}

local SahurWrath = {}

local log = Logger.new("SahurWrath")

-- One slam at a time per plot row so two ready Tungs cannot overlap.
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

local function rowQualifies(plotModel: Model, row: number, minEnemies: number): boolean
	if CombatService.rowHasBoss(plotModel, row) then
		return true
	end
	return #CombatService.getAllMonstersInRow(plotModel, row) >= minEnemies
end

local function projectilesFolder(plotModel: Model): Folder
	local folder = plotModel:FindFirstChild("Projectiles")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Projectiles"
		folder.Parent = plotModel
	end
	return folder :: Folder
end

local function tweenAlpha(
	duration: number,
	easing: Enum.EasingStyle,
	direction: Enum.EasingDirection,
	apply: (alpha: number) -> ()
)
	if duration <= 0 then
		apply(1)
		return
	end
	local value = Instance.new("NumberValue")
	value.Value = 0
	local conn = value:GetPropertyChangedSignal("Value"):Connect(function()
		apply(value.Value)
	end)
	local tween = TweenService:Create(value, TweenInfo.new(duration, easing, direction), { Value = 1 })
	tween:Play()
	tween.Completed:Wait()
	conn:Disconnect()
	value:Destroy()
end

local function destroyWelds(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("WeldConstraint") or descendant:IsA("Weld") or descendant:IsA("Motor6D") then
			descendant:Destroy()
		end
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
end

local function applyGodHighlight(model: Model)
	local color = EvolutionConfig.auraForRarity("God")
	local highlight = Instance.new("Highlight")
	highlight.Name = "WrathHighlight"
	highlight.Adornee = model
	highlight.FillColor = color
	highlight.FillTransparency = 0.72
	highlight.OutlineColor = Color3.fromRGB(255, 230, 255)
	highlight.OutlineTransparency = 0.15
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
end

-- Longest extent stands on +Y so the grow reads as "up from the head".
local function standUpright(model: Model, position: Vector3)
	local o = CombatConfig.BAT_MODEL_ORIENTATION_DEGREES
	local orient = CFrame.Angles(math.rad(o.X), math.rad(o.Y), math.rad(o.Z))
	model:PivotTo(CFrame.new(position) * orient)
	local size = model:GetExtentsSize()
	local align = CFrame.new()
	if size.X >= size.Y and size.X >= size.Z then
		align = CFrame.Angles(0, 0, math.rad(90))
	elseif size.Z >= size.Y then
		align = CFrame.Angles(math.rad(90), 0, 0)
	end
	model:PivotTo(CFrame.new(position) * align * orient)
end

local function captureRest(model: Model, origin: CFrame): { RestPart }
	local rests: { RestPart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local rel = origin:ToObjectSpace(descendant.CFrame)
			local relRot = rel - rel.Position
			table.insert(rests, {
				part = descendant,
				size = descendant.Size,
				relPos = rel.Position,
				relRot = relRot,
			})
		end
	end
	return rests
end

-- Grow up from the origin (head) and fatten on X/Z so it stays a club.
local function applyPose(rests: { RestPart }, origin: CFrame, heightMul: number, widthMul: number)
	for _, rest in rests do
		if not rest.part.Parent then
			continue
		end
		local rightY = math.abs(rest.relRot.RightVector.Y)
		local upY = math.abs(rest.relRot.UpVector.Y)
		local lookY = math.abs(rest.relRot.LookVector.Y)
		local sx = rest.size.X * (widthMul + (heightMul - widthMul) * rightY)
		local sy = rest.size.Y * (widthMul + (heightMul - widthMul) * upY)
		local sz = rest.size.Z * (widthMul + (heightMul - widthMul) * lookY)
		rest.part.Size = Vector3.new(sx, sy, sz)
		local pos = Vector3.new(rest.relPos.X * widthMul, rest.relPos.Y * heightMul, rest.relPos.Z * widthMul)
		rest.part.CFrame = origin * CFrame.new(pos) * rest.relRot
	end
end

local function slamDuration(ctx): number
	local delay = ctx.definition.attackHitDelay
	if type(delay) == "number" and delay > 0 then
		return delay
	end
	return CombatConfig.WRATH_SLAM_DURATION
end

local function runSlam(ctx, callbacks, damage: number)
	local plotModel = ctx.plotModel
	local plant = ctx.model
	if not plotModel.Parent or not plant.Parent then
		return
	end

	local tile = GridService.getWorldPositionAtColumn(plotModel, ctx.position.row, ctx.position.column)
	local east = GridService.getWorldPositionAtColumn(
		plotModel,
		ctx.position.row,
		GridConfig.COLUMNS + CombatConfig.WRATH_EAST_EDGE
	)
	if not tile or not east then
		return
	end

	local visSize, visCenter = ModelUtil.getVisualSizeAndCenter(plant)
	local originX = visCenter.X + CombatConfig.WRATH_FRONT_GAP
	local headY = visCenter.Y + visSize.Y * 0.5 + CombatConfig.WRATH_HOVER_OFFSET
	local slamY = tile.Y + CombatConfig.WRATH_SLAM_HEIGHT
	local z = visCenter.Z
	local desiredLen = math.max(east.X - originX, 0.05)

	local bat = Projectile.createBatVisual()
	bat.Name = "SahurWrathBat"
	bat:SetAttribute("ProjectileKind", "Bat")
	bat.Parent = projectilesFolder(plotModel)
	standUpright(bat, Vector3.new(originX, headY, z))
	local batSize, batCenter = ModelUtil.getVisualSizeAndCenter(bat)
	local bottom = batCenter.Y - batSize.Y * 0.5
	bat:PivotTo(bat:GetPivot() + Vector3.new(0, headY - bottom, 0))
	applyGodHighlight(bat)

	destroyWelds(bat)
	batSize, batCenter = ModelUtil.getVisualSizeAndCenter(bat)
	local currentLen = math.max(batSize.Y, 0.05)
	local lengthMul = desiredLen / currentLen
	local widthMul = CombatConfig.WRATH_WIDTH_SCALE
	local originHover = CFrame.new(originX, headY, z)
	local rests = captureRest(bat, originHover)

	tweenAlpha(CombatConfig.WRATH_EXPAND_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function(alpha)
		if bat.Parent then
			applyPose(
				rests,
				originHover,
				1 + (lengthMul - 1) * alpha,
				1 + (widthMul - 1) * alpha
			)
		end
	end)
	if not bat.Parent or not plant.Parent then
		if bat.Parent then
			bat:Destroy()
		end
		return
	end

	local dropTime = slamDuration(ctx)
	callbacks.pulseAttack()
	-- Quarter-circle chop: upright (+Y) → laid along the lane (+X), pivot at Tung.
	tweenAlpha(dropTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In, function(alpha)
		if bat.Parent then
			local y = headY + (slamY - headY) * alpha
			local origin = CFrame.new(originX, y, z) * CFrame.Angles(0, 0, -math.rad(90) * alpha)
			applyPose(rests, origin, lengthMul, widthMul)
		end
	end)
	if not bat.Parent or not plotModel.Parent then
		if bat.Parent then
			bat:Destroy()
		end
		return
	end

	callbacks.playSound("MeleeBat")
	CombatService.fireBatSlam(ctx.ownerUserId, plotModel, ctx.position.row)
	CombatService.dealEntireRowDamage(
		plotModel,
		ctx.position.row,
		ctx.position.column,
		damage,
		ctx.ownerUserId,
		{
			skipExplosion = true,
			sourceBrainrotId = ctx.definition.id,
		}
	)

	task.wait(CombatConfig.WRATH_LINGER)
	if bat.Parent then
		bat:Destroy()
	end
end

function SahurWrath.tryAct(ctx, callbacks)
	local minEnemies = CombatConfig.WRATH_MIN_ENEMIES
	local params = ctx.extraParams
	if type(params) == "table" and type(params.minEnemies) == "number" then
		minEnemies = params.minEnemies
	end

	if isRowBusy(ctx.plotModel, ctx.position.row) then
		return false
	end
	if not rowQualifies(ctx.plotModel, ctx.position.row, minEnemies) then
		return false
	end

	local BrainrotBehavior = require(script.Parent.Parent.BrainrotBehavior)
	if BrainrotBehavior.hasCloserReadyAlly(ctx.instanceId, "SahurWrath") then
		return false
	end

	local percent = 1000
	if type(params) == "table" then
		percent = params.damagePercent or percent
	end
	local damage = math.max(1, math.floor(ctx.definition.damage * percent / 100))

	setRowBusy(ctx.plotModel, ctx.position.row, true)
	task.spawn(function()
		local ok, err = pcall(runSlam, ctx, callbacks, damage)
		setRowBusy(ctx.plotModel, ctx.position.row, false)
		if not ok then
			log:warn(err)
		end
	end)
	return true
end

return SahurWrath
