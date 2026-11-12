--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.FarmProgressionConfig)
local Monsters = require(Shared.Monsters)
local Remotes = require(Shared.Remotes)
local Theme = require(Shared.Config.UITheme)
local HttpService = game:GetService("HttpService")
local Utilities = script.Parent.Parent.Parent.Utilities
local ShardIcon = require(Utilities.ShardIcon)
local ShardTooltip = require(Utilities.ShardTooltip)
local ShardInventory = {}
local Visual = require(Shared.Config.ShardVisualConfig)
local TILE_WIDTH, TILE_HEIGHT, GAP = Visual.TILE_WIDTH, Visual.TILE_HEIGHT, Visual.TILE_GAP

function ShardInventory.new(list: ScrollingFrame): (any) -> boolean
	local holder = Instance.new("Frame")
	holder.Name, holder.LayoutOrder, holder.Visible = "ShardTiles", 10, false
	holder.BackgroundTransparency, holder.Size = 1, UDim2.new(1, 0, 0, 0)
	holder.Parent = list
	local grid = Instance.new("UIGridLayout")
	grid.CellSize, grid.CellPadding = UDim2.fromOffset(TILE_WIDTH, TILE_HEIGHT), UDim2.fromOffset(GAP, GAP)
	grid.SortOrder, grid.Parent = Enum.SortOrder.LayoutOrder, holder
	local rows, ids, operations = {}, {}, {}
	for id in Config.MONSTERS do table.insert(ids, id) end
	table.sort(ids)
	local pending: string? = nil
	local requestId = 0
	local state: any = nil
	local refresh: (any) -> boolean
	local tooltip
	local messages: { [string]: string } = {}
	local function combine(id: string)
		local amount = if state and state.monsterShards then state.monsterShards[id] or 0 else 0
		if pending or amount < Config.MONSTERS[id].shards then return end
		pending = id
		requestId += 1
		local request = requestId
		messages[id] = "Combining…"
		operations[id] = operations[id] or HttpService:GenerateGUID(false)
		refresh(state)
		task.delay(15, function()
			if list.Parent and requestId == request and pending == id then
				pending, messages[id] = nil, "Retry"
				refresh(state)
			end
		end)
		Remotes.getEvent("CombineMonsterShards"):FireServer(id, operations[id])
	end
	tooltip = ShardTooltip.new(list, combine)
	for index, id in ids do
		local tile = Instance.new("TextButton")
		tile.Name, tile.LayoutOrder, tile.Visible, tile.Text = id .. "Shards", index, false, ""
		tile.Size = UDim2.fromOffset(TILE_WIDTH, TILE_HEIGHT)
		Theme.applyButtonLook(tile, Theme.INVENTORY_PACKET, 10)
		tile.Parent = holder
		local icon = ShardIcon.new(tile, id)
		icon.AnchorPoint, icon.Position, icon.Size = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 0), UDim2.fromOffset(40, 40)
		local title = Instance.new("TextLabel")
		title.Name, title.Text = "Name", Monsters.get(id).name
		title.BackgroundTransparency = 1
		title.Position, title.Size = UDim2.fromOffset(3, 40), UDim2.new(1, -6, 0, 22)
		title.TextSize, title.Font, title.TextWrapped = 10, Enum.Font.GothamBold, true
		title.TextColor3, title.Parent = Theme.INVENTORY_INK, tile
		local count = Instance.new("TextLabel")
		count.Name, count.BackgroundTransparency = "Quantity", 1
		count.Position, count.Size = UDim2.fromOffset(3, 63), UDim2.new(1, -6, 0, 12)
		count.TextSize, count.Font, count.TextColor3 = 10, Enum.Font.GothamMedium, Theme.INVENTORY_INK
		count.Parent = tile
		rows[id] = tile
		tooltip.bind(tile, id, function() refresh(state) end)
	end
	local function fitGrid()
		local first = rows[ids[1]]
		local scale = if first.AbsoluteSize.Y > 0 then first.AbsoluteSize.Y / TILE_HEIGHT else 1
		holder.Size = UDim2.new(1, 0, 0, grid.AbsoluteContentSize.Y / math.max(scale, 0.01))
	end
	local resize = grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitGrid)
	refresh = function(profile: any): boolean
		state = profile
		local anyItems = false
		for id, tile in rows do
			local amount = if profile and profile.monsterShards then profile.monsterShards[id] or 0 else 0
			local owned = profile and table.find(profile.collectedMonsters or {}, id) ~= nil
			tile.Visible = amount > 0 or owned == true
			anyItems = anyItems or tile.Visible
			tile.Quantity.Text = string.format("%d / %d", amount, Config.MONSTERS[id].shards)
			if tile.Visible then ShardIcon.mountPortrait(tile.ShardIcon) end
			tooltip.update(id, Monsters.get(id).name, amount, Config.MONSTERS[id].shards, messages[id], pending ~= nil)
		end
		holder.Visible = anyItems
		task.defer(function() if list.Parent then fitGrid() end end)
		return anyItems
	end
	local result = Remotes.getEvent("MonsterCombineResult").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or type(payload.monsterId) ~= "string" or not operations[payload.monsterId]
			or payload.operation ~= operations[payload.monsterId] then return end
		pending = nil
		if payload.success then operations[payload.monsterId] = nil end
		messages[payload.monsterId] = if payload.success then "Combined!" else "Try again"
		refresh(state)
	end)
	list.Destroying:Once(function() result:Disconnect(); resize:Disconnect() end)
	return refresh
end

return ShardInventory
