--[[
	Server Initialization Script
	Loads and initializes all services in correct order
--]]

local ServerScriptService = game:GetService("ServerScriptService")
local Lighting = game:GetService("Lighting")

-- Set time of day to night and keep it that way
Lighting.ClockTime = 0
Lighting.TimeOfDay = "00:00:00"

-- Require all services
local DebugService = require(ServerScriptService.Services.DebugService)
local DataService = require(ServerScriptService.Services.DataService)
local PlayerService = require(ServerScriptService.Services.PlayerService)
local GameStateService = require(ServerScriptService.Services.GameStateService)
local SecurityService = require(ServerScriptService.Services.SecurityService)
local MansionService = require(ServerScriptService.Services.MansionService)
local LobbyService = require(ServerScriptService.Services.LobbyService)
local ResultsService = require(ServerScriptService.Services.ResultsService)
local ProximityService = require(ServerScriptService.Services.ProximityService)
local RoundService = require(ServerScriptService.Services.RoundService)

-- Initialize services in dependency order
-- DataService first (no dependencies)
DataService:Init()

-- SecurityService second (validates RemoteEvents, rate limiting)
SecurityService:Init()

-- PlayerService third (depends on DataService)
PlayerService:Init()

-- MansionService fourth (procedural generation system)
MansionService:Init()

-- LobbyService fifth (creates lobby structure, player spawning)
LobbyService:Init()

-- ResultsService sixth (depends on DataService for points persistence)
ResultsService:Init()

-- ProximityService seventh (butler proximity checking)
ProximityService:Init()

-- RoundService eighth (depends on LobbyService, MansionService, ResultsService, ProximityService)
RoundService:Init()

-- GameStateService last (may depend on other services in future)
GameStateService:Init()

-- Start lobby background music
local AmbientSoundManager = require(ServerScriptService.Modules.AmbientSoundManager)
AmbientSoundManager:PlayLobbyMusic()

-- Keep time locked at night (prevent automatic time advancement)
game:GetService("RunService").Heartbeat:Connect(function()
	if Lighting.ClockTime ~= 0 then
		Lighting.ClockTime = 0
	end
end)
