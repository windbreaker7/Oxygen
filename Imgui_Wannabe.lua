-- ============================================================================
-- CREDITS & ACKNOWLEDGMENTS:
-- • No Recoil Hook Method by d2o-lang
--   https://github.com/d2o-lang/OpenSource
-- • Iris UI Library Bundle by windbreaker7
--   https://github.com/windbreaker7/Oxygen
-- ============================================================================

local HttpService = game:GetService("HttpService")

-- Dynamic UI Identifier for Stealth
local RANDOM_GUI_ID = "UI_" .. HttpService:GenerateGUID(false):gsub("-", ""):sub(1, 12)

-- Safe setstackhidden wrapper
local hideStack = function(func)
    if setstackhidden then
        setstackhidden(func, true)
    end
    return func
end

-- Safe cloneref wrapper
local getService = hideStack(function(serviceName)
    local service = game:GetService(serviceName)
    if cloneref then
        return cloneref(service)
    end
    return service
end)

-- Safe newcclosure wrapper
local makeCClosure = hideStack(function(func)
    if newcclosure then
        return newcclosure(func)
    end
    return func
end)

local Players = getService("Players")
local RunService = getService("RunService")
local Stats = getService("Stats")
local UserInputService = getService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local targetParent = (gethui and gethui()) or getService("CoreGui")

-- ============================================================================
-- 1. CLEANUP & METATABLE HOOKING (STEALTH ENHANCEMENT)
-- ============================================================================
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

for _, parentContainer in ipairs({targetParent, playerGui}) do
    for _, child in ipairs(parentContainer:GetChildren()) do
        if child.Name:find("UI_") or child.Name == "Oxygen_Iris_UI" or child.Name == "Iris" then
            child:Destroy()
        end
    end
end

-- Hook __namecall to hide UI from game scripts attempting to scan CoreGui/gethui
if hookmetamethod then
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", hideStack(function(self, ...)
        local method = getnamecallmethod()
        if not checkcaller() and (method == "GetChildren" or method == "GetDescendants") then
            if self == targetParent or self == playerGui then
                local children = oldNamecall(self, ...)
                local filtered = {}
                for _, child in ipairs(children) do
                    if child.Name ~= RANDOM_GUI_ID and child.Name ~= "Iris" then
                        table.insert(filtered, child)
                    end
                end
                return filtered
            end
        end
        return oldNamecall(self, ...)
    end))
end

-- ============================================================================
-- 2. CONFIGURATION & STATE
-- ============================================================================
local IsSetupComplete = false
local recoil_x = 0
local recoil_y = 0

-- AIMTOUCH CONFIG
local Aim_Config = {
    Enabled = false,
    TeamCheck = true,
    WallCheck = true,
    FOVCheck = true,
    TargetPart = "head",
    AimTouchParts = { "head", "torso", "UpperTorso" },
    FOV = 120,
    ShowFOV = true,
    Smoothness = 0.2,
    PriorityMode = "Crosshair", -- "Crosshair", "Distance", "Health"
    FOVColor = Color3.fromRGB(0, 255, 200)
}

-- ESP CONFIG WITH DYNAMIC VISIBLE/OCCLUDED COLORS
local ESP_Config = {
    Enabled = true,
    TeamCheck = true,
    
    -- Player ESP
    Boxes = true,
    Tracers = true,
    Names = true,
    Distance = true,
    Health = true,
    SkeletonESP = true,

    -- Dynamic Colors (Visible vs Occluded)
    UseDynamicColors = true,
    VisibleColor = Color3.fromRGB(0, 255, 140),   -- Green when exposed
    OccludedColor = Color3.fromRGB(255, 50, 50),   -- Red when behind wall

    -- Radar ESP
    RadarEnabled = true,
    RadarTeamCheck = true,
    RadarSize = 150,
    RadarMaxDistance = 200,
    RadarPosition = Vector2.new(20, 80),
    RadarBackground = true,
    RadarBorder = true,
    RadarColor = Color3.fromRGB(255, 50, 50),
    RadarTeamColor = Color3.fromRGB(50, 255, 50),
    
    -- World ESP
    GunESP = true,
    AntiPersonnelESP = true,
    ThrownGrenadeESP = true,
    CameraESP = true,
    DefuserESP = true,
    DroneESP = true,
    ClaymoreESP = true,
    GadgetESP = true,
    
    GunColor = Color3.fromRGB(255, 170, 0),
    AntiPersonnelColor = Color3.fromRGB(255, 50, 50),
    GrenadeColor = Color3.fromRGB(255, 0, 0),
    CameraColor = Color3.fromRGB(0, 180, 255),
    DefuserColor = Color3.fromRGB(0, 255, 100),
    DroneColor = Color3.fromRGB(255, 200, 0),
    ClaymoreColor = Color3.fromRGB(255, 30, 30),
    GadgetColor = Color3.fromRGB(255, 100, 255)
}

local Misc_Config = {
    NoRecoilLoaded = false
}

local UI_Theme = {
    CurrentTheme = "Dark",
    AccentColor = Color3.fromRGB(0, 255, 140)
}

local ESP_Cache = {}
local World_Cache = {}
local Grenade_Cache = {}
local Camera_Cache = {}
local Defuser_Cache = {}
local Drone_Cache = {}
local Claymore_Cache = {}
local Gadget_Cache = {}
local Radar_Cache = {}
local TrackedModels = {}

-- GADGET SYSTEM DEFINITIONS
local gadgetNames = {
    "NeedleMine", "Drone", "RemoteC4", "ToxicCharge", "StickyCamera",
    "Claymore", "ProximityAlarm", "BulletproofCamera", "DeployableShield",
    "BarbedWire", "SignalDisruptor", "ShockBattery"
}

local gadgetSet = {}
for _, name in ipairs(gadgetNames) do
    gadgetSet[name] = true
end

local isGadget = hideStack(function(obj)
    return gadgetSet[obj.Name] or false
end)

local getGadgetPosition = hideStack(function(obj)
    if obj:IsA("BasePart") then
        return obj.Position
    elseif obj:IsA("Model") then
        local primary = obj.PrimaryPart
        if primary then
            return primary.Position
        else
            return obj:GetPivot().Position
        end
    end
    return nil
end)

-- BONE CONFIGURATION
local bones = {
    { "torso", "head" }, { "torso", "shoulder1" }, { "torso", "shoulder2" },
    { "shoulder1", "arm1" }, { "shoulder2", "arm2" }, { "torso", "hip1" },
    { "torso", "hip2" }, { "hip1", "leg1" }, { "hip2", "leg2" }
}

local GunPartNames = { "Barrel", "Base", "Grip", "Trigger", "Stock" }
local AntiPersonnelPartNames = { "Cap", "Lever", "Ring" }
local GrenadePartNames = { "Cap", "Root", "Ring" }

-- FPS & Ping Calculation
local fps = 0
local ping = 0
local frameCount = 0
local lastUpdate = os.clock()

RunService.RenderStepped:Connect(makeCClosure(hideStack(function()
    frameCount = frameCount + 1
    local now = os.clock()
    if now - lastUpdate >= 1 then
        fps = math.floor(frameCount / (now - lastUpdate))
        frameCount = 0
        lastUpdate = now

        pcall(function()
            ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        end)
    end
end)))

-- Helper: Raycast WallCheck
local isPartVisible = hideStack(function(targetPart)
    if not targetPart or not targetPart.Parent then return false end
    
    local origin = Camera.CFrame.Position
    local direction = targetPart.Position - origin
    
    local rayParams = RaycastParams.new()
    rayParams.FilterType = RaycastFilterType.Exclude
    
    local ignoreList = {Camera}
    if LocalPlayer.Character then
        table.insert(ignoreList, LocalPlayer.Character)
    end
    
    rayParams.FilterDescendantsInstances = ignoreList
    
    local result = workspace:Raycast(origin, direction, rayParams)
    if result then
        return result.Instance:IsDescendantOf(targetPart.Parent)
    end
    return true
end)

-- Helper: Map Viewmodel to Character Model
local getCharacterForViewmodel = hideStack(function(vm)
    if not vm then return nil end
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and (player.Character.Name == vm.Name or vm:IsDescendantOf(player.Character)) then
            return player.Character
        end
    end
    return workspace:FindFirstChild(vm.Name)
end)

local isTeammateViewmodel = hideStack(function(vm)
    if not vm then return false end
    local char = getCharacterForViewmodel(vm)
    if not char then return false end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Name == char.Name then
            return player.Team == LocalPlayer.Team
        end
    end
    return false
end)

local isSkeletonTeammate = hideStack(function(model)
    if not ESP_Config.TeamCheck then return false end
    local char = getCharacterForViewmodel(model)
    if not char then return false end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Name == char.Name then
            return player.Team == LocalPlayer.Team
        end
    end
    return false
end)

local executeNoRecoilHook = hideStack(function(valX, valY)
    getgenv().RecoilX = tonumber(valX) or 0
    getgenv().RecoilY = tonumber(valY) or 0

    task.spawn(makeCClosure(hideStack(function()
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/d2o-lang/OpenSource/refs/heads/main/n_recoil.lua"))()
        end)
        if success then
            Misc_Config.NoRecoilLoaded = true
        else
            warn("[-] Failed to load No Recoil script:", err)
        end
    end)))
end)

-- ============================================================================
-- 3. FOV CIRCLE & TARGET SELECTION PRIORITIZATION SYSTEM
-- ============================================================================
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5
FOVCircle.Filled = false
FOVCircle.Transparency = 0.8
FOVCircle.Visible = false

local getClosestTargetInFOV = hideStack(function()
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local myHRP = LocalPlayer.Character and (LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or LocalPlayer.Character:FindFirstChild("Torso"))
    
    local closestTarget = nil
    local bestMetric = math.huge

    for obj, data in pairs(TrackedModels) do
        local targetPlayer = data.Player
        local hrp = data.HRP
        local humanoid = data.Humanoid

        local isTeammate = (targetPlayer.Team ~= nil and targetPlayer.Team == LocalPlayer.Team)
        local isAlive = hrp and (not humanoid or humanoid.Health > 0)

        if isAlive and not (Aim_Config.TeamCheck and isTeammate) then
            local targetPart = nil
            for _, partName in ipairs(Aim_Config.AimTouchParts) do
                local found = obj:FindFirstChild(partName)
                if found then
                    targetPart = found
                    break
                end
            end
            targetPart = targetPart or obj:FindFirstChild(Aim_Config.TargetPart) or hrp

            local visible = isPartVisible(targetPart)
            if targetPart and (not Aim_Config.WallCheck or visible) then
                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)

                if onScreen then
                    local distToCenter = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                    
                    if not Aim_Config.FOVCheck or distToCenter <= Aim_Config.FOV then
                        local currentMetric = math.huge

                        if Aim_Config.PriorityMode == "Crosshair" then
                            currentMetric = distToCenter
                        elseif Aim_Config.PriorityMode == "Distance" then
                            currentMetric = myHRP and (myHRP.Position - hrp.Position).Magnitude or distToCenter
                        elseif Aim_Config.PriorityMode == "Health" then
                            currentMetric = humanoid and humanoid.Health or 100
                        end

                        if currentMetric < bestMetric then
                            bestMetric = currentMetric
                            closestTarget = targetPart
                        end
                    end
                end
            end
        end
    end

    return closestTarget
end)

-- ============================================================================
-- 4. RADAR DRAWING ELEMENTS
-- ============================================================================
local RadarFrame = {
    Background = Drawing.new("Square"),
    Border = Drawing.new("Square"),
    CenterCrossH = Drawing.new("Line"),
    CenterCrossV = Drawing.new("Line"),
    CenterDot = Drawing.new("Circle")
}

RadarFrame.Background.Filled = true
RadarFrame.Background.Color = Color3.fromRGB(15, 15, 15)
RadarFrame.Background.Transparency = 0.6
RadarFrame.Background.Visible = false

RadarFrame.Border.Filled = false
RadarFrame.Border.Thickness = 1.5
RadarFrame.Border.Color = Color3.fromRGB(60, 60, 60)
RadarFrame.Border.Visible = false

RadarFrame.CenterCrossH.Thickness = 1
RadarFrame.CenterCrossH.Color = Color3.fromRGB(100, 100, 100)
RadarFrame.CenterCrossH.Transparency = 0.5
RadarFrame.CenterCrossH.Visible = false

RadarFrame.CenterCrossV.Thickness = 1
RadarFrame.CenterCrossV.Color = Color3.fromRGB(100, 100, 100)
RadarFrame.CenterCrossV.Transparency = 0.5
RadarFrame.CenterCrossV.Visible = false

RadarFrame.CenterDot.Radius = 3
RadarFrame.CenterDot.Filled = true
RadarFrame.CenterDot.Color = Color3.fromRGB(0, 255, 140)
RadarFrame.CenterDot.Visible = false

local createRadarDot = hideStack(function(key)
    if Radar_Cache[key] then return end
    local dot = Drawing.new("Circle")
    dot.Radius = 3.5
    dot.Filled = true
    dot.Visible = false
    Radar_Cache[key] = dot
end)

local clearRadarDot = hideStack(function(key)
    if Radar_Cache[key] then
        pcall(function() Radar_Cache[key]:Remove() end)
        Radar_Cache[key] = nil
    end
end)

-- ============================================================================
-- 5. DRAWING & CACHE MANAGEMENT
-- ============================================================================
local createEspObjects = hideStack(function(modelKey)
    if ESP_Cache[modelKey] then return end

    local objects = {
        Box = Drawing.new("Square"),
        Tracer = Drawing.new("Line"),
        NameTag = Drawing.new("Text")
    }

    objects.Box.Thickness = 1.5
    objects.Box.Filled = false
    objects.Box.Visible = false

    objects.Tracer.Thickness = 1.5
    objects.Tracer.Visible = false

    objects.NameTag.Size = 14
    objects.NameTag.Center = true
    objects.NameTag.Outline = true
    objects.NameTag.Visible = false

    ESP_Cache[modelKey] = objects
end)

local clearEspObjects = hideStack(function(modelKey)
    if ESP_Cache[modelKey] then
        for _, obj in pairs(ESP_Cache[modelKey]) do
            pcall(function() obj:Remove() end)
        end
        ESP_Cache[modelKey] = nil
    end
end)

local clearWorldCache = hideStack(function()
    for vm, cache in pairs(World_Cache) do
        if cache.SkeletonLines then
            for _, line in ipairs(cache.SkeletonLines) do
                pcall(function() line:Remove() end)
            end
        end
        if cache.GunText then pcall(function() cache.GunText:Remove() end) end
        if cache.AntiPersonnelText then pcall(function() cache.AntiPersonnelText:Remove() end) end
    end
    World_Cache = {}
end)

local isModelPartMatch = hideStack(function(model, partNames)
    local found = 0
    for _, part in ipairs(model:GetChildren()) do
        if part:IsA("UnionOperation") then
            for _, name in ipairs(partNames) do
                if part.Name:find(name) then 
                    found = found + 1 
                    break
                end
            end
        end
    end
    return found >= #partNames
end)

local isAntiPersonnelModel = hideStack(function(model)
    for _, part in ipairs(model:GetChildren()) do
        if part:IsA("UnionOperation") then
            for _, apPart in ipairs(AntiPersonnelPartNames) do
                if part.Name:find(apPart) then return true end
            end
        end
    end
    return false
end)

local isGunModel = hideStack(function(model)
    for _, part in ipairs(model:GetChildren()) do
        if part:IsA("UnionOperation") then
            for _, gunPart in ipairs(GunPartNames) do
                if part.Name:find(gunPart) then return true end
            end
        end
    end
    return false
end)

local getThrownGrenadeType = hideStack(function(model)
    local clientModel = model:FindFirstChild("ClientModel")
    if clientModel and clientModel:IsA("ObjectValue") and clientModel.Value then
        local valName = clientModel.Value.Name
        if (valName == "FragGrenade" or valName == "StunGrenade") and isModelPartMatch(model, GrenadePartNames) then
            return valName == "FragGrenade" and "Frag Grenade" or "Stun Grenade"
        end
    end
    return nil
end)

local getGunModelFromViewmodel = hideStack(function(vm)
    for _, child in ipairs(vm:GetChildren()) do
        if child:IsA("Model") and not isAntiPersonnelModel(child) and isGunModel(child) then
            return child
        end
    end
    return nil
end)

local getAntiPersonnelModelFromViewmodel = hideStack(function(vm)
    for _, child in ipairs(vm:GetChildren()) do
        if child:IsA("Model") and not isGunModel(child) and isAntiPersonnelModel(child) then
            return child
        end
    end
    return nil
end)

local getHealthColor = hideStack(function(health, maxHealth)
    local pct = math.clamp(health / (maxHealth > 0 and maxHealth or 100), 0, 1)
    return Color3.fromRGB(math.floor(255 * (1 - pct)), math.floor(255 * pct), 0)
end)

local getMapCameras = hideStack(function()
    local foundCameras = {}
    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc.Name == "DefaultCameras" then
            for _, camModel in ipairs(desc:GetChildren()) do
                if camModel.Name == "DefaultCamera" and camModel:IsA("Model") then
                    local camPart = camModel:FindFirstChild("Cam")
                    if camPart and camPart:IsA("UnionOperation") then
                        table.insert(foundCameras, { Model = camModel, Part = camPart })
                    end
                end
            end
        end
    end
    return foundCameras
end)

-- ============================================================================
-- 6. FAST WORKSPACE SCANNER
-- ============================================================================
local scanWorkspaceForPlayers = hideStack(function()
    local foundModels = {}
    local playerNames = {}

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            playerNames[p.Name] = p
            playerNames[p.DisplayName] = p
        end
    end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") then
            local matchedPlayer = playerNames[obj.Name]
            if matchedPlayer then
                local hrp = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso") or obj:FindFirstChild("UpperTorso")
                local humanoid = obj:FindFirstChildOfClass("Humanoid")
                
                if hrp and (not humanoid or humanoid.Health > 0) then
                    foundModels[obj] = { Player = matchedPlayer, HRP = hrp, Humanoid = humanoid }
                end
            end
        end
    end

    for cachedModel in pairs(ESP_Cache) do
        if not cachedModel or not cachedModel.Parent or not foundModels[cachedModel] then
            clearEspObjects(cachedModel)
        end
    end

    for cachedModel in pairs(Radar_Cache) do
        if not cachedModel or not cachedModel.Parent or not foundModels[cachedModel] then
            clearRadarDot(cachedModel)
        end
    end

    TrackedModels = foundModels
end)

task.spawn(makeCClosure(hideStack(function()
    while true do
        scanWorkspaceForPlayers()
        task.wait(0.5)
    end
end)))

-- ============================================================================
-- 7. RENDER LOOP
-- ============================================================================
RunService.RenderStepped:Connect(makeCClosure(hideStack(function()
    -- DRAW CENTER POV CIRCLE
    if Aim_Config.ShowFOV and IsSetupComplete then
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        FOVCircle.Radius = Aim_Config.FOV
        FOVCircle.Color = Aim_Config.FOVColor
        FOVCircle.Visible = true
    else
        FOVCircle.Visible = false
    end

    -- AIMTOUCH LOCK-ON LOGIC
    if Aim_Config.Enabled and IsSetupComplete then
        local target = getClosestTargetInFOV()
        if target then
            local targetCFrame = CFrame.new(Camera.CFrame.Position, target.Position)
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, math.clamp(1 - Aim_Config.Smoothness, 0.01, 1))
        end
    end

    if not IsSetupComplete or not ESP_Config.Enabled then
        for key in pairs(ESP_Cache) do clearEspObjects(key) end
        for key in pairs(Radar_Cache) do clearRadarDot(key) end
        RadarFrame.Background.Visible = false
        RadarFrame.Border.Visible = false
        RadarFrame.CenterCrossH.Visible = false
        RadarFrame.CenterCrossV.Visible = false
        RadarFrame.CenterDot.Visible = false
        clearWorldCache()
        for _, text in pairs(Grenade_Cache) do text.Visible = false end
        for _, text in pairs(Camera_Cache) do text.Visible = false end
        for _, text in pairs(Defuser_Cache) do text.Visible = false end
        for _, cache in pairs(Drone_Cache) do cache.Box.Visible = false cache.Text.Visible = false end
        for _, text in pairs(Claymore_Cache) do text.Visible = false end
        for _, text in pairs(Gadget_Cache) do text.Visible = false end
        return
    end

    local myHRP = LocalPlayer.Character and (LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or LocalPlayer.Character:FindFirstChild("Torso"))

    -- RADAR FRAME RENDER
    if ESP_Config.RadarEnabled then
        local rSize = ESP_Config.RadarSize
        local rPos = ESP_Config.RadarPosition
        local center = rPos + Vector2.new(rSize / 2, rSize / 2)

        RadarFrame.Background.Size = Vector2.new(rSize, rSize)
        RadarFrame.Background.Position = rPos
        RadarFrame.Background.Visible = ESP_Config.RadarBackground

        RadarFrame.Border.Size = Vector2.new(rSize, rSize)
        RadarFrame.Border.Position = rPos
        RadarFrame.Border.Visible = ESP_Config.RadarBorder

        RadarFrame.CenterCrossH.From = Vector2.new(rPos.X, center.Y)
        RadarFrame.CenterCrossH.To = Vector2.new(rPos.X + rSize, center.Y)
        RadarFrame.CenterCrossH.Visible = true

        RadarFrame.CenterCrossV.From = Vector2.new(center.X, rPos.Y)
        RadarFrame.CenterCrossV.To = Vector2.new(center.X, rPos.Y + rSize)
        RadarFrame.CenterCrossV.Visible = true

        RadarFrame.CenterDot.Position = center
        RadarFrame.CenterDot.Visible = true
    else
        RadarFrame.Background.Visible = false
        RadarFrame.Border.Visible = false
        RadarFrame.CenterCrossH.Visible = false
        RadarFrame.CenterCrossV.Visible = false
        RadarFrame.CenterDot.Visible = false
        for key in pairs(Radar_Cache) do clearRadarDot(key) end
    end

    -- PLAYER ESP & RADAR LOOP
    for obj, data in pairs(TrackedModels) do
        local targetPlayer = data.Player
        local hrp = data.HRP
        local humanoid = data.Humanoid

        local isTeammate = (targetPlayer.Team ~= nil and targetPlayer.Team == LocalPlayer.Team)
        local isAlive = hrp and (not humanoid or humanoid.Health > 0)

        if isAlive and not (ESP_Config.TeamCheck and isTeammate) then
            if not ESP_Cache[obj] then createEspObjects(obj) end

            local cache = ESP_Cache[obj]
            local position, onScreen = Camera:WorldToViewportPoint(hrp.Position)

            -- DYNAMIC COLOR DETERMINATION (VISIBLE VS OCCLUDED)
            local visible = isPartVisible(hrp)
            local activeColor = ESP_Config.UseDynamicColors and (visible and ESP_Config.VisibleColor or ESP_Config.OccludedColor) or ESP_Config.VisibleColor

            if onScreen then
                local dist = math.floor((myHRP and (myHRP.Position - hrp.Position).Magnitude) or 0)
                local hrpCFrame = hrp.CFrame
                local topWorld = hrpCFrame * CFrame.new(0, 3, 0)
                local bottomWorld = hrpCFrame * CFrame.new(0, -3.5, 0)

                local topScreen = Camera:WorldToViewportPoint(topWorld.Position)
                local bottomScreen = Camera:WorldToViewportPoint(bottomWorld.Position)

                local height = math.abs(topScreen.Y - bottomScreen.Y)
                local width = height * 0.65

                if ESP_Config.Boxes then
                    cache.Box.Size = Vector2.new(width, height)
                    cache.Box.Position = Vector2.new(position.X - width / 2, position.Y - height / 2)
                    cache.Box.Color = activeColor
                    cache.Box.Visible = true
                else
                    cache.Box.Visible = false
                end

                if ESP_Config.Tracers then
                    cache.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    cache.Tracer.To = Vector2.new(position.X, position.Y + height / 2)
                    cache.Tracer.Color = activeColor
                    cache.Tracer.Visible = true
                else
                    cache.Tracer.Visible = false
                end

                if ESP_Config.Names or ESP_Config.Distance or ESP_Config.Health then
                    local textStr = ""
                    if ESP_Config.Names then textStr = targetPlayer.DisplayName end
                    if ESP_Config.Distance then textStr = textStr .. string.format(" [%dm]", dist) end

                    if ESP_Config.Health and humanoid then
                        local hp = math.floor(humanoid.Health)
                        local maxHp = math.floor(humanoid.MaxHealth)
                        textStr = textStr .. string.format(" | %d/%d HP", hp, maxHp)
                    end

                    cache.NameTag.Text = textStr
                    cache.NameTag.Position = Vector2.new(position.X, position.Y - height / 2 - 16)
                    cache.NameTag.Color = (ESP_Config.Health and humanoid) and getHealthColor(humanoid.Health, humanoid.MaxHealth) or activeColor
                    cache.NameTag.Visible = true
                else
                    cache.NameTag.Visible = false
                end
            else
                cache.Box.Visible = false
                cache.Tracer.Visible = false
                cache.NameTag.Visible = false
            end
        else
            if ESP_Cache[obj] then clearEspObjects(obj) end
        end

        -- RADAR ESP LOGIC
        if ESP_Config.RadarEnabled and isAlive and myHRP then
            if not (ESP_Config.RadarTeamCheck and isTeammate) then
                if not Radar_Cache[obj] then createRadarDot(obj) end
                local dot = Radar_Cache[obj]

                local relPos = hrp.Position - myHRP.Position
                local camCFrame = Camera.CFrame
                local localX = relPos:Dot(camCFrame.RightVector)
                local localZ = relPos:Dot(camCFrame.LookVector)

                local rSize = ESP_Config.RadarSize
                local rRadius = rSize / 2
                local maxDist = ESP_Config.RadarMaxDistance

                local scale = rRadius / maxDist
                local radarX = localX * scale
                local radarY = -localZ * scale

                local clampedX = math.clamp(radarX, -rRadius + 5, rRadius - 5)
                local clampedY = math.clamp(radarY, -rRadius + 5, rRadius - 5)

                local center = ESP_Config.RadarPosition + Vector2.new(rRadius, rRadius)
                dot.Position = center + Vector2.new(clampedX, clampedY)
                dot.Color = isTeammate and ESP_Config.RadarTeamColor or ESP_Config.RadarColor
                dot.Visible = true
            else
                if Radar_Cache[obj] then clearRadarDot(obj) end
            end
        else
            if Radar_Cache[obj] then clearRadarDot(obj) end
        end
    end

    -- VIEWMODELS (SKELETON, GUN & ANTI-PERSONNEL)
    local viewmodelsFolder = workspace:FindFirstChild("Viewmodels")
    if viewmodelsFolder then
        local activeViewmodels = {}

        for _, vm in ipairs(viewmodelsFolder:GetChildren()) do
            if vm.Name ~= "LocalViewmodel" and not isTeammateViewmodel(vm) then
                activeViewmodels[vm] = true

                if not World_Cache[vm] then
                    World_Cache[vm] = {
                        SkeletonLines = {},
                        GunText = Drawing.new("Text"),
                        AntiPersonnelText = Drawing.new("Text")
                    }
                    World_Cache[vm].GunText.Size = 13
                    World_Cache[vm].GunText.Center = true
                    World_Cache[vm].GunText.Outline = true
                    World_Cache[vm].GunText.Color = ESP_Config.GunColor

                    World_Cache[vm].AntiPersonnelText.Size = 13
                    World_Cache[vm].AntiPersonnelText.Center = true
                    World_Cache[vm].AntiPersonnelText.Outline = true
                    World_Cache[vm].AntiPersonnelText.Color = ESP_Config.AntiPersonnelColor
                end

                local cache = World_Cache[vm]

                if ESP_Config.SkeletonESP and not isSkeletonTeammate(vm) then
                    local lineIdx = 0
                    local torsoPart = vm:FindFirstChild("torso") or vm:FindFirstChild("head")
                    local visible = torsoPart and isPartVisible(torsoPart) or false
                    local skelColor = ESP_Config.UseDynamicColors and (visible and ESP_Config.VisibleColor or ESP_Config.OccludedColor) or ESP_Config.VisibleColor

                    for _, bonePair in ipairs(bones) do
                        local p1 = vm:FindFirstChild(bonePair[1])
                        local p2 = vm:FindFirstChild(bonePair[2])

                        if p1 and p2 and p1:IsA("BasePart") and p2:IsA("BasePart") then
                            lineIdx = lineIdx + 1
                            if not cache.SkeletonLines[lineIdx] then
                                local line = Drawing.new("Line")
                                line.Thickness = 1.5
                                cache.SkeletonLines[lineIdx] = line
                            end

                            local pos1, onScreen1 = Camera:WorldToViewportPoint(p1.Position)
                            local pos2, onScreen2 = Camera:WorldToViewportPoint(p2.Position)

                            if onScreen1 and onScreen2 then
                                local line = cache.SkeletonLines[lineIdx]
                                line.From = Vector2.new(pos1.X, pos1.Y)
                                line.To = Vector2.new(pos2.X, pos2.Y)
                                line.Color = skelColor
                                line.Visible = true
                            else
                                cache.SkeletonLines[lineIdx].Visible = false
                            end
                        end
                    end

                    for i = lineIdx + 1, #cache.SkeletonLines do cache.SkeletonLines[i].Visible = false end
                else
                    for _, line in ipairs(cache.SkeletonLines) do line.Visible = false end
                end

                if ESP_Config.GunESP then
                    local gunModel = getGunModelFromViewmodel(vm)
                    local torsoOrHead = vm:FindFirstChild("torso") or vm:FindFirstChild("head")
                    if gunModel and torsoOrHead then
                        local pos, onScreen = Camera:WorldToViewportPoint(torsoOrHead.Position)
                        if onScreen then
                            cache.GunText.Text = string.format("< %s >", gunModel.Name)
                            cache.GunText.Position = Vector2.new(pos.X, pos.Y + 20)
                            cache.GunText.Visible = true
                        else cache.GunText.Visible = false end
                    else cache.GunText.Visible = false end
                else cache.GunText.Visible = false end

                if ESP_Config.AntiPersonnelESP then
                    local apModel = getAntiPersonnelModelFromViewmodel(vm)
                    local torsoOrHead = vm:FindFirstChild("torso") or vm:FindFirstChild("head")
                    if apModel and torsoOrHead then
                        local pos, onScreen = Camera:WorldToViewportPoint(torsoOrHead.Position)
                        if onScreen then
                            local offset = ESP_Config.GunESP and 35 or 20
                            cache.AntiPersonnelText.Text = string.format("[ %s ]", apModel.Name)
                            cache.AntiPersonnelText.Position = Vector2.new(pos.X, pos.Y + offset)
                            cache.AntiPersonnelText.Visible = true
                        else cache.AntiPersonnelText.Visible = false end
                    else cache.AntiPersonnelText.Visible = false end
                else cache.AntiPersonnelText.Visible = false end
            end
        end

        for vm, cache in pairs(World_Cache) do
            if not activeViewmodels[vm] or not vm.Parent then
                for _, line in ipairs(cache.SkeletonLines) do pcall(function() line:Remove() end) end
                pcall(function() cache.GunText:Remove() end)
                pcall(function() cache.AntiPersonnelText:Remove() end)
                World_Cache[vm] = nil
            end
        end
    else
        clearWorldCache()
    end

    -- TACTICAL GADGETS ESP
    if ESP_Config.GadgetESP then
        local activeGadgets = {}
        for _, obj in ipairs(workspace:GetDescendants()) do
            if isGadget(obj) then
                activeGadgets[obj] = true
                if not Gadget_Cache[obj] then
                    local text = Drawing.new("Text")
                    text.Size = 13
                    text.Center = true
                    text.Outline = true
                    text.Color = ESP_Config.GadgetColor
                    Gadget_Cache[obj] = text
                end

                local posWorld = getGadgetPosition(obj)
                if posWorld then
                    local pos, onScreen = Camera:WorldToViewportPoint(posWorld)
                    if onScreen then
                        local dist = math.floor((myHRP and (myHRP.Position - posWorld).Magnitude) or 0)
                        Gadget_Cache[obj].Text = string.format("[%s | %dm]", obj.Name, dist)
                        Gadget_Cache[obj].Position = Vector2.new(pos.X, pos.Y)
                        Gadget_Cache[obj].Visible = true
                    else Gadget_Cache[obj].Visible = false end
                else Gadget_Cache[obj].Visible = false end
            end
        end

        for obj, text in pairs(Gadget_Cache) do
            if not activeGadgets[obj] or not obj.Parent then
                pcall(function() text:Remove() end)
                Gadget_Cache[obj] = nil
            end
        end
    else
        for obj, text in pairs(Gadget_Cache) do pcall(function() text:Remove() end) Gadget_Cache[obj] = nil end
    end

    -- THROWN GRENADE ESP
    if ESP_Config.ThrownGrenadeESP then
        local activeGrenades = {}
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") then
                local grenadeType = getThrownGrenadeType(obj)
                if grenadeType then
                    activeGrenades[obj] = true
                    if not Grenade_Cache[obj] then
                        local text = Drawing.new("Text")
                        text.Size = 14
                        text.Center = true
                        text.Outline = true
                        text.Color = ESP_Config.GrenadeColor
                        Grenade_Cache[obj] = text
                    end

                    local primary = obj.PrimaryPart or obj:FindFirstChild("Root") or obj:FindFirstChildOfClass("BasePart")
                    if primary then
                        local pos, onScreen = Camera:WorldToViewportPoint(primary.Position)
                        if onScreen then
                            local dist = math.floor((myHRP and (myHRP.Position - primary.Position).Magnitude) or 0)
                            Grenade_Cache[obj].Text = string.format("[ %s | %dm ]", grenadeType, dist)
                            Grenade_Cache[obj].Position = Vector2.new(pos.X, pos.Y)
                            Grenade_Cache[obj].Visible = true
                        else Grenade_Cache[obj].Visible = false end
                    else Grenade_Cache[obj].Visible = false end
                end
            end
        end

        for obj, text in pairs(Grenade_Cache) do
            if not activeGrenades[obj] or not obj.Parent then
                pcall(function() text:Remove() end)
                Grenade_Cache[obj] = nil
            end
        end
    else
        for obj, text in pairs(Grenade_Cache) do pcall(function() text:Remove() end) Grenade_Cache[obj] = nil end
    end

    -- CAMERA ESP
    if ESP_Config.CameraESP then
        local activeCameras = {}
        for _, camData in ipairs(getMapCameras()) do
            local camModel, camPart = camData.Model, camData.Part
            activeCameras[camModel] = true

            if not Camera_Cache[camModel] then
                local text = Drawing.new("Text")
                text.Size = 13
                text.Center = true
                text.Outline = true
                text.Color = ESP_Config.CameraColor
                Camera_Cache[camModel] = text
            end

            local pos, onScreen = Camera:WorldToViewportPoint(camPart.Position)
            if onScreen then
                local dist = math.floor((myHRP and (myHRP.Position - camPart.Position).Magnitude) or 0)
                Camera_Cache[camModel].Text = string.format("[ Camera | %dm ]", dist)
                Camera_Cache[camModel].Position = Vector2.new(pos.X, pos.Y)
                Camera_Cache[camModel].Visible = true
            else Camera_Cache[camModel].Visible = false end
        end

        for model, text in pairs(Camera_Cache) do
            if not activeCameras[model] or not model.Parent then
                pcall(function() text:Remove() end)
                Camera_Cache[model] = nil
            end
        end
    else
        for model, text in pairs(Camera_Cache) do pcall(function() text:Remove() end) Camera_Cache[model] = nil end
    end

    -- DEFUSER ESP
    if ESP_Config.DefuserESP then
        local activeDefusers = {}
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj.Name == "Defuser" and obj:IsA("Model") then
                activeDefusers[obj] = true

                if not Defuser_Cache[obj] then
                    local text = Drawing.new("Text")
                    text.Size = 14
                    text.Center = true
                    text.Outline = true
                    text.Color = ESP_Config.DefuserColor
                    Defuser_Cache[obj] = text
                end

                local primary = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart") or obj:FindFirstChild("Root")
                if primary then
                    local pos, onScreen = Camera:WorldToViewportPoint(primary.Position)
                    if onScreen then
                        local dist = math.floor((myHRP and (myHRP.Position - primary.Position).Magnitude) or 0)
                        Defuser_Cache[obj].Text = string.format("[ Defuser | %dm ]", dist)
                        Defuser_Cache[obj].Position = Vector2.new(pos.X, pos.Y)
                        Defuser_Cache[obj].Visible = true
                    else Defuser_Cache[obj].Visible = false end
                else Defuser_Cache[obj].Visible = false end
            end
        end

        for obj, text in pairs(Defuser_Cache) do
            if not activeDefusers[obj] or not obj.Parent then
                pcall(function() text:Remove() end)
                Defuser_Cache[obj] = nil
            end
        end
    else
        for obj, text in pairs(Defuser_Cache) do pcall(function() text:Remove() end) Defuser_Cache[obj] = nil end
    end

    -- DRONE ESP
    if ESP_Config.DroneESP then
        local activeDrones = {}
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") and obj.Name == "Drone" then
                activeDrones[obj] = true

                if not Drone_Cache[obj] then
                    Drone_Cache[obj] = {
                        Box = Drawing.new("Square"),
                        Text = Drawing.new("Text")
                    }
                    Drone_Cache[obj].Box.Thickness = 1.5
                    Drone_Cache[obj].Box.Color = ESP_Config.DroneColor
                    Drone_Cache[obj].Box.Filled = false
                    Drone_Cache[obj].Box.Visible = false

                    Drone_Cache[obj].Text.Size = 13
                    Drone_Cache[obj].Text.Center = true
                    Drone_Cache[obj].Text.Outline = true
                    Drone_Cache[obj].Text.Visible = false
                end

                local cache = Drone_Cache[obj]
                local primary = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
                local humanoid = obj:FindFirstChildOfClass("Humanoid")

                if primary then
                    local pos, onScreen = Camera:WorldToViewportPoint(primary.Position)
                    if onScreen then
                        local dist = math.floor((myHRP and (myHRP.Position - primary.Position).Magnitude) or 0)
                        local scale = (1 / pos.Z) * 600
                        local width = math.clamp(2 * scale, 8, 80)
                        local height = math.clamp(2 * scale, 8, 80)

                        cache.Box.Size = Vector2.new(width, height)
                        cache.Box.Position = Vector2.new(pos.X - width / 2, pos.Y - height / 2)
                        cache.Box.Visible = true

                        local labelStr = string.format("[ Drone | %dm ]", dist)
                        if humanoid then
                            local hp = math.floor(humanoid.Health)
                            local maxHp = math.floor(humanoid.MaxHealth)
                            labelStr = labelStr .. string.format(" | %d/%d HP", hp, maxHp)
                            cache.Text.Color = getHealthColor(humanoid.Health, humanoid.MaxHealth)
                        else
                            cache.Text.Color = ESP_Config.DroneColor
                        end

                        cache.Text.Text = labelStr
                        cache.Text.Position = Vector2.new(pos.X, pos.Y - height / 2 - 15)
                        cache.Text.Visible = true
                    else
                        cache.Box.Visible = false
                        cache.Text.Visible = false
                    end
                else
                    cache.Box.Visible = false
                    cache.Text.Visible = false
                end
            end
        end

        for obj, cache in pairs(Drone_Cache) do
            if not activeDrones[obj] or not obj.Parent then
                pcall(function() cache.Box:Remove() end)
                pcall(function() cache.Text:Remove() end)
                Drone_Cache[obj] = nil
            end
        end
    else
        for obj, cache in pairs(Drone_Cache) do
            pcall(function() cache.Box:Remove() end)
            pcall(function() cache.Text:Remove() end)
            Drone_Cache[obj] = nil
        end
    end

    -- CLAYMORE ESP
    if ESP_Config.ClaymoreESP then
        local activeClaymores = {}
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") and obj.Name == "Claymore" then
                activeClaymores[obj] = true

                if not Claymore_Cache[obj] then
                    local text = Drawing.new("Text")
                    text.Size = 13
                    text.Center = true
                    text.Outline = true
                    text.Color = ESP_Config.ClaymoreColor
                    Claymore_Cache[obj] = text
                end

                local primary = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
                if primary then
                    local pos, onScreen = Camera:WorldToViewportPoint(primary.Position)
                    if onScreen then
                        local dist = math.floor((myHRP and (myHRP.Position - primary.Position).Magnitude) or 0)
                        Claymore_Cache[obj].Text = string.format("[ Claymore | %dm ]", dist)
                        Claymore_Cache[obj].Position = Vector2.new(pos.X, pos.Y)
                        Claymore_Cache[obj].Visible = true
                    else Claymore_Cache[obj].Visible = false end
                else Claymore_Cache[obj].Visible = false end
            end
        end

        for obj, text in pairs(Claymore_Cache) do
            if not activeClaymores[obj] or not obj.Parent then
                pcall(function() text:Remove() end)
                Claymore_Cache[obj] = nil
            end
        end
    else
        for obj, text in pairs(Claymore_Cache) do pcall(function() text:Remove() end) Claymore_Cache[obj] = nil end
    end
end)))

-- ============================================================================
-- 8. LOAD & INITIALIZE IRIS
-- ============================================================================
local Iris = loadstring(game:HttpGet("https://raw.githubusercontent.com/windbreaker7/Oxygen/refs/heads/main/iris_bundle.lua?" .. tick()))()

if Iris.Init then
    Iris.Init()
    
    task.defer(makeCClosure(hideStack(function()
        local irisGui = playerGui:FindFirstChild("Iris") or playerGui:FindFirstChildOfClass("ScreenGui")
        if irisGui then
            irisGui.Name = RANDOM_GUI_ID
            irisGui.Parent = targetParent
        end
    end)))
end

-- Preset Theme Definitions
local ThemePresets = {
    Dark = hideStack(function()
        if Iris.UpdateThemeDark then Iris.UpdateThemeDark() end
    end),
    Light = hideStack(function()
        if Iris.UpdateThemeLight then Iris.UpdateThemeLight() end
    end)
}

ThemePresets.Dark()

-- Dynamic States
local State_SetupX = Iris.State("0")
local State_SetupY = Iris.State("0")

local State_RadarSize = Iris.State(150)
local State_RadarMaxDist = Iris.State(200)
local State_RecoilX = Iris.State("0")
local State_RecoilY = Iris.State("0")

local State_AimFOV = Iris.State(120)
local State_AimSmooth = Iris.State(20)

local State_ConfigFileName = Iris.State("config.json")

local getValidFileName = hideStack(function(inputName)
    local name = inputName:match("^%s*(.-)%s*$")
    if name == "" then
        name = "default.json"
    end
    if not name:lower():find("%.json$") then
        name = name .. ".json"
    end
    return name
end)

local exportConfigJSON = hideStack(function()
    local data = {
        Aim = Aim_Config,
        ESP = ESP_Config,
        RecoilX = recoil_x,
        RecoilY = recoil_y,
        Theme = UI_Theme.CurrentTheme
    }
    local success, result = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if success then
        return result
    end
    return ""
end)

local importConfigJSON = hideStack(function(jsonStr)
    local success, data = pcall(function()
        return HttpService:JSONDecode(jsonStr)
    end)
    if success and type(data) == "table" then
        if data.Aim then
            for k, v in pairs(data.Aim) do
                Aim_Config[k] = v
            end
            State_AimFOV:set(Aim_Config.FOV)
            State_AimSmooth:set(math.floor(Aim_Config.Smoothness * 100))
        end
        if data.ESP then
            for k, v in pairs(data.ESP) do
                ESP_Config[k] = v
            end
        end
        if data.RecoilX then 
            recoil_x = data.RecoilX 
            State_RecoilX:set(tostring(recoil_x))
        end
        if data.RecoilY then 
            recoil_y = data.RecoilY 
            State_RecoilY:set(tostring(recoil_y))
        end
        if data.Theme and ThemePresets[data.Theme] then
            UI_Theme.CurrentTheme = data.Theme
            ThemePresets[data.Theme]()
        end
    end
end)

-- ============================================================================
-- 9. RENDER IRIS UI (FULL STACK HIDDEN)
-- ============================================================================
Iris:Connect(makeCClosure(hideStack(function()
    if not IsSetupComplete then
        Iris.Window({"Initial Setup - Weapon Recoil Calibration"}, {NoClose = true, NoResize = true})
            Iris.Text({"Set your initial Recoil values BEFORE loading the system:"})
            Iris.Separator()
            
            Iris.InputText({"Recoil X (Horizontal)"}, {text = State_SetupX})
            Iris.InputText({"Recoil Y (Vertical)"}, {text = State_SetupY})
            
            Iris.Separator()
            local startBtn = Iris.Button({"Confirm & Launch System"})
            if startBtn.clicked then
                local numX = tonumber(State_SetupX.value) or 0
                local numY = tonumber(State_SetupY.value) or 0
                
                recoil_x = numX
                recoil_y = numY
                
                State_RecoilX:set(tostring(numX))
                State_RecoilY:set(tostring(numY))
                
                executeNoRecoilHook(numX, numY)
                IsSetupComplete = true
            end
            
            local skipBtn = Iris.Button({"Skip No Recoil (Default Off)"})
            if skipBtn.clicked then
                recoil_x = 0
                recoil_y = 0
                IsSetupComplete = true
            end
        Iris.End()
        return
    end

    Iris.Window({"Imgui Wannabes"})
        Iris.Text({string.format("FPS: %d | Ping: %d ms", fps, ping)})
        Iris.Separator()

        Iris.TabBar()

            -- TAB 1: AIMTOUCH
            Iris.Tab({"AimTouch"})
                local aimToggle = Iris.Checkbox({"Enable AimTouch"})
                if aimToggle.clicked then
                    Aim_Config.Enabled = aimToggle.state.isChecked.value
                end

                local teamToggle = Iris.Checkbox({"Team Check"})
                if teamToggle.clicked then
                    Aim_Config.TeamCheck = teamToggle.state.isChecked.value
                end

                local wallToggle = Iris.Checkbox({"Wall Check (Visible Only)"})
                if wallToggle.clicked then
                    Aim_Config.WallCheck = wallToggle.state.isChecked.value
                end

                local fovCheckToggle = Iris.Checkbox({"POV / FOV Check"})
                if fovCheckToggle.clicked then
                    Aim_Config.FOVCheck = fovCheckToggle.state.isChecked.value
                end

                local fovToggle = Iris.Checkbox({"Draw POV Circle"})
                if fovToggle.clicked then
                    Aim_Config.ShowFOV = fovToggle.state.isChecked.value
                end

                Iris.Separator()

                Iris.Text({"Target Selection Priority:"})
                local prioCrosshair = Iris.Button({"Priority: Crosshair Distance"})
                if prioCrosshair.clicked then Aim_Config.PriorityMode = "Crosshair" end

                local prioDist = Iris.Button({"Priority: Closest Player"})
                if prioDist.clicked then Aim_Config.PriorityMode = "Distance" end

                local prioHp = Iris.Button({"Priority: Lowest Health"})
                if prioHp.clicked then Aim_Config.PriorityMode = "Health" end

                Iris.Text({"Active Mode: " .. Aim_Config.PriorityMode})
                Iris.Separator()

                local fovInput = Iris.InputNum({"POV Circle Radius"}, {number = State_AimFOV, min = 10, max = 500})
                if fovInput.numberChanged then
                    Aim_Config.FOV = State_AimFOV.value
                end

                local smoothInput = Iris.InputNum({"Smoothness % (Higher = Slower)"}, {number = State_AimSmooth, min = 1, max = 100})
                if smoothInput.numberChanged then
                    Aim_Config.Smoothness = State_AimSmooth.value / 100
                end

                Iris.Separator()
                Iris.Text({"Target Bone Selection:"})

                local headBtn = Iris.Button({"Target: Head"})
                if headBtn.clicked then
                    Aim_Config.TargetPart = "head"
                    Aim_Config.AimTouchParts = { "head", "torso", "UpperTorso" }
                end

                local torsoBtn = Iris.Button({"Target: Torso"})
                if torsoBtn.clicked then
                    Aim_Config.TargetPart = "torso"
                    Aim_Config.AimTouchParts = { "torso", "UpperTorso", "head" }
                end

                Iris.Text({"Active Target Part: " .. Aim_Config.TargetPart:upper()})
            Iris.End()

            -- TAB 2: VISUALS
            Iris.Tab({"Visuals"})
                local espTree = Iris.Tree({"Player ESP"})
                if espTree.state.isUncollapsed.value then
                    local mainToggle = Iris.Checkbox({"Master ESP Toggle"})
                    if mainToggle.clicked then
                        ESP_Config.Enabled = mainToggle.state.isChecked.value
                    end

                    local teamToggle = Iris.Checkbox({"Team Check"})
                    if teamToggle.clicked then
                        ESP_Config.TeamCheck = teamToggle.state.isChecked.value
                    end

                    local dynamicColorsToggle = Iris.Checkbox({"Dynamic Colors (Vis vs Occluded)"})
                    if dynamicColorsToggle.clicked then
                        ESP_Config.UseDynamicColors = dynamicColorsToggle.state.isChecked.value
                    end

                    local boxToggle = Iris.Checkbox({"Bounding Boxes"})
                    if boxToggle.clicked then
                        ESP_Config.Boxes = boxToggle.state.isChecked.value
                    end

                    local tracerToggle = Iris.Checkbox({"Tracers"})
                    if tracerToggle.clicked then
                        ESP_Config.Tracers = tracerToggle.state.isChecked.value
                    end

                    local nameToggle = Iris.Checkbox({"Names & Distance"})
                    if nameToggle.clicked then
                        ESP_Config.Names = nameToggle.state.isChecked.value
                        ESP_Config.Distance = nameToggle.state.isChecked.value
                    end

                    local healthToggle = Iris.Checkbox({"Health ESP"})
                    if healthToggle.clicked then
                        ESP_Config.Health = healthToggle.state.isChecked.value
                    end

                    local skelToggle = Iris.Checkbox({"Skeleton ESP"})
                    if skelToggle.clicked then
                        ESP_Config.SkeletonESP = skelToggle.state.isChecked.value
                    end
                end
                Iris.End()

                local radarTree = Iris.Tree({"2D Radar ESP"})
                if radarTree.state.isUncollapsed.value then
                    local radarToggle = Iris.Checkbox({"Enable Radar"})
                    if radarToggle.clicked then
                        ESP_Config.RadarEnabled = radarToggle.state.isChecked.value
                    end

                    local rTeamToggle = Iris.Checkbox({"Radar Team Check"})
                    if rTeamToggle.clicked then
                        ESP_Config.RadarTeamCheck = rTeamToggle.state.isChecked.value
                    end

                    local rBgToggle = Iris.Checkbox({"Show Background"})
                    if rBgToggle.clicked then
                        ESP_Config.RadarBackground = rBgToggle.state.isChecked.value
                    end

                    local rBorderToggle = Iris.Checkbox({"Show Border"})
                    if rBorderToggle.clicked then
                        ESP_Config.RadarBorder = rBorderToggle.state.isChecked.value
                    end

                    local sizeInput = Iris.InputNum({"Radar Size (px)"}, {number = State_RadarSize, min = 100, max = 400})
                    if sizeInput.numberChanged then
                        ESP_Config.RadarSize = State_RadarSize.value
                    end

                    local distInput = Iris.InputNum({"Max Distance (m)"}, {number = State_RadarMaxDist, min = 50, max = 500})
                    if distInput.numberChanged then
                        ESP_Config.RadarMaxDistance = State_RadarMaxDist.value
                    end
                end
                Iris.End()

                local worldTree = Iris.Tree({"World ESP"})
                if worldTree.state.isUncollapsed.value then
                    local gadgetToggle = Iris.Checkbox({"Gadget ESP"})
                    if gadgetToggle.clicked then
                        ESP_Config.GadgetESP = gadgetToggle.state.isChecked.value
                    end

                    local gunToggle = Iris.Checkbox({"Gun ESP"})
                    if gunToggle.clicked then
                        ESP_Config.GunESP = gunToggle.state.isChecked.value
                    end

                    local apToggle = Iris.Checkbox({"Anti-Personnel Tools ESP"})
                    if apToggle.clicked then
                        ESP_Config.AntiPersonnelESP = apToggle.state.isChecked.value
                    end

                    local gToggle = Iris.Checkbox({"Thrown Grenade ESP"})
                    if gToggle.clicked then
                        ESP_Config.ThrownGrenadeESP = gToggle.state.isChecked.value
                    end

                    local camToggle = Iris.Checkbox({"Camera ESP"})
                    if camToggle.clicked then
                        ESP_Config.CameraESP = camToggle.state.isChecked.value
                    end

                    local defuserToggle = Iris.Checkbox({"Defuser ESP"})
                    if defuserToggle.clicked then
                        ESP_Config.DefuserESP = defuserToggle.state.isChecked.value
                    end

                    local droneToggle = Iris.Checkbox({"Drone ESP"})
                    if droneToggle.clicked then
                        ESP_Config.DroneESP = droneToggle.state.isChecked.value
                    end

                    local claymoreToggle = Iris.Checkbox({"Claymore ESP"})
                    if claymoreToggle.clicked then
                        ESP_Config.ClaymoreESP = claymoreToggle.state.isChecked.value
                    end
                end
                Iris.End()
            Iris.End()

            -- TAB 3: MISC
            Iris.Tab({"Misc"})
                local recoilTree = Iris.Tree({"Weapon Mods"})
                if recoilTree.state.isUncollapsed.value then
                    Iris.InputText({"Recoil X Multiplier"}, {text = State_RecoilX})
                    Iris.InputText({"Recoil Y Multiplier"}, {text = State_RecoilY})
                    
                    local applyButton = Iris.Button({"Update Recoil Active Values"})
                    if applyButton.clicked then
                        local numX = tonumber(State_RecoilX.value)
                        local numY = tonumber(State_RecoilY.value)
                        
                        if numX then recoil_x = numX end
                        if numY then recoil_y = numY end

                        executeNoRecoilHook(recoil_x, recoil_y)
                    end

                    local loadButton = Iris.Button({"Reset to Zero (0, 0)"})
                    if loadButton.clicked then
                        recoil_x = 0
                        recoil_y = 0
                        State_RecoilX:set("0")
                        State_RecoilY:set("0")
                        executeNoRecoilHook(0, 0)
                    end
                    
                    Iris.Text({string.format("Current Active: Recoil X = %s, Recoil Y = %s", tostring(recoil_x), tostring(recoil_y))})
                    Iris.Text({Misc_Config.NoRecoilLoaded and "Status: Hook Active" or "Status: Load Pending"})
                end
                Iris.End()
            Iris.End()

            -- TAB 4: SETTINGS
            Iris.Tab({"Settings"})
                local themeTree = Iris.Tree({"UI Themes"})
                if themeTree.state.isUncollapsed.value then
                    Iris.Text({"Select Preset Theme:"})
                    
                    local darkBtn = Iris.Button({"Dark Theme"})
                    if darkBtn.clicked then
                        UI_Theme.CurrentTheme = "Dark"
                        ThemePresets.Dark()
                    end

                    local lightBtn = Iris.Button({"Light Theme"})
                    if lightBtn.clicked then
                        UI_Theme.CurrentTheme = "Light"
                        ThemePresets.Light()
                    end
                end
                Iris.End()

                local configTree = Iris.Tree({"Configuration Manager"})
                if configTree.state.isUncollapsed.value then
                    Iris.Text({"Enter config file name (e.g. haha.json):"})
                    
                    Iris.InputText({"File Name"}, {text = State_ConfigFileName})
                    Iris.Separator()

                    local saveBtn = Iris.Button({"Save Config File"})
                    if saveBtn.clicked then
                        local fileName = getValidFileName(State_ConfigFileName.value)
                        local jsonStr = exportConfigJSON()
                        
                        if writefile then
                            local success, err = pcall(function()
                                writefile(fileName, jsonStr)
                            end)
                            if success then
                                print("[+] Saved config to " .. fileName)
                            else
                                warn("[-] Failed to write file:", err)
                            end
                        else
                            warn("[-] writefile function not supported by executor environment.")
                        end
                    end

                    local loadBtn = Iris.Button({"Load Config File"})
                    if loadBtn.clicked then
                        local fileName = getValidFileName(State_ConfigFileName.value)
                        
                        if readfile and isfile then
                            if isfile(fileName) then
                                local success, content = pcall(function()
                                    return readfile(fileName)
                                end)
                                if success and content then
                                    importConfigJSON(content)
                                    print("[+] Successfully loaded " .. fileName)
                                else
                                    warn("[-] Failed to read file content.")
                                end
                            else
                                warn("[-] File does not exist: " .. fileName)
                            end
                        else
                            warn("[-] File reading functions not supported by executor environment.")
                        end
                    end
                end
                Iris.End()
            Iris.End()

            -- TAB 5: PLAYERS
            Iris.Tab({"Players"})
                Iris.Text({string.format("Players Online: %d", #Players:GetPlayers())})
                Iris.Separator()
                for _, player in ipairs(Players:GetPlayers()) do
                    local isLocal = (player == LocalPlayer)
                    local tag = isLocal and " [YOU]" or ""
                    Iris.Text({string.format("• %s (@%s)%s", player.DisplayName, player.Name, tag)})
                end
            Iris.End()

            -- TAB 6: THANKS TO
            Iris.Tab({"Thanks To"})
                Iris.Text({"Special Thanks & External Code Contributions:"})
                Iris.Separator()
                
                local recoilCredits = Iris.Tree({"d2o-lang"})
                if recoilCredits.state.isUncollapsed.value then
                    Iris.Text({"• Feature: Parallel Luau Actor No Recoil Hook"})
                    Iris.Text({"• Source: github.com/d2o-lang/OpenSource"})
                end
                Iris.End()

                local uiCredits = Iris.Tree({"windbreaker7"})
                if uiCredits.state.isUncollapsed.value then
                    Iris.Text({"• Feature: Iris UI Engine & Bundler"})
                    Iris.Text({"• Source: github.com/windbreaker7/Oxygen"})
                end
                Iris.End()
            Iris.End()

        Iris.End()

    Iris.End()
})))
