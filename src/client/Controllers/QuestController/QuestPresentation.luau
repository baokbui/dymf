--!strict
-- Display rows shared by the full quest view and compact tracker.
local QuestPresentation = {}
local titles = { CollectCoins = "Collect coins", DefeatMonsters = "Defeat monsters", ClearDay = "Clear campaign days" }
function QuestPresentation.rows(state: any, weekly: boolean): { any }
	local track = if weekly then state.weekly else state
	if not state.ready or not track then return {} end
	local rows, completed = {}, 0
	for _, quest in track.quests do
		if quest.progress >= quest.target then completed += 1 end
		table.insert(rows, { title = titles[quest.id] or quest.id, quest = quest, dayKey = track.dayKey })
	end
	table.insert(rows, { title = "Complete all three!", dayKey = track.dayKey,
		quest = { id = if weekly then "WeeklyComplete" else "DailyComplete", progress = completed,
			target = #track.quests, brains = track.bonusBrains, claimed = track.bonusClaimed } })
	return rows
end
return QuestPresentation
