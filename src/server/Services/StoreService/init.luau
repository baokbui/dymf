--!strict
--[[
	StoreService
	Clones mini-store templates beside each plot house and wires Talk prompts.
	Purchases stay on ProgressService.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local StoreConfig = require(Shared.Config.StoreConfig)
local Remotes = require(Shared.Remotes)
local Logger = require(Shared.Utilities.Logger)
local ModelUtil = require(Shared.Utilities.ModelUtil)

local StoreService = {}
StoreService.Name = "StoreService"

local log = Logger.new(StoreService.Name)
local templatesReady = false
local missingLogged = false

local function mascotMatches(root: Instance, name: string): boolean
	local want = string.lower(name)
	if string.lower(root.Name) == want then
		return true
	end
	for _, descendant in root:GetDescendants() do
		if string.lower(descendant.Name) == want then
			return true
		end
	end
	return false
end

local function findMascot(root: Instance, name: string): Model?
	local want = string.lower(name)
	local inst: Instance? = root:FindFirstChild(name, true)
	if not inst then
		for _, descendant in root:GetDescendants() do
			if string.lower(descendant.Name) == want then
				inst = descendant
				break
			end
		end
	end
	if inst and inst:IsA("Model") then
		return inst
	end
	if inst and inst:IsA("BasePart") then
		local parent = inst.Parent
		if parent and parent:IsA("Model") then
			return parent
		end
	end
	return nil
end

local function promptPart(model: Model): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function attachPrompt(mascot: Model, shopKind: string, objectText: string)
	local part = promptPart(mascot)
	if not part then
		log:warn("store mascot has no part", mascot:GetFullName())
		return
	end
	local existing = part:FindFirstChild("ProgressionStorePrompt")
	if existing then
		existing:Destroy()
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ProgressionStorePrompt"
	prompt.ActionText = StoreConfig.PROMPT_ACTION
	prompt.ObjectText = objectText
	prompt.HoldDuration = StoreConfig.PROMPT_HOLD
	prompt.MaxActivationDistance = StoreConfig.PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player: Player)
		Remotes.getEvent("OpenProgressionStore"):FireClient(player, shopKind)
	end)
end

local function ensureAssetsFolder(): Folder
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		assets = Instance.new("Folder")
		assets.Name = "Assets"
		assets.Parent = ReplicatedStorage
	end
	local stores = assets:FindFirstChild(StoreConfig.ASSETS_FOLDER)
	if not (stores and stores:IsA("Folder")) then
		stores = Instance.new("Folder")
		stores.Name = StoreConfig.ASSETS_FOLDER
		stores.Parent = assets
	end
	return stores :: Folder
end

-- Prefer Assets.Stores; otherwise move Workspace.Progression Stores models there
-- so they are templates, not a single world shop.
local function adoptWorkspaceTemplates()
	local dest = ensureAssetsFolder()
	local src = Workspace:FindFirstChild(StoreConfig.WORKSPACE_FOLDER)
	if not src then
		return
	end
	for _, child in src:GetChildren() do
		if child:IsA("Model") and not dest:FindFirstChild(child.Name) then
			child.Parent = dest
		end
	end
	src:Destroy()
end

local function templateByMascot(folder: Folder?, mascotName: string): Model?
	if not folder then
		return nil
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and mascotMatches(child, mascotName) then
			return child
		end
	end
	return nil
end

local function resolveTemplate(modelId: string, mascotName: string): Model?
	local named = ModelUtil.findStoreTemplate(modelId)
	if named then
		return named
	end
	return templateByMascot(ModelUtil.getStoreTemplatesFolder(), mascotName)
end

local function placeStore(
	template: Model,
	parent: Instance,
	name: string,
	worldPos: Vector3,
	shopKind: string,
	mascotName: string,
	objectText: string
)
	local clone = ModelUtil.cloneTemplate(template, {
		faceDirection = StoreConfig.FACE_DIRECTION,
		orientationDegrees = StoreConfig.MODEL_ORIENTATION_DEGREES,
		keepCollision = true,
		skipBodyAlias = true,
	})
	clone.Name = name
	ModelUtil.snapFeetToTileTop(clone, worldPos)
	clone.Parent = parent
	local mascot = findMascot(clone, mascotName) or clone
	attachPrompt(mascot, shopKind, objectText)
end

function StoreService.attachToHouse(plotModel: Model, house: Model)
	adoptWorkspaceTemplates()
	templatesReady = true

	local brainrotTemplate = resolveTemplate(StoreConfig.BRAINROT_STORE_MODEL_ID, StoreConfig.BRAINROT_MASCOT_NAME)
	local upgradeTemplate = resolveTemplate(StoreConfig.UPGRADE_STORE_MODEL_ID, StoreConfig.UPGRADE_MASCOT_NAME)
	if not brainrotTemplate and not upgradeTemplate then
		if not missingLogged then
			missingLogged = true
			log:warn("no store templates in Assets.Stores (or Workspace.Progression Stores)")
		end
		return
	end

	local existing = plotModel:FindFirstChild(StoreConfig.PLOT_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = StoreConfig.PLOT_FOLDER_NAME
	folder.Parent = plotModel

	local size, center = ModelUtil.getVisualSizeAndCenter(house)
	local grassY = center.Y - size.Y * 0.5
	local frontX = center.X + size.X * 0.5
	local origin = Vector3.new(frontX + StoreConfig.YARD_OFFSET_X, grassY, center.Z + StoreConfig.DOOR_RIGHT_Z)
	local face = Vector3.new(StoreConfig.FACE_DIRECTION.X, 0, StoreConfig.FACE_DIRECTION.Z)
	if face.Magnitude < 1e-4 then
		face = Vector3.new(1, 0, 0)
	else
		face = face.Unit
	end
	-- After template yaw −90, FACE is stall width (not depth). Offset along
	-- FACE so Upgrades sits beside Brainrots instead of behind it.
	local along = face
	if along.Z > 0 then
		along = -along
	end
	local spacing = along * StoreConfig.STORE_SPACING

	if brainrotTemplate then
		placeStore(
			brainrotTemplate,
			folder,
			StoreConfig.BRAINROT_STORE_MODEL_ID,
			origin,
			StoreConfig.SHOP_BRAINROTS,
			StoreConfig.BRAINROT_MASCOT_NAME,
			StoreConfig.BRAINROT_PROMPT_OBJECT
		)
	end
	if upgradeTemplate then
		placeStore(
			upgradeTemplate,
			folder,
			StoreConfig.UPGRADE_STORE_MODEL_ID,
			origin + spacing,
			StoreConfig.SHOP_UPGRADES,
			StoreConfig.UPGRADE_MASCOT_NAME,
			StoreConfig.UPGRADE_PROMPT_OBJECT
		)
	end
end

function StoreService.init()
end

function StoreService.start()
	adoptWorkspaceTemplates()
	log:info("started")
end

return StoreService
