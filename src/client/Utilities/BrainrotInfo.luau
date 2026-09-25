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
		description = "Spits coins onto a random tile.",
	},
	MeleeBat = {
		label = "Melee Bat",
		description = "Bats monsters on its tile or the one ahead.",
	},
	RangedRampage = {
		label = "Ranged Rampage",
		description = "Throws a spinning bat down the row. Hits knock monsters back a quarter tile.",
	},
	SahurWrath = {
		label = "Sahur's Wrath",
		description = "A giant bat slams the whole row for 1000% damage, and the rows beside it for 500%. Needs 3 or more monsters, or a boss.",
	},
	BubbleTrap = {
		label = "Bubble Trap",
		description = "Shoots a bubble that traps the closest monster in the row.",
	},
	LineBomb = {
		label = "Line Bomb",
		description = "Blows up the whole row once, right when you plant it.",
	},
	FreezeTime = {
		label = "Freeze",
		description = "Freezes 2 tiles in front and 2 behind for 7 seconds, then vanishes. Monsters can't eat it.",
	},
	ThrowKnife = {
		label = "Throw Shuriken",
		description = "Throws a spinning shuriken at the closest monster in the row.",
	},
	LobPineapple = {
		label = "Lob Pineapple",
		description = "Lobs a pineapple over the front monster and any grave, hitting the one behind. If only one monster is in the row, it hits that one.",
	},
	InkPuddle = {
		label = "Ink Puddle",
		description = "Lobs ink onto a random empty tile in her row. Closer tiles arc lower, farther tiles arc higher. The puddle lasts 7 seconds and slows monsters while they walk through it. 10 second cooldown.",
	},
	PullToLane = {
		label = "Pull To Lane",
		description = "Floats above the tile, then pulls the closest 1-tile monster from each neighboring row onto her tile. Monsters two or more tiles wide are left alone. An edge row pulls one. A middle row pulls one from each side. Then she vanishes.",
	},
	Wall = {
		label = "Sturdy Wall",
		description = "Doesn't attack. Blocks the row and soaks up hits.",
	},
	Stoneheart = {
		label = "Stoneheart",
		description = "Once, below 10% health, turns to stone for 10 seconds and can't be hurt. It can't attack while stone.",
	},
	TenfoldGuard = {
		label = "Tenfold Guard",
		description = "Every 10 attacks, gains a shield for 30% of its max HP for 5 seconds and can't be stunned.",
	},
	ClearFogRow = {
		label = "Clear Fog",
		description = "Blows the night fog off the lawn for 7 seconds, then vanishes.",
	},
	BustGrave = {
		label = "Grave Smash",
		description = "Plant him on a grave. Monsters walk past him. 2 smashes per swing, 1 second apart. 6 smashes break the grave, then he vanishes.",
	},
	PierceBrew = {
		label = "Piercing Brew",
		description = "For 6 seconds, shurikens hit the first monster and the one behind it, even through graves. 10s cooldown.",
	},
	Jackpot = {
		label = "Jackpot",
		description = "For 10 seconds, coins come out 200% faster, and each coin has a 33% chance to drop an extra. 30s cooldown.",
	},
	PrimalRetaliation = {
		label = "Primal Retaliation",
		description = "For 15 seconds, sends 25% of bite damage back at that monster. 30s cooldown.",
	},
	ShadowRequiem = {
		label = "Shadow Requiem",
		description = "Sends a growing sword wave down the row for 2000% damage, plus 100% per tile, then a 1000% blast on the last tile. Needs 3 or more monsters, or a boss. 45s cooldown.",
	},
	AbyssalTorrent = {
		label = "Abyssal Torrent",
		description = "Shoots a water jet from his mouth to the end of the row for 15 seconds. It goes through every monster in the way. Each second in the jet deals 55 damage, plus 20% more for every tile closer to him, and pushes them back 0.25 tiles. Needs 3 or more monsters, or a boss. The closest one fires first. 45s cooldown.",
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
		return "No special ability."
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
			value = string.format("%d each time", definition.coinGeneration),
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
