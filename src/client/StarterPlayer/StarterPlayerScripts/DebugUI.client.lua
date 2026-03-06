--[[
	DebugUI - Client-side debug controls

	Provides toggles for:
	- Proximity death (infinite range when enabled)
	- Monster death (disable kill zones when disabled)
	- Show kill zones (visualize NPC kill zones for calibration)

	ONLY VISIBLE IN ROBLOX STUDIO (not in production)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Only create debug UI in Roblox Studio
if not RunService:IsStudio() then
	print("[DebugUI] Running in production - Debug UI disabled")
	return
end

print("[DebugUI] Running in Studio - Debug UI enabled")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for RemoteEvent
local debugRemote = ReplicatedStorage:WaitForChild("DebugToggle")

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DebugUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Create frame container
local frame = Instance.new("Frame")
frame.Name = "Container"
frame.Size = UDim2.new(0, 250, 0, 175)
frame.Position = UDim2.new(1, -260, 0, 10)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BackgroundTransparency = 0.3
frame.BorderSizePixel = 0
frame.Parent = screenGui

-- Add rounded corners
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

-- Title
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 30)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Debug Controls"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 16
title.Font = Enum.Font.GothamBold
title.Parent = frame

-- Helper function to create toggle switch
local function createToggle(name, labelText, yPosition)
	-- Container for this toggle row
	local container = Instance.new("Frame")
	container.Name = name .. "Container"
	container.Size = UDim2.new(1, -20, 0, 35)
	container.Position = UDim2.new(0, 10, 0, yPosition)
	container.BackgroundTransparency = 1
	container.Parent = frame

	-- Label
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(0.65, 0, 1, 0)
	label.Position = UDim2.new(0, 0, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 14
	label.Font = Enum.Font.Gotham
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container

	-- Toggle switch background
	local toggleBg = Instance.new("TextButton")
	toggleBg.Name = "ToggleButton"
	toggleBg.Size = UDim2.new(0, 60, 0, 28)
	toggleBg.Position = UDim2.new(1, -60, 0.5, -14)
	toggleBg.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	toggleBg.BorderSizePixel = 0
	toggleBg.Text = ""
	toggleBg.Parent = container

	local toggleBgCorner = Instance.new("UICorner")
	toggleBgCorner.CornerRadius = UDim.new(1, 0)
	toggleBgCorner.Parent = toggleBg

	-- Toggle switch slider
	local slider = Instance.new("Frame")
	slider.Name = "Slider"
	slider.Size = UDim2.new(0, 22, 0, 22)
	slider.Position = UDim2.new(0, 3, 0.5, -11)
	slider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	slider.BorderSizePixel = 0
	slider.Parent = toggleBg

	local sliderCorner = Instance.new("UICorner")
	sliderCorner.CornerRadius = UDim.new(1, 0)
	sliderCorner.Parent = slider

	return toggleBg, slider
end

-- Create proximity death toggle
local proximityToggle, proximitySlider = createToggle("Proximity", "Proximity Death", 40)

-- Create monster death toggle
local monsterToggle, monsterSlider = createToggle("Monster", "Monster Death", 85)

-- Create show kill zones toggle
local killZonesToggle, killZonesSlider = createToggle("KillZones", "Show Kill Zones", 130)

-- State
local proximityDeathEnabled = true
local monsterDeathEnabled = true
local showKillZones = false

-- Update toggle appearance
local function updateToggle(toggleBg, slider, enabled)
	local TweenService = game:GetService("TweenService")

	if enabled then
		-- ON state (green, enabled)
		toggleBg.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
		TweenService:Create(slider, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			Position = UDim2.new(1, -25, 0.5, -11)
		}):Play()
	else
		-- OFF state (red, disabled)
		toggleBg.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
		TweenService:Create(slider, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			Position = UDim2.new(0, 3, 0.5, -11)
		}):Play()
	end
end

-- Toggle proximity death
proximityToggle.MouseButton1Click:Connect(function()
	proximityDeathEnabled = not proximityDeathEnabled
	updateToggle(proximityToggle, proximitySlider, proximityDeathEnabled)
	debugRemote:FireServer("ProximityDeath", proximityDeathEnabled)
end)

-- Toggle monster death
monsterToggle.MouseButton1Click:Connect(function()
	monsterDeathEnabled = not monsterDeathEnabled
	updateToggle(monsterToggle, monsterSlider, monsterDeathEnabled)
	debugRemote:FireServer("MonsterDeath", monsterDeathEnabled)
end)

-- Toggle show kill zones
killZonesToggle.MouseButton1Click:Connect(function()
	showKillZones = not showKillZones
	updateToggle(killZonesToggle, killZonesSlider, showKillZones)
	debugRemote:FireServer("ShowKillZones", showKillZones)
end)

-- Initial state
updateToggle(proximityToggle, proximitySlider, proximityDeathEnabled)
updateToggle(monsterToggle, monsterSlider, monsterDeathEnabled)
updateToggle(killZonesToggle, killZonesSlider, showKillZones)

print("[DebugUI] Debug controls initialized")
