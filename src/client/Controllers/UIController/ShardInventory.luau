--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.FarmProgressionConfig)
local Farm = require(Shared.Utilities.FarmProgression)
local Monsters = require(Shared.Monsters)
local Remotes = require(Shared.Remotes)
local Theme = require(Shared.Config.UITheme)
local HttpService = game:GetService("HttpService")
local ShardInventory = {}

function ShardInventory.new(list: ScrollingFrame): (any) -> boolean
	local rows = {}
	local ids = {}
	for id in Config.MONSTERS do table.insert(ids, id) end
	table.sort(ids)
	local pending: string? = nil
	local requestId = 0
	local operations: { [string]: string } = {}
	for index, id in ids do
		local card = Instance.new("Frame")
		card.Name, card.LayoutOrder = id .. "Shards", index + 10
		card.Size, card.Visible = UDim2.new(1, 0, 0, 108), false
		Theme.applyButtonLook(card, Theme.INVENTORY_PACKET, 12)
		card.Parent = list
		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Position, title.Size = UDim2.fromOffset(12, 8), UDim2.new(1, -145, 0, 30)
		title.Text = Monsters.get(id).name .. " Shards"
		title.TextSize, title.Font = 16, Enum.Font.GothamBold
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = Theme.INVENTORY_INK
		title.TextWrapped = true
		title.Parent = card
		local detail = title:Clone()
		detail.Name = "ShardProgress"
		detail.Position, detail.Size = UDim2.fromOffset(12, 42), UDim2.new(1, -145, 0, 52)
		detail.TextSize, detail.Font = 13, Enum.Font.Gotham
		detail.Parent = card
		local button = Instance.new("TextButton")
		button.Position, button.Size = UDim2.new(1, -130, 0, 26), UDim2.fromOffset(118, 50)
		button.TextSize = 14
		Theme.applyButtonLook(button, Theme.SUCCESS, 10)
		Theme.applyOutlinedTitle(button)
		button.Parent = card
		button.Activated:Connect(function()
			if not button.Active or pending then return end
			pending = id
			requestId += 1
			local request = requestId
			task.delay(15, function()
				if list.Parent and requestId == request and pending == id then
					pending = nil
					button.Text = "Retry"
				end
			end)
			button.Text = "Combining…"
			operations[id] = operations[id] or HttpService:GenerateGUID(false)
			Remotes.getEvent("CombineMonsterShards"):FireServer(id, operations[id])
		end)
		rows[id] = { card = card, detail = detail, button = button }
	end
	local state: any = nil
	local function refresh(profile: any): boolean
		state = profile
		local anyItems = false
		for id, row in rows do
			local amount = if profile and profile.monsterShards then profile.monsterShards[id] or 0 else 0
			local owned = profile and table.find(profile.collectedMonsters or {}, id) ~= nil
			row.card.Visible = amount > 0 or owned == true
			anyItems = anyItems or row.card.Visible
			row.detail.Text = string.format("%d / %d shards\n%s", amount, Config.MONSTERS[id].shards, "Random size • Lv. 1–12")
			row.button.Active = amount >= Config.MONSTERS[id].shards and pending == nil
			row.button.Text = if pending == id then "Combining…" elseif amount < Config.MONSTERS[id].shards then "Need shards" else "Combine"
		end
		return anyItems
	end
	local result = Remotes.getEvent("MonsterCombineResult").OnClientEvent:Connect(function(payload)
		if payload.operation ~= operations[payload.monsterId] then return end
		pending = nil
		if payload.success then operations[payload.monsterId] = nil end
		refresh(state)
		local row = rows[payload.monsterId]
		if row and not payload.success then row.button.Text = "Try again"
		elseif row and payload.monster then row.button.Text = payload.monster.tier .. " · Lv. " .. tostring(require(Shared.Utilities.MonsterFusion).tier(payload.monster.tier).level) end
	end)
	list.Destroying:Once(function() result:Disconnect() end)
	return refresh
end

return ShardInventory
