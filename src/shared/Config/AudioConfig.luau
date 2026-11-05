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
	-- Skip the oldest-instance cap until `AudioController.stopSfx`.
	KeepUntilStopped: boolean?,
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
		"FirstTimeRewardStamp",
		"MeleeBat",
		"ThrowKnifeHit",
		"PineappleHit",
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
		"MonsterAttack_Vampire",
		"MonsterAttack_DukeVampire",
		"SandTornado",
		"Terrify",
		"FreezeTime",
		"FreezeTimeEnd",
		"BubbleTrap",
		"CoinCollect",
		"PurchaseKaching",
		"PurchaseError",
		"PlaceBrainrot",
		"PlaceBrainrot_BallerinaCappucina",
		"PlaceBrainrot_TungTungSahur",
		"PlaceBrainrot_TralaleroTralala",
		"PlaceBrainrot_BombardinoCrocodilo",
		"PlaceBrainrot_LiriliLarila",
		"PlaceBrainrot_CappuccinoAssassino",
		"PlaceBrainrot_ChimpanziniBananini",
		"PlaceBrainrot_OrangutiniAnanassini",
		"PlaceBrainrot_BlueberrinniOctopusini",
		"PlaceBrainrot_BrrBrrPatapim",
		"PlaceBrainrot_GiraffaCeleste",
		"PlaceBrainrot_LaVaccaSaturnoSaturnita",
		"PlaceBrainrot_BonecaAmbalabu",
		"WindGust",
		"GraveShake",
		"GraveCollapse",
		"SwordWave",
		"SwordWavePillar",
		"SahurWrath",
		"InkLand",
		"TileTrap",
		"LightningStrike",
		"LastLaughExplosion",
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

		FirstTimeRewardStamp = {
			SoundId = "rbxassetid://521293072",
			Volume = 0.75,
		},

		-- Economy / placement
		CoinCollect = {
			SoundId = "rbxassetid://134583420216867",
			Volume = 0.7,
		},
		PurchaseKaching = {
			SoundId = "rbxassetid://7112275565",
			Volume = 0.85,
			MaxDuration = 1.4,
		},
		PurchaseError = {
			SoundId = "rbxassetid://132281440773764",
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
		PlaceBrainrot_OrangutiniAnanassini = {
			SoundId = "rbxassetid://92163425392945",
			Volume = 0.85,
		},
		PlaceBrainrot_BlueberrinniOctopusini = {
			SoundId = "rbxassetid://91691159755945",
			Volume = 0.85,
		},
		PlaceBrainrot_BrrBrrPatapim = {
			SoundId = "rbxassetid://138952404452431",
			Volume = 0.85,
		},
		PlaceBrainrot_LaVaccaSaturnoSaturnita = {
			SoundId = "rbxassetid://90484863638361",
			Volume = 0.85,
		},
		PlaceBrainrot_BonecaAmbalabu = {
			SoundId = "rbxassetid://82401058692450",
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
		-- Vampire / Duke Vampire life-drain tick.
		MonsterAttack_Vampire = {
			SoundId = "rbxassetid://92913957136482",
			Volume = 0.85,
		},
		MonsterAttack_DukeVampire = {
			SoundId = "rbxassetid://92913957136482",
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
		-- Tung Tung GOD: bat grows vertically before the slam.
		SahurWrath = {
			SoundId = "rbxassetid://137463821",
			Volume = 0.85,
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
		PineappleHit = {
			SoundId = "rbxassetid://130869638485735",
			Volume = 0.75,
		},
		-- Cappuccino GOD Shadow Requiem: crescent whoosh (starts 1s before launch; cut when the pillar starts).
		SwordWave = {
			SoundId = "rbxassetid://135712825042019",
			Volume = 0.85,
			KeepUntilStopped = true,
		},
		-- Last-tile light-pillar detonation.
		SwordWavePillar = {
			SoundId = "rbxassetid://119977062667102",
			Volume = 0.9,
		},
		-- Boneca headbutt landing (every TileTrap hit, including kills).
		TileTrap = {
			SoundId = "rbxassetid://133256956059581",
			Volume = 0.85,
		},
		-- Boneca God of Thunder bolt (CombatVisual kind "LightningStrike").
		LightningStrike = {
			SoundId = "rbxassetid://138687206526097",
			Volume = 0.85,
		},
		-- Boneca GOD Last Laugh mushroom cloud (CombatVisual kind "MushroomExplosion").
		LastLaughExplosion = {
			SoundId = "rbxassetid://139210252225248",
			Volume = 0.9,
		},
		-- Blueberrinni ink splat when the droplet reaches the tile.
		InkLand = {
			SoundId = "rbxassetid://117260647120678",
			Volume = 0.8,
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
