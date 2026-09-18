--!strict
--[[
	EvolutionConfig
	Brainrot leveling (not campaign days) and rarity-tier gates.
	XP math is tuned so a main attacker lands around level 20–30 by Day 50.
]]

export type TierDef = {
	id: string,
	level: number,
	aura: Color3,
	kind: string,
}

local EvolutionConfig = {
	MAX_LEVEL = 50,

	-- XP to go from level n → n+1 grows each step:
	-- floor(XP_BASE * XP_GROWTH^(n-1)), then at least 1 more than level n-1.
	-- Kill / boss grants stay flat, so later levels take more kills.
	XP_BASE = 70,
	XP_GROWTH = 1.14,

	-- Normal kill: all XP to the species that landed the last hit.
	KILL_XP = 14,
	-- Boss kill: split evenly across every living plant on the lawn
	-- (4 Tungs + 1 Ballerina → Tung pool gets 4 shares).
	BOSS_XP = 140,

	-- Support jobs (ability id, not unit name). Smaller than a last-hit kill.
	COIN_XP = 5, -- GenerateCoins: per coin actually dropped
	-- Golden Discount: shared plot cooldown after a Ballerina grants the charge.
	PLANT_DISCOUNT_COOLDOWN = 20,
	SOAK_XP = 4, -- Wall: per chew / damage tick that lands
	FREEZE_XP = 20, -- FreezeTime: per monster frozen on that cast (Lirili is one-shot; no last-hit)
	BUBBLE_XP = 8, -- BubbleTrap: per BUBBLE_XP_HITS landed attacks (not last-hit)
	BUBBLE_XP_HITS = 2,
	MELEE_XP = 8, -- MeleeBat: per MELEE_XP_HITS connecting hits (not last-hit)
	MELEE_XP_HITS = 3,

	-- Landed-hit XP jobs keyed by ability id. These also skip last-hit kill XP.
	HIT_JOB = {
		BubbleTrap = { xp = 8, hits = 2 },
		MeleeBat = { xp = 8, hits = 3 },
	} :: { [string]: { xp: number, hits: number } },

	-- These abilities deal damage but earn XP via HIT_JOB, not last-hit.
	SKIP_LAST_HIT = {
		BubbleTrap = true,
		BubbleBarrage = true,
		MeleeBat = true,
	} :: { [string]: boolean },

	-- Brains to *claim* a tier after the Brainrot level gate (not auto-unlock).
	TIER_BRAINS = {
		Epic = 25,
		Legendary = 50,
		Mythic = 100,
		Immortal = 200,
		God = 400,
	} :: { [string]: number },

	TIERS = {
		{ id = "Common", level = 1, aura = Color3.fromRGB(255, 255, 255), kind = "Ability" },
		{ id = "Epic", level = 10, aura = Color3.fromRGB(168, 85, 247), kind = "Stat" },
		{ id = "Legendary", level = 20, aura = Color3.fromRGB(245, 190, 40), kind = "Active" },
		{ id = "Mythic", level = 30, aura = Color3.fromRGB(255, 110, 50), kind = "Passive" },
		{ id = "Immortal", level = 40, aura = Color3.fromRGB(160, 30, 35), kind = "Passive" },
		{ id = "God", level = 50, aura = Color3.fromRGB(255, 70, 180), kind = "Ultimate" },
	} :: { TierDef },

	-- World aura size on planted Brainrots (monsters use their own scale).
	BRAINROT_AURA_SCALE = 1.15,
}

function EvolutionConfig.xpToNext(level: number): number
	if level < 1 or level >= EvolutionConfig.MAX_LEVEL then
		return 0
	end
	local need = math.max(1, math.floor(EvolutionConfig.XP_BASE * EvolutionConfig.XP_GROWTH ^ (level - 1)))
	if level == 1 then
		return need
	end
	-- Floor on a shallow curve can stall; never allow a level to cost ≤ the last.
	return math.max(need, EvolutionConfig.xpToNext(level - 1) + 1)
end

-- Total XP required to *reach* `level` (level 1 = 0).
function EvolutionConfig.xpForLevel(level: number): number
	local clamped = math.clamp(math.floor(level), 1, EvolutionConfig.MAX_LEVEL)
	local total = 0
	for n = 1, clamped - 1 do
		total += EvolutionConfig.xpToNext(n)
	end
	return total
end

export type XpBreakdown = {
	level: number,
	xpIntoLevel: number,
	xpToNext: number,
	totalXp: number,
}

function EvolutionConfig.parseXp(totalXp: number): XpBreakdown
	local xp = math.max(0, math.floor(totalXp))
	local level = 1
	local remaining = xp
	while level < EvolutionConfig.MAX_LEVEL do
		local need = EvolutionConfig.xpToNext(level)
		if remaining < need then
			break
		end
		remaining -= need
		level += 1
	end
	local needNow = EvolutionConfig.xpToNext(level)
	return {
		level = level,
		xpIntoLevel = remaining,
		xpToNext = needNow,
		totalXp = xp,
	}
end

function EvolutionConfig.maxTotalXp(): number
	return EvolutionConfig.xpForLevel(EvolutionConfig.MAX_LEVEL)
end

function EvolutionConfig.formatProgress(totalXp: number): string
	local breakdown = EvolutionConfig.parseXp(totalXp)
	if breakdown.xpToNext <= 0 then
		return string.format("Level %d  ·  MAX", breakdown.level)
	end
	return string.format(
		"Level %d  ·  %d / %d XP",
		breakdown.level,
		breakdown.xpIntoLevel,
		breakdown.xpToNext
	)
end

function EvolutionConfig.tierForLevel(level: number): TierDef?
	local best: TierDef? = nil
	for _, tier in EvolutionConfig.TIERS do
		if level >= tier.level then
			best = tier
		end
	end
	return best
end

function EvolutionConfig.auraForRarity(rarity: string): Color3
	for _, tier in EvolutionConfig.TIERS do
		if tier.id == rarity then
			return tier.aura
		end
	end
	return Color3.fromRGB(180, 180, 190)
end

function EvolutionConfig.worldAura(rarity: string): Color3
	if rarity == "Epic" then
		return Color3.fromRGB(155, 55, 230)
	end
	if rarity == "Legendary" then
		return Color3.fromRGB(255, 196, 48)
	end
	if rarity == "Mythic" then
		return Color3.fromRGB(255, 110, 50)
	end
	if rarity == "Immortal" then
		return Color3.fromRGB(175, 28, 38)
	end
	return EvolutionConfig.auraForRarity(rarity)
end

function EvolutionConfig.isRainbow(rarity: string): boolean
	return rarity == "God"
end

function EvolutionConfig.rainbowSequence(): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 40, 70)),
		ColorSequenceKeypoint.new(0.16, Color3.fromRGB(255, 150, 30)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 50)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 220, 90)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(40, 180, 255)),
		ColorSequenceKeypoint.new(0.83, Color3.fromRGB(150, 70, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 40, 70)),
	})
end

function EvolutionConfig.rainbowFillSequence(): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 190)),
		ColorSequenceKeypoint.new(0.16, Color3.fromRGB(255, 210, 160)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 245, 180)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(180, 245, 200)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(175, 220, 255)),
		ColorSequenceKeypoint.new(0.83, Color3.fromRGB(215, 185, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 170, 190)),
	})
end

function EvolutionConfig.skipsLastHit(ability: string): boolean
	return EvolutionConfig.SKIP_LAST_HIT[ability] == true
end

function EvolutionConfig.hitJob(ability: string): { xp: number, hits: number }?
	return EvolutionConfig.HIT_JOB[ability]
end

function EvolutionConfig.brainsCost(rarity: string): number
	local cost = EvolutionConfig.TIER_BRAINS[rarity]
	if type(cost) ~= "number" then
		return 0
	end
	return math.max(0, math.floor(cost))
end

function EvolutionConfig.displayName(rarity: string): string
	if rarity == "God" then
		return "GOD"
	end
	return rarity
end

function EvolutionConfig.lightFill(rarity: string): Color3
	if EvolutionConfig.isRainbow(rarity) then
		return Color3.fromRGB(255, 236, 248)
	end
	return EvolutionConfig.auraForRarity(rarity):Lerp(Color3.fromRGB(255, 250, 255), 0.62)
end

function EvolutionConfig.darkText(rarity: string): Color3
	if EvolutionConfig.isRainbow(rarity) then
		return Color3.fromRGB(70, 20, 90)
	end
	return EvolutionConfig.auraForRarity(rarity):Lerp(Color3.fromRGB(18, 8, 28), 0.45)
end

function EvolutionConfig.lightText(rarity: string): Color3
	if EvolutionConfig.isRainbow(rarity) then
		return Color3.fromRGB(255, 230, 250)
	end
	return EvolutionConfig.auraForRarity(rarity):Lerp(Color3.fromRGB(255, 236, 255), 0.32)
end

table.freeze(EvolutionConfig.TIERS)
table.freeze(EvolutionConfig.TIER_BRAINS)
table.freeze(EvolutionConfig.SKIP_LAST_HIT)
table.freeze(EvolutionConfig.HIT_JOB)
table.freeze(EvolutionConfig)

return EvolutionConfig
