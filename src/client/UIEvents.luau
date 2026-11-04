--!strict
--[[
	UIEvents
	Lightweight client-only signals for UI feedback. Avoids circular requires
	between UIController and gameplay controllers.
]]

local UIEvents = {}

local inspectOwnedBindable = Instance.new("BindableEvent")
UIEvents.inspectOwnedBrainrot = inspectOwnedBindable.Event

function UIEvents.fireInspectOwnedBrainrot(id: string)
	inspectOwnedBindable:Fire(id)
end

local coinDeltaBindable = Instance.new("BindableEvent")
local pendingSpendBindable = Instance.new("BindableEvent")
local plantFailedBindable = Instance.new("BindableEvent")
local fieldInspectBindable = Instance.new("BindableEvent")
local retentionBindable = Instance.new("BindableEvent")
local retentionState: any = nil

UIEvents.retentionUpdated = retentionBindable.Event

function UIEvents.fireRetentionState(state: any)
	retentionState = state
	retentionBindable:Fire(state)
end

function UIEvents.getRetentionState(): any
	return retentionState
end

-- Fired with a positive coin amount collected from the ground.
UIEvents.coinDelta = coinDeltaBindable.Event

-- Fired when the player attempts to place a Brainrot (wait for CoinsUpdated to show -cost).
UIEvents.pendingSpend = pendingSpendBindable.Event

-- Fired with a player-facing reason string when a plant attempt is rejected.
UIEvents.plantFailed = plantFailedBindable.Event

-- Fired with a planted Brainrot or a local-plot monster Model to inspect, or nil to hide.
UIEvents.fieldInspect = fieldInspectBindable.Event

function UIEvents.fireCoinDelta(delta: number)
	if delta ~= 0 then
		coinDeltaBindable:Fire(delta)
	end
end

function UIEvents.markPendingSpend()
	pendingSpendBindable:Fire()
end

function UIEvents.firePlantFailed(reason: string)
	if reason ~= "" then
		plantFailedBindable:Fire(reason)
	end
end

function UIEvents.fireFieldInspect(model: Model?)
	fieldInspectBindable:Fire(model)
end

return UIEvents
