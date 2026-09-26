--!strict
-- One count per chew, even when a multi-lane swing hits several Brainrots
-- in the same call. The flag clears next resume so the following chew counts again.

local function swingCount(state: { [string]: any }, key: string): number
	local openKey = key .. "Open"
	local countKey = key .. "Count"
	if state[openKey] ~= true then
		state[openKey] = true
		local count = state[countKey]
		if type(count) ~= "number" then
			count = 0
		end
		count += 1
		state[countKey] = count
		task.defer(function()
			state[openKey] = false
		end)
	end
	local count = state[countKey]
	return if type(count) == "number" then count else 0
end

return swingCount
