--!strict
local Config = {}
Config.TIERS = table.freeze({
	{ id = "Tiny", level = 1, scale = 0.45, income = 0.25 },
	{ id = "Small", level = 2, scale = 0.7, income = 0.5 },
	{ id = "Medium", level = 3, scale = 1, income = 1 },
	{ id = "Big", level = 5, scale = 1.35, income = 1.75 },
	{ id = "Gigantic", level = 8, scale = 1.7, income = 3 },
	{ id = "Titanic", level = 12, scale = 2.1, income = 5 },
})
-- Percentages, in tier order. Every recipe can produce any tier.
Config.COMBINE_WEIGHTS = table.freeze({ 45, 30, 18, 5, 1.7, 0.3 })
Config.FUSION_WEIGHTS = table.freeze({
	[3] = table.freeze({ 35, 28, 22, 10, 4, 1 }),
	[4] = table.freeze({ 28, 25, 24, 15, 6, 2 }),
	[5] = table.freeze({ 20, 22, 25, 20, 9, 4 }),
})
Config.RECEIPT_LIMIT = 24
return table.freeze(Config)
