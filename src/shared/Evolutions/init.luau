--!strict
--[[
	Evolutions
	Display catalog for the Epic→Immortal ladder. Claiming a tier costs brains
	after the Brainrot level gate. Combat bonuses are not applied yet.
]]

local EvolutionConfig = require(script.Parent.Config.EvolutionConfig)

export type EvolutionRow = {
	rarity: string,
	level: number,
	name: string,
	description: string,
}

local TRACKS: { [string]: { EvolutionRow } } = {
	BallerinaCappucina = {
		{ rarity = "Epic", level = 10, name = "Wallet Ballet", description = "Coin interval 12s (from 18s)." },
		{ rarity = "Legendary", level = 20, name = "Golden Waltz", description = "Every 30s, generate 1 coin, then produce coins 2× faster for 6s." },
		{ rarity = "Mythic", level = 30, name = "Encore", description = "Each coin produced: 30% chance to produce one extra." },
		{ rarity = "Celestial", level = 40, name = "Golden Discount", description = "When producing a coin, the next Brainrot plant costs 50%." },
		{ rarity = "Immortal", level = 50, name = "Jackpot", description = "Produce coins 3× faster; each coin during the ultimate 33% extra. 30s cooldown." },
	},
	ChimpanziniBananini = {
		{ rarity = "Epic", level = 10, name = "Goliath", description = "4000 HP (from 2000)." },
		{ rarity = "Legendary", level = 20, name = "Banana Bastion", description = "Shield 500 HP every 10s." },
		{ rarity = "Mythic", level = 30, name = "Jungle Vitality", description = "Heal 5% max HP every 5s." },
		{ rarity = "Celestial", level = 40, name = "Stoneheart", description = "Once per plant: below 10% HP, stone / invulnerable 10s. No active or ultimate while stone." },
		{ rarity = "Immortal", level = 50, name = "Primal Retaliation", description = "15s: reflect 25% of chew damage to that monster. 30s cooldown." },
	},
	TungTungSahur = {
		{ rarity = "Epic", level = 10, name = "Tung Tung Training", description = "1500 HP / 100 dmg (from 1200 / 55)." },
		{ rarity = "Legendary", level = 20, name = "Ranged Rampage", description = "Becomes a ranged attacker for 10s." },
		{ rarity = "Mythic", level = 30, name = "Desperate Fury", description = "Once per plant: below 50% HP, +50% attack speed." },
		{ rarity = "Celestial", level = 40, name = "Tenfold Guard", description = "Every 10 attacks: shield 30% max HP for 5s; stun-immune while shielded." },
		{ rarity = "Immortal", level = 50, name = "Sahur's Wrath", description = "Hit the entire lane once for 1000% of original damage. 30s cooldown." },
	},
	TralaleroTralala = {
		{ rarity = "Epic", level = 10, name = "Ocean's Rhythm", description = "Attack interval 3s (from 5s)." },
		{ rarity = "Legendary", level = 20, name = "Bubble Barrage", description = "Fire 5 bubbles at once, one per lawn row; each traps. 15s cooldown." },
		{ rarity = "Mythic", level = 30, name = "Double Bubble", description = "Each bubble 33% chance to spawn an extra trap bubble." },
		{ rarity = "Celestial", level = 40, name = "Wound of the Shark", description = "Monsters leaving a bubble are slowed 40% for 3s." },
		{ rarity = "Immortal", level = 50, name = "Tidal Cataclysm", description = "Lane tsunami: knockback + stun, then slow 30% for 3s." },
	},
	CappuccinoAssassino = {
		{ rarity = "Epic", level = 10, name = "Espresso Rush", description = "+50% attack speed." },
		{ rarity = "Legendary", level = 20, name = "Piercing Brew", description = "Attack pierces the first monster: 100% dmg to it and the one behind. 10s cooldown." },
		{ rarity = "Mythic", level = 30, name = "Fifth Strike", description = "Every 5th attack deals 200% dmg." },
		{ rarity = "Celestial", level = 40, name = "Assassin's Verdict", description = "Execute on hit if target is below 7.5% HP (2% for bosses)." },
		{ rarity = "Immortal", level = 50, name = "Shadow Requiem", description = "Vanish to the east end of the lane, run back, stab every monster for 2000% dmg. 45s cooldown." },
	},
	LiriliLarila = {
		{ rarity = "Epic", level = 10, name = "Cryocycle", description = "Plant recharge 15s (from 20s)." },
		{ rarity = "Legendary", level = 20, name = "Winter's Grasp", description = "Freeze a whole lane." },
		{ rarity = "Mythic", level = 30, name = "Permafrost", description = "Freeze duration 7s." },
		{ rarity = "Celestial", level = 40, name = "Frostbound Neighbor", description = "Also freeze one adjacent lane." },
		{ rarity = "Immortal", level = 50, name = "Glacial Dominion", description = "Freeze the whole lawn and apply 25% slow for 3s." },
	},
}

local Evolutions = {}

local CLAIM_ORDER = { "Epic", "Legendary", "Mythic", "Celestial", "Immortal" }

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
	local picked: { [string]: boolean } = {}
	if type(raw) == "table" then
		for _, rarity in raw do
			if type(rarity) == "string" and allowed[rarity] then
				picked[rarity] = true
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
