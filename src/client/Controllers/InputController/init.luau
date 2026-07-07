--!strict
--[[
	InputController
	Centralizes raw input (mouse / touch / keyboard) and re-exposes it as
	high-level intent signals, so other controllers don't each re-implement
	input handling. It carries no gameplay logic — it only translates devices
	into "primary action", "secondary action", and the cursor position.

	Signals (each carries the screen position the action occurred at):
		primaryAction     - left click / tap / Enter   (confirm, e.g. place)
		secondaryAction   - right click on the battlefield (remove when not placing)
		placementCancel   - Esc / Backspace (cancel placement selection)

	Right click is not used for placement cancel so it remains free for camera control.

	Inputs already consumed by the GUI (gameProcessed) are ignored, so clicking
	Shop buttons never doubles as a battlefield action.

	Milestone 4.
]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.Utilities.Logger)

local InputController = {}
InputController.Name = "InputController"

local log = Logger.new(InputController.Name)

local primaryBindable = Instance.new("BindableEvent")
local secondaryBindable = Instance.new("BindableEvent")
local cancelBindable = Instance.new("BindableEvent")

-- RBXScriptSignals other controllers connect to. Set in init().
InputController.primaryAction = primaryBindable.Event
InputController.secondaryAction = secondaryBindable.Event
InputController.placementCancel = cancelBindable.Event

local function currentScreenPosition(input: InputObject): Vector2
	-- input.Position is in screen space for mouse/touch; Z is unused here.
	return Vector2.new(input.Position.X, input.Position.Y)
end

local function onInputBegan(input: InputObject, processed: boolean)
	if processed then
		return -- consumed by the GUI (e.g. a Shop button)
	end

	local inputType = input.UserInputType
	local keyCode = input.KeyCode

	if inputType == Enum.UserInputType.MouseButton1
		or inputType == Enum.UserInputType.Touch
		or keyCode == Enum.KeyCode.Return
	then
		primaryBindable:Fire(currentScreenPosition(input))
	elseif inputType == Enum.UserInputType.MouseButton2 then
		secondaryBindable:Fire(currentScreenPosition(input))
	elseif keyCode == Enum.KeyCode.Escape or keyCode == Enum.KeyCode.Backspace then
		cancelBindable:Fire(currentScreenPosition(input))
	end
end

function InputController.init()
end

function InputController.start()
	UserInputService.InputBegan:Connect(onInputBegan)
	log:info("started")
end

return InputController
