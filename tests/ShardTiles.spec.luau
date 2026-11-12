--!strict
-- Production tiles and tooltips in an isolated GUI; no real requests or saves.
return function(module: ModuleScript): string
	local result = Instance.new("BindableEvent")
	local requests = 0
	local tooltip = module.Parent.Parent.Parent.Utilities.ShardTooltip:Clone()
	tooltip.Parent = module.Parent.Parent.Parent.Utilities
	local realRequire = require
	local chunk = assert(loadstring(module.Source))
	setfenv(chunk, setmetatable({ script = module, require = function(dependency)
		if dependency.Name == "ShardTooltip" then return realRequire(tooltip) end
		if dependency.Name == "Remotes" then return { getEvent = function()
			return { OnClientEvent = result.Event, FireServer = function() requests += 1 end }
		end } end
		return realRequire(dependency)
	end }, { __index = getfenv() }))
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.Parent = "ShardTileFixture", game.StarterGui
	local host = Instance.new("Frame")
	host.Size, host.Parent = UDim2.fromOffset(600, 400), gui
	local list = Instance.new("ScrollingFrame")
	list.Size, list.CanvasSize, list.Parent = UDim2.fromScale(1, 1), UDim2.new(), host
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	local layout = Instance.new("UIListLayout")
	layout.Parent = list
	local update = chunk().new(list)
	local previous = game.GuiService.SelectedObject
	local ok, failure = pcall(function()
		assert(update({ monsterShards = { Zombie = 3, Goblin = 4, Vampire = 1, GoblinElite = 2, PharaohMummy = 1, Spider = 4 } }))
		task.wait()
		local tiles = list.ShardTiles
		local tile = tiles.ZombieShards
		assert(tile:FindFirstChild("Name").Text == "Zombie", "Tile should show only the species name")
		assert(tile:FindFirstChild("ShardIcon") and not tile:FindFirstChild("ShardProgress"))
		assert(tile.Size.X.Offset == 76 and tile.Size.Y.Offset == 76, "Shard tile is not compact")
		assert(tile.Quantity.Text == "3 / 15" and tile.ShardIcon:FindFirstChild("MonsterPortrait"))
		assert(tile.ShardIcon.CrystalOverlay.ZIndex > tile.ShardIcon.MonsterPortrait.ZIndex, "Shard glass must overlap the portrait")
		local icon = tile.ShardIcon
		local portrait = icon.MonsterPortrait
		assert(portrait.ClipsDescendants, "Portrait must be clipped")
		local half = portrait.AbsoluteSize / 2
		local center = portrait.AbsolutePosition + half
		local crystalCenter = icon.AbsolutePosition + Vector2.new(icon.AbsoluteSize.X * 0.5, icon.AbsoluteSize.Y * 0.47)
		local delta = center - crystalCenter
		local radius = icon.AbsoluteSize.X * 0.59 * 0.86 / math.sqrt(2)
		assert(math.abs(delta.X) + math.abs(delta.Y) + half.X + half.Y < radius, "Portrait corners protrude beyond the shard")
		assert(not host.ShardTooltip.Visible)
		game.GuiService.SelectedObject = tile
		task.wait()
		local tip = host.ShardTooltip
		assert(tip.Visible and tip.OwnedNeeded.Text == "3 / 15 shards")
		assert(tip.Description.Text == "Combine shards to form a Zombie.")
		assert(not tip.Combine.Visible and requests == 0, "Inspecting a tile must not combine")
		update({ monsterShards = { Zombie = 15 } })
		assert(tile.Quantity.Text == "15 / 15")
		assert(tip.OwnedNeeded.Text == "15 / 15 shards" and tip.Combine.Visible and tip.Combine.Active)
		task.wait()
		local wideHeight = tiles.Size.Y.Offset
		update({ monsterShards = { Zombie = 3, Goblin = 4, Vampire = 1, GoblinElite = 2, PharaohMummy = 1, Spider = 4 } })
		host.Size = UDim2.fromOffset(240, 400)
		task.wait(); task.wait()
		assert(tiles.Size.Y.Offset > wideHeight, "Narrow layout did not wrap tiles")
		assert(not tip.Visible, "Resizing must close the old tooltip")
		assert(not update({ monsterShards = {} }), "Empty inventory should hide the shard section")
		assert(not tiles.Visible)
	end)
	game.GuiService.SelectedObject = previous
	gui:Destroy(); result:Destroy(); tooltip:Destroy()
	assert(ok, failure)
	return "Compact names/icons, inspection-only tooltip, live counts, combine gate, wrapping and empty state passed"
end
