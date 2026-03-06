--[[
	ProximityEvents - Remote events for butler proximity system

	Manages communication between server and client for the proximity countdown timer.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProximityEvents = {}

-- Create remote events folder if it doesn't exist
local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remotesFolder.Name = "Remotes"
remotesFolder.Parent = ReplicatedStorage

-- Create proximity countdown event
local countdownEvent = remotesFolder:FindFirstChild("ProximityCountdown") or Instance.new("RemoteEvent")
countdownEvent.Name = "ProximityCountdown"
countdownEvent.Parent = remotesFolder

-- Create proximity death event
local deathEvent = remotesFolder:FindFirstChild("ProximityDeath") or Instance.new("RemoteEvent")
deathEvent.Name = "ProximityDeath"
deathEvent.Parent = remotesFolder

ProximityEvents.CountdownUpdate = countdownEvent
ProximityEvents.Death = deathEvent

return ProximityEvents
