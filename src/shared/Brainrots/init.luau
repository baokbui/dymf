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
		attackInterval = 18,
		rangeTiles = 0,
		ability = "GenerateCoins",
		coinGeneration = 25,
		color = Color3.fromRGB(255, 182, 193),
		previewFocusOffset = Vector3.new(0, -0.8, 0),
		modelId = "Ballerina Cappuccina",
		modelOrientationDegrees = Vector3.new(0, 0, 0),
		modelYOffset = 4.7,
		modelScale = BrainrotConfig.COMPACT_MODEL_SCALE,
		animated = true,
		attackAnimationId = "rbxassetid://135103987361576",
		attackHitDelay = 0.5,
	},

	TungTungSahur = {
		id = "TungTungSahur",
		name = "Tung Tung Sahur",
		cost = 75,
		maxHealth = 1200,
		health = 12,
		damage = 55,
		attackInterval = 1.5,
		rangeTiles = 1,
		ability = "MeleeBat",
		color = Color3.fromRGB(139, 90, 43),
		previewFocusOffset = Vector3.new(0, -0.8, 0),
		modelId = "Tung Tung Tung Sahur",
		-- Toolbox mesh orientation verified in-game (pitch / yaw / roll degrees).
		modelOrientationDegrees = Vector3.new(0, 0, 0),
		-- Raise (+) / lower (−) after feet-snap; tune until soles sit on the tile.
		modelYOffset = 5,
		modelScale = BrainrotConfig.COMPACT_MODEL_SCALE,
		-- AnimationController + Animator on the Assets template.
		animated = true,
		attackAnimationId = "rbxassetid://128065031620598",
		-- Windup before damage so the bat swing lands on the hit frame.
		attackHitDelay = 0.5,
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
		previewFocusOffset = Vector3.new(0, -0.5, 0),
		modelId = "Tralalero Tralala",
		modelOrientationDegrees = Vector3.new(0, 0, 0),
		modelYOffset = 1,
		animated = true,
		attackAnimationId = "rbxassetid://138181249321727",
		attackHitDelay = 0.25,
	},

	BombardinoCrocodilo = {
		id = "BombardinoCrocodilo",
		name = "Bombardino Crocodilo",
		cost = 325,
		maxHealth = 1,
		health = 1,
		damage = 1000,
		attackInterval = 0,
		rangeTiles = FULL_LINE,
		ability = "LineBomb",
		triggersOnPlace = true,
		plantCooldown = 30,
		color = Color3.fromRGB(60, 140, 70),
		previewFocusOffset = Vector3.new(0, -0.5, 0),
		modelId = "Bombardiro Crocodilo",
		modelOrientationDegrees = Vector3.new(0, 0, 0),
		modelYOffset = 5,
	},

	LiriliLarila = {
		id = "LiriliLarila",
		name = "Lirili Larila",
		cost = 75,
		maxHealth = 1,
		health = 1,
		damage = 0,
		attackInterval = 0,
		rangeTiles = FULL_LINE,
		ability = "FreezeTime",
		abilityParams = { freezeDuration = 7 },
		triggersOnPlace = true,
		plantCooldown = 20,
		color = Color3.fromRGB(180, 220, 255),
		previewFocusOffset = Vector3.new(0, -0.6, 0),
		modelId = "Lirilì Larilà",
		modelOrientationDegrees = Vector3.new(0, 0, 0),
		modelYOffset = 3,
		modelScale = BrainrotConfig.COMPACT_MODEL_SCALE,
		animated = true,
		attackAnimationId = "rbxassetid://124921779580222",
		attackHitDelay = 0.5,
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
		previewFocusOffset = Vector3.new(0, -0.7, 0),
		modelId = "Cappuccino Assassino",
		modelOrientationDegrees = Vector3.new(0, 0, 0),
		modelYOffset = 3,
		modelScale = BrainrotConfig.COMPACT_MODEL_SCALE,
		animated = true,
		attackAnimationId = "rbxassetid://99069565346809",
		attackHitDelay = 0.5,
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
		previewFocusOffset = Vector3.new(0, -0.2, 0),
		modelId = "Chimpanzini Bananini",
		modelOrientationDegrees = Vector3.new(0, 0, 0),
		modelYOffset = 2,
		modelScale = BrainrotConfig.COMPACT_MODEL_SCALE,
		animated = true,
		hitAnimationId = "rbxassetid://113108515716026",
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
