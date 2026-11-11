--!strict
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.SanctuaryConfig)
local ModelUtil = require(Shared.Utilities.ModelUtil)
local Fusion = require(Shared.Utilities.MonsterFusion)
local Farm = require(Shared.Utilities.FarmProgression)
local Resident = {}

local function addNameplate(model: Model, definition: any, monster: Fusion.Monster)
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not anchor then return end
	local bounds, size = model:GetBoundingBox()
	local attachment = Instance.new("Attachment")
	attachment.Name = "FarmNameplateAnchor"
	attachment.Position = anchor.CFrame:PointToObjectSpace(bounds.Position + Vector3.new(0, size.Y / 2, 0))
	attachment.Parent = anchor

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "FarmNameplate"
	billboard.Adornee = attachment
	billboard.Size = UDim2.fromOffset(220, 88)
	billboard.SizeOffset = Vector2.new(0, 0.5)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 0.8, 0)
	billboard.MaxDistance = 100
	billboard.Parent = model
	local tier = Fusion.tier(monster.tier)
	local function line(name: string, value: string, y: number, height: number, size: number, color: Color3)
		local label = Instance.new("TextLabel")
		label.Name, label.Text = name, value
		label.BackgroundTransparency = 1
		label.Position, label.Size = UDim2.fromOffset(0, y), UDim2.new(1, 0, 0, height)
		label.Font, label.TextSize = Enum.Font.GothamBold, size
		label.TextColor3 = color
		label.TextStrokeColor3, label.TextStrokeTransparency = Color3.fromRGB(20, 30, 23), 0.15
		label.Parent = billboard
	end
	line("Size", tier.id, 0, 20, 15, Color3.fromRGB(255, 218, 128))
	line("MonsterName", definition.name or definition.id, 20, 26, 18, Color3.new(1, 1, 1))
	line("Level", "Lv. " .. tier.level, 46, 18, 14, Color3.new(1, 1, 1))
	line("IncomeRate", "≈ " .. Farm.formatRate(Farm.monsterRate(monster)), 64, 22, 14, Color3.fromRGB(167, 245, 172))
end

function Resident.spawn(parent: Folder, definition: any, center: Vector3, bounds: Vector2, instance: Fusion.Monster?): () -> ()
	local monster = instance or { uid = definition.id, monsterId = definition.id, tier = "Medium" }
	local tier = Fusion.tier(monster.tier)
	local template = ModelUtil.findMonsterTemplate(definition.modelId or definition.id)
	local model: Model
	if template then
		model = ModelUtil.cloneTemplate(template, {
			targetHeight = Config.CREATURE_HEIGHT * tier.scale, targetFootprint = Config.CREATURE_FOOTPRINT * tier.scale,
			anchorAllParts = true, skipBodyAlias = true,
		})
	else
		model = Instance.new("Model")
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Size = Vector3.new(3, Config.CREATURE_HEIGHT, 3) * tier.scale
		body.Color = definition.color or Color3.fromRGB(133, 171, 108)
		body.Parent = model
		model.PrimaryPart = body
	end
	model.Name = monster.uid
	model:SetAttribute("MonsterId", monster.monsterId)
	model:SetAttribute("FarmMonsterId", monster.uid)
	model:SetAttribute("SizeTier", monster.tier)
	model:SetAttribute("Level", tier.level)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide, item.CanTouch, item.CanQuery = false, false, false
		end
	end
	local rng = Random.new()
	local function destination(): Vector3
		return center + Vector3.new(rng:NextNumber(-bounds.X, bounds.X), 0, rng:NextNumber(-bounds.Y, bounds.Y))
	end
	ModelUtil.pivotToTileTop(model, destination())
	addNameplate(model, definition, monster)
	model.Parent = parent
	local height = model:GetPivot().Position.Y - center.Y
	local driver = Instance.new("CFrameValue")
	driver.Value = model:GetPivot()
	local connection = driver.Changed:Connect(function(value) model:PivotTo(value) end)
	local alive = true
	local tween: Tween? = nil
	local thread = task.spawn(function()
		while alive and model.Parent do
			task.wait(rng:NextNumber(Config.MIN_PAUSE, Config.MAX_PAUSE))
			if not alive or not model.Parent then break end
			local target = destination() + Vector3.new(0, height, 0)
			local start = driver.Value.Position
			local distance = (target - start).Magnitude
			if distance < 0.1 then continue end
			local facing = CFrame.lookAt(start, Vector3.new(target.X, start.Y, target.Z))
			driver.Value = facing
			tween = TweenService:Create(driver, TweenInfo.new(distance / Config.ROAM_SPEED, Enum.EasingStyle.Linear),
				{ Value = facing + (target - start) })
			tween:Play()
			tween.Completed:Wait()
		end
	end)
	return function()
		alive = false
		task.cancel(thread)
		if tween then tween:Cancel() end
		connection:Disconnect()
		driver:Destroy()
		model:Destroy()
	end
end

return Resident
