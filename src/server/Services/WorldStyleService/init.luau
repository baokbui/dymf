--!strict
-- Daytime baseline; WeatherController still owns each client's night/desert lighting.
local Lighting = game:GetService("Lighting")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.WorldStyleConfig)
local Style = require(Shared.Utilities.WorldStyle)
local Service = { Name = "WorldStyleService" }

function Service.init()
	if not Config.ENABLED then return end
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Color = Config.BASEPLATE_COLOR
		Style.applyPart(baseplate, "Ground")
	end
	Lighting.Brightness = Config.DAY_BRIGHTNESS
	Lighting.Ambient = Config.DAY_AMBIENT
	Lighting.OutdoorAmbient = Config.DAY_OUTDOOR_AMBIENT
	Lighting.EnvironmentDiffuseScale = Config.DAY_DIFFUSE
	Lighting.EnvironmentSpecularScale = Config.DAY_SPECULAR
end

return Service
