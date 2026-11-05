--!strict
-- Adapt existing feature panels to the shared Menu without moving their logic.
local UITheme = require(game:GetService("ReplicatedStorage").Shared.Config.UITheme)
local Menu = require(script.Parent.Parent.Parent.Utilities.MenuRouter)
local FirstTimeRewards = require(script.Parent.Parent.QuestController.FirstTimeRewards)
local DailySpinHud = require(script.Parent.Parent.QuestController.DailySpinHud)
local MenuPages = {}

function MenuPages.register(main: ScreenGui, panels: any, refreshSettings: () -> ())
	Menu.configure(main, function()
		FirstTimeRewards.close()
		DailySpinHud.close()
		panels.field:hide()
		panels.monster:hide()
		-- A physical Brainrot-shop dialog must close before opening any Menu page.
		if panels.store.frame.Parent == main then panels.store:close() end
	end)
	Menu.register("Inventory", panels.inventory.frame, {
		selfScrolling = true,
		open = function() panels.inventory:setOpen(true) end,
		close = function() panels.inventory:setOpen(false) end,
		detail = panels.inventory.inspect.frame,
		back = function() panels.inventory:hideStats() end,
	})
	Menu.register("Index", panels.index.frame, {
		selfScrolling = true,
		open = function() panels.index:setOpen(true) end,
		close = function() panels.index:setOpen(false) end,
	})
	Menu.register("Upgrades", panels.store.frame, {
		fill = UITheme.UPGRADE_PANEL,
		height = 318,
		selfScrolling = true,
		open = function() panels.store:open(panels.upgradeKind) end,
		close = function() panels.store:close() end,
		detail = panels.store.statsCard,
		back = function() panels.store:hideStats() end,
	})
	Menu.register("Settings", panels.settings.frame, {
		selfScrolling = true,
		open = function() panels.settings:setOpen(true); task.defer(refreshSettings) end,
		close = function() panels.settings:setOpen(false) end,
	})
	Menu.register("Statistics", panels.statistics.frame, {
		selfScrolling = true,
		open = function() panels.statistics.frame.Visible = true; task.defer(refreshSettings) end,
		close = function() panels.statistics.frame.Visible = false end,
	})
end

return MenuPages
