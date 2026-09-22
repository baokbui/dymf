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
		description = "Vaults over the first Brainrot in its lane, then chews the rest.",
	},
	GoblinEliteClubOneShot = {
		label = "Crushing Club",
		description = "One-shots Brainrots across all three lanes it occupies.",
	},
	QueenSpiderStun = {
		label = "Venom Stun",
		description = "Stuns chewed Brainrots for 2 seconds.",
	},
	QueenSpiderPoison = {
		label = "Venom Poison",
		description = "Poisons chewed Brainrots for a few seconds (DoT).",
	},
	DukeVampireFreeze = {
		label = "Last Stand",
		description = "Once at low HP: falls, turns invulnerable, and heals back up.",
	},
	DukeVampireTerrify = {
		label = "Terrify",
		description = "Weakens and freezes Brainrots in its lane and the lanes beside it.",
	},
	SkeletonArrow = {
		label = "Bone Arrow",
		description = "Stops 3 tiles east of a Brainrot and shoots arrows. Does not chew.",
	},
	WerewolfLifesteal = {
		label = "Lifesteal",
		description = "Heals 5% of its max HP every time it chews a Brainrot.",
	},
	NecromancerSummon = {
		label = "Raise Dead",
		description = "Summons lesser undead onto the lawn.",
	},
	NecromancerLaneChange = {
		label = "Lane Shift",
		description = "Can change lanes while marching.",
	},
	GoblinKingRegen = {
		label = "Royal Regen",
		description = "Steadily regenerates health while alive.",
	},
	GoblinKingSpeedBuff = {
		label = "War Cry",
		description = "Speeds up nearby monsters (stub).",
	},
	PharaohSummon = {
		label = "Raise the Guard",
		description = "Summons a Small Mummy in every lane (20s cooldown).",
	},
	PharaohSteal = {
		label = "Royal Tribute",
		description = "Steals one Brainrot from each of 3 random lanes (15s cooldown).",
	},
	ScorpionBurrow = {
		label = "Burrow",
		description = "Digs under the lawn on entry and rises in front of the first Brainrot. Does not burrow in empty lanes.",
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
		return "No special ability — chews Brainrots in its lane."
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
