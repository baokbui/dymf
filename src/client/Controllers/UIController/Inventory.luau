--!strict
--[[
	Inventory
	Equip / unequip unlocked Brainrots for the placement shop loadout.
	Sends SetEquipped intent; server validates unlocks and max slots.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared.Brainrots)
local ProgressConfig = require(Shared.Config.ProgressConfig)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local AudioController = require(script.Parent.Parent.AudioController)

local Inventory = {}
Inventory.__index = Inventory

local PANEL_BG = Color3.fromRGB(18, 20, 30)
local TEXT = Color3.fromRGB(235, 238, 245)
local ROW_BG = Color3.fromRGB(36, 40, 54)
local EQUIPPED = Color3.fromRGB(90, 200, 120)
local UNEQUIPPED = Color3.fromRGB(70, 74, 90)

export type InventoryPanel = typeof(setmetatable(
	{} :: {
		frame: Frame,
		list: Frame,
		brainsLabel: TextLabel,
		unlocks: { string },
		equipped: { string },
		rows: { [string]: TextButton },
	},
	Inventory
))

local function styleCorner(instance: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function sortedUnlocks(unlocks: { string }): { Types.BrainrotDefinition }
	local list: { Types.BrainrotDefinition } = {}
	for _, id in unlocks do
		local def = Brainrots.get(id)
		if def then
			table.insert(list, def)
		end
	end
	table.sort(list, function(a, b)
		if a.cost ~= b.cost then
			return a.cost < b.cost
		end
		return a.name < b.name
	end)
	return list
end

function Inventory.new(parent: Frame): InventoryPanel
	parent.Visible = false
	parent.AnchorPoint = Vector2.new(0.5, 0.5)
	parent.Position = UDim2.fromScale(0.5, 0.5)
	parent.Size = UDim2.fromOffset(420, 420)
	parent.BackgroundColor3 = PANEL_BG
	parent.BackgroundTransparency = 0.06
	parent.ZIndex = 30
	styleCorner(parent, 14)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -80, 0, 32)
	title.Position = UDim2.fromOffset(16, 12)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = TEXT
	title.Text = "Inventory"
	title.Parent = parent

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 10)
	close.Size = UDim2.fromOffset(36, 36)
	close.BackgroundColor3 = Color3.fromRGB(150, 45, 45)
	close.Font = Enum.Font.GothamBold
	close.TextSize = 20
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Text = "X"
	close.Parent = parent
	styleCorner(close, 8)

	local brainsLabel = Instance.new("TextLabel")
	brainsLabel.Name = "Brains"
	brainsLabel.BackgroundTransparency = 1
	brainsLabel.Size = UDim2.new(1, -32, 0, 20)
	brainsLabel.Position = UDim2.fromOffset(16, 48)
	brainsLabel.Font = Enum.Font.Gotham
	brainsLabel.TextSize = 14
	brainsLabel.TextXAlignment = Enum.TextXAlignment.Left
	brainsLabel.TextColor3 = Color3.fromRGB(180, 140, 255)
	brainsLabel.Text = "Brains: 0"
	brainsLabel.Parent = parent

	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Size = UDim2.new(1, -32, 0, 18)
	hint.Position = UDim2.fromOffset(16, 70)
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 13
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextColor3 = Color3.fromRGB(160, 168, 180)
	hint.Text = string.format("Equip up to %d for the shop bar", ProgressConfig.MAX_EQUIPPED)
	hint.Parent = parent

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(12, 96)
	list.Size = UDim2.new(1, -24, 1, -108)
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.ScrollBarThickness = 6
	list.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local self = setmetatable({
		frame = parent,
		list = list,
		brainsLabel = brainsLabel,
		unlocks = {},
		equipped = {},
		rows = {},
	}, Inventory) :: InventoryPanel

	close.Activated:Connect(function()
		AudioController.play("UiClick")
		self:setOpen(false)
	end)

	return self
end

local function isEquipped(equipped: { string }, id: string): boolean
	for _, value in equipped do
		if value == id then
			return true
		end
	end
	return false
end

function Inventory.refresh(self: InventoryPanel)
	for _, child in self.list:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	self.rows = {}

	local order = 0
	for _, definition in sortedUnlocks(self.unlocks) do
		order += 1
		local equipped = isEquipped(self.equipped, definition.id)
		local button = Instance.new("TextButton")
		button.Name = definition.id
		button.LayoutOrder = order
		button.Size = UDim2.new(1, -8, 0, 44)
		button.BackgroundColor3 = ROW_BG
		button.AutoButtonColor = false
		button.Font = Enum.Font.GothamMedium
		button.TextSize = 15
		button.TextColor3 = TEXT
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.Text = string.format("  %s   [%s]", definition.name, if equipped then "Equipped" else "Unequipped")
		button.Parent = self.list
		styleCorner(button, 8)

		local badge = Instance.new("Frame")
		badge.Size = UDim2.fromOffset(10, 10)
		badge.Position = UDim2.new(1, -24, 0.5, -5)
		badge.BackgroundColor3 = if equipped then EQUIPPED else UNEQUIPPED
		badge.BorderSizePixel = 0
		badge.Parent = button
		styleCorner(badge, 5)

		button.Activated:Connect(function()
			AudioController.play("UiClick")
			local nextEquipped = table.clone(self.equipped)
			if isEquipped(nextEquipped, definition.id) then
				if #nextEquipped <= 1 then
					return
				end
				local filtered: { string } = {}
				for _, id in nextEquipped do
					if id ~= definition.id then
						table.insert(filtered, id)
					end
				end
				nextEquipped = filtered
			else
				if #nextEquipped >= ProgressConfig.MAX_EQUIPPED then
					return
				end
				table.insert(nextEquipped, definition.id)
			end
			Remotes.getEvent("SetEquipped"):FireServer(nextEquipped)
		end)

		self.rows[definition.id] = button
	end

	self.list.CanvasSize = UDim2.fromOffset(0, order * 50)
end

function Inventory.applyProfile(self: InventoryPanel, profile: { [string]: any })
	if type(profile.unlocks) == "table" then
		self.unlocks = profile.unlocks :: { string }
	end
	if type(profile.equipped) == "table" then
		self.equipped = profile.equipped :: { string }
	end
	if type(profile.brains) == "number" then
		self.brainsLabel.Text = string.format("Brains: %d", profile.brains)
	end
	self:refresh()
end

function Inventory.setOpen(self: InventoryPanel, open: boolean)
	self.frame.Visible = open
end

function Inventory.isOpen(self: InventoryPanel): boolean
	return self.frame.Visible
end

return Inventory
