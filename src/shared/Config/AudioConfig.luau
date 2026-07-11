--!strict
--[[
	AudioConfig
	Client audio tuning and asset ids. Playback is owned by AudioController;
	gameplay never depends on these values.

	SoundId may be rbxasset:// (engine) or rbxassetid:// (catalog). Empty string
	or missing entries are treated as silent.
]]

export type SoundDef = {
	SoundId: string,
	Volume: number?,
	PlaybackSpeed: number?,
	Looped: boolean?,
	-- Hard-stop one-shots that have long tails (seconds from Play).
	MaxDuration: number?,
	-- Skip leading silence in the asset (seconds).
	StartOffset: number?,
}

local AudioConfig = {
	MASTER_VOLUME = 1,
	MUSIC_VOLUME = 0.32,
	SFX_VOLUME = 0.75,
	AMBIENT_VOLUME = 0.18,

	-- Crossfade when switching music tracks (seconds).
	MUSIC_FADE_DURATION = 0.85,

	-- Max concurrent one-shot SFX instances (oldest destroyed when exceeded).
	MAX_SFX_INSTANCES = 12,

	-- Preload on join so combat SFX aren't delayed by first asset download.
	PRELOAD_SFX = {
		"MeleeBat",
		"ThrowKnifeHit",
		"Hit",
		"Death",
		"Death_Zombie",
		"Death_TutorialZombie",
		"Death_EarlyZombie",
		"FreezeTime",
		"BubbleTrap",
		"CoinCollect",
		"PlaceBrainrot",
	},

	MUSIC = {
		Default = {
			SoundId = "rbxassetid://1848354536",
			Volume = 0.32,
			Looped = true,
		},
		Boss = {
			SoundId = "rbxassetid://1841647093",
			Volume = 0.4,
			Looped = true,
		},
	} :: { [string]: SoundDef },

	AMBIENT = {
		Plot = {
			SoundId = "rbxasset://sounds/impact_water.mp3",
			Volume = 0.08,
			Looped = true,
			PlaybackSpeed = 0.55,
		},
	} :: { [string]: SoundDef },

	SFX = {
		-- UI
		UiClick = {
			SoundId = "rbxasset://sounds/switch.wav",
			Volume = 0.45,
		},
		UiSelect = {
			SoundId = "rbxassetid://122835655736085",
			Volume = 0.6,
		},
		LevelStart = {
			SoundId = "rbxasset://sounds/switch.wav",
			Volume = 0.55,
			PlaybackSpeed = 1.15,
		},

		-- Economy / placement
		CoinCollect = {
			SoundId = "rbxassetid://134583420216867",
			Volume = 0.7,
		},
		PlaceBrainrot = {
			SoundId = "rbxassetid://72957154832455",
			Volume = 0.7,
			PlaybackSpeed = 1,
		},
		RemoveBrainrot = {
			SoundId = "rbxassetid://135342195223049",
			Volume = 0.7,
		},

		-- Combat
		Hit = {
			SoundId = "rbxasset://sounds/collide.wav",
			Volume = 0.4,
			PlaybackSpeed = 1.2,
		},
		Death = {
			SoundId = "rbxasset://sounds/impact_water.mp3",
			Volume = 0.55,
			PlaybackSpeed = 1.4,
		},
		-- Per-monster death overrides (key = MonsterId attribute).
		Death_Zombie = {
			SoundId = "rbxassetid://6845870387",
			Volume = 0.85,
			StartOffset = 0.05,
		},
		Death_TutorialZombie = {
			SoundId = "rbxassetid://6845870387",
			Volume = 0.85,
			StartOffset = 0.05,
		},
		Death_EarlyZombie = {
			SoundId = "rbxassetid://6845870387",
			Volume = 0.85,
			StartOffset = 0.05,
		},
		Explosion = {
			SoundId = "rbxasset://sounds/impact_explosion_03.mp3",
			Volume = 0.7,
		},

		-- Levels
		CountdownTick = {
			SoundId = "rbxasset://sounds/switch.wav",
			Volume = 0.35,
			PlaybackSpeed = 1.5,
		},
		BigWave = {
			SoundId = "rbxasset://sounds/Rocket whoosh 01.wav",
			Volume = 0.65,
		},
		Victory = {
			SoundId = "rbxasset://sounds/electronicpingshort.wav",
			Volume = 0.7,
			PlaybackSpeed = 0.85,
		},
		Defeat = {
			SoundId = "rbxasset://sounds/collide.wav",
			Volume = 0.65,
			PlaybackSpeed = 0.7,
		},

		-- Monsters
		MonsterAttack = {
			SoundId = "rbxasset://sounds/snap.wav",
			Volume = 0.4,
			PlaybackSpeed = 0.9,
		},

		-- Brainrot abilities (keys match BrainrotAction.action / ability ids)
		MeleeBat = {
			SoundId = "rbxassetid://9113322410",
			Volume = 0.75,
			-- Asset has a long grassy tail; keep only the hit transient.
			MaxDuration = 0.22,
		},
		BubbleTrap = {
			SoundId = "rbxassetid://5852470908",
			Volume = 0.75,
		},
		LineBomb = {
			SoundId = "rbxassetid://139771888058836",
			Volume = 0.75,
		},
		FreezeTime = {
			SoundId = "rbxassetid://127777354835900",
			Volume = 0.75,
		},
		ThrowKnifeHit = {
			SoundId = "rbxassetid://137287949709499",
			Volume = 0.75,
		},
	} :: { [string]: SoundDef },
}

table.freeze(AudioConfig.PRELOAD_SFX)
table.freeze(AudioConfig.MUSIC)
table.freeze(AudioConfig.AMBIENT)
table.freeze(AudioConfig.SFX)
table.freeze(AudioConfig)

return AudioConfig
