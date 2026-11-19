--!strict
-- Studded toy-world art direction. PBR instances/maps live in default.project.json.
return table.freeze({
	ENABLED = true,
	GROUND_VARIANT = "BvmStudsGround",
	SCENERY_VARIANT = "BvmStudsScenery",
	UNIT_VARIANT = "BvmStudsUnits",
	MATERIAL = Enum.Material.Plastic,
	BASEPLATE_COLOR = Color3.fromRGB(103, 199, 48),
	DAY_BRIGHTNESS = 2.5,
	DAY_AMBIENT = Color3.fromRGB(92, 105, 125),
	DAY_OUTDOOR_AMBIENT = Color3.fromRGB(145, 158, 177),
	DAY_DIFFUSE = 0.7,
	DAY_SPECULAR = 0.35,
})
