--!strict
-- Owned farm pets: display state and send explicit equip/unequip intent.
local Shared = game:GetService("ReplicatedStorage").Shared
local Fusion = require(Shared.Utilities.MonsterFusion)
local Residents = require(Shared.Utilities.FarmResidents)
local Farm = require(Shared.Utilities.FarmProgression)
local ProgressConfig = require(Shared.Config.ProgressConfig)
local Monsters = require(Shared.Monsters)
local Remotes = require(Shared.Remotes)
local Theme = require(Shared.Config.UITheme)
local UIEvents = require(script.Parent.Parent.Parent.UIEvents)
local Preview = require(script.Parent.Parent.Parent.Utilities.MonsterPreview)
local Pets = {}
local capacityUpgrade = ProgressConfig.upgradeById("FarmCapacity")

local function label(parent: Instance, name: string, y: number, height: number, size: number): TextLabel
	local text = Instance.new("TextLabel")
	text.Name, text.BackgroundTransparency, text.TextSize = name, 1, size
	text.Position, text.Size = UDim2.fromOffset(5, y), UDim2.new(1, -10, 0, height)
	text.TextWrapped = true
	Theme.applyBodyText(text, Theme.INVENTORY_INK)
	text.Parent = parent
	return text
end

function Pets.new(parent: Frame): ScrollingFrame
	local list = Instance.new("ScrollingFrame")
	list.Name, list.Visible, list.BackgroundTransparency, list.BorderSizePixel = "Pets", false, 1, 0
	list.Position, list.Size = UDim2.fromOffset(12, 82), UDim2.new(1, -24, 1, -94)
	list.AutomaticCanvasSize, list.CanvasSize = Enum.AutomaticSize.Y, UDim2.new()
	list.ScrollingDirection, list.ScrollBarThickness = Enum.ScrollingDirection.Y, 6
	list.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	list.Parent = parent
	local padding = Instance.new("UIPadding")
	padding.PaddingTop, padding.PaddingLeft = UDim.new(0, 5), UDim.new(0, 5)
	padding.PaddingBottom, padding.PaddingRight = UDim.new(0, 5), UDim.new(0, 5)
	padding.Parent = list
	local layout = Instance.new("UIListLayout")
	layout.SortOrder, layout.Padding, layout.Parent = Enum.SortOrder.LayoutOrder, UDim.new(0, 8), list
	local status = label(list, "Status", 0, 38, 13)
	status.LayoutOrder = -1
	local holder = Instance.new("Frame")
	holder.Name, holder.BackgroundTransparency = "Tiles", 1
	holder.Size, holder.AutomaticSize = UDim2.fromScale(1, 0), Enum.AutomaticSize.Y
	holder.Parent = list
	local grid = Instance.new("UIGridLayout")
	grid.CellSize, grid.CellPadding = UDim2.fromOffset(112, 172), UDim2.fromOffset(8, 8)
	grid.SortOrder, grid.Parent = Enum.SortOrder.LayoutOrder, holder
	local tiles = {}
	local state: any = UIEvents.getProfileState()
	local pending: string? = nil
	local requestSerial = 0
	local message: string? = nil
	local refresh: () -> ()
	refresh = function()
		local monsters = Fusion.sanitize(if state then state.farmMonsters else nil, if state then state.collectedMonsters else nil)
		local capacity = ProgressConfig.upgradeLevel(capacityUpgrade, if state and state.upgrades then state.upgrades.FarmCapacity else nil)
		local selected = Residents.selected(monsters, capacity)
		local active, owned = {}, {}
		for _, monster in selected do active[monster.uid] = true end
		for _, monster in monsters do owned[monster.uid] = true end
		for uid, tile in tiles do if not owned[uid] then tile:Destroy(); tiles[uid] = nil end end
		status.Text = message or (if #monsters == 0 then "No pets yet. Combine shards in Items." else string.format("%d / %d on farm • Only placed pets earn brains.", #selected, capacity))
		for index, monster in monsters do
			local tile = tiles[monster.uid]
			if not tile then
				tile = Instance.new("TextButton")
				tile.Name, tile.Text, tile.Parent = "Pet_" .. monster.uid, "", holder
				label(tile, "Name", 66, 31, 13).Font = Enum.Font.GothamBold
				label(tile, "Tier", 98, 18, 11)
				label(tile, "Income", 116, 18, 10)
				local action = label(tile, "Action", 140, 25, 12)
				Theme.applyButtonLook(action, Theme.SUCCESS, 7)
				action.Font = Enum.Font.GothamBold
				local uid = monster.uid
				tile.Activated:Connect(function()
					if pending or not tile.Active then return end
					local placed = tile:GetAttribute("OnFarm") == true
					pending, message = uid, nil
					requestSerial += 1
					local serial = requestSerial
					refresh()
					Remotes.getEvent("SetFarmPet"):FireServer(uid, not placed)
					task.delay(8, function()
						if list.Parent and pending == uid and requestSerial == serial then pending = nil; message = "No response. Please try again."; refresh() end
					end)
				end)
				tiles[uid] = tile
			end
			if list.Visible and not tile:GetAttribute("PreviewMounted") then
				Preview.mount(tile, Monsters.get(monster.monsterId), UDim2.fromOffset(66, 60), UDim2.new(0.5, 0, 0, 4))
				tile:SetAttribute("PreviewMounted", true)
			end
			local placed = active[monster.uid] == true
			tile.LayoutOrder = index
			tile:SetAttribute("OnFarm", placed)
			tile.Active = pending == nil and (placed or #selected < capacity)
			Theme.applyButtonLook(tile, if placed then Theme.INVENTORY_INSET else Theme.INVENTORY_PACKET, 10)
			local name = tile:FindFirstChild("Name") :: TextLabel
			local tierLabel = tile:FindFirstChild("Tier") :: TextLabel
			local income = tile:FindFirstChild("Income") :: TextLabel
			local action = tile:FindFirstChild("Action") :: TextLabel
			name.Text = Monsters.get(monster.monsterId).name
			local tier = Fusion.tier(monster.tier)
			tierLabel.Text = string.format("%s • Lv. %d", tier.id, tier.level)
			income.Text = Farm.formatRate(Farm.monsterRate(monster))
			action.Text = if pending == monster.uid then "Updating…" elseif placed then "Remove" else "Place on farm"
		end
	end
	local profileConnection = UIEvents.profileUpdated:Connect(function(profile) state = profile; refresh() end)
	local visibleConnection = list:GetPropertyChangedSignal("Visible"):Connect(refresh)
	local resultConnection = Remotes.getEvent("FarmPetResult").OnClientEvent:Connect(function(result)
		if type(result) ~= "table" or result.uid ~= pending then return end
		pending = nil
		local errors = { FarmFull = "Your farm is full. Remove a pet or upgrade capacity.", NotOwned = "That pet is no longer owned.", DayPaused = "Resume the day before changing pets.", Busy = "Saving progress. Try again shortly." }
		message = if result.success then nil else (errors[result.reason] or "Unable to change pets. Try again.")
		refresh()
	end)
	list.Destroying:Once(function() profileConnection:Disconnect(); visibleConnection:Disconnect(); resultConnection:Disconnect() end)
	refresh()
	return list
end

return Pets
