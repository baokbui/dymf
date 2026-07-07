--!strict
local SpiderJump = {}

function SpiderJump.shouldSkipBrainrot(_ctx, state, _brainrotInstanceId: string): boolean
	if state.jumped then
		return false
	end
	state.jumped = true
	return true
end

return SpiderJump
