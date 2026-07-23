--!strict
--[[
	Brainrots Registry
	Central, data-driven catalog of every Brainrot definition.

	Brainrot behavior is resolved from this data at runtime. Never branch on
	specific Brainrot names with if/elseif chains; read the definition instead.

	Milestone 14+ balance — see docs/BALANCE.md.
]]

local BrainrotConfig = require(script.Parent.Config.BrainrotConfig)
local Types = require(script.Parent.Types)

local Brainrots = {}

local FULL_LINE = BrainrotConfig.FULL_LINE_RANGE

local definitions: { [string]: Types.BrainrotDefinition } = {
	BallerinaCappucina = {
		id = "BallerinaCappucina",
		name = "Ballerina Cappucina",
		cost = 50,
		maxHealth = 500,
		health = 5,
		damage = 0,
		attackInterval = 25,
		rangeTiles = 0,
		ability = "GenerateCoins",
		coinGeneration = 25,
		color = Color3.fromRGB(255, 182, 193),
		modelId = "Ballerina Cappuccina",
		modelOrientationDegrees = Vector3.new(90, 0, 0),
		modelScale = BrainrotConfig.COMPACT_MODEL_SCALE,
	},

	TungTungSahur = {
		id = "TungTungSahur",
		name = "Tung Tung Sahur",
		cost = 75,
		maxHealth = 800,
		health = 8,
		damage = 40,
		attackInterval = 1.5,
		rangeTiles = 1,
		ability = "MeleeBat",
		color = Color3.fromRGB(139, 90, 43),
		modelId = "Tung Tung Tung Sahur",
		-- Toolbox mesh orientation verified in-game (pitch / yaw / roll degrees).
		modelOrientationDegrees = Vector3.new(90, 0, 180),
		modelScale = BrainrotConfig.COMPACT_MODEL_SCALE,
	},

	TralaleroTralala = {
		id = "TralaleroTralala",
		name = "Tralalero Tralala",
		cost = 175,
		maxHealth = 500,
		health = 5,
		damage = 55,
		attackInterval = 5.0,
		rangeTiles = FULL_LINE,
		ability = "BubbleTrap",
		abilityParams = { trapDuration = 0.5 },
		color = Color3.fromRGB(100, 200, 255),
		modelId = "Tralalero Tralala",
		modelOrientationDegrees = Vector3.new(-90, 180, -90),
	},

	BombardinoCrocodilo = {
		id = "BombardinoCrocodilo",
		name = "Bombardino Crocodilo",
		cost = 375,
		maxHealth = 1,
		health = 1,
		damage = 1000,
		attackInterval = 0,
		rangeTiles = FULL_LINE,
		ability = "LineBomb",
		triggersOnPlace = true,
		color = Color3.fromRGB(60, 140, 70),
		modelId = "Bombardiro Crocodilo",
		modelOrientationDegrees = Vector3.new(90, 0, 0),
	},

	LiriliLarila = {
		id = "LiriliLarila",
		name = "Lirili Larila",
		cost = 150,
		maxHealth = 500,
		health = 5,
		damage = 0,
		attackInterval = 6.0,
		rangeTiles = 2,
		ability = "FreezeTime",
		abilityParams = { freezeDuration = 0.7 },
		color = Color3.fromRGB(180, 220, 255),
		modelId = "Lirilì Larilà",
		modelOrientationDegrees = Vector3.new(-90, 180, 0),
		modelScale = BrainrotConfig.COMPACT_MODEL_SCALE,
	},

	CappuccinoAssassino = {
		id = "CappuccinoAssassino",
		name = "Cappuccino Assassino",
		cost = 100,
		maxHealth = 500,
		health = 5,
		damage = 50,
		attackInterval = 2.0,
		rangeTiles = FULL_LINE,
		ability = "ThrowKnife",
		color = Color3.fromRGB(80, 50, 35),
		modelId = "Cappuccino Assassino",
		modelOrientationDegrees = Vector3.new(-90, 180, 0),
		modelScale = BrainrotConfig.COMPACT_MODEL_SCALE,
	},

	ChimpanziniBananini = {
		id = "ChimpanziniBananini",
		name = "Chimpanzini Bananini",
		cost = 75,
		maxHealth = 2000,
		health = 20,
		damage = 0,
		attackInterval = 0,
		rangeTiles = 0,
		ability = "Wall",
		color = Color3.fromRGB(255, 220, 80),
		modelId = "Chimpanzini Bananini",
		-- Toolbox mesh orientation verified in-game.
		modelOrientationDegrees = Vector3.new(-90, 180, 90),
		modelScale = BrainrotConfig.COMPACT_MODEL_SCALE,
	},
}

function Brainrots.get(id: string): Types.BrainrotDefinition?
	return definitions[id]
end

function Brainrots.exists(id: string): boolean
	return definitions[id] ~= nil
end

function Brainrots.getAll(): { [string]: Types.BrainrotDefinition }
	return definitions
end

return Brainrots
