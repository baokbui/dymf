--!strict
-- Inject source strings and pure modules; remotes and scheduling are mocked.
return function(sources: any, dependencies: any): string
	local realRequire = require
	local config, time = dependencies.RetentionConfig, dependencies.RetentionTime
	local rules, login = dependencies.DailyQuests, dependencies.LoginRewards
	local achievements = dependencies.Achievements
	local now=20000*86400
	local active=false
	local handler
	local handlers = {}
	local outputs,analytics,deferred={}, {}, {}
	local claimed=0
	local ret
	local player={UserId=222,Name="QuestEventTest",Parent=true}
	local remote={getEvent=function(name)
	 return {OnServerEvent={Connect=function(_,fn) handlers[name]=fn end},
	 FireClient=function(_,_,data) table.insert(outputs,{name=name,data=data}) end}
	end}
	local function lastResult()
	 for i=#outputs,1,-1 do if outputs[i].name=="RetentionClaimResult" then return outputs[i].data end end
	 error("No claim result")
	end
	local saves=0
	local save={
	 saveNow=function()saves+=1 end,
	 claimRetentionReward=function(_,kind,day,id)
	  local snapshot=ret.getSaveSlice(player)
	  local rule=if kind=="Login" then login elseif kind=="Achievement" then achievements else rules
	  local amount,reason=rule.claim(snapshot,day,id,now,kind=="WeeklyQuest")
	  if amount then claimed+=amount;ret.markCommitted(player,day,id,kind,snapshot) end
	  return amount~=nil,reason,amount
	 end
	}
	local modules={
	 RetentionConfig=config,RetentionTime=time,DailyQuests=rules,LoginRewards=login,Achievements=achievements,NextGoal=dependencies.NextGoal,Remotes=remote,
	 Analytics={log=function(_,action)table.insert(analytics,action) end,goal=function(_,action,kind)table.insert(analytics,action..":"..kind)end},
	 ProgressService={getClientState=function()return {unlocks={"BallerinaCappucina","TungTungSahur","ChimpanziniBananini"},evolutions={}}end},
	 LevelService={getSaveProgress=function()return 30,30,5 end,isLevelActive=function()return active end},
	 SaveService=save
	}
	local f=assert(loadstring(sources.Retention))
	setfenv(f,setmetatable({
	 script=game.ServerScriptService.Server.Services.RetentionService,
	 require=function(m)return modules[m.Name] or realRequire(m) end,
	 os={time=function()return now end,clock=function()return now end},
	 task={defer=function(fn)table.insert(deferred,fn) end,delay=function()return coroutine.create(function()end) end,cancel=function()end}
	},{__index=getfenv()}))
	ret=f();ret.init();handler=handlers.ClaimRetentionReward;ret.hydrate(player,nil)
	ret.recordEvent(player,"CoinsCollected",150,"Campaign")
	assert(ret.getClientState(player).quests[1].progress==0,"prep pickup")
	active=true
	ret.recordEvent(player,"CoinsCollected",150,"Challenge")
	assert(ret.getClientState(player).quests[1].progress==0,"challenge pickup")
	ret.recordEvent(player,"CoinsCollected",150,"Campaign")
	ret.recordEvent(player,"MonsterDefeated",15,"Hidden")
	ret.recordEvent(player,"CampaignDayCleared",1,"Hidden")
	assert(ret.getClientState(player).quests[3].progress==0,"hidden clear credited as campaign")
	ret.recordEvent(player,"CampaignDayCleared",1,"Campaign")
	active=false -- failure/preparation does not reset real progress
	assert(ret.getSaveSlice(player).dailyQuests.quests[2].progress==15,"failed run reset progress")
	handler(player,{kind="Progress",dayKey=20000,id="CollectCoins",amount=999})
	assert(claimed==0 and lastResult().reason=="InvalidRequest","client progress accepted")
	now+=1
	handler(player,{kind="Quest",dayKey=20000,id="CollectCoins"})
	assert(claimed==3 and lastResult().success,"claim")
	handler(player,{kind="Quest",dayKey=20000,id="CollectCoins"})
	assert(lastResult().reason=="RateLimited","throttle reply")
	now+=1;handler(player,{kind="Quest",dayKey=20000,id="CollectCoins"})
	assert(claimed==3 and lastResult().reason=="AlreadyClaimed","repeat paid")

	now+=1
	local loginView=ret.getClientState(player).login
	assert(loginView.track=="Welcome" and loginView.ready and loginView.brains==6,"initial login offer")
	handler(player,{kind="Login",dayKey=20000,id="Welcome"})
	assert(claimed==9 and lastResult().success,"login remote")
	now+=1
	handler(player,{kind="Login",dayKey=20000,id="Welcome"})
	assert(claimed==9 and lastResult().reason=="AlreadyClaimed","duplicate login remote")
	local second={UserId=223,Name="Other",Parent=true}
	ret.hydrate(second,nil)
	assert(ret.getClientState(second).login.ready,"claim leaked across players")
	ret.cleanup(second)
	active=true
	ret.beginRun(player,"Campaign")
	ret.recordEvent(player,"HouseBreached",1,"Campaign")
	ret.recordEvent(player,"CampaignDayCleared",1,"Campaign")
	assert(ret.getSaveSlice(player).achievements.FirstPerfectDefense.progress==0,"breach ignored")
	ret.beginRun(player,"Hidden")
	ret.recordEvent(player,"CampaignDayCleared",1,"Campaign")
	assert(ret.getSaveSlice(player).achievements.FirstPerfectDefense.progress==0,"Hidden run granted perfect campaign")
	ret.beginRun(player,"Campaign")
	ret.endRun(player) -- defeat/cancel clears the attempt marker
	ret.recordEvent(player,"CampaignDayCleared",1,"Campaign")
	assert(ret.getSaveSlice(player).achievements.FirstPerfectDefense.progress==0,"failed run granted perfect")
	ret.beginRun(player,"Campaign")
	ret.recordEvent(player,"CampaignDayCleared",1,"Campaign")
	assert(ret.getSaveSlice(player).achievements.FirstPerfectDefense.progress==1,"clean attempt not recognized")
	ret.recordEvent(player,"MonsterDefeated",1,"Challenge",{isBoss=true})
	assert(ret.getSaveSlice(player).achievements.FirstBoss.progress==0,"challenge boss counted")
	ret.recordEvent(player,"MonsterDefeated",1,"Campaign",{isBoss=true})
	assert(ret.getSaveSlice(player).achievements.FirstBoss.progress==1,"real boss not counted")
	now+=1
	handler(player,{kind="Achievement",dayKey=20000,id="FirstBoss",amount=999})
	assert(claimed==14 and lastResult().success,"achievement claim or client amount accepted")
	now+=1
	handler(player,{kind="Achievement",dayKey=20000,id="FirstBoss"})
	assert(claimed==14 and lastResult().reason=="AlreadyClaimed","duplicate permanent reward")
	ret.profileChanged(player,{unlocks={"BallerinaCappucina","TungTungSahur","ChimpanziniBananini","CappuccinoAssassino","TralaleroTralala"},evolutions={TungTungSahur={"Epic"}},brains=0,brainrotXp={}})
	assert(ret.getSaveSlice(player).achievements.FirstEpic.progress==1 and ret.getSaveSlice(player).achievements.OwnFiveBrainrots.progress==5,"profile catch-up")
	local goal=ret.getClientState(player).nextGoal
	local analyticsBefore=#analytics
	handlers.ViewRetentionGoal(player,goal.id)
	assert(#analytics==analyticsBefore+1,"goal engagement not logged")
	handlers.ViewRetentionGoal(player,goal.id)
	assert(#analytics==analyticsBefore+1,"goal engagement spam")
	now+=3
	handlers.ViewRetentionGoal(player,"UnknownGoal")
	assert(#analytics==analyticsBefore+1,"unverified goal engagement accepted")
	local before=ret.getSaveSlice(player)
	ret.hydrate(player,before)
	assert(ret.getClientState(player).quests[1].claimed and ret.getClientState(player).login.claimed and ret.getSaveSlice(player).achievements.FirstBoss.claimed,"reconnect claim")
	now+=86400
	assert(ret.getClientState(player).quests[1].progress==0 and ret.getClientState(player).login.step==2,"UTC rollover")
	active=true
	ret.recordEvent(player,"CoinsCollected",1500,"Campaign")
	now+=1
	handler(player,{kind="WeeklyQuest",dayKey=time.weekKey(now),id="CollectCoins"})
	assert(lastResult().success and ret.getSaveSlice(player).weeklyQuests.quests[1].claimed,"weekly remote claim")
	now+=1
	handler(player,{kind="Ticket",dayKey=0,id="GiraffaCeleste"})
	assert(lastResult().reason=="InvalidRequest","retention remote bypassed store ticket path")
	for _,fn in deferred do fn() end
	assert(saves>0,"assignment/completion not scheduled for save")
	ret.cleanup(player)
	assert(not ret.getClientState(player).ready,"cleanup")
	return "PASS: RetentionService integration: quest events, login remotes/duplicates, UTC rollover, reconnect, two-player isolation, scheduled persistence, cleanup."
end

