--!strict
--[[
	MechanicIntroPopup
	Center-screen intro for campaign hazards (graves). Display-only —
	LevelService decides what/when via introducedMechanicIds.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GraveConfig = require(Shared.Config.GraveConfig)
local UITheme = require(Shared.Config.UITheme)
local ModelUtil = require(Shared.Utilities.ModelUtil)

local MechanicInfo = require(script.Parent.Parent.Parent.Utilities.MechanicInfo)
local AudioController = require(script.Parent.Parent.AudioController)

local MechanicIntroPopup = {}
MechanicIntroPopup.__index = MechanicIntroPopup

local PORTRAIT_SIZE = 120

export type MechanicIntroPopupHud = typeof(setmetatable(
	{} :: {
		frame: Frame,
		banner: TextLabel,
		portraitHolder: Frame,
		nameLabel: TextLabel,
		summaryLabel: TextLabel,
		bodyLabel: TextLabel,
		onHidden: (() -> ())?,
	},
	MechanicIntroPopup
))

local function centerAtOrigin(model: Model)
	local cf = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() - cf.Position)
end

local function frameModel(camera: Camera, model: Model)
	local cf, size = model:GetBoundingBox()
	local extent = math.max(size.X, size.Y, size.Z)
	local distance = math.max(extent * 2.1, 3.6)
	local lookFrom = cf.Position + Vector3.new(distance * 0.85, distance * 0.4, distance * 0.35)
	camera.FieldOfView = 28
	camera.CFrame = CFrame.lookAt(lookFrom, cf.Position)
end

local function mountGravePreview(parent: Frame)
	for _, child in parent:GetChildren() do
		child:Destroy()
	end

	local template = ModelUtil.findGraveTemplate(GraveConfig.MODEL_ID)
	if not template then
		local swatch = Instance.new("Frame")
		swatch.Name = "Swatch"
		swatch.AnchorPoint = Vector2.new(0.5, 0)
		swatch.Position = UDim2.new(0.5, 0, 0, 5)
		swatch.Size = UDim2.fromOffset(PORTRAIT_SIZE - 10, PORTRAIT_SIZE - 10)
		swatch.BackgroundColor3 = Color3.fromRGB(72, 74, 68)
		swatch.BorderSizePixel = 0
		swatch.Parent = parent
		UITheme.styleCorner(swatch, 8)
		return
	end

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Preview"
	viewport.AnchorPoint = Vector2.new(0.5, 0)
	viewport.Position = UDim2.new(0.5, 0, 0, 5)
	viewport.Size = UDim2.fromOffset(PORTRAIT_SIZE - 10, PORTRAIT_SIZE - 10)
	viewport.BackgroundColor3 = Color3.fromRGB(48, 52, 46)
	viewport.BackgroundTransparency = 0.2
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(190, 190, 200)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(0.85, -0.45, -0.3)
	viewport.Parent = parent

	local world = Instance.new("WorldModel")
	world.Parent = viewport

	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local model = ModelUtil.cloneTemplate(template, {
		targetFootprint = 2.4,
		faceDirection = GraveConfig.FACE_DIRECTION,
		skipBodyAlias = true,
	})
	model.Name = "PreviewModel"
	centerAtOrigin(model)
	model.Parent = world
	frameModel(camera, model)
end

function MechanicIntroPopup.new(parent: Frame): MechanicIntroPopupHud
	parent.Visible = false
	parent.AnchorPoint = Vector2.new(0.5, 0.5)
	parent.Position = UDim2.fromScale(0.5, 0.5)
	parent.Size = UDim2.fromOffset(420, 468)
	parent.ZIndex = 41
	UITheme.applyPanelLook(parent, nil, UITheme.PANEL_BG_MECHANIC_INTRO)

	local banner = Instance.new("TextLabel")
	banner.Name = "Banner"
	banner.BackgroundTransparency = 1
	banner.Size = UDim2.new(1, -24, 0, 28)
	banner.Position = UDim2.fromOffset(12, 14)
	banner.TextSize = 16
	banner.Text = "NEW HAZARD!"
	banner.Parent = parent
	UITheme.applyOutlinedTitle(banner, UITheme.WARNING)

	local portraitHolder = Instance.new("Frame")
	portraitHolder.Name = "PortraitHolder"
	portraitHolder.AnchorPoint = Vector2.new(0.5, 0)
	portraitHolder.Position = UDim2.new(0.5, 0, 0, 50)
	portraitHolder.Size = UDim2.fromOffset(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portraitHolder.BackgroundColor3 = Color3.fromRGB(48, 52, 46)
	portraitHolder.BackgroundTransparency = 0.15
	portraitHolder.BorderSizePixel = 0
	portraitHolder.Parent = parent
	UITheme.styleCorner(portraitHolder, 12)
	UITheme.applyStroke(portraitHolder, 3)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.BackgroundTransparency = 1
	nameLabel.AnchorPoint = Vector2.new(0.5, 0)
	nameLabel.Position = UDim2.new(0.5, 0, 0, 182)
	nameLabel.Size = UDim2.new(1, -24, 0, 26)
	nameLabel.TextSize = 20
	nameLabel.Text = ""
	nameLabel.Parent = parent
	UITheme.applyOutlinedTitle(nameLabel)

	local summaryLabel = Instance.new("TextLabel")
	summaryLabel.Name = "Summary"
	summaryLabel.BackgroundTransparency = 1
	summaryLabel.AnchorPoint = Vector2.new(0.5, 0)
	summaryLabel.Position = UDim2.new(0.5, 0, 0, 210)
	summaryLabel.Size = UDim2.new(1, -32, 0, 48)
	summaryLabel.TextSize = 13
	summaryLabel.TextWrapped = true
	summaryLabel.Text = ""
	summaryLabel.Parent = parent
	UITheme.applyOutlinedTitle(summaryLabel, UITheme.TITLE)

	local bodyCard = Instance.new("Frame")
	bodyCard.Name = "BodyCard"
	bodyCard.AnchorPoint = Vector2.new(0.5, 0)
	bodyCard.Position = UDim2.new(0.5, 0, 0, 262)
	bodyCard.Size = UDim2.new(1, -32, 0, 128)
	bodyCard.BackgroundColor3 = Color3.fromRGB(245, 242, 230)
	bodyCard.BorderSizePixel = 0
	bodyCard.Parent = parent
	UITheme.styleCorner(bodyCard, 10)
	UITheme.applyStroke(bodyCard, 2)

	local bodyLabel = Instance.new("TextLabel")
	bodyLabel.Name = "Body"
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	bodyLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
	bodyLabel.Size = UDim2.new(1, -16, 1, -10)
	bodyLabel.TextSize = 13
	bodyLabel.TextWrapped = true
	bodyLabel.Text = ""
	bodyLabel.Parent = bodyCard
	UITheme.applyOutlinedTitle(bodyLabel)
	bodyLabel.TextSize = 13

	local dismiss = Instance.new("TextButton")
	dismiss.Name = "Dismiss"
	dismiss.AnchorPoint = Vector2.new(0.5, 1)
	dismiss.Position = UDim2.new(0.5, 0, 1, -16)
	dismiss.Size = UDim2.fromOffset(160, 40)
	dismiss.TextSize = 16
	dismiss.Text = "Got it!"
	dismiss.Parent = parent
	UITheme.applyButtonLook(dismiss, UITheme.WARNING)
	UITheme.applyOutlinedTitle(dismiss)

	local self = setmetatable({
		frame = parent,
		banner = banner,
		portraitHolder = portraitHolder,
		nameLabel = nameLabel,
		summaryLabel = summaryLabel,
		bodyLabel = bodyLabel,
	}, MechanicIntroPopup) :: MechanicIntroPopupHud

	dismiss.Activated:Connect(function()
		AudioController.play("UiClick")
		self:hide()
	end)

	return self
end

function MechanicIntroPopup.show(self: MechanicIntroPopupHud, mechanicId: string)
	local copy = MechanicInfo.copyFor(mechanicId)
	if not copy then
		return
	end

	if mechanicId == "Grave" then
		mountGravePreview(self.portraitHolder)
	else
		for _, child in self.portraitHolder:GetChildren() do
			child:Destroy()
		end
	end

	self.banner.Text = copy.banner
	self.nameLabel.Text = copy.title
	self.summaryLabel.Text = copy.summary
	self.bodyLabel.Text = copy.body
	self.frame.Visible = true
end

function MechanicIntroPopup.hide(self: MechanicIntroPopupHud)
	self.frame.Visible = false
	if self.onHidden then
		self.onHidden()
	end
end

return MechanicIntroPopup
