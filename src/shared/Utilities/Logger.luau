--!strict
--[[
	Logger
	Thin, consistent logging wrapper so every Service/Controller prints with a
	recognizable scope prefix. Centralized so output formatting can change once.
]]

local Logger = {}
Logger.__index = Logger

export type Logger = typeof(setmetatable(
	{} :: { scope: string },
	Logger
))

function Logger.new(scope: string): Logger
	return setmetatable({ scope = scope }, Logger)
end

function Logger.info(self: Logger, ...: any)
	print(string.format("[%s]", self.scope), ...)
end

function Logger.warn(self: Logger, ...: any)
	warn(string.format("[%s]", self.scope), ...)
end

return Logger
