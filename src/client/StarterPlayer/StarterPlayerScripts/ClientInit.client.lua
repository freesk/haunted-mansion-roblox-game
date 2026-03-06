--[[
	Client Initialization Script
	Loads and initializes all client controllers
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local StarterPlayerScripts = script.Parent

-- Require all controllers
local LeaderboardUIController = require(StarterPlayerScripts.Controllers.LeaderboardUIController)

-- Initialize controllers
LeaderboardUIController:Init()
