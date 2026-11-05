--!strict
-- Item cards render server-owned quantities. Redemption stays in the Brainrot Shop.
local Theme = require(game:GetService("ReplicatedStorage").Shared.Config.UITheme)
local RewardIcon = require(script.Parent.Parent.QuestController.RewardIcon)

local InventoryItems = {}
local catalog = {
	{
		id = "BrainrotTicket",
		countKey = "brainrotTickets",
		name = "Brainrot Selection Ticket",
		description = "Redeem at your Brainrot Shop for one unowned Brainrot.",
		icon = { kind = "Ticket" },
	},
}

local function label(parent: GuiObject, name: string, copy: string, size: number): TextLabel
	local text = Instance.new("TextLabel")
	text.Name, text.Text, text.TextSize = name, copy, size
	text.BackgroundTransparency = 1
	text.TextXAlignment = Enum.TextXAlignment.Left
	Theme.applyBodyText(text, Theme.INVENTORY_INK)
	text.Parent = parent
	return text
end

function InventoryItems.new(parent: Frame): (ScrollingFrame, (any) -> ())
	local list = Instance.new("ScrollingFrame")
	list.Name, list.Visible = "Items", false
	list.Position, list.Size = UDim2.fromOffset(12, 82), UDim2.new(1, -24, 1, -94)
	list.BackgroundTransparency, list.BorderSizePixel = 1, 0
	list.AutomaticCanvasSize, list.CanvasSize = Enum.AutomaticSize.Y, UDim2.new()
	list.ScrollingDirection, list.ScrollBarThickness = Enum.ScrollingDirection.Y, 6
	list.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	list.Parent = parent
	local padding = Instance.new("UIPadding")
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 5), UDim.new(0, 5)
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 5), UDim.new(0, 5)
	padding.Parent = list
	local layout = Instance.new("UIListLayout")
	layout.SortOrder, layout.Padding = Enum.SortOrder.LayoutOrder, UDim.new(0, 10)
	layout.Parent = list

	local empty = label(list, "Empty", "Loading items…", 16)
	empty.Size = UDim2.new(1, 0, 0, 68)
	empty.TextXAlignment = Enum.TextXAlignment.Center
	empty.TextWrapped = true

	local rows = {}
	for order, definition in catalog do
		local card = Instance.new("Frame")
		card.Name, card.LayoutOrder = definition.id, order
		card.Size, card.Visible = UDim2.new(1, 0, 0, 94), false
		Theme.applyButtonLook(card, Theme.INVENTORY_PACKET, 12)
		Theme.applySurfaceDepth(card)
		card.Parent = list

		local tile = Instance.new("Frame")
		tile.Name, tile.Position, tile.Size = "IconTile", UDim2.fromOffset(10, 14), UDim2.fromOffset(66, 66)
		Theme.applyButtonLook(tile, Theme.INVENTORY_INSET, 10)
		tile.Parent = card
		local icon = RewardIcon.new(tile)
		icon.AnchorPoint, icon.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
		RewardIcon.set(icon, definition.icon)

		local title = label(card, "Title", definition.name, 16)
		title.Position, title.Size = UDim2.fromOffset(86, 9), UDim2.new(1, -151, 0, 34)
		title.Font, title.TextWrapped = Enum.Font.GothamBold, true
		local description = label(card, "Description", definition.description, 13)
		description.Position, description.Size = UDim2.fromOffset(86, 45), UDim2.new(1, -98, 0, 39)
		description.TextWrapped = true
		local count = label(card, "Quantity", "", 13)
		count.Position, count.Size = UDim2.new(1, -62, 0, 14), UDim2.fromOffset(50, 25)
		count.TextXAlignment = Enum.TextXAlignment.Center
		Theme.applyButtonLook(count, Theme.INVENTORY_INK, 7)
		Theme.applyOutlinedTitle(count)
		rows[order] = { card = card, count = count }
	end

	return list, function(payload: any)
		local ready = type(payload) == "table" and payload.ready ~= false
		local hasItems = false
		for order, definition in catalog do
			local raw = if ready then payload[definition.countKey] else nil
			local quantity = if type(raw) == "number" and raw > 0 and raw < math.huge then math.floor(raw) else 0
			local row = rows[order]
			row.card.Visible = quantity > 0
			row.count.Text = string.format("×%d", quantity)
			hasItems = hasItems or quantity > 0
		end
		empty.Visible = not hasItems
		empty.Text = if ready then "No items yet" else "Loading items…"
	end
end

return InventoryItems
