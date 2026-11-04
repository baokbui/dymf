--!strict
-- Isolated regression fixture. Inject the real modules; the store backend is memory-only.
-- Not mapped into the live place by Rojo. Returns the number of checks performed.
return function(Rules: any, Store: any, saveConfig: any): number
	local checks = 0
	local function check(value: any, message: string)
		checks += 1
		assert(value, message)
	end
	local function copy(value: any): any
		if type(value) ~= "table" then return value end
		local result = {}
		for key, entry in value do result[key] = copy(entry) end
		return result
	end
	local today = 20000 * 86400
	local state = Rules.sanitize(nil)
	check(Rules.ensure(state, today, 1), "initial assignment")
	check(not Rules.ensure(state, today + 1, 50), "same-day reward snapshot")
	check(state.dailyQuests.quests[1].brains == 1, "original band retained")
	check(not Rules.record(state, "CoinsCollected", -1), "negative progress")
	Rules.record(state, "CoinsCollected", 149)
	check(Rules.claim(copy(state), 20000, "CollectCoins", today) == nil, "incomplete quest")
	Rules.record(state, "CoinsCollected", 5000)
	check(state.dailyQuests.quests[1].progress == 150, "progress bounded")
	check(Rules.claim(state, 20000, "CollectCoins", today) == 1, "reward")
	local reward, reason = Rules.claim(state, 20000, "CollectCoins", today)
	check(reward == nil and reason == "AlreadyClaimed", "duplicate payout")
	check(Rules.claim(state, 20000, "DailyComplete", today) == nil, "incomplete bonus")
	Rules.record(state, "MonsterDefeated", 15)
	Rules.record(state, "CampaignDayCleared", 1)
	check(Rules.claim(state, 20000, "DailyComplete", today) == 2, "bonus")
	check(Rules.claim(state, 20000, "DailyComplete", today) == nil, "duplicate bonus")
	local restored = Rules.sanitize(copy(state))
	check(restored.dailyQuests.quests[1].claimed, "claim survives serialization")
	check(Rules.claim(restored, 20000, "DefeatMonsters", today + 86400) == nil, "expired claim")
	check(Rules.ensure(restored, today + 86400, 30), "daily rollover")
	check(restored.dailyQuests.quests[1].brains == 3, "new day gets new band")
	check(not Rules.ensure(restored, today, 1), "clock rollback")
	check(Rules.sanitize({ dailyQuests = { dayKey = 0 / 0, quests = {} } }).dailyQuests == nil, "malformed save")
	local backend: any = { records = {}, failBefore = 0, failAfter = 0 }
	function backend:UpdateAsync(key: string, callback: any): any
		if self.failBefore > 0 then self.failBefore -= 1; error("before write") end
		local result = callback(copy(self.records[key]))
		if result ~= nil then
			-- Roblox may invoke a transform again; it must not apply side effects twice.
			self.records[key] = copy(callback(copy(self.records[key])))
		end
		if self.failAfter > 0 then self.failAfter -= 1; error("committed response lost") end
		return copy(result)
	end
	local now, sequence = today, 0
	local function guid(): string
		sequence += 1
		return tostring(sequence)
	end
	local function makeStore(): any
		return Store.new(backend, function() return now end, guid, function() end, saveConfig)
	end
	local first, second = makeStore(), makeStore()
	backend.records.Player_1 = { version = 7, brains = 100 }
	check(first:acquire(1).brains == 100, "v7 data preserved")
	check(second:acquire(1) == nil, "concurrent owner refused")
	backend.failAfter = 1
	check(first:write(1, { version = 8, brains = 103 }), "uncertain commit reconciled")
	check(backend.records.Player_1.brains == 103 and backend.records.Player_1._revision == 1, "single commit")
	local ok, failure = first:write(1, { brains = 999 }, function() return false end)
	check(not ok and failure == "Expired" and first:isWritable(1), "expired request safely cancels")
	check(backend.records.Player_1.brains == 103, "cancel preserves balance")
	now += saveConfig.LEASE_SECONDS + 1
	check(second:acquire(1).brains == 103, "expired lease takeover")
	check(not first:write(1, { brains = 1 }), "old writer rejected")
	first:release(1)
	check(backend.records.Player_1._session ~= nil, "old release cannot clear new owner")
	check(second:write(1, { version = 8, brains = 105 }), "new owner writes")
	second:release(1)
	check(backend.records.Player_1._session == nil, "lease released")
	local rejoin = makeStore()
	check(rejoin:acquire(1).brains == 105, "rejoin preserves committed balance")
	backend.failBefore = saveConfig.SAVE_RETRIES
	check(not rejoin:write(1, { brains = 999999 }), "write failure")
	check(not rejoin:isWritable(1), "uncertain writer blocked")
	check(backend.records.Player_1.brains == 105, "failed write never wipes progress")
	rejoin:release(1)
	return checks
end
