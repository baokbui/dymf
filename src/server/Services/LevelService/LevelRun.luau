--!strict
--[[
	LevelRun
	Spawn-group scheduler for one active level attempt. LevelService owns lifecycle;
	this module tracks per-run spawn timing (no monster AI).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GridConfig = require(ReplicatedStorage.Shared.Config.GridConfig)
local LevelConfig = require(ReplicatedStorage.Shared.Config.LevelConfig)
local Types = require(ReplicatedStorage.Shared.Types)

local LevelRun = {}
LevelRun.__index = LevelRun

export type RunPhase = "group_delay" | "big_wave_warning" | "spawning" | "done_spawning"

export type LevelRun = typeof(setmetatable(
	{} :: {
		definition: Types.LevelDefinition,
		totalToSpawn: number,
		totalSpawned: number,
		groupIndex: number,
		spawnedInGroup: number,
		phase: RunPhase,
		nextActionTime: number,
		bigWaveWarningActive: boolean,
	},
	LevelRun
))

local function totalMonsters(definition: Types.LevelDefinition): number
	local total = 0
	for _, group in definition.groups do
		total += group.count
	end
	return total
end

function LevelRun.new(definition: Types.LevelDefinition): LevelRun
	local self = setmetatable({
		definition = definition,
		totalToSpawn = totalMonsters(definition),
		totalSpawned = 0,
		groupIndex = 1,
		spawnedInGroup = 0,
		phase = "group_delay" :: RunPhase,
		nextActionTime = 0,
		bigWaveWarningActive = false,
	}, LevelRun)

	local firstGroup = definition.groups[1]
	local delay = if firstGroup and firstGroup.startDelay ~= nil then firstGroup.startDelay else 0
	self.nextActionTime = os.clock() + delay
	return self
end

function LevelRun.getCurrentGroup(self: LevelRun): Types.SpawnGroup?
	return self.definition.groups[self.groupIndex]
end

function LevelRun.spawnInterval(self: LevelRun): number
	local group = self:getCurrentGroup()
	if group and group.spawnInterval then
		return group.spawnInterval
	end
	return LevelConfig.DEFAULT_SPAWN_INTERVAL
end

function LevelRun.groupDelay(self: LevelRun, group: Types.SpawnGroup): number
	if group.startDelay ~= nil then
		return group.startDelay
	end
	return LevelConfig.DEFAULT_GROUP_DELAY
end

function LevelRun.isDoneSpawning(self: LevelRun): boolean
	return self.phase == "done_spawning"
end

function LevelRun.advance(self: LevelRun, now: number): { spawn: boolean, bigWaveWarning: boolean, bigWaveWarningEnd: boolean }
	local result = { spawn = false, bigWaveWarning = false, bigWaveWarningEnd = false }

	if self.phase == "done_spawning" then
		return result
	end

	if now < self.nextActionTime then
		return result
	end

	local group = self:getCurrentGroup()
	if not group then
		self.phase = "done_spawning"
		return result
	end

	if self.phase == "group_delay" then
		if group.isBigWave then
			self.phase = "big_wave_warning"
			self.bigWaveWarningActive = true
			self.nextActionTime = now + LevelConfig.BIG_WAVE_WARNING_TIME
			result.bigWaveWarning = true
			return result
		end
		self.phase = "spawning"
		self.spawnedInGroup = 0
		self.nextActionTime = now
		return self:advance(now)
	end

	if self.phase == "big_wave_warning" then
		self.phase = "spawning"
		self.bigWaveWarningActive = false
		self.spawnedInGroup = 0
		self.nextActionTime = now
		result.bigWaveWarningEnd = true
		return self:advance(now)
	end

	-- spawning
	if self.spawnedInGroup < group.count then
		self.spawnedInGroup += 1
		self.totalSpawned += 1
		result.spawn = true
		if self.spawnedInGroup < group.count then
			self.nextActionTime = now + self:spawnInterval()
		else
			self:_finishGroup(now)
		end
		return result
	end

	return result
end

function LevelRun._finishGroup(self: LevelRun, now: number)
	if self.groupIndex >= #self.definition.groups then
		self.phase = "done_spawning"
		return
	end

	self.groupIndex += 1
	local nextGroup = self.definition.groups[self.groupIndex]
	self.spawnedInGroup = 0
	self.phase = "group_delay"
	self.nextActionTime = now + self:groupDelay(nextGroup)
end

function LevelRun.randomRow(): number
	return math.random(1, GridConfig.ROWS)
end

return LevelRun
