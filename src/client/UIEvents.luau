--!strict
--[[
	UIEvents
	Lightweight client-only signals for UI feedback. Avoids circular requires
	between UIController and gameplay controllers.
]]

local UIEvents = {}

local coinDeltaBindable = Instance.new("BindableEvent")
local pendingSpendBindable = Instance.new("BindableEvent")

-- Fired with a positive coin amount collected from the ground.
UIEvents.coinDelta = coinDeltaBindable.Event

-- Fired when the player attempts to place a Brainrot (wait for CoinsUpdated to show -cost).
UIEvents.pendingSpend = pendingSpendBindable.Event

function UIEvents.fireCoinDelta(delta: number)
	if delta ~= 0 then
		coinDeltaBindable:Fire(delta)
	end
end

function UIEvents.markPendingSpend()
	pendingSpendBindable:Fire()
end

return UIEvents
