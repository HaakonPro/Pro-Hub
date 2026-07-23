-- ===== games/MoneySimulator1_4_0.lua =====
local MoneySimulator1_4_0 = {}

local RunService = game:GetService("RunService")
local autoMoneyConnection = nil

local function formatNumber(n)
	local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi" }
	local index = 1
	while n >= 1000 and index < #suffixes do
		n = n / 1000
		index = index + 1
	end
	return string.format("%.2f%s", n, suffixes[index])
end

-- cus game breakin later :P
local function FixGame()
	local numberScale = workspace:WaitForChild("NumberScale")

	if not numberScale:FindFirstChild("46") then
		local clone = numberScale:WaitForChild("31"):Clone()
		clone.Name = "46"
		clone.Value = "Bugged Value #46"
		clone.Parent = numberScale
	end

	local effects = game:GetService("Players").LocalPlayer
		:WaitForChild("PlayerGui")
		:WaitForChild("ScreenGui")
		:FindFirstChild("Effects")

	if effects and effects:IsA("LocalScript") then
		effects.Disabled = true
		task.wait()
		effects.Disabled = false
	end

	print("Fixed NumberScale 46")
end

FixGame()

function MoneySimulator1_4_0.Init(Window, Rayfield, IsActiveSession)
	local Tabs = {
		Main = Window:CreateTab("Main"),
		AutoOres = Window:CreateTab("Auto Ores"),
		Misc = Window:CreateTab("Misc"),
		Info = Window:CreateTab("Info"),
	}

	pcall(function()
		local pad = workspace:WaitForChild("SellPad", 10)
		if pad then
			pad.CanCollide = false
		end
	end)

	-- ===== Auto Money (click + XP UI update) =====
	Tabs.Main:CreateToggle({
		Name = "Auto Money",
		CurrentValue = false,
		Flag = "AutoMoney",
		Callback = function(Value)
			if Value then
				autoMoneyConnection = RunService.Heartbeat:Connect(function()
					if not (Rayfield.Flags["AutoMoney"].CurrentValue and IsActiveSession()) then
						if autoMoneyConnection then
							autoMoneyConnection:Disconnect()
							autoMoneyConnection = nil
						end
						return
					end

					pcall(function()
						game.ReplicatedStorage.BobuxEvent:FireServer()

						local player = game.Players.LocalPlayer
						local stats = player:FindFirstChild("stats")
						local gui = player.PlayerGui:FindFirstChild("ScreenGui")

						if stats and gui then
							local req = 10 * 1.25 ^ stats.Level.Value
							gui.LevelBar.Bar.Size = UDim2.new(stats.XP.Value / req, 0, 1, 0)
							gui.LvlTxt.Text = "Level "
								.. stats.Level.Value
								.. " ("
								.. math.floor(stats.XP.Value / req * 100)
								.. "%) "
								.. formatNumber(stats.XP.Value)
								.. "/"
								.. formatNumber(req)
							gui.ClickPoints.Text = formatNumber(stats.ClickPoints.Value)
						end
					end)
				end)
			elseif autoMoneyConnection then
				autoMoneyConnection:Disconnect()
				autoMoneyConnection = nil
			end
		end,
	})

	-- ===== Click-detector based auto toggles =====
	local function CreateAutoClickToggle(tab, name, flag, partName)
		tab:CreateToggle({
			Name = name,
			CurrentValue = false,
			Flag = flag,
			Callback = function(Value)
				if Value then
					task.spawn(function()
						while Rayfield.Flags[flag].CurrentValue and IsActiveSession() do
							pcall(function()
								local part = workspace:WaitForChild(partName, 5)
								local clickDetector = part and part:FindFirstChild("ClickDetector")
								if clickDetector then
									fireclickdetector(clickDetector)
								else
									warn("[" .. name .. "] ClickDetector not found in " .. partName)
								end
							end)
							task.wait(0.1)
						end
					end)
				end
			end,
		})
	end

	CreateAutoClickToggle(Tabs.Main, "Auto Package", "AutoPackage", "CreatePackage")
	CreateAutoClickToggle(Tabs.Main, "Auto Iron Block", "AutoIron", "SmeltIron")
	CreateAutoClickToggle(Tabs.Main, "Auto Gold Block", "AutoGold", "CraftGold")
	CreateAutoClickToggle(Tabs.Main, "Auto Event Click", "AutoEvent", "UpgradeEvent1")

	-- ===== Auto Minigame =====
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	Tabs.Main:CreateToggle({
		Name = "Auto Minigame",
		CurrentValue = false,
		Flag = "AutoMinigame",

		Callback = function(enabled)
			if not enabled then
				return
			end

			task.spawn(function()
				local player = Players.LocalPlayer
				local connection

				local function getHRP()
					local character = player.Character or player.CharacterAdded:Wait()
					return character:WaitForChild("HumanoidRootPart")
				end

				local hrp = getHRP()
				local originalPosition = hrp.Position

				player.CharacterAdded:Connect(function()
					hrp = getHRP()
					originalPosition = hrp.Position
				end)

				while Rayfield.Flags.AutoMinigame.CurrentValue and IsActiveSession() do
					local minigame = workspace:FindFirstChild("Minigames")
						and workspace.Minigames:FindFirstChild("SaveThePackages")

					if minigame then
						local started = minigame:FindFirstChild("Started")

						if started and started.Value then
							local packages = minigame:FindFirstChild("Packages")

							if packages then
								local function clickPackage(package)
									if not Rayfield.Flags.AutoMinigame.CurrentValue then
										return
									end

									if not package:IsA("BasePart") then
										return
									end

									local clickDetector = package:WaitForChild("ClickDetector", 2)

									if clickDetector then
										pcall(function()
											fireclickdetector(clickDetector)
										end)

										--	print("Clicked:", package.Name)
									end
								end

								-- Click existing packages
								for _, package in ipairs(packages:GetChildren()) do
									task.spawn(clickPackage, package)
								end

								-- Listen for new packages
								if not connection then
									connection = packages.ChildAdded:Connect(function(package)
										task.spawn(clickPackage, package)
									end)
								end
							end
						else
							ReplicatedStorage.StartMinigame:FireServer("SaveThePackages")

							repeat
								task.wait()
							until started.Value or not Rayfield.Flags.AutoMinigame.CurrentValue

							if hrp then
								hrp.CFrame = CFrame.new(originalPosition + Vector3.new(0, 3, 0))
							end
						end
					end

					task.wait(0.5)
				end

				if connection then
					connection:Disconnect()
					connection = nil
				end
			end)
		end,
	})

	-- ===== Ore selection dropdown =====
	local OreMapping = {
		["Crystal"] = "BobuxCrystal1",
		["Gems 1"] = "BobuxGems1",
		["Gems 2"] = "BobuxGems2",
		["Gems 3"] = "BobuxGems3",
		["Gems 4"] = "BobuxGems4",
		["Dark Bobux"] = "DarkBobux1",
		["Gold 1"] = "GoldBobux1",
		["Gold 2"] = "GoldBobux2",
		["Neon 1"] = "NeonBobux1",
		["Neon 2"] = "NeonBobux2",
		["Rainbow"] = "RainbowBobux1",
	}

	local CustomNames = {
		"Crystal",
		"Gems 1",
		"Gems 2",
		"Gems 3",
		"Gems 4",
		"Dark Bobux",
		"Gold 1",
		"Gold 2",
		"Neon 1",
		"Neon 2",
		"Rainbow",
	}

	local SelectedOre = OreMapping["Rainbow"]

	Tabs.AutoOres:CreateDropdown({
		Name = "Select Ore",
		Options = CustomNames,
		CurrentOption = "Rainbow",
		MultipleOptions = false,
		Flag = "OreDropdown",
		Callback = function(Options)
			local SelectedOption = type(Options) == "table" and Options[1] or Options
			SelectedOre = OreMapping[SelectedOption]
		end,
	})

	-- ===== Auto Ore (teleport to selected ore) =====
	Tabs.AutoOres:CreateToggle({
		Name = "Auto Ore",
		CurrentValue = false,
		Flag = "AutoOre",
		Callback = function(Value)
			if Value then
				task.spawn(function()
					local player = game.Players.LocalPlayer
					local character = player.Character or player.CharacterAdded:Wait()
					local hrp = character:WaitForChild("HumanoidRootPart")
					local originalPosition = hrp.Position

					while Rayfield.Flags["AutoOre"].CurrentValue and IsActiveSession() do
						local oreFolder = workspace:FindFirstChild("BobuxOres")
						local oreParts = oreFolder and SelectedOre and oreFolder:FindFirstChild(SelectedOre)

						if not oreParts then
							warn("[AutoOre] " .. tostring(SelectedOre) .. " not found!")
							break
						end

						for _, part in ipairs(oreParts:GetChildren()) do
							if not (Rayfield.Flags["AutoOre"].CurrentValue and IsActiveSession()) then
								break
							end
							if part:IsA("BasePart") and part.Transparency ~= 1 then
								pcall(function()
									hrp.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 0))
								end)
								task.wait(1)
							end
						end
					end

					pcall(function()
						hrp.CFrame = CFrame.new(originalPosition + Vector3.new(0, 3, 0))
					end)
				end)
			end
		end,
	})

	-- ===== Auto All Ores (touch-interest based) =====
	Tabs.AutoOres:CreateToggle({
		Name = "Auto All Ores",
		CurrentValue = false,
		Flag = "AutoOreAll",
		Callback = function(Value)
			if Value then
				task.spawn(function()
					while Rayfield.Flags["AutoOreAll"].CurrentValue and IsActiveSession() do
						pcall(function()
							local oresFolder = workspace:WaitForChild("BobuxOres", 5)
							local player = game:GetService("Players").LocalPlayer
							local character = player.Character or player.CharacterAdded:Wait()
							local hrp = character:WaitForChild("HumanoidRootPart")

							if oresFolder then
								for _, ore in ipairs(oresFolder:GetDescendants()) do
									if ore:IsA("BasePart") then
										ore.CanCollide = false
										firetouchinterest(ore, hrp, 0)
										task.wait(0.01)
										firetouchinterest(ore, hrp, 1)
									end
								end
							end
						end)
						task.wait(0.1)
					end
				end)
			end
		end,
	})

	-- ===== Auto Mine (priority-based quarry mining) =====
	local CurrentOreLabel = Tabs.AutoOres:CreateLabel("Auto Mine Disabled")

	local function findOreWithPriority()
		local orePriority = {
			"Meteorite",
			"Diamond",
			"Platinum",
			"Topaz",
			"Sapphire",
			"Event Ore",
			"Opal",
			"Emerald",
			"Ruby",
			"Gold",
			"Silver",
			"Amethyst",
			"Copper",
			"Iron",
			"Coal",
			"Slate",
			"Stone",
			"Dirt",
			"Clay",
			"Grass",
		}

		local quarry = workspace:FindFirstChild("BobuxQuarry")
		if not quarry then
			return nil
		end

		local chunk1 = quarry:FindFirstChild("Chunk-1")
		if not chunk1 then
			local chunk0 = quarry:FindFirstChild("Chunk0")
			if chunk0 then
				for _, ore in ipairs(chunk0:GetChildren()) do
					if ore:IsA("BasePart") and ore.Name ~= "Bedrock" then
						pcall(function()
							game:GetService("ReplicatedStorage").MineBlock:FireServer(ore)
						end)
						task.wait(0.5)
						break
					end
				end
			end
			chunk1 = quarry:FindFirstChild("Chunk-1")
		end

		local function findBestOreInChunk(chunk)
			if not chunk then
				return nil
			end
			local orePriorityMap = {}
			for priority, oreName in ipairs(orePriority) do
				orePriorityMap[oreName] = priority
			end

			local bestOre, bestPriority = nil, math.huge
			for _, ore in ipairs(chunk:GetChildren()) do
				if ore:IsA("BasePart") and ore.Name ~= "Bedrock" then
					local p = orePriorityMap[ore.Name]
					if p and p < bestPriority then
						bestOre, bestPriority = ore, p
					end
				end
			end
			return bestOre
		end

		if chunk1 then
			local bestOre = findBestOreInChunk(chunk1)
			if bestOre then
				return bestOre
			end
		end

		return findBestOreInChunk(quarry:FindFirstChild("Chunk0"))
	end

	Tabs.AutoOres:CreateToggle({
		Name = "Auto Mine",
		CurrentValue = false,
		Flag = "AutoMine",
		Callback = function(Value)
			if Value then
				task.spawn(function()
					while Rayfield.Flags["AutoMine"].CurrentValue and IsActiveSession() do
						pcall(function()
							local ore = findOreWithPriority()
							if ore then
								local health = ore:FindFirstChild("Health")
								CurrentOreLabel:Set(
									ore.Name .. ": " .. (health and tostring(health.Value) or "N/A") .. " HP"
								)

								game:GetService("ReplicatedStorage").MineBlock:FireServer(ore)

								local pad = workspace:WaitForChild("SellPad", 5)
								local character = game.Players.LocalPlayer.Character
								local hrp = character and character:FindFirstChildWhichIsA("BasePart")

								if pad and hrp then
									firetouchinterest(pad, hrp, 0)
									task.wait()
									firetouchinterest(pad, hrp, 1)
								end
							else
								CurrentOreLabel:Set("No valid ore found!")
							end
						end)
						task.wait(0.1)
					end
					CurrentOreLabel:Set("Auto Mine Disabled")
				end)
			end
		end,
	})

	local function getBobux()
		local leaderstats = game.Players.LocalPlayer:FindFirstChild("leaderstats")
		local bobux = leaderstats and leaderstats:FindFirstChild("Bobux")
		return bobux and bobux.Value or 0
	end

	local MoneyLabel = Tabs.Misc:CreateLabel("You earned ?/s")

	Tabs.Misc:CreateButton({
		Name = "Check Your Money /s [5s Test]",
		Callback = function()
			local total = 0

			MoneyLabel:Set("Checking...")

			for i = 1, 5 do
				local lastValue = getBobux()
				task.wait(1)
				local newValue = getBobux()

				total += newValue - lastValue
			end

			local persec = total / 5

			local scale = math.floor(math.log10(persec + 1) / 3 + 1)
			scale = math.clamp(scale, 1, #game.Workspace.NumberScale:GetChildren())

			local val = math.floor(persec / (1000 ^ scale / 1000) * 100) / 100
			local suffix = game.Workspace.NumberScale[scale].Value

			MoneyLabel:Set("You earn: " .. val .. suffix .. "/s")
		end,
	})

	Tabs.Misc:CreateToggle({
		Name = "Auto Event 5x",
		CurrentValue = false,
		Flag = "AutoEvent5x",
		Callback = function(Value)
			if Value then
				task.spawn(function()
					local upgrade = workspace.UpgradeEvent2

					while Rayfield.Flags["AutoEvent5x"].CurrentValue and IsActiveSession() do
						while Rayfield.Flags["AutoEvent5x"].CurrentValue and upgrade.Bonus.Value < 6 do
							fireclickdetector(upgrade.ClickDetector)
							--	print("Bonus:", upgrade.Bonus.Value)
							task.wait(1)
						end

						task.wait(1)
					end
				end)
			end
		end,
	})

	Tabs.Misc:CreateToggle({
		Name = "Auto Upgrade",
		CurrentValue = false,
		Flag = "AutoUpgrade",
		Callback = function(Value)
			if Value then
				task.spawn(function()
					while Rayfield.Flags["AutoUpgrade"].CurrentValue and IsActiveSession() do
						local Event = game:GetService("ReplicatedStorage").Upgrade
						Event:FireServer("Rebirth")
						Event:FireServer("Rank")
						Event:FireServer("Amount")
						Event:FireServer("Cooldown")
						task.wait(1)
					end
				end)
			end
		end,
	})

	-- ===== Info =====
	Tabs.Info:CreateParagraph({ Title = "Creator", Content = "Haakon" })
	Tabs.Info:CreateParagraph({ Title = "Created/Updated", Content = "24/1/2025 | 18/3/2025" })
	Tabs.Info:CreateParagraph({ Title = "Discord", Content = "haakonyt" })
end

return MoneySimulator1_4_0
