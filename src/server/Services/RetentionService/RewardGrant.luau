--!strict
-- Pure mutation of a SaveService-owned transaction snapshot, never a live balance.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config.ProgressConfig)
local Brainrots = require(game:GetService("ReplicatedStorage").Shared.Brainrots)
local RewardGrant = {}
local function append(list: { string }, id: string)
	if not table.find(list, id) then table.insert(list, id) end
end
function RewardGrant.prepare(snapshot: any, grant: any): number
	if not grant then return 0 end
	if grant.kind == "Upgrade" then
		for _, def in Config.UPGRADE_CATALOG do
			if def.id ~= grant.upgradeId then continue end
			local current = Config.upgradeLevel(def, snapshot.upgrades[def.id])
			if current >= def.maxLevel then
				grant.kind, grant.amount = "Brains", grant.fallbackBrains
				return grant.amount
			end
			grant.level = current + 1
		end
	end
	return 0
end
function RewardGrant.apply(snapshot: any, grant: any)
	if not grant then return end
	if grant.kind == "Upgrade" then
		snapshot.upgrades[grant.upgradeId] = math.max(snapshot.upgrades[grant.upgradeId] or 0, grant.level)
	elseif grant.kind == "Ticket" then
		snapshot.retention.brainrotTickets = (snapshot.retention.brainrotTickets or 0) + grant.amount
	elseif grant.kind == "Brainrot" then
		append(snapshot.unlocks, grant.brainrotId)
		if #snapshot.equipped < Config.MAX_EQUIPPED then append(snapshot.equipped, grant.brainrotId) end
		append(snapshot.introducedBrainrots, grant.brainrotId)
	end
end
function RewardGrant.redeem(snapshot: any, id: string): (number?, string?, any?)
	local sold = false
	for _, entry in Config.STORE_CATALOG do if entry.brainrotId == id then sold = true end end
	if not sold or not Brainrots.isPlayable(id) then return nil, "InvalidRequest" end
	if table.find(snapshot.unlocks, id) then return nil, "AlreadyClaimed" end
	if (snapshot.retention.brainrotTickets or 0) < 1 then return nil, "NotReady" end
	snapshot.retention.brainrotTickets -= 1
	return 0, nil, { kind = "Brainrot", brainrotId = id }
end
return RewardGrant
