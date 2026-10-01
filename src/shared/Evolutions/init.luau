--!strict
--[[
	Evolutions
	Epic→God catalog. Claiming a tier costs brains after the Brainrot
	level gate. Epic `stats` compose onto the shared registry definition. Legendary extras
	and Mythic / Immortal passives resolve from `ability` ids / `abilityParams` (never
	mutate the catalog; never branch on unit names). GOD ultimates: `Jackpot`,
	`PrimalRetaliation`, `SahurWrath`, `ShadowRequiem`, `AbyssalTorrent`, `PineappleExpress`,
	plus Lirili `freezeEntireLawn` and Boneca `lastLaughDamage` (Last Laugh) overlays.
]]

local EvolutionConfig = require(script.Parent.Config.EvolutionConfig)
local Types = require(script.Parent.Types)

export type StatOverrides = {
	attackInterval: number?,
	maxHealth: number?,
	health: number?,
	damage: number?,
	plantCooldown: number?,
	immovable: boolean?,
	charges: number?,
}

export type EvolutionRow = {
	rarity: string,
	level: number,
	name: string,
	description: string,
	stats: StatOverrides?,
	-- Extra ability handler id (Legendary+). Resolved by Brainrot Abilities.
	ability: string?,
	abilityParams: { [string]: number }?,
}

local TRACKS: { [string]: { EvolutionRow } } = {
	BallerinaCappucina = {
		{
			rarity = "Epic",
			level = 10,
			name = "Wallet Ballet",
			description = "Spits coins 50% faster.",
			stats = { attackInterval = 12 },
		},
		{
			rarity = "Legendary",
			level = 20,
			name = "Golden Waltz",
			description = "Every 30s, coins come out 100% faster for 6s.",
			ability = "CoinHaste",
			abilityParams = { cooldown = 30, duration = 6, factor = 2 },
		},
		{
			rarity = "Mythic",
			level = 30,
			name = "Encore",
			description = "Each coin has a 30% chance to drop an extra.",
			abilityParams = { extraCoinChance = 30 },
		},
		{
			rarity = "Immortal",
			level = 40,
			name = "Golden Discount",
			description = "When she spits a coin, the next Brainrot you plant costs 50%. 20s cooldown.",
			abilityParams = { plantDiscountPercent = 50, plantDiscountCooldown = 20 },
		},
		{ rarity = "God", level = 50, name = "Jackpot", description = "For 10 seconds, coins come out 200% faster, and each coin has a 33% chance to drop an extra. 30s cooldown.", ability = "Jackpot", abilityParams = { cooldown = 30, duration = 10, factor = 3, extraChance = 33 } },
	},
	ChimpanziniBananini = {
		{
			rarity = "Epic",
			level = 10,
			name = "Goliath",
			description = "100% more HP, and can't be stolen or pushed off his tile.",
			stats = { maxHealth = 4000, immovable = true },
		},
		{
			rarity = "Legendary",
			level = 20,
			name = "Banana Bastion",
			description = "Gains a 500 HP shield every 10 seconds.",
			ability = "ShieldPulse",
			abilityParams = { cooldown = 10, shield = 500 },
		},
		{
			rarity = "Mythic",
			level = 30,
			name = "Jungle Vitality",
			description = "Heals 5% max HP every 5 seconds.",
			ability = "RegenPulse",
			abilityParams = { cooldown = 5, healPercent = 5 },
		},
		{
			rarity = "Immortal",
			level = 40,
			name = "Stoneheart",
			description = "Once, below 10% health, turns to stone for 10 seconds and can't be hurt. It can't attack while stone.",
			ability = "Stoneheart",
			abilityParams = { healthPercent = 10, duration = 10 },
		},
		{ rarity = "God", level = 50, name = "Primal Retaliation", description = "For 15 seconds, sends 25% of bite damage back at that monster. 30s cooldown.", ability = "PrimalRetaliation", abilityParams = { cooldown = 30, duration = 15, reflectPercent = 25 } },
	},
	TungTungSahur = {
		{
			rarity = "Epic",
			level = 10,
			name = "Tung Tung Training",
			description = "25% more HP and 82% more damage.",
			stats = { maxHealth = 1500, damage = 100 },
		},
		{
			rarity = "Legendary",
			level = 20,
			name = "Ranged Rampage",
			description = "For 10 seconds, throws a spinning bat down the row. Hits knock monsters back a quarter tile. 20s cooldown.",
			ability = "RangedRampage",
			abilityParams = { cooldown = 20, duration = 10 },
		},
		{
			rarity = "Mythic",
			level = 30,
			name = "Desperate Fury",
			description = "Once, below 50% health, attacks 50% faster.",
			ability = "DesperateFury",
			abilityParams = { healthPercent = 50, factor = 1.5 },
		},
		{
			rarity = "Immortal",
			level = 40,
			name = "Tenfold Guard",
			description = "Every 10 attacks, gains a shield for 30% of its max HP for 5 seconds and can't be stunned.",
			ability = "TenfoldGuard",
			abilityParams = { every = 10, shieldPercent = 30, duration = 5, orbitShield = 1 },
		},
		{
			rarity = "God",
			level = 50,
			name = "Sahur's Wrath",
			description = "A giant bat slams the whole row for 1000% damage, and the rows beside it for 500%. Needs 3 or more monsters, or a boss. 30s cooldown.",
			ability = "SahurWrath",
			abilityParams = { cooldown = 30, damagePercent = 1000, splashPercent = 500, minEnemies = 3 },
		},
	},
	TralaleroTralala = {
		{
			rarity = "Epic",
			level = 10,
			name = "Ocean's Rhythm",
			description = "Attacks 67% faster, deals 18% more damage, and traps last 50% longer.",
			stats = { attackInterval = 3, damage = 65 },
			abilityParams = { trapDuration = 0.75 },
		},
		{
			rarity = "Legendary",
			level = 20,
			name = "Bubble Barrage",
			description = "Shoots one bubble that splits into five, one for each row. 15s cooldown.",
			ability = "BubbleBarrage",
			abilityParams = { cooldown = 15 },
		},
		{
			rarity = "Mythic",
			level = 30,
			name = "Double Bubble",
			description = "Each bubble has a 33% chance to make an extra trap.",
			abilityParams = { extraBubbleChance = 33 },
		},
		{
			rarity = "Immortal",
			level = 40,
			name = "Wound of the Shark",
			description = "Monsters leaving a bubble are slowed 40% for 3 seconds.",
			abilityParams = { bubbleExitSlowPercent = 40, bubbleExitSlowDuration = 3 },
		},
		{
			rarity = "God",
			level = 50,
			name = "Abyssal Torrent",
			description = "Shoots a water jet from his mouth to the end of the row for 15 seconds. It goes through every monster in the way. Each second in the jet deals 55 damage, plus 20% more for every tile closer to him. Needs 3 or more monsters, or a boss. The closest one fires first. 45s cooldown.",
			ability = "AbyssalTorrent",
			abilityParams = { cooldown = 45, duration = 15, minEnemies = 3, closePercent = 20 },
		},
	},
	CappuccinoAssassino = {
		{
			rarity = "Epic",
			level = 10,
			name = "Espresso Rush",
			description = "Attacks 50% faster and deals 50% more damage.",
			-- 2s base / 1.5 = ~1.333s between knives. Damage is base 50 + 25.
			stats = { attackInterval = 2 / 1.5, damage = 75 },
		},
		{
			rarity = "Legendary",
			level = 20,
			name = "Piercing Brew",
			description = "For 6 seconds, shurikens hit the first monster and the one behind it, even through graves. 10s cooldown.",
			ability = "PierceBrew",
			abilityParams = { cooldown = 10, duration = 6 },
		},
		{
			rarity = "Mythic",
			level = 30,
			name = "Fifth Strike",
			description = "Every 5th attack deals 200% damage.",
			abilityParams = { fifthStrikeEvery = 5, fifthStrikeFactor = 2 },
		},
		{
			rarity = "Immortal",
			level = 40,
			name = "Assassin's Verdict",
			description = "Finishes a monster below 7.5% health. Bosses have to be below 2%.",
			abilityParams = { executeHealthPercent = 7.5, executeBossPercent = 2 },
		},
		{
			rarity = "God",
			level = 50,
			name = "Shadow Requiem",
			description = "Sends a growing sword wave down the row for 2000% damage, plus 100% per tile, then a 1000% blast on the last tile. Needs 3 or more monsters, or a boss. 45s cooldown.",
			ability = "ShadowRequiem",
			abilityParams = { cooldown = 45, damagePercent = 2000, travelPercent = 100, finisherPercent = 1000, minEnemies = 3 },
		},
	},
	LiriliLarila = {
		{
			rarity = "Epic",
			level = 10,
			name = "Cryocycle",
			description = "Recharge is 25% shorter.",
			stats = { plantCooldown = 15 },
		},
		{
			rarity = "Legendary",
			level = 20,
			name = "Winter's Grasp",
			description = "Freezes a whole row.",
			abilityParams = { freezeEntireLane = 1 },
		},
		{
			rarity = "Mythic",
			level = 30,
			name = "Permafrost",
			description = "Freezes last 40% longer.",
			abilityParams = { freezeDuration = 7 },
		},
		{
			rarity = "Immortal",
			level = 40,
			name = "Frostbound Neighbor",
			description = "Also freezes the neighboring row with the most monsters.",
			abilityParams = { freezeAdjacentLane = 1 },
		},
		{ rarity = "God", level = 50, name = "Glacial Dominion", description = "Freezes the whole lawn, then slows everyone 25% for 3 seconds after they thaw.", abilityParams = { freezeEntireLawn = 1, lawnSlowPercent = 25, lawnSlowDuration = 3 } },
	},
	OrangutiniAnanassini = {
		{
			rarity = "Epic",
			level = 10,
			name = "Heavy Fruit",
			description = "Throws harder and faster: 60 damage and a 1.5 second attack.",
			stats = { damage = 60, attackInterval = 1.5 },
		},
		{
			rarity = "Legendary",
			level = 20,
			name = "Second Serving",
			description = "Every 4 seconds, the throw also sends a pineapple at the next monster behind the usual target.",
			abilityParams = { secondServingCooldown = 4 },
		},
		{
			rarity = "Mythic",
			level = 30,
			name = "Juice Splash",
			description = "Each pineapple also splashes the monster it jumped over for 50% damage.",
			abilityParams = { juiceSplashPercent = 50 },
		},
		{
			rarity = "Immortal",
			level = 40,
			name = "Overripe",
			description = "A pineapple that kills its target bursts for 80% damage to every other monster on that tile.",
			abilityParams = { overripePercent = 80 },
		},
		{
			rarity = "God",
			level = 50,
			name = "Pineapple Express",
			description = "Lobs a giant pineapple at the furthest monster in the row for 1200% damage and a 1.5 second stun. 30s cooldown.",
			ability = "PineappleExpress",
			abilityParams = { cooldown = 30, damagePercent = 1200, stunDuration = 1.5 },
		},
	},
	BonecaAmbalabu = {
		{
			rarity = "Epic",
			level = 10,
			name = "Thick Skull",
			description = "10 headbutts before she poofs, and 33% more damage.",
			stats = { charges = 10, damage = 200 },
		},
		{
			rarity = "Legendary",
			level = 20,
			name = "God of Thunder",
			description = "Every headbutt calls down lightning on that monster: 200 damage and a 1.5 second stun.",
			abilityParams = { lightningDamage = 200, lightningStunDuration = 1.5 },
		},
		{
			rarity = "Mythic",
			level = 30,
			name = "Rattled",
			description = "Monsters she headbutts are slowed 30% for 3 seconds after the stun ends.",
			abilityParams = { rattleSlowPercent = 30, rattleSlowDuration = 3 },
		},
		{
			rarity = "Immortal",
			level = 40,
			name = "Rolling Thunder",
			description = "Each lightning strike sends electric currents into 3 to 4 nearby monsters for 50 damage each.",
			abilityParams = { chainDamage = 50, chainMinTargets = 3, chainMaxTargets = 4, chainRangeTiles = 2 },
		},
		{
			rarity = "God",
			level = 50,
			name = "Last Laugh",
			description = "Her last headbutt ends in a mushroom cloud blast that deals 450 damage on her tile and one tile on each side.",
			abilityParams = { lastLaughDamage = 450, lastLaughRadius = 1 },
		},
	},
}

local Evolutions = {}

local CLAIM_ORDER = { "Epic", "Legendary", "Mythic", "Immortal", "God" }

local function rarityIndex(rarity: string): number?
	for index, id in CLAIM_ORDER do
		if id == rarity then
			return index
		end
	end
	return nil
end

function Evolutions.rowsFor(brainrotId: string): { EvolutionRow }
	return TRACKS[brainrotId] or {}
end

function Evolutions.rowFor(brainrotId: string, rarity: string): EvolutionRow?
	for _, row in Evolutions.rowsFor(brainrotId) do
		if row.rarity == rarity then
			return row
		end
	end
	return nil
end

function Evolutions.tierUnlocked(row: EvolutionRow, brainrotLevel: number): boolean
	return brainrotLevel >= row.level
end

function Evolutions.previousRarity(rarity: string): string?
	local index = rarityIndex(rarity)
	if not index then
		return nil
	end
	if index <= 1 then
		return "Common"
	end
	return CLAIM_ORDER[index - 1]
end

function Evolutions.claimedSet(claimed: { string }?): { [string]: boolean }
	local set: { [string]: boolean } = { Common = true }
	if type(claimed) ~= "table" then
		return set
	end
	for _, rarity in claimed do
		if type(rarity) == "string" then
			set[rarity] = true
		end
	end
	return set
end

function Evolutions.sanitizeClaimed(brainrotId: string, raw: { string }?): { string }
	local rows = Evolutions.rowsFor(brainrotId)
	if #rows == 0 then
		return {}
	end
	local allowed: { [string]: boolean } = {}
	for _, row in rows do
		allowed[row.rarity] = true
	end
	-- Pre-rename saves: Celestial (40) + Immortal (50) → Immortal + God.
	local hasLegacyCelestial = false
	if type(raw) == "table" then
		for _, rarity in raw do
			if rarity == "Celestial" then
				hasLegacyCelestial = true
				break
			end
		end
	end
	local picked: { [string]: boolean } = {}
	if type(raw) == "table" then
		for _, rarity in raw do
			if type(rarity) ~= "string" then
				continue
			end
			local mapped = rarity
			if hasLegacyCelestial then
				if rarity == "Immortal" then
					mapped = "God"
				elseif rarity == "Celestial" then
					mapped = "Immortal"
				end
			end
			if allowed[mapped] then
				picked[mapped] = true
			end
		end
	end
	local result: { string } = {}
	for _, rarity in CLAIM_ORDER do
		if not allowed[rarity] then
			continue
		end
		if not picked[rarity] then
			break
		end
		table.insert(result, rarity)
	end
	return result
end

local KIND_LABEL: { [string]: string } = {
	Ability = "Ability",
	Stat = "Stat Increase",
	Active = "Active",
	Passive = "Passive",
	Ultimate = "Ultimate",
}

function Evolutions.highestClaimedRarity(claimed: { string }?): string?
	local set = Evolutions.claimedSet(claimed)
	local best: string? = nil
	for _, rarity in CLAIM_ORDER do
		if set[rarity] then
			best = rarity
		end
	end
	return best
end

-- Overlay claimed-tier `stats` and `abilityParams` onto the registry definition.
-- Later rarities overwrite earlier ones. Never mutates `base`.
function Evolutions.applyStats(base: Types.BrainrotDefinition, claimed: { string }?): Types.BrainrotDefinition
	local overlay: { [string]: any } = {}
	local paramsOverlay: { [string]: number } = {}
	local changed = false
	local set = Evolutions.claimedSet(claimed)
	if type(base.abilityParams) == "table" then
		for key, value in base.abilityParams do
			paramsOverlay[key] = value
		end
	end
	for _, rarity in CLAIM_ORDER do
		if not set[rarity] then
			continue
		end
		local row = Evolutions.rowFor(base.id, rarity)
		if not row then
			continue
		end
		if row.stats then
			for key, value in row.stats do
				overlay[key] = value
				changed = true
			end
		end
		if row.abilityParams and (type(row.ability) ~= "string" or row.ability == "") then
			for key, value in row.abilityParams do
				paramsOverlay[key] = value
				changed = true
			end
		end
	end
	if next(paramsOverlay) then
		overlay.abilityParams = paramsOverlay
	end
	if not changed then
		return base
	end
	return (setmetatable(overlay, { __index = base }) :: any) :: Types.BrainrotDefinition
end

export type ExtraAbility = {
	ability: string,
	params: { [string]: number },
}

function Evolutions.claimedExtras(brainrotId: string, claimed: { string }?): { ExtraAbility }
	local extras: { ExtraAbility } = {}
	local set = Evolutions.claimedSet(claimed)
	for _, rarity in CLAIM_ORDER do
		if not set[rarity] then
			continue
		end
		local row = Evolutions.rowFor(brainrotId, rarity)
		if not row or type(row.ability) ~= "string" or row.ability == "" then
			continue
		end
		table.insert(extras, {
			ability = row.ability,
			params = row.abilityParams or {},
		})
	end
	return extras
end

function Evolutions.kindFor(rarity: string): string
	for _, tier in EvolutionConfig.TIERS do
		if tier.id == rarity then
			return KIND_LABEL[tier.kind] or tier.kind
		end
	end
	return rarity
end

function Evolutions.auraColor(rarity: string): Color3
	return EvolutionConfig.auraForRarity(rarity)
end

return Evolutions
