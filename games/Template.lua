-- ===== games/Template.lua =====
local Template = {}

function Template.Init(Window, Rayfield, IsActiveSession)
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

	Misc:CreateButton({
		Name = "Button :P",
		Callback = function()
			print("hi")
		end,
	})
end

return Template
