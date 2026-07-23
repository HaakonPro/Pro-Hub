-- ===== games/Template.lua =====
local Template = {}

function Template.Init(Window, Rayfield, IsActiveSession)
	local Tabs = {
		FarmTab = Window:CreateTab("Farm"),
		Upgrades = Window:CreateTab("Upgrades"),
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
						game:GetService("ReplicatedStorage").Events.ClickMoney:FireServer()
						task.wait(0.1)
					end
				end)
			end
		end,
	})

	Tabs.Misc:CreateSlider({
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

	Tabs.Misc:CreateButton({
		Name = "Button :P",
		Callback = function()
			print("hi")
		end,
	})

	-- ===== Info =====
	Tabs.Info:CreateParagraph({ Title = "Creator", Content = "Haakon" })
	Tabs.Info:CreateParagraph({ Title = "Created/Updated", Content = "24/1/2025 | 18/3/2025" })
	Tabs.Info:CreateParagraph({ Title = "Discord", Content = "haakonyt" })
	Tabs.Info:CreateParagraph({ Title = "Version", Content = Version })
end

return Template
