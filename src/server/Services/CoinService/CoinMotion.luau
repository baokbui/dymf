--!strict
--[[
	CoinMotion
	Server-replicated drop animations for ground coins (rain from sky, spit arc
	from a producer). Collection is gated until Landed = true.
]]

local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)

local CoinMotion = {}

local function flatCFrame(position: Vector3): CFrame
	return CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
end

local function nextMotion(part: BasePart): number
	local generation = (part:GetAttribute("MotionGen") :: number? or 0) + 1
	part:SetAttribute("MotionGen", generation)
	return generation
end

local function motionCurrent(part: BasePart, generation: number): boolean
	return part.Parent ~= nil and part:GetAttribute("MotionGen") == generation
end

local function markLanded(part: BasePart)
	part.CanTouch = true
	part:SetAttribute("Landed", true)
end

local function tweenAlpha(duration: number, easing: Enum.EasingStyle, direction: Enum.EasingDirection, onStep: (t: number) -> (), onDone: (() -> ())?)
	local alpha = Instance.new("NumberValue")
	alpha.Value = 0
	local conn: RBXScriptConnection
	conn = alpha.Changed:Connect(function(value)
		onStep(value)
	end)

	local tween = TweenService:Create(
		alpha,
		TweenInfo.new(duration, easing, direction),
		{ Value = 1 }
	)
	tween.Completed:Connect(function()
		conn:Disconnect()
		alpha:Destroy()
		onStep(1)
		if onDone then
			onDone()
		end
	end)
	tween:Play()
end

--[[
	Slow vertical rain onto `landPosition` (already includes coin Y offset).
]]
function CoinMotion.rainFromSky(part: BasePart, landPosition: Vector3)
	local drift = EconomyConfig.PASSIVE_RAIN_DRIFT
	local start = landPosition
		+ Vector3.new(
			(math.random() * 2 - 1) * drift,
			EconomyConfig.PASSIVE_RAIN_HEIGHT,
			(math.random() * 2 - 1) * drift
		)

	part.CanTouch = false
	part:SetAttribute("Landed", false)
	part.CFrame = flatCFrame(start)
	local generation = nextMotion(part)

	tweenAlpha(
		EconomyConfig.PASSIVE_RAIN_DURATION,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In,
		function(t)
			if not motionCurrent(part, generation) then
				return
			end
			part.CFrame = flatCFrame(start:Lerp(landPosition, t))
		end,
		function()
			if motionCurrent(part, generation) then
				part.CFrame = flatCFrame(landPosition)
				markLanded(part)
			end
		end
	)
end

--[[
	Spit arc from `fromPosition` (e.g. Ballerina) to `landPosition`.
]]
function CoinMotion.spitFromOrigin(part: BasePart, fromPosition: Vector3, landPosition: Vector3)
	part.CanTouch = false
	part:SetAttribute("Landed", false)
	part.CFrame = flatCFrame(fromPosition)
	local generation = nextMotion(part)

	local arc = EconomyConfig.PRODUCER_SPIT_ARC_HEIGHT
	tweenAlpha(
		EconomyConfig.PRODUCER_SPIT_DURATION,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		function(t)
			if not motionCurrent(part, generation) then
				return
			end
			local flat = fromPosition:Lerp(landPosition, t)
			local loft = arc * 4 * t * (1 - t)
			part.CFrame = flatCFrame(flat + Vector3.new(0, loft, 0))
		end,
		function()
			if motionCurrent(part, generation) then
				part.CFrame = flatCFrame(landPosition)
				markLanded(part)
			end
		end
	)
end

--[[
	Pull a coin (landed or still in the air) toward a moving target.
	Cancels an in-flight rain or spit so those tweens stop writing CFrame.
]]
function CoinMotion.pullToward(part: BasePart, getTarget: () -> Vector3?, duration: number, onDone: () -> ())
	part.CanTouch = false
	local generation = nextMotion(part)
	local start = part.Position
	tweenAlpha(
		duration,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out,
		function(t)
			if not motionCurrent(part, generation) then
				return
			end
			local target = getTarget()
			if not target then
				return
			end
			part.CFrame = flatCFrame(start:Lerp(target, t))
		end,
		function()
			if motionCurrent(part, generation) and onDone then
				onDone()
			end
		end
	)
end

return CoinMotion
