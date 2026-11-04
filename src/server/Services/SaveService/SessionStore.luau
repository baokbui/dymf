--!strict
-- SaveService's storage adapter. Injected backend/clock/id factory enable isolated tests.
-- A failed/ambiguous write blocks this session; it must never overwrite a possible commit.
local SessionStore = {}
SessionStore.__index = SessionStore

function SessionStore.new(backend: any, clock: () -> number, guid: () -> string, pause: (number) -> (), config: any)
	return setmetatable({ backend = backend, clock = clock, guid = guid, pause = pause,
		config = config, sessions = {} :: { [number]: any } }, SessionStore)
end

local function key(userId: number): string
	return string.format("Player_%d", userId)
end

function SessionStore.acquire(self: any, userId: number): (any?, string?)
	local token = self.guid()
	for attempt = 1, self.config.LOAD_RETRIES do
		local now = self.clock()
		local ok, result = pcall(function()
			return self.backend:UpdateAsync(key(userId), function(old: any)
				local data = if type(old) == "table" then table.clone(old) else {}
				local lease = data._session
				if type(lease) == "table" and lease.id ~= token and type(lease.expiresAt) == "number"
					and lease.expiresAt > now then return nil end
				data._session = { id = token, expiresAt = now + self.config.LEASE_SECONDS }
				return data
			end)
		end)
		if ok and type(result) == "table" and result._session.id == token then
			self.sessions[userId] = { token = token, revision = result._revision or 0, blocked = false }
			return result, nil
		end
		if ok then return nil, "SessionLocked" end
		self.pause(self.config.RETRY_SECONDS * attempt)
	end
	return nil, "SaveUnavailable"
end

function SessionStore.write(self: any, userId: number, payload: any, valid: (() -> boolean)?): (boolean, string?)
	local session = self.sessions[userId]
	if not session or session.blocked then return false, "SaveUnavailable" end
	local operation = self.guid()
	for attempt = 1, self.config.SAVE_RETRIES do
		local now = self.clock()
		local cancelled = "SessionLocked"
		local ok, result = pcall(function()
			return self.backend:UpdateAsync(key(userId), function(old: any)
				if type(old) ~= "table" or type(old._session) ~= "table" or old._session.id ~= session.token then
					cancelled = "SessionLocked"; return nil
				end
				-- A response can be lost after a commit; replay the acknowledgement.
				if old._operation == operation then return old end
				if (old._revision or 0) ~= session.revision then return nil end
				if valid and not valid() then cancelled = "Expired"; return nil end
				local data = table.clone(payload)
				data._session = { id = session.token, expiresAt = now + self.config.LEASE_SECONDS }
				data._revision = session.revision + 1
				data._operation = operation
				return data
			end)
		end)
		if ok and type(result) == "table" and result._operation == operation then
			session.revision = result._revision
			return true, nil
		end
		if ok then
			if cancelled ~= "Expired" then session.blocked = true end
			return false, cancelled
		end
		self.pause(math.min(self.config.MAX_RETRY_SECONDS, self.config.RETRY_SECONDS * 2 ^ (attempt - 1)))
	end
	session.blocked = true
	return false, "SaveUnavailable"
end

function SessionStore.isWritable(self: any, userId: number): boolean
	local session = self.sessions[userId]
	return session ~= nil and not session.blocked
end

function SessionStore.release(self: any, userId: number)
	local session = self.sessions[userId]
	if not session then return end
	-- Preserve the latest durable contents, even after an uncertain write.
	pcall(function()
		self.backend:UpdateAsync(key(userId), function(old: any)
			if type(old) ~= "table" or type(old._session) ~= "table" or old._session.id ~= session.token then return nil end
			local data = table.clone(old)
			data._session = nil
			return data
		end)
	end)
	self.sessions[userId] = nil
end

return SessionStore
