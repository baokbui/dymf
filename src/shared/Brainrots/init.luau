--!strict
--[[
	Brainrots Registry
	Central, data-driven catalog of every Brainrot definition.

	Brainrot behavior is resolved from this data at runtime. Never branch on
	specific Brainrot names with if/elseif chains; read the definition instead.
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
		attackInterval = 12,
		rangeTiles = 0,
		ability = "GenerateCoins",
		coinGeneration = 25,
		color = Color3.fromRGB(255, 182, 193),
	},

	TungTungSahur = {
		id = "TungTungSahur",
		name = "Tung Tung Sahur",
		cost = 75,
		maxHealth = 800,
		health = 8,
		damage = 100,
		attackInterval = 1,
		rangeTiles = 1,
		ability = "MeleeBat",
		abilityParams = { meleeReach = 0.85 },
		color = Color3.fromRGB(139, 90, 43),
	},

	TralaleroTralala = {
		id = "TralaleroTralala",
		name = "Tralalero Tralala",
		cost = 175,
		maxHealth = 500,
		health = 5,
		damage = 100,
		attackInterval = 1.5,
		rangeTiles = FULL_LINE,
		ability = "BubbleTrap",
		abilityParams = { trapDuration = 1 },
		color = Color3.fromRGB(100, 200, 255),
	},

	BombardinoCrocodilo = {
		id = "BombardinoCrocodilo",
		name = "Bombardino Crocodilo",
		cost = 350,
		maxHealth = 1,
		health = 1,
		damage = 9000,
		attackInterval = 0,
		rangeTiles = FULL_LINE,
		ability = "LineBomb",
		triggersOnPlace = true,
		color = Color3.fromRGB(60, 140, 70),
	},

	LiriliLarila = {
		id = "LiriliLarila",
		name = "Lirili Larila",
		cost = 150,
		maxHealth = 500,
		health = 5,
		damage = 0,
		attackInterval = 2.5,
		rangeTiles = 2,
		ability = "FreezeTime",
		abilityParams = { freezeDuration = 1.5 },
		color = Color3.fromRGB(180, 220, 255),
	},

	CappuccinoAssassino = {
		id = "CappuccinoAssassino",
		name = "Cappuccino Assassino",
		cost = 100,
		maxHealth = 500,
		health = 5,
		damage = 100,
		attackInterval = 1.5,
		rangeTiles = FULL_LINE,
		ability = "ThrowKnife",
		color = Color3.fromRGB(80, 50, 35),
	},

	ChimpanziniBananini = {
		id = "ChimpanziniBananini",
		name = "Chimpanzini Bananini",
		cost = 50,
		maxHealth = 6000,
		health = 60,
		damage = 0,
		attackInterval = 0,
		rangeTiles = 0,
		ability = "Wall",
		color = Color3.fromRGB(255, 220, 80),
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
