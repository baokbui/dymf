--!strict
-- Full SaveService integration fixture. Pass source strings and injected pure modules.
-- The DataStoreService, players, gameplay services, and scheduling are mocked.
return function(sources: any, modules: any): string
	local realGame,realRequire,shared=game,require,game.ReplicatedStorage.Shared
	local function copy(v) if type(v)~="table" then return v end local out={} for k,x in v do out[k]=copy(x) end return out end
	local config,time,saveConfig=modules.RetentionConfig,modules.RetentionTime,modules.SaveConfig
	local rules,Store,login=modules.DailyQuests,modules.SessionStore,modules.LoginRewards
	local achievements=modules.Achievements
	local grant=modules.RewardGrant
	local now=20000*86400
	local player={UserId=101,Name="IsolatedQuestPlayer",Parent=true}
	function player:Kick(reason) self.kicked=reason;self.Parent=nil end
	local profile,retention
	local current,highest=30,30
	local function noop() end
	local backend={record={version=7,brains=100,currentLevel=30,highestLevel=30},writes=0}
	function backend:UpdateAsync(_,fn)
	 if self.hook then local h=self.hook;self.hook=nil;h() end
	 local result=fn(copy(self.record))
	 if result then self.record=copy(result);self.writes+=1 end
	 return copy(result)
	end
	local level={
	 getSaveProgress=function() return current,highest,5 end,
	 applySaveProgress=function(_,c,h) current=c;highest=h end,
	 applyDevDay=function() return nil end,queueJoinIntros=noop,
	 isHiddenDayPending=function() return false end,applyWeatherRulesForPlayer=noop
	}
	local progress={
	 applySaveSlice=function(_,s) profile=copy(s) end,
	 getSaveSlice=function() return copy(profile) end,
	 addBrains=function(_,amount)
	  if profile then profile.brains+=amount;profile.statistics.brainsEarned=(profile.statistics.brainsEarned or 0)+amount end
	 end,
	 applyDurableReward=function(_,reward) if reward.kind~="Ticket" then grant.apply(profile,reward) end end,
	 reset=noop,applyDevRoster=noop,applyDevEvolutions=noop,applyDevBrains=noop
	}
	local ret={
	 hydrate=function(_,s) retention=rules.sanitize(s);rules.ensure(retention,now,highest);login.ensure(retention,now,highest);rules.ensure(retention,now,highest,true) end,
	 getSaveSlice=function() return rules.sanitize(retention) end,
	 markCommitted=function(_,day,id,kind,committed) if kind=="Login" then login.markCommitted(retention,committed) elseif kind=="Achievement" then achievements.markCommitted(retention,id) elseif kind~="Ticket" then rules.markCommitted(retention,day,id,kind=="WeeklyQuest") end; if committed then retention.brainrotTickets=committed.brainrotTickets end end,
	 cleanup=function() retention=nil end
	}
	local handlers={}
	local nearStore=true
	local fakePlayers={
	 GetPlayers=function() return {} end,
	 GetPlayerByUserId=function()return player end,
	 PlayerAdded={Connect=function(_,fn) handlers.add=fn end},
	 PlayerRemoving={Connect=function(_,fn) handlers.remove=fn end}
	}
	local fakeGame={}
	function fakeGame:GetService(name)
	 if name=="DataStoreService" then return {GetDataStore=function()return backend end} end
	 if name=="Players" then return fakePlayers end
	 return realGame:GetService(name)
	end
	function fakeGame:BindToClose() end
	local fakeTask={wait=noop,defer=noop,spawn=noop}
	local modules={
	 RewardGrant=grant,StoreService={canPlayerUseShop=function()return nearStore end},SessionStore=Store,DailyQuests=rules,LoginRewards=login,Achievements=achievements,RetentionService=ret,ProgressService=progress,
	 LevelService=level,PlotService={getPlotModel=function()return nil end},
	 BrainrotService={},CoinService={applyDayPurse=noop,applyDevPurse=noop},
	 SaveConfig=saveConfig,RetentionTime=time,
	 Logger={new=function()return {warn=noop,info=noop} end},
	 Remotes={getEvent=function()return {OnServerEvent={Connect=noop}} end}
	}
	local constants=table.clone(realRequire(shared.Constants));constants.SAVE_VERSION=11
	modules.Constants=constants
	local f=assert(loadstring(sources.Save))
	setfenv(f,setmetatable({
	 game=fakeGame,script=game.ServerScriptService.Server.Services.SaveService,task=fakeTask,
	 os={time=function()return now end,clock=os.clock},
	 require=function(m)return modules[m.Name] or realRequire(m) end
	},{__index=getfenv()}))
	local Save=f()
	Save.init();Save.start();handlers.add(player)
	assert(profile.brains==100 and retention.dailyQuests.bandId=="Late")
	rules.record(retention,"CoinsCollected",150)
	rules.record(retention,"MonsterDefeated",15)
	rules.record(retention,"CampaignDayCleared",1)
	local nestedBusy
	backend.hook=function()
	 profile.brains-=10 -- a purchase while the claim write is yielding
	 Save.saveNow(player,"queued_purchase")
	 nestedBusy=select(2,Save.claimDailyQuest(player,20000,"CollectCoins"))
	end
	local ok,reason,reward=Save.claimDailyQuest(player,20000,"CollectCoins")
	assert(ok and reward==3 and nestedBusy=="Busy",tostring(reason))
	assert(profile.brains==93 and backend.record.brains==93,"queued balance overwritten")
	assert(backend.record.retention.dailyQuests.quests[1].claimed,"queued claim flag lost")
	assert(backend.record.version==11,"migration")
	assert(not Save.claimDailyQuest(player,20000,"CollectCoins"),"duplicate payout")

	local beforeLogin=profile.brains
	backend.hook=function()
	 profile.brains-=5
	 Save.saveNow(player,"purchase_during_login")
	end
	local loginOk,loginReason,loginReward=Save.claimRetentionReward(player,"Login",20000,"Welcome")
	assert(loginOk and loginReward==6,tostring(loginReason))
	assert(profile.brains==beforeLogin+1 and backend.record.brains==profile.brains,"login purchase merge")
	assert(backend.record.retention.login.welcomeClaims==1 and backend.record.retention.login.lastClaimDay==20000,"login count not atomic")
	assert(backend.record.retention.dailyQuests.quests[1].claimed,"login erased quest claim")
	assert(not Save.claimRetentionReward(player,"Login",20000,"Welcome"),"duplicate login")
	assert(not Save.claimRetentionReward(player,"Invalid",20000,"Welcome"),"invalid kind")
	achievements.record(retention,"MonsterDefeated",{isBoss=true})
	local beforeAchievement=profile.brains
	backend.hook=function()
	 profile.brains-=4
	 achievements.record(retention,"PerfectDefense")
	 Save.saveNow(player,"queued_achievement_purchase")
	 now+=86400 -- permanent reward must not expire while the write yields
	end
	assert(Save.claimRetentionReward(player,"Achievement",20000,"FirstBoss"))
	assert(profile.brains==beforeAchievement+1 and backend.record.brains==profile.brains,"achievement balance merge")
	assert(backend.record.retention.achievements.FirstBoss.claimed,"achievement flag not saved")
	assert(backend.record.retention.achievements.FirstPerfectDefense.progress==1,"concurrent milestone lost")
	assert(not Save.claimRetentionReward(player,"Achievement",20001,"FirstBoss"),"permanent duplicate")
	now-=86400
	local before=backend.record.brains
	backend.hook=function()
	 Save.saveNow(player,"leave_snapshot")
	 profile=nil;player.Parent=nil -- other services cleaned up during PlayerRemoving
	end
	assert(Save.claimDailyQuest(player,20000,"DefeatMonsters"))
	assert(backend.record.brains==before+3,"leave snapshot lost reward")
	assert(backend.record.retention.dailyQuests.quests[2].claimed,"leave flag lost")
	handlers.remove(player)
	assert(backend.record._session==nil,"leave did not release lease")
	assert(retention==nil,"retention cleanup")

	player.Parent=true
	level.queueJoinIntros=function()Save.saveNow(player,"intro_save")end
	handlers.add(player)
	assert(retention.login.welcomeClaims==1 and retention.login.lastClaimDay==20000,"rejoin/intro save erased login")
	assert(not Save.claimRetentionReward(player,"Login",20000,"Welcome"),"reconnect repaid")
	now+=86400
	rules.ensure(retention,now,highest);login.ensure(retention,now,highest)
	local beforeLeave=backend.record.brains
	backend.hook=function()
	 Save.saveNow(player,"leave_login_snapshot")
	 profile=nil;player.Parent=nil
	end
	assert(Save.claimRetentionReward(player,"Login",20001,"Welcome"),"login disconnect failed")
	assert(backend.record.brains==beforeLeave and backend.record.upgrades.WalkSpeed==1 and backend.record.retention.login.welcomeClaims==2,"login leave lost reward or count")
	handlers.remove(player)
	player.Parent=true
	handlers.add(player)
	achievements.catchUp(retention,{unlocks={"BallerinaCappucina","TungTungSahur","ChimpanziniBananini","CappuccinoAssassino","TralaleroTralala"},evolutions={}})
	local achievementLeaveBalance=backend.record.brains
	backend.hook=function()
	 Save.saveNow(player,"leave_achievement_snapshot")
	 profile=nil;player.Parent=nil
	end
	assert(Save.claimRetentionReward(player,"Achievement",20001,"OwnFiveBrainrots"),"achievement disconnect failed")
	assert(backend.record.brains==achievementLeaveBalance+5 and backend.record.retention.achievements.OwnFiveBrainrots.claimed,"achievement disconnect lost flag or reward")
	handlers.remove(player)
	player.Parent=true;handlers.add(player)
	for step=3,7 do
	 now+=86400;login.ensure(retention,now,highest)
	 assert(Save.claimRetentionReward(player,"Login",math.floor(now/86400),"Welcome"),"first-time progression")
	end
	assert(backend.record.retention.brainrotTickets==1 and retention.brainrotTickets==1,"ticket not durable")
	nearStore=false
	assert(not Save.claimRetentionReward(player,"Ticket",0,"GiraffaCeleste") and retention.brainrotTickets==1,"ticket bypassed store range")
	nearStore=true
	local balanceBeforeTicket=profile.brains
	backend.hook=function() Save.saveNow(player,"queued_ticket_purchase") end
	assert(Save.claimRetentionReward(player,"Ticket",0,"GiraffaCeleste"),"ticket purchase failed")
	assert(profile.brains==balanceBeforeTicket and backend.record.brains==balanceBeforeTicket,"ticket charged brains")
	assert(table.find(profile.unlocks,"GiraffaCeleste") and table.find(backend.record.unlocks,"GiraffaCeleste"),"ticket ownership not durable")
	assert(backend.record.retention.brainrotTickets==0 and retention.brainrotTickets==0,"ticket consumed twice or not consumed")
	assert(not Save.claimRetentionReward(player,"Ticket",0,"BlueberrinniOctopusini"),"ticket reused")
	rules.ensure(retention,now,highest,true)
	rules.record(retention,"CoinsCollected",1500,true)
	assert(Save.claimRetentionReward(player,"WeeklyQuest",time.weekKey(now),"CollectCoins"),"weekly durable claim")
	assert(backend.record.retention.weeklyQuests.quests[1].claimed,"weekly claim flag missing")
	handlers.remove(player)
	backend.record.version=12
	player.Parent=true
	handlers.add(player)
	assert(player.kicked and backend.record.version==12,"newer schema overwritten")
	return "PASS: full SaveService in-memory tests: quest regression, v7/v8/v9/v10→v11, durable first-time/weekly/ticket/achievement flags and balances, concurrent purchase/save merge, duplicate claims, reconnect and intro save, disconnect during login claim, lease release, newer schema refusal. No real player data accessed."

end

