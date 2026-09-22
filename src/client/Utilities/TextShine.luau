--!strict
--[[
	TextShine
	Gleam on UI: evolution rarity titles (left↔right) and inspect-card
	backgrounds (top-left → bottom-right). One Heartbeat drives every
	active gradient so nameplates and inspect cards share it.

	High Quality VFX Off skips that Heartbeat. Colors stay; the gleam does not
	move. GOD keeps a static rainbow gradient.
]]

local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EvolutionConfig = require(ReplicatedStorage.Shared.Config.EvolutionConfig)
local VfxLoad = require(ReplicatedStorage.Shared.Utilities.VfxLoad)

local TextShine = {}

local TITLE_PERIOD = 2.0
local PANEL_SWEEP = 0.55 -- seconds for the slash to cross the card
local PANEL_REST = 3.0 -- seconds with no gleam between passes
local PANEL_HIDDEN = Vector2.new(1.25, 0) -- gleam parked off the bottom-right
local PANEL_ROTATION = 45 -- degrees; 0 is left→right, 45 is top-left→bottom-right
local GRADIENT_NAME = "ShineGradient"

type ShineKind = "title" | "panel" | "rainbow" | "rainbowPanel"

type ShineEntry = {
	gui: GuiObject,
	kind: ShineKind,
	color: Color3,
}

local titleActive: { [UIGradient]: boolean } = {}
local panelActive: { [UIGradient]: boolean } = {}
local tracked: { [GuiObject]: ShineEntry } = {}
local heartbeatStarted = false

local function pingPong(period: number): number
	local cycle = (os.clock() / period) % 2
	return 1 - math.abs(cycle - 1)
end

local function panelOffset(): Vector2
	local cycle = PANEL_SWEEP + PANEL_REST
	local t = os.clock() % cycle
	if t >= PANEL_SWEEP then
		return PANEL_HIDDEN
	end
	return Vector2.new(-1 + 2 * (t / PANEL_SWEEP), 0)
end

local function ensureHeartbeat()
	if heartbeatStarted then
		return
	end
	heartbeatStarted = true
	RunService.Heartbeat:Connect(function()
		if next(titleActive) then
			local offset = Vector2.new(-1 + 2 * pingPong(TITLE_PERIOD), 0)
			for gradient in pairs(titleActive) do
				if not gradient.Parent then
					titleActive[gradient] = nil
					continue
				end
				gradient.Offset = offset
			end
		end
		if next(panelActive) then
			-- Quick TL → BR slash, then 3s of solid rarity color.
			local offset = panelOffset()
			for gradient in pairs(panelActive) do
				if not gradient.Parent then
					panelActive[gradient] = nil
					continue
				end
				gradient.Offset = offset
			end
		end
	end)
end

local function findShine(gui: GuiObject): UIGradient?
	local existing = gui:FindFirstChild(GRADIENT_NAME)
	if existing and existing:IsA("UIGradient") then
		return existing
	end
	return gui:FindFirstChildOfClass("UIGradient")
end

local function detachGradient(gui: GuiObject)
	local existing = findShine(gui)
	if not existing then
		return
	end
	titleActive[existing] = nil
	panelActive[existing] = nil
	existing:Destroy()
end

function TextShine.clear(gui: GuiObject)
	tracked[gui] = nil
	detachGradient(gui)
end

local function makeTitleSequence(dark: Color3): ColorSequence
	local gleam = dark:Lerp(Color3.fromRGB(255, 255, 255), 0.82)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, dark),
		ColorSequenceKeypoint.new(0.18, dark),
		ColorSequenceKeypoint.new(0.34, gleam),
		ColorSequenceKeypoint.new(0.50, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.66, gleam),
		ColorSequenceKeypoint.new(0.82, dark),
		ColorSequenceKeypoint.new(1, dark),
	})
end

-- Narrow slash (a bit wider than a hairline so it still reads at 45°).
local function makePanelSequence(dark: Color3): ColorSequence
	local gleam = dark:Lerp(Color3.fromRGB(255, 255, 255), 0.7)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, dark),
		ColorSequenceKeypoint.new(0.40, dark),
		ColorSequenceKeypoint.new(0.46, gleam),
		ColorSequenceKeypoint.new(0.50, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.54, gleam),
		ColorSequenceKeypoint.new(0.60, dark),
		ColorSequenceKeypoint.new(1, dark),
	})
end

local function paint(entry: ShineEntry)
	local gui = entry.gui
	detachGradient(gui)
	local animated = VfxLoad.isHighQuality()
	if entry.kind == "panel" then
		if not animated then
			gui.BackgroundColor3 = entry.color
			return
		end
		gui.BackgroundColor3 = Color3.new(1, 1, 1)
		local gradient = Instance.new("UIGradient")
		gradient.Name = GRADIENT_NAME
		gradient.Color = makePanelSequence(entry.color)
		gradient.Rotation = PANEL_ROTATION
		gradient.Offset = PANEL_HIDDEN
		gradient.Parent = gui
		panelActive[gradient] = true
		ensureHeartbeat()
		return
	end
	if entry.kind == "rainbowPanel" then
		gui.BackgroundColor3 = Color3.new(1, 1, 1)
		local gradient = Instance.new("UIGradient")
		gradient.Name = GRADIENT_NAME
		gradient.Color = EvolutionConfig.rainbowFillSequence()
		gradient.Rotation = 18
		gradient.Offset = Vector2.new(-1, 0)
		gradient.Parent = gui
		if animated then
			titleActive[gradient] = true
			ensureHeartbeat()
		end
		return
	end
	if not gui:IsA("TextLabel") then
		return
	end
	gui.TextColor3 = Color3.new(1, 1, 1)
	if entry.kind == "title" and not animated then
		gui.TextColor3 = entry.color
		return
	end
	local gradient = Instance.new("UIGradient")
	gradient.Name = GRADIENT_NAME
	gradient.Rotation = if entry.kind == "rainbow" then 0 else 12
	gradient.Offset = Vector2.new(-1, 0)
	gradient.Color = if entry.kind == "rainbow"
		then EvolutionConfig.rainbowSequence()
		else makeTitleSequence(entry.color)
	gradient.Parent = gui
	if animated then
		titleActive[gradient] = true
		ensureHeartbeat()
	end
end

local function remember(gui: GuiObject, kind: ShineKind, color: Color3)
	local entry: ShineEntry = {
		gui = gui,
		kind = kind,
		color = color,
	}
	tracked[gui] = entry
	paint(entry)
end

function TextShine.apply(label: TextLabel, dark: Color3)
	remember(label, "title", dark)
end

function TextShine.applyPanel(gui: GuiObject, dark: Color3)
	remember(gui, "panel", dark)
end

-- GOD: scrolling rainbow (same Heartbeat as title gleam). Off = static rainbow.
function TextShine.applyRainbow(label: TextLabel)
	remember(label, "rainbow", Color3.new(1, 1, 1))
end

function TextShine.applyRainbowPanel(gui: GuiObject)
	remember(gui, "rainbowPanel", Color3.new(1, 1, 1))
end

VfxLoad.onHighQualityChanged(function()
	local dead: { GuiObject } = {}
	for gui, entry in tracked do
		if gui.Parent then
			paint(entry)
		else
			table.insert(dead, gui)
		end
	end
	for _, gui in dead do
		tracked[gui] = nil
	end
end)

return TextShine
