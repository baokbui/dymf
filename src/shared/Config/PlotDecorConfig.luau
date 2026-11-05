--!strict
-- Static garden scenery outside the planting grid. Distances are in studs.
return table.freeze({
	SEED = 48319,
	PATH_WIDTH = 8,
	PATH_OFFSET = 10,
	GARDEN_OFFSET = 24,
	BEDS_PER_SIDE = 3,
	BED_LENGTH = 23,
	BED_DEPTH = 9,
	FLOWERS_PER_BED = 5,
	TREE_SCALE = 0.48,
	BUSH_MODEL_ID = "GardenBush", -- Toolbox asset 8647777369, stored in Assets.Decor
	BUSH_FOOTPRINT = 6,
	BUSH_HEIGHT = 4.2,
	PATH_COLOR = Color3.fromRGB(194, 176, 139),
	EDGE_COLOR = Color3.fromRGB(137, 133, 111),
	SOIL_COLOR = Color3.fromRGB(98, 70, 47),
	WOOD_COLOR = Color3.fromRGB(143, 94, 53),
	LEAF_COLOR = Color3.fromRGB(87, 151, 67),
	FLOWER_COLORS = table.freeze({
		Color3.fromRGB(255, 199, 68),
		Color3.fromRGB(244, 123, 153),
		Color3.fromRGB(175, 144, 245),
		Color3.fromRGB(246, 240, 210),
	}),
})
