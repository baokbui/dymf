--!strict
--[[
	AudioController
	Owns all client audio: SoundGroups, one-shot SFX, and weather / boss music.
	Other controllers call play() / music helpers — they never create Sounds
	themselves.

	The only looping BGM is weather theme + boss (big-wave warning). Plot
	gameplay SFX are owner-only via SoundService. Any Sound under a plot model
	(Toolbox leftovers on monsters, etc.) is destroyed.

	Milestone 12.
]]

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local AudioConfig = require(Shared.Config.AudioConfig)
local Constants = require(Shared.Constants)
local Logger = require(Shared.Utilities.Logger)
local Remotes = require(Shared.Remotes)
local WeatherUtil = require(Shared.Utilities.WeatherUtil)

local PlotUtil = require(script.Parent.Parent.Utilities.PlotUtil)
local SfxPlayer = require(script.SfxPlayer)

local AudioController = {}
AudioController.Name = "AudioController"

local log = Logger.new(AudioController.Name)
local musicGroup: SoundGroup
local sfxGroup: SoundGroup
local ambientGroup: SoundGroup

local musicSound: Sound? = nil
local ambientSound: Sound? = nil
local currentMusicKey: string? = nil
-- Non-boss loop from the current day's weather (Default / Night / Desert).
local themeMusicKey = "Default"
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
	PlaceBrainrot_BrrBrrPatapim = true,
	PlaceBrainrot_GiraffaCeleste = true,
	WindGust = true,
	GraveShake = true,
	GraveCollapse = true,
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

local function themeKeyForWeather(weather: string?): string
	if WeatherUtil.isDesert(weather) then
		return "Desert"
	end
	if WeatherUtil.isNight(weather) then
		return "Night"
	end
	return "Default"
end

function AudioController.setThemeFromWeather(weather: string?)
	local key = themeKeyForWeather(weather)
	if themeMusicKey == key then
		return
	end
	themeMusicKey = key
	if not bossMusicActive then
		AudioController.playMusic(key)
	end
end

function AudioController.setBossMusic(active: boolean)
	if bossMusicActive == active then
		return
	end
	bossMusicActive = active
	AudioController.playMusic(if active then "Boss" else themeMusicKey)
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

-- Destroy any Sound under a plot (Toolbox music on spawn, leftover asset
-- audio). Gameplay SFX are played via SoundService, not under plot models.
local function silencePlotSound(instance: Instance)
	if not instance:IsA("Sound") then
		return
	end
	if not PlotUtil.getOwningPlotModel(instance) then
		return
	end
	instance:Stop()
	instance.Volume = 0
	instance:Destroy()
end

local function watchPlotsForEmbeddedAudio()
	local plotsFolder = workspace:FindFirstChild(Constants.WORKSPACE_FOLDERS.Plots)
	if not plotsFolder then
		return false
	end
	for _, descendant in plotsFolder:GetDescendants() do
		silencePlotSound(descendant)
	end
	plotsFolder.DescendantAdded:Connect(silencePlotSound)
	return true
end

-- Chew / club SFX are fired from the server via CombatVisual kind
-- `MonsterAttack` (per-monster keys like MonsterAttack_Goblin). Health-attribute
-- listeners were removed so goblin clubs don't double-play with the generic hit.

function AudioController.init()
	ensureGroups()
end

function AudioController.start()
	SfxPlayer.preload()
	AudioController.playMusic(themeMusicKey)

	Remotes.getEvent("LevelStateChanged").OnClientEvent:Connect(function(state: unknown)
		if type(state) ~= "table" then
			return
		end
		local data = state :: { [string]: any }
		AudioController.setThemeFromWeather(if type(data.weather) == "string" then data.weather else nil)
	end)
	task.spawn(function()
		local ok, state = pcall(function()
			return Remotes.getFunction("RequestState"):InvokeServer()
		end)
		if ok and type(state) == "table" and type(state.level) == "table" then
			local level = state.level :: { [string]: any }
			AudioController.setThemeFromWeather(if type(level.weather) == "string" then level.weather else nil)
		end
	end)

	task.spawn(function()
		for _ = 1, 40 do
			if watchPlotsForEmbeddedAudio() then
				break
			end
			task.wait(0.25)
		end
	end)

	log:info("started")
end

return AudioController
