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
                    while Rayfield:GetFlagValue("AutoClickMoney") and IsActiveSession() do
                        local ok, err = pcall(function()
                            game:GetService("ReplicatedStorage").Events.ClickMoney:FireServer()
                        end)
                        if not ok then
                            warn("[MoneyClickerInc] ClickMoney failed: " .. tostring(err))
                        end
                        task.wait(1)
                    end
                end)
            end
        end,
    })

    Misc:CreateSlider({
        Name = "WalkSpeed",
        Range = {0, 250},
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
