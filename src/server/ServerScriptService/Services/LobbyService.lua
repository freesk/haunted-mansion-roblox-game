--[[
    LobbyService - Lobby management and player spawning

    Manages lobby area, player spawning, and teleportation between lobby and mansion.
    Creates the lobby structure and handles player tracking.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local RoundTypes = require(ReplicatedStorage.Shared.Types.RoundTypes)
local RoundEvents = require(ReplicatedStorage.Remotes.RoundEvents)

local LobbyService = {}
LobbyService.__index = LobbyService

-- Lobby structure references
local lobbySpawn = nil
local lobbyModel = nil
local readyZone = nil

-- Player tracking
local playersInLobby = {}
local playersInReadyZone = {} -- Players who stepped into the ready zone

-- Reference to DataService (set during Init)
local DataService = nil

-- Reference to SoundEvents for per-player music control
local SoundEvents = nil

function LobbyService:Init()

    -- Get reference to DataService
    DataService = require(ServerScriptService.Services.DataService)

    -- Get reference to SoundEvents
    SoundEvents = require(ReplicatedStorage.Remotes.SoundEvents)

    -- Create lobby structure
    self:CreateLobbyStructure()

    -- Connect to player events
    Players.PlayerAdded:Connect(function(player)
        self:OnPlayerAdded(player)
        -- Wait for data to load, then update scoreboard
        task.wait(1)
        self:RefreshScoreboard()
    end)

    Players.PlayerRemoving:Connect(function(player)
        playersInLobby[player] = nil
        playersInReadyZone[player] = nil
        -- Update scoreboard when player leaves
        self:RefreshScoreboard()
    end)

    -- Initial scoreboard update
    task.delay(2, function()
        self:RefreshScoreboard()
    end)

end

-- Helper function to add texture to a wall
local function AddWallTexture(wall, face)
    local texture = Instance.new("Texture")
    texture.Texture = "rbxassetid://8546348110"
    texture.StudsPerTileU = 4
    texture.StudsPerTileV = 4
    texture.Face = face
    texture.Parent = wall
end

-- Helper function to create lobby walls
local function CreateLobbyWalls(lobbyModel, lobbySize, wallHeight)
    local WALL_THICKNESS = 1
    local halfSize = lobbySize / 2
    local wallColor = Color3.fromRGB(80, 70, 90) -- Dark purple-grey

    -- North Wall
    local northWall = Instance.new("Part")
    northWall.Name = "WallNorth"
    northWall.Size = Vector3.new(lobbySize, wallHeight, WALL_THICKNESS)
    northWall.Position = Vector3.new(0, wallHeight/2 + 2, -halfSize)
    northWall.Color = wallColor
    northWall.Material = Enum.Material.Brick
    northWall.Anchored = true
    northWall.Parent = lobbyModel
    AddWallTexture(northWall, Enum.NormalId.Back) -- Interior face

    -- South Wall
    local southWall = Instance.new("Part")
    southWall.Name = "WallSouth"
    southWall.Size = Vector3.new(lobbySize, wallHeight, WALL_THICKNESS)
    southWall.Position = Vector3.new(0, wallHeight/2 + 2, halfSize)
    southWall.Color = wallColor
    southWall.Material = Enum.Material.Brick
    southWall.Anchored = true
    southWall.Parent = lobbyModel
    AddWallTexture(southWall, Enum.NormalId.Front) -- Interior face

    -- East Wall
    local eastWall = Instance.new("Part")
    eastWall.Name = "WallEast"
    eastWall.Size = Vector3.new(WALL_THICKNESS, wallHeight, lobbySize)
    eastWall.Position = Vector3.new(halfSize, wallHeight/2 + 2, 0)
    eastWall.Color = wallColor
    eastWall.Material = Enum.Material.Brick
    eastWall.Anchored = true
    eastWall.Parent = lobbyModel
    AddWallTexture(eastWall, Enum.NormalId.Left) -- Interior face

    -- West Wall
    local westWall = Instance.new("Part")
    westWall.Name = "WallWest"
    westWall.Size = Vector3.new(WALL_THICKNESS, wallHeight, lobbySize)
    westWall.Position = Vector3.new(-halfSize, wallHeight/2 + 2, 0)
    westWall.Color = wallColor
    westWall.Material = Enum.Material.Brick
    westWall.Anchored = true
    westWall.Parent = lobbyModel
    AddWallTexture(westWall, Enum.NormalId.Right) -- Interior face
end

-- Helper function to create lobby ceiling
local function CreateLobbyCeiling(lobbyModel, lobbySize, wallHeight)
    local ceiling = Instance.new("Part")
    ceiling.Name = "Ceiling"
    ceiling.Size = Vector3.new(lobbySize, 0.5, lobbySize)
    ceiling.Position = Vector3.new(0, wallHeight + 2 - 0.25, 0)
    ceiling.Color = Color3.fromRGB(40, 40, 50) -- Dark grey
    ceiling.Material = Enum.Material.Slate
    ceiling.Anchored = true
    ceiling.Parent = lobbyModel

    -- Add ambient lighting to ceiling
    local ceilingLight = Instance.new("PointLight")
    ceilingLight.Name = "LobbyLight"
    ceilingLight.Color = Color3.fromRGB(255, 240, 220) -- Warm white
    ceilingLight.Brightness = 2
    ceilingLight.Range = 40
    ceilingLight.Shadows = true
    ceilingLight.Parent = ceiling
end

-- Create the lobby structure
function LobbyService:CreateLobbyStructure()

    -- Create lobby model container
    lobbyModel = Instance.new("Model")
    lobbyModel.Name = "Lobby"
    lobbyModel.Parent = Workspace

    local LOBBY_SIZE = 50
    local WALL_HEIGHT = 16

    -- Create lobby platform (50x2x50 studs) at ground level (Y = 0)
    local platform = Instance.new("Part")
    platform.Name = "LobbyPlatform"
    platform.Size = Vector3.new(LOBBY_SIZE, 2, LOBBY_SIZE)
    platform.Position = Vector3.new(0, 1, 0) -- Y = 1 so bottom is at Y = 0
    platform.Anchored = true
    platform.CanCollide = true -- Ensure players can stand on it
    platform.Material = Enum.Material.WoodPlanks
    platform.Color = Color3.fromRGB(120, 90, 60) -- Brown wood
    platform.Parent = lobbyModel

    -- Create walls around lobby
    CreateLobbyWalls(lobbyModel, LOBBY_SIZE, WALL_HEIGHT)

    -- Create ceiling
    CreateLobbyCeiling(lobbyModel, LOBBY_SIZE, WALL_HEIGHT)

    -- Create spawn location on top of platform
    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "LobbySpawn"
    spawn.Size = Vector3.new(6, 1, 6)
    spawn.Position = Vector3.new(0, 2.5, 0) -- On top of platform (platform top = 2)
    spawn.Anchored = true
    spawn.Transparency = 1.0 -- Fully transparent
    spawn.CanCollide = false
    spawn.Duration = 0 -- No forced respawn delay
    spawn.Parent = lobbyModel

    lobbySpawn = spawn

    -- Create ready zone (glowing rectangle on floor near status screen)
    local READY_ZONE_WIDTH = 30
    local READY_ZONE_DEPTH = 8
    local READY_ZONE_HEIGHT = 0.5
    local READY_ZONE_X = 0
    local READY_ZONE_Z = -15

    -- Visual indicator (green glowing plane on floor)
    local readyZonePart = Instance.new("Part")
    readyZonePart.Name = "ReadyZone"
    readyZonePart.Size = Vector3.new(READY_ZONE_WIDTH, READY_ZONE_HEIGHT, READY_ZONE_DEPTH)
    readyZonePart.Position = Vector3.new(READY_ZONE_X, 2.25, READY_ZONE_Z) -- Near status screen (north wall at -25)
    readyZonePart.Anchored = true
    readyZonePart.CanCollide = false
    readyZonePart.Material = Enum.Material.Neon
    readyZonePart.Color = Color3.fromRGB(100, 255, 100) -- Green glow
    readyZonePart.Transparency = 0.5 -- Semi-transparent
    readyZonePart.Parent = lobbyModel

    -- Detection zone (invisible, full height of lobby)
    local detectionZone = Instance.new("Part")
    detectionZone.Name = "ReadyZoneDetection"
    detectionZone.Size = Vector3.new(READY_ZONE_WIDTH, WALL_HEIGHT, READY_ZONE_DEPTH)
    detectionZone.Position = Vector3.new(READY_ZONE_X, WALL_HEIGHT/2 + 2, READY_ZONE_Z) -- Centered vertically in lobby
    detectionZone.Anchored = true
    detectionZone.CanCollide = false
    detectionZone.Transparency = 1 -- Fully invisible
    detectionZone.Parent = lobbyModel

    readyZone = detectionZone -- Use detection zone for touch events

    -- Add subtle pulsing glow effect
    local readyLight = Instance.new("PointLight")
    readyLight.Name = "ReadyGlow"
    readyLight.Color = Color3.fromRGB(100, 255, 100)
    readyLight.Brightness = 3
    readyLight.Range = 15
    readyLight.Shadows = false
    readyLight.Parent = readyZonePart

    -- Add text label above ready zone
    local readyTextPart = Instance.new("Part")
    readyTextPart.Name = "ReadyZoneText"
    readyTextPart.Size = Vector3.new(20, 4, 0.1)
    readyTextPart.Position = Vector3.new(0, 8, -15) -- Above ready zone
    readyTextPart.Anchored = true
    readyTextPart.CanCollide = false
    readyTextPart.Transparency = 1
    readyTextPart.Parent = lobbyModel

    local readyTextGui = Instance.new("SurfaceGui")
    readyTextGui.Name = "ReadyTextGui"
    readyTextGui.Face = Enum.NormalId.Front
    readyTextGui.AlwaysOnTop = true
    readyTextGui.LightInfluence = 0
    readyTextGui.Parent = readyTextPart

    local readyTextLabel = Instance.new("TextLabel")
    readyTextLabel.Name = "ReadyText"
    readyTextLabel.Size = UDim2.new(1, 0, 1, 0)
    readyTextLabel.BackgroundTransparency = 1
    readyTextLabel.Text = "READY ZONE\nStep here to join the next round!"
    readyTextLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    readyTextLabel.TextSize = 48
    readyTextLabel.Font = Enum.Font.GothamBold
    readyTextLabel.TextStrokeTransparency = 0.5
    readyTextLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    readyTextLabel.Parent = readyTextGui

    -- Add back-facing text gui (visible from south)
    local readyTextGuiBack = Instance.new("SurfaceGui")
    readyTextGuiBack.Name = "ReadyTextGuiBack"
    readyTextGuiBack.Face = Enum.NormalId.Back
    readyTextGuiBack.AlwaysOnTop = true
    readyTextGuiBack.LightInfluence = 0
    readyTextGuiBack.Parent = readyTextPart

    local readyTextLabelBack = readyTextLabel:Clone()
    readyTextLabelBack.Parent = readyTextGuiBack

    -- Set up touch detection for ready zone (using invisible detection zone)
    detectionZone.Touched:Connect(function(hit)
        if not hit or not hit.Parent then return end

        -- Check if hit a player character
        local character = hit.Parent
        local humanoid = character:FindFirstChild("Humanoid")
        local player = Players:GetPlayerFromCharacter(character)

        if player and humanoid and humanoid.Health > 0 then
            -- Player entered ready zone
            if not playersInReadyZone[player] then
                playersInReadyZone[player] = true
                print("[LobbyService] Player", player.Name, "entered ready zone")

                -- Visual feedback: send event to client (future feature)
                -- RoundEvents.PlayerReady:FireClient(player, true)
            end
        end
    end)

    detectionZone.TouchEnded:Connect(function(hit)
        if not hit or not hit.Parent then return end

        -- Check if hit a player character
        local character = hit.Parent
        local player = Players:GetPlayerFromCharacter(character)

        if player then
            -- Player left ready zone
            if playersInReadyZone[player] then
                playersInReadyZone[player] = nil
                print("[LobbyService] Player", player.Name, "left ready zone")

                -- Visual feedback: send event to client (future feature)
                -- RoundEvents.PlayerReady:FireClient(player, false)
            end
        end
    end)

    local SCREEN_WIDTH = 30
    local SCREEN_HEIGHT = 16
    local SCREEN_Y = 10

    -- Helper function to create a screen part with proper orientation
    local function CreateScreen(name, position, lookDirection)
        local part = Instance.new("Part")
        part.Name = name
        part.Size = Vector3.new(SCREEN_WIDTH, SCREEN_HEIGHT, 0.5)
        part.Anchored = true
        part.CanCollide = false
        part.Material = Enum.Material.Neon
        part.Color = Color3.fromRGB(50, 50, 60)
        part.Transparency = 0

        -- Orient the part to look in the specified direction
        if lookDirection == "South" then
            -- North wall looking south: use CFrame.lookAt equivalent
            part.CFrame = CFrame.new(position, position + Vector3.new(0, 0, 1))
        elseif lookDirection == "North" then
            -- South wall looking north: use CFrame.lookAt equivalent
            part.CFrame = CFrame.new(position, position + Vector3.new(0, 0, -1))
        end

        part.Parent = lobbyModel
        return part
    end

    -- Create status sign on north wall (-Z) looking south (+Z into lobby)
    local signPart = CreateScreen("StatusSign", Vector3.new(0, SCREEN_Y, -24.5), "South")

    local surfaceGui = Instance.new("SurfaceGui")
    surfaceGui.Name = "StatusGui"
    surfaceGui.Face = Enum.NormalId.Front  -- Front always faces the look direction
    surfaceGui.AlwaysOnTop = false
    surfaceGui.LightInfluence = 0
    surfaceGui.PixelsPerStud = 100
    surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    surfaceGui.Parent = signPart

    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "StatusText"
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.Position = UDim2.new(0, 0, 0, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = "MANSION ESCAPE\n\nStep into the green zone to ready up!"
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextSize = 72
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextWrapped = true
    textLabel.TextYAlignment = Enum.TextYAlignment.Center
    textLabel.TextXAlignment = Enum.TextXAlignment.Center
    textLabel.TextScaled = false
    textLabel.Parent = surfaceGui

    -- Create scoreboard on south wall (+Z) looking north (-Z into lobby)
    local scorePart = CreateScreen("ScoreboardSign", Vector3.new(0, SCREEN_Y, 24), "North")

    local scoreGui = Instance.new("SurfaceGui")
    scoreGui.Name = "ScoreGui"
    scoreGui.Face = Enum.NormalId.Front  -- Front always faces the look direction
    scoreGui.AlwaysOnTop = false
    scoreGui.LightInfluence = 0
    scoreGui.PixelsPerStud = 100
    scoreGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    scoreGui.Parent = scorePart

    local scoreTitle = Instance.new("TextLabel")
    scoreTitle.Name = "ScoreTitle"
    scoreTitle.Size = UDim2.new(1, 0, 0.15, 0)
    scoreTitle.Position = UDim2.new(0, 0, 0, 0)
    scoreTitle.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    scoreTitle.BackgroundTransparency = 0
    scoreTitle.BorderSizePixel = 0
    scoreTitle.Text = "LEADERBOARD"
    scoreTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
    scoreTitle.TextSize = 120
    scoreTitle.Font = Enum.Font.GothamBold
    scoreTitle.TextYAlignment = Enum.TextYAlignment.Center
    scoreTitle.TextXAlignment = Enum.TextXAlignment.Center
    scoreTitle.Parent = scoreGui

    local scoreList = Instance.new("ScrollingFrame")
    scoreList.Name = "ScoreList"
    scoreList.Size = UDim2.new(1, 0, 0.85, 0)
    scoreList.Position = UDim2.new(0, 0, 0.15, 0)
    scoreList.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    scoreList.BackgroundTransparency = 0
    scoreList.BorderSizePixel = 0
    scoreList.ScrollBarThickness = 8
    scoreList.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    scoreList.CanvasSize = UDim2.new(1, 0, 0, 0)
    scoreList.ScrollingEnabled = true
    scoreList.ClipsDescendants = false
    scoreList.Parent = scoreGui

    -- Add UIListLayout for organizing score entries
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 4)
    listLayout.Parent = scoreList
end

-- Handle player joining
function LobbyService:OnPlayerAdded(player)
    -- CRITICAL: Mark player as in lobby immediately to prevent early return in character handler
    playersInLobby[player] = true

    local hasSpawned = false

    -- Single handler for all character spawns
    local function handleCharacterAdded(character)
        if not playersInLobby[player] then return end  -- Player left

        task.wait(0.5)
        self:SpawnPlayerInLobby(player)

        -- Only play music on first spawn
        if not hasSpawned and SoundEvents then
            task.wait(1)
            if player and player.Parent then  -- Verify still in game
                SoundEvents.PlayLobbyMusic:FireClient(player)
                print("[LobbyService] Sent lobby music to", player.Name, "(initial join)")
            end
            hasSpawned = true
        end
    end

    -- Connect to future character spawns
    player.CharacterAdded:Connect(handleCharacterAdded)

    -- Clear ready status when character is removed (death/reset)
    player.CharacterRemoving:Connect(function()
        if playersInReadyZone[player] then
            playersInReadyZone[player] = nil
            print("[LobbyService] Player", player.Name, "removed from ready zone (character removed)")
        end
    end)

    -- Handle existing character
    if player.Character then
        handleCharacterAdded(player.Character)
    end
end

-- Spawn player in lobby (Pattern 3 from RESEARCH.md - use PivotTo)
function LobbyService:SpawnPlayerInLobby(player)
    local character = player.Character

    -- Wait for character if it doesn't exist yet
    if not character then
        local startTime = tick()
        local timeout = 10  -- 10 second timeout

        -- Wait with timeout
        local connection
        connection = player.CharacterAdded:Connect(function(char)
            character = char
            if connection then
                connection:Disconnect()
            end
        end)

        -- Wait for character or timeout
        while not character and player.Parent and (tick() - startTime) < timeout do
            task.wait(0.1)
        end

        if connection then
            connection:Disconnect()
        end

        if not character then
            warn("[LobbyService] Character load timeout for " .. player.Name)
            return false
        end
    end

    if not lobbySpawn then
        return false
    end

    -- Wait for HumanoidRootPart to ensure character is fully loaded
    local hrp = character:WaitForChild("HumanoidRootPart", 5)
    if not hrp then
        return false
    end

    -- Wait for Humanoid (needed for production network replication)
    local humanoid = character:WaitForChild("Humanoid", 5)
    if not humanoid then
        return false
    end

    -- CRITICAL: Wait for physics to settle (production network latency fix)
    -- Without this, character falls through floor in production
    task.wait(0.1)

    -- Anchor character during teleport (prevents falling through floor)
    hrp.Anchored = true

    -- Reset velocity to prevent flying/momentum issues
    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

    -- Teleport using PivotTo (replaces deprecated SetPrimaryPartCFrame)
    -- Increased Y offset to 5 studs for safety (was 3)
    local spawnCFrame = lobbySpawn.CFrame * CFrame.new(0, 5, 0)
    character:PivotTo(spawnCFrame)

    -- Wait a frame for teleport to register
    task.wait()

    -- Unanchor to allow movement
    hrp.Anchored = false

    -- Reset velocity again after teleport (ensure no lingering momentum)
    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

    playersInLobby[player] = true

    return true
end

-- Teleport all players back to lobby (called after rounds)
function LobbyService:TeleportAllToLobby()

    for _, player in ipairs(Players:GetPlayers()) do
        -- Ensure player has a character before teleporting
        if not player.Character then
            print("[LobbyService] Player", player.Name, "has no character, loading...")
            player:LoadCharacter()
            task.wait(0.5)
        end

        self:SpawnPlayerInLobby(player)

        -- Play lobby music for each player when returning from round
        if SoundEvents then
            task.wait(0.5)
            SoundEvents.PlayLobbyMusic:FireClient(player)
            print("[LobbyService] Sent lobby music to", player.Name, "after round")
        end
    end
end

-- Get active players in lobby
function LobbyService:GetActivePlayers()
    local active = {}
    for player, _ in pairs(playersInLobby) do
        if player.Parent then -- Check player still in game
            table.insert(active, player)
        else
            playersInLobby[player] = nil -- Clean up disconnected players
        end
    end
    return active
end

-- Get ready players (players in the ready zone)
function LobbyService:GetReadyPlayers()
    local ready = {}
    for player, _ in pairs(playersInReadyZone) do
        -- Validate player is still in game
        if not player.Parent then
            playersInReadyZone[player] = nil
            continue
        end

        -- Validate player has a character and is alive
        local character = player.Character
        if not character then
            playersInReadyZone[player] = nil
            continue
        end

        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid or humanoid.Health <= 0 then
            playersInReadyZone[player] = nil
            print("[LobbyService] Player", player.Name, "removed from ready zone (dead or no humanoid)")
            continue
        end

        -- Player is valid and ready
        table.insert(ready, player)
    end
    return ready
end

-- Clear ready zone (called when round starts)
function LobbyService:ClearReadyZone()
    playersInReadyZone = {}
    print("[LobbyService] Ready zone cleared")
end

-- Update status display with custom message
function LobbyService:UpdateStatusMessage(message)
    if not lobbyModel then return end

    local sign = lobbyModel:FindFirstChild("StatusSign")
    if not sign then return end

    local surfaceGui = sign:FindFirstChildOfClass("SurfaceGui")
    if not surfaceGui then return end

    local textLabel = surfaceGui:FindFirstChild("StatusText")
    if not textLabel then return end

    textLabel.Text = "MANSION ESCAPE\n\n" .. message
end

-- Update player count display (called by RoundService)
function LobbyService:UpdatePlayerCount(currentCount, requiredCount)
    if currentCount == 0 then
        self:UpdateStatusMessage(string.format("Step into the green zone!\n\n%d/%d players ready", currentCount, requiredCount))
    else
        self:UpdateStatusMessage(string.format("Waiting for players...\n\n%d/%d players ready", currentCount, requiredCount))
    end
end

-- Update lobby status text (called by RoundService on state changes)
function LobbyService:UpdateLobbyStatus(state, details)
    if not lobbyModel then return end

    local statusMessages = {
        [RoundTypes.State.Lobby] = details or "Waiting for players...",
        [RoundTypes.State.Countdown] = details or "Round starting soon!",
        [RoundTypes.State.Playing] = details or "Round in progress...",
        [RoundTypes.State.Results] = details or "Round complete!"
    }

    local message = statusMessages[state] or "Standby..."
    self:UpdateStatusMessage(message)
end

-- Refresh scoreboard with current player scores from DataService
function LobbyService:RefreshScoreboard()
    if not DataService then
        return
    end
    if not lobbyModel then
        return
    end


    -- Get all current players and their scores
    local playerScores = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local points = DataService:GetPlayerPoints(player)
        playerScores[player] = points
    end


    -- Update the display
    self:UpdateScoreboard(playerScores)
end

-- Update scoreboard with player scores
function LobbyService:UpdateScoreboard(playerScores)
    if not lobbyModel then
        return
    end

    local scoreSign = lobbyModel:FindFirstChild("ScoreboardSign")
    if not scoreSign then
        return
    end

    local surfaceGui = scoreSign:FindFirstChildOfClass("SurfaceGui")
    if not surfaceGui then
        return
    end

    local scoreList = surfaceGui:FindFirstChild("ScoreList")
    if not scoreList then
        return
    end

    -- Clear existing entries (but keep UIListLayout)
    for _, child in ipairs(scoreList:GetChildren()) do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end

    -- Sort players by score (descending)
    local sortedScores = {}
    for player, score in pairs(playerScores) do
        table.insert(sortedScores, {player = player, score = score})
    end
    table.sort(sortedScores, function(a, b)
        if a.score == b.score then
            return a.player.Name < b.player.Name
        end
        return a.score > b.score
    end)

    -- Create entry for each player
    for i, entry in ipairs(sortedScores) do
        local entryFrame = Instance.new("Frame")
        entryFrame.Name = "Entry" .. i
        entryFrame.Size = UDim2.new(1, -10, 0, 100)
        entryFrame.BackgroundColor3 = i % 2 == 0 and Color3.fromRGB(30, 30, 40) or Color3.fromRGB(25, 25, 35)
        entryFrame.BackgroundTransparency = 0
        entryFrame.BorderSizePixel = 0
        entryFrame.LayoutOrder = i
        entryFrame.Visible = true
        entryFrame.Parent = scoreList

        local entryLabel = Instance.new("TextLabel")
        entryLabel.Name = "Label"
        entryLabel.Size = UDim2.new(1, -20, 1, 0)
        entryLabel.Position = UDim2.new(0, 10, 0, 0)
        entryLabel.BackgroundTransparency = 1
        entryLabel.Text = string.format("%d. %s - %d pts", i, entry.player.Name, entry.score)
        entryLabel.TextColor3 = i <= 3 and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(255, 255, 255)
        entryLabel.TextSize = 80
        entryLabel.Font = Enum.Font.Gotham
        entryLabel.TextXAlignment = Enum.TextXAlignment.Left
        entryLabel.TextYAlignment = Enum.TextYAlignment.Center
        entryLabel.TextScaled = false
        entryLabel.Visible = true
        entryLabel.Parent = entryFrame
    end

    -- Update canvas size (set width to match parent, height based on entry count)
    -- Height = (entry height + padding) per entry
    scoreList.CanvasSize = UDim2.new(1, 0, 0, #sortedScores * 104)
end

-- Get lobby spawn CFrame (for future use)
function LobbyService:GetLobbySpawnCFrame()
    if lobbySpawn then
        return lobbySpawn.CFrame
    end
    return CFrame.new(0, 2.5, 0) -- Default position at ground level
end

return LobbyService
