--[[
	POC Environment Builder
	Creates basic lobby and mansion structure for testing Phase 1

	DISABLED: Phase 2 replaces this with LobbyService and MansionService
--]]

if true then return end -- DISABLED

local Workspace = game:GetService("Workspace")

print("[POC] Building environment...")

-- Clear existing baseplate (from Rojo config)
if Workspace:FindFirstChild("Baseplate") then
	Workspace.Baseplate:Destroy()
end

-- Helper function to create a part
local function createPart(name, size, position, color, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Anchored = true
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = parent or Workspace
	return part
end

---
-- LOBBY AREA
---
local LobbyFolder = Instance.new("Folder")
LobbyFolder.Name = "Lobby"
LobbyFolder.Parent = Workspace

-- Lobby floor (bigger so you don't fall off)
local lobbyFloor = createPart(
	"Floor",
	Vector3.new(100, 2, 100),
	Vector3.new(0, -1, 0),
	Color3.fromRGB(100, 200, 100), -- Green
	LobbyFolder
)

-- Lobby spawn location
local lobbySpawn = Instance.new("SpawnLocation")
lobbySpawn.Name = "LobbySpawn"
lobbySpawn.Size = Vector3.new(6, 1, 6)
lobbySpawn.Position = Vector3.new(0, 1, 0)
lobbySpawn.Color = Color3.fromRGB(50, 150, 50)
lobbySpawn.Anchored = true
lobbySpawn.CanCollide = false
lobbySpawn.Transparency = 0.5
lobbySpawn.Material = Enum.Material.Neon
lobbySpawn.Parent = LobbyFolder

-- "Waiting for players" sign with visible text
local waitingSign = createPart(
	"WaitingSign",
	Vector3.new(20, 10, 1),
	Vector3.new(0, 7, -35),
	Color3.fromRGB(40, 40, 40), -- Dark gray
	LobbyFolder
)

-- Add text to the sign
local surfaceGui = Instance.new("SurfaceGui")
surfaceGui.Face = Enum.NormalId.Front
surfaceGui.Parent = waitingSign

local textLabel = Instance.new("TextLabel")
textLabel.Size = UDim2.new(1, 0, 1, 0)
textLabel.BackgroundTransparency = 1
textLabel.Text = "MANSION ESCAPE\n\nPress PLAY to start\n(Solo test mode)"
textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
textLabel.TextScaled = true
textLabel.Font = Enum.Font.GothamBold
textLabel.Parent = surfaceGui


-- East barrier (with gap for mansion)
createPart(
	"BarrierEast1",
	Vector3.new(barrierThick, barrierHeight, 35),
	Vector3.new(50, barrierHeight/2, -32.5),
	Color3.fromRGB(80, 160, 80),
	LobbyFolder
)

createPart(
	"BarrierEast2",
	Vector3.new(barrierThick, barrierHeight, 35),
	Vector3.new(50, barrierHeight/2, 32.5),
	Color3.fromRGB(80, 160, 80),
	LobbyFolder
)

-- West barrier
createPart(
	"BarrierWest",
	Vector3.new(barrierThick, barrierHeight, 100),
	Vector3.new(-50, barrierHeight/2, 0),
	Color3.fromRGB(80, 160, 80),
	LobbyFolder
)

---
-- BASIC MANSION (far from lobby)
---
local MansionFolder = Instance.new("Folder")
MansionFolder.Name = "Mansion1"
MansionFolder.Parent = Workspace

local mansionOffset = Vector3.new(100, 0, 0) -- Place mansion 100 studs away

-- Mansion floor
local mansionFloor = createPart(
	"Floor",
	Vector3.new(40, 2, 40),
	mansionOffset + Vector3.new(0, -1, 0),
	Color3.fromRGB(60, 60, 80), -- Dark gray-blue
	MansionFolder
)

-- Mansion walls (4 walls forming a square)
local wallHeight = 12
local wallThickness = 1


-- Exit marker (green platform at far end)
local exitMarker = createPart(
	"Exit",
	Vector3.new(8, 1, 8),
	mansionOffset + Vector3.new(-15, 1, 0),
	Color3.fromRGB(50, 255, 50),
	MansionFolder
)
exitMarker.Material = Enum.Material.Neon
exitMarker.CanCollide = false
exitMarker.Transparency = 0.3

-- Add dim lighting for atmosphere
local lighting = game:GetService("Lighting")
lighting.Brightness = 1
lighting.Ambient = Color3.fromRGB(50, 50, 70)
lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 90)
lighting.TimeOfDay = "00:00:00" -- Night time

print("[POC] Environment built successfully!")
print("[POC] - Lobby at (0, 0, 0)")
print("[POC] - Mansion at (100, 0, 0)")
print("[POC] - Walk through the entrance on the east wall")
