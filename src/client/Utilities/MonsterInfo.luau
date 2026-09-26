--!strict
--[[
	MonsterInfo
	Client-only display text for monster / boss ability ids and formatted
	stat rows. Presentation only — lookups are keyed by ability id (never
	monster name) so intros/tooltips stay data-driven.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)

local MonsterInfo = {}

export type StatRow = { label: string, value: string }

local ABILITY_INFO: { [string]: { label: string, description: string } } = {
	SpiderJump = {
		label = "Leap",
		description = "Jumps over the first Brainrot, then eats the rest.",
	},
	GoblinEliteClubOneShot = {
		label = "Crushing Club",
		description = "Knocks out Brainrots in all three of its rows.",
	},
	QueenSpiderStun = {
		label = "Stun",
		description = "Stuns Brainrots it bites for 2 seconds.",
	},
	QueenSpiderPoison = {
		label = "Poison Bite",
		description = "Every second bite poisons for 3% health each second, for 4 seconds.",
	},
	DukeVampireFreeze = {
		label = "Last Stand",
		description = "At 20% health, falls and can't be hurt, then gets back up at 25% health.",
	},
	DukeVampireTerrify = {
		label = "Terrify",
		description = "Weakens and freezes Brainrots in its row and the rows beside it.",
	},
	SkeletonArrow = {
		label = "Bone Arrow",
		description = "Stops 3 tiles away and shoots. Doesn't bite.",
	},
	WerewolfLifesteal = {
		label = "Lifesteal",
		description = "Heals 5% of its max HP every time it bites a Brainrot.",
	},
	NecromancerSummon = {
		label = "Raise Dead",
		description = "Summons smaller undead onto the lawn.",
	},
	NecromancerLaneChange = {
		label = "Lane Shift",
		description = "Can switch rows while walking.",
	},
	GoblinKingRegen = {
		label = "Royal Regen",
		description = "Heals 5% of its max HP every 10 seconds.",
	},
	GoblinKingAttackBuff = {
		label = "War Cry",
		description = "While he is alive, he and every Goblin gain 10% attack damage.",
	},
	PharaohSummon = {
		label = "Raise the Guard",
		description = "Summons a Small Mummy in every row. 20s cooldown.",
	},
	PharaohSteal = {
		label = "Royal Tribute",
		description = "Steals one Brainrot from 3 random rows. 15s cooldown.",
	},
	ScorpionBurrow = {
		label = "Burrow",
		description = "Digs under the lawn and pops up in front of the first Brainrot. Skips empty rows.",
	},
	ScorpionVenom = {
		label = "Venom",
		description = "Every third bite applies Venom: 3% health each second, for 4 seconds.",
	},
}

local function abilityIds(definition: Types.MonsterDefinition): { string }
	if not definition.abilities then
		return {}
	end
	return definition.abilities
end

function MonsterInfo.abilityLabel(abilityId: string?): string
	if not abilityId then
		return "None"
	end
	local info = ABILITY_INFO[abilityId]
	return if info then info.label else abilityId
end

function MonsterInfo.abilityDescription(abilityId: string?): string
	if not abilityId then
		return "No special ability."
	end
	local info = ABILITY_INFO[abilityId]
	return if info then info.description else "—"
end

function MonsterInfo.abilitySummary(definition: Types.MonsterDefinition): string
	local ids = abilityIds(definition)
	if #ids == 0 then
		return "No special ability. It just bites Brainrots in its row."
	end
	local parts: { string } = {}
	for _, id in ids do
		table.insert(
			parts,
			string.format("%s — %s", MonsterInfo.abilityLabel(id), MonsterInfo.abilityDescription(id))
		)
	end
	return table.concat(parts, "\n")
end

function MonsterInfo.statRows(definition: Types.MonsterDefinition): { StatRow }
	local rows: { StatRow } = {
		{ label = "Health", value = tostring(definition.health) },
		{ label = "Speed", value = string.format("%.1fs/tile", definition.secondsPerGrid) },
	}
	if definition.damage > 0 then
		table.insert(rows, { label = "Damage", value = tostring(definition.damage) })
		table.insert(
			rows,
			{ label = "Attack", value = string.format("%.1fs", definition.attackInterval) }
		)
	end
	if type(definition.rangedTiles) == "number" and definition.rangedTiles > 0 then
		table.insert(rows, { label = "Range", value = string.format("%d tiles", definition.rangedTiles) })
	end
	local span = definition.laneSpan or 1
	if span > 1 then
		table.insert(rows, { label = "Width", value = string.format("%d lanes", span) })
	end
	if definition.isBoss then
		table.insert(rows, { label = "Type", value = "Boss" })
	end
	return rows
end

return MonsterInfo
