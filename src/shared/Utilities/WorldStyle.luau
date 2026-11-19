--!strict
-- One material assignment per eligible part; no physical studs or runtime loops.
local Shared = script.Parent.Parent
local Config = require(Shared.Config.WorldStyleConfig)
local MaterialService = game:GetService("MaterialService")
local WorldStyle = {}
export type Kind = "Ground" | "Scenery" | "Unit"
local variants = { Ground = Config.GROUND_VARIANT, Scenery = Config.SCENERY_VARIANT, Unit = Config.UNIT_VARIANT }
local managed = { [Config.GROUND_VARIANT] = true, [Config.SCENERY_VARIANT] = true, [Config.UNIT_VARIANT] = true }
local preserve = {
	[Enum.Material.Neon] = true, [Enum.Material.Glass] = true,
	[Enum.Material.ForceField] = true, [Enum.Material.Ice] = true,
}

function WorldStyle.applyPart(part: BasePart, kind: Kind): boolean
	if not Config.ENABLED or part.Transparency >= 0.95 or part:GetAttribute("KeepAuthoredMaterial") == true then return false end
	if preserve[part.Material] then return false end
	if part.MaterialVariant ~= "" and not managed[part.MaterialVariant] then
		local authored = MaterialService:FindFirstChild(part.MaterialVariant)
		if authored and authored:IsA("MaterialVariant") and authored.BaseMaterial == part.Material then return false end
	end
	-- Imported artwork/face atlases need their own UV-authored retexture. Keep it intact.
	if part:IsA("MeshPart") and part.TextureID ~= "" then return false end
	if part:FindFirstChildOfClass("SurfaceAppearance") then return false end
	local mesh = part:FindFirstChildOfClass("SpecialMesh")
	if mesh and mesh.TextureId ~= "" then return false end
	if part.Material == Config.MATERIAL and part.MaterialVariant == variants[kind] then return true end
	-- Material changes must not alter friction, density or other physical behavior.
	if part.CustomPhysicalProperties == nil then part.CustomPhysicalProperties = part.CurrentPhysicalProperties end
	part.Material = Config.MATERIAL
	part.MaterialVariant = variants[kind]
	part.Reflectance = 0
	return true
end

function WorldStyle.apply(root: Instance, kind: Kind)
	if not Config.ENABLED or root:GetAttribute("KeepAuthoredMaterial") == true then return end
	if root:IsA("BasePart") then WorldStyle.applyPart(root, kind) end
	for _, item in root:GetDescendants() do
		if not item:IsA("BasePart") then continue end
		local ancestor = item.Parent
		local excluded = false
		while ancestor and ancestor ~= root do
			if ancestor:GetAttribute("KeepAuthoredMaterial") == true then excluded = true; break end
			ancestor = ancestor.Parent
		end
		if not excluded then WorldStyle.applyPart(item, kind) end
	end
end

-- Only game-owned scenery/unit templates are styled; projectiles and graves keep their looks.
function WorldStyle.templateKind(template: Instance): Kind?
	local assets = Shared.Parent:FindFirstChild("Assets")
	if not assets then return nil end
	local parent = template.Parent
	while parent and parent.Parent ~= assets do parent = parent.Parent end
	if not parent then return nil end
	if parent.Name == "Brainrots" or parent.Name == "Monsters" then return "Unit" end
	if parent.Name == "Houses" or parent.Name == "Stores" or parent.Name == "Decor" then return "Scenery" end
	return nil
end

return WorldStyle
