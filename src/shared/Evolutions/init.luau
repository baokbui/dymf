--!strict
--[[
	Evolutions
	Epic→God catalog. Claiming a tier costs brains after the Brainrot
	level gate. Epic `stats` compose onto the shared registry definition. Legendary extras
	and Mythic / Immortal passives resolve from `ability` ids / `abilityParams` (never
	mutate the catalog; never branch on unit names). GOD ultimates: `Jackpot`,
	`PrimalRetaliation`, `SahurWrath`, `ShadowRequiem`, plus Lirili `freezeEntireLawn` overlay.
	Tidal Cataclysm is not wired yet.
]]

local EvolutionConfig = require(script.Parent.Config.EvolutionConfig)
local Types = require(script.Parent.Types)

export type StatOverrides = {
	attackInterval: number?,
	maxHealth: number?,
	health: number?,
	damage: number?,
	plantCooldown: number?,
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
			description = "Coin interval 12s (from 18s).",
			stats = { attackInterval = 12 },
		},
		{
			rarity = "Legendary",
			level = 20,
			name = "Golden Waltz",
			description = "Every 30s, produce coins 2x faster for 6s.",
			ability = "CoinHaste",
			abilityParams = { cooldown = 30, duration = 6, factor = 2 },
		},
		{
			rarity = "Mythic",
			level = 30,
			name = "Encore",
			description = "Each coin produced: 30% chance to produce one extra.",
			abilityParams = { extraCoinChance = 30 },
		},
		{
			rarity = "Immortal",
			level = 40,
			name = "Golden Discount",
			description = "When producing a coin, the next Brainrot plant (any unit) costs 50%. 20s cooldown shared by all planted Ballerinas.",
			abilityParams = { plantDiscountPercent = 50, plantDiscountCooldown = 20 },
		},
		{ rarity = "God", level = 50, name = "Jackpot", description = "Produce coins 3× faster for 10s; each coin during the ultimate 33% extra. 30s cooldown.", ability = "Jackpot", abilityParams = { cooldown = 30, duration = 10, factor = 3, extraChance = 33 } },
	},
	ChimpanziniBananini = {
		{
			rarity = "Epic",
			level = 10,
			name = "Goliath",
			description = "4000 HP (from 2000).",
			stats = { maxHealth = 4000 },
		},
		{
			rarity = "Legendary",
			level = 20,
			name = "Banana Bastion",
			description = "Shield 500 HP every 10s.",
			ability = "ShieldPulse",
			abilityParams = { cooldown = 10, shield = 500 },
		},
		{
			rarity = "Mythic",
			level = 30,
			name = "Jungle Vitality",
			description = "Heal 5% max HP every 5s.",
			ability = "RegenPulse",
			abilityParams = { cooldown = 5, healPercent = 5 },
		},
		{
			rarity = "Immortal",
			level = 40,
			name = "Stoneheart",
			description = "Once per plant: below 10% HP, turn to stone and become invulnerable for 10s. Can't act while stone.",
			ability = "Stoneheart",
			abilityParams = { healthPercent = 10, duration = 10 },
		},
		{ rarity = "God", level = 50, name = "Primal Retaliation", description = "For 15s, reflect 25% of chew damage to that monster. 30s cooldown.", ability = "PrimalRetaliation", abilityParams = { cooldown = 30, duration = 15, reflectPercent = 25 } },
	},
	TungTungSahur = {
		{
			rarity = "Epic",
			level = 10,
			name = "Tung Tung Training",
			description = "1500 HP / 100 dmg (from 1200 / 55).",
			stats = { maxHealth = 1500, damage = 100 },
		},
		{
			rarity = "Legendary",
			level = 20,
			name = "Ranged Rampage",
			description = "Throw a spinning bat down the row for 10s. Lawn hits knock back half a tile.",
			ability = "RangedRampage",
			abilityParams = { cooldown = 20, duration = 10 },
		},
		{
			rarity = "Mythic",
			level = 30,
			name = "Desperate Fury",
			description = "Once per plant: below 50% HP, +50% attack speed.",
			ability = "DesperateFury",
			abilityParams = { healthPercent = 50, factor = 1.5 },
		},
		{
			rarity = "Immortal",
			level = 40,
			name = "Tenfold Guard",
			description = "Every 10 attacks: shield 30% max HP for 5s. Stun-immune while shielded.",
			ability = "TenfoldGuard",
			abilityParams = { every = 10, shieldPercent = 30, duration = 5, orbitShield = 1 },
		},
		{
			rarity = "God",
			level = 50,
			name = "Sahur's Wrath",
			description = "Giant bat slams the whole row to the plot edge for 1000% damage, plus 500% on the adjacent rows. Needs 3+ enemies or a boss. 30s cooldown.",
			ability = "SahurWrath",
			abilityParams = { cooldown = 30, damagePercent = 1000, splashPercent = 500, minEnemies = 3 },
		},
	},
	TralaleroTralala = {
		{
			rarity = "Epic",
			level = 10,
			name = "Ocean's Rhythm",
			description = "Attack interval 3s (from 5s).",
			stats = { attackInterval = 3 },
		},
		{
			rarity = "Legendary",
			level = 20,
			name = "Bubble Barrage",
			description = "Shoot one bubble from the mouth; it splits into 5, one per lawn row. 15s cooldown.",
			ability = "BubbleBarrage",
			abilityParams = { cooldown = 15 },
		},
		{
			rarity = "Mythic",
			level = 30,
			name = "Double Bubble",
			description = "Each bubble 33% chance to spawn an extra trap bubble.",
			abilityParams = { extraBubbleChance = 33 },
		},
		{
			rarity = "Immortal",
			level = 40,
			name = "Wound of the Shark",
			description = "Monsters leaving a bubble are slowed 40% for 3s.",
			abilityParams = { bubbleExitSlowPercent = 40, bubbleExitSlowDuration = 3 },
		},
		{ rarity = "God", level = 50, name = "Tidal Cataclysm", description = "Lane tsunami: knockback + stun, then slow 30% for 3s." },
	},
	CappuccinoAssassino = {
		{
			rarity = "Epic",
			level = 10,
			name = "Espresso Rush",
			description = "+50% attack speed.",
			-- 2s base / 1.5 = ~1.333s between knives.
			stats = { attackInterval = 2 / 1.5 },
		},
		{
			rarity = "Legendary",
			level = 20,
			name = "Piercing Brew",
			description = "For 6s, knives pierce the first monster and the one behind (flies through graves). 10s cooldown.",
			ability = "PierceBrew",
			abilityParams = { cooldown = 10, duration = 6 },
		},
		{
			rarity = "Mythic",
			level = 30,
			name = "Fifth Strike",
			description = "Every 5th attack deals 200% dmg.",
			abilityParams = { fifthStrikeEvery = 5, fifthStrikeFactor = 2 },
		},
		{
			rarity = "Immortal",
			level = 40,
			name = "Assassin's Verdict",
			description = "Execute on hit if target is below 7.5% HP (2% for bosses).",
			abilityParams = { executeHealthPercent = 7.5, executeBossPercent = 2 },
		},
		{
			rarity = "God",
			level = 50,
			name = "Shadow Requiem",
			description = "A sword wave flies down the row, growing as it goes. 2000% plus 100% per tile, then a last-tile pillar for +1000%. Needs 3+ enemies or a boss. 45s cooldown.",
			ability = "ShadowRequiem",
			abilityParams = { cooldown = 45, damagePercent = 2000, travelPercent = 100, finisherPercent = 1000, minEnemies = 3 },
		},
	},
	LiriliLarila = {
		{
			rarity = "Epic",
			level = 10,
			name = "Cryocycle",
			description = "Plant recharge 15s (from 20s).",
			stats = { plantCooldown = 15 },
		},
		{
			rarity = "Legendary",
			level = 20,
			name = "Winter's Grasp",
			description = "Freeze a whole lane.",
			abilityParams = { freezeEntireLane = 1 },
		},
		{
			rarity = "Mythic",
			level = 30,
			name = "Permafrost",
			description = "Freeze duration 7s.",
			abilityParams = { freezeDuration = 7 },
		},
		{
			rarity = "Immortal",
			level = 40,
			name = "Frostbound Neighbor",
			description = "Also freeze the adjacent lane with more monsters. Ties go to the lower row.",
			abilityParams = { freezeAdjacentLane = 1 },
		},
		{ rarity = "God", level = 50, name = "Glacial Dominion", description = "Freeze the whole lawn and apply 25% slow for 3s after thaw.", abilityParams = { freezeEntireLawn = 1, lawnSlowPercent = 25, lawnSlowDuration = 3 } },
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
