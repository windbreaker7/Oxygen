-- ============================================================================
-- THE LOST FRONT - REMOTE AIMBOT MODULE
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Aimbot = {
    Enabled = false,
    TeamCheck = true,
    WallCheck = true,
    FOVRadius = 120,
    ShowFOV = true,
    FOVPositionMode = "Center", -- "Center" or "Mouse"
    TargetPartMode = "Head",   -- "Head", "Torso", "HumanoidRootPart", or "Random"
    Smoothness = 0.25,         -- 0.01 (Very Smooth) to 1.0 (Instant Snap)
    AimKey = Enum.UserInputType.MouseButton2, -- RMB by default
    IsAiming = false,
    CurrentTarget = nil
}

-- R6 Part List Reference
Aimbot.R6Parts = {
    "Head",
    "Torso",
    "HumanoidRootPart",
    "Left Arm",
    "Right Arm",
    "Left Leg",
    "Right Leg"
}

-- FOV Circle Drawing Initialization
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5
FOVCircle.Filled = false
FOVCircle.Transparency = 1
FOVCircle.Color = Color3.fromRGB(0, 220, 255)
FOVCircle.Visible = false

-- Visibility Check Helper
local function IsPartVisible(part, targetCharacter)
    if not part then return false end
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {Camera, LocalPlayer.Character, targetCharacter}

    local result = workspace:Raycast(Camera.CFrame.Position, part.Position - Camera.CFrame.Position, raycastParams)
    return result == nil
end

-- FOV Center Vector Helper
local function GetFOVCenter()
    if Aimbot.FOVPositionMode == "Mouse" then
        return UserInputService:GetMouseLocation()
    else
        return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    end
end

-- Get Chosen Body Part
local function GetTargetPart(character)
    if not character then return nil end
    if Aimbot.TargetPartMode == "Random" then
        local validParts = {}
        for _, partName in ipairs(Aimbot.R6Parts) do
            local p = character:FindFirstChild(partName)
            if p then table.insert(validParts, p) end
        end
        if #validParts > 0 then
            return validParts[math.random(1, #validParts)]
        end
    end
    return character:FindFirstChild(Aimbot.TargetPartMode) or character:FindFirstChild("Head")
end

-- Find Closest Target Within FOV
local function GetClosestTarget(isTeammateFunc)
    local center = GetFOVCenter()
    local closestPart = nil
    local shortestDistance = Aimbot.FOVRadius

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if Aimbot.TeamCheck and isTeammateFunc and isTeammateFunc(player) then
                continue
            end

            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if char and hum and hum.Health > 0 then
                local targetPart = GetTargetPart(char)
                if targetPart then
                    if Aimbot.WallCheck and not IsPartVisible(targetPart, char) then
                        continue
                    end

                    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                    if onScreen then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                        if dist < shortestDistance then
                            shortestDistance = dist
                            closestPart = targetPart
                        end
                    end
                end
            end
        end
    end

    return closestPart
end

-- Input Listeners for Aiming Key
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Aimbot.AimKey or input.KeyCode == Aimbot.AimKey then
        Aimbot.IsAiming = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Aimbot.AimKey or input.KeyCode == Aimbot.AimKey then
        Aimbot.IsAiming = false
        Aimbot.CurrentTarget = nil
    end
end)

-- Main Render Loop Integration
function Aimbot:Update(isTeammateFunc)
    -- FOV Circle Update
    if Aimbot.Enabled and Aimbot.ShowFOV then
        FOVCircle.Position = GetFOVCenter()
        FOVCircle.Radius = Aimbot.FOVRadius
        FOVCircle.Visible = true
    else
        FOVCircle.Visible = false
    end

    -- Aim Tracking Execution
    if Aimbot.Enabled and Aimbot.IsAiming then
        if not Aimbot.CurrentTarget or not Aimbot.CurrentTarget.Parent or not Aimbot.CurrentTarget.Parent:FindFirstChildOfClass("Humanoid") or Aimbot.CurrentTarget.Parent:FindFirstChildOfClass("Humanoid").Health <= 0 then
            Aimbot.CurrentTarget = GetClosestTarget(isTeammateFunc)
        end

        if Aimbot.CurrentTarget then
            local targetPos = Aimbot.CurrentTarget.Position
            local currentCFrame = Camera.CFrame
            local targetCFrame = CFrame.new(currentCFrame.Position, targetPos)
            Camera.CFrame = currentCFrame:Lerp(targetCFrame, math.clamp(Aimbot.Smoothness, 0.01, 1))
        end
    end
end

return Aimbot
