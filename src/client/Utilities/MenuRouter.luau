--!strict
-- One client menu window; feature modules keep ownership of their existing panels.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Theme = require(Shared.Config.UITheme)
local Audio = require(script.Parent.Parent.Controllers.AudioController)
local MenuTiles = require(script.Parent.MenuTiles)
local MenuDrawer = require(script.Parent.MenuDrawer)
local OutsideDismiss = require(script.Parent.OutsideDismiss)
local UISizing = require(script.Parent.UISizing)
local HudLayout = require(script.Parent.HudLayout)
local MenuRouter = {}
export type PageOptions = { open: () -> (), close: () -> (), detail: Frame?, back: (() -> ())?, gap: number?, selfScrolling: boolean?, fill: Color3? }
local sections = { "Inventory", "Index", "Upgrades", "Settings", "Quests", "Achievements", "Statistics" }
local pages: { [string]: any } = {}
local buttons: { [string]: any } = {}
local active: string? = nil
local resizeWindow: (() -> ())?
local overlay: Frame?
local shell: Frame?
local drawer: any = nil
local sectionIcons: Frame?
local screenScale: UIScale?
local body: Frame?
local viewport: ScrollingFrame?
local back: TextButton?
local badge: TextLabel?
local beforeOpen: (() -> ())?
local transitioning, fitting = false, false

local function text(parent: Instance, value: string, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text, label.TextSize = value, size
	label.Size = UDim2.fromScale(1, 1)
	label.Parent = parent
	Theme.applyOutlinedTitle(label)
	return label
end

local function scale(gui: GuiObject): UIScale
	local value = gui:FindFirstChild("MenuScale") :: UIScale?
	if not value then value = Instance.new("UIScale"); value.Name = "MenuScale"; value.Parent = gui end
	return value
end

local function restoreDetail(page: any)
	local detail = page.detail
	if not detail then return end
	detail.Parent = page.frame
	detail.AnchorPoint, detail.Position = page.detailAnchor, page.detailPosition
	if page.detailSize then detail.Size = page.detailSize end
	local value = detail:FindFirstChild("MenuScale")
	if value then value:Destroy() end
end

local function fit()
	if fitting or not active or not body or not shell then return end
	local page = pages[active]
	if not page then return end
	fitting = true
	local area = viewport.AbsoluteSize / (if screenScale then screenScale.Scale else 1) - Vector2.new(12, 0)
	local detail = page.detail
	local showing = detail and detail.Visible
	local extra = if showing then detail.Size.X.Offset + page.gap else 0
	local narrow = showing and area.X < page.frame.Size.X.Offset + extra + 16
	back.Visible = narrow == true
	local width = page.frame.Size.X.Offset + (if narrow then 0 else extra)
	local height = math.max(page.size.Y.Offset, if showing and not narrow then detail.Size.Y.Offset else 0)
	local zoom = math.clamp((area.X - 12) / math.max(1, width), 0.1, 1)
	scale(page.frame).Scale = zoom
	if page.selfScrolling then
		page.frame.Size = UDim2.fromOffset(page.size.X.Offset, math.min(page.size.Y.Offset, math.max(180, area.Y / zoom)))
		height = page.frame.Size.Y.Offset
	end
	page.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	page.frame.Position = UDim2.new(0.5, if narrow then 0 else -extra * zoom / 2, 0.5, 0)
	if narrow then
		detail.Parent = body
		detail.AnchorPoint, detail.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
		local detailZoom = math.clamp((area.X - 12) / detail.Size.X.Offset, 0.1, 1)
		scale(detail).Scale = detailZoom
		if page.selfScrolling and detail:FindFirstChildWhichIsA("ScrollingFrame", true) then
			detail.Size = UDim2.fromOffset(page.detailSize.X.Offset, math.min(page.detailSize.Y.Offset, area.Y / detailZoom))
		end
		height = detail.Size.Y.Offset * detailZoom
	elseif detail then
		restoreDetail(page)
		if page.selfScrolling and showing and detail:FindFirstChildWhichIsA("ScrollingFrame", true) then
			detail.Size = UDim2.fromOffset(page.detailSize.X.Offset, math.min(page.detailSize.Y.Offset, area.Y / zoom))
		end
	end
	if not narrow then
		if page.selfScrolling and showing then height = math.max(page.frame.Size.Y.Offset, detail.Size.Y.Offset) end
		height *= zoom
	end
	local ownScroll = page.selfScrolling and height <= area.Y + 1
	if page.selfScrolling then
		viewport.ScrollingEnabled = not ownScroll
		viewport.ScrollBarThickness = if ownScroll then 0 else 5
		viewport.AutomaticCanvasSize = if ownScroll then Enum.AutomaticSize.None else Enum.AutomaticSize.Y
	end
	-- Do not turn a fitting page into overflow just to add bottom padding.
	local canvasHeight = if ownScroll or height <= area.Y + 1 then area.Y else height + 12
	body.Size = UDim2.new(1, -12, 0, canvasHeight)
	fitting = false
end

local function closePage()
	local page = if active then pages[active] else nil
	active = nil
	if overlay then overlay.Visible = false end
	if page then page.close(); restoreDetail(page); page.frame.Visible = false end
	if back then back.Visible = false end
end

function MenuRouter.close()
	closePage()
	if drawer then drawer.setOpen(false) end
end

function MenuRouter.open(id: string)
	local page = pages[id]
	if not page or not overlay or not body then return end
	transitioning = true
	closePage()
	if beforeOpen then beforeOpen() end
	page.frame.Parent = body
	page.frame.Size = page.size
	for button in page.closes do button.Visible = false end
	active = id
	-- The host is the feature's only panel surface while it is in Menu.
	shell.BackgroundColor3 = page.fill
	page.frame.BackgroundTransparency = 1
	if page.stroke then page.stroke.Enabled = false end
	viewport.Visible = true
	viewport.ScrollingEnabled = not page.selfScrolling
	viewport.ScrollBarThickness = if page.selfScrolling then 0 else 5
	viewport.AutomaticCanvasSize = if page.selfScrolling then Enum.AutomaticSize.None else Enum.AutomaticSize.Y
	viewport.CanvasSize = UDim2.new()
	if drawer and not drawer.isOpen() then drawer.setOpen(true) end
	if resizeWindow then resizeWindow() end
	overlay.Visible = true
	page.open()
	page.frame.Visible = true
	viewport.CanvasPosition = Vector2.zero
	for _, item in buttons do Theme.applyOutlinedTitle(item.caption, Theme.TITLE) end
	transitioning = false
	fit()
end

-- Close the Menu and its peer inspectors/store before a standalone panel opens.
function MenuRouter.prepareStandalone()
	MenuRouter.close()
	if beforeOpen then beforeOpen() end
end

-- The HUD entry opens navigation beside itself, without the feature window.
function MenuRouter.home()
	if not drawer then return end
	MenuRouter.close()
	if beforeOpen then beforeOpen() end
	drawer.setOpen(true)
end

function MenuRouter.configure(main: ScreenGui, onOpen: (() -> ())?)
	if onOpen then beforeOpen = onOpen end
	if overlay then return end
	local layer = Instance.new("Frame")
	layer.Name = "Menu"
	layer.Size = UDim2.fromScale(1, 1)
	layer.BackgroundTransparency = 1
	layer.Visible = false
	layer.ZIndex = 19 -- day results/intros stay above the optional Menu
	layer.Parent = main
	overlay = layer
	local window = Instance.new("Frame")
	window.Name = "Window"
	window.Active = true
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.ZIndex = 25
	window.Parent = layer
	Theme.applyPanelLook(window)
	shell = window
	screenScale = Instance.new("UIScale")
	screenScale.Name, screenScale.Parent = "DesktopScale", window
	OutsideDismiss.mount(layer, window, MenuRouter.close)
	local close = Instance.new("TextButton")
	close.Name, close.Text, close.TextSize = "Close", "X", 21
	close.Position, close.Size = UDim2.new(1, -48, 0, 12), UDim2.fromOffset(34, 34)
	close.Parent = window
	Theme.applyButtonLook(close, Theme.DANGER)
	Theme.applyOutlinedTitle(close)
	close.Activated:Connect(MenuRouter.close)
	back = Instance.new("TextButton")
	back.Name, back.Text, back.TextSize = "Back", "‹ Back", 15
	back.Position, back.Size = UDim2.new(1, -158, 0, 12), UDim2.fromOffset(100, 34)
	back.Visible = false
	back.Parent = window
	Theme.applyButtonLook(back)
	Theme.applyOutlinedTitle(back)
	back.Activated:Connect(function()
		local page = if active then pages[active] else nil
		if page and page.back then page.back(); viewport.CanvasPosition = Vector2.zero end
	end)
	buttons, sectionIcons = MenuTiles.build(window, sections, function(name: string)
		Audio.play("UiClick"); MenuRouter.open(name)
	end)
	viewport = Instance.new("ScrollingFrame")
	viewport.Name = "Content"
	viewport.Position, viewport.Size = UDim2.fromOffset(16, 60), UDim2.new(1, -32, 1, -76)
	viewport.BackgroundTransparency, viewport.BorderSizePixel = 1, 0
	viewport.ScrollingDirection, viewport.AutomaticCanvasSize = Enum.ScrollingDirection.Y, Enum.AutomaticSize.Y
	viewport.CanvasSize, viewport.ScrollBarThickness = UDim2.new(), 5
	viewport.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	viewport.Parent = window
	body = Instance.new("Frame")
	body.Name = "Pages"
	body.Position = UDim2.fromOffset(6, 0)
	body.Size = UDim2.new(1, -12, 1, 0)
	body.BackgroundTransparency, body.ClipsDescendants = 1, true
	body.Parent = viewport
	local function resize()
		local width, height = 640, 640
		local origin, bounds = HudLayout.bounds(main)
		local page = if active then pages[active] else nil
		local desiredHeight = if page then page.size.Y.Offset + 76 else height
		screenScale.Scale = math.min(UISizing.desktop(main.AbsoluteSize), math.max(1, bounds.Y / desiredHeight))
		local available = bounds / screenScale.Scale
		if page then
			local detail = page.detail
			local extra = if detail and detail.Visible then detail.Size.X.Offset + page.gap else 0
			width = page.size.X.Offset + 64
			-- Keep details beside the feature only when both fit at readable size.
			if width + extra <= available.X - 24 then width += extra end
			height = math.max(page.size.Y.Offset, if extra > 0 then detail.Size.Y.Offset else 0) + 76
		end
		window.Size = UDim2.fromOffset(math.max(1, math.min(width, available.X)), math.max(1, math.min(height, available.Y)))
		window.Position = UDim2.fromOffset(origin.X + bounds.X / 2, origin.Y + bounds.Y / 2)
		fit()
	end
	resizeWindow = resize
	HudLayout.watch(main, window, resize)
	viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	resize()
	local entry = Instance.new("TextButton")
	entry.Name, entry.Text = "MenuEntry", ""
	entry.AnchorPoint, entry.Position, entry.Size = Vector2.new(0, 1), UDim2.new(0, 16, 1, -16), UDim2.fromOffset(96, 94)
	entry.BackgroundTransparency, entry.BorderSizePixel, entry.ZIndex = 1, 0, 40
	entry.Parent = main
	local bars: { Frame } = {}
	for index = 0, 2 do
		local bar = Instance.new("Frame")
		bar.Name = "MenuBar" .. (index + 1)
		bar.BackgroundColor3, bar.BorderSizePixel = Theme.TITLE, 0
		bar.Position, bar.Size = UDim2.fromOffset(22, 12 + index * 17), UDim2.fromOffset(52, 7)
		bar.Parent = entry
		table.insert(bars, bar)
		Theme.styleCorner(bar, 3)
		Theme.applyStroke(bar, 2)
	end
	local caption = text(entry, "Menu", 14)
	caption.Name = "Caption"
	caption.Position, caption.Size = UDim2.fromOffset(0, 72), UDim2.fromOffset(96, 22)
	badge = text(entry, "!", 15)
	badge.Name = "AvailableRewards"
	badge.Visible, badge.Position, badge.Size = false, UDim2.fromOffset(70, 0), UDim2.fromOffset(22, 22)
	badge.BackgroundTransparency, badge.BackgroundColor3 = 0, Theme.DANGER
	Theme.styleCorner(badge, 11)
	drawer = MenuDrawer.new(main, entry, sectionIcons :: Frame, bars, caption)
	entry.Activated:Connect(function() Audio.play("UiClick"); if drawer.isOpen() then MenuRouter.close() else MenuRouter.home() end end)
end

function MenuRouter.register(id: string, frame: Frame, callbacks: PageOptions)
	if not overlay then MenuRouter.configure(Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("MainUI") :: ScreenGui) end
	assert(buttons[id] and not pages[id], "Invalid or duplicate menu section: " .. id)
	local page = { frame = frame, open = callbacks.open, close = callbacks.close, detail = callbacks.detail,
		back = callbacks.back, gap = callbacks.gap or 14, parent = frame.Parent, anchor = frame.AnchorPoint, position = frame.Position, closes = {},
		selfScrolling = callbacks.selfScrolling, size = frame.Size,
		fill = callbacks.fill or frame.BackgroundColor3, transparency = frame.BackgroundTransparency, stroke = frame:FindFirstChildOfClass("UIStroke") }
	page.strokeEnabled = if page.stroke then page.stroke.Enabled else false
	if page.detail then page.detailAnchor, page.detailPosition, page.detailSize = page.detail.AnchorPoint, page.detail.Position, page.detail.Size end
	for _, child in frame:GetChildren() do
		if child:IsA("TextButton") and child.Text == "X" then page.closes[child] = child.Visible; child.Visible = false end
	end
	pages[id] = page
	frame.Visible, frame.Parent = false, body
	buttons[id].button.Active = true
	frame:GetPropertyChangedSignal("Position"):Connect(function() if active == id then fit() end end)
	frame:GetPropertyChangedSignal("Visible"):Connect(function() if active == id and not frame.Visible and not transitioning then MenuRouter.close() end end)
	if page.detail then
		page.detail:GetPropertyChangedSignal("Visible"):Connect(function()
			if active ~= id then return end
			if resizeWindow then resizeWindow() else fit() end
		end)
	end
end

-- The physical Brainrot stall reuses ProgressionStore outside the Menu.
function MenuRouter.detach(id: string)
	local page = pages[id]
	if not page then return end
	if active == id then MenuRouter.close() end
	restoreDetail(page)
	page.frame.BackgroundTransparency = page.transparency
	page.frame.Size = page.size
	if page.stroke then page.stroke.Enabled = page.strokeEnabled end
	page.frame.Parent, page.frame.AnchorPoint, page.frame.Position = page.parent, page.anchor, page.position
	local value = page.frame:FindFirstChild("MenuScale")
	if value then value:Destroy() end
	for button, visible in page.closes do button.Visible = visible end
end

function MenuRouter.setBadge(id: string, amount: number)
	local item = buttons[id]
	if not item then return end
	item.count, item.badge.Visible = amount, amount > 0
	item.badge.Text = if amount > 1 then tostring(amount) else "!"
	local total = 0
	for _, section in buttons do total += section.count end
	if badge then badge.Visible = total > 0; badge.Text = if total > 9 then "9+" else tostring(total) end
end

return MenuRouter
