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
		"Death_Vampire",
		"Death_DukeVampire",
		"Death_Goblin",
		"Death_GoblinElite",
		"Death_GoblinKing",
		"Death_SmallMummy",
		"Death_PharaohMummy",
		"Death_Scorpion",
		"MonsterAttack",
		"MonsterAttack_Goblin",
		"MonsterAttack_GoblinElite",
		"MonsterAttack_GoblinKing",
		"MonsterAttack_Scorpion",
		"MonsterAttack_SmallMummy",
		"MonsterAttack_PharaohMummy",
		"SandTornado",
		"Terrify",
		"FreezeTime",
		"FreezeTimeEnd",
		"BubbleTrap",
		"CoinCollect",
		"PlaceBrainrot",
		"PlaceBrainrot_BallerinaCappucina",
		"PlaceBrainrot_TungTungSahur",
		"PlaceBrainrot_TralaleroTralala",
		"PlaceBrainrot_BombardinoCrocodilo",
		"PlaceBrainrot_LiriliLarila",
		"PlaceBrainrot_CappuccinoAssassino",
		"PlaceBrainrot_ChimpanziniBananini",
		"PlaceBrainrot_BrrBrrPatapim",
		"PlaceBrainrot_GiraffaCeleste",
		"WindGust",
		"GraveShake",
		"GraveCollapse",
	},

	MUSIC = {
		-- Days 1–20 (no weather): Relaxed Scene — chill daytime loop.
		Default = {
			SoundId = "rbxassetid://1848354536",
			Volume = 0.32,
			Looped = true,
		},
		-- Days 21–40 (Night / NightFog / NightFogReceded): same chill energy,
		-- slightly spooky (APM "Mysterious", same Mystery Movie family).
		Night = {
			SoundId = "rbxassetid://1838974004",
			Volume = 0.32,
			Looped = true,
		},
		-- Days 41–50 (Desert): chill sand / oasis loop.
		Desert = {
			SoundId = "rbxassetid://1837253820",
			Volume = 0.32,
			Looped = true,
		},
		Boss = {
			SoundId = "rbxassetid://1841647093",
			Volume = 0.4,
			Looped = true,
		},
	} :: { [string]: SoundDef },

	-- Unused: only weather BGM + boss music loop (no extra plot bed).
	AMBIENT = {
		Plot = {
			SoundId = "",
			Volume = 0,
			Looped = true,
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
		PlaceBrainrot_BallerinaCappucina = {
			SoundId = "rbxassetid://136160874492071",
			Volume = 0.85,
		},
		PlaceBrainrot_TungTungSahur = {
			SoundId = "rbxassetid://138857089980331",
			Volume = 0.85,
		},
		PlaceBrainrot_TralaleroTralala = {
			SoundId = "rbxassetid://107015186635337",
			Volume = 0.85,
		},
		PlaceBrainrot_BombardinoCrocodilo = {
			SoundId = "rbxassetid://127920374501264",
			Volume = 0.85,
		},
		PlaceBrainrot_LiriliLarila = {
			SoundId = "rbxassetid://99934484535097",
			Volume = 0.85,
		},
		PlaceBrainrot_CappuccinoAssassino = {
			SoundId = "rbxassetid://132507332049936",
			Volume = 0.85,
		},
		PlaceBrainrot_ChimpanziniBananini = {
			SoundId = "rbxassetid://112519317017452",
			Volume = 0.85,
		},
		PlaceBrainrot_BrrBrrPatapim = {
			SoundId = "rbxassetid://138952404452431",
			Volume = 0.85,
		},
		PlaceBrainrot_GiraffaCeleste = {
			SoundId = "rbxassetid://72548265830474",
			Volume = 0.85,
		},
		RemoveBrainrot = {
			SoundId = "rbxassetid://135342195223049",
			Volume = 0.7,
		},

		-- Combat
		Hit = {
			SoundId = "rbxassetid://12221967",
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
		Death_Vampire = {
			SoundId = "rbxassetid://119636957649573",
			Volume = 0.85,
		},
		Death_DukeVampire = {
			SoundId = "rbxassetid://119636957649573",
			Volume = 0.85,
		},
		Death_Goblin = {
			SoundId = "rbxassetid://83502215419926",
			Volume = 0.85,
		},
		Death_GoblinElite = {
			SoundId = "rbxassetid://83502215419926",
			Volume = 0.9,
		},
		Death_GoblinKing = {
			SoundId = "rbxassetid://83502215419926",
			Volume = 0.9,
		},
		Death_SmallMummy = {
			SoundId = "rbxassetid://297569488",
			Volume = 0.85,
		},
		Death_PharaohMummy = {
			SoundId = "rbxassetid://297569488",
			Volume = 0.85,
		},
		Death_Scorpion = {
			SoundId = "rbxassetid://74185022698539",
			Volume = 0.85,
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
			SoundId = "rbxassetid://12221967",
			Volume = 0.65,
			PlaybackSpeed = 0.7,
		},

		-- Monsters
		MonsterAttack = {
			SoundId = "rbxassetid://116770139807499",
			Volume = 0.75,
			PlaybackSpeed = 0.9,
		},
		-- Goblin club swing (Goblin / Goblin Elite / Goblin King chew).
		MonsterAttack_Goblin = {
			SoundId = "rbxassetid://128854594485072",
			Volume = 0.85,
		},
		MonsterAttack_GoblinElite = {
			SoundId = "rbxassetid://128854594485072",
			Volume = 0.9,
		},
		MonsterAttack_GoblinKing = {
			SoundId = "rbxassetid://128854594485072",
			Volume = 0.9,
		},
		MonsterAttack_Scorpion = {
			SoundId = "rbxassetid://136569304505276",
			Volume = 0.85,
		},
		MonsterAttack_SmallMummy = {
			SoundId = "rbxassetid://78304267856955",
			Volume = 0.85,
		},
		MonsterAttack_PharaohMummy = {
			SoundId = "rbxassetid://78304267856955",
			Volume = 0.85,
		},
		-- Pharaoh steal tornado (CombatVisual kind "SandTornado").
		SandTornado = {
			SoundId = "rbxassetid://8011936855",
			Volume = 0.85,
		},
		-- Duke Vampire Terrify scream (CombatVisual kind "Terrify").
		Terrify = {
			SoundId = "rbxassetid://5527368920",
			Volume = 0.85,
		},

		-- Brainrot abilities (keys match BrainrotAction.action / ability ids)
		MeleeBat = {
			SoundId = "rbxassetid://173818824",
			Volume = 0.8,
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
			SoundId = "rbxassetid://139589191046133",
			Volume = 0.75,
		},
		FreezeTimeEnd = {
			SoundId = "rbxassetid://127329791266618",
			Volume = 0.75,
		},
		ThrowKnifeHit = {
			SoundId = "rbxassetid://137287949709499",
			Volume = 0.75,
		},
		-- Giraffa Celeste gust after the place animation.
		WindGust = {
			SoundId = "rbxassetid://139638115866253",
			Volume = 0.85,
		},
		GraveShake = {
			SoundId = "rbxassetid://114632405756391",
			Volume = 0.85,
		},
		GraveCollapse = {
			SoundId = "rbxassetid://6860676457",
			Volume = 0.9,
		},
	} :: { [string]: SoundDef },
}

table.freeze(AudioConfig.PRELOAD_SFX)
table.freeze(AudioConfig.MUSIC)
table.freeze(AudioConfig.AMBIENT)
table.freeze(AudioConfig.SFX)
table.freeze(AudioConfig)

return AudioConfig
