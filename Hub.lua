-- ===== Hub.lua =====
local Hub = {}

function Hub.CreateWindow()
    local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

    local Window = Rayfield:CreateWindow({
        Name = "H-Hub",
        Icon = 0,
        LoadingTitle = "H-Hub",
        LoadingSubtitle = "by HaakonPro",
        ShowText = "Rayfield",
        Theme = "Default",
        ToggleUIKeybind = "K",
        DisableRayfieldPrompts = false,
        DisableBuildWarnings = false,
        ConfigurationSaving = {
            Enabled = true,
            FolderName = "ProHub",
            FileName = "Config"
        },
        Discord = {
            Enabled = false,
            Invite = "noinvitelink",
            RememberJoins = true
        },
        KeySystem = false,
    })

    return Window, Rayfield
end

return Hub
