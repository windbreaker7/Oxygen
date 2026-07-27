-- [[ IMGUI WANNABES LOADER - ENHANCED MULTI-GAME LOADER ]]
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

-- Safe cloneref / gethui
local targetParent = (gethui and gethui()) or CoreGui

-- Cleanup existing UI
if targetParent:FindFirstChild("ImguiWannabesLoaderUI") then 
    targetParent.ImguiWannabesLoaderUI:Destroy() 
end

-- ============================================================================
-- 1. GAME MODULE REGISTRY
-- ============================================================================
local GameModules = {
    ["Operation One"] = {
        Url = "https://raw.githubusercontent.com/windbreaker7/Oxygen/refs/heads/main/Imgui_Wannabe.lua",
        Desc = "ESP, Radar, Viewmodels & No Recoil"
    },
    ["Future Game 1"] = {
        Url = "",
        Desc = "Placeholder module"
    },
    ["Future Game 2"] = {
        Url = "",
        Desc = "Placeholder module"
    }
}

local selectedModuleName = "Operation One"

-- ============================================================================
-- 2. UI INITIALIZATION
-- ============================================================================
local LoaderUI = Instance.new("ScreenGui")
LoaderUI.Name = "ImguiWannabesLoaderUI"
LoaderUI.ResetOnSpawn = false
LoaderUI.Parent = targetParent

-- Main Window
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 0, 0, 0) -- Scaled down for entrance
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.BackgroundColor3 = Color3.fromRGB(13, 13, 15)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = false
MainFrame.Parent = LoaderUI

local Corner = Instance.new("UICorner", MainFrame)
Corner.CornerRadius = UDim.new(0, 8)

local Stroke = Instance.new("UIStroke", MainFrame)
Stroke.Color = Color3.fromRGB(0, 255, 140)
Stroke.Thickness = 1.2
Stroke.Transparency = 0.4

-- Title & Subtitle
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 25)
Title.Position = UDim2.new(0, 0, 0, 10)
Title.BackgroundTransparency = 1
Title.Text = "IMGUI WANNABES"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 16
Title.Font = Enum.Font.Code
Title.Parent = MainFrame

local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(1, 0, 0, 15)
Subtitle.Position = UDim2.new(0, 0, 0, 32)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "github.com/windbreaker7/Oxygen"
Subtitle.TextColor3 = Color3.fromRGB(0, 255, 140)
Subtitle.TextSize = 10
Subtitle.Font = Enum.Font.Code
Subtitle.Transparency = 0.3
Subtitle.Parent = MainFrame

-- ============================================================================
-- 3. DROPDOWN GAME SELECTOR
-- ============================================================================
local DropdownContainer = Instance.new("Frame")
DropdownContainer.Size = UDim2.new(0.85, 0, 0, 32)
DropdownContainer.Position = UDim2.new(0.075, 0, 0.25, 0)
DropdownContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
DropdownContainer.BorderSizePixel = 0
DropdownContainer.ZIndex = 5
DropdownContainer.Parent = MainFrame

Instance.new("UICorner", DropdownContainer).CornerRadius = UDim.new(0, 6)
local DropStroke = Instance.new("UIStroke", DropdownContainer)
DropStroke.Color = Color3.fromRGB(45, 45, 55)
DropStroke.Thickness = 1

local DropBtn = Instance.new("TextButton")
DropBtn.Size = UDim2.new(1, -25, 1, 0)
DropBtn.Position = UDim2.new(0, 10, 0, 0)
DropBtn.BackgroundTransparency = 1
DropBtn.Text = "Target: Operation One"
DropBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
DropBtn.Font = Enum.Font.Code
DropBtn.TextSize = 11
DropBtn.TextXAlignment = Enum.TextXAlignment.Left
DropBtn.ZIndex = 6
DropBtn.Parent = DropdownContainer

local Arrow = Instance.new("TextLabel")
Arrow.Size = UDim2.new(0, 20, 1, 0)
Arrow.Position = UDim2.new(1, -22, 0, 0)
Arrow.BackgroundTransparency = 1
Arrow.Text = "v"
Arrow.TextColor3 = Color3.fromRGB(0, 255, 140)
Arrow.Font = Enum.Font.Code
Arrow.TextSize = 12
Arrow.ZIndex = 6
Arrow.Parent = DropdownContainer

-- Dropdown List Container
local DropList = Instance.new("Frame")
DropList.Size = UDim2.new(1, 0, 0, 0)
DropList.Position = UDim2.new(0, 0, 1, 4)
DropList.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
DropList.BorderSizePixel = 0
DropList.ClipsDescendants = true
DropList.Visible = false
DropList.ZIndex = 10
DropList.Parent = DropdownContainer

Instance.new("UICorner", DropList).CornerRadius = UDim.new(0, 6)
local ListStroke = Instance.new("UIStroke", DropList)
ListStroke.Color = Color3.fromRGB(0, 255, 140)
ListStroke.Thickness = 1
ListStroke.Transparency = 0.5

local ListLayout = Instance.new("UIListLayout", DropList)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Populate Options
local isOpen = false
local function toggleDropdown()
    isOpen = not isOpen
    if isOpen then
        DropList.Visible = true
        Arrow.Text = "^"
        TweenService:Create(DropList, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, 0, 0, #ListLayout:GetChildren() * 26)
        }):Play()
    else
        Arrow.Text = "v"
        local t = TweenService:Create(DropList, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(1, 0, 0, 0)
        })
        t:Play()
        t.Completed:Connect(function()
            if not isOpen then DropList.Visible = false end
        end)
    end
end

DropBtn.MouseButton1Click:Connect(toggleDropdown)

for name, info in pairs(GameModules) do
    local OptionBtn = Instance.new("TextButton")
    OptionBtn.Size = UDim2.new(1, 0, 0, 26)
    OptionBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    OptionBtn.BackgroundTransparency = 0
    OptionBtn.Text = "  " .. name
    OptionBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    OptionBtn.Font = Enum.Font.Code
    OptionBtn.TextSize = 11
    OptionBtn.TextXAlignment = Enum.TextXAlignment.Left
    OptionBtn.ZIndex = 11
    OptionBtn.Parent = DropList

    OptionBtn.MouseEnter:Connect(function()
        OptionBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
        OptionBtn.TextColor3 = Color3.fromRGB(0, 255, 140)
    end)
    OptionBtn.MouseLeave:Connect(function()
        OptionBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
        OptionBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    end)

    OptionBtn.MouseButton1Click:Connect(function()
        selectedModuleName = name
        DropBtn.Text = "Target: " .. name
        toggleDropdown()
    end)
end

-- ============================================================================
-- 4. PROGRESS BAR & EXECUTE BUTTON
-- ============================================================================
local BarBackground = Instance.new("Frame")
BarBackground.Size = UDim2.new(0.85, 0, 0, 4)
BarBackground.Position = UDim2.new(0.075, 0, 0.48, 0)
BarBackground.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
BarBackground.BorderSizePixel = 0
BarBackground.Parent = MainFrame

Instance.new("UICorner", BarBackground).CornerRadius = UDim.new(1, 0)

local BarFill = Instance.new("Frame")
BarFill.Size = UDim2.new(0, 0, 1, 0)
BarFill.BackgroundColor3 = Color3.fromRGB(0, 255, 140)
BarFill.BorderSizePixel = 0
BarFill.Parent = BarBackground

Instance.new("UICorner", BarFill).CornerRadius = UDim.new(1, 0)

-- Execute Button
local LoadBtn = Instance.new("TextButton")
LoadBtn.Size = UDim2.new(0.85, 0, 0, 38)
LoadBtn.Position = UDim2.new(0.075, 0, 0.58, 0)
LoadBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
LoadBtn.Text = "EXECUTE"
LoadBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
LoadBtn.Font = Enum.Font.Code
LoadBtn.TextSize = 13
LoadBtn.AutoButtonColor = false
LoadBtn.Parent = MainFrame

local BtnCorner = Instance.new("UICorner", LoadBtn)
BtnCorner.CornerRadius = UDim.new(0, 6)

local BtnStroke = Instance.new("UIStroke", LoadBtn)
BtnStroke.Color = Color3.fromRGB(45, 45, 55)
BtnStroke.Thickness = 1

-- Status Indicator
local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, 0, 0, 20)
Status.Position = UDim2.new(0, 0, 0.84, 0)
Status.BackgroundTransparency = 1
Status.Text = "System Ready"
Status.TextColor3 = Color3.fromRGB(130, 130, 140)
Status.TextSize = 10
Status.Font = Enum.Font.Code
Status.Parent = MainFrame

-- Entrance Tween Animation
TweenService:Create(MainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Size = UDim2.new(0, 340, 0, 240)
}):Play()

-- Hover Animations
LoadBtn.MouseEnter:Connect(function()
    TweenService:Create(LoadBtn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(30, 30, 38) }):Play()
    TweenService:Create(BtnStroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(0, 255, 140) }):Play()
end)

LoadBtn.MouseLeave:Connect(function()
    TweenService:Create(LoadBtn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(20, 20, 25) }):Play()
    TweenService:Create(BtnStroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(45, 45, 55) }):Play()
end)

-- ============================================================================
-- 5. EXECUTION LOGIC
-- ============================================================================
local isExecuting = false
LoadBtn.MouseButton1Click:Connect(function()
    if isExecuting then return end

    local moduleData = GameModules[selectedModuleName]
    if not moduleData or moduleData.Url == "" then
        Status.Text = "Error: Invalid script URL for target!"
        Status.TextColor3 = Color3.fromRGB(255, 80, 80)
        return
    end

    isExecuting = true
    if isOpen then toggleDropdown() end

    LoadBtn.Text = "EXECUTING..."
    Status.Text = "Connecting to repository..."

    TweenService:Create(BarFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0.5, 0, 1, 0)
    }):Play()

    task.wait(0.3)
    Status.Text = "Downloading " .. selectedModuleName .. "..."

    TweenService:Create(BarFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0.85, 0, 1, 0)
    }):Play()

    local success, err = pcall(function()
        local scriptRaw = game:HttpGet(moduleData.Url .. "?" .. tick())
        local func, parseErr = loadstring(scriptRaw)
        if not func then
            error("Syntax Error in Target Script: " .. tostring(parseErr))
        end
        func()
    end)

    if success then
        TweenService:Create(BarFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, 0, 1, 0)
        }):Play()
        Status.Text = "Loaded Successfully!"
        Status.TextColor3 = Color3.fromRGB(0, 255, 140)
        
        task.wait(0.4)
        
        -- Exit Animation
        MainFrame.ClipsDescendants = true
        local exitTween = TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0)
        })
        exitTween:Play()
        exitTween.Completed:Connect(function()
            LoaderUI:Destroy()
        end)
    else
        BarFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        LoadBtn.Text = "CRITICAL ERROR"
        LoadBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
        Status.Text = "Execution failed! (Check F9 Log)"
        Status.TextColor3 = Color3.fromRGB(255, 80, 80)
        warn("[!] Imgui Wannabes Loader Error: " .. tostring(err))
    end
end)
