--!strict
-- Full SaveService integration fixture. Pass source strings and injected pure modules.
-- The DataStoreService, players, gameplay services, and scheduling are mocked.
return function(sources: any, modules: any): string
	local realGame,realRequire,shared=game,require,game.ReplicatedStorage.Shared
	local function copy(v) if type(v)~="table" then return v end local out={} for k,x in v do out[k]=copy(x) end return out end
	local config,time,saveConfig=modules.RetentionConfig,modules.RetentionTime,modules.SaveConfig
	local rules,Store,login=modules.DailyQuests,modules.SessionStore,modules.LoginRewards
	local achievements,spin=modules.Achievements,modules.DailySpin
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
	 reset=function(_,upgrades) profile.brains=0; profile.statistics={}; profile.upgrades=copy(upgrades or {}); profile.farmMonsters={}; profile.farmReceipts={}; profile.monsterShards={}; profile.dayStars={}; profile.collectedMonsters={} end,applyDevRoster=noop,applyDevEvolutions=noop,applyDevBrains=noop
	}
	local ret={
	 hydrate=function(_,s) retention=rules.sanitize(s);rules.ensure(retention,now,highest);login.ensure(retention,now,highest);rules.ensure(retention,now,highest,true) end,
	 getSaveSlice=function() return rules.sanitize(retention) end,
	 markCommitted=function(_,day,id,kind,committed) if kind=="Login" then login.markCommitted(retention,committed) elseif kind=="Achievement" then achievements.markCommitted(retention,id) elseif kind=="Challenge" then retention.challengeClaimDay=committed.challengeClaimDay elseif kind=="Spin" then retention.spin=committed.spin elseif kind~="Ticket" then rules.markCommitted(retention,day,id,kind=="WeeklyQuest") end; if committed then retention.brainrotTickets=committed.brainrotTickets end end,
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
	 FarmProgression=modules.FarmProgression,MonsterFusion=modules.MonsterFusion,RewardGrant=grant,StoreService={canPlayerUseShop=function()return nearStore end},SessionStore=Store,DailyQuests=rules,DailySpin=spin,LoginRewards=login,Achievements=achievements,RetentionService=ret,ProgressService=progress,
	 LevelService=level,PlotService={getPlotModel=function()return nil end},
	 BrainrotService={clearPlantCooldowns=noop},CoinService={applyDayPurse=noop,applyDevPurse=noop,resetBalance=noop},
	 SaveConfig=saveConfig,RetentionTime=time,RetentionConfig=config,
	 Logger={new=function()return {warn=noop,info=noop} end},
	 Remotes={getEvent=function()return {OnServerEvent={Connect=noop}} end}
	}
	local constants=table.clone(realRequire(shared.Constants));constants.SAVE_VERSION=16
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
	assert(backend.record.version==16,"migration")
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
	local challengeDay=time.dayKey(now)
	local beforeChallenge=profile.brains
	assert(select(2,Save.claimRetentionReward(player,"Challenge",challengeDay-1,"ForestRush"))=="Expired")
	backend.hook=function() Save.saveNow(player,"queued_challenge_clear") end
	local won,_,payout=Save.claimRetentionReward(player,"Challenge",challengeDay,"ForestRush")
	assert(won and payout==12 and backend.record.brains==beforeChallenge+12,"challenge payout")
	assert(retention.challengeClaimDay==challengeDay and backend.record.retention.challengeClaimDay==challengeDay,"challenge receipt")
	assert(select(2,Save.claimRetentionReward(player,"Challenge",challengeDay,"ForestRush"))=="AlreadyClaimed")
	handlers.remove(player)
	player.Parent=true;handlers.add(player)
	assert(select(2,Save.claimRetentionReward(player,"Challenge",challengeDay,"ForestRush"))=="AlreadyClaimed","challenge replay after reconnect")
	now+=86400
	assert(Save.claimRetentionReward(player,"Challenge",time.dayKey(now),"ForestRush"),"challenge next UTC day")

	local beforeMilestone=profile.brains
	assert(select(2,Save.claimRetentionReward(player,"Achievement",0,"ReachDay35"))=="NotReady")
	local reached,_,milestoneBrains=Save.claimRetentionReward(player,"Achievement",0,"ReachDay30")
	assert(reached and milestoneBrains==10 and backend.record.brains==beforeMilestone+10,"campaign milestone payout")
	assert(backend.record.retention.achievements.ReachDay30.claimed,"campaign claim was not durable")
	assert(select(2,Save.claimRetentionReward(player,"Achievement",0,"ReachDay30"))=="AlreadyClaimed")

	-- Species-specific combining is a durable spend+unlock transaction.
	profile.monsterShards = { Zombie = 15 }
	profile.dayStars = { Level1 = 3 }
	profile.collectedMonsters = {}
	profile.farmMonsters, profile.farmReceipts = {}, {}
	local combined = Save.claimRetentionReward(player, "Monster", 0, "Zombie", nil, "combine-zombie-1")
	assert(combined and backend.record.monsterShards.Zombie == 0, "combine did not spend shards")
	assert(table.find(backend.record.collectedMonsters, "Zombie"), "combine unlock was not durable")
	assert(profile.monsterShards.Zombie == 0 and table.find(profile.collectedMonsters, "Zombie"), "combine live state mismatch")
	assert(backend.record.dayStars.Level1 == 3, "star record lost in transaction")
	assert(Save.claimRetentionReward(player, "Monster", 0, "Zombie", nil, "combine-zombie-1"), "combine retry failed")
	assert(#profile.farmMonsters == 1 and #backend.record.farmMonsters == 1 and profile.monsterShards.Zombie == 0, "combine retry duplicated the result")
	profile.monsterShards.Goblin = 19
	assert(select(2, Save.claimRetentionReward(player, "Monster", 0, "Goblin")) == "NotReady", "incomplete shard collection combined")
	profile.monsterShards.Goblin = 20
	local nestedCombine
	backend.hook = function()
		profile.monsterShards.Goblin += 5
		Save.saveNow(player, "shards_during_combine")
		nestedCombine = select(2, Save.claimRetentionReward(player, "Monster", 0, "Goblin"))
	end
	assert(Save.claimRetentionReward(player, "Monster", 0, "Goblin"))
	assert(nestedCombine == "Busy", "concurrent combine was accepted")
	assert(profile.monsterShards.Goblin == 5 and backend.record.monsterShards.Goblin == 5, "concurrent shard gain lost or double spent")
	assert(table.find(backend.record.collectedMonsters, "Goblin"), "queued snapshot lost monster unlock")
	-- Repeated species are independent instances. Fusion spends exact selected ids.
	local beforeCount = #profile.farmMonsters
	profile.monsterShards.Zombie = 45
	local ids = {}
	for index = 1, 3 do
		local made, _, _, result = Save.claimRetentionReward(player, "Monster", 0, "Zombie", nil, "zombie-copy-" .. index)
		assert(made and result.monster.uid)
		table.insert(ids, result.monster.uid)
	end
	assert(#profile.farmMonsters == beforeCount + 3, "duplicate species were collapsed")
	backend.hook = function()
		profile.monsterShards.Goblin += 2
		Save.saveNow(player, "gain_during_fusion")
	end
	local fused, _, _, result = Save.claimRetentionReward(player, "MonsterFusion", 0, "Fusion", ids, "fusion-operation-1")
	assert(fused and result.monster.monsterId == "Zombie", "fusion changed species")
	assert(#profile.farmMonsters == beforeCount + 1 and #backend.record.farmMonsters == beforeCount + 1, "fusion spend/result mismatch")
	for _, monster in profile.farmMonsters do assert(not table.find(ids, monster.uid), "fusion input survived") end
	assert(profile.monsterShards.Goblin == backend.record.monsterShards.Goblin, "concurrent fusion snapshot lost shards")
	assert(Save.claimRetentionReward(player, "MonsterFusion", 0, "Fusion", ids, "fusion-operation-1"), "fusion retry failed after inputs consumed")
	assert(#profile.farmMonsters == beforeCount + 1, "fusion retry duplicated output")
	assert(select(2, Save.claimRetentionReward(player, "MonsterFusion", 0, "Fusion", { ids[1], ids[1], ids[1] }, "invalid-fusion-1")) == "NotReady")
	local savedMonsterCount = #profile.farmMonsters
	handlers.remove(player)
	player.Parent = true
	handlers.add(player)
	assert(#profile.farmMonsters == savedMonsterCount, "rejoin lost individual monsters")
	assert(Save.claimRetentionReward(player, "MonsterFusion", 0, "Fusion", ids, "fusion-operation-1"), "saved fusion receipt was lost on rejoin")
	assert(#profile.farmMonsters == savedMonsterCount, "rejoin retry duplicated fusion output")
	local spinDay=time.dayKey(now)
	local beforeSpin=backend.record.brains
	assert(select(2,Save.claimRetentionReward(player,"Spin",spinDay-1,"DailySpin"))=="Expired")
	local beforeHighest=highest
	highest=2
	assert(select(2,Save.claimRetentionReward(player,"Spin",spinDay,"DailySpin"))=="NotReady")
	highest=beforeHighest
	local spinBusy
	backend.hook=function()
		Save.saveNow(player,"leave_during_spin")
		spinBusy=select(2,Save.claimRetentionReward(player,"Spin",spinDay,"DailySpin"))
		profile=nil;player.Parent=nil
	end
	local spun,_,spinBrains=Save.claimRetentionReward(player,"Spin",spinDay,"DailySpin")
	local savedSpin=backend.record.retention.spin
	assert(spun and spinBusy=="Busy" and savedSpin.dayKey==spinDay and savedSpin.brains==spinBrains)
	assert(backend.record.brains==beforeSpin+spinBrains,"spin disconnect lost payout")
	handlers.remove(player)
	player.Parent=true;handlers.add(player)
	assert(retention.spin.rewardId==savedSpin.rewardId and retention.spin.brains==spinBrains)
	assert(select(2,Save.claimRetentionReward(player,"Spin",spinDay,"DailySpin"))=="AlreadyClaimed")
	now+=86400
	assert(Save.claimRetentionReward(player,"Spin",time.dayKey(now),"DailySpin"),"spin next UTC day")

	local spinReceipt=retention.spin
	local challengeReceipt=retention.challengeClaimDay
	local loginReceipt=copy(retention.login)
	retention.brainrotTickets=1
	profile.upgrades.WalkSpeed=15;profile.upgrades.Magnet=5
	Save.resetProgress(player)
	assert(current==1 and highest==1 and backend.record.brains==0,"Reset Progress did not reset campaign")
	assert(backend.record.retention.spin.dayKey==spinReceipt.dayKey
		and backend.record.retention.spin.rewardId==spinReceipt.rewardId
		and backend.record.retention.challengeClaimDay==challengeReceipt,"Reset Progress reopened a daily reward")
	assert(not backend.record.retention.achievements.ReachDay30.claimed,"Reset Progress retained permanent quest claims")
	assert(retention.login.welcomeClaims==7 and retention.login.lastClaimDay==loginReceipt.lastClaimDay,"reset reopened first-time rewards")
	assert(backend.record.upgrades.WalkSpeed==2 and backend.record.upgrades.Magnet==2,"reset must retain only first-time upgrade levels")
	assert(profile.upgrades.WalkSpeed==2 and profile.upgrades.Magnet==2,"live reset upgrades disagree with save")
	assert(backend.record.retention.brainrotTickets==1,"reset lost an unused ticket")
	Save.resetProgress(player)
	assert(backend.record.upgrades.WalkSpeed==2 and backend.record.upgrades.Magnet==2
		and backend.record.retention.brainrotTickets==1 and backend.record.brains==0,"repeated reset duplicated rewards")
	retention.brainrotTickets=0
	Save.resetProgress(player)
	assert(backend.record.retention.brainrotTickets==0,"reset refunded a spent ticket")

	handlers.remove(player)
	player.Parent=true;handlers.add(player)
	current,highest=2,2
	backend.hook=function()
		-- Simulate gameplay cleanup while the final leave write yields, then
		-- BindToClose attempting another snapshot of the cleared runtime.
		current,highest=1,1
		profile=nil
		Save.saveNow(player,"shutdown")
	end
	handlers.remove(player)
	assert(backend.record.currentLevel==2 and backend.record.highestLevel==2,"shutdown replaced final leave snapshot with Day 1")
	player.Parent=true;handlers.add(player)
	assert(current==2 and highest==2,"rejoin lost the saved day after shutdown")
	handlers.remove(player)
	backend.record.version=17
	player.Parent=true
	handlers.add(player)
	assert(player.kicked and backend.record.version==17,"newer schema overwritten")
	return "PASS: full SaveService in-memory tests: quest regression, v7/v8/v9/v10→v16, instance combining, fusion, retry receipts and stars, durable first-time/weekly/ticket/achievement/challenge/spin flags and balances, concurrent purchase/save merge, duplicate claims, reconnect and intro save, disconnect during login claim, lease release, newer schema refusal. No real player data accessed."

end

