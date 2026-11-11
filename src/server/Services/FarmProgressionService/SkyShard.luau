--!strict
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.FarmProgressionConfig)
local Monsters = require(Shared.Monsters)
local SkyShard = {}

function SkyShard.spawn(player: Player, plot: Model, id: string, collect: () -> ()): () -> ()
	local grid = plot:FindFirstChild("Grid")
	local tiles = if grid then grid:GetChildren() else {}
	if #tiles == 0 then return function() end end
	local tile = tiles[Random.new():NextInteger(1, #tiles)]
	if not tile:IsA("BasePart") then return function() end end
	local target = tile.Position + Vector3.new(0, 2.5, 0)
	local shard = Instance.new("Part")
	shard.Name = "MonsterShard_" .. id
	shard.Size = Vector3.new(1.5, 2.5, 1.5)
	shard.Material = Enum.Material.Neon
	shard.Color = if Config.MONSTERS[id].major then Color3.fromRGB(255, 205, 70) else Color3.fromRGB(190, 100, 255)
	shard.Anchored = true
	shard.CanCollide, shard.CanTouch, shard.CanQuery = false, false, false
	shard.Position = target + Vector3.new(0, Config.SKY_DROP_HEIGHT, 0)
	shard.Parent = plot
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Collect shard"
	prompt.ObjectText = Monsters.get(id).name .. " Shard"
	prompt.MaxActivationDistance = Config.SKY_PICKUP_RADIUS
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = shard
	local alive, landed = true, false
	local tween = TweenService:Create(shard, TweenInfo.new(Config.SKY_FALL_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = target })
	local function cleanup()
		if not alive then return end
		alive = false
		tween:Cancel()
		shard:Destroy()
	end
	prompt.Triggered:Connect(function(actor)
		if actor ~= player or not alive or not landed then return end
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
	task.delay(Config.SKY_LIFETIME, cleanup)
	return cleanup
end

return SkyShard
