 -- [[ OXYGEN V3 - FINAL STABLE BUILD (HARD FIXED POV) ]]
local RS, Players, LP = game:GetService("RunService"), game:GetService("Players"), game:GetService("Players").LocalPlayer
local Camera = workspace.CurrentCamera

-- [[ MASTER CONFIG ]]
_G.Config = {
    Visuals = { Player = false, Health = false, Armor = false },
    Loot = { Containers = false, Items = false },
    Aimtouch = { Enabled = false, WallCheck = false, Smoothness = 10, FOV = 100, ShowFOV = false },
    Silent = { Enabled = false, WallCheck = true, HitChance = 100, FOV = 50, ShowFOV = false },
    Trigger = { Enabled = false, WallCheck = true, FOV = 25, ShowFOV = false, Delay = 0 },
    Targets = { Players = true, Bone = "Head" }
}

-- [[ POV INITIALIZATION - HARD REWRITE ]]
local function CreateCircle(color)
    local circle = Drawing.new("Circle")
    circle.Visible = false
    circle.Thickness = 2
    circle.Transparency = 1
    circle.Color = color
    circle.Filled = false
    circle.NumSides = 64 -- Smoother circle
    return circle
end

local AimCircle = CreateCircle(Color3.fromRGB(255, 255, 255))
local SilentCircle = CreateCircle(Color3.fromRGB(0, 255, 255))
local TriggerCircle = CreateCircle(Color3.fromRGB(255, 50, 50))

-- [[ ERROR HANDLER ]]
local function SafetyExecute(name, func)
    local success, err = pcall(func)
    if not success then
        warn("Oxygen Error: " .. name .. " -> " .. tostring(err))
        -- Notification handled after UI loads
    end
end

-- [[ UI INITIALIZATION ]]
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({Name = "OXYGEN | V3", LoadingTitle = "Oxygen System v3"})

local VisualsTab = Window:CreateTab("Visuals")
local AimTab = Window:CreateTab("Aimtouch")
local SilentTab = Window:CreateTab("Silent Aim")
local TestTab = Window:CreateTab("Triggerbot")
local LogTab = Window:CreateTab("Logs")

-- [[ VISUALS & LOOT SECTION ]]
SafetyExecute("Visuals Tab", function()
    VisualsTab:CreateSection("ESP Players")
    VisualsTab:CreateToggle({Name = "Player ESP", CurrentValue = false, Callback = function(v) _G.Config.Visuals.Player = v end})
    VisualsTab:CreateToggle({Name = "Armor & Helmet ESP", CurrentValue = false, Callback = function(v) _G.Config.Visuals.Armor = v end})
    VisualsTab:CreateToggle({Name = "Health Bar", CurrentValue = false, Callback = function(v) _G.Config.Visuals.Health = v end})

    VisualsTab:CreateSection("Loot")
    VisualsTab:CreateToggle({Name = "Container ESP", CurrentValue = false, Callback = function(v) _G.Config.Loot.Containers = v end})
end)

-- [[ AIMTOUCH SECTION ]]
SafetyExecute("Aimtouch Tab", function()
    AimTab:CreateSection("Mechanics")
    AimTab:CreateToggle({Name = "Aimtouch", CurrentValue = false, Callback = function(v) _G.Config.Aimtouch.Enabled = v end})
    AimTab:CreateToggle({Name = "Wall Check", CurrentValue = false, Callback = function(v) _G.Config.Aimtouch.WallCheck = v end})
    AimTab:CreateToggle({Name = "Show POV Circle", CurrentValue = false, Callback = function(v) _G.Config.Aimtouch.ShowFOV = v end})
    AimTab:CreateSlider({Name = "POV Size", Range = {10, 800}, Increment = 1, CurrentValue = 100, Callback = function(v) _G.Config.Aimtouch.FOV = v end})
    AimTab:CreateSlider({Name = "Smoothness", Range = {1, 100}, Increment = 1, CurrentValue = 10, Callback = function(v) _G.Config.Aimtouch.Smoothness = v end})
end)

-- [[ SILENT AIM SECTION ]]
SafetyExecute("Silent Aim Tab", function()
    SilentTab:CreateSection("Mechanics")
    SilentTab:CreateToggle({Name = "Silent Aim", CurrentValue = false, Callback = function(v) _G.Config.Silent.Enabled = v end})
    SilentTab:CreateToggle({Name = "Wall Check", CurrentValue = true, Callback = function(v) _G.Config.Silent.WallCheck = v end})
    SilentTab:CreateToggle({Name = "Show POV Circle", CurrentValue = false, Callback = function(v) _G.Config.Silent.ShowFOV = v end})
    SilentTab:CreateSlider({Name = "Hit Chance", Range = {1, 100}, Increment = 1, CurrentValue = 100, Callback = function(v) _G.Config.Silent.HitChance = v end})
    SilentTab:CreateSlider({Name = "POV Size", Range = {10, 600}, Increment = 1, CurrentValue = 50, Callback = function(v) _G.Config.Silent.FOV = v end})
end)

-- [[ TRIGGERBOT SECTION ]]
SafetyExecute("Triggerbot Tab", function()
    TestTab:CreateSection("Mechanics")
    TestTab:CreateToggle({Name = "Triggerbot", CurrentValue = false, Callback = function(v) _G.Config.Trigger.Enabled = v end})
    TestTab:CreateToggle({Name = "Wall Check", CurrentValue = true, Callback = function(v) _G.Config.Trigger.WallCheck = v end})
    TestTab:CreateToggle({Name = "Show POV Circle", CurrentValue = false, Callback = function(v) _G.Config.Trigger.ShowFOV = v end})
    TestTab:CreateSlider({Name = "POV Size", Range = {5, 400}, Increment = 1, CurrentValue = 25, Callback = function(v) _G.Config.Trigger.FOV = v end})
    TestTab:CreateSlider({Name = "Delay (ms)", Range = {0, 200}, Increment = 1, CurrentValue = 0, Callback = function(v) _G.Config.Trigger.Delay = v end})
end)

-- [[ LOGS SYSTEM ]]
SafetyExecute("Logs Tab", function()
    local LogBox = LogTab:CreateParagraph({Title = "Fetching Logs...", Content = "Connecting to GitHub..."})
    task.spawn(function()
        local success, result = pcall(function() return game:HttpGet("https://raw.githubusercontent.com/windbreaker7/Oxygen/refs/heads/main/Changelog.txt") end)
        if success then LogBox:Set({Title = "Latest Updates", Content = result}) end
    end)
end)

-- [[ CORE POV RENDER LOOP ]]
RS.RenderStepped:Connect(function()
    -- Get current screen center every frame
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    -- Force updates for Aimtouch Circle
    if AimCircle then
        AimCircle.Visible = _G.Config.Aimtouch.ShowFOV
        AimCircle.Radius = _G.Config.Aimtouch.FOV
        AimCircle.Position = center
    end

    -- Force updates for Silent Circle
    if SilentCircle then
        SilentCircle.Visible = _G.Config.Silent.ShowFOV
        SilentCircle.Radius = _G.Config.Silent.FOV
        SilentCircle.Position = center
    end

    -- Force updates for Trigger Circle
    if TriggerCircle then
        TriggerCircle.Visible = _G.Config.Trigger.ShowFOV
        TriggerCircle.Radius = _G.Config.Trigger.FOV
        TriggerCircle.Position = center
    end
end)

-- Final notification check
task.delay(1, function()
    if not Window then
        Rayfield:Notify({Title = "Error", Content = "yo twin check your code", Duration = 5})
    end
end)
