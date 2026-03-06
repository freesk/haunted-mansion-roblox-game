--[[
	DataService - Handles player data persistence using ProfileService
	Provides session-locked data management with error handling
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ProfileService = require(ReplicatedStorage.Packages.ProfileService)

local DataService = {}
DataService.__index = DataService

-- Profile store configuration
local PROFILE_STORE_NAME = "PlayerData"
local DATA_TEMPLATE = {
	Points = 0,
	Tokens = 0,
	UnlockedMansions = {1} -- Start with mansion 1 unlocked
}

-- Active profiles by player
local Profiles = {}

-- Initialize the profile store
local ProfileStore = nil

function DataService:Init()
	ProfileStore = ProfileService.GetProfileStore(PROFILE_STORE_NAME, DATA_TEMPLATE)
	print("[DataService] Initialized with ProfileService")
end

-- Type checking to prevent data corruption from exploiters
function DataService:_ValidateData(data)
	if type(data) ~= "table" then
		return false
	end

	if type(data.Points) ~= "number" or data.Points < 0 then
		return false
	end

	if type(data.Tokens) ~= "number" or data.Tokens < 0 then
		return false
	end

	if type(data.UnlockedMansions) ~= "table" then
		return false
	end

	-- Validate UnlockedMansions array
	for _, mansionId in ipairs(data.UnlockedMansions) do
		if type(mansionId) ~= "number" or mansionId < 1 then
			return false
		end
	end

	return true
end

-- Load player data with session locking
function DataService:LoadPlayerData(player)
	local userId = tostring(player.UserId)

	-- Prevent double-loading
	if Profiles[player] then
		warn("[DataService] Profile already loaded for " .. player.Name)
		return false
	end

	-- Load profile using ProfileService (session-locked)
	local profile = ProfileStore:LoadProfileAsync(userId, function(sessionLockedBy)
		-- Profile is session-locked by another server
		player:Kick("Your data is being loaded in another server. Please wait and try again.")
	end)

	if not profile then
		warn("[DataService] Failed to load profile for " .. player.Name)

		-- Studio: Create mock profile for testing
		if RunService:IsStudio() then
			warn("[DataService] Creating mock profile for Studio testing")
			local mockProfile = {
				Data = {
					Points = 0,
					Tokens = 0,
					UnlockedMansions = {1}
				},
				-- Mock ProfileService interface
				Release = function()
					-- No-op for mock profiles (no session to release)
				end
			}
			Profiles[player] = mockProfile
			self:CreateLeaderstats(player)
			return true
		else
			-- Production: Kick player to prevent data loss
			player:Kick("Failed to load your data. Please rejoin.")
			return false
		end
	end

	-- Validate loaded data
	if not self:_ValidateData(profile.Data) then
		warn("[DataService] Invalid data detected for " .. player.Name .. ", resetting to template")
		profile.Data = {
			Points = 0,
			Tokens = 0,
			UnlockedMansions = {1}
		}
	end

	-- Handle player leaving while loading
	profile.OnRelease = function()
		Profiles[player] = nil
		player:Kick("Your profile was released")
	end

	-- Check if player still in game
	if not player:IsDescendantOf(Players) then
		profile:Release()
		return false
	end

	-- Store profile
	Profiles[player] = profile
	print("[DataService] Loaded profile for " .. player.Name)

	-- Create leaderstats for built-in Roblox leaderboard
	self:CreateLeaderstats(player)

	return true
end

-- Create leaderstats folder for player
function DataService:CreateLeaderstats(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local pointsValue = Instance.new("IntValue")
	pointsValue.Name = "Points"
	pointsValue.Value = Profiles[player].Data.Points
	pointsValue.Parent = leaderstats

	print("[DataService] Created leaderstats for " .. player.Name)
end

-- Get player profile (safe access)
function DataService:GetProfile(player)
	return Profiles[player]
end

-- Save player data (ProfileService auto-saves with UpdateAsync pattern)
function DataService:SavePlayerData(player)
	local profile = Profiles[player]

	if not profile then
		warn("[DataService] No profile to save for " .. player.Name)
		return false
	end

	-- Validate before saving
	if not self:_ValidateData(profile.Data) then
		warn("[DataService] Invalid data detected, refusing to save for " .. player.Name)
		return false
	end

	-- ProfileService handles auto-saving with UpdateAsync pattern
	-- Manual save happens on release
	print("[DataService] Data will be saved for " .. player.Name)
	return true
end

-- Release player profile (called on disconnect)
function DataService:ReleaseProfile(player)
	local profile = Profiles[player]

	if not profile then
		return
	end

	-- Validate before final save
	if not self:_ValidateData(profile.Data) then
		warn("[DataService] Invalid data detected on release for " .. player.Name)
		-- Still release to prevent session lock, but data won't be saved
	end

	-- Release profile (mock profiles have no-op Release function)
	if profile.Release then
		profile:Release()
	end
	Profiles[player] = nil

	print("[DataService] Released profile for " .. player.Name)
end

-- Update player data safely
function DataService:UpdatePlayerData(player, updateFunction)
	local profile = Profiles[player]

	if not profile then
		warn("[DataService] No profile found for " .. player.Name)
		return false
	end

	-- Use pcall to safely update data
	local success, err = pcall(function()
		updateFunction(profile.Data)
	end)

	if not success then
		warn("[DataService] Error updating data for " .. player.Name .. ": " .. tostring(err))
		return false
	end

	-- Validate after update
	if not self:_ValidateData(profile.Data) then
		warn("[DataService] Data validation failed after update for " .. player.Name)
		return false
	end

	return true
end

-- Update player points (convenience method)
function DataService:UpdatePlayerPoints(player, pointsToAdd)
	if type(pointsToAdd) ~= "number" or pointsToAdd < 0 then
		warn("[DataService] Invalid points value:", pointsToAdd)
		return false
	end

	local success = self:UpdatePlayerData(player, function(data)
		data.Points = data.Points + pointsToAdd
	end)

	if success then
		-- Update leaderstats display
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local pointsValue = leaderstats:FindFirstChild("Points")
			if pointsValue then
				pointsValue.Value = Profiles[player].Data.Points
			end
		end

		print("[DataService] Updated points for " .. player.Name .. " (+" .. pointsToAdd .. " = " .. Profiles[player].Data.Points .. ")")
	end

	return success
end

-- Get player's current points
function DataService:GetPlayerPoints(player)
	local profile = Profiles[player]
	if not profile then
		warn("[DataService] No profile found for " .. player.Name)
		return 0
	end

	return profile.Data.Points
end

-- Get top players sorted by points
function DataService:GetTopPlayers(count)
	count = count or 10

	-- Collect all player data
	local playerData = {}
	for player, profile in pairs(Profiles) do
		table.insert(playerData, {
			player = player,
			name = player.Name,
			points = profile.Data.Points
		})
	end

	-- Sort by points descending
	table.sort(playerData, function(a, b)
		return a.points > b.points
	end)

	-- Return top N
	local topPlayers = {}
	for i = 1, math.min(count, #playerData) do
		table.insert(topPlayers, playerData[i])
	end

	return topPlayers
end

return DataService
