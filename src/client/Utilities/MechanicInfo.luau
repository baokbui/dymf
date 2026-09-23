--!strict
--[[
	MechanicInfo
	Client-only display text for mechanic / hazard intro popups
	(ProgressConfig.MECHANIC_INTRO_SCHEDULE). Presentation only.
]]

local MechanicInfo = {}

export type MechanicIntroCopy = {
	banner: string,
	title: string,
	summary: string,
	body: string,
}

local INFO: { [string]: MechanicIntroCopy } = {
	Grave = {
		banner = "GRAVES APPEAR!",
		title = "Graves",
		summary = "Fog can hide graves. Monsters crawl out, and most shots stop at the stone.",
		body = "Plant Brr Brr Patapim on a grave to break it.\n\nCappuccino's Piercing Brew flies through graves and hits the monster behind them. It doesn't hurt the grave.",
	},
}

function MechanicInfo.copyFor(id: string): MechanicIntroCopy?
	return INFO[id]
end

return MechanicInfo
