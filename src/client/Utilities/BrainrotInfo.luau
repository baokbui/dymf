--!strict
--[[
	BrainrotInfo
	Client-only display text for Brainrot ability ids and formatted stat rows.
	Presentation only — a lookup table keyed by ability id (data-driven, never
	a per-Brainrot-name branch) so tooltips/inspectors read the same registry
	everything else uses.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrainrotConfig = require(Shared.Config.BrainrotConfig)
local Types = require(Shared.Types)

local BrainrotInfo = {}

export type StatRow = { label: string, value: string }

local ABILITY_INFO: { [string]: { label: string, description: string } } = {
	GenerateCoins = {
		label = "Coin Generator",
		description = "Spits coins onto a random lawn tile every cycle.",
	},
	MeleeBat = {
		label = "Melee Bat",
		description = "Bats monsters on its own tile or the tile ahead.",
	},
	RangedRampage = {
		label = "Ranged Rampage",
		description = "Throws a spinning bat from the left hand down the whole row. Hits on the lawn knock monsters back half a tile.",
	},
	SahurWrath = {
		label = "Sahur's Wrath",
		description = "A giant bat grows above Tung, then his melee swing arcs it onto the row covering every tile to the plot edge. Needs 4+ enemies or a boss in the row; the Tung closest to the enemies slams first.",
	},
	BubbleTrap = {
		label = "Bubble Trap",
		description = "Launches a bubble that traps the closest monster in the row.",
	},
	LineBomb = {
		label = "Line Bomb",
		description = "Explodes across the entire row once, on placement.",
	},
	FreezeTime = {
		label = "Freeze",
		description = "Freezes 2 tiles in front and 2 behind (7s) on plant, then disappears. Can't be eaten.",
	},
	ThrowKnife = {
		label = "Throw Shuriken",
		description = "Throws a spinning shuriken at the closest monster in the row.",
	},
	Wall = {
		label = "Sturdy Wall",
		description = "No attack — just soaks up hits to block the lane.",
	},
	Stoneheart = {
		label = "Stoneheart",
		description = "Once per plant: below 10% HP, turns to stone and is invulnerable for 10s. Cannot use active or ultimate while stone.",
	},
	TenfoldGuard = {
		label = "Tenfold Guard",
		description = "Every 10 attacks: shield 30% max HP for 5s. Stun-immune while that shield lasts. A small shield orbits Tung.",
	},
	ClearFogRow = {
		label = "Clear Fog",
		description = "One-shot. Plays a gust, blows Night Fog off the whole plot for 7s, then disappears.",
	},
	BustGrave = {
		label = "Grave Smash",
		description = "Plant on a grave. Immune — monsters walk through. Two smashes per swing (1s apart); 6 collapse the stone, then he disappears.",
	},
	PierceBrew = {
		label = "Piercing Brew",
		description = "Next shuriken flies through graves and hits the monster behind the first. The grave takes no damage.",
	},
	Jackpot = {
		label = "Jackpot",
		description = "For 10s, produce coins 3× faster; each coin has a 33% chance to drop an extra. Independent of Encore. 30s cooldown.",
	},
	PrimalRetaliation = {
		label = "Primal Retaliation",
		description = "For 15s, reflect 25% of chew damage back to that monster. A small mirror orbits Chimpanzini. 30s cooldown.",
	},
}

function BrainrotInfo.abilityLabel(abilityId: string?): string
	if not abilityId then
		return "None"
	end
	local info = ABILITY_INFO[abilityId]
	return if info then info.label else abilityId
end

function BrainrotInfo.abilityDescription(abilityId: string?): string
	if not abilityId then
		return "This unit has no active ability."
	end
	local info = ABILITY_INFO[abilityId]
	return if info then info.description else "—"
end

local function formatSeconds(seconds: number): string
	local rounded = math.floor(seconds * 10 + 0.5) / 10
	if rounded == math.floor(rounded) then
		return string.format("%ds", rounded)
	end
	return string.format("%.1fs", rounded)
end

local function formatRange(definition: Types.BrainrotDefinition): string?
	local range = definition.rangeTiles
	if range == nil or range == 0 then
		return nil
	end
	if range == BrainrotConfig.FULL_LINE_RANGE then
		return "Full row"
	end
	return string.format("%d tile%s", range, if range == 1 then "" else "s")
end

-- Ordered stat rows for a tooltip / inspector. Only includes rows relevant to
-- the unit (e.g. Damage is omitted for pure support/coin units).
function BrainrotInfo.statRows(definition: Types.BrainrotDefinition): { StatRow }
	local rows: { StatRow } = {}

	table.insert(rows, { label = "Cost", value = string.format("%d coins", definition.cost) })
	if definition.ignoreMonsterChew or definition.health <= 0 then
		table.insert(rows, { label = "Health", value = "—" })
	else
		table.insert(rows, { label = "Health", value = string.format("%d HP", definition.maxHealth) })
	end

	if definition.damage > 0 then
		table.insert(rows, { label = "Damage", value = tostring(definition.damage) })
	end

	if definition.attackInterval > 0 then
		table.insert(rows, {
			label = "Atk. Speed",
			value = string.format("every %s", formatSeconds(definition.attackInterval)),
		})
	end

	local range = formatRange(definition)
	if range then
		table.insert(rows, { label = "Range", value = range })
	end

	if definition.coinGeneration and definition.coinGeneration > 0 then
		table.insert(rows, {
			label = "Coins",
			value = string.format("%d / cycle", definition.coinGeneration),
		})
	end

	local params = definition.abilityParams
	if params then
		local trap = params.trapDuration
		if type(trap) == "number" and trap > 0 then
			table.insert(rows, { label = "Trap", value = formatSeconds(trap) })
		end
		local freeze = params.freezeDuration
		if type(freeze) == "number" and freeze > 0 then
			table.insert(rows, { label = "Freeze", value = formatSeconds(freeze) })
		end
	end

	local recharge = BrainrotConfig.plantCooldownFor(definition)
	if recharge > 0 then
		table.insert(rows, { label = "Recharge", value = formatSeconds(recharge) })
	end

	table.insert(rows, { label = "Ability", value = BrainrotInfo.abilityLabel(definition.ability) })

	return rows
end

return BrainrotInfo
