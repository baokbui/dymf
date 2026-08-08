--!strict
--[[
	CollisionUtil
	Registers BVM PhysicsService groups so player characters phase through
	monsters (and keeps monster parts CanCollide = false as a belt-and-suspenders).
]]

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local CollisionUtil = {}

local initialized = false

local function ensureGroup(name: string)
	local ok = pcall(function()
		PhysicsService:RegisterCollisionGroup(name)
	end)
	if not ok then
		-- Already registered (soft-reload / duplicate init).
		return
	end
end

function CollisionUtil.init()
	if initialized then
		return
	end
	initialized = true

	local players = Constants.COLLISION_GROUPS.Players
	local monsters = Constants.COLLISION_GROUPS.Monsters
	ensureGroup(players)
	ensureGroup(monsters)
	PhysicsService:CollisionGroupSetCollidable(players, monsters, false)
end

local function setPartGroup(part: BasePart, groupName: string)
	part.CollisionGroup = groupName
end

function CollisionUtil.applyCharacter(character: Model)
	CollisionUtil.init()
	local group = Constants.COLLISION_GROUPS.Players

	local function assign(instance: Instance)
		if instance:IsA("BasePart") then
			setPartGroup(instance, group)
		end
	end

	for _, descendant in character:GetDescendants() do
		assign(descendant)
	end
	character.DescendantAdded:Connect(assign)
end

function CollisionUtil.applyMonster(model: Model)
	CollisionUtil.init()
	local group = Constants.COLLISION_GROUPS.Monsters

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.Massless = true
			setPartGroup(descendant, group)
		end
	end
end

return CollisionUtil
