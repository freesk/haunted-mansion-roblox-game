--[[
	DebugService - Server-side debug state management

	Handles debug toggles from client UI and provides state to other services.
	SECURITY: Debug commands only work in Studio, not in production.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DebugService = {}

-- Check if running in Studio (for security)
local IS_STUDIO = RunService:IsStudio()

if IS_STUDIO then
	print("[DebugService] Running in STUDIO - Debug features enabled")
else
	print("[DebugService] Running in PRODUCTION - Debug features disabled")
end

-- Debug state (only functional in Studio)
DebugService.ProximityDeathEnabled = true
DebugService.MonsterDeathEnabled = true
DebugService.ShowKillZones = false

-- Helper function to check if debug mode is available
function DebugService.IsDebugMode()
	return IS_STUDIO
end

-- Create or get RemoteEvent for client communication
local debugRemote = ReplicatedStorage:FindFirstChild("DebugToggle")
if not debugRemote then
	debugRemote = Instance.new("RemoteEvent")
	debugRemote.Name = "DebugToggle"
	debugRemote.Parent = ReplicatedStorage
end

-- Handle toggle requests from client
debugRemote.OnServerEvent:Connect(function(player, toggleType, enabled)
	-- SECURITY: Only allow debug commands in Studio
	if not IS_STUDIO then
		warn(string.format("[DebugService] SECURITY: Player %s attempted to use debug commands in production", player.Name))
		return
	end

	if toggleType == "ProximityDeath" then
		DebugService.ProximityDeathEnabled = enabled
		print(string.format("[DebugService] Proximity Death: %s", enabled and "ON" or "OFF"))
	elseif toggleType == "MonsterDeath" then
		DebugService.MonsterDeathEnabled = enabled
		print(string.format("[DebugService] Monster Death: %s", enabled and "ON" or "OFF"))
	elseif toggleType == "ShowKillZones" then
		DebugService.ShowKillZones = enabled
		print(string.format("[DebugService] Show Kill Zones: %s", enabled and "ON" or "OFF"))

		-- Update all existing kill zones
		for _, npc in ipairs(game.Workspace:GetDescendants()) do
			if npc.Name == "GhostNPC" or npc.Name == "MonsterNPC" then
				local killZone = npc:FindFirstChild("KillZone")
				if killZone and killZone:IsA("BasePart") then
					killZone.Transparency = enabled and 0.7 or 1
				end
			end
		end
	end
end)

return DebugService
