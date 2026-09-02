--!strict
--[[
	TextShine
	Left-to-right gleam on a TextLabel (evolution rarity titles), then back.
	One Heartbeat drives every active gradient so inspect rows and world
	nameplates share it.
]]

local RunService = game:GetService("RunService")

local TextShine = {}

local SHINE_PERIOD = 2.0
local active: { [UIGradient]: boolean } = {}
local heartbeatStarted = false

local function ensureHeartbeat()
	if heartbeatStarted then
		return
	end
	heartbeatStarted = true
	RunService.Heartbeat:Connect(function()
		-- 0→1 across, then 1→0 back (no jump).
		local cycle = (os.clock() / SHINE_PERIOD) % 2
		local t = 1 - math.abs(cycle - 1)
		local offset = Vector2.new(-1 + 2 * t, 0)
		for gradient in pairs(active) do
			if not gradient.Parent then
				active[gradient] = nil
				continue
			end
			gradient.Offset = offset
		end
	end)
end

function TextShine.clear(label: TextLabel)
	local existing = label:FindFirstChildOfClass("UIGradient")
	if existing then
		active[existing] = nil
		existing:Destroy()
	end
end

function TextShine.apply(label: TextLabel, dark: Color3)
	TextShine.clear(label)
	label.TextColor3 = Color3.new(1, 1, 1)
	local gleam = dark:Lerp(Color3.fromRGB(255, 255, 255), 0.82)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, dark),
		ColorSequenceKeypoint.new(0.18, dark),
		ColorSequenceKeypoint.new(0.34, gleam),
		ColorSequenceKeypoint.new(0.50, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.66, gleam),
		ColorSequenceKeypoint.new(0.82, dark),
		ColorSequenceKeypoint.new(1, dark),
	})
	gradient.Rotation = 12
	gradient.Offset = Vector2.new(-1, 0)
	gradient.Parent = label
	active[gradient] = true
	ensureHeartbeat()
end

return TextShine
