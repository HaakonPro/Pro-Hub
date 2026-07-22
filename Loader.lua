-- ===== Loader.lua =====

getgenv().SessionID = getgenv().SessionID or 0
getgenv().SessionID += 1
local mySession = getgenv().SessionID

local function IsActiveSession()
    return mySession == getgenv().SessionID
end

if getgenv().RayfieldWindow then
    pcall(function() getgenv().RayfieldWindow:Destroy() end)
end

local BASE_URL = "https://raw.githubusercontent.com/HaakonPro/Pro-Hub/main/"

local function FetchModule(path)
    local ok, result = pcall(function()
        return game:HttpGet(BASE_URL .. path .. "?t=" .. tostring(os.time()))
    end)

    if not ok then
        warn("[Loader] Failed to fetch " .. path .. ": " .. tostring(result))
        return nil
    end

    local compiled, compileErr = loadstring(result)
    if not compiled then
        warn("[Loader] Failed to compile " .. path .. ": " .. tostring(compileErr))
        return nil
    end

    local success, moduleOrErr = pcall(compiled)
    if not success then
        warn("[Loader] Error running " .. path .. ": " .. tostring(moduleOrErr))
        return nil
    end

    return moduleOrErr
end

local Hub = FetchModule("Hub.lua")
if not Hub then return end

local Window, Rayfield = Hub.CreateWindow()
getgenv().RayfieldWindow = Window

local GameScripts = {
    [18408132742] = "games/MoneyClickerInc.lua",
    [6193882657] = "games/MoneySimulator1_4_0.lua",
}

local path = GameScripts[game.PlaceId]

if path then
    local GameModule = FetchModule(path)
    if GameModule then
        GameModule.Init(Window, Rayfield, IsActiveSession)
    end
else
    Rayfield:Notify({
        Title = "Unsupported Game",
        Content = "No hub module for PlaceId " .. game.PlaceId,
        Duration = 5,
    })
end
