--!strict
local BattleClock = require(game:GetService("ReplicatedStorage").Shared.Utilities.BattleClock)
-- Quest/login reward authority. Clients send intent, never amounts or progress.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.RetentionConfig)
local Time = require(Shared.Utilities.RetentionTime)
local Types = require(Shared.Types.Retention)
local Remotes = require(Shared.Remotes)
local Rules = require(script.DailyQuests)
local LoginRewards = require(script.LoginRewards)
local Achievements = require(script.Achievements)
local NextGoal = require(script.NextGoal)
local Analytics = require(script.Analytics)
local DailySpin = require(script.DailySpin)
local RetentionService = { Name = "RetentionService" }
local states: { [number]: Types.RetentionSave } = {}
local pushes: { [number]: thread } = {}
local resets: { [number]: thread } = {}
local requests: { [number]: number } = {}
local profiles: { [number]: any } = {}
local runs: { [number]: { mode: string, breached: boolean } } = {}
local goalIds: { [number]: string } = {}
local goalViews: { [number]: number } = {}

local function highestDay(player: Player): number
	local _, highest = require(script.Parent.LevelService).getSaveProgress(player)
	return highest
end

local function saveSoon(player: Player)
	task.defer(function()
		if player.Parent then require(script.Parent.SaveService).saveNow(player, "retention") end
	end)
end

local function ensure(player: Player): boolean
	local state = states[player.UserId]
	if not state then return false end
	local assigned = Rules.ensure(state, os.time(), highestDay(player))
	local weeklyAssigned = Rules.ensure(state, os.time(), highestDay(player), true)
	local loginAssigned = LoginRewards.ensure(state, os.time(), highestDay(player))
	if assigned then
		Analytics.log(player, "Assigned")
	end
	if loginAssigned then Analytics.log(player, "Assigned", nil, nil, "Login") end
	if weeklyAssigned then Analytics.log(player, "Assigned", nil, nil, "WeeklyQuest") end
	if assigned or loginAssigned or weeklyAssigned then saveSoon(player) end
	return assigned or loginAssigned or weeklyAssigned
end

function RetentionService.getSaveSlice(player: Player): Types.RetentionSave?
	local state = states[player.UserId]
	return if state then Rules.sanitize(state) else nil
end

function RetentionService.getClientState(player: Player): { [string]: any }
	ensure(player)
	local state = states[player.UserId]
	if not state or not state.dailyQuests then return { ready = false } end
	Achievements.syncCampaign(state, highestDay(player))
	local daily = Rules.sanitize(state).dailyQuests
	assert(daily)
	local goal = NextGoal.select(profiles[player.UserId] or {}, highestDay(player), require(Shared.Levels).count())
	local goalKey = goal.kind .. ":" .. goal.id
	if goalIds[player.UserId] ~= goalKey then
		goalIds[player.UserId] = goalKey
		Analytics.goal(player, "Shown", goal.kind)
	end
	return { ready = true, dayKey = daily.dayKey, resetAt = Time.nextResetAt(os.time()),
		weekly = state.weeklyQuests, weeklyResetAt = Time.nextWeeklyResetAt(os.time()), brainrotTickets = state.brainrotTickets or 0,
		quests = daily.quests, bonusBrains = daily.bonusBrains, bonusClaimed = daily.bonusClaimed,
		login = LoginRewards.clientState(state, os.time(), highestDay(player)),
		achievements = Achievements.clientState(state), campaign = Achievements.clientState(state, true), nextGoal = goal,
		spin = DailySpin.clientState(state, os.time(), highestDay(player)) }
end

local function push(player: Player)
	if player.Parent then
		Remotes.getEvent("RetentionUpdated"):FireClient(player, RetentionService.getClientState(player))
	end
end

local function schedulePush(player: Player)
	if pushes[player.UserId] then return end
	pushes[player.UserId] = task.delay(Config.STATE_PUSH_INTERVAL, function()
		pushes[player.UserId] = nil
		push(player)
	end)
end

local function completed(player: Player, ids: { string })
	for _, id in ids do Analytics.log(player, "Completed", nil, nil, "Achievement", id) end
	if #ids > 0 then saveSoon(player) end
end

function RetentionService.profileChanged(player: Player, profile: any)
	local state = states[player.UserId]
	if not state then return end
	profiles[player.UserId] = profile
	completed(player, Achievements.catchUp(state, profile))
	schedulePush(player)
end

function RetentionService.beginRun(player: Player, mode: string)
	if not states[player.UserId] or (mode ~= "Campaign" and mode ~= "Hidden") then return end
	runs[player.UserId] = { mode = mode, breached = false }
end

function RetentionService.endRun(player: Player)
	runs[player.UserId] = nil
end

local function scheduleReset(player: Player)
	resets[player.UserId] = task.delay(Time.secondsUntilReset(os.time()), function()
		if not states[player.UserId] or not player.Parent then return end
		ensure(player)
		push(player)
		scheduleReset(player)
	end)
end

local function cancel(threads: { [number]: thread }, userId: number)
	local pending = threads[userId]
	if pending and coroutine.status(pending) ~= "dead" then task.cancel(pending) end
	threads[userId] = nil
end

function RetentionService.hydrate(player: Player, raw: any)
	cancel(resets, player.UserId)
	cancel(pushes, player.UserId)
	states[player.UserId] = Rules.sanitize(raw)
	runs[player.UserId] = nil
	profiles[player.UserId] = require(script.Parent.ProgressService).getClientState(player)
	completed(player, Achievements.catchUp(states[player.UserId], profiles[player.UserId]))
	ensure(player)
	scheduleReset(player)
	push(player)
end

-- Called only from successful server pickup/death/victory paths, once per action.
function RetentionService.recordEvent(player: Player, event: string, amount: number, mode: string, details: any?)
	if (mode ~= "Campaign" and mode ~= "Hidden") or not states[player.UserId] then return end
	if event == "CampaignDayCleared" and mode ~= "Campaign" then return end
	if amount ~= amount or amount <= 0 or amount == math.huge then return end
	if event ~= "CampaignDayCleared" and not require(script.Parent.LevelService).isLevelActive(player) then return end
	ensure(player)
	local run = runs[player.UserId]
	if event == "HouseBreached" and run then run.breached = true end
	completed(player, Achievements.record(states[player.UserId], event, details))
	if event == "CampaignDayCleared" then
		if run and run.mode == "Campaign" and not run.breached then
			completed(player, Achievements.record(states[player.UserId], "PerfectDefense"))
		end
		runs[player.UserId] = nil
	end
	local changed, questCompleted = Rules.record(states[player.UserId], event, math.floor(amount))
	local weeklyChanged, weeklyCompleted = Rules.record(states[player.UserId], event, math.floor(amount), true)
	changed = changed or weeklyChanged
	if weeklyCompleted then Analytics.log(player, "Completed", nil, nil, "WeeklyQuest"); saveSoon(player) end
	if questCompleted then Analytics.log(player, "Completed"); saveSoon(player) end
	if changed or event == "MonsterDefeated" or event == "CampaignDayCleared" then schedulePush(player) end
end

function RetentionService.markCommitted(player: Player, day: number, id: string, kind: string?, committed: Types.RetentionSave?)
	local state = states[player.UserId]
	if state then
		if kind == "Login" and committed then LoginRewards.markCommitted(state, committed)
		elseif kind == "Achievement" then Achievements.markCommitted(state, id)
		elseif kind == "Challenge" and committed then state.challengeClaimDay = committed.challengeClaimDay
		elseif kind == "Spin" and committed then state.spin = committed.spin
		elseif kind ~= "Ticket" then Rules.markCommitted(state, day, id, kind == "WeeklyQuest") end
		if committed then state.brainrotTickets = committed.brainrotTickets or 0 end
	end
	push(player)
end

function RetentionService.cleanup(player: Player)
	cancel(pushes, player.UserId)
	cancel(resets, player.UserId)
	states[player.UserId] = nil
	requests[player.UserId] = nil
	profiles[player.UserId], runs[player.UserId] = nil, nil
	goalIds[player.UserId], goalViews[player.UserId] = nil, nil
end

local function onClaim(player: Player, request: any)
	local isSpin = type(request) == "table" and request.kind == "Spin"
	local now = os.clock()
	if now < (requests[player.UserId] or 0) then
		Remotes.getEvent("RetentionClaimResult"):FireClient(player, { success = false, reason = "RateLimited", kind = if isSpin then "Spin" else nil })
		return
	end
	requests[player.UserId] = now + Config.CLAIM_REQUEST_INTERVAL
	local reason: string? = "InvalidRequest"
	local success, amount = false, nil :: number?
	local grant: any = nil
	if type(request) == "table" and (request.kind == "Quest" or request.kind == "WeeklyQuest" or request.kind == "Login" or request.kind == "Achievement" or (isSpin and request.id == "DailySpin")) and type(request.id) == "string"
		and #request.id <= 32 and type(request.dayKey) == "number" and request.dayKey == request.dayKey
		and request.dayKey >= 0 and request.dayKey < math.huge and request.dayKey % 1 == 0 then
		ensure(player)
		success, reason, amount, grant = require(script.Parent.SaveService).claimRetentionReward(player, request.kind, request.dayKey, request.id)
	end
	Analytics.log(player, if success then "Claimed" else "Rejected", amount, reason,
		if isSpin then "Spin" elseif type(request) == "table" and request.kind == "Login" then "Login"
		elseif type(request) == "table" and request.kind == "Achievement" then "Achievement"
		elseif type(request) == "table" and request.kind == "WeeklyQuest" then "WeeklyQuest" else "Quest",
		if type(request) == "table" and type(request.id) == "string" then request.id else nil)
	if player.Parent then
		Remotes.getEvent("RetentionClaimResult"):FireClient(player, {
			success = success, reason = reason, brainsGranted = amount, reward = grant,
			kind = if isSpin then "Spin" elseif type(request) == "table" and request.kind == "Login" then "Login"
				elseif type(request) == "table" and request.kind == "Achievement" then "Achievement"
				elseif type(request) == "table" and request.kind == "WeeklyQuest" then "WeeklyQuest" else "Quest",
		})
		push(player)
	end
end

function RetentionService.init()
	Remotes.getEvent("ClaimRetentionReward").OnServerEvent:Connect(function(player, ...) if not BattleClock.isPaused(player) then onClaim(player, ...) end end)
	Remotes.getEvent("ViewRetentionGoal").OnServerEvent:Connect(function(player: Player, id: any)
		if BattleClock.isPaused(player) then return end
		if type(id) ~= "string" or #id > 96 or not states[player.UserId] then return end
		local now = os.clock()
		if now < (goalViews[player.UserId] or 0) then return end
		goalViews[player.UserId] = now + Config.GOAL_VIEW_INTERVAL
		local goal = RetentionService.getClientState(player).nextGoal
		if goal and goal.id == id then Analytics.goal(player, "Viewed", goal.kind) end
	end)
end

return RetentionService
