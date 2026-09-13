--!strict
--[[
	SahurWrath (Tung Tung GOD)
	Same Tung Bat as Ranged Rampage: appears above the plant, expands,
	stretches east to the plot edge, then slams the row for damagePercent
	of current bat damage.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local EvolutionConfig = require(ReplicatedStorage.Shared.Config.EvolutionConfig)
local GridConfig = require(ReplicatedStorage.Shared.Config.GridConfig)
local ModelUtil = require(ReplicatedStorage.Shared.Utilities.ModelUtil)

local CombatService = require(script.Parent.Parent.Parent.CombatService)
local GridService = require(script.Parent.Parent.Parent.GridService)
local Projectile = require(script.Parent.Parent.Parent.CombatService.Projectile)

type RestPart = {
	part: BasePart,
	size: Vector3,
	relPos: Vector3,
	relRot: CFrame,
	stretchAxis: string,
}

local SahurWrath = {}

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

local function layAlongLane(model: Model, position: Vector3): CFrame
	local o = CombatConfig.BAT_MODEL_ORIENTATION_DEGREES
	local orient = CFrame.Angles(math.rad(o.X), math.rad(o.Y), math.rad(o.Z))
	model:PivotTo(CFrame.new(position) * orient)
	local size = model:GetExtentsSize()
	local align = CFrame.new()
	if size.Y >= size.X and size.Y >= size.Z then
		align = CFrame.Angles(0, 0, math.rad(90))
	elseif size.Z >= size.X then
		align = CFrame.Angles(0, math.rad(90), 0)
	end
	local pivot = CFrame.new(position) * align * orient
	model:PivotTo(pivot)
	return pivot
end

local function stretchAxisFor(relRot: CFrame): string
	local right = relRot.RightVector
	local up = relRot.UpVector
	local look = relRot.LookVector
	local ax = math.abs(right.X)
	local ay = math.abs(up.X)
	local az = math.abs(look.X)
	if ax >= ay and ax >= az then
		return "X"
	end
	if ay >= az then
		return "Y"
	end
	return "Z"
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
				stretchAxis = stretchAxisFor(relRot),
			})
		end
	end
	return rests
end

local function applyPose(rests: { RestPart }, origin: CFrame, stretch: number)
	for _, rest in rests do
		if not rest.part.Parent then
			continue
		end
		local sx = rest.size.X
		local sy = rest.size.Y
		local sz = rest.size.Z
		if rest.stretchAxis == "X" then
			sx *= stretch
		elseif rest.stretchAxis == "Y" then
			sy *= stretch
		else
			sz *= stretch
		end
		rest.part.Size = Vector3.new(sx, sy, sz)
		local pos = Vector3.new(rest.relPos.X * stretch, rest.relPos.Y, rest.relPos.Z)
		rest.part.CFrame = origin * CFrame.new(pos) * rest.relRot
	end
end

local function runSlam(
	ctx,
	callbacks,
	damage: number
)
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
	local westX = plant:GetPivot().Position.X
	local hoverY = visCenter.Y + visSize.Y * 0.5 + CombatConfig.WRATH_HOVER_OFFSET
	local slamY = tile.Y + CombatConfig.WRATH_SLAM_HEIGHT
	local z = tile.Z

	local bat = Projectile.createBatVisual()
	bat.Name = "SahurWrathBat"
	bat:SetAttribute("ProjectileKind", "Bat")
	bat.Parent = projectilesFolder(plotModel)
	layAlongLane(bat, Vector3.new(westX, hoverY, z))
	applyGodHighlight(bat)

	local startScale = bat:GetScale()
	local expandedScale = startScale * CombatConfig.WRATH_EXPAND_SCALE
	tweenAlpha(CombatConfig.WRATH_EXPAND_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function(alpha)
		if bat.Parent then
			bat:ScaleTo(startScale + (expandedScale - startScale) * alpha)
		end
	end)
	if not bat.Parent then
		return
	end

	destroyWelds(bat)
	local cf, aabb = bat:GetBoundingBox()
	local minX = cf.Position.X - aabb.X * 0.5
	local currentLen = math.max(aabb.X, 0.05)
	local desiredLen = math.max(east.X - westX, currentLen)
	local rests = captureRest(bat, CFrame.new(minX, hoverY, z))
	local targetStretch = desiredLen / currentLen

	tweenAlpha(CombatConfig.WRATH_STRETCH_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function(alpha)
		if bat.Parent then
			local ox = minX + (westX - minX) * alpha
			applyPose(rests, CFrame.new(ox, hoverY, z), 1 + (targetStretch - 1) * alpha)
		end
	end)
	if not bat.Parent then
		return
	end

	tweenAlpha(CombatConfig.WRATH_SLAM_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In, function(alpha)
		if bat.Parent then
			local y = hoverY + (slamY - hoverY) * alpha
			applyPose(rests, CFrame.new(westX, y, z), targetStretch)
		end
	end)
	if not bat.Parent or not plotModel.Parent then
		if bat.Parent then
			bat:Destroy()
		end
		return
	end

	callbacks.playSound("MeleeBat")
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
	if #CombatService.getAllMonstersInRow(ctx.plotModel, ctx.position.row) == 0 then
		return false
	end

	local percent = 1000
	local params = ctx.extraParams
	if type(params) == "table" then
		percent = params.damagePercent or percent
	end
	local damage = math.max(1, math.floor(ctx.definition.damage * percent / 100))

	callbacks.pulseAttack()
	task.spawn(function()
		runSlam(ctx, callbacks, damage)
	end)
	return true
end

return SahurWrath
