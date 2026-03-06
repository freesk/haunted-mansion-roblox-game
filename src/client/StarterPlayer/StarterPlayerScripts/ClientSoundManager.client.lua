--[[
	ClientSoundManager - Client-side sound control

	Handles per-player music playback based on server events.
	Prevents sound bleeding when player dies and respawns in lobby.
]]

print("[ClientSoundManager] Script starting...")

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

print("[ClientSoundManager] Services loaded")

-- Wait for Remotes folder
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
if not Remotes then
	warn("[ClientSoundManager] Failed to find Remotes folder!")
	return
end

print("[ClientSoundManager] Remotes folder found")

-- Wait for SoundEvents module to exist
local SoundEventsModule = Remotes:WaitForChild("SoundEvents", 10)
if not SoundEventsModule then
	warn("[ClientSoundManager] Failed to find SoundEvents module!")
	return
end

print("[ClientSoundManager] SoundEvents module found, requiring...")

local SoundEvents = require(SoundEventsModule)
print("[ClientSoundManager] SoundEvents loaded successfully")

-- Track current background music
local currentMusic = nil

-- Sound library (same as server-side)
local SOUND_LIBRARY = {
	ambientInMansion = "rbxassetid://134980593475246",
	ambientInLobby = "rbxassetid://82579828626004",
}

--[[
	Stops all currently playing music for this client.
]]
local function StopAllMusic()
	if currentMusic then
		currentMusic:Stop()
		currentMusic:Destroy()
		currentMusic = nil
	end
end

--[[
	Plays mansion background music for this client.
]]
local function PlayMansionMusic()
	print("[ClientSoundManager] PlayMansionMusic called")

	-- Check if mansion music is already playing - don't restart
	if currentMusic and currentMusic.SoundId == SOUND_LIBRARY.ambientInMansion and currentMusic.IsPlaying then
		print("[ClientSoundManager] Mansion music already playing, skipping")
		return
	end

	-- Stop any existing music first
	StopAllMusic()

	-- Create new sound
	local sound = Instance.new("Sound")
	sound.Name = "MansionAmbient"
	sound.SoundId = SOUND_LIBRARY.ambientInMansion
	sound.Volume = 0.3
	sound.Looped = true
	sound.Parent = SoundService
	sound:Play()

	currentMusic = sound
	print("[ClientSoundManager] Mansion music playing")
end

--[[
	Plays lobby background music for this client.
]]
local function PlayLobbyMusic()
	print("[ClientSoundManager] PlayLobbyMusic called")

	-- Check if lobby music is already playing - don't restart
	if currentMusic and currentMusic.SoundId == SOUND_LIBRARY.ambientInLobby and currentMusic.IsPlaying then
		print("[ClientSoundManager] Lobby music already playing, skipping")
		return
	end

	local success, err = pcall(function()
		-- Stop any existing music first
		StopAllMusic()

		-- Create new sound
		local sound = Instance.new("Sound")
		sound.Name = "LobbyAmbient"
		sound.SoundId = SOUND_LIBRARY.ambientInLobby
		sound.Volume = 0.4
		sound.Looped = true
		sound.Parent = SoundService

		print("[ClientSoundManager] Sound created, attempting to play...")
		sound:Play()

		currentMusic = sound
		print("[ClientSoundManager] Lobby music playing, IsPlaying:", sound.IsPlaying)
	end)

	if not success then
		warn("[ClientSoundManager] Error playing lobby music:", err)
	end
end

--[[
	Handles character death/respawn to stop mansion sounds in lobby.
]]
local function OnCharacterAdded(character)
	local player = Players.LocalPlayer

	-- Wait for humanoid
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end

	-- Listen for death
	humanoid.Died:Connect(function()
		-- Player died, stop all music immediately
		-- They will respawn in lobby and lobby music will be triggered by server
		StopAllMusic()
	end)
end

-- Connect to remote events with debug output
SoundEvents.PlayMansionMusic.OnClientEvent:Connect(function()
	print("[ClientSoundManager] *** Received PlayMansionMusic event from server ***")
	PlayMansionMusic()
end)

SoundEvents.PlayLobbyMusic.OnClientEvent:Connect(function()
	print("[ClientSoundManager] *** Received PlayLobbyMusic event from server ***")
	PlayLobbyMusic()
end)

SoundEvents.StopAllMusic.OnClientEvent:Connect(function()
	print("[ClientSoundManager] *** Received StopAllMusic event from server ***")
	StopAllMusic()
end)

print("[ClientSoundManager] Event listeners connected successfully")
print("[ClientSoundManager] Listening to:", SoundEvents.PlayLobbyMusic)

-- Handle initial character and future respawns
local player = Players.LocalPlayer
if player.Character then
	OnCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(OnCharacterAdded)

print("[ClientSoundManager] Initialized for", player.Name)
