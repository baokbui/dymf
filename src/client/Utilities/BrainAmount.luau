--!strict
-- Inline currency presentation shared by rewards and statistics. No balance math.
local TextService = game:GetService("TextService")
local BrainAmount = {}
BrainAmount.IMAGE = "rbxassetid://12691330734"

function BrainAmount.set(parent: TextLabel | TextButton, value: string, showIcon: boolean?)
	local group = parent:FindFirstChild("BrainAmount") :: Frame?
	if not group then
		group = Instance.new("Frame")
		group.Name, group.BackgroundTransparency = "BrainAmount", 1
		group.AnchorPoint, group.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
		group.Parent = parent
		local label = Instance.new("TextLabel")
		label.Name, label.BackgroundTransparency = "Value", 1
		label.TextSize, label.Font = parent.TextSize, parent.Font
		label.TextColor3, label.TextStrokeColor3 = parent.TextColor3, parent.TextStrokeColor3
		label.TextStrokeTransparency = parent.TextStrokeTransparency
		label.Parent = group
		local icon = Instance.new("ImageLabel")
		icon.Name, icon.BackgroundTransparency = "Icon", 1
		icon.Image, icon.ScaleType = BrainAmount.IMAGE, Enum.ScaleType.Fit
		icon.Parent = group
		local zoom = Instance.new("UIScale")
		zoom.Parent = group
		local function fit()
			zoom.Scale = math.min(1, math.max(0.1, (parent.AbsoluteSize.X - 8) / math.max(1, group.Size.X.Offset)))
		end
		parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		group:GetPropertyChangedSignal("Size"):Connect(fit)
	end
	parent.Text = ""
	local label, icon = group.Value :: TextLabel, group.Icon :: ImageLabel
	label.Text, label.TextColor3 = value, parent.TextColor3
	local width = TextService:GetTextSize(value, label.TextSize, label.Font, Vector2.new(10000, 100)).X
	local height = math.max(24, label.TextSize + 6)
	group.Size = UDim2.fromOffset(width + (if showIcon then height + 4 else 0), height)
	label.Size = UDim2.fromOffset(width, height)
	icon.Visible, icon.Position, icon.Size = showIcon == true, UDim2.fromOffset(width + 4, 0), UDim2.fromOffset(height, height)
end

return BrainAmount
