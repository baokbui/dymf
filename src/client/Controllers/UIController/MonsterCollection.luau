--!strict
-- Select exact owned monster instances for a server-validated fusion.
local Shared = game:GetService("ReplicatedStorage").Shared
local Fusion = require(Shared.Utilities.MonsterFusion)
local Config = require(Shared.Config.MonsterFusionConfig)
local Farm = require(Shared.Utilities.FarmProgression)
local Monsters = require(Shared.Monsters)
local Remotes = require(Shared.Remotes)
local Theme = require(Shared.Config.UITheme)
local HttpService = game:GetService("HttpService")
local Collection = {}

local function label(parent: Instance, text: string, position: UDim2, size: UDim2, fontSize: number): TextLabel
	local result = Instance.new("TextLabel")
	result.Text, result.TextSize = text, fontSize
	result.Position, result.Size = position, size
	result.BackgroundTransparency, result.TextWrapped = 1, true
	result.TextXAlignment = Enum.TextXAlignment.Left
	Theme.applyBodyText(result, Theme.INVENTORY_INK)
	result.Parent = parent
	return result
end

function Collection.new(list: ScrollingFrame): (any) -> boolean
	local header = Instance.new("Frame")
	header.Name, header.LayoutOrder = "MonsterFusion", 1000
	header.Size = UDim2.new(1, 0, 0, 156)
	header.BackgroundTransparency = 1
	header.Parent = list
	label(header, "Farm monsters", UDim2.fromOffset(8, 4), UDim2.new(1, -16, 0, 26), 18).Font = Enum.Font.GothamBold
	local status = label(header, "Select 3–5 of one species. Consumes them for one random-size monster.", UDim2.fromOffset(8, 34), UDim2.new(1, -16, 0, 42), 13)
	local odds = label(header, "", UDim2.fromOffset(8, 80), UDim2.new(1, -16, 0, 24), 12)
	local fuse = Instance.new("TextButton")
	fuse.Name, fuse.TextSize = "Fuse", 14
	fuse.Position, fuse.Size = UDim2.fromOffset(8, 110), UDim2.fromOffset(164, 36)
	Theme.applyButtonLook(fuse, Theme.SUCCESS, 9)
	Theme.applyOutlinedTitle(fuse)
	fuse.Parent = header
	local clear = fuse:Clone()
	clear.Name, clear.Text = "ClearSelection", "Clear"
	clear.Position, clear.Size = UDim2.fromOffset(180, 110), UDim2.fromOffset(80, 36)
	clear.Parent = header
	local rows, selected = {}, {}
	local state: any = nil
	local pending = false
	local operation: string? = nil
	local operationSelection = ""
	local message: string? = nil
	local refresh: (any) -> boolean
	local function selection(): { string }
		local ids = {}
		for uid in selected do table.insert(ids, uid) end
		table.sort(ids)
		return ids
	end
	refresh = function(profile: any): boolean
		state = profile
		local monsters = Fusion.sanitize(if profile then profile.farmMonsters else nil, if profile then profile.collectedMonsters else nil)
		local owned = {}
		for _, monster in monsters do owned[monster.uid] = monster end
		for uid in selected do if not owned[uid] then selected[uid] = nil end end
		local ids = selection()
		local species = if #ids > 0 then owned[ids[1]].monsterId else nil
		header.Visible = #monsters > 0
		status.Text = message or "Select 3–5 of one species. Consumes them for one random-size monster."
		local weights = Config.FUSION_WEIGHTS[#ids]
		odds.Text = if weights then string.format("Big %.1f%% • Gigantic %.1f%% • Titanic %.1f%%", weights[4], weights[5], weights[6]) else "Choose 3, 4 or 5 monsters to see the odds"
		fuse.Text = if pending then "Fusing…" else string.format("Fuse (%d/5)", #ids)
		fuse.Active = not pending and #ids >= 3 and #ids <= 5
		clear.Active = not pending
		for uid, row in rows do if not owned[uid] then row:Destroy(); rows[uid] = nil end end
		for index, monster in monsters do
			local row = rows[monster.uid]
			if not row then
				row = Instance.new("TextButton")
				row.Name, row.Text = "FarmMonster_" .. monster.uid, ""
				row.Size = UDim2.new(1, 0, 0, 78)
				row.Parent = list
				local title = label(row, "", UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 28), 15)
				title.Name, title.Font = "Title", Enum.Font.GothamBold
				label(row, "", UDim2.fromOffset(12, 38), UDim2.new(1, -24, 0, 28), 12).Name = "Details"
				local uid = monster.uid
				row.Activated:Connect(function()
					if not row.Active or pending then return end
					selected[uid] = if selected[uid] then nil else true
					message, operation = nil, nil
					refresh(state)
				end)
				rows[uid] = row
			end
			row.LayoutOrder = 1000 + index
			Theme.applyButtonLook(row, if selected[monster.uid] then Theme.SUCCESS else Theme.INVENTORY_PACKET, 10)
			row.Active = not pending and (selected[monster.uid] == true or (#ids < 5 and (not species or species == monster.monsterId)))
			local tier = Fusion.tier(monster.tier)
			local title = row:FindFirstChild("Title") :: TextLabel
			title.Text = (if selected[monster.uid] then "✓ " else "") .. Monsters.get(monster.monsterId).name
			local detail = row:FindFirstChild("Details") :: TextLabel
			detail.Text = string.format("%s • Lv. %d • %s", tier.id, tier.level, Farm.formatRate(Farm.monsterRate(monster)))
		end
		return #monsters > 0
	end
	clear.Activated:Connect(function()
		if pending then return end
		table.clear(selected)
		message, operation = nil, nil
		refresh(state)
	end)
	fuse.Activated:Connect(function()
		if not fuse.Active or pending then return end
		local ids = selection()
		local signature = table.concat(ids, ",")
		if not operation or operationSelection ~= signature then operation = HttpService:GenerateGUID(false); operationSelection = signature end
		pending, message = true, nil
		refresh(state)
		Remotes.getEvent("FuseFarmMonsters"):FireServer(ids, operation)
		local current = operation
		task.delay(15, function()
			if list.Parent and pending and current == operation then
				pending = false
				message = "Still saving. Retry the same selection to check the result."
				refresh(state)
			end
		end)
	end)
	local connection = Remotes.getEvent("MonsterFusionResult").OnClientEvent:Connect(function(result)
		if result.operation ~= operation then return end
		pending = false
		if result.success and result.monster then
			local monster = result.monster
			message = string.format("Created %s %s • Lv. %d", monster.tier, Monsters.get(monster.monsterId).name, Fusion.tier(monster.tier).level)
			table.clear(selected)
			operation = nil
		else
			message = if result.reason == "NotReady" then "Some selected monsters are no longer available." else "Unable to fuse. Please try again."
		end
		refresh(state)
	end)
	list.Destroying:Once(function() connection:Disconnect() end)
	return refresh
end

return Collection
