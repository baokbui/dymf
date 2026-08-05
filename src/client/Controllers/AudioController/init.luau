--!strict
--[[
	AudioController
	Owns all client audio: SoundGroups, one-shot SFX, looping ambient, and
	background / boss music. Other controllers call play() / music helpers —
	they never create Sounds themselves.

	Plot gameplay SFX (plant, attack, death, …) are owner-only: the server
	pushes remotes to the plot owner, and this client plays via SoundService
	(never spatial Sounds under the plot). Foreign-plot Sounds are silenced.

	Milestone 12.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local AudioConfig = require(Shared.Config.AudioConfig)
local Constants = require(Shared.Constants)
local Logger = require(Shared.Utilities.Logger)

local PlotUtil = require(script.Parent.Parent.Utilities.PlotUtil)
local SfxPlayer = require(script.SfxPlayer)

local AudioController = {}
AudioController.Name = "AudioController"

local log = Logger.new(AudioController.Name)
local localPlayer = Players.LocalPlayer

local musicGroup: SoundGroup
local sfxGroup: SoundGroup
local ambientGroup: SoundGroup

local musicSound: Sound? = nil
local ambientSound: Sound? = nil
local currentMusicKey: string? = nil
local bossMusicActive = false
local muted = false
local musicVolumeScale = 1
local sfxVolumeScale = 1
local ambientVolumeScale = 1
local brainrotSfxEnabled = true

local BRAINROT_SFX: { [string]: boolean } = {
	MeleeBat = true,
	FreezeTime = true,
	FreezeTimeEnd = true,
	BubbleTrap = true,
	LineBomb = true,
	PlaceBrainrot = true,
	PlaceBrainrot_BallerinaCappucina = true,
	PlaceBrainrot_TungTungSahur = true,
	PlaceBrainrot_TralaleroTralala = true,
	PlaceBrainrot_BombardinoCrocodilo = true,
	PlaceBrainrot_LiriliLarila = true,
	PlaceBrainrot_CappuccinoAssassino = true,
	PlaceBrainrot_ChimpanziniBananini = true,
	RemoveBrainrot = true,
	ThrowKnifeHit = true,
}

local function applyGroupVolumes()
	if not musicGroup then
		return
	end
	local master = if muted then 0 else AudioConfig.MASTER_VOLUME
	musicGroup.Volume = AudioConfig.MUSIC_VOLUME * master * musicVolumeScale
	sfxGroup.Volume = AudioConfig.SFX_VOLUME * master * sfxVolumeScale
	ambientGroup.Volume = AudioConfig.AMBIENT_VOLUME * master * ambientVolumeScale
end

local function ensureGroups()
	local folder = SoundService:FindFirstChild("BVM")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "BVM"
		folder.Parent = SoundService
	end

	local function getOrCreateGroup(name: string): SoundGroup
		local existing = folder:FindFirstChild(name)
		if existing and existing:IsA("SoundGroup") then
			return existing
		end
		local group = Instance.new("SoundGroup")
		group.Name = name
		group.Parent = folder
		return group
	end

	local preloadFolder = folder:FindFirstChild("Preload")
	if not (preloadFolder and preloadFolder:IsA("Folder")) then
		preloadFolder = Instance.new("Folder")
		preloadFolder.Name = "Preload"
		preloadFolder.Parent = folder
	end

	musicGroup = getOrCreateGroup("Music")
	sfxGroup = getOrCreateGroup("Sfx")
	ambientGroup = getOrCreateGroup("Ambient")
	SfxPlayer.bind(sfxGroup, preloadFolder :: Folder)
	applyGroupVolumes()
end

local function applyDef(sound: Sound, def: AudioConfig.SoundDef, group: SoundGroup)
	sound.SoundId = def.SoundId
	sound.Volume = def.Volume or 1
	sound.PlaybackSpeed = def.PlaybackSpeed or 1
	sound.Looped = def.Looped == true
	sound.SoundGroup = group
end

function AudioController.play(key: string)
	if BRAINROT_SFX[key] and not brainrotSfxEnabled then
		return
	end
	SfxPlayer.play(key)
end

function AudioController.stopSfx(key: string)
	SfxPlayer.stop(key)
end

local function fadeOutAndDestroy(sound: Sound, duration: number)
	local tween = TweenService:Create(
		sound,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Volume = 0 }
	)
	tween:Play()
	tween.Completed:Connect(function()
		sound:Stop()
		sound:Destroy()
	end)
end

function AudioController.playMusic(trackKey: string)
	local def = AudioConfig.MUSIC[trackKey]
	if not def or def.SoundId == "" then
		return
	end
	if currentMusicKey == trackKey and musicSound and musicSound.Parent then
		return
	end

	local fade = AudioConfig.MUSIC_FADE_DURATION
	if musicSound and musicSound.Parent then
		fadeOutAndDestroy(musicSound, fade)
		musicSound = nil
	end

	local sound = Instance.new("Sound")
	sound.Name = "Music_" .. trackKey
	applyDef(sound, def, musicGroup)
	sound.Volume = 0
	sound.Parent = SoundService
	musicSound = sound
	currentMusicKey = trackKey
	sound:Play()

	local targetVolume = def.Volume or 1
	TweenService:Create(
		sound,
		TweenInfo.new(fade, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Volume = targetVolume }
	):Play()
end

function AudioController.setBossMusic(active: boolean)
	if bossMusicActive == active then
		return
	end
	bossMusicActive = active
	AudioController.playMusic(if active then "Boss" else "Default")
end

function AudioController.isBossMusicActive(): boolean
	return bossMusicActive
end

function AudioController.setMuted(isMuted: boolean)
	muted = isMuted
	SfxPlayer.setMuted(isMuted)
	applyGroupVolumes()
	if muted then
		if musicSound then
			musicSound:Pause()
		end
		if ambientSound then
			ambientSound:Pause()
		end
	else
		if musicSound then
			musicSound:Resume()
		end
		if ambientSound then
			ambientSound:Resume()
		end
	end
end

function AudioController.setMusicVolumeScale(scale: number)
	musicVolumeScale = math.clamp(scale, 0, 1)
	applyGroupVolumes()
end

function AudioController.setSfxVolumeScale(scale: number)
	sfxVolumeScale = math.clamp(scale, 0, 1)
	applyGroupVolumes()
end

function AudioController.setBrainrotSfxEnabled(enabled: boolean)
	brainrotSfxEnabled = enabled
end

local function startAmbient()
	local def = AudioConfig.AMBIENT.Plot
	if not def or def.SoundId == "" then
		return
	end
	if ambientSound and ambientSound.Parent then
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = "Ambient_Plot"
	applyDef(sound, def, ambientGroup)
	sound.Parent = SoundService
	ambientSound = sound
	sound:Play()
end

local function isOnLocalPlot(model: Model): boolean
	return PlotUtil.isOnLocalPlot(model)
end

-- Silence any Sound that appears under another player's plot (Toolbox leftovers,
-- accidental server Sounds). Gameplay SFX are played via SoundService locally.
local function silenceForeignPlotSound(instance: Instance)
	if not instance:IsA("Sound") then
		return
	end
	local plot = PlotUtil.getOwningPlotModel(instance)
	if not plot then
		return
	end
	if plot:GetAttribute("OwnerUserId") == localPlayer.UserId then
		return
	end
	instance:Stop()
	instance.Volume = 0
	instance:Destroy()
end

local function watchPlotsForForeignAudio()
	local plotsFolder = workspace:FindFirstChild(Constants.WORKSPACE_FOLDERS.Plots)
	if not plotsFolder then
		return false
	end
	for _, descendant in plotsFolder:GetDescendants() do
		silenceForeignPlotSound(descendant)
	end
	plotsFolder.DescendantAdded:Connect(silenceForeignPlotSound)
	return true
end

local function onMonsterAdded(instance: Instance)
	if not instance:IsA("Model") or not isOnLocalPlot(instance) then
		return
	end
	if instance:GetAttribute("IsBoss") == true then
		AudioController.setBossMusic(true)
	end
end

-- Chew / club SFX are fired from the server via CombatVisual kind
-- `MonsterAttack` (per-monster keys like MonsterAttack_Goblin). Health-attribute
-- listeners were removed so goblin clubs don't double-play with the generic hit.

function AudioController.init()
	ensureGroups()
end

function AudioController.start()
	SfxPlayer.preload()
	AudioController.playMusic("Default")
	startAmbient()

	CollectionService:GetInstanceAddedSignal(Constants.TAGS.Monster):Connect(onMonsterAdded)
	for _, monster in CollectionService:GetTagged(Constants.TAGS.Monster) do
		onMonsterAdded(monster)
	end

	task.spawn(function()
		for _ = 1, 40 do
			if watchPlotsForForeignAudio() then
				break
			end
			task.wait(0.25)
		end
	end)

	log:info("started")
end

return AudioController
