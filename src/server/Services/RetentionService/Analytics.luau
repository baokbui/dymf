--!strict
local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config.RetentionConfig)
local Analytics = {}
local allowed = { Assigned = true, Attempted = true, Retried = true, Failed = true, Completed = true, Claimed = true, Rejected = true }

function Analytics.log(player: Player, action: string, value: number?, reason: string?, kind: string?, id: string?)
	if RunService:IsStudio() or not allowed[action] then return end
	local suffix = ""
	if action == "Rejected" and table.find(Config.REJECTION_REASONS, reason) then
		suffix = "_" .. (reason :: string)
	end
	if kind == "Achievement" and action ~= "Rejected" then
		for _, definition in Config.ACHIEVEMENTS do
			if definition.id == id then suffix ..= "_" .. definition.id; break end
		end
	end
	task.defer(function()
		pcall(function()
			local prefix = if kind == "Spin" then "BvmDailySpin" elseif kind == "Challenge" then "BvmDailyChallenge" elseif kind == "Login" then "BvmLoginRewards" elseif kind == "Achievement" then "BvmAchievements" elseif kind == "WeeklyQuest" then "BvmWeeklyQuests" else "BvmDailyQuests"
			AnalyticsService:LogCustomEvent(player, prefix .. action .. suffix, value or 1)
		end)
	end)
end

function Analytics.goal(player: Player, action: string, kind: string)
	if RunService:IsStudio() or (action ~= "Shown" and action ~= "Viewed") then return end
	if kind ~= "Campaign" and kind ~= "Level" and kind ~= "Evolution" then return end
	task.defer(function()
		pcall(function() AnalyticsService:LogCustomEvent(player, "BvmNextGoal" .. action .. "_" .. kind, 1) end)
	end)
end

return Analytics
