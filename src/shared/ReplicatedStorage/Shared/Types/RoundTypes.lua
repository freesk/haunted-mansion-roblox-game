--[[
    RoundTypes

    Type definitions and state enums for the round system.
    Provides TypeScript-like type safety for Luau with exported types.
]]

local RoundTypes = {}

-- Round state enum
-- Defines the lifecycle of a game round
RoundTypes.State = {
    Lobby = "Lobby",           -- Waiting for players in lobby
    Countdown = "Countdown",   -- Countdown to round start (5 seconds)
    Playing = "Playing",       -- Round in progress (mansion gameplay)
    Results = "Results"        -- Round ended, showing results
}

-- Valid state transitions for validation
RoundTypes.StateTransitions = {
    Lobby = {"Countdown"},
    Countdown = {"Playing", "Lobby"}, -- Can cancel if players leave
    Playing = {"Results"},
    Results = {"Lobby"}
}

-- Player status during round
export type PlayerStatus = {
    alive: boolean,
    survivalTime: number,
    joinTime: number
}

-- Round data structure
export type RoundData = {
    state: string,
    timeRemaining: number,
    playerCount: number,
    activePlayers: {[Player]: PlayerStatus}
}

-- Round results structure
export type RoundResults = {
    survivors: number,
    totalPlayers: number,
    duration: number,
    pointsEarned: number
}

return RoundTypes
