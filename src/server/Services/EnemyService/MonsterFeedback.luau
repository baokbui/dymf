--!strict
--[[
	MonsterFeedback
	Server-side visual feedback on monster models (replicates to clients).

	Attack pulse uses Model:ScaleTo so authored MeshParts are not Size-warped.
	Hit flash tints visible BaseParts (same pattern as BrainrotFeedback).
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterConfig = require(ReplicatedStorage.Shared.Config.MonsterConfig)
local ModelUtil = require(ReplicatedStorage.Shared.Utilities.ModelUtil)

local MonsterFeedback = {}

local baseScales: { [Model]: number } = {}
local pulseTokens: { [Model]: number } = {}

local activeHitFlashTweens: { [Model]: { Tween } } = {}
local hitFlashBaseColors: { [Model]: { [BasePart]: Color3 } } = {}

type FrozenLook = {
	colors: { [BasePart]: Color3 },
	materials: { [BasePart]: Enum.Material },
	-- Toolbox MeshParts often use SurfaceAppearance / TextureID which ignore
	-- BasePart.Color — stash and clear them so Ice material + color show.
	surfaceAppearanceParents: { [SurfaceAppearance]: Instance },
	meshTextures: { [MeshPart]: string },
	specialMeshTextures: { [SpecialMesh]: string },
}

local frozenLooks: { [Model]: FrozenLook } = {}
local bubbledModels: { [Model]: boolean } = {}
local poppingBubbles: { [Model]: boolean } = {}

local FREEZE_HIGHLIGHT_NAME = "FreezeHighlight"

local function ensureFreezeHighlight(model: Model)
	local existing = model:FindFirstChild(FREEZE_HIGHLIGHT_NAME)
	if existing and existing:IsA("Highlight") then
		existing.Enabled = true
		existing.FillColor = MonsterConfig.FREEZE_COLOR
		existing.OutlineColor = Color3.fromRGB(220, 245, 255)
		existing.FillTransparency = MonsterConfig.FREEZE_HIGHLIGHT_FILL
		existing.OutlineTransparency = MonsterConfig.FREEZE_HIGHLIGHT_OUTLINE
		return
	end
	if existing then
		existing:Destroy()
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = FREEZE_HIGHLIGHT_NAME
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = MonsterConfig.FREEZE_COLOR
	highlight.OutlineColor = Color3.fromRGB(220, 245, 255)
	highlight.FillTransparency = MonsterConfig.FREEZE_HIGHLIGHT_FILL
	highlight.OutlineTransparency = MonsterConfig.FREEZE_HIGHLIGHT_OUTLINE
	highlight.Adornee = model
	highlight.Parent = model
end

local function clearFreezeHighlight(model: Model)
	local existing = model:FindFirstChild(FREEZE_HIGHLIGHT_NAME)
	if existing then
		existing:Destroy()
	end
end

local function visibleParts(model: Model): { BasePart }
	local parts: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Transparency < 0.95 and descendant.Name ~= "BubbleShell" then
			table.insert(parts, descendant)
		end
	end
	if #parts == 0 then
		local body = model.PrimaryPart or model:FindFirstChild("Body")
		if body and body:IsA("BasePart") then
			table.insert(parts, body)
		end
	end
	return parts
end

local function resolveBody(model: Model): BasePart?
	local body = model:FindFirstChild("Body", true)
	if body and body:IsA("BasePart") then
		return body
	end
	local primary = model.PrimaryPart
	if primary then
		return primary
	end
	local hrp = model:FindFirstChild("HumanoidRootPart", true)
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
	return nil
end

local function cancelHitFlash(model: Model)
	local tweens = activeHitFlashTweens[model]
	if tweens then
		for _, tween in tweens do
			tween:Cancel()
		end
		activeHitFlashTweens[model] = nil
	end
end

local function ensureFreezeVfx(body: BasePart)
	local existing = body:FindFirstChild("FreezeVfx")
	if existing then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "FreezeVfx"
	attachment.Parent = body

	local flakes = Instance.new("ParticleEmitter")
	flakes.Name = "IceFlakes"
	flakes.Color = ColorSequence.new(MonsterConfig.FREEZE_COLOR)
	flakes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	flakes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	flakes.Lifetime = NumberRange.new(0.4, 0.8)
	flakes.Speed = NumberRange.new(0.5, 2)
	flakes.SpreadAngle = Vector2.new(180, 180)
	flakes.Rate = 12
	flakes.LightEmission = 0.4
	flakes.Parent = attachment
end

local function clearFreezeVfx(body: BasePart)
	local existing = body:FindFirstChild("FreezeVfx")
	if existing then
		existing:Destroy()
	end
end

--[[
	Persistent tinted aura for standout bosses (e.g. Duke Vampire's dark aura).
	Data-driven via `MonsterDefinition.auraColor` — never branch on names.
	Attached once at spawn; torn down in `cleanup` like every other VFX here.
]]
function MonsterFeedback.applyAura(model: Model, auraColor: Color3?, auraScale: number?)
	if not auraColor then
		return
	end
	local body = resolveBody(model)
	if not body then
		return
	end
	if body:FindFirstChild("AuraVfx") then
		return
	end

	local scale = auraScale or 1

	local attachment = Instance.new("Attachment")
	attachment.Name = "AuraVfx"
	attachment.Parent = body

	local wisps = Instance.new("ParticleEmitter")
	wisps.Name = "AuraWisps"
	wisps.Color = ColorSequence.new(auraColor)
	wisps.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6 * scale),
		NumberSequenceKeypoint.new(0.5, 2.2 * scale),
		NumberSequenceKeypoint.new(1, 0.3 * scale),
	})
	wisps.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.7, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	wisps.Lifetime = NumberRange.new(1.4, 2.2)
	wisps.Speed = NumberRange.new(1 * scale, 2.4 * scale)
	wisps.SpreadAngle = Vector2.new(180, 180)
	wisps.Rate = 28
	wisps.LightEmission = 0.6
	wisps.LightInfluence = 0
	wisps.Parent = attachment

	-- Bigger, slower-drifting outer haze so the aura reads at a distance too.
	local haze = Instance.new("ParticleEmitter")
	haze.Name = "AuraHaze"
	haze.Color = ColorSequence.new(auraColor)
	haze.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.5 * scale),
		NumberSequenceKeypoint.new(0.6, 4 * scale),
		NumberSequenceKeypoint.new(1, 5.5 * scale),
	})
	haze.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.5, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	haze.Lifetime = NumberRange.new(1.8, 2.6)
	haze.Speed = NumberRange.new(0.2 * scale, 0.6 * scale)
	haze.SpreadAngle = Vector2.new(180, 180)
	haze.Rate = 6
	haze.LightEmission = 0.3
	haze.LightInfluence = 0
	haze.Parent = attachment

	local glow = Instance.new("PointLight")
	glow.Name = "AuraGlow"
	glow.Color = auraColor
	glow.Brightness = 4
	glow.Range = 20 * scale
	glow.Shadows = false
	glow.Parent = attachment
end

function MonsterFeedback.pulseAttack(model: Model)
	-- ScaleTo breaks Motor6D / Bone crawl rigs (spiders go invisible or explode).
	if model:FindFirstChildWhichIsA("Motor6D", true) or model:FindFirstChildWhichIsA("Bone", true) then
		return
	end

	local token = (pulseTokens[model] or 0) + 1
	pulseTokens[model] = token

	local base = baseScales[model]
	if not base then
		base = model:GetScale()
		baseScales[model] = base
	else
		model:ScaleTo(base)
	end

	model:ScaleTo(base * MonsterConfig.ATTACK_PULSE_SCALE)
	local half = MonsterConfig.ATTACK_PULSE_DURATION / 2
	task.delay(half, function()
		if pulseTokens[model] ~= token or not model.Parent then
			return
		end
		model:ScaleTo(base)
		task.delay(half, function()
			if pulseTokens[model] == token then
				pulseTokens[model] = nil
			end
		end)
	end)
end

function MonsterFeedback.flashHit(model: Model, _isFatal: boolean?)
	local parts = visibleParts(model)
	if #parts == 0 then
		return
	end

	cancelHitFlash(model)

	local bases = hitFlashBaseColors[model]
	if not bases then
		bases = {}
		hitFlashBaseColors[model] = bases
		for _, part in parts do
			bases[part] = part.Color
		end
	end

	for _, part in parts do
		if not bases[part] then
			bases[part] = part.Color
		end
		part.Color = MonsterConfig.HIT_FLASH_COLOR
	end

	local tweens: { Tween } = {}
	local remaining = 0
	for _, part in parts do
		local baseColor = bases[part]
		if baseColor then
			remaining += 1
			local tween = TweenService:Create(
				part,
				TweenInfo.new(MonsterConfig.HIT_FLASH_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Color = baseColor }
			)
			table.insert(tweens, tween)
			tween.Completed:Connect(function()
				remaining -= 1
				if remaining <= 0 and activeHitFlashTweens[model] == tweens then
					activeHitFlashTweens[model] = nil
				end
			end)
			tween:Play()
		end
	end
	activeHitFlashTweens[model] = tweens
end

function MonsterFeedback.setFrozen(model: Model, frozen: boolean)
	local parts = visibleParts(model)
	local body = resolveBody(model)
	if #parts == 0 then
		return
	end
	-- Boss / R15 templates may lack a "Body" part — still tint meshes and
	-- parent freeze VFX to PrimaryPart / first visible part.
	local vfxParent = body or parts[1]

	if frozen then
		cancelHitFlash(model)
		if not frozenLooks[model] then
			local colors: { [BasePart]: Color3 } = {}
			local materials: { [BasePart]: Enum.Material } = {}
			local surfaceAppearanceParents: { [SurfaceAppearance]: Instance } = {}
			local meshTextures: { [MeshPart]: string } = {}
			local specialMeshTextures: { [SpecialMesh]: string } = {}

			for _, part in parts do
				colors[part] = part.Color
				materials[part] = part.Material
				if part:IsA("MeshPart") and part.TextureID ~= "" then
					meshTextures[part] = part.TextureID
					part.TextureID = ""
				end
				for _, child in part:GetChildren() do
					if child:IsA("SurfaceAppearance") and child.Parent then
						surfaceAppearanceParents[child] = child.Parent
						child.Parent = nil
					elseif child:IsA("SpecialMesh") and child.TextureId ~= "" then
						specialMeshTextures[child] = child.TextureId
						child.TextureId = ""
					end
				end
			end
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("SurfaceAppearance") and descendant.Parent and surfaceAppearanceParents[descendant] == nil then
					surfaceAppearanceParents[descendant] = descendant.Parent
					descendant.Parent = nil
				end
			end

			frozenLooks[model] = {
				colors = colors,
				materials = materials,
				surfaceAppearanceParents = surfaceAppearanceParents,
				meshTextures = meshTextures,
				specialMeshTextures = specialMeshTextures,
			}
		end

		local ice = MonsterConfig.FREEZE_COLOR
		for _, part in parts do
			part.Color = ice
			part.Material = MonsterConfig.FREEZE_MATERIAL
		end
		local bases = hitFlashBaseColors[model]
		if not bases then
			bases = {}
			hitFlashBaseColors[model] = bases
		end
		for _, part in parts do
			bases[part] = ice
		end
		model:SetAttribute("Frozen", true)
		ensureFreezeVfx(vfxParent)
		ensureFreezeHighlight(model)
	else
		local look = frozenLooks[model]
		if look then
			for part, color in look.colors do
				if part.Parent then
					part.Color = color
					part.Material = look.materials[part] or Enum.Material.SmoothPlastic
				end
			end
			for appearance, parent in look.surfaceAppearanceParents do
				if parent.Parent and appearance.Parent == nil then
					appearance.Parent = parent
				end
			end
			for mesh, textureId in look.meshTextures do
				if mesh.Parent then
					mesh.TextureID = textureId
				end
			end
			for mesh, textureId in look.specialMeshTextures do
				if mesh.Parent then
					mesh.TextureId = textureId
				end
			end
			hitFlashBaseColors[model] = look.colors
			frozenLooks[model] = nil
		end
		model:SetAttribute("Frozen", false)
		clearFreezeVfx(vfxParent)
		clearFreezeHighlight(model)
	end
end

local function getBubbleShell(model: Model): BasePart?
	local shell = model:FindFirstChild("BubbleShell")
	if shell and shell:IsA("BasePart") then
		return shell
	end
	return nil
end

local function syncBubbleShell(model: Model, body: BasePart)
	local shell = getBubbleShell(model)
	if not shell then
		shell = Instance.new("Part")
		shell.Name = "BubbleShell"
		shell.Shape = Enum.PartType.Ball
		shell.Material = Enum.Material.ForceField
		shell.Anchored = true
		shell.CanCollide = false
		shell.CanTouch = false
		shell.CanQuery = false
		shell.CastShadow = false
		shell.Parent = model
	end

	-- Character bounds only (GetExtentsSize includes this shell and grows every tick).
	local size, center = ModelUtil.getVisualSizeAndCenter(model)
	if size.Magnitude < 1e-3 then
		size = body.Size
		center = body.Position
	end
	local pad = MonsterConfig.BUBBLE_SIZE_PADDING
	local diameter = math.max(size.X, size.Y, size.Z) + pad
	shell.Size = Vector3.new(diameter, diameter, diameter)
	shell.CFrame = CFrame.new(center)
	shell.Transparency = MonsterConfig.BUBBLE_TRANSPARENCY
	shell.Color = MonsterConfig.BUBBLE_COLOR
end

local function popBubbleShell(model: Model)
	local shell = getBubbleShell(model)
	if not shell then
		bubbledModels[model] = nil
		poppingBubbles[model] = nil
		return
	end

	if poppingBubbles[model] then
		return
	end
	poppingBubbles[model] = true
	bubbledModels[model] = nil

	local popSize = shell.Size * 1.45
	local tween = TweenService:Create(
		shell,
		TweenInfo.new(MonsterConfig.BUBBLE_POP_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{
			Size = popSize,
			Transparency = 1,
		}
	)
	tween:Play()
	tween.Completed:Connect(function()
		poppingBubbles[model] = nil
		if shell.Parent then
			shell:Destroy()
		end
	end)
end

function MonsterFeedback.setBubbled(model: Model, bubbled: boolean)
	local body = resolveBody(model)
	if not body then
		return
	end

	if bubbled then
		if poppingBubbles[model] then
			return
		end
		bubbledModels[model] = true
		model:SetAttribute("Bubbled", true)
		syncBubbleShell(model, body)
		return
	end

	if not bubbledModels[model] and not getBubbleShell(model) then
		model:SetAttribute("Bubbled", false)
		return
	end

	model:SetAttribute("Bubbled", false)
	popBubbleShell(model)
end

function MonsterFeedback.cleanup(model: Model)
	local base = baseScales[model]
	if base and model.Parent then
		model:ScaleTo(base)
	end
	baseScales[model] = nil
	pulseTokens[model] = nil

	cancelHitFlash(model)
	local bases = hitFlashBaseColors[model]
	if bases then
		for part, color in bases do
			if part.Parent then
				part.Color = color
			end
		end
	end
	hitFlashBaseColors[model] = nil
	frozenLooks[model] = nil
	bubbledModels[model] = nil
	poppingBubbles[model] = nil
	clearFreezeHighlight(model)

	local body = resolveBody(model)
	if body then
		clearFreezeVfx(body)
		local aura = body:FindFirstChild("AuraVfx")
		if aura then
			aura:Destroy()
		end
	end

	local shell = getBubbleShell(model)
	if shell then
		shell:Destroy()
	end
end

return MonsterFeedback
