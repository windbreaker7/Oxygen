-- ============================================================================
-- CREDITS & ACKNOWLEDGMENTS:
-- • No Recoil Hook Method by d2o-lang
--   https://github.com/d2o-lang/OpenSource
-- • Iris UI Library Bundle by windbreaker7
--   https://github.com/windbreaker7/Oxygen
-- ============================================================================

-- Safe cloneref wrapper
local getService = function(serviceName)
    local service = game:GetService(serviceName)
    if cloneref then
        return cloneref(service)
    end
    return service
end

-- Safe newcclosure wrapper
local makeCClosure = function(func)
    if newcclosure then
        return newcclosure(func)
    end
    return func
end

local Players = getService("Players")
local RunService = getService("RunService")
local Stats = getService("Stats")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local targetParent = (gethui and gethui()) or getService("CoreGui")

-- ============================================================================
-- 1. CLEANUP OLD INSTANCES
-- ============================================================================
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

for _, parentContainer in ipairs({targetParent, playerGui}) do
    for _, child in ipairs(parentContainer:GetChildren()) do
        if child.Name == "Oxygen_Iris_UI" or child.Name == "Iris" or child.Name == "Oxygen_Highlight_Folder" then
            child:Destroy()
        end
    end
end

-- ============================================================================
-- 2. CONFIGURATION & STATE
-- ============================================================================
local recoil_x = 0
local recoil_y = 0

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
    
    BoxColor = Color3.fromRGB(0, 255, 140),
    TracerColor = Color3.fromRGB(0, 255, 140),
    SkeletonColor = Color3.fromRGB(255, 255, 0),
    GunColor = Color3.fromRGB(255, 170, 0),
    AntiPersonnelColor = Color3.fromRGB(255, 50, 50),
    GrenadeColor = Color3.fromRGB(255, 0, 0),
    CameraColor = Color3.fromRGB(0, 180, 255),
    DefuserColor = Color3.fromRGB(0, 255, 100),
    DroneColor = Color3.fromRGB(255, 200, 0),
    ClaymoreColor = Color3.fromRGB(255, 30, 30)
}

local Misc_Config = {
    NoRecoilLoaded = false
}

local ESP_Cache = {}
local World_Cache = {}
local Grenade_Cache = {}
local Camera_Cache = {}
local Defuser_Cache = {}
local Drone_Cache = {}
local Claymore_Cache = {}
local Radar_Cache = {}
local TrackedModels = {}

local SkeletonPartNames = {
    "arm1", "arm2", "head", "hip1", "hip2",
    "leg1", "leg2", "shoulder1", "shoulder2", "torso"
}

local GunPartNames = { "Barrel", "Base", "Grip", "Trigger", "Stock" }
local AntiPersonnelPartNames = { "Cap", "Lever", "Ring" }
local GrenadePartNames = { "Cap", "Root", "Ring" }

local fps = 0
local ping = 0
local frameCount = 0
local lastUpdate = os.clock()

RunService.RenderStepped:Connect(makeCClosure(function()
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
end))

local function loadExternalNoRecoil()
    getgenv().RecoilX = recoil_x
    getgenv().RecoilY = recoil_y

    if Misc_Config.NoRecoilLoaded then 
        return 
    end

    task.spawn(makeCClosure(function()
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/d2o-lang/OpenSource/refs/heads/main/n_recoil.lua"))()
        end)
        if success then
            Misc_Config.NoRecoilLoaded = true
        else
            warn("[-] Failed to load No Recoil script:", err)
        end
    end))
end

-- ============================================================================
-- 3. RADAR DRAWING ELEMENTS
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

local function createRadarDot(key)
    if Radar_Cache[key] then return end
    local dot = Drawing.new("Circle")
    dot.Radius = 3.5
    dot.Filled = true
    dot.Visible = false
    Radar_Cache[key] = dot
end

local function clearRadarDot(key)
    if Radar_Cache[key] then
        pcall(function() Radar_Cache[key]:Remove() end)
        Radar_Cache[key] = nil
    end
end

-- ============================================================================
-- 4. DRAWING & CACHE MANAGEMENT
-- ============================================================================
local function createEspObjects(modelKey)
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
end

local function clearEspObjects(modelKey)
    if ESP_Cache[modelKey] then
        for _, obj in pairs(ESP_Cache[modelKey]) do
            pcall(function() obj:Remove() end)
        end
        ESP_Cache[modelKey] = nil
    end
end

local function clearWorldCache()
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
end

local function isModelPartMatch(model, partNames)
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
end

local function isAntiPersonnelModel(model)
    for _, part in ipairs(model:GetChildren()) do
        if part:IsA("UnionOperation") then
            for _, apPart in ipairs(AntiPersonnelPartNames) do
                if part.Name:find(apPart) then return true end
            end
        end
    end
    return false
end

local function isGunModel(model)
    for _, part in ipairs(model:GetChildren()) do
        if part:IsA("UnionOperation") then
            for _, gunPart in ipairs(GunPartNames) do
                if part.Name:find(gunPart) then return true end
            end
        end
    end
    return false
end

local function getThrownGrenadeType(model)
    local clientModel = model:FindFirstChild("ClientModel")
    if clientModel and clientModel:IsA("ObjectValue") and clientModel.Value then
        local valName = clientModel.Value.Name
        if (valName == "FragGrenade" or valName == "StunGrenade") and isModelPartMatch(model, GrenadePartNames) then
            return valName == "FragGrenade" and "Frag Grenade" or "Stun Grenade"
        end
    end
    return nil
end

local function getGunModelFromViewmodel(vm)
    for _, child in ipairs(vm:GetChildren()) do
        if child:IsA("Model") and not isAntiPersonnelModel(child) and isGunModel(child) then
            return child
        end
    end
    return nil
end

local function getAntiPersonnelModelFromViewmodel(vm)
    for _, child in ipairs(vm:GetChildren()) do
        if child:IsA("Model") and not isGunModel(child) and isAntiPersonnelModel(child) then
            return child
        end
    end
    return nil
end

local function getHealthColor(health, maxHealth)
    local pct = math.clamp(health / (maxHealth > 0 and maxHealth or 100), 0, 1)
    return Color3.fromRGB(math.floor(255 * (1 - pct)), math.floor(255 * pct), 0)
end

local function getMapCameras()
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
end

-- ============================================================================
-- 5. FAST WORKSPACE SCANNER
-- ============================================================================
local function scanWorkspaceForPlayers()
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
end

task.spawn(makeCClosure(function()
    while true do
        scanWorkspaceForPlayers()
        task.wait(0.5)
    end
end))

-- ============================================================================
-- 6. RENDER LOOP
-- ============================================================================
RunService.RenderStepped:Connect(makeCClosure(function()
    if not ESP_Config.Enabled then
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

            if onScreen then
                local dist = math.floor((myHRP and (myHRP.Position - hrp.Position).Magnitude) or 0)
                local scale = (1 / position.Z) * 1000
                local width = math.clamp(4 * scale, 10, 150)
                local height = math.clamp(6 * scale, 15, 200)

                if ESP_Config.Boxes then
                    cache.Box.Size = Vector2.new(width, height)
                    cache.Box.Position = Vector2.new(position.X - width / 2, position.Y - height / 2)
                    cache.Box.Color = ESP_Config.BoxColor
                    cache.Box.Visible = true
                else
                    cache.Box.Visible = false
                end

                if ESP_Config.Tracers then
                    cache.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    cache.Tracer.To = Vector2.new(position.X, position.Y + height / 2)
                    cache.Tracer.Color = ESP_Config.TracerColor
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
                    cache.NameTag.Color = (ESP_Config.Health and humanoid) and getHealthColor(humanoid.Health, humanoid.MaxHealth) or Color3.fromRGB(255, 255, 255)
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

    -- VIEWMODELS
    local viewmodelsFolder = workspace:FindFirstChild("Viewmodels")
    if viewmodelsFolder then
        local activeViewmodels = {}

        for _, vm in ipairs(viewmodelsFolder:GetChildren()) do
            if vm.Name ~= "LocalViewmodel" then
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

                if ESP_Config.SkeletonESP then
                    local parts = {}
                    for _, pName in ipairs(SkeletonPartNames) do parts[pName] = vm:FindFirstChild(pName) end

                    local connections = {
                        {parts.torso, parts.head},
                        {parts.torso, parts.shoulder1},
                        {parts.torso, parts.shoulder2},
                        {parts.shoulder1, parts.arm1},
                        {parts.shoulder2, parts.arm2},
                        {parts.torso, parts.hip1},
                        {parts.torso, parts.hip2},
                        {parts.hip1, parts.leg1},
                        {parts.hip2, parts.leg2}
                    }

                    local lineIdx = 0
                    for _, pair in ipairs(connections) do
                        local p1, p2 = pair[1], pair[2]
                        if p1 and p2 and p1:IsA("BasePart") and p2:IsA("BasePart") then
                            lineIdx = lineIdx + 1
                            if not cache.SkeletonLines[lineIdx] then
                                local line = Drawing.new("Line")
                                line.Thickness = 1.5
                                line.Color = ESP_Config.SkeletonColor
                                cache.SkeletonLines[lineIdx] = line
                            end

                            local pos1, onScreen1 = Camera:WorldToViewportPoint(p1.Position)
                            local pos2, onScreen2 = Camera:WorldToViewportPoint(p2.Position)

                            if onScreen1 and onScreen2 then
                                local line = cache.SkeletonLines[lineIdx]
                                line.From = Vector2.new(pos1.X, pos1.Y)
                                line.To = Vector2.new(pos2.X, pos2.Y)
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
end))

-- ============================================================================
-- 7. LOAD & INITIALIZE IRIS
-- ============================================================================
local Iris = loadstring(game:HttpGet("https://raw.githubusercontent.com/windbreaker7/Oxygen/refs/heads/main/iris_bundle.lua?" .. tick()))()

if Iris.UpdateGlobalConfig then
    Iris.UpdateGlobalConfig({
        WindowBg = Color3.fromRGB(15, 15, 18),
        WindowBgTransparency = 0.5,
        FrameBg = Color3.fromRGB(25, 25, 30),
        FrameBgTransparency = 0.35,
        Button = Color3.fromRGB(30, 30, 38),
        ButtonHovered = Color3.fromRGB(45, 45, 55),
        ButtonActive = Color3.fromRGB(0, 255, 140),
        Header = Color3.fromRGB(20, 20, 25),
        Text = Color3.fromRGB(240, 240, 240)
    })
end

if Iris.Init then
    Iris.Init()
    
    task.defer(makeCClosure(function()
        local irisGui = playerGui:FindFirstChild("Iris") or playerGui:FindFirstChildOfClass("ScreenGui")
        if irisGui then
            irisGui.Name = "Oxygen_Iris_UI"
            irisGui.Parent = targetParent
        end
    end))
end

-- DELTA / ANDROID SPECIFIC FILE PATH RESOLVER
local cachedAssetId = nil

local function getDeltaAsset()
    if cachedAssetId then return cachedAssetId end

    local relativePath = "background.jpeg"
    local fullPath = "/storage/emulated/0/Delta/Workspace/background.jpeg"

    if getcustomasset then
        -- 1. Try standard workspace relative path
        if isfile and isfile(relativePath) then
            local success, res = pcall(getcustomasset, relativePath)
            if success and res then
                cachedAssetId = res
                return cachedAssetId
            end
        end

        -- 2. Try direct absolute Delta path
        local success, res = pcall(getcustomasset, fullPath)
        if success and res then
            cachedAssetId = res
            return cachedAssetId
        end
    end

    return nil
end

-- Inject image inside Iris Window Frame
local function updateWindowBackground(windowInstance)
    if not windowInstance or not windowInstance.Instance then return end
    
    local frame = windowInstance.Instance
    frame.ClipsDescendants = true
    
    local bg = frame:FindFirstChild("IrisDeltaBG")
    if not bg then
        local asset = getDeltaAsset()
        if not asset then return end

        bg = Instance.new("ImageLabel")
        bg.Name = "IrisDeltaBG"
        bg.Image = asset
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.Position = UDim2.new(0, 0, 0, 0)
        bg.BackgroundTransparency = 1
        bg.ImageTransparency = 0.35
        bg.ImageColor3 = Color3.fromRGB(255, 255, 255)
        bg.ScaleType = Enum.ScaleType.Crop
        bg.ZIndex = 0
        bg.Active = false
        bg.Parent = frame
    end
end

-- ============================================================================
-- 8. RENDER UI
-- ============================================================================
Iris:Connect(makeCClosure(function()
    local mainWindow = Iris.Window({"Imgui Wannabes"}, {
        size = Iris.State and Iris.State(Vector2.new(520, 380)) or Vector2.new(520, 380)
    })
    
    -- Inject background directly inside Iris Window Instance
    updateWindowBackground(mainWindow)
        
        Iris.Text({string.format("FPS: %d | Ping: %d ms", fps, ping)})
        Iris.Separator()

        Iris.TabBar()

            -- TAB 1: VISUALS
            Iris.Tab({"Visuals"})
                -- PLAYER ESP
                local espTree = Iris.Tree({"Player ESP"})
                if espTree.state.isUncollapsed.value then
                    local mainToggle = Iris.Checkbox({"Master ESP Toggle"})
                    if mainToggle.numberChanged or mainToggle.clicked then
                        ESP_Config.Enabled = mainToggle.state.isChecked.value
                    end

                    local teamToggle = Iris.Checkbox({"Team Check"})
                    if teamToggle.numberChanged or teamToggle.clicked then
                        ESP_Config.TeamCheck = teamToggle.state.isChecked.value
                    end

                    local boxToggle = Iris.Checkbox({"Bounding Boxes"})
                    if boxToggle.numberChanged or boxToggle.clicked then
                        ESP_Config.Boxes = boxToggle.state.isChecked.value
                    end

                    local tracerToggle = Iris.Checkbox({"Tracers"})
                    if tracerToggle.numberChanged or tracerToggle.clicked then
                        ESP_Config.Tracers = tracerToggle.state.isChecked.value
                    end

                    local nameToggle = Iris.Checkbox({"Names & Distance"})
                    if nameToggle.numberChanged or nameToggle.clicked then
                        ESP_Config.Names = nameToggle.state.isChecked.value
                        ESP_Config.Distance = nameToggle.state.isChecked.value
                    end

                    local healthToggle = Iris.Checkbox({"Health ESP"})
                    if healthToggle.numberChanged or healthToggle.clicked then
                        ESP_Config.Health = healthToggle.state.isChecked.value
                    end

                    local skelToggle = Iris.Checkbox({"Skeleton ESP"})
                    if skelToggle.numberChanged or skelToggle.clicked then
                        ESP_Config.SkeletonESP = skelToggle.state.isChecked.value
                    end
                end
                Iris.End()

                -- RADAR ESP
                local radarTree = Iris.Tree({"2D Radar ESP"})
                if radarTree.state.isUncollapsed.value then
                    local radarToggle = Iris.Checkbox({"Enable Radar"})
                    if radarToggle.numberChanged or radarToggle.clicked then
                        ESP_Config.RadarEnabled = radarToggle.state.isChecked.value
                    end

                    local rTeamToggle = Iris.Checkbox({"Radar Team Check"})
                    if rTeamToggle.numberChanged or rTeamToggle.clicked then
                        ESP_Config.RadarTeamCheck = rTeamToggle.state.isChecked.value
                    end

                    local rBgToggle = Iris.Checkbox({"Show Background"})
                    if rBgToggle.numberChanged or rBgToggle.clicked then
                        ESP_Config.RadarBackground = rBgToggle.state.isChecked.value
                    end

                    local rBorderToggle = Iris.Checkbox({"Show Border"})
                    if rBorderToggle.numberChanged or rBorderToggle.clicked then
                        ESP_Config.RadarBorder = rBorderToggle.state.isChecked.value
                    end

                    local sizeSlider = Iris.SliderNum({"Radar Size (px)", 100, 400})
                    if sizeSlider.numberChanged or sizeSlider.clicked then
                        ESP_Config.RadarSize = sizeSlider.state.number.value
                    end

                    local distSlider = Iris.SliderNum({"Max Distance (m)", 50, 500})
                    if distSlider.numberChanged or distSlider.clicked then
                        ESP_Config.RadarMaxDistance = distSlider.state.number.value
                    end
                end
                Iris.End()

                -- WORLD ESP
                local worldTree = Iris.Tree({"World ESP"})
                if worldTree.state.isUncollapsed.value then
                    local gunToggle = Iris.Checkbox({"Gun ESP"})
                    if gunToggle.numberChanged or gunToggle.clicked then
                        ESP_Config.GunESP = gunToggle.state.isChecked.value
                    end

                    local apToggle = Iris.Checkbox({"Anti-Personnel Tools ESP"})
                    if apToggle.numberChanged or apToggle.clicked then
                        ESP_Config.AntiPersonnelESP = apToggle.state.isChecked.value
                    end

                    local gToggle = Iris.Checkbox({"Thrown Grenade ESP"})
                    if gToggle.numberChanged or gToggle.clicked then
                        ESP_Config.ThrownGrenadeESP = gToggle.state.isChecked.value
                    end

                    local camToggle = Iris.Checkbox({"Camera ESP"})
                    if camToggle.numberChanged or camToggle.clicked then
                        ESP_Config.CameraESP = camToggle.state.isChecked.value
                    end

                    local defuserToggle = Iris.Checkbox({"Defuser ESP"})
                    if defuserToggle.numberChanged or defuserToggle.clicked then
                        ESP_Config.DefuserESP = defuserToggle.state.isChecked.value
                    end

                    local droneToggle = Iris.Checkbox({"Drone ESP"})
                    if droneToggle.numberChanged or droneToggle.clicked then
                        ESP_Config.DroneESP = droneToggle.state.isChecked.value
                    end

                    local claymoreToggle = Iris.Checkbox({"Claymore ESP"})
                    if claymoreToggle.numberChanged or claymoreToggle.clicked then
                        ESP_Config.ClaymoreESP = claymoreToggle.state.isChecked.value
                    end
                end
                Iris.End()
            Iris.End()

            -- TAB 2: MISC
            Iris.Tab({"Misc"})
                local recoilTree = Iris.Tree({"Weapon Mods"})
                if recoilTree.state.isUncollapsed.value then
                    local inputX = Iris.InputText({"Recoil X Multiplier"})
                    local inputY = Iris.InputText({"Recoil Y Multiplier"})
                    
                    local applyButton = Iris.Button({"Apply Custom Values"})
                    if applyButton.clicked then
                        local numX = tonumber(inputX.state.text.value)
                        local numY = tonumber(inputY.state.text.value)
                        
                        if numX then recoil_x = numX end
                        if numY then recoil_y = numY end

                        loadExternalNoRecoil()
                    end

                    local loadButton = Iris.Button({"Load/Apply Default No Recoil (0, 0)"})
                    if loadButton.clicked then
                        recoil_x = 0
                        recoil_y = 0
                        loadExternalNoRecoil()
                    end
                    
                    Iris.Text({function() return string.format("Current Values: Recoil X = %s, Recoil Y = %s", tostring(recoil_x), tostring(recoil_y)) end})
                    Iris.Text({function() 
                        if Misc_Config.NoRecoilLoaded then
                            return "Status: No Recoil Active"
                        else
                            return "Status: Not Loaded"
                        end
                    end})
                end
                Iris.End()
            Iris.End()

            -- TAB 3: PLAYERS
            Iris.Tab({"Players"})
                Iris.Text({string.format("Players Online: %d", #Players:GetPlayers())})
                Iris.Separator()
                for _, player in ipairs(Players:GetPlayers()) do
                    local isLocal = (player == LocalPlayer)
                    local tag = isLocal and " [YOU]" or ""
                    Iris.Text({string.format("• %s (@%s)%s", player.DisplayName, player.Name, tag)})
                end
            Iris.End()

            -- TAB 4: THANKS TO
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
end))
