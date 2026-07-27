-- [[ IMGUI WANNABES LOADER - ENHANCED ]]
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

-- Safe cloneref / gethui
local targetParent = (gethui and gethui()) or CoreGui

-- Cleanup existing UI
if targetParent:FindFirstChild("ImguiWannabesLoaderUI") then 
    targetParent.ImguiWannabesLoaderUI:Destroy() 
end

local LoaderUI = Instance.new("ScreenGui")
LoaderUI.Name = "ImguiWannabesLoaderUI"
LoaderUI.ResetOnSpawn = false
LoaderUI.Parent = targetParent

-- Main Window
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 0, 0, 0) -- Scaled down initially for entrance animation
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.BackgroundColor3 = Color3.fromRGB(13, 13, 15)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = LoaderUI

local Corner = Instance.new("UICorner", MainFrame)
Corner.CornerRadius = UDim.new(0, 8)

local Stroke = Instance.new("UIStroke", MainFrame)
Stroke.Color = Color3.fromRGB(0, 255, 140)
Stroke.Thickness = 1.2
Stroke.Transparency = 0.4

-- Title Label
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 35)
Title.Position = UDim2.new(0, 0, 0, 10)
Title.BackgroundTransparency = 1
Title.Text = "IMGUI WANNABES"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 16
Title.Font = Enum.Font.Code
Title.Parent = MainFrame

local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(1, 0, 0, 15)
Subtitle.Position = UDim2.new(0, 0, 0, 40)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "github.com/windbreaker7/Oxygen"
Subtitle.TextColor3 = Color3.fromRGB(0, 255, 140)
Subtitle.TextSize = 10
Subtitle.Font = Enum.Font.Code
Subtitle.Transparency = 0.3
Subtitle.Parent = MainFrame

-- Loading Progress Bar Background
local BarBackground = Instance.new("Frame")
BarBackground.Size = UDim2.new(0.85, 0, 0, 4)
BarBackground.Position = UDim2.new(0.075, 0, 0.42, 0)
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
LoadBtn.Size = UDim2.new(0.85, 0, 0, 40)
LoadBtn.Position = UDim2.new(0.075, 0, 0.55, 0)
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
    Size = UDim2.new(0, 320, 0, 190)
}):Play()

-- Interactive Hover Effects
LoadBtn.MouseEnter:Connect(function()
    TweenService:Create(LoadBtn, TweenInfo.new(0.2), {
        BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    }):Play()
    TweenService:Create(BtnStroke, TweenInfo.new(0.2), {
        Color = Color3.fromRGB(0, 255, 140)
    }):Play()
end)

LoadBtn.MouseLeave:Connect(function()
    TweenService:Create(LoadBtn, TweenInfo.new(0.2), {
        BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    }):Play()
    TweenService:Create(BtnStroke, TweenInfo.new(0.2), {
        Color = Color3.fromRGB(45, 45, 55)
    }):Play()
end)

-- Execute Logic
local isExecuting = false
LoadBtn.MouseButton1Click:Connect(function()
    if isExecuting then return end
    isExecuting = true

    LoadBtn.Text = "EXECUTING..."
    Status.Text = "Connecting to repository..."

    -- Animate progress bar filling up
    TweenService:Create(BarFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0.5, 0, 1, 0)
    }):Play()

    task.wait(0.3)
    Status.Text = "Downloading script payload..."

    TweenService:Create(BarFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0.85, 0, 1, 0)
    }):Play()

    local success, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/windbreaker7/Oxygen/refs/heads/main/Imgui_Wannabe.lua"))()
    end)

    if success then
        TweenService:Create(BarFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, 0, 1, 0)
        }):Play()
        Status.Text = "Loaded Successfully!"
        Status.TextColor3 = Color3.fromRGB(0, 255, 140)
        
        task.wait(0.4)
        
        -- Exit Animation
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
        Status.Text = "Execution failed!"
        Status.TextColor3 = Color3.fromRGB(255, 80, 80)
        warn("Imgui Wannabes Loader Error: " .. tostring(err))
    end
end)
