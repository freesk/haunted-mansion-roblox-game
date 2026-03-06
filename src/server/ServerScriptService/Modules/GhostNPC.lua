--[[
	GhostNPC - Main ghost orchestrator

	A clean, simple interface for spawning and managing floating ghost NPCs.
	Uses modular components for spawning and movement.

	Usage:
		GhostNPC:SpawnGhost(spawnCFrame, parent)
		GhostNPC:CleanupAll()
]]

local GhostConfig = require(script.Parent.Ghost.GhostConfig)
local GhostSpawner = require(script.Parent.Ghost.GhostSpawner)
local GhostMovement = require(script.Parent.Ghost.GhostMovement)
local AmbientSoundManager = require(script.Parent.AmbientSoundManager)

local GhostNPC = {}

-- Active ghosts state
local activeGhosts = {} -- {ghost = Model, cleanup = function}

--[[
	Cleans up all ghost NPCs
]]
function GhostNPC:CleanupAll()
	for _, ghostData in ipairs(activeGhosts) do
		if ghostData.cleanup then
			ghostData.cleanup()
		end
		if ghostData.ghost and ghostData.ghost.Parent then
			ghostData.ghost:Destroy()
		end
	end

	activeGhosts = {}
end

--[[
	Spawns a floating ghost NPC

	@param spawnCFrame CFrame - Where to spawn the ghost
	@param parent Instance - Parent to attach ghost to
	@return Model - Ghost model or nil on failure
]]
function GhostNPC:SpawnGhost(spawnCFrame, parent)
	-- Load ghost model
	local ghost = GhostSpawner:LoadGhostModel(spawnCFrame)
	if not ghost then
		return nil
	end

	ghost.Parent = parent

	-- Add kill zone for collision detection (reactive to debug toggle)
	GhostSpawner:AddKillZone(ghost)

	-- Add ghost sound (eerie whispers)
	AmbientSoundManager:AddMonsterSound(ghost, GhostConfig.SOUND_ID)

	-- Start floating behavior (pass parent as mansion for bounds)
	local cleanup = GhostMovement:StartFloating(ghost, parent)

	-- Track active ghost
	table.insert(activeGhosts, {
		ghost = ghost,
		cleanup = cleanup
	})

	return ghost
end

--[[
	Gets all active ghost instances

	@return table - Array of ghost models
]]
function GhostNPC:GetActiveGhosts()
	local ghosts = {}
	for _, ghostData in ipairs(activeGhosts) do
		if ghostData.ghost and ghostData.ghost.Parent then
			table.insert(ghosts, ghostData.ghost)
		end
	end
	return ghosts
end

return GhostNPC
