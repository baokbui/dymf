--!strict
-- Isolated projectile module and plots; never touches a running battle.
return function(): string
	local module = game.ServerScriptService.Server.Services.CombatService.Projectile:Clone()
	module.Parent = game.ServerScriptService.Server.Services.CombatService
	local projectiles = require(module)
	local a, b = Instance.new("Model"), Instance.new("Model")
	a:SetAttribute("OwnerUserId", 991001)
	b:SetAttribute("OwnerUserId", 991002)
	local function position(part, _, row, column, y) part.Position = Vector3.new(column, y, row) end
	local function launch(plot, owner)
		projectiles.launch({ plotModel = plot, row = 1, startColumn = 1, targetColumn = 2,
			targetInstanceId = "fixture", damage = 1, ownerUserId = owner }, 0, position)
	end
	local ok, result = xpcall(function()
		launch(a, 991001); launch(b, 991002)
		assert(#a.Projectiles:GetChildren() > 0 and #b.Projectiles:GetChildren() > 0)
		projectiles.destroyAllOnPlot(a)
		assert(#a.Projectiles:GetChildren() == 0 and #b.Projectiles:GetChildren() > 0,
			"Pause projectile removal crossed plots")
		local impacts = 0
		projectiles.tick(10, function() return 2 end, position, function() impacts += 1; return true end)
		assert(impacts == 1, "Removed projectile still caused an impact")
		return "Per-plot projectile removal and no post-removal impact passed"
	end, debug.traceback)
	projectiles.destroyAllOnPlot(a); projectiles.destroyAllOnPlot(b)
	a:Destroy(); b:Destroy(); module:Destroy()
	assert(ok, result)
	return result
end
