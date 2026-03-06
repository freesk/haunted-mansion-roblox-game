--[[
    RoundEvents

    RemoteEvent instances for round system communication.
    Server fires these events to update clients about round state changes.

    Placed in ReplicatedStorage.Remotes for access by both server and client.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundEvents = {}

-- Create RemoteEvent instances
-- StateChanged: Fires when round state transitions (Lobby -> Countdown, etc.)
local StateChanged = Instance.new("RemoteEvent")
StateChanged.Name = "StateChanged"
StateChanged.Parent = ReplicatedStorage.Remotes
RoundEvents.StateChanged = StateChanged

-- CountdownUpdate: Fires each second during countdown (5, 4, 3, 2, 1)
local CountdownUpdate = Instance.new("RemoteEvent")
CountdownUpdate.Name = "CountdownUpdate"
CountdownUpdate.Parent = ReplicatedStorage.Remotes
RoundEvents.CountdownUpdate = CountdownUpdate

-- PlayersUpdate: Fires when player count changes
local PlayersUpdate = Instance.new("RemoteEvent")
PlayersUpdate.Name = "PlayersUpdate"
PlayersUpdate.Parent = ReplicatedStorage.Remotes
RoundEvents.PlayersUpdate = PlayersUpdate

-- RoundResults: Fires at end of round with results data
local RoundResults = Instance.new("RemoteEvent")
RoundResults.Name = "RoundResults"
RoundResults.Parent = ReplicatedStorage.Remotes
RoundEvents.RoundResults = RoundResults

return RoundEvents
