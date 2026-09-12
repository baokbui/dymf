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
		summary = "Fog tiles can hide graves. Monsters crawl out, and most Brainrot shots stop at the stone.",
		body = "Destroy a grave by planting Brr Brr Patapim (Grave Buster) on it.\n\nCappuccino Assassino's Piercing Brew (Legendary evolution) flies through and hits the monster behind it. That shot does not damage the grave.",
	},
}

function MechanicInfo.copyFor(id: string): MechanicIntroCopy?
	return INFO[id]
end

return MechanicInfo
