--!strict
local BattleClock = require(game:GetService("ReplicatedStorage").Shared.Utilities.BattleClock)
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.FarmProgressionConfig)
local Monsters = require(Shared.Monsters)
local ShardModel = require(Shared.Utilities.ShardModel)
local VisualConfig = require(Shared.Config.ShardVisualConfig)
local SkyShard = {}

function SkyShard.spawn(player: Player, plot: Model, id: string, collect: () -> ()): () -> ()
	local grid = plot:FindFirstChild("Grid")
	local tiles = if grid then grid:GetChildren() else {}
	if #tiles == 0 then return function() end end
	local tile = tiles[Random.new():NextInteger(1, #tiles)]
	if not tile:IsA("BasePart") then return function() end end
	local target = tile.Position + Vector3.new(0, tile.Size.Y / 2 + VisualConfig.HEIGHT / 2 + VisualConfig.GROUND_CLEARANCE, 0)
	local shard = ShardModel.create(id)
	local root = shard.PrimaryPart :: BasePart
	shard:PivotTo(CFrame.new(target + Vector3.new(0, Config.SKY_DROP_HEIGHT, 0)))
	local driver = Instance.new("CFrameValue")
	driver.Value = shard:GetPivot()
	local movement = driver.Changed:Connect(function(value) shard:PivotTo(value) end)
	shard.Parent = plot
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Collect shard"
	prompt.ObjectText = Monsters.get(id).name .. " Shard"
	prompt.MaxActivationDistance = Config.SKY_PICKUP_RADIUS
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = root
	local alive, landed = true, false
	local tween = BattleClock.tween(player, driver, TweenInfo.new(Config.SKY_FALL_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = CFrame.new(target) })
	local function cleanup()
		if not alive then return end
		alive = false
		tween:Cancel()
		movement:Disconnect()
		driver:Destroy()
		shard:Destroy()
	end
	prompt.Triggered:Connect(function(actor)
		if actor ~= player or not alive or not landed or BattleClock.isPaused(player) then return end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or (root.Position - target).Magnitude > Config.SKY_PICKUP_RADIUS then return end
		if require(script.Parent.Parent.SaveService).isProgressionLocked(player) then return end
		cleanup()
		collect()
	end)
	tween.Completed:Once(function(status)
		if alive and status == Enum.PlaybackState.Completed then landed = true; prompt.Enabled = true end
	end)
	tween:Play()
	BattleClock.delay(player, Config.SKY_LIFETIME, cleanup)
	return cleanup
end

return SkyShard
