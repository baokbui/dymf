--!strict
--[[
	AudioController
	Owns all client audio: SoundGroups, one-shot SFX, looping ambient, and
	background / boss music. Other controllers call play() / music helpers —
	they never create Sound instances themselves.

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

local activeSfx: { Sound } = {}
local lastBrainrotHealth: { [Model]: number } = {}

local function applyGroupVolumes()
	local master = if muted then 0 else AudioConfig.MASTER_VOLUME
	musicGroup.Volume = AudioConfig.MUSIC_VOLUME * master
	sfxGroup.Volume = AudioConfig.SFX_VOLUME * master
	ambientGroup.Volume = AudioConfig.AMBIENT_VOLUME * master
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

	musicGroup = getOrCreateGroup("Music")
	sfxGroup = getOrCreateGroup("Sfx")
	ambientGroup = getOrCreateGroup("Ambient")
	applyGroupVolumes()
end

local function applyDef(sound: Sound, def: AudioConfig.SoundDef, group: SoundGroup)
	sound.SoundId = def.SoundId
	sound.Volume = def.Volume or 1
	sound.PlaybackSpeed = def.PlaybackSpeed or 1
	sound.Looped = def.Looped == true
	sound.SoundGroup = group
end

local function pruneSfx()
	local alive: { Sound } = {}
	for _, sound in activeSfx do
		if sound.Parent and sound.IsPlaying then
			table.insert(alive, sound)
		elseif sound.Parent then
			sound:Destroy()
		end
	end
	activeSfx = alive

	while #activeSfx >= AudioConfig.MAX_SFX_INSTANCES do
		local oldest = table.remove(activeSfx, 1)
		if oldest then
			oldest:Stop()
			oldest:Destroy()
		end
	end
end

function AudioController.play(key: string)
	if muted then
		return
	end
	local def = AudioConfig.SFX[key]
	if not def or def.SoundId == "" then
		return
	end

	pruneSfx()

	local sound = Instance.new("Sound")
	sound.Name = "Sfx_" .. key
	applyDef(sound, def, sfxGroup)
	sound.Parent = SoundService
	table.insert(activeSfx, sound)
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
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
	local plot = PlotUtil.getLocalPlotModel()
	return plot ~= nil and model:IsDescendantOf(plot)
end

local function onMonsterAdded(instance: Instance)
	if not instance:IsA("Model") or not isOnLocalPlot(instance) then
		return
	end
	AudioController.play("MonsterSpawn")
	if instance:GetAttribute("IsBoss") == true then
		AudioController.setBossMusic(true)
	end
end

local function onBrainrotAdded(instance: Instance)
	if not instance:IsA("Model") or not isOnLocalPlot(instance) then
		return
	end
	local health = instance:GetAttribute("Health")
	if type(health) == "number" then
		lastBrainrotHealth[instance] = health
	end
	instance:GetAttributeChangedSignal("Health"):Connect(function()
		local current = instance:GetAttribute("Health")
		if type(current) ~= "number" then
			return
		end
		local previous = lastBrainrotHealth[instance]
		lastBrainrotHealth[instance] = current
		if previous and current < previous then
			AudioController.play("MonsterAttack")
		end
	end)
	instance.Destroying:Connect(function()
		lastBrainrotHealth[instance] = nil
	end)
end

function AudioController.init()
	ensureGroups()
end

function AudioController.start()
	AudioController.playMusic("Default")
	startAmbient()

	CollectionService:GetInstanceAddedSignal(Constants.TAGS.Monster):Connect(onMonsterAdded)
	for _, monster in CollectionService:GetTagged(Constants.TAGS.Monster) do
		onMonsterAdded(monster)
	end

	CollectionService:GetInstanceAddedSignal(Constants.TAGS.Brainrot):Connect(onBrainrotAdded)
	for _, brainrot in CollectionService:GetTagged(Constants.TAGS.Brainrot) do
		onBrainrotAdded(brainrot)
	end

	log:info("started")
end

return AudioController
