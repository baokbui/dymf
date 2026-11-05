--!strict
-- Cosmetic weighted wheel. The server's saved reward chooses its stopping angle.
local Shared = game:GetService("ReplicatedStorage").Shared
local Theme = require(Shared.Config.UITheme)
local BrainAmount = require(script.Parent.Parent.Parent.Utilities.BrainAmount)
local SpinWheel = {}
local DIAMETER = 256
local SLICES = 180
local COLORS = { Theme.SUCCESS, Theme.BUTTON_BG, Theme.GOLD }

function SpinWheel.build(parent: Frame)
	local disc = Instance.new("Frame")
	disc.Name = "Wheel"
	disc.AnchorPoint, disc.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 62)
	disc.Size = UDim2.fromOffset(DIAMETER, DIAMETER)
	Theme.applyButtonLook(disc, Theme.FIELD_INSET, DIAMETER / 2)
	disc.Parent = parent
	local rotor = Instance.new("Frame")
	rotor.Name, rotor.BackgroundTransparency = "Rotor", 1
	rotor.AnchorPoint, rotor.Position, rotor.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1)
	rotor.Parent = disc
	local slices: { Frame } = {}
	for index = 1, SLICES do
		local angle = (index - 0.5) * 360 / SLICES
		local length = DIAMETER / 2 - 4
		local slice = Instance.new("Frame")
		slice.Name, slice.BorderSizePixel = "Slice", 0
		-- Roblox rotates a GuiObject around its geometric center, regardless
		-- of AnchorPoint. Place that center halfway along the desired radius.
		slice.AnchorPoint = Vector2.new(0.5, 0.5)
		slice.Position = UDim2.fromScale(0.5 + math.sin(math.rad(angle)) * length / (2 * DIAMETER), 0.5 - math.cos(math.rad(angle)) * length / (2 * DIAMETER))
		slice.Size, slice.Rotation = UDim2.fromOffset(6, length), angle
		slice.BackgroundColor3 = Theme.FIELD_INSET
		slice.Parent = rotor
		slices[index] = slice
	end
	local labels = Instance.new("Folder")
	labels.Name, labels.Parent = "Rewards", rotor
	local hub = Instance.new("Frame")
	hub.Name, hub.AnchorPoint, hub.Position = "Hub", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	hub.Size, hub.ZIndex = UDim2.fromOffset(36, 36), 3
	Theme.applyButtonLook(hub, Theme.TITLE, 18)
	hub.Parent = disc
	local pointer = Instance.new("TextLabel")
	pointer.Name, pointer.Text, pointer.TextSize = "Pointer", "▼", 34
	pointer.BackgroundTransparency, pointer.ZIndex = 1, 4
	pointer.AnchorPoint, pointer.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 45)
	pointer.Size = UDim2.fromOffset(40, 38)
	Theme.applyOutlinedTitle(pointer, Theme.TITLE)
	pointer.Parent = parent
	local centers: { [string]: number } = {}
	local signature = ""
	local function configure(rewards: { any })
		local keys = {}
		for _, reward in rewards do table.insert(keys, string.format("%s:%d:%f", reward.id, reward.brains, reward.odds)) end
		local nextSignature = table.concat(keys, "|")
		if signature == nextSignature then return end
		signature = nextSignature
		labels:ClearAllChildren()
		table.clear(centers)
		local total = 0
		for _, reward in rewards do total += reward.odds end
		if total <= 0 then return end
		local start = 0
		for index, reward in rewards do
			local finish = start + reward.odds / total * 360
			local center = (start + finish) / 2
			centers[reward.id] = center
			for sliceIndex, slice in slices do
				local angle = (sliceIndex - 0.5) * 360 / SLICES
				if angle >= start and angle < finish then slice.BackgroundColor3 = COLORS[(index - 1) % #COLORS + 1] end
			end
			local amount = Instance.new("TextLabel")
			amount.Name, amount.Text, amount.TextSize = reward.id, tostring(reward.brains), 21
			amount.AnchorPoint, amount.BackgroundTransparency = Vector2.new(0.5, 0.5), 1
			amount.Position = UDim2.new(0.5, math.sin(math.rad(center)) * 83, 0.5, -math.cos(math.rad(center)) * 83)
			amount.Size, amount.ZIndex = UDim2.fromOffset(66, 34), 2
			amount.Rotation = center -- the selected reward becomes upright beneath the pointer
			Theme.applyOutlinedTitle(amount)
			amount.Parent = labels
			BrainAmount.set(amount, tostring(reward.brains), true)
			start = finish
		end
	end
	local function angleFor(id: string): number
		return (360 - (centers[id] or 0)) % 360
	end
	return { rotor = rotor, configure = configure, angleFor = angleFor }
end

return SpinWheel
