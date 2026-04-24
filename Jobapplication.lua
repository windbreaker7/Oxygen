-- [[ OXYGEN V2 - THE COMPLETE UNABRIDGED HUMANIZED BUILD ]]
local RS = game:GetService("RunService")
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- [[ BYPASS ENGINE ]]
local function ApplyBypass()
    pcall(function() hookfunction(RS.IsStudio, function() return true end) end)
    local Remote = game:GetService("ReplicatedStorage"):FindFirstChild("ExecutorDetection")
    local mt = getrawmetatable(game)
    local oldNC = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        if (self == Remote or tostring(self) == "ExecutorDetection") and getnamecallmethod() == "FireServer" then return nil end
        return oldNC(self, ...)
    end)
    setreadonly(mt, true)
end
ApplyBypass()

-- [[ FOV VISUALIZER (OUTLINED ONLY) ]]
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5
FOVCircle.Color = Color3.new(1, 1, 1)
FOVCircle.Transparency = 0.8
FOVCircle.Filled = false
FOVCircle.Visible = false
FOVCircle.Radius = 100 

-- [[ MASTER CONFIG ]]
_G.Config = {
    Visuals = { Player = false, Scav = false, Health = false },
    Loot = { Master = false, Bot = false, Player = false },
    Gear = { Master = false, Scan = false },
    Aim = { Enabled = false, WallCheck = false, Smoothness = 10, FOV = 100, TargetPart = "Head", ShowFOV = false },
    Targets = { Players = true, NPCs = false }
}

local Helmets = {"IND50", "KSS2 Tactical", "RST Special Forces", "F70 Tactical", "PAS Standard"}
local Armors = {"KN Comp. Spartan B", "SEK Fortress", "926 Composite"}

-- [[ UI INITIALIZATION ]]
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({Name = "OXYGEN | V2", LoadingTitle = "Oxygen System", ConfigurationSaving = {Enabled = false}})

local VisualsTab = Window:CreateTab("Visuals")
local AimTab = Window:CreateTab("Aimtouch")
local TestTab = Window:CreateTab("Testing")
local InfoTab = Window:CreateTab("Logs")

-- [[ LOGS SECTION - UPDATED TO WINDBREAKER7 ]]
InfoTab:CreateSection("System Information")
local LogBox = InfoTab:CreateParagraph({Title = "Changelog", Content = "Fetching data..."})
local function SyncLogs()
    local success, result = pcall(function() 
        return game:HttpGet("https://raw.githubusercontent.com/windbreaker7/Oxygen/refs/heads/main/Changelog.txt") 
    end)
    if success then 
        LogBox:Set({Title = "Update Log: "..os.date("%X"), Content = result}) 
    end
end
InfoTab:CreateButton({Name = "Refresh Logs", Callback = SyncLogs})
task.spawn(SyncLogs)

-- [[ VISUALS SECTION ]]
VisualsTab:CreateSection("ESP")
VisualsTab:CreateToggle({Name = "Player ESP", Callback = function(v) _G.Config.Visuals.Player = v end})
VisualsTab:CreateToggle({Name = "Scav ESP", Callback = function(v) _G.Config.Visuals.Scav = v end})
VisualsTab:CreateToggle({Name = "Health ESP", Callback = function(v) _G.Config.Visuals.Health = v end})

VisualsTab:CreateSection("ESP LOOT")
VisualsTab:CreateToggle({Name = "Loot Master", Callback = function(v) _G.Config.Loot.Master = v end})
VisualsTab:CreateToggle({Name = "Bot Loot", Callback = function(v) _G.Config.Loot.Bot = v end})
VisualsTab:CreateToggle({Name = "Player Loot", Callback = function(v) _G.Config.Loot.Player = v end})

VisualsTab:CreateSection("ESP GEAR")
VisualsTab:CreateToggle({Name = "Gear Master", Callback = function(v) _G.Config.Gear.Master = v end})
VisualsTab:CreateToggle({Name = "Armor/Helmet ESP", Callback = function(v) _G.Config.Gear.Scan = v end})

-- [[ AIMTOUCH SECTION ]]
AimTab:CreateSection("Targeting")
AimTab:CreateDropdown({Name = "Targets", Options = {"Players", "Scavs"}, CurrentOption = {"Players"}, MultipleOptions = true, Callback = function(o)
    _G.Config.Targets.Players = table.find(o, "Players") and true or false
    _G.Config.Targets.NPCs = table.find(o, "Scavs") and true or false
end})
AimTab:CreateDropdown({Name = "Target Bone", Options = {"Head", "HumanoidRootPart", "LeftFoot", "RightFoot"}, CurrentOption = {"Head"}, Callback = function(o) _G.Config.Aim.TargetPart = o[1] end})

AimTab:CreateSection("Mechanics")
AimTab:CreateToggle({Name = "Enable Aimtouch", Callback = function(v) _G.Config.Aim.Enabled = v end})
AimTab:CreateToggle({Name = "Wall Check", Callback = function(v) _G.Config.Aim.WallCheck = v end})
AimTab:CreateToggle({Name = "Show FOV Circle", Callback = function(v) _G.Config.Aim.ShowFOV = v end})

AimTab:CreateSlider({
    Name = "POV Size (px)", 
    Range = {10, 800}, 
    Increment = 1, 
    Suffix = "px", 
    CurrentValue = 100, 
    Callback = function(v) _G.Config.Aim.FOV = v; FOVCircle.Radius = v end
})

AimTab:CreateSlider({
    Name = "Smoothness (%)", 
    Range = {1, 100}, 
    Increment = 1, 
    Suffix = "%", 
    CurrentValue = 10, 
    Callback = function(v) _G.Config.Aim.Smoothness = v end
})

-- [[ TESTING SECTION ]]
TestTab:CreateSection("Integrity Check")
local StatusLabel = TestTab:CreateLabel("Status: IDLE")
TestTab:CreateButton({Name = "Run Bypass Scanner", Callback = function()
    local ac_script = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("AntiExecutor")
    local ac_remote = game:GetService("ReplicatedStorage"):FindFirstChild("ExecutorDetection")
    StatusLabel:Set((ac_remote and ac_script) and "Status: ✅ Verified" or "Status: ⚠️ Missing")
end})
TestTab:CreateButton({Name = "Force Manual Bypass", Callback = ApplyBypass})

-- [[ CORE ESP LOGIC ]]
local function Tag(part, text, color, id)
    local tagId = "Ox_"..id
    local ui = part:FindFirstChild(tagId) or Instance.new("BillboardGui", part)
    ui.Name, ui.AlwaysOnTop, ui.Size = tagId, true, UDim2.new(0, 200, 0, 50)
    local offsets = { P = 2, S = 2, Health = 3.2, PLoot = 4.5, Gear = 6 }
    ui.ExtentsOffset = Vector3.new(0, offsets[id] or 2, 0)
    local label = ui:FindFirstChild("Label") or Instance.new("TextLabel", ui)
    label.Name, label.BackgroundTransparency, label.Size = "Label", 1, UDim2.new(1,0,1,0)
    label.Text, label.TextColor3, label.TextSize = text, color, 11
    label.Font = Enum.Font.Code; label.TextStrokeTransparency = 0.5
end

local function GetHealthColor(hum)
    local ratio = hum.Health / hum.MaxHealth
    return ratio > 0.6 and Color3.new(0,1,0) or ratio > 0.3 and Color3.new(1,1,0) or Color3.new(1,0,0)
end

-- [[ AIM LOGIC ]]
local function IsVisible(part)
    if not _G.Config.Aim.WallCheck then return true end
    local cast = Camera:GetPartsObscuringTarget({Camera.CFrame.Position, part.Position}, {LP.Character, part.Parent})
    return #cast == 0
end

local function GetClosest()
    local target, shortest = nil, _G.Config.Aim.FOV
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    local function Check(model)
        local p = model:FindFirstChild(_G.Config.Aim.TargetPart, true)
        if p and p:IsA("BasePart") and p.Name ~= "M4" then
            local pos, screen = Camera:WorldToViewportPoint(p.Position)
            if screen then
                local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                if dist < shortest and IsVisible(p) then shortest, target = dist, p end
            end
        end
    end
    if _G.Config.Targets.Players then for _, p in pairs(Players:GetPlayers()) do if p ~= LP and p.Character then Check(p.Character) end end end
    if _G.Config.Targets.NPCs then
        local AI = workspace:FindFirstChild("ACS_WorkSpace") and workspace.ACS_WorkSpace:FindFirstChild("AI")
        if AI then for _, b in pairs(AI:GetChildren()) do Check(b) end end
    end
    return target
end

-- [[ MAIN LOOP ]]
RS.RenderStepped:Connect(function()
    FOVCircle.Visible = _G.Config.Aim.ShowFOV
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and p.Character:FindFirstChild("Head") then
            local head, hum = p.Character.Head, p.Character:FindFirstChild("Humanoid")
            if _G.Config.Visuals.Player then Tag(head, p.Name, Color3.new(1, 0.4, 0.4), "P") end
            if _G.Config.Visuals.Health and hum then Tag(head, math.floor(hum.Health).." HP", GetHealthColor(hum), "Health") end
            if _G.Config.Loot.Master and _G.Config.Loot.Player then
                local bpk = {}
                for _, t in pairs(p.Backpack:GetChildren()) do table.insert(bpk, t.Name) end
                Tag(head, "[BP] "..(table.concat(bpk, ", ")), Color3.new(0.4, 1, 1), "PLoot")
            end
            if _G.Config.Gear.Master and _G.Config.Gear.Scan then
                local h, a = "None", "None"
                for _, obj in pairs(p.Character:GetDescendants()) do
                    if table.find(Helmets, obj.Name) then h = obj.Name elseif table.find(Armors, obj.Name) then a = obj.Name end
                end
                Tag(head, "H: "..h.." | A: "..a, Color3.new(0.6, 1, 0.6), "Gear")
            end
        end
    end

    local AI = workspace:FindFirstChild("ACS_WorkSpace") and workspace.ACS_WorkSpace:FindFirstChild("AI")
    if AI then
        for _, b in pairs(AI:GetChildren()) do
            local head, hum = b:FindFirstChild("Head"), b:FindFirstChild("Humanoid")
            if head then
                if _G.Config.Visuals.Scav then Tag(head, "[SCAV] "..b.Name, Color3.new(1, 0.6, 0), "S") end
                if _G.Config.Visuals.Health and hum then Tag(head, math.floor(hum.Health).." HP", GetHealthColor(hum), "Health") end
                local loot = b:FindFirstChild("Loot")
                if loot and _G.Config.Loot.Master and _G.Config.Loot.Bot then
                    for _, item in pairs(loot:GetDescendants()) do
                        local p = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart", true)
                        if p then Tag(p, "[LOOT] "..item.Name, Color3.new(1, 1, 0.4), "BLoot") end
                    end
                end
            end
        end
    end

    if _G.Config.Aim.Enabled then
        local t = GetClosest()
        if t then
            local targetCFrame = CFrame.new(Camera.CFrame.Position, t.Position)
            local smooth = math.clamp(1 - (_G.Config.Aim.Smoothness / 105), 0.01, 1)
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, smooth)
        end
    end
end)
