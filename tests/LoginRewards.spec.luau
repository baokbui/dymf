--!strict
-- First-time track and calendar regressions; never accesses player data.
return function(Login: any, Quests: any, Config: any, Time: any, Grant: any): number
	local checks = 0
	local function check(value: any, message: string) checks += 1; assert(value, message) end
	local now = 20000 * 86400
	local state = Quests.sanitize(nil)
	check(Login.ensure(state, now, 1), "first offer")
	check(not Login.ensure(state, now, 50) and state.login.pendingBrains == 2, "snapshotted band")
	for step = 1, 7 do
		if step > 1 then now += (if step == 2 then 5 else 1) * 86400; Login.ensure(state, now, 1) end
		local day = Time.dayKey(now)
		check(Login.claim(state, day, "Weekly", now) == nil, "removed recurring track")
		local amount, reason, grant = Login.claim(state, day, "Welcome", now)
		check(amount ~= nil and not reason and grant.kind == Config.FIRST_TIME_REWARDS[step].kind, "typed first-time reward")
		check(Login.claim(state, day, "Welcome", now) == nil, "duplicate claim")
		check(not Login.ensure(state, now, 1), "one claim per UTC date")
		state = Quests.sanitize(state)
	end
	check(not Login.ensure(state, now + 100 * 86400, 1), "track must end permanently")
	check(Login.clientState(state, now + 100 * 86400, 1).finished, "finished UI")
	local migrated = Login.sanitize({ welcomeClaims = 7, weeklyClaims = 4, lastClaimDay = 20000, pendingTrack = "Weekly" })
	check(migrated.welcomeClaims == 6 and migrated.weeklyClaims == nil, "legacy completion gets final ticket catch-up")
	check(Login.sanitize(migrated).welcomeClaims == 6, "migration does not repeat")
	check(Time.weekKey(4 * 86400) == 4 and Time.weekKey(10 * 86400) == 4 and Time.weekKey(11 * 86400) == 11, "Monday boundary")
	local weekly = Quests.sanitize(nil)
	Quests.ensure(weekly, now, 1, true)
	Quests.ensure(weekly, now, 1)
	Quests.record(weekly, "CoinsCollected", 1500, true)
	check(weekly.weeklyQuests.quests[1].progress == 1500 and weekly.dailyQuests.quests[1].progress == 0, "tracks isolated")
	local week = Time.weekKey(now)
	check(Quests.claim(weekly, week, "CollectCoins", now, true) == 3, "weekly payout")
	check(Quests.claim(weekly, week, "CollectCoins", now, true) == nil, "weekly duplicate")
	check(Quests.claim(weekly, week, "DefeatMonsters", Time.nextWeeklyResetAt(now), true) == nil, "weekly expiration")
	local snap = { retention = { brainrotTickets = 1 }, upgrades = { WalkSpeed = 20 }, unlocks = {}, equipped = {}, introducedBrainrots = {} }
	local upgrade = table.clone(Config.FIRST_TIME_REWARDS[2])
	check(Grant.prepare(snap, upgrade) == 10 and upgrade.kind == "Brains", "maxed upgrade fallback")
	local tracked = Quests.sanitize(nil)
	Login.ensureUpgradeHistory(tracked, {})
	Login.recordUpgrade(tracked, upgrade)
	check(Login.resetUpgrades(tracked, { WalkSpeed = 20 }).WalkSpeed == 0, "brains fallback must not retain an upgrade")
	Login.recordUpgrade(tracked, { kind = "Upgrade", upgradeId = "WalkSpeed", amount = 1 })
	check(Login.resetUpgrades(tracked, { WalkSpeed = 20 }).WalkSpeed == 1, "only actually granted levels survive reset")
	local legacy = Quests.sanitize({ login = { welcomeClaims = 7, firstTimeVersion = 1 } })
	local carried = Login.resetUpgrades(legacy, { WalkSpeed = 12, Magnet = 5 })
	check(carried.WalkSpeed == 2 and carried.Magnet == 2, "legacy first-time levels migrate with Magnet baseline")
	check(Login.resetUpgrades(Quests.sanitize(legacy), carried).WalkSpeed == 2, "carryover survives serialization and repeated resets")
	check(Grant.redeem(snap, "TungTungSahur") == nil and snap.retention.brainrotTickets == 1, "ticket cannot buy campaign unit")
	local amount, _, reward = Grant.redeem(snap, "GiraffaCeleste")
	check(amount == 0 and snap.retention.brainrotTickets == 0, "ticket consumed")
	Grant.apply(snap, reward)
	check(table.find(snap.unlocks, "GiraffaCeleste"), "ticket unlock")
	check(Grant.redeem(snap, "GiraffaCeleste") == nil, "duplicate ownership rejected")
	check(Grant.redeem(snap, "BlueberrinniOctopusini") == nil, "no second free purchase")
	return checks
end
