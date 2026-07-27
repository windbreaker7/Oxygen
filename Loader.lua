-- [[ IMGUI WANNABES LOADER ]]
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

-- Cleanup existing UI
if CoreGui:FindFirstChild("ImguiWannabesLoaderUI") then CoreGui.ImguiWannabesLoaderUI:Destroy() end

local LoaderUI = Instance.new("ScreenGui")
LoaderUI.Name = "ImguiWannabesLoaderUI"
LoaderUI.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 300, 0, 180)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -90)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = LoaderUI

local Corner = Instance.new("UICorner", MainFrame)
Corner.CornerRadius = UDim.new(0, 4)

local Stroke = Instance.new("UIStroke", MainFrame)
Stroke.Color = Color3.fromRGB(40, 40, 40)
Stroke.Thickness = 1.5

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundTransparency = 1
Title.Text = "IMGUI WANNABES"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 18
Title.Font = Enum.Font.Code
Title.Parent = MainFrame

local LoadBtn = Instance.new("TextButton")
LoadBtn.Size = UDim2.new(0.8, 0, 0, 45)
LoadBtn.Position = UDim2.new(0.1, 0, 0.45, 0)
LoadBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
LoadBtn.Text = "EXECUTE IMGUI WANNABES"
LoadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
LoadBtn.Font = Enum.Font.Code
LoadBtn.TextSize = 13
LoadBtn.AutoButtonColor = true
LoadBtn.Parent = MainFrame

local BtnStroke = Instance.new("UIStroke", LoadBtn)
BtnStroke.Color = Color3.fromRGB(60, 60, 60)
BtnStroke.Thickness = 1

Instance.new("UICorner", LoadBtn).CornerRadius = UDim.new(0, 4)

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, 0, 0, 20)
Status.Position = UDim2.new(0, 0, 0.8, 0)
Status.BackgroundTransparency = 1
Status.Text = "Ready to load..."
Status.TextColor3 = Color3.fromRGB(120, 120, 120)
Status.TextSize = 11
Status.Font = Enum.Font.Code
Status.Parent = MainFrame

-- Logic
LoadBtn.MouseButton1Click:Connect(function()
    LoadBtn.Text = "EXECUTING..."
    Status.Text = "Fetching windbreaker7/Oxygen..."
    
    task.wait(0.5)
    
    local success, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/windbreaker7/Oxygen/refs/heads/main/Imgui_Wannabe.lua"))()
    end)
    
    if success then
        LoaderUI:Destroy()
    else
        LoadBtn.Text = "CRIT ERROR"
        Status.Text = "Source retrieval failed."
        warn("Imgui Wannabes Loader Error: " .. tostring(err))
    end
end)
