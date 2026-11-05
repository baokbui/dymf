--!strict
-- The save writer calls this on its private transaction snapshot.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.RetentionConfig)
local Time = require(Shared.Utilities.RetentionTime)
local Types = require(Shared.Types)
local random = Random.new()

local DailySpin = {}

function DailySpin.sanitize(raw: any): Types.DailyReward?
	if type(raw) ~= "table" or raw.claimed ~= true or type(raw.rewardId) ~= "string" then return nil end
	local day, brains = raw.dayKey, raw.brains
	if type(day) ~= "number" or day < 0 or day % 1 ~= 0 then return nil end
	if type(brains) ~= "number" or brains < 0 or brains % 1 ~= 0 then return nil end
	return { dayKey = day, brains = brains, claimed = true, rewardId = raw.rewardId }
end

function DailySpin.clientState(state: Types.RetentionSave, now: number, highest: number): any
	local day = Time.dayKey(now)
	local outcome = state.spin
	local rewards = {}
	local total = 0
	for _, reward in Config.SPIN_REWARDS do total += reward.weight end
	for _, reward in Config.SPIN_REWARDS do
		table.insert(rewards, { id = reward.id, brains = Config.brainsFor(reward.brains, highest), odds = reward.weight / total })
	end
	return {
		dayKey = day,
		eligible = highest >= Config.SPIN_MINIMUM_DAY,
		minimumDay = Config.SPIN_MINIMUM_DAY,
		spent = outcome ~= nil and outcome.dayKey >= day,
		outcome = if outcome and outcome.dayKey == day then table.clone(outcome) else nil,
		rewards = rewards,
	}
end

function DailySpin.claim(state: Types.RetentionSave, day: number, now: number, highest: number): (number?, string?)
	if day ~= Time.dayKey(now) then return nil, "Expired" end
	if highest < Config.SPIN_MINIMUM_DAY then return nil, "NotReady" end
	if state.spin and state.spin.dayKey >= day then return nil, "AlreadyClaimed" end
	local total = 0
	for _, reward in Config.SPIN_REWARDS do total += reward.weight end
	local roll = random:NextInteger(1, total)
	for _, reward in Config.SPIN_REWARDS do
		roll -= reward.weight
		if roll <= 0 then
			local brains = Config.brainsFor(reward.brains, highest)
			state.spin = { dayKey = day, claimed = true, rewardId = reward.id, brains = brains }
			return brains, nil
		end
	end
	return nil, "InvalidRequest"
end

return DailySpin
