--!strict
--[[
	WeatherController
	Client-only weather presentation for the local player's current day:
	night lighting + a cheap, always-visible fog bank over the east lawn and
	forest (NightFog). Desert days swap that for sand lighting, hidden forest,
	and pyramids (DesertVisuals). Planting rules are enforced on the server.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GridConfig = require(Shared.Config.GridConfig)
local PlotConfig = require(Shared.Config.PlotConfig)
local WeatherConfig = require(Shared.Config.WeatherConfig)
local Remotes = require(Shared.Remotes)
local Logger = require(Shared.Utilities.Logger)
local WeatherUtil = require(Shared.Utilities.WeatherUtil)

local PlotUtil = require(script.Parent.Parent.Utilities.PlotUtil)
local DesertVisuals = require(script:WaitForChild("DesertVisuals"))

local WeatherController = {}
WeatherController.Name = "WeatherController"

local log = Logger.new(WeatherController.Name)

local currentWeather: string? = nil
local fogFolder: Folder? = nil
local savedLighting: { [string]: any }? = nil
local atmosphere: Atmosphere? = nil

local function captureLighting()
	if savedLighting then
		return
	end
	savedLighting = {
		ClockTime = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		ColorShift_Top = Lighting.ColorShift_Top,
		ColorShift_Bottom = Lighting.ColorShift_Bottom,
		FogStart = Lighting.FogStart,
		FogEnd = Lighting.FogEnd,
		FogColor = Lighting.FogColor,
	}
end

local function restoreLighting()
	local saved = savedLighting
	if not saved then
		return
	end
	Lighting.ClockTime = saved.ClockTime
	Lighting.Brightness = saved.Brightness
	Lighting.Ambient = saved.Ambient
	Lighting.OutdoorAmbient = saved.OutdoorAmbient
	Lighting.ColorShift_Top = saved.ColorShift_Top
	Lighting.ColorShift_Bottom = saved.ColorShift_Bottom
	Lighting.FogStart = saved.FogStart
	Lighting.FogEnd = saved.FogEnd
	Lighting.FogColor = saved.FogColor
	savedLighting = nil

	if atmosphere then
		atmosphere:Destroy()
		atmosphere = nil
	end
end

local function applyNightLighting()
	captureLighting()
	Lighting.ClockTime = WeatherConfig.NIGHT_CLOCK_TIME
	Lighting.Brightness = WeatherConfig.NIGHT_BRIGHTNESS
	Lighting.Ambient = WeatherConfig.NIGHT_AMBIENT
	Lighting.OutdoorAmbient = WeatherConfig.NIGHT_OUTDOOR_AMBIENT
	Lighting.ColorShift_Top = WeatherConfig.NIGHT_COLOR_SHIFT_TOP
	Lighting.ColorShift_Bottom = WeatherConfig.NIGHT_COLOR_SHIFT_BOTTOM
	Lighting.FogStart = WeatherConfig.NIGHT_FOG_START
	Lighting.FogEnd = WeatherConfig.NIGHT_FOG_END
	Lighting.FogColor = WeatherConfig.NIGHT_FOG_COLOR

	if not atmosphere then
		local existing = Lighting:FindFirstChildOfClass("Atmosphere")
		atmosphere = if existing then existing else Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = WeatherConfig.NIGHT_ATMOSPHERE_DENSITY
	atmosphere.Offset = WeatherConfig.NIGHT_ATMOSPHERE_OFFSET
	atmosphere.Color = WeatherConfig.NIGHT_FOG_COLOR
	atmosphere.Decay = Color3.fromRGB(70, 80, 120)
	atmosphere.Glare = WeatherConfig.NIGHT_ATMOSPHERE_GLARE
	atmosphere.Haze = WeatherConfig.NIGHT_ATMOSPHERE_HAZE
end

local function applyDesertLighting()
	captureLighting()
	Lighting.ClockTime = WeatherConfig.DESERT_CLOCK_TIME
	Lighting.Brightness = WeatherConfig.DESERT_BRIGHTNESS
	Lighting.Ambient = WeatherConfig.DESERT_AMBIENT
	Lighting.OutdoorAmbient = WeatherConfig.DESERT_OUTDOOR_AMBIENT
	Lighting.ColorShift_Top = WeatherConfig.DESERT_COLOR_SHIFT_TOP
	Lighting.ColorShift_Bottom = WeatherConfig.DESERT_COLOR_SHIFT_BOTTOM
	Lighting.FogStart = WeatherConfig.DESERT_FOG_START
	Lighting.FogEnd = WeatherConfig.DESERT_FOG_END
	Lighting.FogColor = WeatherConfig.DESERT_FOG_COLOR

	if not atmosphere then
		local existing = Lighting:FindFirstChildOfClass("Atmosphere")
		atmosphere = if existing then existing else Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = WeatherConfig.DESERT_ATMOSPHERE_DENSITY
	atmosphere.Offset = WeatherConfig.DESERT_ATMOSPHERE_OFFSET
	atmosphere.Color = WeatherConfig.DESERT_ATMOSPHERE_COLOR
	atmosphere.Decay = WeatherConfig.DESERT_ATMOSPHERE_DECAY
	atmosphere.Glare = WeatherConfig.DESERT_ATMOSPHERE_GLARE
	atmosphere.Haze = WeatherConfig.DESERT_ATMOSPHERE_HAZE
end

local function clearFogFolder()
	if fogFolder then
		fogFolder:Destroy()
		fogFolder = nil
	end
end

local function addLightMist(part: BasePart, rate: number, densityScale: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "FogMist"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(WeatherConfig.FOG_PARTICLE_COLOR)
	local particleSize = WeatherConfig.FOG_PARTICLE_SIZE * (0.85 + 0.2 * densityScale)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, particleSize * 0.7),
		NumberSequenceKeypoint.new(0.5, particleSize),
		NumberSequenceKeypoint.new(1, particleSize * 1.35),
	})
	-- Higher densityScale → denser (less transparent) mist.
	local startT = math.clamp(0.42 - 0.22 * densityScale, 0.08, 0.55)
	local midT = math.clamp(0.58 - 0.2 * densityScale, 0.2, 0.75)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, startT),
		NumberSequenceKeypoint.new(0.5, midT),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(
		WeatherConfig.FOG_PARTICLE_LIFETIME * 0.7,
		WeatherConfig.FOG_PARTICLE_LIFETIME
	)
	emitter.Speed = NumberRange.new(0.05, 0.35)
	emitter.RotSpeed = NumberRange.new(-8, 8)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Rate = rate
	emitter.LightEmission = WeatherConfig.FOG_PARTICLE_LIGHT_EMISSION
	emitter.LightInfluence = WeatherConfig.FOG_PARTICLE_LIGHT_INFLUENCE
	emitter.LockedToPart = false
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Orientation = Enum.ParticleOrientation.FacingCamera
	emitter.Parent = part
end

-- Invisible emission volume + soft particle mist (no translucent box mesh).
local function makeFogBank(
	name: string,
	cframe: CFrame,
	size: Vector3,
	parent: Instance,
	rate: number,
	densityScale: number
)
	local bank = Instance.new("Part")
	bank.Name = name
	bank.Anchored = true
	bank.CanCollide = false
	bank.CanQuery = false
	bank.CanTouch = false
	bank.CastShadow = false
	bank.Material = Enum.Material.SmoothPlastic
	bank.Transparency = 1
	bank.Size = size
	bank.CFrame = cframe
	bank.Parent = parent
	addLightMist(bank, rate, densityScale)
end

local function buildFogVolumes(plotModel: Model)
	clearFogFolder()
	local folder = Instance.new("Folder")
	folder.Name = "ClientWeatherFog"
	folder.Parent = plotModel
	fogFolder = folder

	local tileSize = PlotConfig.TILE_SIZE
	local startCol = WeatherConfig.fogStartColumn(currentWeather)
	local height = WeatherConfig.FOG_HEIGHT_STUDS
	local centerHeight = WeatherConfig.FOG_CENTER_HEIGHT_STUDS

	-- Light mist over the fog lawn columns (closest to the playable plot).
	local west = PlotUtil.getTileTopCenter(plotModel, 1, startCol)
	local east = PlotUtil.getTileTopCenter(plotModel, GridConfig.ROWS, GridConfig.COLUMNS)
	if west and east then
		local minX = math.min(west.X, east.X) - tileSize * 0.5
		local maxX = math.max(west.X, east.X) + tileSize * 0.5
		local minZ = math.min(west.Z, east.Z) - tileSize * 0.5
		local maxZ = math.max(west.Z, east.Z) + tileSize * 0.5
		local groundY = (west.Y + east.Y) * 0.5
		local size = Vector3.new(maxX - minX, height, maxZ - minZ)
		local center = Vector3.new((minX + maxX) * 0.5, groundY + centerHeight, (minZ + maxZ) * 0.5)
		makeFogBank(
			"LawnFog",
			CFrame.new(center),
			size,
			folder,
			WeatherConfig.FOG_LAWN_PARTICLE_RATE,
			0.8
		)
	end

	-- Forest: denser deep east, lighter near the lawn edge.
	local edge = PlotUtil.getTileTopCenter(plotModel, math.ceil(GridConfig.ROWS / 2), GridConfig.COLUMNS)
	if edge then
		local depth = WeatherConfig.forestFogDepthFromLawnEdge()
		local base = plotModel.PrimaryPart
		local stripZ = if base then base.Size.Z else PlotConfig.BASE_DEPTH
		local centerZ = if base then base.Position.Z else edge.Z
		local forestStartX = edge.X + tileSize * 0.5
		local nearDepth = depth * WeatherConfig.FOG_FOREST_NEAR_DEPTH_FRACTION
		local deepDepth = depth - nearDepth
		local bankHeight = height * 1.15

		makeFogBank(
			"ForestFogNear",
			CFrame.new(forestStartX + nearDepth * 0.5, edge.Y + centerHeight, centerZ),
			Vector3.new(nearDepth, bankHeight, stripZ),
			folder,
			WeatherConfig.FOG_FOREST_NEAR_PARTICLE_RATE,
			1.2
		)
		makeFogBank(
			"ForestFogDeep",
			CFrame.new(forestStartX + nearDepth + deepDepth * 0.5, edge.Y + centerHeight, centerZ),
			Vector3.new(deepDepth, bankHeight * 1.1, stripZ),
			folder,
			WeatherConfig.FOG_FOREST_DEEP_PARTICLE_RATE,
			1.6
		)
	end
end

local function clearWeatherVisuals()
	clearFogFolder()
	DesertVisuals.clear()
	restoreLighting()
end

local function applyWeatherVisuals(weather: string?)
	if weather == currentWeather then
		local plot = PlotUtil.getLocalPlotModel()
		if WeatherUtil.isNightFog(weather) then
			if plot and (not fogFolder or fogFolder.Parent ~= plot) then
				buildFogVolumes(plot)
			end
		elseif WeatherUtil.isDesert(weather) and plot then
			local ok, err = pcall(DesertVisuals.apply, plot)
			if not ok then
				log:warn("desert visuals failed", err)
			end
		end
		return
	end

	clearWeatherVisuals()
	currentWeather = weather

	if WeatherUtil.isDesert(weather) then
		applyDesertLighting()
		local plot = PlotUtil.getLocalPlotModel()
		if plot then
			local ok, err = pcall(DesertVisuals.apply, plot)
			if not ok then
				log:warn("desert visuals failed", err)
			end
		end
		return
	end

	if not WeatherUtil.isNight(weather) then
		return
	end

	applyNightLighting()
	if not WeatherUtil.isNightFog(weather) then
		return
	end

	local plot = PlotUtil.getLocalPlotModel()
	if plot then
		buildFogVolumes(plot)
	end
end

function WeatherController.getWeather(): string?
	return currentWeather
end

function WeatherController.setWeather(weather: string?)
	applyWeatherVisuals(if type(weather) == "string" then weather else nil)
end

function WeatherController.init()
end

function WeatherController.start()
	Remotes.getEvent("LevelStateChanged").OnClientEvent:Connect(function(state: unknown)
		if type(state) ~= "table" then
			return
		end
		local data = state :: { [string]: any }
		WeatherController.setWeather(if type(data.weather) == "string" then data.weather else nil)
	end)

	task.spawn(function()
		local ok, state = pcall(function()
			return Remotes.getFunction("RequestState"):InvokeServer()
		end)
		if ok and type(state) == "table" and type(state.level) == "table" then
			local level = state.level :: { [string]: any }
			WeatherController.setWeather(if type(level.weather) == "string" then level.weather else nil)
		end
		for _ = 1, 40 do
			local plot = PlotUtil.getLocalPlotModel()
			if plot then
				if WeatherUtil.isNightFog(currentWeather) and (not fogFolder or fogFolder.Parent ~= plot) then
					buildFogVolumes(plot)
				elseif WeatherUtil.isDesert(currentWeather) then
					local applied, err = pcall(DesertVisuals.apply, plot)
					if not applied then
						log:warn("desert visuals failed", err)
					end
				end
				break
			end
			task.wait(0.25)
		end
	end)

	log:info("started")
end

return WeatherController
