--!strict
local BattleClock = require(game:GetService("ReplicatedStorage").Shared.Utilities.BattleClock)
--[[
	AbyssalTorrent (Tralalero GOD)
	A water jet from the mouth to the east end of the row. It pierces every
	monster in that stretch. Each full second a monster spends in the jet
	deals Tralalero's base damage (catalog damage, not the evolved stat),
	plus 20% of that base for every tile the monster is closer to his plant
	than the east edge of the row.
	Needs 3+ enemies still in front of him, or a boss still in front.
	Monsters that have already walked past him are not in the jet.
	If several GOD Tralaleros in the
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
local GridUtil = require(ReplicatedStorage.Shared.Utilities.GridUtil)
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

local function rowQualifies(plotModel: Model, row: number, originColumn: number, minEnemies: number): boolean
	local count, boss = CombatService.frontLaneThreat(plotModel, row, originColumn)
	return boss or count >= minEnemies
end

local function hitDamage(base: number, plantColumn: number, monsterColumn: number, closePercent: number): number
	local plantTile = GridUtil.tileAtColumn(plantColumn)
	local monsterTile = GridUtil.tileAtColumn(monsterColumn)
	local away = math.max(0, monsterTile - plantTile)
	local span = math.max(0, GridConfig.COLUMNS - plantTile)
	local closer = math.max(0, span - away)
	local percent = closer * closePercent
	return math.max(1, math.floor(base * (100 + percent) / 100))
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
		-- The jet leaves the mouth toward the east end of the row.
		if CombatService.isStillInFront(monsterId, fromColumn) then
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
}

type Helix = {
	attachments: { Attachment },
	phase: number,
	color: Color3,
}

type OrbitBubble = {
	part: BasePart,
	core: BasePart,
	along: number,
	angle: number,
	radius: number,
	drift: number,
}

-- Bright core, soft glow, rings rushing down the beam, and two spiral streaks.
local function sprayJet(startPos: Vector3, endPos: Vector3, parent: Instance): Model
	local direction, lifted, length = axisFrame(startPos, endPos)
	local side = direction:Cross(lifted).Unit
	local mid = startPos + direction * (length * 0.5)
	local basis = CFrame.fromMatrix(mid, direction, lifted)

	local model = Instance.new("Model")
	model.Name = "AbyssalTorrent"

	local ringCount = VfxConfig.HYDRO_JET_RING_COUNT
	local ringSegments = VfxConfig.HYDRO_JET_RING_SEGMENTS
	local streakCount = VfxConfig.HYDRO_JET_STREAKS
	local helixPoints = VfxConfig.HYDRO_JET_HELIX_POINTS
	local bubbleCount = VfxConfig.HYDRO_JET_BUBBLE_COUNT
	local rushRate = 28

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
	rush.Rate = rushRate
	rush.Enabled = rushRate > 0
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
	for index = 1, streakCount do
		local angle = (index - 1) / streakCount * math.pi * 2
		local offset = Vector3.new(0, math.sin(angle) * streakRadius, math.cos(angle) * streakRadius)
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(-length * 0.5, 0, 0) + offset
		a0.Parent = hub
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(length * 0.5, 0, 0) + offset
		a1.Parent = hub
		linkBeam(a0, a1, VfxConfig.HYDRO_JET_CORE_COLOR, 0.35, 0.25)
	end

	local function makeRing(color: Color3, radius: number): Ring
		local attachments: { Attachment } = {}
		local anchor = ghostPart(model, "Ring")
		for _ = 1, ringSegments do
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
		return { attachments = attachments, radius = radius }
	end

	local rings: { Ring } = {}
	for index = 1, ringCount do
		local color = if index % 2 == 0 then VfxConfig.HYDRO_JET_WATER_COLOR else VfxConfig.HYDRO_JET_CORE_COLOR
		table.insert(rings, makeRing(color, VfxConfig.HYDRO_JET_RING_RADIUS))
	end

	local helices: { Helix } = {
		{ attachments = {}, phase = 0, color = VfxConfig.HYDRO_JET_CORE_COLOR },
		{ attachments = {}, phase = math.pi, color = VfxConfig.HYDRO_JET_WATER_COLOR },
	}
	for _, helix in helices do
		local anchor = ghostPart(model, "Helix")
		for _ = 1, helixPoints do
			local attachment = Instance.new("Attachment")
			attachment.Parent = anchor
			table.insert(helix.attachments, attachment)
		end
		for index = 1, #helix.attachments - 1 do
			linkBeam(helix.attachments[index], helix.attachments[index + 1], helix.color, 0.55, 0.08)
		end
	end

	local bubbles: { OrbitBubble } = {}
	for index = 1, bubbleCount do
		local scale = 0.75 + (index % 5) * 0.1
		local size = VfxConfig.HYDRO_JET_BUBBLE_SIZE * scale
		local bubble = Instance.new("Part")
		bubble.Name = "TorrentBubble"
		bubble.Shape = Enum.PartType.Ball
		bubble.Anchored = true
		bubble.CanCollide = false
		bubble.CanQuery = false
		bubble.CanTouch = false
		bubble.CastShadow = false
		bubble.Material = Enum.Material.Glass
		bubble.Reflectance = 0.45
		bubble.Color = VfxConfig.HYDRO_JET_BUBBLE_COLOR
		bubble.Transparency = VfxConfig.HYDRO_JET_BUBBLE_TRANSPARENCY
		bubble.Size = Vector3.new(size, size, size)
		bubble:SetAttribute("VfxLayer", "High")
		bubble.Parent = model
		local coreBubble = Instance.new("Part")
		coreBubble.Name = "TorrentBubbleCore"
		coreBubble.Shape = Enum.PartType.Ball
		coreBubble.Anchored = true
		coreBubble.CanCollide = false
		coreBubble.CanQuery = false
		coreBubble.CanTouch = false
		coreBubble.CastShadow = false
		coreBubble.Material = Enum.Material.Neon
		coreBubble.Color = Color3.fromRGB(255, 255, 255)
		coreBubble.Transparency = 0.35
		coreBubble.Size = Vector3.new(size, size, size) * 0.45
		coreBubble:SetAttribute("VfxLayer", "High")
		coreBubble.Parent = model
		table.insert(bubbles, {
			part = bubble,
			core = coreBubble,
			along = (index - 1) / math.max(bubbleCount, 1),
			angle = (index - 1) / math.max(bubbleCount, 1) * math.pi * 2,
			radius = VfxConfig.HYDRO_JET_BUBBLE_RADIUS * (0.9 + (index % 3) * 0.2),
			drift = 0.18 + (index % 4) * 0.05,
		})
	end

	local function pointOnBeam(along: number, angle: number, radius: number): Vector3
		return startPos
			+ direction * along
			+ side * (math.cos(angle) * radius)
			+ lifted * (math.sin(angle) * radius)
	end

	local function pose(elapsed: number)
		local spin = elapsed * VfxConfig.HYDRO_JET_SPIN
		local traveling = #rings
		local travelIndex = 0
		for _, ring in rings do
			travelIndex += 1
			local travel = (elapsed * 0.45 + (travelIndex - 1) / math.max(traveling, 1)) % 1
			local along = travel * length
			local radius = ring.radius + (1 - travel) * VfxConfig.HYDRO_JET_RING_GROW
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
		for _, bubble in bubbles do
			local along = (bubble.along + elapsed * bubble.drift) % 1
			local angle = bubble.angle + elapsed * 0.8
			local cf = CFrame.new(pointOnBeam(along * length, angle, bubble.radius))
			bubble.part.CFrame = cf
			bubble.core.CFrame = cf
		end
	end

	model.PrimaryPart = core
	model.Parent = parent
	pose(0)

	local started = BattleClock.now(parent)
	local spinConn: RBXScriptConnection
	spinConn = RunService.Heartbeat:Connect(function()
		if not model.Parent then
			spinConn:Disconnect()
			return
		end
		pose(BattleClock.now(parent) - started)
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
	local closePercent = CombatConfig.TORRENT_CLOSE_PERCENT
	if type(params) == "table" then
		if type(params.minEnemies) == "number" then
			minEnemies = params.minEnemies
		end
		if type(params.closePercent) == "number" then
			closePercent = params.closePercent
		end
	end

	if isRowBusy(ctx.plotModel, ctx.position.row) then
		return false
	end
	if not rowQualifies(ctx.plotModel, ctx.position.row, ctx.position.column, minEnemies) then
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

	callbacks.lockExclusive(duration)
	callbacks.lockCore(duration)
	local BrainrotAnimation = require(script.Parent.Parent.BrainrotAnimation)
	BrainrotAnimation.stopAttack(ctx.model)
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
				if not BattleClock.wait(ctx.plotModel, STEP) then break end
				if not model.Parent then
					break
				end
				local inside: { [string]: boolean } = {}
				for _, monsterId in monstersInJet(plotModel, row, fromColumn) do
					inside[monsterId] = true
					local held = (exposure[monsterId] or 0) + 1
					if held >= stepsPerHit then
						held -= stepsPerHit
						local column = CombatService.getMonsterColumn(monsterId)
						local hit = damage
						if type(column) == "number" then
							hit = hitDamage(damage, fromColumn, column, closePercent)
						end
						CombatService.damageMonster(monsterId, hit, brainrotId)
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
