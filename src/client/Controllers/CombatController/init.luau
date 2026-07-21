--!strict
--[[
	CombatController
	Client-side combat visuals pushed by the server (CombatVisual remote).
	Gameplay stays server-side; this only renders feedback on the local plot.

	Milestone 11 — projectiles, explosions, hit/death particles.
	Milestone 12 — hit/death SFX (never block the visual handler on folder waits).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local AudioConfig = require(Shared.Config.AudioConfig)
local CombatConfig = require(Shared.Config.CombatConfig)
local GridConfig = require(Shared.Config.GridConfig)
local VfxConfig = require(Shared.Config.VfxConfig)
local Constants = require(Shared.Constants)
local Remotes = require(Shared.Remotes)
local Logger = require(Shared.Utilities.Logger)

local PlotUtil = require(script.Parent.Parent.Utilities.PlotUtil)
local VfxUtil = require(script.Parent.Parent.Utilities.VfxUtil)
local AudioController = require(script.Parent.AudioController)

local CombatController = {}
CombatController.Name = "CombatController"

local log = Logger.new(CombatController.Name)

local projectileWatchConnected = false

local function findModelByInstanceId(instanceId: string): Model?
	local plotModel = PlotUtil.getLocalPlotModel()
	if plotModel then
		for _, folderName in { "Monsters", "Brainrots" } do
			local folder = plotModel:FindFirstChild(folderName)
			if folder then
				for _, child in folder:GetChildren() do
					if child:IsA("Model") and child:GetAttribute("InstanceId") == instanceId then
						return child
					end
				end
			end
		end
	end

	for _, tag in { Constants.TAGS.Brainrot, Constants.TAGS.Monster } do
		for _, model in CollectionService:GetTagged(tag) do
			if model:IsA("Model") and model:GetAttribute("InstanceId") == instanceId then
				return model
			end
		end
	end
	return nil
end

local function flashHit(instanceId: string?)
	if not instanceId then
		return
	end
	local model = findModelByInstanceId(instanceId)
	if not model then
		return
	end

	-- Red flash is applied on the server (client Color is overwritten by replication).
	local center = PlotUtil.getModelBodyCenter(model)
	if center then
		VfxUtil.playHitBurst(center)
	end
end

local function playDeathVfx(instanceId: string?)
	if not instanceId then
		return
	end
	local model = findModelByInstanceId(instanceId)
	if not model then
		return
	end

	-- Fall / linger / fade run on the server (replicated). Client: burst + hide bars.
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BillboardGui") then
			descendant.Enabled = false
		end
	end

	local center = PlotUtil.getModelBodyCenter(model)
	if center then
		VfxUtil.playDeathBurst(center)
	end

	-- Thanos-style ash when the corpse fades (after tip-over + linger).
	local disintegrateAt = CombatConfig.DEATH_FALL_DURATION + CombatConfig.DEATH_CORPSE_LINGER
	task.delay(disintegrateAt, function()
		local corpse = findModelByInstanceId(instanceId)
		if corpse and corpse.Parent then
			VfxUtil.playDeathDisintegrate(corpse)
		end
	end)
end

local function playExplosion(row: number?, column: number?, entireRow: boolean?, staggerOverride: number?)
	if type(row) ~= "number" then
		return
	end
	local plotModel = PlotUtil.getLocalPlotModel()
	if not plotModel then
		return
	end

	if entireRow == true then
		local stagger = if type(staggerOverride) == "number" then staggerOverride else VfxConfig.ROW_EXPLOSION_STAGGER
		for col = 1, GridConfig.COLUMNS do
			local position = PlotUtil.getTileTopCenter(plotModel, row, col)
			if position then
				local delaySec = (col - 1) * stagger
				if delaySec <= 0 then
					VfxUtil.playTileExplosion(position)
				else
					task.delay(delaySec, function()
						VfxUtil.playTileExplosion(position)
					end)
				end
			end
		end
		return
	end

	if type(column) ~= "number" then
		return
	end
	local position = PlotUtil.getTileTopCenter(plotModel, row, column)
	if position then
		VfxUtil.playExplosion(position)
	end
end

local function watchProjectile(instance: Instance)
	local part: BasePart? = nil
	if instance:IsA("BasePart") then
		part = instance
	elseif instance:IsA("Model") then
		part = instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end
	if part then
		VfxUtil.decorateProjectile(part)
	end
end

-- Non-blocking: never WaitForChild here — that delayed Death SFX by seconds when
-- only melee Brainrots were used (Projectiles folder is created lazily by knives).
local function tryConnectProjectileWatcher(): boolean
	if projectileWatchConnected then
		return true
	end
	local plotModel = PlotUtil.getLocalPlotModel()
	if not plotModel then
		return false
	end

	local folder = plotModel:FindFirstChild("Projectiles")
	if not folder then
		return false
	end

	projectileWatchConnected = true
	for _, child in folder:GetChildren() do
		watchProjectile(child)
	end
	folder.ChildAdded:Connect(watchProjectile)
	return true
end

local function playDeathSound(monsterId: unknown)
	if type(monsterId) == "string" then
		local keyed = "Death_" .. monsterId
		if AudioConfig.SFX[keyed] then
			AudioController.play(keyed)
			return
		end
	end
	AudioController.play("Death")
end

local function playHitSound(soundKey: unknown)
	if type(soundKey) == "string" and AudioConfig.SFX[soundKey] then
		AudioController.play(soundKey)
	else
		AudioController.play("Hit")
	end
end

local function onCombatVisual(payload: unknown)
	if type(payload) ~= "table" then
		return
	end
	local data = payload :: { [string]: any }
	local kind = data.kind

	-- Audio first — never gate SFX behind projectile-folder setup.
	if kind == "Hit" then
		if data.muteSound ~= true then
			playHitSound(data.soundKey)
		end
		flashHit(data.instanceId)
	elseif kind == "Death" then
		playDeathSound(data.monsterId)
		playDeathVfx(data.instanceId)
	elseif kind == "Explosion" then
		if data.muteSound ~= true then
			AudioController.play("Explosion")
		end
		playExplosion(data.row, data.column, data.entireRow == true, data.stagger)
	end

	tryConnectProjectileWatcher()
end

function CombatController.init()
end

function CombatController.start()
	Remotes.getEvent("CombatVisual").OnClientEvent:Connect(onCombatVisual)

	task.spawn(function()
		for _ = 1, 40 do
			if tryConnectProjectileWatcher() then
				break
			end
			task.wait(0.25)
		end
	end)

	log:info("started")
end

return CombatController
