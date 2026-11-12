--!strict
-- Deterministic owner isolation, paused deadlines, tweens and cancellation.
return function(source: string): string
	local clock, queue = 0, {}
	local function later(seconds, callback) table.insert(queue, { at = clock + seconds, callback = callback }) end
	local function advance(seconds)
		clock += seconds
		local current = queue; queue = {}
		for _, item in current do if item.at <= clock then item.callback() else table.insert(queue, item) end end
	end
	local chunk = assert(loadstring(source))
	setfenv(chunk, setmetatable({ os = { clock = function() return clock end }, task = { delay = later } }, { __index = getfenv() }))
	local time = chunk()
	local owner, other = 123, 456
	local first, second = 0, 0
	time.delay(owner, 2, function() first += 1 end)
	time.delay(other, 2, function() second += 1 end)
	advance(1)
	local value = Instance.new("NumberValue")
	local tween = time.tween(owner, value, TweenInfo.new(10), { Value = 1 })
	tween:Play()
	time.setPaused(owner, true)
	assert(tween.PlaybackState == Enum.PlaybackState.Paused)
	advance(20)
	assert(time.now(owner) == 1 and time.now(other) == 21)
	assert(first == 0 and second == 1, "Paused windup fired or another owner was paused")
	time.setPaused(owner, false)
	assert(time.now(owner) == 1 and tween.PlaybackState == Enum.PlaybackState.Playing)
	advance(0.5); assert(first == 0)
	advance(0.5); assert(first == 1, "Windup did not keep its remaining duration")
	time.setPaused(owner, true)
	local cancelled = false
	time.delay(owner, 0, function() error("Cancelled attempt ran") end, function() cancelled = true end)
	advance(1)
	time.clear(owner)
	assert(cancelled)
	advance(100)
	time.clear(other); value:Destroy()
	return "Owner clocks, delayed hits, pause/resume tweens and attempt cancellation passed"
end
