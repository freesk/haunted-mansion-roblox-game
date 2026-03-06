--[[
	ProximityUI - Client-side countdown timer display
	Shows countdown when player is too far from butler.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Import the UI module
local ProximityUIModule = require(script.Parent.Controllers.ProximityUIModule)
local ProximityEvents = require(ReplicatedStorage.Remotes.ProximityEvents)

-- Initialize UI
ProximityUIModule:CreateUI(playerGui)

-- Connect events
ProximityEvents.CountdownUpdate.OnClientEvent:Connect(function(timeLeft, active)
	ProximityUIModule:UpdateCountdown(timeLeft, active)
end)

ProximityEvents.Death.OnClientEvent:Connect(function()
	ProximityUIModule:OnDeath()
end)
