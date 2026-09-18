--!strict
--[[
	SfxPlayer
	One-shot SFX templates, preload, and playback for AudioController.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

local AudioConfig = require(ReplicatedStorage.Shared.Config.AudioConfig)

local SfxPlayer = {}

local sfxGroup: SoundGroup
local preloadFolder: Folder
local muted = false
local activeSfx: { Sound } = {}
local sfxTemplates: { [string]: Sound } = {}

local function applyDef(sound: Sound, def: AudioConfig.SoundDef, group: SoundGroup)
	sound.SoundId = def.SoundId
	sound.Volume = def.Volume or 1
	sound.PlaybackSpeed = def.PlaybackSpeed or 1
	sound.Looped = def.Looped == true
	sound.SoundGroup = group
end

local function ensureTemplate(key: string): Sound?
	local existing = sfxTemplates[key]
	if existing then
		return existing
	end
	local def = AudioConfig.SFX[key]
	if not def or def.SoundId == "" then
		return nil
	end
	local template = Instance.new("Sound")
	template.Name = "Template_" .. key
	applyDef(template, def, sfxGroup)
	template.Parent = preloadFolder
	sfxTemplates[key] = template
	return template
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
		local dropIndex: number? = nil
		for index, sound in activeSfx do
			local key = if string.sub(sound.Name, 1, 4) == "Sfx_" then string.sub(sound.Name, 5) else sound.Name
			local def = AudioConfig.SFX[key]
			if not (def and def.KeepUntilStopped == true) then
				dropIndex = index
				break
			end
		end
		if not dropIndex then
			break
		end
		local oldest = table.remove(activeSfx, dropIndex)
		if oldest then
			oldest:Stop()
			oldest:Destroy()
		end
	end
end

function SfxPlayer.bind(group: SoundGroup, folder: Folder)
	sfxGroup = group
	preloadFolder = folder
end

function SfxPlayer.setMuted(isMuted: boolean)
	muted = isMuted
end

function SfxPlayer.preload()
	local assets: { Instance } = {}
	for _, key in AudioConfig.PRELOAD_SFX do
		local template = ensureTemplate(key)
		if template then
			table.insert(assets, template)
		end
	end
	if #assets == 0 then
		return
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(assets)
		end)
	end)
end

function SfxPlayer.play(key: string)
	if muted then
		return
	end
	local def = AudioConfig.SFX[key]
	if not def or def.SoundId == "" then
		return
	end

	pruneSfx()

	local template = ensureTemplate(key)
	local sound: Sound
	if template then
		sound = template:Clone()
	else
		sound = Instance.new("Sound")
		applyDef(sound, def, sfxGroup)
	end
	sound.Name = "Sfx_" .. key
	sound.SoundGroup = sfxGroup
	sound.Parent = SoundService
	table.insert(activeSfx, sound)

	local startOffset = def.StartOffset
	if type(startOffset) == "number" and startOffset > 0 then
		sound.TimePosition = startOffset
	end
	sound:Play()

	local maxDuration = def.MaxDuration
	if type(maxDuration) == "number" and maxDuration > 0 then
		task.delay(maxDuration, function()
			if sound.Parent then
				sound:Stop()
				sound:Destroy()
			end
		end)
	else
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
	end
end

function SfxPlayer.stop(key: string)
	for index = #activeSfx, 1, -1 do
		local sound = activeSfx[index]
		if sound.Name == "Sfx_" .. key then
			table.remove(activeSfx, index)
			if sound.Parent then
				sound:Stop()
				sound:Destroy()
			end
		end
	end
end

return SfxPlayer
