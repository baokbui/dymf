--!strict
--[[
	Brainrots Registry
	Central, data-driven catalog of every Brainrot definition.

	Brainrot behavior is resolved from this data at runtime. Never branch on
	specific Brainrot names with if/elseif chains; read the definition instead.

	Milestone 14 balance pass — see docs/BALANCE.md.
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
		attackInterval = 11,
		rangeTiles = 0,
		ability = "GenerateCoins",
		coinGeneration = 25,
		color = Color3.fromRGB(255, 182, 193),
		modelId = "Ballerina Cappuccina",
		modelOrientationDegrees = Vector3.new(90, 0, 0),
	},

	TungTungSahur = {
		id = "TungTungSahur",
		name = "Tung Tung Sahur",
		cost = 75,
		maxHealth = 1000,
		health = 10,
		damage = 45,
		attackInterval = 0.95,
		rangeTiles = 1,
		ability = "MeleeBat",
		abilityParams = { meleeReach = 0.85 },
		color = Color3.fromRGB(139, 90, 43),
		modelId = "Tung Tung Tung Sahur",
		-- Toolbox mesh orientation verified in-game (pitch / yaw / roll degrees).
		modelOrientationDegrees = Vector3.new(90, 0, 180),
	},

	TralaleroTralala = {
		id = "TralaleroTralala",
		name = "Tralalero Tralala",
		cost = 175,
		maxHealth = 500,
		health = 5,
		damage = 60,
		attackInterval = 1.7,
		rangeTiles = FULL_LINE,
		ability = "BubbleTrap",
		abilityParams = { trapDuration = 1.2 },
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
		damage = 2800,
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
		attackInterval = 3.5,
		rangeTiles = 2,
		ability = "FreezeTime",
		abilityParams = { freezeDuration = 2 },
		color = Color3.fromRGB(180, 220, 255),
		modelId = "Lirilì Larilà",
		modelOrientationDegrees = Vector3.new(-90, 180, 0),
	},

	CappuccinoAssassino = {
		id = "CappuccinoAssassino",
		name = "Cappuccino Assassino",
		cost = 100,
		maxHealth = 500,
		health = 5,
		damage = 60,
		attackInterval = 1.75,
		rangeTiles = FULL_LINE,
		ability = "ThrowKnife",
		color = Color3.fromRGB(80, 50, 35),
		modelId = "Cappuccino Assassino",
		modelOrientationDegrees = Vector3.new(-90, 180, 0),
	},

	ChimpanziniBananini = {
		id = "ChimpanziniBananini",
		name = "Chimpanzini Bananini",
		cost = 75,
		maxHealth = 3500,
		health = 35,
		damage = 0,
		attackInterval = 0,
		rangeTiles = 0,
		ability = "Wall",
		color = Color3.fromRGB(255, 220, 80),
		modelId = "Chimpanzini Bananini",
		-- Toolbox mesh orientation verified in-game.
		modelOrientationDegrees = Vector3.new(-90, 180, 90),
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
