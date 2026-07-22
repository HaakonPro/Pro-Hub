-- ===== games/MoneyClickerInc.lua =====
local MoneyClickerInc = {}

function MoneyClickerInc.Init(Window, Rayfield, IsActiveSession)
	local FarmTab = Window:CreateTab("Farm")
	local Upgrades = Window:CreateTab("Upgrades")
	local Misc = Window:CreateTab("Misc")
	local Info = Window:CreateTab("Info")

	FarmTab:CreateToggle({
		Name = "Autoclick Money",
		CurrentValue = false,
		Flag = "AutoClickMoney",
		Callback = function(Value)
			if Value then
				task.spawn(function()
					while Rayfield.Flags["AutoClickMoney"].CurrentValue and IsActiveSession() do
						game:GetService("ReplicatedStorage").Events.ClickMoney:FireServer()
						task.wait(0.1)
					end
				end)
			end
		end,
	})

	FarmTab:CreateToggle({
		Name = "Auto Money Upgrades",
		CurrentValue = false,
		Flag = "AutoMoneyUpgrades",
		Callback = function(Value)
			if Value then
				task.spawn(function()
					while Rayfield.Flags["AutoClickMoney"].CurrentValue and IsActiveSession() do
						for i = 1, 15 do
							local Event = game:GetService("ReplicatedStorage").Events.Upgrade
							Event:FireServer(2, false)
						end
						task.wait(1)
					end
				end)
			end
		end,
	})

	Misc:CreateSlider({
		Name = "WalkSpeed",
		Range = { 0, 250 },
		Increment = 5,
		Suffix = "WalkSpeed",
		CurrentValue = 16,
		Flag = "PlayerWalkSpeed",
		Callback = function(Value)
			local character = game.Players.LocalPlayer.Character
			local humanoid = character and character:FindFirstChild("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = Value
			end
		end,
	})
end

return MoneyClickerInc
