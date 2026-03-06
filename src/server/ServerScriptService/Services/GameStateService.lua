--[[
	GameStateService - Manages game state and round flow
	Placeholder for Phase 2 round management
--]]

local GameStateService = {}
GameStateService.__index = GameStateService

-- Game state enumeration
local GameState = {
	LOBBY = "LOBBY",
	PLAYING = "PLAYING",
	ENDED = "ENDED"
}

-- Current game state
local CurrentState = GameState.LOBBY

function GameStateService:Init()
	-- Initialize in LOBBY state
	CurrentState = GameState.LOBBY

	print("[GameStateService] Initialized - State: " .. CurrentState)

	-- Phase 2 will add round management here
end

-- Get current game state
function GameStateService:GetState()
	return CurrentState
end

-- Set game state (for future round management)
function GameStateService:SetState(newState)
	if not GameState[newState] then
		warn("[GameStateService] Invalid state: " .. tostring(newState))
		return false
	end

	local oldState = CurrentState
	CurrentState = newState

	print("[GameStateService] State changed: " .. oldState .. " -> " .. newState)

	return true
end

-- Check if in lobby
function GameStateService:IsLobby()
	return CurrentState == GameState.LOBBY
end

-- Check if game is playing
function GameStateService:IsPlaying()
	return CurrentState == GameState.PLAYING
end

-- Check if game has ended
function GameStateService:IsEnded()
	return CurrentState == GameState.ENDED
end

-- Export game state enum
GameStateService.State = GameState

return GameStateService
