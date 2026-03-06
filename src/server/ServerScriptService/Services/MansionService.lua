--[[
	MansionService

	Manages mansion lifecycle: generation, cleanup, and spawn/exit locations.
	Implements Pattern 4 from RESEARCH.md: Procedural Generation Cleanup

	Responsibilities:
	- Generate new mansion at round start
	- Clean up previous mansion before generating new one
	- Provide spawn locations for player teleportation
	- Provide exit location for win condition

	Usage:
		local MansionService = require(ServerScriptService.Services.MansionService)
		MansionService:Init()
		MansionService:GenerateNewMansion()
]]

local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local RoomGenerator = require(ServerScriptService.Modules.MansionGenerator)
local AmbientSoundManager = require(ServerScriptService.Modules.AmbientSoundManager)
local FurnitureSpawner = require(ServerScriptService.Modules.FurnitureSpawner)

local MansionService = {}

-- Reference to current mansion for cleanup (Pattern 4)
local currentMansion = nil

-- Mansion spawn location in world (away from lobby)
local MANSION_WORLD_OFFSET = Vector3.new(200, 0, 0)

--[[
	Initializes the MansionService.
	Called by ServerInit.
]]
function MansionService:Init()

	-- Future: Connect to RoundService state changes
	-- On "Playing" state: generate mansion
	-- On "Lobby" state: cleanup mansion
end

--[[
	Generates a new mansion and places it in the world.
	Destroys previous mansion first to prevent memory leaks.

	@return Model - The generated mansion, or nil if generation failed
]]
function MansionService:GenerateNewMansion()

	-- Cleanup previous mansion (Pattern 4: Procedural Generation Cleanup)
	self:CleanupMansion()

	-- Generate new mansion
	local mansion = RoomGenerator:GenerateMansion()

	if not mansion then
		warn("[MansionService] Failed to generate mansion")
		return nil
	end

	-- Position mansion away from lobby
	mansion:PivotTo(CFrame.new(MANSION_WORLD_OFFSET))

	-- Parent to Workspace
	mansion.Parent = Workspace

	-- Store reference for cleanup
	currentMansion = mansion

	-- Add ambient sounds to mansion
	AmbientSoundManager:AddAmbientSounds(mansion)


	return mansion
end

--[[
	Cleans up the current mansion if it exists.
	Implements Pattern 4 from RESEARCH.md to prevent memory leaks.
]]
function MansionService:CleanupMansion()
	if currentMansion then

		-- Destroy all connections and instances (prevents memory leak)
		currentMansion:Destroy()
		currentMansion = nil

	end
end

--[[
	Gets spawn locations from the entrance room.
	Returns array of CFrame positions for player teleportation.

	@return table - Array of CFrame spawn positions
]]
function MansionService:GetSpawnLocations()
	if not currentMansion then
		warn("[MansionService] No mansion exists to get spawn locations")
		return {}
	end

	local spawnLocations = {}

	-- Find any room with a SpawnLocation
	for _, room in ipairs(currentMansion:GetChildren()) do
		for _, child in ipairs(room:GetDescendants()) do
			if child:IsA("SpawnLocation") then
				-- Return CFrame with small Y offset to prevent spawning in floor
				table.insert(spawnLocations, child.CFrame * CFrame.new(0, 3, 0))
			end
		end
	end


	return spawnLocations
end

--[[
	Gets the exit marker location from the exit room.
	Returns CFrame position of the exit for win detection.

	@return CFrame - Exit marker position, or nil if not found
]]
function MansionService:GetExitLocation()
	if not currentMansion then
		warn("[MansionService] No mansion exists to get exit location")
		return nil
	end

	-- Find any ExitMarker in the mansion
	for _, room in ipairs(currentMansion:GetChildren()) do
		local exitMarker = room:FindFirstChild("ExitMarker", true)
		if exitMarker then
			return exitMarker.CFrame
		end
	end

	warn("[MansionService] No exit marker found in mansion")
	return nil
end

--[[
	Gets the current mansion instance.

	@return Model - Current mansion, or nil if none exists
]]
function MansionService:GetCurrentMansion()
	return currentMansion
end

--[[
	Gets valid monster spawn locations distributed evenly across levels.
	Excludes rooms with stairs, exit marker, and player spawn.

	@param monstersPerLevel number - Number of monsters to spawn per level (default 3)
	@return table - Array of {cframe = CFrame, level = number, room = Model}
]]
function MansionService:GetMonsterSpawnLocations(monstersPerLevel)
	if not currentMansion then
		warn("[MansionService] No mansion exists to get monster spawn locations")
		return {}
	end

	monstersPerLevel = monstersPerLevel or 3
	local spawnLocations = {}

	-- Organize rooms by level
	local roomsByLevel = {} -- {[level] = {room1, room2, ...}}
	local excludedRooms = {} -- Rooms to exclude (stairs, exit, player spawn)

	-- First pass: collect all rooms and identify excluded rooms
	for _, room in ipairs(currentMansion:GetChildren()) do
		if room.Name:match("^Room_L%d") then
			local level = tonumber(room.Name:match("Room_L(%d)"))
			if level then
				-- Initialize level array if needed
				if not roomsByLevel[level] then
					roomsByLevel[level] = {}
				end

				-- Check if room should be excluded
				local shouldExclude = false

				-- Exclude if has stairs (check attribute first, then parts)
				if room:GetAttribute("HasStairs") or room:FindFirstChild("CentralPole") or room:FindFirstChild("Step1") then
					shouldExclude = true
				end

				-- Exclude if room has no floor (room above stairs)
				if room:GetAttribute("NoFloor") then
					shouldExclude = true
				end

				-- Exclude if has exit marker
				if room:FindFirstChild("ExitMarker", true) then
					shouldExclude = true
				end

				-- Exclude if has player spawn (check attribute first, then search)
				if room:GetAttribute("HasPlayerSpawn") then
					shouldExclude = true
					print("[MansionService] Excluding spawn room from monster spawns (attribute):", room.Name)
				elseif room:FindFirstChild("PlayerSpawn", true) then
					shouldExclude = true
					print("[MansionService] Excluding spawn room from monster spawns (child):", room.Name)
				end

				if not shouldExclude then
					table.insert(roomsByLevel[level], room)
				else
					excludedRooms[room.Name] = true
				end
			end
		end
	end

	-- Debug output
	print("[MansionService] Monster spawn room distribution:")
	for level, rooms in pairs(roomsByLevel) do
		print(string.format("[MansionService]   Level %d: %d eligible rooms", level, #rooms))
	end

	-- Second pass: distribute monsters evenly across each level
	for level, rooms in pairs(roomsByLevel) do
		if #rooms > 0 then
			-- Calculate how many monsters to actually spawn (min of available rooms and target)
			local actualMonsterCount = math.min(monstersPerLevel, #rooms)

			-- Divide rooms into segments and pick from middle of each segment for even distribution
			local segmentSize = #rooms / actualMonsterCount

			for segmentIndex = 0, actualMonsterCount - 1 do
				-- Pick middle room from this segment
				local roomIndex = math.floor(segmentIndex * segmentSize + segmentSize / 2) + 1
				roomIndex = math.min(roomIndex, #rooms) -- Safety clamp

				local room = rooms[roomIndex]
				local roomPivot = room:GetPivot()

				-- Random offset within room (but not at exact center)
				local randomX = (math.random() - 0.5) * 4
				local randomZ = (math.random() - 0.5) * 4

				-- Use same Y logic as player spawn: room pivot + floor offset + spawn offset
				local spawnCFrame = roomPivot * CFrame.new(randomX, 3.5, randomZ)

				table.insert(spawnLocations, {
					cframe = spawnCFrame,
					level = level,
					room = room
				})
			end
		end
	end


	return spawnLocations
end

--[[
	Spawns furniture throughout the mansion.
	Should be called after butler path is calculated.

	@param butlerPath table - Array of waypoints from butler navigation
]]
function MansionService:SpawnFurniture(butlerPath)
	if not currentMansion then
		warn("[MansionService] No mansion exists to spawn furniture")
		return
	end


	-- Get all rooms
	local rooms = {}
	for _, child in ipairs(currentMansion:GetChildren()) do
		if child.Name:match("^Room_L%d") then
			table.insert(rooms, child)
		end
	end

	-- Spawn furniture
	FurnitureSpawner:SpawnAllFurniture(currentMansion, rooms, butlerPath)

end

return MansionService
