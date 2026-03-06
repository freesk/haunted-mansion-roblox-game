--[[
	SoundEvents - RemoteEvents for client-side sound control

	Allows server to trigger sound play/stop on individual clients.
	Prevents sounds from continuing when players respawn in lobby.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SoundEvents = {}

print("[SoundEvents] Module loading...")

-- Wait for Remotes folder to exist
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
if not Remotes then
	warn("[SoundEvents] Failed to find Remotes folder!")
	return SoundEvents
end

-- Function to get or create a RemoteEvent
local function getOrCreateRemoteEvent(name)
	local existing = Remotes:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		print("[SoundEvents] Found existing RemoteEvent:", name)
		return existing
	end

	-- Only server should create RemoteEvents
	if RunService:IsServer() then
		local newEvent = Instance.new("RemoteEvent")
		newEvent.Name = name
		newEvent.Parent = Remotes
		print("[SoundEvents] Server created RemoteEvent:", name)
		return newEvent
	else
		-- Client waits for server to create it
		print("[SoundEvents] Client waiting for RemoteEvent:", name)
		local event = Remotes:WaitForChild(name, 10)
		if event then
			print("[SoundEvents] Client found RemoteEvent:", name)
			return event
		else
			warn("[SoundEvents] Client failed to find RemoteEvent:", name)
			return nil
		end
	end
end

-- Get or create RemoteEvents
SoundEvents.PlayMansionMusic = getOrCreateRemoteEvent("PlayMansionMusic")
SoundEvents.PlayLobbyMusic = getOrCreateRemoteEvent("PlayLobbyMusic")
SoundEvents.StopAllMusic = getOrCreateRemoteEvent("StopAllMusic")

print("[SoundEvents] Module ready with events:", SoundEvents.PlayMansionMusic, SoundEvents.PlayLobbyMusic, SoundEvents.StopAllMusic)

return SoundEvents
