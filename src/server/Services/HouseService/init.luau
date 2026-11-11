--!strict
-- Owns the sanctuary collection presentation and online passive income.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.SanctuaryConfig)
local ProgressConfig = require(Shared.Config.ProgressConfig)
local capacityUpgrade = ProgressConfig.upgradeById("FarmCapacity")
local HouseConfig = require(Shared.Config.HouseConfig)
local Fusion = require(Shared.Utilities.MonsterFusion)
local Farm = require(Shared.Utilities.FarmProgression)
local Monsters = require(Shared.Monsters)
local Progress = require(script.Parent.ProgressService)
local PlotService = require(script.Parent.PlotService)
local Resident = require(script.Resident)
local HouseService = { Name = "HouseService" }
type Habitat = { house: Model, signature: string, cleanup: { () -> () }, seconds: number, count: number }
local habitats: { [Player]: Habitat } = {}

local function clear(player: Player)
	local habitat = habitats[player]
	if not habitat then return end
	for _, cleanup in habitat.cleanup do cleanup() end
	habitats[player] = nil
end

local function update(player: Player)
	local plot = PlotService.getPlotModel(player)
	if not plot or not Progress.isHydrated(player) then clear(player); return end
	local house = plot:FindFirstChild("House")
	if not house or not house:IsA("Model") then clear(player); return end
	local Save = require(script.Parent.SaveService)
	if Save.isProgressionLocked(player) then return end
	local snapshot = Progress.getSaveSlice(player)
	if not snapshot then return end
	local collection = Fusion.sanitize(snapshot.farmMonsters, Progress.getCollectedMonsters(player))
	local capacity = ProgressConfig.upgradeLevel(capacityUpgrade, snapshot.upgrades.FarmCapacity)
	local selected = {}
	for index = math.max(1, #collection - capacity + 1), #collection do
		table.insert(selected, collection[index])
	end
	local identities = {}
	for _, monster in selected do table.insert(identities, monster.uid) end
	local signature = table.concat(identities, ",")
	local habitat = habitats[player]
	if habitat and habitat.house ~= house then clear(player); habitat = nil end
	if not habitat then
		habitat = { house = house, signature = "", cleanup = {}, seconds = 0, count = 0 }
		habitats[player] = habitat
	end
	if habitat.signature ~= signature then
		for _, cleanup in habitat.cleanup do cleanup() end
		table.clear(habitat.cleanup)
		habitat.signature = signature
		habitat.count = #selected
		if #selected == 0 then habitat.seconds = 0 end
		local pivot = house:GetPivot().Position
		local groundY = house:GetAttribute("ResidentGroundY")
		local center = Vector3.new(pivot.X, if type(groundY) == "number" then groundY else pivot.Y + 0.2, pivot.Z)
		local bounds = Vector2.new(
			house:GetAttribute("ResidentHalfWidth") or (HouseConfig.DEPTH / 2 - Config.EDGE_INSET),
			house:GetAttribute("ResidentHalfDepth") or (HouseConfig.WIDTH / 2 - Config.EDGE_INSET))
		local folder = house:FindFirstChild("Residents") :: Folder
		for _, monster in selected do
			local definition = Monsters.get(monster.monsterId)
			if definition then table.insert(habitat.cleanup, Resident.spawn(folder, definition, center, bounds, monster)) end
		end
	end
	local rate = 0
	for _, monster in selected do rate += Farm.monsterRate(monster) end
	house:SetAttribute("CollectedSpecies", #collection)
	house:SetAttribute("ResidentCount", #selected)
	if habitat.count == 0 then return end
	habitat.seconds += Config.UPDATE_INTERVAL * rate
	if habitat.seconds + 1e-9 >= 1 then
		local periods = math.floor(habitat.seconds + 1e-9)
		habitat.seconds = math.max(0, habitat.seconds - periods)
		Progress.addBrains(player, periods)
	end
end

function HouseService.start()
	Players.PlayerRemoving:Connect(clear)
	local folder = workspace:WaitForChild("Plots")
	for _, plot in folder:GetChildren() do
		plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
			for player, habitat in habitats do
				if habitat.house.Parent == plot then clear(player) end
			end
		end)
	end
	task.spawn(function()
		while true do
			task.wait(Config.UPDATE_INTERVAL)
			for _, player in Players:GetPlayers() do update(player) end
		end
	end)
end

return HouseService
