--[[
	PlayerService - Manages player lifecycle (join/leave)
	Handles data loading and leaderstats creation
--]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ServerScriptService.Services.DataService)

local PlayerService = {}
PlayerService.__index = PlayerService

-- Reference to other services (set during Init)
local LobbyService = nil

function PlayerService:Init()
	-- Get service references
	LobbyService = require(ServerScriptService.Services.LobbyService)
	-- Connect to player join event
	Players.PlayerAdded:Connect(function(player)
		self:_OnPlayerJoin(player)
	end)

	-- Connect to player leave event
	Players.PlayerRemoving:Connect(function(player)
		self:_OnPlayerLeave(player)
	end)

	print("[PlayerService] Initialized - listening for player events")
end

-- Handle player join
function PlayerService:_OnPlayerJoin(player)
	print("[PlayerService] Player joining: " .. player.Name)

	-- Load player data
	local success = DataService:LoadPlayerData(player)

	if not success then
		warn("[PlayerService] Failed to load data for " .. player.Name)
		warn("[PlayerService] Allowing player in mock mode (development)")
		-- Don't kick in Studio - ProfileService will use mock mode
		-- player:Kick("Failed to load your data. Please try again.")
		-- return
	end

	-- Update lobby scoreboard
	if LobbyService then
		LobbyService:RefreshScoreboard()
	end
end

-- Handle player leave
function PlayerService:_OnPlayerLeave(player)
	-- Save and release profile
	DataService:SavePlayerData(player)
	DataService:ReleaseProfile(player)

	-- Update lobby scoreboard
	task.wait(0.1) -- Small delay to ensure profile is released
	if LobbyService then
		LobbyService:RefreshScoreboard()
	end
end

-- Get player points (convenience method)
function PlayerService:GetPlayerPoints(player)
	local profile = DataService:GetProfile(player)

	if not profile then
		return 0
	end

	return profile.Data.Points
end

-- Add points to player (convenience method)
function PlayerService:AddPlayerPoints(player, amount)
	if type(amount) ~= "number" or amount <= 0 then
		warn("[PlayerService] Invalid amount: " .. tostring(amount))
		return false
	end

	local success = DataService:UpdatePlayerData(player, function(data)
		data.Points = data.Points + amount
	end)

	if success then
		-- Update leaderstats display
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local pointsValue = leaderstats:FindFirstChild("Points")
			if pointsValue then
				pointsValue.Value = pointsValue.Value + amount
			end
		end
	end

	return success
end

-- Teleport a single player to a specific location
-- Implements Pattern 3 from RESEARCH.md: Character:PivotTo()
function PlayerService:TeleportPlayer(player, targetCFrame)
	local character = player.Character

	-- Wait for character to load if it doesn't exist yet
	if not character then
		print("[PlayerService] Waiting for character to load for", player.Name)

		local startTime = tick()
		local timeout = 10  -- 10 second timeout

		-- Wait with timeout
		local connection
		connection = player.CharacterAdded:Connect(function(char)
			character = char
			if connection then
				connection:Disconnect()
			end
		end)

		-- Wait for character or timeout
		while not character and player.Parent and (tick() - startTime) < timeout do
			task.wait(0.1)
		end

		if connection then
			connection:Disconnect()
		end

		if not character then
			warn("[PlayerService] Character load timeout for " .. player.Name)
			return false
		end
	end

	-- Wait for HumanoidRootPart to ensure character is fully loaded
	local hrp = character:WaitForChild("HumanoidRootPart", 5)
	if not hrp then
		warn("[PlayerService] HumanoidRootPart not found for", player.Name)
		return false
	end

	-- Wait for Humanoid (needed for production network replication)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then
		warn("[PlayerService] Humanoid not found for", player.Name)
		return false
	end

	-- CRITICAL FIX: Anchor IMMEDIATELY to stop all physics momentum
	-- This must happen BEFORE any velocity checks or waits
	hrp.Anchored = true

	-- CRITICAL FIX: Reset Humanoid state to prevent carrying over jump/fall states
	-- Without this, player continues jumping/falling after teleport
	if humanoid.GetState then
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		task.wait(0.05)  -- Brief wait for state change to register
	end

	-- Reset ALL velocity and rotation (do this while anchored for stability)
	hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	hrp.CFrame = hrp.CFrame -- Reset any rotation momentum

	-- CRITICAL: Extended wait for physics to fully settle
	-- Increased from 0.1 to 0.2 for players jumping before teleport
	task.wait(0.2)

	-- Increased Y offset to 6 studs for extra safety (was 5)
	local teleportCFrame = targetCFrame * CFrame.new(0, 6, 0)

	-- Use PivotTo (replaces deprecated SetPrimaryPartCFrame)
	character:PivotTo(teleportCFrame)

	-- CRITICAL FIX: Wait multiple frames for teleport to fully replicate
	-- Network replication delay can cause floor to not exist on client yet
	-- Increased from 1 frame to 3 frames (0.15s at 60fps)
	task.wait(0.15)

	-- Reset velocity AGAIN after teleport (safety measure)
	hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

	-- CRITICAL FIX: Set Humanoid to GettingUp state before unanchoring
	-- This ensures character properly "lands" on the floor
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	task.wait(0.05)

	-- Unanchor to allow movement
	hrp.Anchored = false

	print("[PlayerService] Teleported", player.Name, "to", targetCFrame.Position)
	return true
end

-- Teleport all players to mansion entrance using spawn locations
-- Uses round-robin spawn point selection for distribution
function PlayerService:TeleportAllToMansion(players, spawnLocations)
	if not players or #players == 0 then
		warn("[PlayerService] No players to teleport")
		return
	end

	if not spawnLocations or #spawnLocations == 0 then
		warn("[PlayerService] No spawn locations provided")
		return
	end

	print("[PlayerService] Teleporting", #players, "players to mansion...")

	-- CRITICAL: Spatial offsets to prevent player collision (production fix)
	-- Players spawning at exact same position push each other through floor/ceiling
	-- Create a grid pattern around spawn point to spread players out
	local spatialOffsets = {
		Vector3.new(0, 0, 0),      -- Center (first player)
		Vector3.new(3, 0, 0),      -- Right
		Vector3.new(-3, 0, 0),     -- Left
		Vector3.new(0, 0, 3),      -- Forward
		Vector3.new(0, 0, -3),     -- Back
		Vector3.new(3, 0, 3),      -- Diagonal: Right-Forward
		Vector3.new(-3, 0, 3),     -- Diagonal: Left-Forward
		Vector3.new(3, 0, -3),     -- Diagonal: Right-Back
		Vector3.new(-3, 0, -3),    -- Diagonal: Left-Back
		Vector3.new(5, 0, 0),      -- Far right
		Vector3.new(-5, 0, 0),     -- Far left
		Vector3.new(0, 0, 5),      -- Far forward
		Vector3.new(0, 0, -5),     -- Far back
	}

	-- Round-robin spawn selection with spatial offsets
	for i, player in ipairs(players) do
		local spawnIndex = ((i - 1) % #spawnLocations) + 1
		local baseSpawnCFrame = spawnLocations[spawnIndex]

		-- Add spatial offset to prevent collision (cycle through offsets)
		local offsetIndex = ((i - 1) % #spatialOffsets) + 1
		local offset = spatialOffsets[offsetIndex]
		local offsetSpawnCFrame = baseSpawnCFrame * CFrame.new(offset)

		self:TeleportPlayer(player, offsetSpawnCFrame)

		-- CRITICAL: Small delay between each player teleport (production fix)
		-- Prevents physics interference when multiple players teleport simultaneously
		-- Without this, concurrent teleports can cause one player to fall through floor
		if i < #players then  -- Don't wait after last player
			task.wait(0.1)
		end
	end

	print("[PlayerService] All players teleported to mansion")
end

-- Teleport all players back to lobby
-- Called by RoundService via LobbyService
function PlayerService:TeleportAllToLobby(players)
	local LobbyService = require(ServerScriptService.Services.LobbyService)
	local lobbySpawn = LobbyService:GetLobbySpawnCFrame()

	if not lobbySpawn then
		warn("[PlayerService] No lobby spawn location")
		return
	end

	print("[PlayerService] Teleporting", #players, "players to lobby...")

	-- CRITICAL: Spatial offsets to prevent player collision (production fix)
	-- Same grid pattern as mansion spawns
	local spatialOffsets = {
		Vector3.new(0, 0, 0),      -- Center (first player)
		Vector3.new(3, 0, 0),      -- Right
		Vector3.new(-3, 0, 0),     -- Left
		Vector3.new(0, 0, 3),      -- Forward
		Vector3.new(0, 0, -3),     -- Back
		Vector3.new(3, 0, 3),      -- Diagonal: Right-Forward
		Vector3.new(-3, 0, 3),     -- Diagonal: Left-Forward
		Vector3.new(3, 0, -3),     -- Diagonal: Right-Back
		Vector3.new(-3, 0, -3),    -- Diagonal: Left-Back
		Vector3.new(5, 0, 0),      -- Far right
		Vector3.new(-5, 0, 0),     -- Far left
		Vector3.new(0, 0, 5),      -- Far forward
		Vector3.new(0, 0, -5),     -- Far back
	}

	for i, player in ipairs(players) do
		-- Add spatial offset to prevent collision (cycle through offsets)
		local offsetIndex = ((i - 1) % #spatialOffsets) + 1
		local offset = spatialOffsets[offsetIndex]
		local offsetSpawnCFrame = lobbySpawn * CFrame.new(offset)

		self:TeleportPlayer(player, offsetSpawnCFrame)

		-- CRITICAL: Small delay between each player teleport (production fix)
		-- Prevents physics interference when multiple players teleport simultaneously
		if i < #players then  -- Don't wait after last player
			task.wait(0.1)
		end
	end

	print("[PlayerService] All players teleported to lobby")
end

return PlayerService
