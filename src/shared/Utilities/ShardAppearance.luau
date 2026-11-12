--!strict
local Shared = script.Parent.Parent
local Config = require(Shared.Config.ShardVisualConfig)
local Species = require(Shared.Config.FarmProgressionConfig).MONSTERS
local Monsters = require(Shared.Monsters)
local Appearance = {}

function Appearance.rarity(monsterId: string): number
	local entry = Species[monsterId]
	if entry and entry.major then return 2 end
	local definition = Monsters.get(monsterId)
	return if definition and definition.isBoss then 1 else 0
end

function Appearance.color(monsterId: string): Color3
	return Config.SPECIES_COLORS[monsterId] or Config.COMMON_COLOR
end

return Appearance
