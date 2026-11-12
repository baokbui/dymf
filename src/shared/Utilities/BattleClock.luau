--!strict
-- Per-owner simulation time. Never use this for UTC rewards, save leases or request throttles.
local TweenService = game:GetService("TweenService")
local Clock = {}
type Timer = { due: number, callback: () -> (), cancel: (() -> ())?, waiting: boolean }
type State = { offset: number, pausedAt: number?, timers: { [Timer]: boolean }, tweens: { [Tween]: boolean } }
local states: { [number]: State } = {}

local function owner(context: any): number?
	if type(context) == "number" then return context end
	-- Lightweight internal player descriptors are also used by isolated fixtures.
	if type(context) == "table" and type(context.UserId) == "number" then return context.UserId end
	if typeof(context) ~= "Instance" then return nil end
	if context:IsA("Player") then return context.UserId end
	local item: Instance? = context
	while item do
		local id = item:GetAttribute("OwnerUserId")
		if type(id) == "number" then return id end
		item = item.Parent
	end
	return nil
end

local function get(context: any): State?
	local id = owner(context)
	if not id then return nil end
	if not states[id] then states[id] = { offset = 0, timers = {}, tweens = {} } end
	return states[id]
end

function Clock.now(context: any): number
	local state = get(context)
	return if state then (state.pausedAt or os.clock()) - state.offset else os.clock()
end

function Clock.isPaused(context: any): boolean
	local state = get(context)
	return state ~= nil and state.pausedAt ~= nil
end

local function schedule(state: State, timer: Timer)
	local function wake()
		if not state.timers[timer] then return end
		if state.pausedAt then timer.waiting = true; return end
		local remaining = timer.due - (os.clock() - state.offset)
		if remaining > 0 then task.delay(remaining, wake); return end
		state.timers[timer] = nil
		timer.callback()
	end
	task.delay(math.max(0, timer.due - ((state.pausedAt or os.clock()) - state.offset)), wake)
end

function Clock.delay(context: any, seconds: number, callback: () -> (), cancel: (() -> ())?): () -> ()
	local state = get(context)
	if not state then
		local thread = task.delay(seconds, callback)
		return function() task.cancel(thread); if cancel then cancel() end end
	end
	local timer: Timer = { due = Clock.now(context) + seconds, callback = callback, cancel = cancel, waiting = false }
	state.timers[timer] = true
	schedule(state, timer)
	return function()
		if state.timers[timer] then state.timers[timer] = nil; if cancel then cancel() end end
	end
end

function Clock.wait(context: any, seconds: number): boolean
	local event = Instance.new("BindableEvent")
	Clock.delay(context, seconds, function() event:Fire(true) end, function() event:Fire(false) end)
	local completed = event.Event:Wait()
	event:Destroy()
	return completed == true
end

function Clock.tween(context: any, instance: Instance, info: TweenInfo, goals: any): Tween
	local tween = TweenService:Create(instance, info, goals)
	local state = get(context)
	if not state then return tween end
	state.tweens[tween] = false
	local finished, destroyed
	local function cleanup()
		state.tweens[tween] = nil
		if finished then finished:Disconnect() end
		if destroyed then destroyed:Disconnect() end
	end
	finished = tween.Completed:Connect(cleanup)
	destroyed = instance.Destroying:Connect(function() cleanup(); tween:Cancel() end)
	return tween
end

function Clock.setPaused(context: any, paused: boolean)
	local state = get(context)
	if not state or paused == (state.pausedAt ~= nil) then return end
	if paused then
		state.pausedAt = os.clock()
		for tween in state.tweens do
			if tween.PlaybackState == Enum.PlaybackState.Playing then state.tweens[tween] = true; tween:Pause() end
		end
	else
		state.offset += os.clock() - (state.pausedAt :: number)
		state.pausedAt = nil
		for tween, playing in state.tweens do if playing then state.tweens[tween] = false; tween:Play() end end
		for timer in state.timers do if timer.waiting then timer.waiting = false; schedule(state, timer) end end
	end
end

function Clock.clear(context: any)
	local id = owner(context)
	local state = if id then states[id] else nil
	if not state then return end
	for timer in state.timers do state.timers[timer] = nil; if timer.cancel then timer.cancel() end end
	for tween in state.tweens do tween:Cancel() end
	states[id :: number] = nil
end

return Clock
