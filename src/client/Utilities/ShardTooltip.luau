--!strict
-- One shared hover/tap detail card, outside the inventory scroller's clipping.
local Theme = require(game:GetService("ReplicatedStorage").Shared.Config.UITheme)
local Tooltip = {}

function Tooltip.new(list: ScrollingFrame, combine: (string) -> ()): any
	local host = list.Parent :: GuiObject
	local panel = Instance.new("Frame")
	panel.Name, panel.Size, panel.Visible = "ShardTooltip", UDim2.fromOffset(228, 154), false
	panel.ZIndex, panel.Active = 30, true
	Theme.applyButtonLook(panel, Theme.INVENTORY_INSET, 10)
	panel.Parent = host
	local function text(name: string, y: number, height: number, size: number): TextLabel
		local label = Instance.new("TextLabel")
		label.Name, label.BackgroundTransparency = name, 1
		label.Position, label.Size = UDim2.fromOffset(12, y), UDim2.new(1, -24, 0, height)
		label.TextSize, label.TextWrapped, label.TextXAlignment = size, true, Enum.TextXAlignment.Left
		Theme.applyBodyText(label, Theme.INVENTORY_INK)
		label.ZIndex, label.Parent = 31, panel
		return label
	end
	local title = text("Name", 8, 26, 14)
	title.Font = Enum.Font.GothamBold
	local description = text("Description", 36, 36, 12)
	local count = text("OwnedNeeded", 76, 22, 13)
	count.Font = Enum.Font.GothamBold
	local action = Instance.new("TextButton")
	action.Name, action.Size, action.Position = "Combine", UDim2.new(1, -24, 0, 32), UDim2.fromOffset(12, 108)
	action.TextSize, action.ZIndex = 13, 31
	Theme.applyButtonLook(action, Theme.SUCCESS, 8)
	Theme.applyOutlinedTitle(action)
	action.Parent = panel
	local active: string? = nil
	local hoveredTile, hoveredPanel, pinned = false, false, false
	local token = 0
	local function hide()
		active, hoveredTile, hoveredPanel, pinned = nil, false, false, false
		panel.Visible = false
		token += 1
	end
	local function scheduleHide()
		token += 1
		local current = token
		task.delay(0.18, function()
			if token == current and not hoveredTile and not hoveredPanel and not pinned then hide() end
		end)
	end
	local function place(tile: GuiObject)
		local scale = if tile.AbsoluteSize.Y > 0 then tile.AbsoluteSize.Y / tile.Size.Y.Offset else 1
		local offset = (tile.AbsolutePosition - host.AbsolutePosition) / scale
		local bounds = host.AbsoluteSize / scale
		local x = offset.X + tile.AbsoluteSize.X / scale + 8
		if x + 228 > bounds.X - 6 then x = offset.X - 236 end
		panel.Position = UDim2.fromOffset(math.clamp(x, 6, math.max(6, bounds.X - 234)),
			math.clamp(offset.Y, 6, math.max(6, bounds.Y - 160)))
	end
	panel.MouseEnter:Connect(function() hoveredPanel = true; token += 1 end)
	panel.MouseLeave:Connect(function() hoveredPanel = false; scheduleHide() end)
	action.Activated:Connect(function() if active and action.Active then combine(active) end end)
	local scroll = list:GetPropertyChangedSignal("CanvasPosition"):Connect(hide)
	local visible = list:GetPropertyChangedSignal("Visible"):Connect(hide)
	local size = list:GetPropertyChangedSignal("AbsoluteSize"):Connect(hide)
	local hostVisible = host:GetPropertyChangedSignal("Visible"):Connect(hide)
	list.Destroying:Once(function() scroll:Disconnect(); visible:Disconnect(); size:Disconnect(); hostVisible:Disconnect(); hide(); panel:Destroy() end)
	local api = {}
	function api.update(id: string, name: string, amount: number, needed: number, message: string?, busy: boolean)
		if active ~= id then return end
		title.Text = name
		description.Text = "Combine shards to form a " .. name .. "."
		count.Text = string.format("%d / %d shards", amount, needed)
		action.Text = message or (if amount >= needed then "Combine" else "Need shards")
		action.Active, action.AutoButtonColor = amount >= needed and not busy, amount >= needed and not busy
		action.BackgroundColor3 = if action.Active then Theme.SUCCESS else Theme.INVENTORY_PACKET
		action.Visible = amount >= needed or message ~= nil
		panel.Size = UDim2.fromOffset(228, if action.Visible then 154 else 108)
	end
	function api.bind(tile: TextButton, id: string, refresh: () -> ())
		local function show(pin: boolean)
			active, pinned = id, pin
			token += 1
			place(tile)
			panel.Visible = true
			refresh()
		end
		tile.MouseEnter:Connect(function() hoveredTile = true; show(false) end)
		tile.MouseLeave:Connect(function() hoveredTile = false; scheduleHide() end)
		tile.SelectionGained:Connect(function() show(true) end)
		tile.SelectionLost:Connect(hide)
		tile.Activated:Connect(function()
			if active == id and pinned then hide() else show(true) end
		end)
		tile:GetPropertyChangedSignal("Visible"):Connect(function() if active == id and not tile.Visible then hide() end end)
	end
	return api
end

return Tooltip
