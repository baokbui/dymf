--!strict
-- Inject real pure rules/registries; no player data, remotes or DataStore.
return function(Achievements: any, Quests: any, Goal: any, Brainrots: any, Evolution: any, Evolutions: any): number
	local count = 0
	local function check(value: any, message: string)
		count += 1
		assert(value, message)
	end
	local state = Quests.sanitize(nil)
	check(Achievements.claim(state, 0, "FirstBoss", 0) == nil, "incomplete objective")
	check(Achievements.claim(state, 0, "Unknown", 0) == nil, "unknown objective")
	local starters = { "BallerinaCappucina", "TungTungSahur", "ChimpanziniBananini" }
	Achievements.catchUp(state, { unlocks = starters, evolutions = {}, statistics = { bossesDefeated = 500 }, introducedMonsters = { "GoblinKing" }, playerHealth = 5 })
	check(state.achievements.OwnFiveBrainrots.progress == 3, "starter ownership")
	check(state.achievements.FirstBoss.progress == 0 and state.achievements.FirstPerfectDefense.progress == 0, "historical events inferred")
	local duplicate = table.clone(starters)
	table.insert(duplicate, starters[1]); table.insert(duplicate, "Unknown")
	Achievements.catchUp(state, { unlocks = duplicate, evolutions = { Unknown = { "Epic" } } })
	check(state.achievements.OwnFiveBrainrots.progress == 3 and state.achievements.FirstEpic.progress == 0, "invalid catch-up")
	Achievements.record(state, "MonsterDefeated", { isBoss = false })
	check(state.achievements.FirstBoss.progress == 0, "regular kill counted")
	Achievements.record(state, "MonsterDefeated", { isBoss = true })
	check(state.achievements.FirstBoss.progress == 1, "boss kill missed")
	check(#Achievements.record(state, "MonsterDefeated", { isBoss = true }) == 0, "duplicate completion")
	local all = {}
	for _, definition in Brainrots.getAll() do
		if not definition.hidden then table.insert(all, definition.id) end
	end
	Achievements.catchUp(state, { unlocks = all, evolutions = { TungTungSahur = { "Epic", "Legendary", "God" } },
		statistics = { monstersDefeated = 500, brainrotsPlaced = 100 } })
	check(state.achievements.FirstEpic.progress == 1, "claimed Epic catch-up")
	check(state.achievements.OwnFiveBrainrots.progress == 5 and state.achievements.OwnTenBrainrots.progress == 10, "ownership objectives capped")
	Achievements.record(state, "PerfectDefense")
	local total = 0
	for _, row in Achievements.clientState(state) do
		check(row.progress == row.target and not row.claimed, "objective state")
		total += Achievements.claim(state, 0, row.id, 0)
		check(Achievements.claim(state, 999, row.id, 999) == nil, "permanent duplicate")
	end
	check(total == 75, "achievement budget")
	Achievements.syncCampaign(state, 9)
	check(#Achievements.clientState(state, true) == 10, "campaign milestones missing")
	check(Achievements.claim(state, 0, "ReachDay10", 0) == nil, "locked milestone paid")
	check(Achievements.claim(state, 0, "ReachDay5", 0) == 5, "reached milestone missing")
	check(Achievements.claim(state, 999, "ReachDay5", 999) == nil, "milestone paid twice")
	Achievements.syncCampaign(state, 50)
	check(Achievements.claim(state, 0, "ReachDay50", 0) == 14, "last milestone missing")
	state = Quests.sanitize(state)
	Quests.ensure(state, 99999 * 86400, 50)
	check(state.achievements.FirstBoss.claimed and state.achievements.FirstEpic.claimed, "rollover lost permanent claims")
	local migrated = Achievements.sanitize({ FirstBoss = true, FirstEpic = { progress = 0 / 0 }, Unknown = true })
	check(migrated.FirstBoss.claimed and migrated.FirstBoss.progress == 1, "legacy claimed flag")
	check(migrated.FirstEpic.progress == 0 and migrated.Unknown == nil, "malformed progress")
	local goal = Goal.select({ unlocks = starters, evolutions = {}, brains = 0, brainrotXp = {} }, 1, 50)
	check(goal.kind == "Campaign" and goal.brainrotId == "CappuccinoAssassino", "new-player unlock goal")
	local profile = { unlocks = all, equipped = { "TungTungSahur" }, evolutions = {}, brains = 10,
		brainrotXp = { TungTungSahur = Evolution.xpForLevel(10) } }
	goal = Goal.select(profile, 15, 50)
	check(goal.kind == "Evolution" and goal.rarity == "Epic" and goal.brainrotId == "TungTungSahur", "eligible evolution")
	check(goal.brainsNeeded == 15, "brains shortfall")
	profile.brains = 25
	goal = Goal.select(profile, 15, 50)
	check(goal.brainsNeeded == 0 and goal.description:find("25 Brains", 1, true), "affordable evolution")
	profile.evolutions.TungTungSahur = { "Epic" }
	goal = Goal.select(profile, 15, 50)
	check(goal.kind == "Level" and goal.rarity == "Legendary", "next unclaimed gate")
	profile.brainrotXp.TungTungSahur = Evolution.xpForLevel(50)
	goal = Goal.select(profile, 15, 50)
	check(goal.kind == "Evolution" and goal.rarity == "Legendary", "later tiers cannot skip earlier claims")
	for _, id in all do
		profile.evolutions[id] = {}
		profile.brainrotXp[id] = Evolution.xpForLevel(50)
		for _, row in Evolutions.rowsFor(id) do table.insert(profile.evolutions[id], row.rarity) end
	end
	goal = Goal.select(profile, 50, 50)
	check(goal.kind == "Campaign" and not goal.rarity, "max-level player offered unavailable tier")
	goal = Goal.select({ unlocks = { "GiraffaCeleste" }, evolutions = {}, brainrotXp = {} }, 1, 50)
	check(goal.kind == "Campaign", "unit without evolution offered a tier")
	return count
end
