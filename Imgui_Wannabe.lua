-- ============================================================================
-- THE LOST FRONT - CHAMS + ESP + TRACERS + RADAR + AUTO PICKUP
-- WITH NOTIFICATIONS, SEPARATE TOGGLEABLE CONSOLE WINDOW, HOTKEYS & OVERLAYS
-- ============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats = game:GetService("Stats")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Stealth Containers for UI & Rendering
local TargetParent = (gethui and gethui()) or CoreGui

local SafeContainer = Instance.new("Folder")
SafeContainer.Name = "RenderStorage_" .. HttpService:GenerateGUID(false):sub(1, 8)
SafeContainer.Parent = TargetParent

local IrisGui = Instance.new("ScreenGui")
IrisGui.Name = "UIContainer_" .. HttpService:GenerateGUID(false):sub(1, 8)
IrisGui.ResetOnSpawn = false
IrisGui.DisplayOrder = 100
IrisGui.Parent = TargetParent

-- Game Pants IDs for Team Detection Fallback
local ATTACKER_PANTS_ID = "71322661859196"
local DEFENDER_PANTS_ID = "82267040223924"

-- R6 Bone Connections
local R6_CONNECTIONS = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"}
}

-- Default Colors
local COLOR_VISIBLE        = Color3.fromRGB(0, 255, 100)
local COLOR_HIDDEN         = Color3.fromRGB(255, 50, 50)
local COLOR_DROPPED        = Color3.fromRGB(255, 230, 80)
local COLOR_DRONE          = Color3.fromRGB(255, 170, 0)
local COLOR_TRACER         = Color3.fromRGB(0, 220, 255)
local COLOR_GRENADE_SAFE   = Color3.fromRGB(255, 170, 0)
local COLOR_GRENADE_DANGER = Color3.fromRGB(255, 30, 30)
local COLOR_CORPSE         = Color3.fromRGB(150, 150, 150)

-- Lighting Backup Defaults
local defaultAmbient = Lighting.Ambient
local defaultOutdoorAmbient = Lighting.OutdoorAmbient
local defaultBrightness = Lighting.Brightness
local defaultClockTime = Lighting.ClockTime
local defaultFogEnd = Lighting.FogEnd
local isFullbrightActive = false

-- ============================================================================
-- 1. IRIS UI SETUP & STATES
-- ============================================================================
local Iris = loadstring(game:HttpGet("https://raw.githubusercontent.com/windbreaker7/Oxygen/refs/heads/main/iris_bundle.lua"))()

if type(Iris) == "table" and Iris.Init then
    Iris.Init(IrisGui)
end

-- SafeSliderNum helper
local function SafeSliderNum(label, config)
    return Iris.SliderNum(label, {
        number = config.number,
        min = config.min,
        max = config.max
    })
end

-- Global & Visual States
local S_MasterSwitch   = Iris.State(true)
local S_TeamCheck      = Iris.State(true)
local S_WallCheck      = Iris.State(true)
local S_ShowStats      = Iris.State(true)

local S_ChamsEnabled   = Iris.State(true)
local S_ChamsVisOnly   = Iris.State(true)
local S_Boxes          = Iris.State(true)
local S_Bones          = Iris.State(true)
local S_Names          = Iris.State(true)
local S_Health         = Iris.State(true)
local S_HealthText     = Iris.State(true)
local S_Snaplines      = Iris.State(true)
local S_SnaplineOrigin = Iris.State("Bottom")
local S_Distance       = Iris.State(true)
local S_GunESP         = Iris.State(true)
local S_AmmoESP        = Iris.State(true)
local S_DroneESP       = Iris.State(true)
local S_GrenadeESP     = Iris.State(true)
local S_CorpseESP      = Iris.State(true)
local S_AutoPickup     = Iris.State(true)
local S_PickupRadius   = Iris.State(15)
local S_GrenadeWarnDist= Iris.State(15)
local S_OffscreenESP   = Iris.State(true)
local S_IndicatorSize  = Iris.State(15)
local S_IndicatorRadius= Iris.State(250)

-- Crosshair States
local S_CrosshairEnabled = Iris.State(true)
local S_CrosshairSize    = Iris.State(8)
local S_CrosshairGap     = Iris.State(4)
local S_CrosshairDot     = Iris.State(true)

-- Bullet Tracer States
local S_TracersEnabled = Iris.State(true)
local S_TracerDuration = Iris.State(0.75)

-- Radar States
local S_RadarEnabled   = Iris.State(true)
local S_RadarItems     = Iris.State(true)
local S_RadarFOVCone   = Iris.State(true)
local S_RadarRange     = Iris.State(150)
local S_RadarSize      = Iris.State(140)

-- Misc States
local S_Fullbright           = Iris.State(false)
local S_FullbrightBrightness = Iris.State(2)

-- Background Image Settings
local S_BgEnabled      = Iris.State(true)
local S_BgAssetId      = Iris.State("rbxassetid://1000151035")
local S_BgTransparency = Iris.State(0.35)

-- Overlay & Separate Window Settings
local S_ShowKeybindWin = Iris.State(true)
local S_ShowConsoleWin = Iris.State(false)
local S_ShowActiveOnly = Iris.State(false)
local S_UIMenuToggle   = Iris.State("Insert")

-- Color & Theme States
local S_AttackerCol   = Iris.State(Color3.fromRGB(255, 60, 60))
local S_DefenderCol   = Iris.State(Color3.fromRGB(60, 160, 255))
local S_NeutralCol    = Iris.State(Color3.fromRGB(200, 200, 200))
local S_CurrentTheme  = Iris.State("Default")

-- System State (Notifications & Logger)
local AppState = {
    Notifications = {},
    Logs = {}
}

-- Keybind System Structures
local Keybinds = {
    MasterSwitch   = { Name = "Master Switch",     State = S_MasterSwitch,   Key = "F1", Mode = Iris.State("Toggle") },
    Chams          = { Name = "Chams",             State = S_ChamsEnabled,   Key = "F2", Mode = Iris.State("Toggle") },
    Boxes          = { Name = "Box ESP",           State = S_Boxes,          Key = "F3", Mode = Iris.State("Toggle") },
    Offscreen      = { Name = "Offscreen ESP",     State = S_OffscreenESP,   Key = "F4", Mode = Iris.State("Hold") },
    Tracers        = { Name = "Bullet Tracers",    State = S_TracersEnabled, Key = "F5", Mode = Iris.State("Toggle") },
    Radar          = { Name = "Radar Minimap",     State = S_RadarEnabled,   Key = "F6", Mode = Iris.State("Toggle") },
    ConsoleWindow  = { Name = "Console Window",    State = S_ShowConsoleWin, Key = "F9", Mode = Iris.State("Toggle") },
}

local KeybindStateBuffers = {}
for id, data in pairs(Keybinds) do
    KeybindStateBuffers[id] = Iris.State(data.Key)
end

-- ============================================================================
-- 2. LOGGER & NOTIFICATION SYSTEM
-- ============================================================================

local function AddLog(msg, level)
    level = level or "INFO"
    local timeStr = os.date("%H:%M:%S")
    table.insert(AppState.Logs, 1, {
        time = timeStr,
        text = msg,
        level = level
    })
    
    if #AppState.Logs > 100 then
        table.remove(AppState.Logs)
    end
end

local function Notify(msg, level, duration)
    level = level or "INFO"
    duration = duration or 3
    
    table.insert(AppState.Notifications, {
        id = tick() .. math.random(100, 999),
        text = msg,
        level = level,
        expireAt = tick() + duration
    })
    
    AddLog("[NOTIFY] " .. msg, level)
end

-- ============================================================================
-- 3. DYNAMIC BACKGROUND IMAGE INJECTION
-- ============================================================================
local BackgroundImageObj = nil

local function ApplyMenuBackground(windowFrame)
    if not windowFrame then return end

    if not BackgroundImageObj or BackgroundImageObj.Parent ~= windowFrame then
        if BackgroundImageObj then BackgroundImageObj:Destroy() end
        
        BackgroundImageObj = Instance.new("ImageLabel")
        BackgroundImageObj.Name = "ImGui_CustomBackground"
        BackgroundImageObj.Size = UDim2.new(1, 0, 1, 0)
        BackgroundImageObj.Position = UDim2.new(0, 0, 0, 0)
        BackgroundImageObj.BackgroundTransparency = 1
        BackgroundImageObj.ScaleType = Enum.ScaleType.Crop
        BackgroundImageObj.ZIndex = 0
        BackgroundImageObj.Parent = windowFrame
    end

    BackgroundImageObj.Image = S_BgAssetId.value
    BackgroundImageObj.ImageTransparency = S_BgTransparency.value
    BackgroundImageObj.Visible = S_BgEnabled.value
end

-- ============================================================================
-- 4. CONFIG SYSTEM
-- ============================================================================
local CONFIG_FILE = "TheLostFront_Config.json"

local function SaveConfig()
    if not writefile then 
        Notify("Config Save Failed: Unsupported Environment", "WARN", 3)
        return 
    end

    local data = {
        MasterSwitch   = S_MasterSwitch.value,
        TeamCheck      = S_TeamCheck.value,
        WallCheck      = S_WallCheck.value,
        ShowStats      = S_ShowStats.value,
        ChamsEnabled   = S_ChamsEnabled.value,
        ChamsVisOnly   = S_ChamsVisOnly.value,
        Boxes          = S_Boxes.value,
        Bones          = S_Bones.value,
        Names          = S_Names.value,
        Health         = S_Health.value,
        HealthText     = S_HealthText.value,
        Snaplines      = S_Snaplines.value,
        SnaplineOrigin = S_SnaplineOrigin.value,
        Distance       = S_Distance.value,
        GunESP         = S_GunESP.value,
        AmmoESP        = S_AmmoESP.value,
        DroneESP       = S_DroneESP.value,
        GrenadeESP     = S_GrenadeESP.value,
        CorpseESP      = S_CorpseESP.value,
        AutoPickup     = S_AutoPickup.value,
        PickupRadius   = S_PickupRadius.value,
        GrenadeWarnDist= S_GrenadeWarnDist.value,
        OffscreenESP   = S_OffscreenESP.value,
        CrosshairEnabled = S_CrosshairEnabled.value,
        CrosshairSize  = S_CrosshairSize.value,
        CrosshairGap   = S_CrosshairGap.value,
        CrosshairDot   = S_CrosshairDot.value,
        TracersEnabled = S_TracersEnabled.value,
        RadarEnabled   = S_RadarEnabled.value,
        RadarItems     = S_RadarItems.value,
        RadarFOVCone   = S_RadarFOVCone.value,
        RadarRange     = S_RadarRange.value,
        IndicatorRadius= S_IndicatorRadius.value,
        IndicatorSize  = S_IndicatorSize.value,
        Fullbright     = S_Fullbright.value,
        FullbrightBrightness = S_FullbrightBrightness.value,
        ShowKeybindWin = S_ShowKeybindWin.value,
        ShowConsoleWin = S_ShowConsoleWin.value,
        ShowActiveOnly = S_ShowActiveOnly.value,
        UIMenuToggle   = S_UIMenuToggle.value,
        BgEnabled      = S_BgEnabled.value,
        BgAssetId      = S_BgAssetId.value,
        BgTransparency = S_BgTransparency.value,
        CurrentTheme   = S_CurrentTheme.value,
        Keybinds       = {}
    }

    for id, bind in pairs(Keybinds) do
        data.Keybinds[id] = {
            Key = KeybindStateBuffers[id].value,
            Mode = bind.Mode.value
        }
    end

    writefile(CONFIG_FILE, HttpService:JSONEncode(data))
    Notify("Configuration Saved Successfully", "SUCCESS", 2.5)
end

local function LoadConfig()
    if not (readfile and isfile and isfile(CONFIG_FILE)) then 
        Notify("Config Load Failed: File Not Found", "WARN", 3)
        return 
    end

    local success, decoded = pcall(function()
        return HttpService:JSONDecode(readfile(CONFIG_FILE))
    end)

    if not success or not decoded then 
        Notify("Config Load Failed: JSON Error", "WARN", 3)
        return 
    end

    if decoded.MasterSwitch ~= nil then S_MasterSwitch:set(decoded.MasterSwitch) end
    if decoded.TeamCheck ~= nil then S_TeamCheck:set(decoded.TeamCheck) end
    if decoded.WallCheck ~= nil then S_WallCheck:set(decoded.WallCheck) end
    if decoded.ShowStats ~= nil then S_ShowStats:set(decoded.ShowStats) end
    if decoded.ChamsEnabled ~= nil then S_ChamsEnabled:set(decoded.ChamsEnabled) end
    if decoded.ChamsVisOnly ~= nil then S_ChamsVisOnly:set(decoded.ChamsVisOnly) end
    if decoded.Boxes ~= nil then S_Boxes:set(decoded.Boxes) end
    if decoded.Bones ~= nil then S_Bones:set(decoded.Bones) end
    if decoded.Names ~= nil then S_Names:set(decoded.Names) end
    if decoded.Health ~= nil then S_Health:set(decoded.Health) end
    if decoded.HealthText ~= nil then S_HealthText:set(decoded.HealthText) end
    if decoded.Snaplines ~= nil then S_Snaplines:set(decoded.Snaplines) end
    if decoded.SnaplineOrigin ~= nil then S_SnaplineOrigin:set(decoded.SnaplineOrigin) end
    if decoded.Distance ~= nil then S_Distance:set(decoded.Distance) end
    if decoded.GunESP ~= nil then S_GunESP:set(decoded.GunESP) end
    if decoded.AmmoESP ~= nil then S_AmmoESP:set(decoded.AmmoESP) end
    if decoded.DroneESP ~= nil then S_DroneESP:set(decoded.DroneESP) end
    if decoded.GrenadeESP ~= nil then S_GrenadeESP:set(decoded.GrenadeESP) end
    if decoded.CorpseESP ~= nil then S_CorpseESP:set(decoded.CorpseESP) end
    if decoded.AutoPickup ~= nil then S_AutoPickup:set(decoded.AutoPickup) end
    if decoded.PickupRadius ~= nil then S_PickupRadius:set(decoded.PickupRadius) end
    if decoded.GrenadeWarnDist ~= nil then S_GrenadeWarnDist:set(decoded.GrenadeWarnDist) end
    if decoded.OffscreenESP ~= nil then S_OffscreenESP:set(decoded.OffscreenESP) end
    if decoded.CrosshairEnabled ~= nil then S_CrosshairEnabled:set(decoded.CrosshairEnabled) end
    if decoded.CrosshairSize ~= nil then S_CrosshairSize:set(decoded.CrosshairSize) end
    if decoded.CrosshairGap ~= nil then S_CrosshairGap:set(decoded.CrosshairGap) end
    if decoded.CrosshairDot ~= nil then S_CrosshairDot:set(decoded.CrosshairDot) end
    if decoded.TracersEnabled ~= nil then S_TracersEnabled:set(decoded.TracersEnabled) end
    if decoded.RadarEnabled ~= nil then S_RadarEnabled:set(decoded.RadarEnabled) end
    if decoded.RadarItems ~= nil then S_RadarItems:set(decoded.RadarItems) end
    if decoded.RadarFOVCone ~= nil then S_RadarFOVCone:set(decoded.RadarFOVCone) end
    if decoded.RadarRange ~= nil then S_RadarRange:set(decoded.RadarRange) end
    if decoded.IndicatorRadius ~= nil then S_IndicatorRadius:set(decoded.IndicatorRadius) end
    if decoded.IndicatorSize ~= nil then S_IndicatorSize:set(decoded.IndicatorSize) end
    if decoded.Fullbright ~= nil then S_Fullbright:set(decoded.Fullbright) end
    if decoded.FullbrightBrightness ~= nil then S_FullbrightBrightness:set(decoded.FullbrightBrightness) end
    if decoded.ShowKeybindWin ~= nil then S_ShowKeybindWin:set(decoded.ShowKeybindWin) end
    if decoded.ShowConsoleWin ~= nil then S_ShowConsoleWin:set(decoded.ShowConsoleWin) end
    if decoded.ShowActiveOnly ~= nil then S_ShowActiveOnly:set(decoded.ShowActiveOnly) end
    if decoded.UIMenuToggle ~= nil then S_UIMenuToggle:set(decoded.UIMenuToggle) end
    if decoded.BgEnabled ~= nil then S_BgEnabled:set(decoded.BgEnabled) end
    if decoded.BgAssetId ~= nil then S_BgAssetId:set(decoded.BgAssetId) end
    if decoded.BgTransparency ~= nil then S_BgTransparency:set(decoded.BgTransparency) end

    if decoded.Keybinds then
        for id, bindData in pairs(decoded.Keybinds) do
            if Keybinds[id] then
                if type(bindData) == "table" then
                    KeybindStateBuffers[id]:set(bindData.Key or Keybinds[id].Key)
                    Keybinds[id].Mode:set(bindData.Mode or "Toggle")
                else
                    KeybindStateBuffers[id]:set(bindData)
                end
            end
        end
    end

    Notify("Configuration Loaded", "SUCCESS", 2.5)
end

-- ============================================================================
-- 5. KEYBIND & INPUT HANDLER
-- ============================================================================
local function HandleInputState(input, isBegan)
    local inputName = (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode and input.KeyCode.Name) 
                   or (input.UserInputType == Enum.UserInputType.MouseButton1 and "MouseButton1")
                   or (input.UserInputType == Enum.UserInputType.MouseButton2 and "MouseButton2")
                   or (input.UserInputType == Enum.UserInputType.MouseButton3 and "MouseButton3")
    
    if not inputName then return end

    if isBegan and inputName == S_UIMenuToggle.value then
        IrisGui.Enabled = not IrisGui.Enabled
        Notify("Menu " .. (IrisGui.Enabled and "Opened" or "Hidden"), "INFO", 1.5)
        return
    end

    if isBegan and inputName == "Insert" then
        S_ShowKeybindWin:set(not S_ShowKeybindWin.value)
        Notify("Keybind Overlay " .. (S_ShowKeybindWin.value and "Shown" or "Hidden"), "INFO", 1.5)
        return
    end

    for id, bindData in pairs(Keybinds) do
        local boundKey = KeybindStateBuffers[id].value
        local mode = bindData.Mode.value

        if isBegan then
            if mode == "Always" then
                bindData.State:set(true)
            elseif inputName == boundKey then
                if mode == "Toggle" then
                    local nextVal = not bindData.State.value
                    bindData.State:set(nextVal)
                    Notify(bindData.Name .. " " .. (nextVal and "ENABLED" or "DISABLED"), nextVal and "SUCCESS" or "WARN", 2)
                elseif mode == "Hold" then
                    bindData.State:set(true)
                end
            end
        else
            if mode == "Hold" and inputName == boundKey then
                bindData.State:set(false)
            elseif mode == "Always" then
                bindData.State:set(true)
            end
        end
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    HandleInputState(input, true)
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    HandleInputState(input, false)
end)

-- ============================================================================
-- 6. STATS TRACKER (FPS / PING) & FULLBRIGHT MODULE
-- ============================================================================
local frameCounter = 0
local lastFpsUpdate = os.clock()
local currentFps = 60
local currentPing = 0

local function GetStatsText()
    frameCounter = frameCounter + 1
    local now = os.clock()
    if now - lastFpsUpdate >= 0.5 then
        currentFps = math.floor(frameCounter / (now - lastFpsUpdate))
        frameCounter = 0
        lastFpsUpdate = now
    end

    local pingVal = Stats.Network.ServerStatsItem["Data Ping"]
    currentPing = pingVal and math.floor(pingVal:GetValue()) or 0
    return string.format("FPS: %d  |  Ping: %d ms", currentFps, currentPing)
end

local function UpdateFullbright()
    if S_MasterSwitch.value and S_Fullbright.value then
        isFullbrightActive = true
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = S_FullbrightBrightness.value
        Lighting.ClockTime = 12
        Lighting.FogEnd = 1000000
    elseif isFullbrightActive then
        isFullbrightActive = false
        Lighting.Ambient = defaultAmbient
        Lighting.OutdoorAmbient = defaultOutdoorAmbient
        Lighting.Brightness = defaultBrightness
        Lighting.ClockTime = defaultClockTime
        Lighting.FogEnd = defaultFogEnd
    end
end

-- ============================================================================
-- 7. RADAR & FOV CONE MODULE
-- ============================================================================
local RadarElements = {
    Background   = Drawing.new("Circle"),
    Outline      = Drawing.new("Circle"),
    CenterCross1 = Drawing.new("Line"),
    CenterCross2 = Drawing.new("Line"),
    FovLeftLine  = Drawing.new("Line"),
    FovRightLine = Drawing.new("Line"),
    CounterText  = Drawing.new("Text"),
    Dots         = {}
}

RadarElements.Background.Filled = true
RadarElements.Background.Color = Color3.fromRGB(15, 15, 20)
RadarElements.Background.Transparency = 0.65

RadarElements.Outline.Filled = false
RadarElements.Outline.Thickness = 1.5
RadarElements.Outline.Color = Color3.fromRGB(0, 220, 255)

RadarElements.CenterCross1.Color = Color3.fromRGB(255, 255, 255)
RadarElements.CenterCross1.Thickness = 1
RadarElements.CenterCross2.Color = Color3.fromRGB(255, 255, 255)
RadarElements.CenterCross2.Thickness = 1

RadarElements.FovLeftLine.Color = Color3.fromRGB(0, 220, 255)
RadarElements.FovLeftLine.Thickness = 1
RadarElements.FovLeftLine.Transparency = 0.4

RadarElements.FovRightLine.Color = Color3.fromRGB(0, 220, 255)
RadarElements.FovRightLine.Thickness = 1
RadarElements.FovRightLine.Transparency = 0.4

RadarElements.CounterText.Size = 14
RadarElements.CounterText.Center = true
RadarElements.CounterText.Outline = true
RadarElements.CounterText.Font = 2
RadarElements.CounterText.Color = Color3.fromRGB(255, 220, 50)

local function UpdateRadar(activeTargetPositions)
    if not (S_MasterSwitch.value and S_RadarEnabled.value) then
        RadarElements.Background.Visible = false
        RadarElements.Outline.Visible = false
        RadarElements.CenterCross1.Visible = false
        RadarElements.CenterCross2.Visible = false
        RadarElements.FovLeftLine.Visible = false
        RadarElements.FovRightLine.Visible = false
        RadarElements.CounterText.Visible = false
        for _, obj in ipairs(RadarElements.Dots) do
            if obj.Dot then obj.Dot.Visible = false end
            if obj.DirLine then obj.DirLine.Visible = false end
        end
        return
    end

    local radarCenter = Vector2.new(170, 170)
    local radius = S_RadarSize.value
    local maxRange = math.max(S_RadarRange.value, 1)

    RadarElements.Background.Position = radarCenter
    RadarElements.Background.Radius = radius
    RadarElements.Background.Visible = true

    RadarElements.Outline.Position = radarCenter
    RadarElements.Outline.Radius = radius
    RadarElements.Outline.Visible = true

    RadarElements.CenterCross1.From = radarCenter - Vector2.new(6, 0)
    RadarElements.CenterCross1.To = radarCenter + Vector2.new(6, 0)
    RadarElements.CenterCross1.Visible = true

    RadarElements.CenterCross2.From = radarCenter - Vector2.new(0, 6)
    RadarElements.CenterCross2.To = radarCenter + Vector2.new(0, 6)
    RadarElements.CenterCross2.Visible = true

    RadarElements.CounterText.Text = "TARGETS: " .. #activeTargetPositions
    RadarElements.CounterText.Position = radarCenter - Vector2.new(0, radius + 18)
    RadarElements.CounterText.Visible = true

    if S_RadarFOVCone.value then
        local halfFovRad = math.rad(Camera.FieldOfView / 2)
        local leftVector = Vector2.new(-math.sin(halfFovRad), -math.cos(halfFovRad)) * radius
        local rightVector = Vector2.new(math.sin(halfFovRad), -math.cos(halfFovRad)) * radius

        RadarElements.FovLeftLine.From = radarCenter
        RadarElements.FovLeftLine.To = radarCenter + leftVector
        RadarElements.FovLeftLine.Visible = true

        RadarElements.FovRightLine.From = radarCenter
        RadarElements.FovRightLine.To = radarCenter + rightVector
        RadarElements.FovRightLine.Visible = true
    else
        RadarElements.FovLeftLine.Visible = false
        RadarElements.FovRightLine.Visible = false
    end

    local localChar = LocalPlayer.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")

    if not localRoot then
        for _, obj in ipairs(RadarElements.Dots) do
            if obj.Dot then obj.Dot.Visible = false end
            if obj.DirLine then obj.DirLine.Visible = false end
        end
        return
    end

    local camCFrame = Camera.CFrame

    for index, targetData in ipairs(activeTargetPositions) do
        local elem = RadarElements.Dots[index]
        if not elem then
            elem = {
                Dot = Drawing.new("Circle"),
                DirLine = Drawing.new("Line")
            }
            elem.Dot.Radius = 3.5
            elem.Dot.Filled = true
            elem.DirLine.Thickness = 1.5
            RadarElements.Dots[index] = elem
        end

        local relPos = targetData.Position - localRoot.Position
        local lookVec = camCFrame.LookVector
        local rightVec = camCFrame.RightVector

        local forwardDist = Vector3.new(relPos.X, 0, relPos.Z):Dot(Vector3.new(lookVec.X, 0, lookVec.Z).Unit)
        local sideDist = Vector3.new(relPos.X, 0, relPos.Z):Dot(Vector3.new(rightVec.X, 0, rightVec.Z).Unit)

        local mapX = (sideDist / maxRange) * radius
        local mapY = -((forwardDist / maxRange) * radius)

        local distFromCenter = math.sqrt(mapX^2 + mapY^2)
        if distFromCenter > radius then
            mapX = (mapX / distFromCenter) * radius
            mapY = (mapY / distFromCenter) * radius
        end

        local dotPos = radarCenter + Vector2.new(mapX, mapY)
        elem.Dot.Position = dotPos
        elem.Dot.Color = targetData.Color
        elem.Dot.Visible = true

        if targetData.LookVector then
            local tLook = targetData.LookVector
            local fwd = Vector3.new(tLook.X, 0, tLook.Z).Unit:Dot(Vector3.new(lookVec.X, 0, lookVec.Z).Unit)
            local sde = Vector3.new(tLook.X, 0, tLook.Z).Unit:Dot(Vector3.new(rightVec.X, 0, rightVec.Z).Unit)

            local lineDir = Vector2.new(sde, -fwd).Unit * 10
            elem.DirLine.From = dotPos
            elem.DirLine.To = dotPos + lineDir
            elem.DirLine.Color = targetData.Color
            elem.DirLine.Visible = true
        else
            elem.DirLine.Visible = false
        end
    end

    for i = #activeTargetPositions + 1, #RadarElements.Dots do
        RadarElements.Dots[i].Dot.Visible = false
        RadarElements.Dots[i].DirLine.Visible = false
    end
end

-- ============================================================================
-- 8. TRACERS & WEAPON ESP LOGIC
-- ============================================================================
local ActiveTracers = {}

local function AddBulletTracer(fromPos, toPos)
    if not (S_MasterSwitch.value and S_TracersEnabled.value) then return end

    local tracerLine = Drawing.new("Line")
    tracerLine.Thickness = 1.5
    tracerLine.Color = COLOR_TRACER
    tracerLine.Transparency = 1

    table.insert(ActiveTracers, {
        Line = tracerLine,
        From = fromPos,
        To = toPos,
        Created = os.clock(),
        Duration = S_TracerDuration.value
    })
end

local function FireTracerFromCamera()
    local localChar = LocalPlayer.Character
    local head = localChar and localChar:FindFirstChild("Head")
    if not head then return end

    local ray = Camera:ViewportPointToRay(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {localChar, Camera}

    local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
    local targetPos = result and result.Position or (ray.Origin + ray.Direction * 300)

    AddBulletTracer(head.Position, targetPos)
end

task.spawn(function()
    local hooked = false
    local networkFolder = ReplicatedStorage:FindFirstChild("network")
    if networkFolder then
        local mobileBind = networkFolder:FindFirstChild("mobileBind")
        if mobileBind and (mobileBind:IsA("BindableEvent") or mobileBind:IsA("RemoteEvent")) then
            mobileBind.Event:Connect(function(...)
                FireTracerFromCamera()
            end)
            hooked = true
        end
    end

    if not hooked then
        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if not (S_MasterSwitch.value and S_TracersEnabled.value) then return end

            local isPCShot = (input.UserInputType == Enum.UserInputType.MouseButton1)
            local isMobileTouch = (input.UserInputType == Enum.UserInputType.Touch)

            if isPCShot or isMobileTouch then
                local localChar = LocalPlayer.Character
                local tool = localChar and localChar:FindFirstChildOfClass("Tool")
                if tool then
                    FireTracerFromCamera()
                end
            end
        end)
    end
end)

local function UpdateBulletTracers()
    local now = os.clock()
    for i = #ActiveTracers, 1, -1 do
        local tracer = ActiveTracers[i]
        local elapsed = now - tracer.Created

        if elapsed >= tracer.Duration then
            tracer.Line:Remove()
            table.remove(ActiveTracers, i)
        else
            local screenFrom, visFrom = Camera:WorldToViewportPoint(tracer.From)
            local screenTo, visTo = Camera:WorldToViewportPoint(tracer.To)

            if visFrom or visTo then
                tracer.Line.From = Vector2.new(screenFrom.X, screenFrom.Y)
                tracer.Line.To = Vector2.new(screenTo.X, screenTo.Y)
                tracer.Line.Transparency = 1 - (elapsed / tracer.Duration)
                tracer.Line.Visible = true
            else
                tracer.Line.Visible = false
            end
        end
    end
end

local function GetHeldWeaponName(character)
    if not character then return "None" end

    local itemFolder = character:FindFirstChild("ItemFolder")
    if itemFolder then
        local itemModel = itemFolder:FindFirstChildOfClass("Model")
        if itemModel then return itemModel.Name end
    end

    local tool = character:FindFirstChildOfClass("Tool")
    if tool then return tool.Name end

    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Model") and (child.Name:lower():find("gun") or child.Name:lower():find("weapon") or child:FindFirstChild("Handle")) then
            return child.Name
        end
    end

    return "None"
end

-- ============================================================================
-- 9. VISIBILITY CHECK MODULE
-- ============================================================================
local function IsVisible(character)
    if not character then return false end
    local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    if not head then return false end

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {Camera, SafeContainer, LocalPlayer.Character, character}

    local result = workspace:Raycast(Camera.CFrame.Position, head.Position - Camera.CFrame.Position, raycastParams)
    return result == nil
end

-- ============================================================================
-- 10. AUTO PICKUP MODULE
-- ============================================================================
local AutoPickupTarget = nil

task.spawn(function()
    local weaponHL = ReplicatedStorage:FindFirstChild("WeaponHighlight")
    if weaponHL then
        weaponHL:GetPropertyChangedSignal("Adornee"):Connect(function()
            AutoPickupTarget = weaponHL.Adornee
        end)
    end
end)

task.spawn(function()
    while true do
        task.wait(0.2)
        if S_MasterSwitch.value and S_AutoPickup.value then
            local localChar = LocalPlayer.Character
            local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")

            if localRoot then
                local pickupRemote = ReplicatedStorage:FindFirstChild("network") and ReplicatedStorage.network:FindFirstChild("pickup") and ReplicatedStorage.network.pickup:FindFirstChild("collect")

                if pickupRemote then
                    if AutoPickupTarget and AutoPickupTarget.Parent then
                        local pos = AutoPickupTarget:IsA("BasePart") and AutoPickupTarget.Position or AutoPickupTarget:GetPivot().Position
                        if (localRoot.Position - pos).Magnitude <= S_PickupRadius.value then
                            pickupRemote:FireServer(AutoPickupTarget)
                            Notify("Auto Picked Up: " .. AutoPickupTarget.Name, "INFO", 1.5)
                        end
                    end

                    local debrisFolder = workspace:FindFirstChild("Debris") or workspace:FindFirstChild("debris")
                    local droppedFolder = debrisFolder and (debrisFolder:FindFirstChild("Dropped") or debrisFolder:FindFirstChild("dropped")) or workspace:FindFirstChild("Dropped") or workspace:FindFirstChild("Items") or workspace
                    
                    if droppedFolder then
                        for _, item in ipairs(droppedFolder:GetChildren()) do
                            if item:IsA("Tool") or item:IsA("BasePart") or item:IsA("Model") then
                                local pos = item:IsA("BasePart") and item.Position or item:GetPivot().Position
                                if (localRoot.Position - pos).Magnitude <= S_PickupRadius.value then
                                    pickupRemote:FireServer(item)
                                    Notify("Auto Picked Up: " .. item.Name, "INFO", 1.5)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ============================================================================
-- 11. CUSTOM CROSSHAIR MODULE
-- ============================================================================
local CrosshairLines = {
    Top    = Drawing.new("Line"),
    Bottom = Drawing.new("Line"),
    Left   = Drawing.new("Line"),
    Right  = Drawing.new("Line"),
    Dot    = Drawing.new("Circle")
}

for name, line in pairs(CrosshairLines) do
    if name ~= "Dot" then
        line.Thickness = 1.5
        line.Transparency = 1
    end
end
CrosshairLines.Dot.Radius = 1.5
CrosshairLines.Dot.Filled = true

local function UpdateCrosshair()
    if not (S_MasterSwitch.value and S_CrosshairEnabled.value) then
        for _, element in pairs(CrosshairLines) do element.Visible = false end
        return
    end

    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local gap = S_CrosshairGap.value
    local size = S_CrosshairSize.value
    local col = COLOR_VISIBLE

    CrosshairLines.Top.From = center - Vector2.new(0, gap)
    CrosshairLines.Top.To   = center - Vector2.new(0, gap + size)
    CrosshairLines.Top.Color = col
    CrosshairLines.Top.Visible = true

    CrosshairLines.Bottom.From = center + Vector2.new(0, gap)
    CrosshairLines.Bottom.To   = center + Vector2.new(0, gap + size)
    CrosshairLines.Bottom.Color = col
    CrosshairLines.Bottom.Visible = true

    CrosshairLines.Left.From = center - Vector2.new(gap, 0)
    CrosshairLines.Left.To   = center - Vector2.new(gap + size, 0)
    CrosshairLines.Left.Color = col
    CrosshairLines.Left.Visible = true

    CrosshairLines.Right.From = center + Vector2.new(gap, 0)
    CrosshairLines.Right.To   = center + Vector2.new(gap + size, 0)
    CrosshairLines.Right.Color = col
    CrosshairLines.Right.Visible = true

    CrosshairLines.Dot.Position = center
    CrosshairLines.Dot.Color = col
    CrosshairLines.Dot.Visible = S_CrosshairDot.value
end

-- ============================================================================
-- 12. IRIS UI LAYOUT & RENDER PIPELINE
-- ============================================================================
Iris:Connect(function()
    
    -- TOAST NOTIFICATION OVERLAY
    local currentTime = tick()
    local yOffset = 20
    
    for i = #AppState.Notifications, 1, -1 do
        local toast = AppState.Notifications[i]
        
        if currentTime > toast.expireAt then
            table.remove(AppState.Notifications, i)
        else
            Iris.SetNextWindowPos(Vector2.new(20, yOffset))
            Iris.SetNextWindowSize(Vector2.new(280, 0))
            
            Iris.Window({"Toast_" .. toast.id, false, false, false, false, true}, {
                isOpened = true
            })
                local color = toast.level == "WARN" and Color3.fromRGB(255, 170, 0) 
                           or toast.level == "SUCCESS" and Color3.fromRGB(85, 255, 127)
                           or Color3.fromRGB(85, 170, 255)
                
                Iris.Text({string.format("[%s] %s", toast.level, toast.text), color})
            Iris.End()
            
            yOffset = yOffset + 45
        end
    end

    -- MAIN SCRIPT MENU
    if IrisGui.Enabled then
        Iris.PushConfig({
            WindowBgTransparency = S_BgEnabled.value and 0.45 or 0.0,
            WindowBg = Color3.fromRGB(15, 15, 15)
        })

        local mainWindow = Iris.Window({"The lost front | Israel approved🇮🇱✡️"}, {NoClose = true})
            if mainWindow and mainWindow.Instance then
                ApplyMenuBackground(mainWindow.Instance)
            end

            -- Direct FPS/Ping Display inside Iris UI
            if S_ShowStats.value then
                Iris.Text({GetStatsText(), Color3.fromRGB(0, 255, 150)})
                Iris.Separator()
            end

            Iris.TabBar()

                -- VISUALS TAB
                Iris.Tab({"Visuals"})
                    Iris.Text({"-- Global Settings --"})
                    Iris.Checkbox({"Master Switch"}, {isChecked = S_MasterSwitch})
                    Iris.Checkbox({"Show Stats Banner in Menu"}, {isChecked = S_ShowStats})
                    Iris.Checkbox({"Show Console / Logs Window"}, {isChecked = S_ShowConsoleWin})
                    Iris.Checkbox({"Team Check Filter"}, {isChecked = S_TeamCheck})
                    Iris.Checkbox({"ESP Wall Check (Green/Red)"}, {isChecked = S_WallCheck})
                    
                    Iris.Text({"-- Player ESP & Chams --"})
                    Iris.Checkbox({"Enable Chams"}, {isChecked = S_ChamsEnabled})
                    Iris.Checkbox({"Chams Behind Wall (Visible Only Check)"}, {isChecked = S_ChamsVisOnly})
                    Iris.Checkbox({"Show Box"}, {isChecked = S_Boxes})
                    Iris.Checkbox({"Show R6 Bones"}, {isChecked = S_Bones})
                    Iris.Checkbox({"Show Name"}, {isChecked = S_Names})
                    Iris.Checkbox({"Show Health Bar"}, {isChecked = S_Health})
                    Iris.Checkbox({"Show Numerical Health Text"}, {isChecked = S_HealthText})
                    Iris.Checkbox({"Show Target Snaplines"}, {isChecked = S_Snaplines})
                    Iris.Checkbox({"Show Distance"}, {isChecked = S_Distance})
                    Iris.Checkbox({"Show Held Weapon"}, {isChecked = S_GunESP})

                    Iris.Text({"-- Crosshair Overlay --"})
                    Iris.Checkbox({"Enable Custom Crosshair"}, {isChecked = S_CrosshairEnabled})
                    Iris.Checkbox({"Show Center Dot"}, {isChecked = S_CrosshairDot})
                    SafeSliderNum({"Crosshair Size"}, {number = S_CrosshairSize, min = 2, max = 25})
                    SafeSliderNum({"Crosshair Gap"}, {number = S_CrosshairGap, min = 0, max = 20})

                    Iris.Text({"-- Bullet Tracers & Tactical Radar --"})
                    Iris.Checkbox({"Show Bullet Tracers"}, {isChecked = S_TracersEnabled})
                    Iris.Checkbox({"Show 2D Radar Minimap"}, {isChecked = S_RadarEnabled})
                    Iris.Checkbox({"Show Radar FOV Cone"}, {isChecked = S_RadarFOVCone})
                    Iris.Checkbox({"Show Dropped Items on Radar"}, {isChecked = S_RadarItems})
                    
                    SafeSliderNum({"Radar Range"}, {number = S_RadarRange, min = 50, max = 300})

                    Iris.Text({"-- Offscreen ESP Settings --"})
                    Iris.Checkbox({"Show Offscreen Indicators"}, {isChecked = S_OffscreenESP})
                    SafeSliderNum({"Radius"}, {number = S_IndicatorRadius, min = 100, max = 500})
                    SafeSliderNum({"Indicator Size"}, {number = S_IndicatorSize, min = 8, max = 30})

                    Iris.Text({"-- World & Projectile ESP --"})
                    Iris.Checkbox({"Show Ammo/Dropped Items"}, {isChecked = S_AmmoESP})
                    Iris.Checkbox({"Show Drone ESP"}, {isChecked = S_DroneESP})
                    Iris.Checkbox({"Show Grenade ESP (Debris)"}, {isChecked = S_GrenadeESP})
                    Iris.Checkbox({"Show Corpse ESP (workspace.bodies)"}, {isChecked = S_CorpseESP})
                    SafeSliderNum({"Grenade Danger Radius (m)"}, {number = S_GrenadeWarnDist, min = 5, max = 30})

                    Iris.Text({"-- Auto Looting --"})
                    Iris.Checkbox({"Enable Auto Pickup"}, {isChecked = S_AutoPickup})
                    SafeSliderNum({"Pickup Radius (m)"}, {number = S_PickupRadius, min = 5, max = 50})
                Iris.End()

                -- KEYBINDS TAB
                Iris.Tab({"Keybinds"})
                    Iris.Text({"-- Overlay Settings --"})
                    Iris.Checkbox({"Show Keybinds Overlay Window"}, {isChecked = S_ShowKeybindWin})
                    Iris.Checkbox({"Show Active Binds Only"}, {isChecked = S_ShowActiveOnly})
                    Iris.InputText({"Main UI Key"}, {text = S_UIMenuToggle})
                    
                    for id, data in pairs(Keybinds) do
                        Iris.Text({data.Name .. " Key & Mode:"})
                        Iris.InputText({data.Name .. " Key"}, {text = KeybindStateBuffers[id]})
                    end
                Iris.End()

                -- MISC TAB
                Iris.Tab({"Misc"})
                    Iris.Text({"-- Lighting & Map --"})
                    Iris.Checkbox({"Fullbright"}, {isChecked = S_Fullbright})
                    SafeSliderNum({"Fullbright Brightness"}, {number = S_FullbrightBrightness, min = 1, max = 10})
                Iris.End()

                -- SETTINGS TAB
                Iris.Tab({"Settings"})
                    Iris.Text({"-- Config Management --"})
                    if Iris.Button({"Save Config"}).clicked() then SaveConfig() end
                    if Iris.Button({"Load Config"}).clicked() then LoadConfig() end
                Iris.End()

            Iris.End()
        Iris.End()

        -- SEPARATE CONSOLE / LOGS WINDOW
        if S_MasterSwitch.value and S_ShowConsoleWin.value then
            Iris.Window({"Console / Logs"}, {NoClose = false})
                if Iris.Button({"Clear Logs"}).clicked() then
                    AppState.Logs = {}
                    Notify("Logs Cleared", "INFO", 1.5)
                end
                
                Iris.Separator()
                
                Iris.ScrollBox({Vector2.new(320, 200)})
                    for _, log in ipairs(AppState.Logs) do
                        local logColor = log.level == "WARN" and Color3.fromRGB(255, 170, 0)
                                      or log.level == "SUCCESS" and Color3.fromRGB(85, 255, 127)
                                      or Color3.fromRGB(200, 200, 200)
                        
                        Iris.Text({string.format("[%s] [%s] %s", log.time, log.level, log.text), logColor})
                    end
                Iris.End()
            Iris.End()
        end

        -- KEYBIND OVERLAY WINDOW
        if S_MasterSwitch.value and S_ShowKeybindWin.value then
            Iris.Window({"Active Keybinds"}, {NoClose = true})
                for id, bind in pairs(Keybinds) do
                    local isEnabled = bind.State.value
                    if isEnabled then
                        Iris.Text({bind.Name .. " : [ENABLED]"})
                    elseif not S_ShowActiveOnly.value then
                        Iris.Text({bind.Name .. " : [DISABLED]"})
                    end
                end
            Iris.End()
        end

        Iris.PopConfig()
    end
end)

-- ============================================================================
-- 13. TEAM & VISIBILITY LOGIC
-- ============================================================================
local function GetPlayerTeamIdentifier(player)
    if not player then return "None" end
    
    if player.Team ~= nil then
        return tostring(player.Team.Name)
    end

    local character = player.Character
    if character then
        local pants = character:FindFirstChildWhichIsA("Pants")
        if pants and pants.PantsTemplate then
            local template = tostring(pants.PantsTemplate)
            if string.find(template, ATTACKER_PANTS_ID) then return "Attackers"
            elseif string.find(template, DEFENDER_PANTS_ID) then return "Defenders" end
        end
    end

    return "Neutral"
end

local function IsTeammate(player)
    if player == LocalPlayer then return true end
    local myTeam = GetPlayerTeamIdentifier(LocalPlayer)
    local targetTeam = GetPlayerTeamIdentifier(player)

    if myTeam == "Neutral" or myTeam == "None" then return false end
    return (myTeam == targetTeam)
end

local function GetPlayerTeam(player)
    local teamId = GetPlayerTeamIdentifier(player)
    if teamId == "Attackers" then return S_AttackerCol.value, "Attackers"
    elseif teamId == "Defenders" then return S_DefenderCol.value, "Defenders" end
    return S_NeutralCol.value, teamId
end

-- ============================================================================
-- 14. PLAYER ESP CACHE
-- ============================================================================
local PlayerCache = {}

local function CreatePlayerCache(player)
    if player == LocalPlayer or PlayerCache[player] then return end

    local objects = {
        Box = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        Gun = Drawing.new("Text"),
        HpBg = Drawing.new("Square"),
        HpBar = Drawing.new("Square"),
        HpText = Drawing.new("Text"),
        Snapline = Drawing.new("Line"),
        Bones = {},
        OffscreenArrow = Drawing.new("Triangle"),
        Highlight = nil
    }

    objects.Box.Thickness = 1
    objects.Box.Filled = false
    objects.Name.Size = 13
    objects.Name.Center = true
    objects.Name.Outline = true

    objects.Distance.Size = 12
    objects.Distance.Center = true
    objects.Distance.Outline = true

    objects.Gun.Size = 12
    objects.Gun.Center = true
    objects.Gun.Outline = true

    objects.HpBg.Filled = true
    objects.HpBg.Color = Color3.fromRGB(20, 20, 20)
    objects.HpBar.Filled = true

    objects.HpText.Size = 11
    objects.HpText.Center = false
    objects.HpText.Outline = true

    objects.Snapline.Thickness = 1
    objects.OffscreenArrow.Filled = true

    for i = 1, #R6_CONNECTIONS do
        local line = Drawing.new("Line")
        line.Thickness = 1.5
        table.insert(objects.Bones, line)
    end

    PlayerCache[player] = objects
end

local function RemovePlayerCache(player)
    local cache = PlayerCache[player]
    if not cache then return end

    if cache.Highlight then cache.Highlight:Destroy() end
    cache.Box:Remove()
    cache.Name:Remove()
    cache.Distance:Remove()
    cache.Gun:Remove()
    cache.HpBg:Remove()
    cache.HpBar:Remove()
    cache.HpText:Remove()
    cache.Snapline:Remove()
    cache.OffscreenArrow:Remove()

    for _, line in ipairs(cache.Bones) do line:Remove() end
    PlayerCache[player] = nil
end

local function HidePlayerDrawings(cache)
    cache.Box.Visible = false
    cache.Name.Visible = false
    cache.Distance.Visible = false
    cache.Gun.Visible = false
    cache.HpBg.Visible = false
    cache.HpBar.Visible = false
    cache.HpText.Visible = false
    cache.Snapline.Visible = false
    cache.OffscreenArrow.Visible = false
    if cache.Highlight then cache.Highlight.Enabled = false end
    for _, line in ipairs(cache.Bones) do line.Visible = false end
end

-- ============================================================================
-- 15. WORLD OBJECT ESP MODULES
-- ============================================================================
local DroneCache = {}
local ItemCache = {}
local GrenadeCache = {}
local CorpseCache = {}

local function UpdateCorpseESP(activeTargetPositions)
    if not (S_MasterSwitch.value and S_CorpseESP.value) then
        for _, obj in pairs(CorpseCache) do obj:Remove() end
        table.clear(CorpseCache)
        return
    end

    local bodiesFolder = workspace:FindFirstChild("bodies") or workspace:FindFirstChild("Bodies")
    if not bodiesFolder then
        for _, obj in pairs(CorpseCache) do obj:Remove() end
        table.clear(CorpseCache)
        return
    end

    local activeMap = {}
    for _, bodyModel in ipairs(bodiesFolder:GetChildren()) do
        if bodyModel:IsA("Model") then
            activeMap[bodyModel] = true
            local worldPos = bodyModel.PrimaryPart and bodyModel.PrimaryPart.Position or bodyModel:GetPivot().Position

            if worldPos then
                if S_RadarItems.value then
                    table.insert(activeTargetPositions, {
                        Position = worldPos,
                        Color = COLOR_CORPSE,
                        LookVector = nil
                    })
                end

                local drawing = CorpseCache[bodyModel] or Drawing.new("Text")
                drawing.Size = 12
                drawing.Center = true
                drawing.Outline = true
                drawing.Color = COLOR_CORPSE
                CorpseCache[bodyModel] = drawing

                local screenPos, onScreen = Camera:WorldToViewportPoint(worldPos)
                if onScreen then
                    local dist = math.floor((Camera.CFrame.Position - worldPos).Magnitude)
                    drawing.Text = "[DEAD CORPSE] [" .. dist .. "m]"
                    drawing.Position = Vector2.new(screenPos.X, screenPos.Y)
                    drawing.Visible = true
                else
                    drawing.Visible = false
                end
            end
        end
    end

    for bodyObj, drawing in pairs(CorpseCache) do
        if not activeMap[bodyObj] then
            drawing:Remove()
            CorpseCache[bodyObj] = nil
        end
    end
end

local function UpdateGrenadeESP(activeTargetPositions)
    if not (S_MasterSwitch.value and S_GrenadeESP.value) then
        for _, obj in pairs(GrenadeCache) do
            obj.Text:Remove()
            obj.Circle:Remove()
        end
        table.clear(GrenadeCache)
        return
    end

    local debrisFolder = workspace:FindFirstChild("Debris") or workspace:FindFirstChild("debris")
    if not debrisFolder then
        for _, obj in pairs(GrenadeCache) do
            obj.Text:Remove()
            obj.Circle:Remove()
        end
        table.clear(GrenadeCache)
        return
    end

    local localChar = LocalPlayer.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    local activeMap = {}

    for _, model in ipairs(debrisFolder:GetChildren()) do
        if model:IsA("Model") then
            local spoon = model:FindFirstChild("Spoon")
            local handler = model:FindFirstChild("Handler")

            if spoon and handler and spoon:IsA("MeshPart") then
                activeMap[model] = true
                local worldPos = model.PrimaryPart and model.PrimaryPart.Position or model:GetPivot().Position

                if S_RadarItems.value then
                    table.insert(activeTargetPositions, {
                        Position = worldPos,
                        Color = COLOR_GRENADE_DANGER,
                        LookVector = nil
                    })
                end

                local cache = GrenadeCache[model]
                if not cache then
                    cache = {
                        Text = Drawing.new("Text"),
                        Circle = Drawing.new("Circle")
                    }
                    cache.Text.Size = 13
                    cache.Text.Center = true
                    cache.Text.Outline = true
                    cache.Circle.Filled = false
                    cache.Circle.Thickness = 1.5
                    GrenadeCache[model] = cache
                end

                local screenPos, onScreen = Camera:WorldToViewportPoint(worldPos)
                if onScreen then
                    local dist = localRoot and (localRoot.Position - worldPos).Magnitude or 0
                    local isDangerous = localRoot and (dist <= S_GrenadeWarnDist.value)
                    local displayCol = isDangerous and COLOR_GRENADE_DANGER or COLOR_GRENADE_SAFE

                    cache.Text.Text = string.format("[! GRENADE !] [%dm]", math.floor(dist))
                    cache.Text.Position = Vector2.new(screenPos.X, screenPos.Y - 15)
                    cache.Text.Color = displayCol
                    cache.Text.Visible = true

                    cache.Circle.Position = Vector2.new(screenPos.X, screenPos.Y)
                    cache.Circle.Radius = math.clamp(1000 / math.max(dist, 1), 8, 40)
                    cache.Circle.Color = displayCol
                    cache.Circle.Visible = true
                else
                    cache.Text.Visible = false
                    cache.Circle.Visible = false
                end
            end
        end
    end

    for modelObj, cache in pairs(GrenadeCache) do
        if not activeMap[modelObj] then
            cache.Text:Remove()
            cache.Circle:Remove()
            GrenadeCache[modelObj] = nil
        end
    end
end

local function UpdateDroneESP(activeTargetPositions)
    if not (S_MasterSwitch.value and S_DroneESP.value) then
        for _, d in pairs(DroneCache) do d:Remove() end
        table.clear(DroneCache)
        return
    end

    local activeMap = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Base") and obj:FindFirstChild("Battery V10") then
            activeMap[obj] = true
            local pivot = obj:GetPivot()
            local worldPos = obj.PrimaryPart and obj.PrimaryPart.Position or pivot.Position
            local lookVector = pivot.LookVector

            if worldPos then
                table.insert(activeTargetPositions, {
                    Position = worldPos,
                    Color = COLOR_DRONE,
                    LookVector = lookVector
                })

                local drawing = DroneCache[obj] or Drawing.new("Text")
                drawing.Size = 13
                drawing.Center = true
                drawing.Outline = true
                drawing.Color = COLOR_DRONE
                DroneCache[obj] = drawing

                local screenPos, onScreen = Camera:WorldToViewportPoint(worldPos)
                if onScreen then
                    local dist = math.floor((Camera.CFrame.Position - worldPos).Magnitude)
                    drawing.Text = "[DRONE] [" .. dist .. "m]"
                    drawing.Position = Vector2.new(screenPos.X, screenPos.Y)
                    drawing.Visible = true
                else drawing.Visible = false end
            end
        end
    end

    for droneModel, drawing in pairs(DroneCache) do
        if not activeMap[droneModel] then
            drawing:Remove()
            DroneCache[droneModel] = nil
        end
    end
end

local function UpdateItemESP(activeTargetPositions)
    if not (S_MasterSwitch.value and S_AmmoESP.value) then
        for _, item in pairs(ItemCache) do item:Remove() end
        table.clear(ItemCache)
        return
    end

    local activeMap = {}
    local debrisFolder = workspace:FindFirstChild("Debris") or workspace:FindFirstChild("debris")
    local droppedFolder = debrisFolder and (debrisFolder:FindFirstChild("Dropped") or debrisFolder:FindFirstChild("dropped"))

    if droppedFolder then
        for _, item in ipairs(droppedFolder:GetChildren()) do
            activeMap[item] = true
            local worldPos = item:IsA("BasePart") and item.Position or (item.PrimaryPart and item.PrimaryPart.Position or item:GetPivot().Position)

            if worldPos then
                if S_RadarItems.value then
                    table.insert(activeTargetPositions, {
                        Position = worldPos,
                        Color = COLOR_DROPPED,
                        LookVector = nil
                    })
                end

                local drawing = ItemCache[item] or Drawing.new("Text")
                drawing.Size = 12
                drawing.Center = true
                drawing.Outline = true
                drawing.Color = COLOR_DROPPED
                ItemCache[item] = drawing

                local screenPos, onScreen = Camera:WorldToViewportPoint(worldPos)
                if onScreen then
                    local dist = math.floor((Camera.CFrame.Position - worldPos).Magnitude)
                    drawing.Text = item.Name .. " [" .. dist .. "m]"
                    drawing.Position = Vector2.new(screenPos.X, screenPos.Y)
                    drawing.Visible = true
                else
                    drawing.Visible = false
                end
            end
        end
    end

    for itemObj, drawing in pairs(ItemCache) do
        if not activeMap[itemObj] then
            drawing:Remove()
            ItemCache[itemObj] = nil
        end
    end
end

-- ============================================================================
-- 16. DRAWING-BASED MAIN RENDER LOOP
-- ============================================================================
RunService.RenderStepped:Connect(function()
    local masterEnabled = S_MasterSwitch.value
    local activeTargetPositions = {}

    UpdateCrosshair()
    UpdateFullbright()
    UpdateDroneESP(activeTargetPositions)
    UpdateItemESP(activeTargetPositions)
    UpdateGrenadeESP(activeTargetPositions)
    UpdateCorpseESP(activeTargetPositions)
    UpdateBulletTracers()

    for player, cache in pairs(PlayerCache) do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")

        if not (masterEnabled and character and humanoid and rootPart and humanoid.Health > 0) then
            HidePlayerDrawings(cache)
            continue
        end

        if S_TeamCheck.value and IsTeammate(player) then
            HidePlayerDrawings(cache)
            continue
        end

        local teamColor = GetPlayerTeam(player)
        local visible = IsVisible(character)
        local displayColor = S_WallCheck.value and (visible and COLOR_VISIBLE or COLOR_HIDDEN) or teamColor

        table.insert(activeTargetPositions, {
            Position = rootPart.Position,
            Color = displayColor,
            LookVector = rootPart.CFrame.LookVector
        })

        local screenPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)

        -- CHAMS
        if S_ChamsEnabled.value then
            if not cache.Highlight or cache.Highlight.Parent ~= SafeContainer then
                if cache.Highlight then cache.Highlight:Destroy() end
                local hl = Instance.new("Highlight")
                hl.FillTransparency = 0.5
                hl.Parent = SafeContainer
                cache.Highlight = hl
            end
            
            cache.Highlight.Adornee = character
            cache.Highlight.FillColor = displayColor
            cache.Highlight.OutlineColor = displayColor
            cache.Highlight.DepthMode = S_ChamsVisOnly.value and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
            cache.Highlight.Enabled = true
        elseif cache.Highlight then cache.Highlight.Enabled = false end

        -- 2D DRAWINGS
        if onScreen then
            cache.OffscreenArrow.Visible = false
            local distance = (Camera.CFrame.Position - rootPart.Position).Magnitude
            
            local head = character:FindFirstChild("Head")
            local topWorldPos = head and (head.Position + Vector3.new(0, 0.8, 0)) or (rootPart.Position + Vector3.new(0, 3, 0))
            local bottomWorldPos = rootPart.Position - Vector3.new(0, 3, 0)
            
            local topScreenPos = Camera:WorldToViewportPoint(topWorldPos)
            local bottomScreenPos = Camera:WorldToViewportPoint(bottomWorldPos)
            
            local sizeY = math.abs(topScreenPos.Y - bottomScreenPos.Y)
            local sizeX = sizeY * 0.65
            local boxPos = Vector2.new(screenPos.X - sizeX / 2, topScreenPos.Y)

            -- Target Snaplines
            if S_Snaplines.value then
                local originPos = S_SnaplineOrigin.value == "Center" and Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2) or Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                cache.Snapline.From = originPos
                cache.Snapline.To = Vector2.new(screenPos.X, bottomScreenPos.Y)
                cache.Snapline.Color = displayColor
                cache.Snapline.Visible = true
            else cache.Snapline.Visible = false end

            -- Box ESP
            if S_Boxes.value then
                cache.Box.Size = Vector2.new(sizeX, sizeY)
                cache.Box.Position = boxPos
                cache.Box.Color = displayColor
                cache.Box.Visible = true
            else cache.Box.Visible = false end

            -- R6 Bones
            if S_Bones.value then
                for i, pair in ipairs(R6_CONNECTIONS) do
                    local partA = character:FindFirstChild(pair[1])
                    local partB = character:FindFirstChild(pair[2])

                    if partA and partB then
                        local posA, visA = Camera:WorldToViewportPoint(partA.Position)
                        local posB, visB = Camera:WorldToViewportPoint(partB.Position)

                        if visA and visB then
                            local line = cache.Bones[i]
                            if line then
                                line.From = Vector2.new(posA.X, posA.Y)
                                line.To = Vector2.new(posB.X, posB.Y)
                                line.Color = displayColor
                                line.Visible = true
                            end
                        else
                            if cache.Bones[i] then cache.Bones[i].Visible = false end
                        end
                    else
                        if cache.Bones[i] then cache.Bones[i].Visible = false end
                    end
                end
            else
                for _, line in ipairs(cache.Bones) do line.Visible = false end
            end

            -- Name ESP
            if S_Names.value then
                cache.Name.Text = player.DisplayName
                cache.Name.Position = Vector2.new(screenPos.X, boxPos.Y - 16)
                cache.Name.Color = displayColor
                cache.Name.Visible = true
            else cache.Name.Visible = false end

            -- Health Bar & Numerical Text ESP
            if S_Health.value then
                local maxHealth = math.max(humanoid.MaxHealth, 1)
                local currentHealth = math.clamp(humanoid.Health, 0, maxHealth)
                local healthPercent = currentHealth / maxHealth

                local barWidth = 3
                local barX = boxPos.X - barWidth - 4
                
                cache.HpBg.Size = Vector2.new(barWidth, sizeY)
                cache.HpBg.Position = Vector2.new(barX, boxPos.Y)
                cache.HpBg.Visible = true

                local fillHeight = sizeY * healthPercent
                cache.HpBar.Size = Vector2.new(barWidth, fillHeight)
                cache.HpBar.Position = Vector2.new(barX, boxPos.Y + (sizeY - fillHeight))
                cache.HpBar.Color = Color3.fromRGB(255, 0, 0):Lerp(Color3.fromRGB(0, 255, 0), healthPercent)
                cache.HpBar.Visible = true

                if S_HealthText.value then
                    cache.HpText.Text = string.format("%d HP", math.floor(currentHealth))
                    cache.HpText.Position = Vector2.new(barX - 32, boxPos.Y + (sizeY - fillHeight) - 2)
                    cache.HpText.Color = cache.HpBar.Color
                    cache.HpText.Visible = true
                else cache.HpText.Visible = false end
            else
                cache.HpBg.Visible = false
                cache.HpBar.Visible = false
                cache.HpText.Visible = false
            end

            local bottomOffset = boxPos.Y + sizeY + 2

            -- Distance ESP
            if S_Distance.value then
                cache.Distance.Text = "[" .. math.floor(distance) .. "m]"
                cache.Distance.Position = Vector2.new(screenPos.X, bottomOffset)
                cache.Distance.Color = displayColor
                cache.Distance.Visible = true
                bottomOffset = bottomOffset + 14
            else cache.Distance.Visible = false end

            -- Held Weapon ESP
            if S_GunESP.value then
                local weaponName = GetHeldWeaponName(character)
                cache.Gun.Text = weaponName
                cache.Gun.Position = Vector2.new(screenPos.X, bottomOffset)
                cache.Gun.Color = COLOR_DROPPED
                cache.Gun.Visible = true
            else cache.Gun.Visible = false end

        else
            cache.Box.Visible = false
            cache.Name.Visible = false
            cache.Distance.Visible = false
            cache.Gun.Visible = false
            cache.HpBg.Visible = false
            cache.HpBar.Visible = false
            cache.HpText.Visible = false
            cache.Snapline.Visible = false
            for _, line in ipairs(cache.Bones) do line.Visible = false end

            -- Offscreen Indicator
            if S_OffscreenESP.value then
                local radius = S_IndicatorRadius.value
                local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

                local camCFrame = Camera.CFrame
                local relativePos = camCFrame:PointToObjectSpace(rootPart.Position)
                local angle = math.atan2(-relativePos.Z, relativePos.X)

                local arrowPos = center + Vector2.new(math.cos(angle), math.sin(angle)) * radius
                
                local size = S_IndicatorSize.value
                local dir = (arrowPos - center).Unit
                local perp = Vector2.new(-dir.Y, dir.X)

                cache.OffscreenArrow.PointA = arrowPos + (dir * size)
                cache.OffscreenArrow.PointB = arrowPos - (dir * size) + (perp * (size / 1.5))
                cache.OffscreenArrow.PointC = arrowPos - (dir * size) - (perp * (size / 1.5))
                cache.OffscreenArrow.Color = displayColor
                cache.OffscreenArrow.Visible = true
            else
                cache.OffscreenArrow.Visible = false
            end
        end
    end

    UpdateRadar(activeTargetPositions)
end)

-- Player Listeners
for _, p in ipairs(Players:GetPlayers()) do CreatePlayerCache(p) end
Players.PlayerAdded:Connect(CreatePlayerCache)
Players.PlayerRemoving:Connect(RemovePlayerCache)

-- Initialize System Load Notification
Notify("The Lost Front Script Initialized", "SUCCESS", 3)
