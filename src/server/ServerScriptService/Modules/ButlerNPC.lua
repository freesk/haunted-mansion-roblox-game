--[[
	ButlerNPC - Main butler orchestrator

	A clean, simple interface for spawning and managing the butler NPC.
	Uses modular components for pathfinding, movement, and spawning.

	Usage:
		ButlerNPC:SpawnButler(spawnCFrame, exitCFrame, parent, anchored)
		ButlerNPC:Cleanup()
]]

local ButlerConfig = require(script.Parent.Butler.ButlerConfig)
local ButlerSpawner = require(script.Parent.Butler.ButlerSpawner)
local ButlerPathfinding = require(script.Parent.Butler.ButlerPathfinding)
local ButlerMovement = require(script.Parent.Butler.ButlerMovement)
local AmbientSoundManager = require(script.Parent.AmbientSoundManager)

local ButlerNPC = {}

-- Active butler state
local activeButler = nil
local movementCleanup = nil

-- Stored spawn data for delayed navigation
local storedSpawnCFrame = nil
local storedExitCFrame = nil
local storedParentMansion = nil

--[[
	Cleans up the current butler NPC if one exists
]]
function ButlerNPC:Cleanup()
	if movementCleanup then
		movementCleanup()
		movementCleanup = nil
	end

	if activeButler and activeButler.Parent then
		activeButler:Destroy()
	end

	activeButler = nil
	storedSpawnCFrame = nil
	storedExitCFrame = nil
	storedParentMansion = nil
end

--[[
	Spawns a butler NPC

	@param spawnCFrame CFrame - Where to spawn the butler
	@param exitCFrame CFrame - The exit marker location
	@param parent Instance - Parent to attach butler to
	@param anchored boolean - If true, butler stays anchored (for lobby)
	@param startMovement boolean - If false, don't start movement (call StartNavigation later)
	@return boolean - Success status
]]
function ButlerNPC:SpawnButler(spawnCFrame, exitCFrame, parent, anchored, startMovement)
	self:Cleanup()

	-- Default startMovement to true for backward compatibility
	if startMovement == nil then
		startMovement = true
	end

	-- Store spawn data for later use if movement is delayed
	storedSpawnCFrame = spawnCFrame
	storedExitCFrame = exitCFrame
	storedParentMansion = parent

	-- Determine if lobby or mansion
	local isLobby = (parent.Name == "Lobby")
	local useYOffset = isLobby

	-- Load butler model
	local butler, walkTrack = ButlerSpawner:LoadButlerModel(spawnCFrame, useYOffset)
	if not butler then
		warn("[ButlerNPC] Failed to load butler")
		return false
	end

	butler.Parent = parent
	activeButler = butler

	-- Add butler footstep sound (proximity-based)
	AmbientSoundManager:AddButlerSound(butler)

	-- Anchored mode (lobby) - just display, no movement
	if anchored then
		for _, part in ipairs(butler:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
		return true
	end

	-- Lobby mode - simple back and forth movement
	if isLobby then
		self:StartLobbyMovement(butler, spawnCFrame, exitCFrame, useYOffset)
		return true
	end

	-- Mansion mode - only start navigation if requested
	if startMovement then
		self:StartMansionNavigation(butler, spawnCFrame, exitCFrame, parent)
	else
	end

	return true
end

--[[
	Starts simple back-and-forth movement in the lobby
]]
function ButlerNPC:StartLobbyMovement(butler, startCFrame, endCFrame, useYOffset)
	if not butler.PrimaryPart then
		warn("[ButlerNPC] Butler missing primary part")
		return
	end

	-- Apply Y offset if needed
	if useYOffset then
		startCFrame = startCFrame * CFrame.new(0, ButlerConfig.LOBBY_Y_OFFSET, 0)
		endCFrame = endCFrame * CFrame.new(0, ButlerConfig.LOBBY_Y_OFFSET, 0)
	end

	-- Create simple back-and-forth path
	local path = {
		{position = endCFrame.Position, type = "walk"},
		{position = startCFrame.Position, type = "walk"},
	}

	local currentPathIndex = 1

	local function onComplete()
		-- Loop to next target
		currentPathIndex = currentPathIndex + 1
		if currentPathIndex > #path then
			currentPathIndex = 1
		end

		local nextPath = {path[currentPathIndex]}
		task.wait(1) -- Pause at endpoints

		movementCleanup = ButlerMovement:StartMovement(butler, nextPath, onComplete)
	end

	-- Start initial movement
	movementCleanup = ButlerMovement:StartMovement(butler, {path[1]}, onComplete)
end

--[[
	Starts navigation through the mansion to the exit
]]
function ButlerNPC:StartMansionNavigation(butler, spawnCFrame, exitCFrame, mansion)
	if not butler.PrimaryPart then
		warn("[ButlerNPC] Butler missing primary part")
		return
	end


	-- Get mansion base Y coordinate from spawn position
	local mansionBaseY = spawnCFrame.Position.Y

	-- Get mansion and analyze rooms
	local rooms, roomsByName = ButlerPathfinding:GetAllRoomsWithInfo(mansion)

	-- Build path from spawn to exit
	local path = ButlerPathfinding:BuildPathThroughRooms(
		spawnCFrame.Position,
		exitCFrame.Position,
		rooms,
		roomsByName,
		mansionBaseY
	)

	if not path or #path == 0 then
		warn("[ButlerNPC] Failed to build path")
		return
	end


	-- Start movement along path
	movementCleanup = ButlerMovement:StartMovement(butler, path, function()
	end)
end

--[[
	Starts navigation for a spawned butler (call after SpawnButler with startMovement=false)
]]
function ButlerNPC:StartNavigation()
	if not activeButler then
		warn("[ButlerNPC] No active butler to start navigation")
		return false
	end

	if not storedSpawnCFrame or not storedExitCFrame or not storedParentMansion then
		warn("[ButlerNPC] Missing spawn data for navigation")
		return false
	end

	self:StartMansionNavigation(activeButler, storedSpawnCFrame, storedExitCFrame, storedParentMansion)
	return true
end

--[[
	Gets the current butler instance

	@return Model - Butler model or nil
]]
function ButlerNPC:GetButler()
	return activeButler
end

return ButlerNPC
