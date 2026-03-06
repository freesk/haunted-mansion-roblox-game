--[[
    RoundUIController - Client-side UI for round state display

    Displays round state, countdown timer, and player count to the player.
    Listens to RemoteEvents from server and updates UI accordingly.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundEvents = require(ReplicatedStorage.Remotes.RoundEvents)
local RoundTypes = require(ReplicatedStorage.Shared.Types.RoundTypes)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local RoundUIController = {}

-- UI references
local screenGui = nil
local stateLabel = nil
local countdownLabel = nil
local playerCountLabel = nil

-- Current state tracking
local currentState = RoundTypes.State.Lobby
local countdownTime = 0
local playerCount = 0
local minPlayers = GameConfig.MIN_PLAYERS_TO_START

function RoundUIController:Init()
    -- UI disabled - all status messages shown on physical lobby screen only
end

return RoundUIController
