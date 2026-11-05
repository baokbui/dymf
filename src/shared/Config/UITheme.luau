--!strict
--[[
	UITheme
	Shared cartoon / thick-outline visual tokens for HUD panels.
	Look only — layout and structure stay in each panel module.
]]

local UITheme = {}

-- Fills (saturated sticker colors — avoid flat white)
-- Blue remains the default for generic panels and chips.
UITheme.PANEL_BG = Color3.fromRGB(90, 175, 255)
UITheme.PANEL_BG_ALT = Color3.fromRGB(70, 155, 240)
UITheme.CHIP_BG = Color3.fromRGB(90, 175, 255)
UITheme.CARD_BG = Color3.fromRGB(255, 225, 90)
UITheme.CARD_SELECTED_BG = Color3.fromRGB(120, 255, 170)
UITheme.CARD_CLAIMED_BG = Color3.fromRGB(175, 180, 185)
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
UITheme.CHIP_BG_MAGNET = Color3.fromRGB(235, 75, 85) -- magnet red
UITheme.PANEL_BG_QUESTS = Color3.fromRGB(255, 145, 125) -- coral; distinct from teal Upgrades
UITheme.PANEL_BG_ACHIEVEMENTS = Color3.fromRGB(185, 150, 245) -- lavender
UITheme.PANEL_BG_INVENTORY = Color3.fromRGB(110, 220, 150) -- leafy green
UITheme.PANEL_BG_SETTINGS = Color3.fromRGB(34, 39, 55)
UITheme.SETTINGS_ROW = Color3.fromRGB(45, 51, 69)
UITheme.SETTINGS_TILE = Color3.fromRGB(63, 71, 94)
UITheme.SETTINGS_ACCENT = Color3.fromRGB(255, 177, 93)
UITheme.PANEL_BG_REWARD = Color3.fromRGB(255, 205, 70) -- gold
UITheme.PANEL_BG_UNLOCK = Color3.fromRGB(200, 130, 255) -- purple
UITheme.PANEL_BG_STORE = Color3.fromRGB(50, 195, 175) -- teal
UITheme.PANEL_BG_INDEX = Color3.fromRGB(95, 110, 185) -- indigo catalog
UITheme.PANEL_BG_MONSTER_INTRO = Color3.fromRGB(255, 140, 90) -- fiery orange
UITheme.PANEL_BG_MECHANIC_INTRO = Color3.fromRGB(130, 145, 110) -- mossy stone
UITheme.PANEL_BG_GAME_OVER = Color3.fromRGB(45, 28, 40) -- dark defeat card

-- Feature-specific surfaces and accents.
UITheme.INVENTORY_PACKET = Color3.fromRGB(241, 249, 211)
UITheme.INVENTORY_INSET = Color3.fromRGB(196, 229, 183)
UITheme.INVENTORY_INK = Color3.fromRGB(35, 85, 58)
UITheme.INDEX_DISCOVERED = Color3.fromRGB(235, 235, 255)
UITheme.INDEX_UNKNOWN = Color3.fromRGB(188, 193, 227)
UITheme.INDEX_INSET = Color3.fromRGB(124, 132, 192)
UITheme.QUEST_PAPER = Color3.fromRGB(255, 238, 214)
UITheme.QUEST_INK = Color3.fromRGB(122, 58, 47)
UITheme.ACHIEVEMENT_PAPER = Color3.fromRGB(248, 240, 255)
UITheme.ACHIEVEMENT_INK = Color3.fromRGB(84, 55, 131)
UITheme.PANEL_BG_STATISTICS = Color3.fromRGB(147, 213, 232)
UITheme.STATISTICS_INK = Color3.fromRGB(27, 81, 104)
UITheme.STATISTICS_CARD = Color3.fromRGB(230, 248, 255)

-- Field HUD surfaces, paired with bright action and status colors.
UITheme.FIELD_PLANTING = Color3.fromRGB(37, 72, 56)
UITheme.FIELD_DAY = Color3.fromRGB(34, 69, 99)
UITheme.FIELD_PANEL = Color3.fromRGB(30, 44, 53)
UITheme.FIELD_INSET = Color3.fromRGB(49, 67, 78)
UITheme.FIELD_TEXT = Color3.fromRGB(214, 229, 235)
UITheme.FIELD_ACCENT = Color3.fromRGB(150, 234, 165)
UITheme.UPGRADE_PANEL = Color3.fromRGB(22, 33, 46)
UITheme.UPGRADE_SPEED = Color3.fromRGB(108, 220, 255)
UITheme.UPGRADE_MAGNET = Color3.fromRGB(255, 141, 152)
UITheme.SPEED_ICON = "rbxassetid://82103513055414"
UITheme.MAGNET_ICON = "rbxassetid://73519143112132"
UITheme.COIN_PILL = Color3.fromRGB(57, 44, 29)

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

-- Viewport readability reference for proportional desktop enlargement.
UITheme.DESKTOP_REFERENCE = Vector2.new(1536, 864)

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

-- A neutral gradient keeps the existing feature and state colors intact.
function UITheme.applySurfaceDepth(gui: GuiObject)
	local gradient = Instance.new("UIGradient")
	gradient.Name, gradient.Rotation = "SurfaceDepth", 90
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.78, 0.81, 0.88))
	gradient.Parent = gui
end

table.freeze(UITheme)

return UITheme
