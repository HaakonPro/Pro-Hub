-- ===== games/MoneySimulatorX.lua =====
local MoneySimulatorX = {}
local Version = 2.1

function MoneySimulatorX.Init(Window, Rayfield, IsActiveSession)
	local Tabs = {
		FarmTab = Window:CreateTab("Farm"),
		Upgrades = Window:CreateTab("Upgrades"),
		Crafting = Window:CreateTab("Crafting"),
		Misc = Window:CreateTab("Misc"),
		Info = Window:CreateTab("Info"),
	}

	Tabs.FarmTab:CreateToggle({
		Name = "Autoclick Money",
		CurrentValue = false,
		Flag = "AutoClickMoney",
		Callback = function(Value)
			if Value then
				task.spawn(function()
					while Rayfield.Flags["AutoClickMoney"].CurrentValue and IsActiveSession() do
						game:GetService("ReplicatedStorage").GetMoney:FireServer("DropOff", 0)
						task.wait(0.01)
					end
				end)
			end
		end,
	})

	-- upgrades

	local function FireUpgrade(spec)
		if type(spec) == "string" then
			local remote = game.ReplicatedStorage:FindFirstChild(spec)
			if remote then
				remote:FireServer()
			end
		elseif type(spec) == "table" then
			local remote = game.ReplicatedStorage:FindFirstChild(spec.Remote)
			if remote then
				remote:FireServer(table.unpack(spec.Args or {}))
			end
		end
	end

	local function CreateUpgradeDropdown(Tab, config)
		local selected = {}
		local loopStarted = false
		local interval = config.Interval or 0.1

		Tab:CreateDropdown({
			Name = config.Name,
			Options = config.Options,
			CurrentOption = {},
			MultipleOptions = true,
			Flag = config.Flag,
			Callback = function(Options)
				-- Options comes in as an ARRAY of selected strings (e.g. {"Power","Bag"}),
				-- not a dict — convert it to a set so `selected[optionName]` lookups work.
				local set = {}
				for _, name in ipairs(Options) do
					set[name] = true
				end
				selected = set

				if not loopStarted then
					loopStarted = true
					task.spawn(function()
						while IsActiveSession() do
							for optionName, spec in pairs(config.Remotes) do
								if selected[optionName] then
									FireUpgrade(spec)
								end
							end
							task.wait(interval)
						end
					end)
				end
			end,
		})
	end

	CreateUpgradeDropdown(Tabs.Upgrades, {
		Name = "Money Upgrades",
		Flag = "MoneyUpgrades",
		Options = { "Power", "Bag", "Rank", "Tier" },
		Remotes = {
			Power = "UpgradePower",
			Bag = "UpgradeBag",
			Rank = "UpgradeRank",
			Tier = "TierUp",
		},
	})

	-- craftin

	local CraftRecipes2ForDropdown = game:GetService("Workspace"):WaitForChild("CraftRecipes2")
	local knownGeneratorTypes = {}
	do
		local seen = {}
		for _, recipe in ipairs(CraftRecipes2ForDropdown:GetChildren()) do
			local give = recipe:FindFirstChild("Give")
			if give and give:FindFirstChild("CurrencyName") then
				local generatorType = give.CurrencyName.Value:match("^(%a+)Generator%d+$")
				if generatorType and not seen[generatorType] then
					seen[generatorType] = true
					table.insert(knownGeneratorTypes, generatorType)
				end
			end
		end
		table.sort(knownGeneratorTypes)
	end

	local selectedType = knownGeneratorTypes[1]
	local selectedTier = 1
	local selectedCount = 1
	local SmartCraftRunning = false

	local StatusLabel = Tabs.Crafting:CreateLabel("Select a generator type and tier, then craft.")

	Tabs.Crafting:CreateDropdown({
		Name = "Generator Type",
		Options = knownGeneratorTypes,
		CurrentOption = { selectedType },
		Flag = "SmartCraftType",
		Callback = function(Option)
			selectedType = Option[1] or Option
		end,
	})

	Tabs.Crafting:CreateInput({
		Name = "Tier",
		PlaceholderText = "e.g. 4",
		RemoveTextAfterFocusLost = false,
		Flag = "SmartCraftTier",
		Callback = function(Text)
			local n = tonumber(Text)
			if n then
				selectedTier = n
			end
		end,
	})

	Tabs.Crafting:CreateInput({
		Name = "Count",
		PlaceholderText = "e.g. 1",
		RemoveTextAfterFocusLost = false,
		Flag = "SmartCraftCount",
		Callback = function(Text)
			local n = tonumber(Text)
			if n then
				selectedCount = n
			end
		end,
	})

	local CraftButton = Tabs.Crafting:CreateButton({
		Name = "Craft",
		Callback = function()
			if SmartCraftRunning then
				return
			end
			SmartCraftRunning = true

			task.spawn(function()
				local RETRY_TIMEOUT_SECONDS = 10
				local runStart = os.clock()

				local function elapsed()
					return os.clock() - runStart
				end

				local function setStatus(text)
					if StatusLabel then
						StatusLabel:Set(text)
					end
					if CraftButton then
						CraftButton:Set({ Name = text })
					end
				end

				setStatus(
					("Crafting %s Generator %s x%s... 0.0s"):format(
						tostring(selectedType),
						tostring(selectedTier),
						tostring(selectedCount)
					)
				)

				local Players = game:GetService("Players")
				local player = Players.LocalPlayer
				local Workspace = game:GetService("Workspace")
				local ReplicatedStorage = game:GetService("ReplicatedStorage")

				local CraftRemote = ReplicatedStorage:WaitForChild("Craft")
				local Craft2Remote = ReplicatedStorage:WaitForChild("Craft2")
				local CraftRecipes = Workspace:WaitForChild("CraftRecipes")
				local CraftRecipes2 = Workspace:WaitForChild("CraftRecipes2")

				local MAX_CRAFT_ATTEMPTS = 10

				local Producers = {}
				local function IndexRecipes(folder, sourceTable)
					for _, recipe in ipairs(folder:GetChildren()) do
						local give = recipe:FindFirstChild("Give")
						if give and give:FindFirstChild("CurrencyName") then
							Producers[give.CurrencyName.Value] = {
								Table = sourceTable,
								Id = tonumber(recipe.Name),
							}
						end
					end
				end
				IndexRecipes(CraftRecipes, "CraftRecipes")
				IndexRecipes(CraftRecipes2, "CraftRecipes2")

				local function RecipeOf(producer)
					local folder = (producer.Table == "CraftRecipes") and CraftRecipes or CraftRecipes2
					return folder[producer.Id]
				end
				local function TakesItem(producer, itemName)
					for _, ingredient in ipairs(RecipeOf(producer).Take:GetChildren()) do
						if ingredient.Name == itemName then
							return true
						end
					end
					return false
				end
				local excludedPairs = {}
				for itemName, producer in pairs(Producers) do
					for _, ingredient in ipairs(RecipeOf(producer).Take:GetChildren()) do
						local otherProducer = Producers[ingredient.Name]
						if otherProducer and TakesItem(otherProducer, itemName) then
							excludedPairs[itemName] = ingredient.Name
						end
					end
				end
				for itemName in pairs(excludedPairs) do
					Producers[itemName] = nil
				end

				local GeneratorsByTypeAndTier = {}
				for _, recipe in ipairs(CraftRecipes2:GetChildren()) do
					local give = recipe:FindFirstChild("Give")
					if give and give:FindFirstChild("CurrencyName") then
						local generatorType, tier = give.CurrencyName.Value:match("^(%a+)Generator(%d+)$")
						if generatorType and tier then
							GeneratorsByTypeAndTier[generatorType] = GeneratorsByTypeAndTier[generatorType] or {}
							GeneratorsByTypeAndTier[generatorType][tonumber(tier)] = tonumber(recipe.Name)
						end
					end
				end

				local function GetStat(name)
					local stats = player:FindFirstChild("Stats")
					local stat = stats and stats:FindFirstChild(name)
					return stat and stat.Value or 0
				end

				local function PollUntil(predicate, timeout)
					local start = os.clock()
					while not predicate() and (os.clock() - start) < (timeout or 5) do
						task.wait()
					end
					return predicate()
				end

				local EnsureHave

				local function EnsureAllIngredients(recipe, craftsNeeded, visited)
					local ingredients = recipe.Take:GetChildren()

					local function totalShortfall()
						local total = 0
						for _, ingredient in ipairs(ingredients) do
							local needed = ingredient.Value * craftsNeeded
							local have = GetStat(ingredient.Name)
							if have < needed then
								total = total + (needed - have)
							end
						end
						return total
					end

					local lastShortfall = totalShortfall()
					local staleRounds = 0

					for settleAttempt = 1, 200 do
						local allSatisfied = true
						for _, ingredient in ipairs(ingredients) do
							local needed = ingredient.Value * craftsNeeded
							if GetStat(ingredient.Name) < needed then
								allSatisfied = false
								if not EnsureHave(ingredient.Name, needed, visited) then
									return false
								end
							end
						end
						if allSatisfied then
							return true
						end

						local shortfall = totalShortfall()
						if shortfall >= lastShortfall then
							staleRounds = staleRounds + 1
							if staleRounds >= 3 then
								return false
							end
						else
							staleRounds = 0
						end
						lastShortfall = shortfall
					end

					return false
				end

				EnsureHave = function(itemName, amountNeeded, visited)
					visited = visited or {}

					local current = GetStat(itemName)
					if current >= amountNeeded then
						return true
					end

					local producer = Producers[itemName]
					if not producer then
						return false
					end

					local key = producer.Table .. ":" .. producer.Id
					if visited[key] then
						return false
					end
					visited[key] = true

					local function finish(result)
						visited[key] = nil
						return result
					end

					local recipeFolder = (producer.Table == "CraftRecipes") and CraftRecipes or CraftRecipes2
					local recipe = recipeFolder[producer.Id]
					local giveAmount = recipe.Give.Amount.Value
					local deficit = amountNeeded - current
					local craftsNeeded = math.ceil(deficit / giveAmount)

					if not EnsureAllIngredients(recipe, craftsNeeded, visited) then
						return finish(false)
					end

					if producer.Table == "CraftRecipes" then
						CraftRemote:FireServer(producer.Id, craftsNeeded)
						local ok = PollUntil(function()
							return GetStat(itemName) >= amountNeeded
						end, 5)
						if not ok then
							return finish(false)
						end
						return finish(true)
					else
						local attempts = 0
						local lastAmount = current

						while GetStat(itemName) < amountNeeded do
							if attempts >= MAX_CRAFT_ATTEMPTS then
								return finish(false)
							end

							Craft2Remote:FireServer(producer.Id)
							PollUntil(function()
								return GetStat(itemName) > lastAmount
							end, 3)

							local newAmount = GetStat(itemName)
							if newAmount <= lastAmount then
								attempts = attempts + 1
							else
								attempts = 0
							end
							lastAmount = newAmount
						end

						return finish(true)
					end
				end

				local function FindShortages(itemName, amountNeeded, visited, shortages)
					visited = visited or {}
					shortages = shortages or {}

					local current = GetStat(itemName)
					if current >= amountNeeded then
						return shortages
					end

					local producer = Producers[itemName]
					if not producer then
						local entry = shortages[itemName]
						if entry then
							entry.needed = entry.needed + amountNeeded
						else
							shortages[itemName] = { needed = amountNeeded, have = current }
						end
						return shortages
					end

					local key = producer.Table .. ":" .. producer.Id
					if visited[key] then
						return shortages
					end
					visited[key] = true

					local recipeFolder = (producer.Table == "CraftRecipes") and CraftRecipes or CraftRecipes2
					local recipe = recipeFolder[producer.Id]
					local giveAmount = recipe.Give.Amount.Value
					local deficit = amountNeeded - current
					local craftsNeeded = math.ceil(deficit / giveAmount)

					for _, ingredient in ipairs(recipe.Take:GetChildren()) do
						FindShortages(ingredient.Name, ingredient.Value * craftsNeeded, visited, shortages)
					end

					visited[key] = nil
					return shortages
				end

				local function DescribeShortages(recipe)
					local shortages = {}
					for _, ingredient in ipairs(recipe.Take:GetChildren()) do
						FindShortages(ingredient.Name, ingredient.Value, {}, shortages)
					end

					local names = {}
					for name in pairs(shortages) do
						table.insert(names, name)
					end
					table.sort(names)

					if #names == 0 then
						return "nothing base-level short (likely hit a cap)"
					end

					local lines = {}
					for _, name in ipairs(names) do
						local s = shortages[name]
						table.insert(lines, ("%s need %s have %s"):format(name, tostring(s.needed), tostring(s.have)))
					end
					return table.concat(lines, " | ")
				end

				local function CraftOneGenerator(generatorId)
					local recipe = CraftRecipes2[generatorId]
					if not recipe then
						return false, "no such generator recipe"
					end

					if not EnsureAllIngredients(recipe, 1, {}) then
						return false, DescribeShortages(recipe)
					end

					local statName = recipe.Give.CurrencyName.Value
					local before = GetStat(statName)

					Craft2Remote:FireServer(generatorId)
					local increased = PollUntil(function()
						return GetStat(statName) > before
					end, 3)

					if not increased then
						return false, "craft did not go through (likely hit GeneratorsLimit cap)"
					end

					return true
				end

				local tiers = GeneratorsByTypeAndTier[selectedType]
				if not tiers then
					setStatus("Unknown generator type: " .. tostring(selectedType))
					SmartCraftRunning = false
					return
				end

				local generatorId = tiers[selectedTier]
				if not generatorId then
					setStatus(("%s Generator has no tier %s"):format(tostring(selectedType), tostring(selectedTier)))
					SmartCraftRunning = false
					return
				end

				local crafted = 0
				for i = 1, selectedCount do
					if not IsActiveSession() then
						break
					end

					local unitDeadline = os.clock() + RETRY_TIMEOUT_SECONDS
					local ok, reason

					repeat
						ok, reason = CraftOneGenerator(generatorId)
						if not ok then
							setStatus(
								("Retrying %d/%d %s Gen %d... %.1fs — %s"):format(
									crafted + 1,
									selectedCount,
									selectedType,
									selectedTier,
									elapsed(),
									reason or "?"
								)
							)
							task.wait(0.1)
						end
					until ok or os.clock() >= unitDeadline or not IsActiveSession()

					if not ok then
						setStatus(
							("Gave up %d/%d after %.1fs — %s"):format(
								crafted + 1,
								selectedCount,
								elapsed(),
								reason or "?"
							)
						)
						SmartCraftRunning = false
						return
					end

					crafted = crafted + 1
					setStatus(
						("Crafted %d/%d %s Gen %d... %.1fs"):format(
							crafted,
							selectedCount,
							selectedType,
							selectedTier,
							elapsed()
						)
					)
				end

				setStatus(
					("Done: %d/%d %s Generator %d in %.1fs"):format(
						crafted,
						selectedCount,
						selectedType,
						selectedTier,
						elapsed()
					)
				)
				SmartCraftRunning = false
			end)
		end,
	})

	Tabs.Misc:CreateSlider({
		Name = "WalkSpeed",
		Range = { 0, 250 },
		Increment = 5,
		Suffix = "WalkSpeed",
		CurrentValue = 16,
		Flag = "PlayerWalkSpeed",
		Callback = function(Value) end,
	})

	Tabs.Misc:CreateToggle({
		Name = "Enable WalkSpeed",
		CurrentValue = false,
		Flag = "EnableWalkSpeed",
		Callback = function(Value)
			local character = game.Players.LocalPlayer.Character
			local humanoid = character and character:FindFirstChild("Humanoid")
			if Rayfield.Flags["EnableWalkSpeed"].CurrentValue and IsActiveSession() then
				game:GetService("Players").LocalPlayer.PlayerGui.GameGui.PlayerSpeed.Disabled = true
				if humanoid then
					humanoid.WalkSpeed = Rayfield.Flags["PlayerWalkSpeed"].CurrentValue
				end
			else
				game:GetService("Players").LocalPlayer.PlayerGui.GameGui.PlayerSpeed.Disabled = false
			end
		end,
	})

	-- ===== Info =====
	Tabs.Info:CreateParagraph({ Title = "Creator", Content = "Haakon" })
	Tabs.Info:CreateParagraph({ Title = "Created/Updated", Content = "24/1/2025 | 18/3/2025" })
	Tabs.Info:CreateParagraph({ Title = "Discord", Content = "haakonyt" })
	Tabs.Info:CreateParagraph({ Title = "Version", Content = Version })
end

return MoneySimulatorX
