--!strict
--[[
	Spider jump-over: the FIRST Brainrot this spider reaches is vaulted instead
	of chewed. `shouldSkipBrainrot` is a pure query (does not mutate) — the
	behavior tick starts the arc when the spider is close enough, then marks
	the plant skipped so later ticks walk/fight past it.
]]
local SpiderJump = {}

function SpiderJump.shouldSkipBrainrot(_ctx, state, _brainrotInstanceId: string): boolean
	return state.jumped ~= true
end

return SpiderJump
