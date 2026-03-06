--[[
	ProximityService - Manages butler proximity and countdown timers

	Players must stay within range of the butler or face a countdown to death.
	Countdown: 10 seconds when out of range, resets when back in range.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProximityEvents = require(ReplicatedStorage.Remotes.ProximityEvents)
local ButlerNPC = require(script.Parent.Parent.Modules.ButlerNPC)
local DebugService = require(ServerScriptService.Services.DebugService)

local ProximityService = {}

-- Configuration
local MAX_DISTANCE = 10 -- Maximum distance from butler (studs)
local COUNTDOWN_TIME = 10 -- Countdown duration (seconds)
local CHECK_INTERVAL = 0.5 -- How often to check distance (seconds)

-- Player proximity state
local playerStates = {} -- [player] = {countdown = 10, inRange = true}
local running = false

--[[
	Initializes the proximity service
]]
function ProximityService:Init()
	print("[ProximityService] Initialized")
end

--[[
	Starts proximity checking for all players in the round
]]
function ProximityService:StartProximityCheck()
	running = true
	playerStates = {}

	-- Initialize all players
	for _, player in ipairs(Players:GetPlayers()) do
		playerStates[player] = {
			countdown = COUNTDOWN_TIME,
			inRange = true,
			lastUpdate = tick()
		}
	end

	-- Start checking loop
	task.spawn(function()
		while running do
			self:CheckAllPlayers()
			task.wait(CHECK_INTERVAL)
		end
	end)
end

--[[
	Stops proximity checking
]]
function ProximityService:StopProximityCheck()
	running = false
	playerStates = {}

	-- Clear all countdowns on clients
	for _, player in ipairs(Players:GetPlayers()) do
		ProximityEvents.CountdownUpdate:FireClient(player, 0, false)
	end
end

--[[
	Checks all players' distance from butler
]]
function ProximityService:CheckAllPlayers()
	local butler = ButlerNPC:GetButler()
	if not butler or not butler.PrimaryPart then
		warn("[ProximityService] No butler found or butler has no PrimaryPart")
		return
	end

	local butlerPos = butler.PrimaryPart.Position

	local playerCount = 0
	for player, state in pairs(playerStates) do
		playerCount = playerCount + 1
		if player.Parent and player.Character then
			local humanoid = player.Character:FindFirstChild("Humanoid")
			local rootPart = player.Character:FindFirstChild("HumanoidRootPart")

			if humanoid and humanoid.Health > 0 and rootPart then
				local distance = (rootPart.Position - butlerPos).Magnitude
				-- Use infinite range if proximity death debug is disabled
				local maxDistance = DebugService.ProximityDeathEnabled and MAX_DISTANCE or 999999999
				local inRange = distance <= maxDistance

				-- Only process proximity logic if proximity death is enabled
				if DebugService.ProximityDeathEnabled then
					-- Check if range status changed
					if inRange ~= state.inRange then
						state.inRange = inRange

						if not inRange then
							-- Player left range, start countdown
							state.countdown = COUNTDOWN_TIME
						else
							-- Player returned to range, stop countdown
							state.countdown = COUNTDOWN_TIME
							ProximityEvents.CountdownUpdate:FireClient(player, 0, false)
						end
					end

					-- Update countdown if out of range
					if not state.inRange then
						local deltaTime = tick() - state.lastUpdate
						state.countdown = state.countdown - deltaTime

						if state.countdown <= 0 then
							-- Player died from being too far
							self:KillPlayer(player)
						else
							-- Update client countdown
							ProximityEvents.CountdownUpdate:FireClient(player, math.ceil(state.countdown), true)
						end
					end
				else
					-- Proximity death disabled - clear any active countdowns
					if state.inRange == false then
						state.inRange = true
						state.countdown = COUNTDOWN_TIME
						ProximityEvents.CountdownUpdate:FireClient(player, 0, false)
					end
				end

				state.lastUpdate = tick()
			end
		else
			-- Player left or died, clean up
			playerStates[player] = nil
		end
	end

end

--[[
	Kills a player who strayed too far from butler
]]
function ProximityService:KillPlayer(player)
	-- Remove from tracking
	playerStates[player] = nil

	-- Fire death event to client
	ProximityEvents.Death:FireClient(player)

	-- Kill player character
	if player.Character then
		local humanoid = player.Character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end
end

--[[
	Handles player joining mid-round
]]
function ProximityService:OnPlayerJoined(player)
	if running then
		playerStates[player] = {
			countdown = COUNTDOWN_TIME,
			inRange = true,
			lastUpdate = tick()
		}
	end
end

--[[
	Handles player leaving
]]
function ProximityService:OnPlayerLeaving(player)
	playerStates[player] = nil
end

return ProximityService
