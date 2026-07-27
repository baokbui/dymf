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
		description = "Freezes nearby monsters in place for a short time.",
	},
	ThrowKnife = {
		label = "Throw Shuriken",
		description = "Throws a spinning shuriken at the closest monster in the row.",
	},
	Wall = {
		label = "Sturdy Wall",
		description = "No attack — just soaks up hits to block the lane.",
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
	table.insert(rows, { label = "Health", value = string.format("%d hits", definition.health) })

	if definition.damage > 0 then
		table.insert(rows, { label = "Damage", value = tostring(definition.damage) })
		if definition.attackInterval > 0 then
			table.insert(rows, { label = "Attack Speed", value = string.format("every %.1fs", definition.attackInterval) })
		end
	end

	local range = formatRange(definition)
	if range then
		table.insert(rows, { label = "Range", value = range })
	end

	if definition.coinGeneration and definition.coinGeneration > 0 then
		table.insert(rows, {
			label = "Coin Generation",
			value = string.format("%d coins / %.0fs", definition.coinGeneration, definition.attackInterval),
		})
	end

	table.insert(rows, { label = "Ability", value = BrainrotInfo.abilityLabel(definition.ability) })

	return rows
end

return BrainrotInfo
