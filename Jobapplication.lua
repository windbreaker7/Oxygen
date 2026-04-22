-- [[ OXYGEN V2 - MANUAL BYPASS BUILD ]]
local RS = game:GetService("RunService")
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- [[ BYPASS LOGIC FUNCTION ]]
local function ApplyBypass()
    local success, err = pcall(function()
        hookfunction(RS.IsStudio, function() return true end)
        
        local DetRem = game:GetService("ReplicatedStorage"):FindFirstChild("ExecutorDetection")
        local mt = getrawmetatable(game)
        local oldNC = mt.__namecall
        setreadonly(mt, false)

        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if (self == DetRem or tostring(self) == "ExecutorDetection") and method == "FireServer" then
                return nil 
            end
            return oldNC(self, ...)
        end)
        setreadonly(mt, true)
    end)
    return success
end

-- Initial Execution
ApplyBypass()

-- FOV Setup
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Transparency = 0.8 
FOVCircle.Filled = false
FOVCircle.Visible = false
FOVCircle.Radius = 100 

-- UI Initialization
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
   Name = "OXYGEN | V2",
   LoadingTitle = "Oxygen System",
   LoadingStatus = "Initialising Security...",
   ConfigurationSaving = {Enabled = false},
   KeySystem = false 
})

_G.P, _G.S, _G.L = false, false, false
_G.AimEnabled, _G.WallCheck, _G.AimFOV = false, false, 100
_G.AimSmoothness = 1
_G.ShowFOV = false

local VisualsTab = Window:CreateTab("Visuals", 4483362458)
local AimTab = Window:CreateTab("Aimtouch", 4483362458)
local TestTab = Window:CreateTab("Testing", 4483362458)
local InfoTab = Window:CreateTab("Logs", 4483362458)

-- [[ LOGS TAB ]]
InfoTab:CreateSection("System Information")
local LogBox = InfoTab:CreateParagraph({Title = "Changelog", Content = "Connecting..."})

local function UpdateLogs()
    local success, result = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/janjirapetkum-collab/Oxygen/refs/heads/main/Changelog.txt")
    end)
    if success then
        LogBox:Set({Title = "Live Updates ("..os.date("%X")..")", Content = result})
    else
        LogBox:Set({Title = "Connection Error", Content = "Check GitHub Link Integrity."})
    end
end
InfoTab:CreateButton({Name = "Refresh Logs", Callback = UpdateLogs})
task.spawn(UpdateLogs)

-- [[ VISUALS TAB ]]
VisualsTab:CreateSection("ESP Settings")
VisualsTab:CreateToggle({Name = "Player ESP", CurrentValue = false, Callback = function(v) _G.P = v end})
VisualsTab:CreateToggle({Name = "Scav ESP", CurrentValue = false, Callback = function(v) _G.S = v end})
VisualsTab:CreateToggle({Name = "Loot ESP", CurrentValue = false, Callback = function(v) _G.L = v end})

-- [[ AIMTOUCH TAB ]]
AimTab:CreateSection("Safety First: Features are high-risk.")
AimTab:CreateToggle({Name = "Enable Aimtouch", CurrentValue = false, Flag = "AimMain", Callback = function(v) _G.AimEnabled = v end})
AimTab:CreateToggle({Name = "Wall Check", CurrentValue = false, Flag = "AimWall", Callback = function(v) _G.WallCheck = v end})
AimTab:CreateToggle({Name = "POV Visible", CurrentValue = false, Flag = "POVVis", Callback = function(v) _G.ShowFOV = v; FOVCircle.Visible = v end})
AimTab:CreateSlider({
    Name = "POV Size",
    Range = {10, 800},
    Increment = 1,
    Suffix = "px",
    CurrentValue = 100,
    Flag = "POVSlider",
    Callback = function(v) _G.AimFOV = v; FOVCircle.Radius = v end
})
AimTab:CreateSlider({
    Name = "Smoothness",
    Range = {1, 100},
    Increment = 1,
    Suffix = "%",
    CurrentValue = 10,
    Flag = "SmoothSlider",
    Callback = function(v) _G.AimSmoothness = v end
})

-- [[ TESTING TAB ]]
TestTab:CreateSection("Manual Security Tools")
local StatusLabel = TestTab:CreateLabel("Status: IDLE")

TestTab:CreateButton({
    Name = "Manual Bypass Re-Hook",
    Callback = function()
        local didWork = ApplyBypass()
        if didWork then
            Rayfield:Notify({Title = "Security", Content = "Metatable Hooks Re-Applied", Duration = 3})
            StatusLabel:Set("Status: ✅ Bypass Re-Applied")
        else
            StatusLabel:Set("Status: ❌ Bypass Failed")
        end
    end,
})

TestTab:CreateButton({
    Name = "Check Integrity",
    Callback = function()
        local ac_script = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("AntiExecutor")
        local ac_remote = game:GetService("ReplicatedStorage"):FindFirstChild("ExecutorDetection")
        StatusLabel:Set((ac_remote and ac_script) and "Status: ✅ Signatures Found" or "Status: ⚠️ Components Missing")
    end,
})

-- [[ LOGIC FUNCTIONS ]]
local function CreateESP(part, name, color)
    if part:FindFirstChild("Ox_E") then return end
    local B = Instance.new("BillboardGui", part)
    B.Name = "Ox_E"
    B.AlwaysOnTop, B.Size = true, UDim2.new(0, 100, 0, 50)
    local L = Instance.new("TextLabel", B)
    L.BackgroundTransparency, L.Size, L.Text, L.TextColor3, L.TextSize = 1, UDim2.new(1,0,1,0), name, color, 14
    L.Font, L.TextStrokeTransparency = Enum.Font.SourceSansBold, 0
end

local function IsVisible(part)
    if not _G.WallCheck then return true end
    local cast = Camera:GetPartsObscuringTarget({Camera.CFrame.Position, part.Position}, {LP.Character, part.Parent})
    return #cast == 0
end

local function GetClosest()
    local target, shortest = nil, _G.AimFOV
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and p.Character:FindFirstChild("Head") then
            local pos, onScreen = Camera:WorldToViewportPoint(p.Character.Head.Position)
            if onScreen then
                local dist = (Vector2.new(pos.X, pos.Y) - screenCenter).Magnitude
                if dist < shortest and IsVisible(p.Character.Head) then
                    shortest = dist
                    target = p
                end
            end
        end
    end
    return target
end

-- [[ MAIN LOOP ]]
RS.RenderStepped:Connect(function()
    if FOVCircle then
        FOVCircle.Visible = _G.ShowFOV
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    end

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and p.Character:FindFirstChild("Head") then
            if _G.P then CreateESP(p.Character.Head, p.Name, Color3.new(1, 0.2, 0.2))
            elseif p.Character.Head:FindFirstChild("Ox_E") then p.Character.Head.Ox_E:Destroy() end
        end
    end

    if _G.AimEnabled then
        local t = GetClosest()
        if t and t.Character and t.Character:FindFirstChild("Head") then
            local targetCFrame = CFrame.new(Camera.CFrame.Position, t.Character.Head.Position)
            local smoothVal = math.clamp(1 - (_G.AimSmoothness / 105), 0.01, 1)
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, smoothVal)
        end
    end
end)

Rayfield:Notify({Title = "Oxygen", Content = "System Online", Duration = 3})
