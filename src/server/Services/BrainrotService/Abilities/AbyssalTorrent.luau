--!strict
--[[
	AbyssalTorrent (Tralalero GOD)
	A water jet from the mouth to the east end of the row. It pierces every
	monster in that stretch. Each full second a monster spends in the jet
	deals Tralalero's base damage (catalog damage, not the evolved stat)
	and knocks them east by a fraction of a tile.
	Needs 3+ enemies in the row, or a boss. If several GOD Tralaleros in the
	same row are ready, the easternmost (closest to incoming monsters) fires
	first. One whose torrent is still cooling down is skipped.
	Bubbles pause while the jet is out.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local GridConfig = require(ReplicatedStorage.Shared.Config.GridConfig)
local VfxConfig = require(ReplicatedStorage.Shared.Config.VfxConfig)
local Logger = require(ReplicatedStorage.Shared.Utilities.Logger)
local GridService = require(script.Parent.Parent.Parent.GridService)
local CombatService = require(script.Parent.Parent.Parent.CombatService)

local BubbleShot = require(script.Parent.BubbleShot)

local AbyssalTorrent = {}

local log = Logger.new("AbyssalTorrent")
local ABILITY_ID = "AbyssalTorrent"
local STEP = 0.1
local DAMAGE_EVERY = 1

-- One torrent at a time per plot row so two ready Tralaleros cannot overlap.
local rowBusy: { [Model]: { [number]: boolean } } = {}

local function setRowBusy(plotModel: Model, row: number, busy: boolean)
	local rows = rowBusy[plotModel]
	if busy then
		if not rows then
			rows = {}
			rowBusy[plotModel] = rows
		end
		rows[row] = true
		return
	end
	if not rows then
		return
	end
	rows[row] = nil
	if next(rows) == nil then
		rowBusy[plotModel] = nil
	end
end

local function isRowBusy(plotModel: Model, row: number): boolean
	local rows = rowBusy[plotModel]
	return rows ~= nil and rows[row] == true
end

local function rowQualifies(plotModel: Model, row: number, minEnemies: number): boolean
	if CombatService.rowHasBoss(plotModel, row) then
		return true
	end
	return #CombatService.getAllMonstersInRow(plotModel, row) >= minEnemies
end

local function baseDamage(brainrotId: string): number
	local definition = Brainrots.get(brainrotId)
	if definition and definition.damage > 0 then
		return definition.damage
	end
	return 0
end

local function projectilesFolder(plotModel: Model): Folder
	local folder = plotModel:FindFirstChild("Projectiles")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Projectiles"
		folder.Parent = plotModel
	end
	return folder :: Folder
end

local function rowEnd(plotModel: Model, row: number, mouth: Vector3): Vector3?
	-- Column COLUMNS + 0.5 is the east edge of the last lawn tile.
	local edge = GridService.getWorldPositionAtColumn(plotModel, row, GridConfig.COLUMNS + 0.5)
	if not edge then
		return nil
	end
	return Vector3.new(edge.X, mouth.Y, mouth.Z)
end

-- Snout, not the body center. Units face +X, so the mouth is the east face
-- of the head. A generic Head part's world-X offset often sits in the chest.
local SNOUT_NAMES = { "Mouth", "Snout", "Muzzle", "Jaw", "Nose" }
local FACE = Vector3.xAxis

local function eastFaceCenter(part: BasePart): Vector3
	local half = part.Size * 0.5
	local cf = part.CFrame
	local bestDot = -math.huge
	local corners: { Vector3 } = {}
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local world = (cf * CFrame.new(sx * half.X, sy * half.Y, sz * half.Z)).Position
				table.insert(corners, world)
				local dot = world:Dot(FACE)
				if dot > bestDot then
					bestDot = dot
				end
			end
		end
	end
	local sum = Vector3.zero
	local count = 0
	for _, world in corners do
		if world:Dot(FACE) >= bestDot - 0.08 then
			sum += world
			count += 1
		end
	end
	if count == 0 then
		return part.Position
	end
	return sum / count
end

local function torrentMouth(model: Model): Vector3
	for _, name in SNOUT_NAMES do
		local inst = model:FindFirstChild(name, true)
		if inst and (inst:IsA("Attachment") or inst:IsA("Bone")) then
			return inst.WorldPosition - FACE * 0.35
		end
		if inst and inst:IsA("BasePart") then
			return eastFaceCenter(inst) - FACE * 0.35
		end
	end

	local minY = math.huge
	local maxY = -math.huge
	local parts: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Transparency < 0.95 and descendant.Size.Magnitude > 0.2 then
			table.insert(parts, descendant)
			minY = math.min(minY, descendant.Position.Y)
			maxY = math.max(maxY, descendant.Position.Y)
		end
	end
	local band = minY + (maxY - minY) * 0.4
	local best: Vector3? = nil
	local bestX = -math.huge
	for _, part in parts do
		if part.Position.Y < band then
			continue
		end
		local face = eastFaceCenter(part)
		if face.X > bestX then
			bestX = face.X
			best = face
		end
	end
	if best then
		-- Sit just inside the snout so the stream leaves the mouth.
		return best - FACE * 0.45
	end
	return BubbleShot.mouthWorld(model)
end

local function monstersInJet(plotModel: Model, row: number, fromColumn: number): { string }
	local hits: { string } = {}
	for _, monsterId in CombatService.getAllMonstersInRow(plotModel, row) do
		local column = CombatService.getMonsterColumn(monsterId)
		-- The jet leaves the mouth toward the east end of the row.
		if type(column) == "number" and column >= fromColumn then
			table.insert(hits, monsterId)
		end
	end
	return hits
end

local function axisFrame(startPos: Vector3, endPos: Vector3): (Vector3, Vector3, number)
	local delta = endPos - startPos
	local length = math.max(delta.Magnitude, 0.2)
	local direction = delta.Unit
	local side = direction:Cross(Vector3.yAxis)
	if side.Magnitude < 0.05 then
		side = Vector3.zAxis
	end
	side = side.Unit
	local lifted = side:Cross(direction).Unit
	return direction, lifted, length
end

local function ghostPart(parent: Instance, name: string): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Parent = parent
	return part
end

local function neonCylinder(parent: Instance, name: string, color: Color3, transparency: number): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency
	part.Parent = parent
	return part
end

local function lightBeam(parent: Instance, color: Color3, width: number, transparency: number): Beam
	local beam = Instance.new("Beam")
	beam.Color = ColorSequence.new(color)
	beam.Width0 = width
	beam.Width1 = width
	beam.LightEmission = 0.4
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureSpeed = 2.4
	beam.TextureLength = 0.6
	beam.Transparency = NumberSequence.new(transparency)
	beam.Parent = parent
	return beam
end

local function linkBeam(a0: Attachment, a1: Attachment, color: Color3, width: number, transparency: number): Beam?
	local parent = a0.Parent
	if not parent then
		return nil
	end
	local beam = lightBeam(parent, color, width, transparency)
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.TextureSpeed = 3
	return beam
end

type Ring = {
	attachments: { Attachment },
	radius: number,
	locked: boolean,
}

type Helix = {
	attachments: { Attachment },
	phase: number,
	color: Color3,
}

-- Bright core, soft glow, rings rushing down the beam, and two spiral streaks.
local function sprayJet(startPos: Vector3, endPos: Vector3, parent: Instance): Model
	local direction, lifted, length = axisFrame(startPos, endPos)
	local side = direction:Cross(lifted).Unit
	local mid = startPos + direction * (length * 0.5)
	local basis = CFrame.fromMatrix(mid, direction, lifted)

	local model = Instance.new("Model")
	model.Name = "AbyssalTorrent"

	local hub = ghostPart(model, "Hub")
	hub.CFrame = basis

	local function placeCylinder(part: Part, thickness: number)
		part.Size = Vector3.new(length, thickness, thickness)
		part.CFrame = basis
	end

	local core = neonCylinder(model, "Core", VfxConfig.HYDRO_JET_WATER_COLOR, 0.35)
	placeCylinder(core, VfxConfig.HYDRO_JET_CORE_THICKNESS)

	local mouth = ghostPart(model, "Mouth")
	-- Front is local -Z, which lookAt aims down the beam.
	mouth.CFrame = CFrame.lookAt(startPos, endPos)
	local flareSize = VfxConfig.HYDRO_JET_RING_RADIUS * 0.35
	local flare = neonCylinder(model, "Flare", VfxConfig.HYDRO_JET_WATER_COLOR, 0.45)
	flare.Shape = Enum.PartType.Ball
	flare.Size = Vector3.new(flareSize, flareSize, flareSize)
	flare.CFrame = CFrame.new(startPos)
	local light = Instance.new("PointLight")
	light.Color = VfxConfig.HYDRO_JET_WATER_COLOR
	light.Brightness = 1.4
	light.Range = VfxConfig.HYDRO_JET_DEEP_WIDTH * 1.3
	light.Parent = mouth

	local rush = Instance.new("ParticleEmitter")
	rush.Name = "HydroRush"
	rush.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	rush.Color = ColorSequence.new(VfxConfig.HYDRO_JET_CORE_COLOR, VfxConfig.HYDRO_JET_WATER_COLOR)
	rush.LightEmission = 0.4
	rush.LightInfluence = 0
	rush.Rate = 28
	rush.Lifetime = NumberRange.new(0.2, 0.4)
	rush.Speed = NumberRange.new(22, 34)
	rush.SpreadAngle = Vector2.new(6, 6)
	rush.EmissionDirection = Enum.NormalId.Front
	rush.Size = NumberSequence.new(0.4, 0.08)
	rush.Transparency = NumberSequence.new(0.25, 1)
	rush.Parent = mouth

	local tipA = Instance.new("Attachment")
	tipA.Position = Vector3.new(-length * 0.5, 0, 0)
	tipA.Parent = hub
	local tipB = Instance.new("Attachment")
	tipB.Position = Vector3.new(length * 0.5, 0, 0)
	tipB.Parent = hub
	local function spanBeam(color: Color3, width: number, transparency: number)
		local beam = lightBeam(hub, color, width, transparency)
		beam.Attachment0 = tipA
		beam.Attachment1 = tipB
		-- Solid ribbon. The sparkle texture stays on the streaks and spirals.
		beam.Texture = ""
		beam.TextureSpeed = 0
	end
	spanBeam(VfxConfig.HYDRO_JET_DEEP_COLOR, VfxConfig.HYDRO_JET_DEEP_WIDTH, 0.62)
	spanBeam(VfxConfig.HYDRO_JET_WATER_COLOR, VfxConfig.HYDRO_JET_WATER_WIDTH, 0.4)
	spanBeam(VfxConfig.HYDRO_JET_CORE_COLOR, VfxConfig.HYDRO_JET_CORE_WIDTH, 0.22)

	local streakRadius = VfxConfig.HYDRO_JET_HELIX_RADIUS * 0.65
	for index = 1, VfxConfig.HYDRO_JET_STREAKS do
		local angle = (index - 1) / VfxConfig.HYDRO_JET_STREAKS * math.pi * 2
		local offset = Vector3.new(0, math.sin(angle) * streakRadius, math.cos(angle) * streakRadius)
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(-length * 0.5, 0, 0) + offset
		a0.Parent = hub
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(length * 0.5, 0, 0) + offset
		a1.Parent = hub
		linkBeam(a0, a1, VfxConfig.HYDRO_JET_CORE_COLOR, 0.35, 0.25)
	end

	local function makeRing(color: Color3, radius: number, locked: boolean): Ring
		local attachments: { Attachment } = {}
		local anchor = ghostPart(model, "Ring")
		for _ = 1, VfxConfig.HYDRO_JET_RING_SEGMENTS do
			local attachment = Instance.new("Attachment")
			attachment.Parent = anchor
			table.insert(attachments, attachment)
		end
		for index, attachment in attachments do
			local nextAttachment = attachments[(index % #attachments) + 1]
			local beam = linkBeam(attachment, nextAttachment, color, 0.5, 0.2)
			if beam then
				beam.Texture = ""
				beam.TextureSpeed = 0
			end
		end
		return { attachments = attachments, radius = radius, locked = locked }
	end

	local rings: { Ring } = {}
	local mouthRadius = VfxConfig.HYDRO_JET_RING_RADIUS
	for index = 1, VfxConfig.HYDRO_JET_MOUTH_RINGS do
		local color = if index % 2 == 0 then VfxConfig.HYDRO_JET_WATER_COLOR else VfxConfig.HYDRO_JET_CORE_COLOR
		table.insert(rings, makeRing(color, mouthRadius * (0.55 + index * 0.35), true))
	end
	for index = 1, VfxConfig.HYDRO_JET_RING_COUNT do
		local color = if index % 2 == 0 then VfxConfig.HYDRO_JET_WATER_COLOR else VfxConfig.HYDRO_JET_CORE_COLOR
		table.insert(rings, makeRing(color, VfxConfig.HYDRO_JET_RING_RADIUS, false))
	end

	local helices: { Helix } = {
		{ attachments = {}, phase = 0, color = VfxConfig.HYDRO_JET_CORE_COLOR },
		{ attachments = {}, phase = math.pi, color = VfxConfig.HYDRO_JET_WATER_COLOR },
	}
	for _, helix in helices do
		local anchor = ghostPart(model, "Helix")
		for _ = 1, VfxConfig.HYDRO_JET_HELIX_POINTS do
			local attachment = Instance.new("Attachment")
			attachment.Parent = anchor
			table.insert(helix.attachments, attachment)
		end
		for index = 1, #helix.attachments - 1 do
			linkBeam(helix.attachments[index], helix.attachments[index + 1], helix.color, 0.55, 0.08)
		end
	end

	local function pointOnBeam(along: number, angle: number, radius: number): Vector3
		return startPos
			+ direction * along
			+ side * (math.cos(angle) * radius)
			+ lifted * (math.sin(angle) * radius)
	end

	local function pose(elapsed: number)
		local spin = elapsed * VfxConfig.HYDRO_JET_SPIN
		local traveling = 0
		for _, ring in rings do
			if not ring.locked then
				traveling += 1
			end
		end
		local travelIndex = 0
		for _, ring in rings do
			local along: number
			local radius: number
			if ring.locked then
				along = 0.4
				radius = ring.radius * (1 + math.sin(elapsed * 6) * 0.07)
			else
				travelIndex += 1
				local travel = (elapsed * 0.45 + (travelIndex - 1) / math.max(traveling, 1)) % 1
				along = travel * length
				radius = ring.radius + (1 - travel) * VfxConfig.HYDRO_JET_RING_GROW
			end
			local count = #ring.attachments
			for segment, attachment in ring.attachments do
				local angle = (segment - 1) / count * math.pi * 2
				attachment.WorldPosition = pointOnBeam(along, angle, radius)
			end
		end
		local turns = VfxConfig.HYDRO_JET_HELIX_TURNS * math.pi * 2
		local helixRadius = VfxConfig.HYDRO_JET_HELIX_RADIUS
		for _, helix in helices do
			local count = #helix.attachments
			for index, attachment in helix.attachments do
				local t = (index - 1) / math.max(count - 1, 1)
				local angle = helix.phase + spin + t * turns
				local radius = helixRadius * (0.75 + math.sin(t * math.pi) * 0.35)
				attachment.WorldPosition = pointOnBeam(t * length, angle, radius)
			end
		end
	end

	model.PrimaryPart = core
	model.Parent = parent
	pose(0)

	local started = os.clock()
	local spinConn: RBXScriptConnection
	spinConn = RunService.Heartbeat:Connect(function()
		if not model.Parent then
			spinConn:Disconnect()
			return
		end
		pose(os.clock() - started)
	end)
	model.Destroying:Connect(function()
		spinConn:Disconnect()
	end)

	return model
end

function AbyssalTorrent.tryAct(ctx, callbacks)
	local params = ctx.extraParams
	local duration = if params and type(params.duration) == "number" then params.duration else 15
	local minEnemies = CombatConfig.TORRENT_MIN_ENEMIES
	local knockback = CombatConfig.TORRENT_KNOCKBACK_TILES
	if type(params) == "table" then
		if type(params.minEnemies) == "number" then
			minEnemies = params.minEnemies
		end
		if type(params.knockbackTiles) == "number" then
			knockback = params.knockbackTiles
		end
	end

	if isRowBusy(ctx.plotModel, ctx.position.row) then
		return false
	end
	if not rowQualifies(ctx.plotModel, ctx.position.row, minEnemies) then
		return false
	end

	local BrainrotBehavior = require(script.Parent.Parent.BrainrotBehavior)
	if BrainrotBehavior.hasCloserReadyAlly(ctx.instanceId, ABILITY_ID) then
		return false
	end

	local damage = baseDamage(ctx.definition.id)
	if damage <= 0 or duration <= 0 then
		return false
	end

	local fromColumn = ctx.position.column
	local mouth = torrentMouth(ctx.model)
	local finish = rowEnd(ctx.plotModel, ctx.position.row, mouth)
	if not finish or (finish - mouth).Magnitude < 0.2 then
		return false
	end

	callbacks.pulseAttack()
	callbacks.lockExclusive(duration)
	callbacks.lockCore(duration)
	setRowBusy(ctx.plotModel, ctx.position.row, true)

	local jet = sprayJet(mouth, finish, projectilesFolder(ctx.plotModel))
	local model = ctx.model
	local plotModel = ctx.plotModel
	local row = ctx.position.row
	local brainrotId = ctx.definition.id
	local steps = math.floor(duration / STEP + 0.5)
	local stepsPerHit = math.floor(DAMAGE_EVERY / STEP + 0.5)
	local exposure: { [string]: number } = {}

	task.spawn(function()
		local ok, err = pcall(function()
			for _ = 1, steps do
				if not model.Parent then
					break
				end
				task.wait(STEP)
				if not model.Parent then
					break
				end
				local inside: { [string]: boolean } = {}
				for _, monsterId in monstersInJet(plotModel, row, fromColumn) do
					inside[monsterId] = true
					local held = (exposure[monsterId] or 0) + 1
					if held >= stepsPerHit then
						held -= stepsPerHit
						CombatService.damageMonster(monsterId, damage, brainrotId)
						CombatService.applyStatusToMonster(monsterId, "Knockback", 0, knockback)
					end
					exposure[monsterId] = held
				end
				for monsterId in exposure do
					if not inside[monsterId] then
						exposure[monsterId] = nil
					end
				end
			end
		end)
		setRowBusy(plotModel, row, false)
		if jet.Parent then
			jet:Destroy()
		end
		if not ok then
			log:warn(err)
		end
	end)

	return true
end

return AbyssalTorrent
