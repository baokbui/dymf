--!strict
-- Seven first-time claims, once per distinct UTC date. No recurring track.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.RetentionConfig)
local Time = require(Shared.Utilities.RetentionTime)
local Types = require(Shared.Types.Retention)
local LoginRewards = {}
local function integer(value: any): number?
	if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then return nil end
	return math.floor(value)
end
function LoginRewards.sanitize(raw: any): Types.LoginTrack
	local source = if type(raw) == "table" then raw else {}
	local claims = math.min(7, integer(source.welcomeClaims) or 0)
	-- Legacy seven-brain payouts did not include the new final ticket.
	if not source.firstTimeVersion and claims == 7 then claims = 6 end
	local state: Types.LoginTrack = { welcomeClaims = claims, firstTimeVersion = 1,
		lastClaimDay = integer(source.lastClaimDay) }
	local day, step = integer(source.eligibleDay), integer(source.pendingStep)
	if source.pendingTrack == "Welcome" and day and step and step >= 1 and step <= 7 then
		state.eligibleDay, state.pendingStep, state.pendingTrack = day, step, "Welcome"
		state.pendingBrains = integer(source.pendingBrains) or 0
	end
	return state
end
function LoginRewards.ensure(state: Types.RetentionSave, now: number, highestDay: number): boolean
	local login = state.login or LoginRewards.sanitize(nil)
	state.login = login
	if login.welcomeClaims >= 7 then return false end
	local today = Time.dayKey(now)
	if (login.eligibleDay and login.eligibleDay >= today) or not Time.canClaimDay(login.lastClaimDay, now) then return false end
	local step = login.welcomeClaims + 1
	local reward = Config.FIRST_TIME_REWARDS[step]
	login.eligibleDay, login.pendingStep, login.pendingTrack = today, step, "Welcome"
	login.pendingBrains = if reward.kind == "Brains" then Config.brainsFor(reward.amount, highestDay) else 0
	return true
end
function LoginRewards.claim(state: Types.RetentionSave, day: number, id: string, now: number): (number?, string?, any?)
	local login = state.login
	if not login or day ~= Time.dayKey(now) or day ~= login.eligibleDay then return nil, "Expired" end
	if login.welcomeClaims >= 7 or not Time.canClaimDay(login.lastClaimDay, now) then return nil, "AlreadyClaimed" end
	if id ~= "Welcome" or login.pendingTrack ~= "Welcome" then return nil, "InvalidRequest" end
	if login.pendingStep ~= login.welcomeClaims + 1 then return nil, "NotReady" end
	local reward = Config.FIRST_TIME_REWARDS[login.pendingStep]
	login.welcomeClaims += 1
	login.lastClaimDay = day
	return if reward.kind == "Brains" then login.pendingBrains or 0 else 0, nil, table.clone(reward)
end
function LoginRewards.markCommitted(state: Types.RetentionSave, committed: Types.RetentionSave)
	if committed.login then state.login = LoginRewards.sanitize(committed.login) end
end
function LoginRewards.clientState(state: Types.RetentionSave, now: number, highestDay: number): { [string]: any }?
	local login = state.login
	if not login then return nil end
	local finished = login.welcomeClaims >= 7
	local claimed = login.lastClaimDay ~= nil and login.lastClaimDay >= Time.dayKey(now)
	local step = if finished then 7 elseif claimed then math.max(1, login.welcomeClaims) else login.welcomeClaims + 1
	local rewards = {}
	for index, entry in Config.FIRST_TIME_REWARDS do
		local reward = table.clone(entry)
		if entry.kind == "Brains" then
			reward.amount = if index == login.pendingStep then login.pendingBrains else Config.brainsFor(entry.amount, highestDay)
		end
		rewards[index] = reward
	end
	return { track = "Welcome", step = step, dayKey = login.eligibleDay or Time.dayKey(now),
		brains = login.pendingBrains or 0, claimed = claimed or finished, finished = finished,
		ready = not finished and not claimed and login.eligibleDay == Time.dayKey(now), rewards = rewards,
		completed = login.welcomeClaims, nextStep = if finished then nil else math.min(7, login.welcomeClaims + 1) }
end
return LoginRewards
