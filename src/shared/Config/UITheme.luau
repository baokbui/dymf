--!strict
--[[
	UITheme
	Shared cartoon / thick-outline visual tokens for HUD panels.
	Look only — layout and structure stay in each panel module.
]]

local UITheme = {}

-- Fills (saturated sticker colors — avoid flat white)
-- PANEL_BG / CHIP_BG stay light blue: the Day/Start Day panel's look is the
-- reference "house style" every other panel's stroke/corner geometry matches.
UITheme.PANEL_BG = Color3.fromRGB(90, 175, 255)
UITheme.PANEL_BG_ALT = Color3.fromRGB(70, 155, 240)
UITheme.CHIP_BG = Color3.fromRGB(90, 175, 255)
UITheme.CARD_BG = Color3.fromRGB(255, 225, 90)
UITheme.CARD_SELECTED_BG = Color3.fromRGB(120, 255, 170)
UITheme.ROW_BG = Color3.fromRGB(255, 170, 210)
UITheme.BUTTON_BG = Color3.fromRGB(160, 210, 255)
UITheme.MODAL_SCRIM = Color3.fromRGB(20, 24, 40)

-- Per-panel accent fills — same cartoon stroke/corner geometry as PANEL_BG /
-- CHIP_BG, just a different saturated sticker color so each HUD piece reads
-- as its own colorful "candy" rather than one wall of blue.
UITheme.CHIP_BG_COINS = Color3.fromRGB(255, 200, 60) -- gold
UITheme.CHIP_BG_BRAINS = Color3.fromRGB(180, 120, 255) -- purple
UITheme.CHIP_BG_SPEED = Color3.fromRGB(70, 205, 220) -- cyan
UITheme.CHIP_BG_HEARTS = Color3.fromRGB(255, 120, 150) -- rosy red
UITheme.CHIP_BG_INVENTORY_BUTTON = Color3.fromRGB(90, 210, 140) -- leafy green
UITheme.CHIP_BG_SETTINGS_BUTTON = Color3.fromRGB(255, 150, 70) -- orange
UITheme.PANEL_BG_INVENTORY = Color3.fromRGB(110, 220, 150) -- leafy green
UITheme.PANEL_BG_SETTINGS = Color3.fromRGB(255, 165, 80) -- orange
UITheme.PANEL_BG_REWARD = Color3.fromRGB(255, 205, 70) -- gold
UITheme.PANEL_BG_UNLOCK = Color3.fromRGB(200, 130, 255) -- purple
UITheme.PANEL_BG_STORE = Color3.fromRGB(50, 195, 175) -- teal
UITheme.PANEL_BG_MONSTER_INTRO = Color3.fromRGB(255, 140, 90) -- fiery orange
UITheme.PANEL_BG_GAME_OVER = Color3.fromRGB(45, 28, 40) -- dark defeat card

-- Accents
UITheme.OUTLINE = Color3.fromRGB(15, 15, 20)
UITheme.TITLE = Color3.fromRGB(255, 255, 255)
UITheme.BODY = Color3.fromRGB(30, 32, 40)
UITheme.SUBTEXT = Color3.fromRGB(55, 60, 75)
UITheme.ACCENT = Color3.fromRGB(70, 160, 255)
UITheme.SUCCESS = Color3.fromRGB(90, 210, 90)
UITheme.SUCCESS_DARK = Color3.fromRGB(40, 120, 50)
UITheme.DANGER = Color3.fromRGB(230, 70, 70)
UITheme.DANGER_DARK = Color3.fromRGB(140, 30, 30)
UITheme.WARNING = Color3.fromRGB(255, 170, 50)
UITheme.GOLD = Color3.fromRGB(255, 210, 40)
UITheme.GOLD_TEXT = Color3.fromRGB(255, 230, 80)
UITheme.HEART_FILLED = Color3.fromRGB(235, 55, 80)
UITheme.HEART_EMPTY = Color3.fromRGB(160, 150, 160)
UITheme.BRAIN = Color3.fromRGB(170, 120, 255)
UITheme.SHOVEL = Color3.fromRGB(140, 200, 90)
UITheme.CANCEL = Color3.fromRGB(230, 70, 70)
UITheme.TOAST_BG = Color3.fromRGB(255, 150, 150)
UITheme.TOAST_TEXT = Color3.fromRGB(90, 20, 20)

-- Geometry
UITheme.CORNER_PANEL = 14
UITheme.CORNER_CARD = 10
UITheme.CORNER_CHIP = 12
UITheme.CORNER_BUTTON = 10
UITheme.STROKE_PANEL = 4
UITheme.STROKE_CARD = 3
UITheme.STROKE_CHIP = 3
UITheme.STROKE_BUTTON = 3
UITheme.TEXT_STROKE_TRANSPARENCY = 0

function UITheme.styleCorner(instance: Instance, radius: number)
	local existing = instance:FindFirstChildOfClass("UICorner")
	if existing then
		existing.CornerRadius = UDim.new(0, radius)
		return
	end
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

function UITheme.applyStroke(gui: GuiObject, thickness: number?, color: Color3?): UIStroke
	local stroke = gui:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Parent = gui
	end
	stroke.Color = color or UITheme.OUTLINE
	stroke.Thickness = thickness or UITheme.STROKE_PANEL
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Transparency = 0
	return stroke
end

function UITheme.applyPanelLook(gui: GuiObject, cornerRadius: number?, fill: Color3?)
	gui.BackgroundColor3 = fill or UITheme.PANEL_BG
	gui.BackgroundTransparency = 0
	gui.BorderSizePixel = 0
	UITheme.styleCorner(gui, cornerRadius or UITheme.CORNER_PANEL)
	UITheme.applyStroke(gui, UITheme.STROKE_PANEL)
end

function UITheme.applyChipLook(gui: GuiObject, fill: Color3?)
	gui.BackgroundColor3 = fill or UITheme.CHIP_BG
	gui.BackgroundTransparency = 0
	gui.BorderSizePixel = 0
	UITheme.styleCorner(gui, UITheme.CORNER_CHIP)
	UITheme.applyStroke(gui, UITheme.STROKE_CHIP)
end

function UITheme.applyCardLook(gui: GuiObject, selected: boolean?)
	gui.BackgroundColor3 = if selected then UITheme.CARD_SELECTED_BG else UITheme.CARD_BG
	gui.BackgroundTransparency = 0
	gui.BorderSizePixel = 0
	UITheme.styleCorner(gui, UITheme.CORNER_CARD)
	UITheme.applyStroke(gui, if selected then UITheme.STROKE_PANEL else UITheme.STROKE_CARD)
end

function UITheme.applyButtonLook(gui: GuiObject, fill: Color3?, cornerRadius: number?)
	gui.BackgroundColor3 = fill or UITheme.BUTTON_BG
	gui.BackgroundTransparency = 0
	gui.BorderSizePixel = 0
	UITheme.styleCorner(gui, cornerRadius or UITheme.CORNER_BUTTON)
	UITheme.applyStroke(gui, UITheme.STROKE_BUTTON)
end

function UITheme.applyOutlinedTitle(label: TextLabel | TextButton, color: Color3?)
	label.TextColor3 = color or UITheme.TITLE
	label.TextStrokeColor3 = UITheme.OUTLINE
	label.TextStrokeTransparency = UITheme.TEXT_STROKE_TRANSPARENCY
	label.Font = Enum.Font.GothamBold
end

function UITheme.applyBodyText(label: TextLabel | TextButton, color: Color3?)
	label.TextColor3 = color or UITheme.BODY
	label.TextStrokeTransparency = 1
	label.Font = Enum.Font.Gotham
end

table.freeze(UITheme)

return UITheme
