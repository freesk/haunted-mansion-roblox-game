--[[
	AmbientSoundManager - Spatial ambient sound system

	Manages ambient horror sounds in mansion rooms with 3D spatial positioning.
	Implements patterns from RESEARCH.md "Ambient Sound Setup" code example.

	Responsibilities:
	- AddAmbientSounds() creates spatial sounds in mansion rooms
	- AddMonsterSound() attaches roar sound to monster (or custom sound for ghosts)
	- AddButlerSound() attaches footstep sound to butler
	- PlayLobbyMusic() plays lobby background music
	- PlayMansionMusic() plays mansion background music
	- CleanupSounds() removes all ambient sounds on round end

	Usage:
		local AmbientSoundManager = require(ServerScriptService.Modules.AmbientSoundManager)
		AmbientSoundManager:AddAmbientSounds(mansion)  -- On round start
		AmbientSoundManager:AddMonsterSound(monster)   -- When monster spawns
		AmbientSoundManager:AddMonsterSound(ghost, customSoundId)  -- For ghosts with custom sound
		AmbientSoundManager:AddButlerSound(butler)     -- When butler spawns
		AmbientSoundManager:CleanupSounds()            -- On round end
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AmbientSoundManager = {}

-- Track all created sounds for cleanup
local activeSounds = {}
local backgroundMusic = nil

-- Get reference to SoundEvents for client-side music control
local SoundEvents = require(ReplicatedStorage.Remotes.SoundEvents)

-- Roblox library sound IDs for horror ambience
-- Using valid Roblox sound asset IDs
local SOUND_LIBRARY = {
	-- Creaking/wood sounds
	monsterRoar = "rbxassetid://135109687089247",   -- Monster sound
	butlerSteps = "rbxassetid://139116304686326",   -- Butler steps

	-- Wind/ambient
	bumps = "rbxassetid://9113136419",    -- Random bumps and thuds
	breeze = "rbxassetid://2483215757",  -- Wind breeze

	-- Footsteps/movement
	thunderAndRain = "rbxassetid://98719867425764", -- Footsteps

	-- Atmospheric
	ambientInMansion = "rbxassetid://134980593475246",  -- Dark ambient for mansion
	ambientInLobby = "rbxassetid://82579828626004",    -- Music for lobby 
}

--[[
	Loads sound assets into memory (pre-caching).
	Called during initialization to prevent lag during gameplay.
]]
function AmbientSoundManager:LoadSoundAssets()
	-- Note: ContentProvider:PreloadAsync could be used here for pre-caching
	-- For Phase 2, Roblox handles lazy loading automatically
end

--[[
	Adds spatial ambient sounds to mansion rooms.
	- Random bumps in 20% of rooms
	- Thunder/rain sounds at all windows

	@param mansion Model - The mansion model to add sounds to
]]
function AmbientSoundManager:AddAmbientSounds(mansion)
	if not mansion then
		warn("[AmbientSoundManager] No mansion provided for ambient sounds")
		return
	end

	-- Collect all rooms from the mansion
	local allRooms = {}
	for _, child in ipairs(mansion:GetChildren()) do
		-- Match rooms like "Room_L1_X0_Z0" but not "ProceduralMansion" or other models
		if child:IsA("Model") and child.Name:match("^Room_L%d+_X%d+_Z%d+$") then
			table.insert(allRooms, child)
		end
	end

	if #allRooms == 0 then
		warn("[AmbientSoundManager] No rooms found in mansion!")
		return
	end

	-- 1. ADD ONE RANDOM BUMP SOUND (plays at random intervals)
	-- Pick a random room in the middle of the mansion for the bump sound origin
	local middleRoom = allRooms[math.floor(#allRooms / 2)]
	if middleRoom and middleRoom:FindFirstChild("Floor") then
		local bumpSound = Instance.new("Sound")
		bumpSound.Name = "RandomBumps"
		bumpSound.SoundId = SOUND_LIBRARY.bumps
		bumpSound.Volume = 0.4
		bumpSound.Looped = false  -- One-shot sound
		bumpSound.RollOffMode = Enum.RollOffMode.Linear
		bumpSound.RollOffMaxDistance = 100  -- Can be heard from far away
		bumpSound.RollOffMinDistance = 20
		bumpSound.Parent = middleRoom:FindFirstChild("Floor")

		table.insert(activeSounds, bumpSound)

		-- Create random bump player
		local connection = game:GetService("RunService").Heartbeat:Connect(function()
			-- Random chance to play bump (approximately every 10-20 seconds)
			if not bumpSound.IsPlaying and math.random(1, 1000) <= 2 then
				bumpSound:Play()
			end
		end)

		table.insert(activeSounds, connection)
	end

	-- 2. ADD THUNDER/RAIN TO ALL WINDOWS
	for _, room in ipairs(allRooms) do
		-- Find glass parts (windows)
		for _, part in ipairs(room:GetDescendants()) do
			if part:IsA("BasePart") and part.Name:match("Glass$") then
				-- Add thunder/rain sound to this window
				self:CreateSpatialSound(part, SOUND_LIBRARY.thunderAndRain, 0.25)
			end
		end
	end
end

--[[
	Creates a spatial 3D sound instance parented to a part.
	Implements Pattern from RESEARCH.md with Linear rolloff.

	@param part Instance - The part to parent the sound to
	@param soundId string - Roblox asset ID for the sound
	@param volume number - Volume level (0-1)
	@return Sound - The created sound instance
]]
function AmbientSoundManager:CreateSpatialSound(part, soundId, volume)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.3
	sound.Looped = true  -- Ambient sounds loop continuously

	-- Spatial audio settings (Pattern from RESEARCH.md)
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.RollOffMaxDistance = 80  -- Audible within 80 studs
	sound.RollOffMinDistance = 10  -- Full volume within 10 studs

	-- Parent to part for 3D positioning (Pitfall 7: must be parented to part, not workspace)
	sound.Parent = part

	-- Start playing
	sound:Play()

	-- Track for cleanup
	table.insert(activeSounds, sound)

	return sound
end

--[[
	Adds proximity-based roar sound to monster model.
	Roar only plays when a player gets very close (within 12 studs).

	@param monster Model - The monster model
	@param customSoundId string - Optional custom sound ID (for ghosts, etc.)
]]
function AmbientSoundManager:AddMonsterSound(monster, customSoundId)
	if not monster or not monster.PrimaryPart then
		warn("[AmbientSoundManager] Invalid monster model for sound")
		return
	end

	-- Use custom sound ID if provided, otherwise default to monster roar
	local soundId = customSoundId or SOUND_LIBRARY.monsterRoar
	local soundName = customSoundId and "GhostMoan" or "MonsterRoar"

	-- Create sound instance but don't loop it
	local sound = Instance.new("Sound")
	sound.Name = soundName
	sound.SoundId = soundId
	sound.Volume = 0.7  -- Louder for impact
	sound.Looped = false  -- One-shot sound
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.RollOffMaxDistance = 50
	sound.RollOffMinDistance = 10
	sound.Parent = monster.PrimaryPart

	table.insert(activeSounds, sound)

	-- Start proximity monitoring
	local lastRoarTime = 0
	local ROAR_COOLDOWN = 10  -- Seconds between roars
	local ROAR_DISTANCE = 12  -- Studs - trigger when player is this close

	local connection = game:GetService("RunService").Heartbeat:Connect(function()
		if not monster or not monster.Parent or not monster.PrimaryPart then
			return
		end

		local currentTime = os.clock()
		if currentTime - lastRoarTime < ROAR_COOLDOWN then
			return
		end

		-- Check for nearby players
		local monsterPos = monster.PrimaryPart.Position
		local Players = game:GetService("Players")

		for _, player in ipairs(Players:GetPlayers()) do
			if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				local playerPos = player.Character.HumanoidRootPart.Position
				local distance = (monsterPos - playerPos).Magnitude

				if distance <= ROAR_DISTANCE then
					-- Player is very close! Play roar
					sound:Play()
					lastRoarTime = currentTime
					break
				end
			end
		end
	end)

	table.insert(activeSounds, connection)
end

--[[
	Adds proximity-based footstep sound to butler model.
	Sound plays when player is near the butler.

	@param butler Model - The butler model
]]
function AmbientSoundManager:AddButlerSound(butler)
	if not butler or not butler.PrimaryPart then
		warn("[AmbientSoundManager] Invalid butler model for sound")
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = "ButlerSteps"
	sound.SoundId = SOUND_LIBRARY.butlerSteps
	sound.Volume = 0.6  -- Increased volume
	sound.Looped = true
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.RollOffMaxDistance = 70  -- Audible within 70 studs
	sound.RollOffMinDistance = 5  -- Full volume within 5 studs
	sound.Parent = butler.PrimaryPart
	sound:Play()

	table.insert(activeSounds, sound)
end

--[[
	Plays background music for the mansion.
	Triggers client-side music playback for all players.
]]
function AmbientSoundManager:PlayMansionMusic()
	-- Fire to all clients to play mansion music
	SoundEvents.PlayMansionMusic:FireAllClients()
	print("[AmbientSoundManager] Mansion music started (client-side)")
end

--[[
	Plays background music for the lobby.
	Triggers client-side music playback for all players.
]]
function AmbientSoundManager:PlayLobbyMusic()
	-- Fire to all clients to play lobby music
	SoundEvents.PlayLobbyMusic:FireAllClients()
	print("[AmbientSoundManager] Lobby music started (client-side)")
end

--[[
	Cleans up all ambient sounds.
	Called on round end to prevent sounds from persisting.
]]
function AmbientSoundManager:CleanupSounds()
	-- Stop all client-side background music
	SoundEvents.StopAllMusic:FireAllClients()

	-- Stop and destroy all active sounds and connections (server-side spatial sounds)
	for _, item in ipairs(activeSounds) do
		if item then
			-- Check if it's a Sound instance
			if typeof(item) == "Instance" and item:IsA("Sound") then
				pcall(function()
					item:Stop()
					item:Destroy()
				end)
			-- Check if it's a connection (from proximity monitoring)
			-- Connections have a Disconnect method
			elseif typeof(item) == "RBXScriptConnection" or (type(item) == "table" and item.Disconnect) then
				pcall(function()
					item:Disconnect()
				end)
			end
		end
	end

	-- Clear the tracking table
	activeSounds = {}

	print("[AmbientSoundManager] All sounds cleaned up")
end

--[[
	Gets the count of active sounds (for debugging).

	@return number - Number of active ambient sounds
]]
function AmbientSoundManager:GetActiveSoundCount()
	return #activeSounds
end

return AmbientSoundManager
