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
local VfxLoad = require(Shared.Utilities.VfxLoad)

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

local function playTerrifyPulse(instanceId: string?)
	if not instanceId then
		return
	end
	local model = findModelByInstanceId(instanceId)
	if not model then
		return
	end
	local center = PlotUtil.getModelBodyCenter(model)
	if not center then
		return
	end
	-- Waves travel forward with the scream: along his facing (toward the
	-- house / lawn), matching DukeVampireTerrify's forward column AoE.
	local look = model:GetPivot().LookVector
	local screamDir = Vector3.new(look.X, 0, look.Z)
	VfxUtil.playTerrifySoundwave(center, screamDir)
end

local function playDizzy(instanceId: string?, duration: unknown)
	if not instanceId or type(duration) ~= "number" then
		return
	end
	local model = findModelByInstanceId(instanceId)
	if model then
		VfxUtil.playDizzy(model, duration)
		VfxUtil.playStatusFloater(model, "Stunned", VfxConfig.STATUS_FLOAT_STUN_COLOR)
	end
end

local function playPoison(instanceId: string?, duration: unknown)
	if not instanceId or type(duration) ~= "number" then
		return
	end
	local model = findModelByInstanceId(instanceId)
	if model then
		-- Purple wash is server-replicated on the model; client only pops the word.
		VfxUtil.playStatusFloater(model, "Poisoned", VfxConfig.STATUS_FLOAT_POISON_COLOR)
	end
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

local function playBatSlam(data: { [string]: any }, quality: VfxLoad.Quality)
	local raw = data.hits
	if type(raw) ~= "table" then
		return
	end

	for _, packed in raw do
		if type(packed) == "table" then
			local item = packed :: { [string]: any }
			if type(item.x) == "number" and type(item.y) == "number" and type(item.z) == "number" then
				VfxUtil.playBatSlam(Vector3.new(item.x, item.y, item.z), quality)
			end
		end
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
	if instance.Name == "SwordWaveProjectile" or instance.Name == "SwordWavePillar" then
		VfxUtil.applyHeavyQuality(instance, VfxLoad.isHighQuality())
	end
end

-- Pillar SFX follow the replicated VFX so the crescent whoosh (started 1s
-- before launch) cuts the moment the last-tile light pillar appears.
local function playSwordWaveAudio(instance: Instance)
	if instance.Name == "SwordWavePillar" then
		AudioController.stopSfx("SwordWave")
		AudioController.play("SwordWavePillar")
	end
end

local function refreshHeavyProjectiles()
	local plotModel = PlotUtil.getLocalPlotModel()
	if not plotModel then
		return
	end
	local folder = plotModel:FindFirstChild("Projectiles")
	if not folder then
		return
	end
	for _, child in folder:GetChildren() do
		if child.Name == "SwordWaveProjectile" or child.Name == "SwordWavePillar" then
			VfxUtil.applyHeavyQuality(child, VfxLoad.isHighQuality())
		end
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
	folder.ChildAdded:Connect(function(child)
		watchProjectile(child)
		playSwordWaveAudio(child)
	end)
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

local function playMonsterAttackSound(monsterId: unknown)
	if type(monsterId) == "string" then
		local keyed = "MonsterAttack_" .. monsterId
		if AudioConfig.SFX[keyed] then
			AudioController.play(keyed)
			return
		end
	end
	AudioController.play("MonsterAttack")
end

local function asVector3(x: any, y: any, z: any): Vector3?
	if type(x) == "number" and type(y) == "number" and type(z) == "number" then
		return Vector3.new(x, y, z)
	end
	return nil
end

local function playSandTornado(data: { [string]: any })
	local model: Model? = nil
	local instanceId = data.instanceId
	if type(instanceId) == "string" then
		model = findModelByInstanceId(instanceId)
	end

	local hand: BasePart? = nil
	if model then
		hand = VfxUtil.findStealHand(model)
	end

	local destination = asVector3(data.destX, data.destY, data.destZ)
	if not destination and hand then
		destination = hand.Position
	end
	if not destination and model then
		destination = PlotUtil.getModelBodyCenter(model)
	end
	if not destination then
		return
	end

	AudioController.play("SandTornado")

	local origins: { Vector3 } = {}
	if type(data.origins) == "table" then
		for _, point in data.origins do
			if typeof(point) == "Vector3" then
				table.insert(origins, point)
			elseif type(point) == "table" then
				local packed = point :: { [string]: any }
				local origin = asVector3(packed.x or packed.X, packed.y or packed.Y, packed.z or packed.Z)
				if origin then
					table.insert(origins, origin)
				end
			end
		end
	end

	VfxUtil.playSandTornado(destination, origins, hand)
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
	elseif kind == "BatSlam" then
		AudioController.play("Explosion")
		local quality, release = VfxLoad.acquire(VfxConfig.HEAVY_VFX_BAT_SLAM)
		playBatSlam(data, quality)
		task.delay(VfxConfig.HEAVY_VFX_BAT_SLAM_RELEASE, release)
	elseif kind == "Jackpot" then
		local origin = asVector3(data.x or data.X, data.y or data.Y, data.z or data.Z)
		if origin then
			local quality, release = VfxLoad.acquire(VfxConfig.HEAVY_VFX_JACKPOT)
			VfxUtil.playJackpotBurst(origin, quality)
			task.delay(VfxConfig.HEAVY_VFX_JACKPOT_RELEASE, release)
		end
	elseif kind == "Terrify" then
		AudioController.play("Terrify")
		playTerrifyPulse(data.instanceId)
	elseif kind == "SandTornado" then
		playSandTornado(data)
	elseif kind == "Dizzy" then
		playDizzy(data.instanceId, data.duration)
	elseif kind == "Poison" then
		playPoison(data.instanceId, data.duration)
	elseif kind == "WindGust" then
		local WeatherController = require(script.Parent.WeatherController)
		WeatherController.hidePlotFogVisual()
		local plotModel = PlotUtil.getLocalPlotModel()
		if plotModel then
			VfxUtil.playWindGust(plotModel)
		end
	elseif kind == "MonsterAttack" then
		playMonsterAttackSound(data.monsterId)
	end

	tryConnectProjectileWatcher()
end

function CombatController.init()
end

function CombatController.start()
	Remotes.getEvent("CombatVisual").OnClientEvent:Connect(onCombatVisual)
	VfxLoad.onHighQualityChanged(function()
		refreshHeavyProjectiles()
	end)

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
