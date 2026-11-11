--!strict
-- UI action fixture with isolated controls and remotes. Exercises actual callbacks.
return function(source: string, context: Instance, rules: any): string
	local function signal()
		local callbacks = {}
		return {
			Connect = function(_, callback)
				table.insert(callbacks, callback)
				return { Disconnect = function() table.remove(callbacks, table.find(callbacks, callback)) end }
			end,
			Once = function(self, callback) return self:Connect(callback) end,
			Fire = function(_, ...) for _, callback in table.clone(callbacks) do callback(...) end end,
		}
	end
	local function gui(class)
		local properties = { Name = class, children = {}, Activated = signal(), Destroying = signal() }
		local object
		local methods = {
			FindFirstChild = function(_, name)
				for _, child in properties.children do if child.Name == name then return child end end
			end,
			Destroy = function() object.Destroying:Fire(); object.Parent = nil end,
			Clone = function()
				local clone = gui(class)
				for key, value in properties do
					if key ~= "Parent" and key ~= "children" and key ~= "Activated" and key ~= "Destroying" then clone[key] = value end
				end
				return clone
			end,
		}
		object = setmetatable({}, {
			__index = function(_, key) return methods[key] or properties[key] end,
			__newindex = function(_, key, value)
				if key == "Parent" then
					if properties.Parent then
						local index = table.find(properties.Parent.children, object)
						if index then table.remove(properties.Parent.children, index) end
					end
					if value then table.insert(value.children, object) end
				end
				properties[key] = value
			end,
		})
		return object
	end
	local events, request = {}, nil
	local remotes = { getEvent = function(name)
		if not events[name] then events[name] = signal() end
		return { OnClientEvent = events[name], FireServer = function(_, ...) request = { name = name, args = { ... } } end }
	end }
	local realRequire = require
	local chunk = assert(loadstring(source))
	setfenv(chunk, setmetatable({
		script = context,
		Instance = { new = gui },
		task = { delay = function() end },
		require = function(module)
			if module.Name == "Remotes" then return remotes end
			if module.Name == "UITheme" then return setmetatable({}, { __index = function() return function() end end }) end
			return rules[module.Name] or realRequire(module)
		end,
	}, { __index = getfenv() }))
	local list = gui("ScrollingFrame")
	local refresh = chunk().new(list)
	local profile = { farmMonsters = {} }
	for index = 1, 5 do table.insert(profile.farmMonsters, { uid = "z" .. index, monsterId = "Zombie", tier = "Tiny" }) end
	table.insert(profile.farmMonsters, { uid = "g1", monsterId = "Goblin", tier = "Medium" })
	refresh(profile)
	local header = list:FindFirstChild("MonsterFusion")
	local fuse = header:FindFirstChild("Fuse")
	assert(not fuse.Active)
	for index = 1, 3 do list:FindFirstChild("FarmMonster_z" .. index).Activated:Fire() end
	assert(fuse.Active and fuse.Text == "Fuse (3/5)")
	assert(not list:FindFirstChild("FarmMonster_g1").Active, "mixed species selection was enabled")
	for index = 4, 5 do list:FindFirstChild("FarmMonster_z" .. index).Activated:Fire() end
	assert(fuse.Text == "Fuse (5/5)")
	fuse.Activated:Fire()
	assert(request.name == "FuseFarmMonsters" and #request.args[1] == 5 and type(request.args[2]) == "string")
	assert(not fuse.Active and not header:FindFirstChild("ClearSelection").Active)
	profile.farmMonsters = { profile.farmMonsters[6], { uid = "output", monsterId = "Zombie", tier = "Titanic" } }
	refresh(profile)
	events.MonsterFusionResult:Fire({ success = true, operation = request.args[2], monster = profile.farmMonsters[2] })
	assert(list:FindFirstChild("FarmMonster_output") and not list:FindFirstChild("FarmMonster_z1"))
	assert(not fuse.Active and fuse.Text == "Fuse (0/5)")
	return "Fusion UI selects exact 3–5 inputs, excludes mixed species, sends operation id, locks during save and displays the committed result"
end
