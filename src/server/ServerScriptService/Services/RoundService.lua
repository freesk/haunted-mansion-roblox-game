--[[
    RoundService - Round state machine and lifecycle management

    Manages the round loop: Lobby -> Countdown -> Playing -> Results -> repeat
    Server-authoritative state machine with RemoteEvent updates to clients

    ROUND END CONDITIONS (defined in RunRound function):
    1. Timer expires - ROUND_DURATION (600 seconds / 10 minutes) elapsed
    2. All players dead - All players' Humanoid.Health reaches 0
    3. Exit reached - Any player gets within 10 studs of exit marker

    PLAYER DEATH HANDLING:
    - When player dies: marked as dead in activePlayers table
    - Dead players respawn in lobby automatically (Roblox default)
    - Dead players hear lobby music, alive players hear mansion music
    - Dead players can participate in next round (force respawn on round start)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RoundTypes = require(ReplicatedStorage.Shared.Types.RoundTypes)
local RoundEvents = require(ReplicatedStorage.Remotes.RoundEvents)
local SoundEvents = require(ReplicatedStorage.Remotes.SoundEvents)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local ButlerNPC = require(ServerScriptService.Modules.ButlerNPC)
local MonsterNPC = require(ServerScriptService.Modules.MonsterNPC)
local GhostNPC = require(ServerScriptService.Modules.GhostNPC)
local MonsterConfig = require(ServerScriptService.Modules.Monster.MonsterConfig)
local GhostConfig = require(ServerScriptService.Modules.Ghost.GhostConfig)

local RoundService = {}
RoundService.__index = RoundService

-- Reference to other services (set during Init)
local LobbyService = nil
local MansionService = nil
local PlayerService = nil
local ResultsService = nil
local DataService = nil
local ProximityService = nil

-- Reference to modules
local AmbientSoundManager = nil

-- Butler instance
local mansionButler = nil

-- Current round state
local currentState = RoundTypes.State.Lobby
local activePlayers = {} -- [Player] = PlayerStatus
local connections = {} -- Event connections to disconnect on cleanup

-- Player tracking for round completion
local roundRunning = false
local countdownCancelled = false
local roundStartTime = 0
local exitReachedFlag = false

function RoundService:Init()

    -- Get references to services
    LobbyService = require(ServerScriptService.Services.LobbyService)
    MansionService = require(ServerScriptService.Services.MansionService)
    PlayerService = require(ServerScriptService.Services.PlayerService)
    ResultsService = require(ServerScriptService.Services.ResultsService)
    DataService = require(ServerScriptService.Services.DataService)
    ProximityService = require(ServerScriptService.Services.ProximityService)

    -- Get references to modules
    AmbientSoundManager = require(ServerScriptService.Modules.AmbientSoundManager)

    -- Handle player disconnections during rounds
    table.insert(connections, Players.PlayerRemoving:Connect(function(player)
        self:HandlePlayerLeaving(player)
    end))

    -- Handle players joining during rounds
    table.insert(connections, Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(character)
            -- Handle death during round
            local humanoid = character:WaitForChild("Humanoid", 5)
            if humanoid then
                humanoid.Died:Connect(function()
                    if roundRunning then
                        -- Mark player as dead in round tracking
                        if activePlayers[player] then
                            activePlayers[player].alive = false
                            print("[RoundService] Player", player.Name, "died during round")
                        end

                        -- Play lobby music when they respawn
                        task.wait(0.5)
                        if SoundEvents and player and player.Parent then
                            SoundEvents.PlayLobbyMusic:FireClient(player)
                        end

                        -- Check if all players are now dead (round should end)
                        local aliveCount = #self:GetAlivePlayers()
                        print("[RoundService] Alive players remaining:", aliveCount)
                        if aliveCount == 0 then
                            print("[RoundService] All players dead - ending round")
                        end
                    end
                end)
            end
        end)
    end))

    -- Start the main round loop in a coroutine
    task.spawn(function()
        self:RunMainLoop()
    end)

end

-- Set state with validation
function RoundService:SetState(newState)
    local validTransitions = RoundTypes.StateTransitions[currentState]

    if not validTransitions or not table.find(validTransitions, newState) then
        warn("[RoundService] Invalid state transition:", currentState, "->", newState)
        return false
    end

    currentState = newState

    -- Fire RemoteEvent to update all clients
    RoundEvents.StateChanged:FireAllClients(newState)

    -- Update lobby status display
    if LobbyService then
        LobbyService:UpdateLobbyStatus(newState)
    end

    return true
end

-- Get current state (read-only access)
function RoundService:GetState()
    return currentState
end

-- Wait for minimum players to start
function RoundService:WaitForPlayers()

    while true do
        local readyPlayers = LobbyService:GetReadyPlayers()
        local playerCount = #readyPlayers

        -- Update lobby sign display (physical screen in lobby)
        if LobbyService then
            LobbyService:UpdatePlayerCount(playerCount, GameConfig.MIN_PLAYERS_TO_START)
        end

        if playerCount >= GameConfig.MIN_PLAYERS_TO_START then
            return true
        end

        task.wait(1)
    end
end

-- Run accurate countdown using task.wait() return values (Pattern 2 from RESEARCH.md)
function RoundService:RunCountdown(duration)
    countdownCancelled = false

    local delta = duration

    while delta > 0 do
        -- Display rounded time to players
        local displayTime = math.ceil(delta)
        RoundEvents.CountdownUpdate:FireAllClients(displayTime)

        -- Update lobby display with countdown
        if LobbyService then
            local readyPlayers = LobbyService:GetReadyPlayers()
            local playerCount = #readyPlayers
            local playerWord = playerCount == 1 and "player" or "players"
            LobbyService:UpdateStatusMessage(string.format("Starting in %d seconds!\n\n%d %s ready", displayTime, playerCount, playerWord))
        end

        -- Subtract actual elapsed time to prevent drift
        local elapsed = task.wait(1)
        delta -= elapsed

        -- Check if countdown should be cancelled (player left, etc.)
        if countdownCancelled then
            RoundEvents.CountdownUpdate:FireAllClients(0)
            if LobbyService then
                LobbyService:UpdateStatusMessage("Countdown cancelled!\n\nWaiting for players...")
            end
            return false
        end

        -- Check if we still have minimum ready players
        local readyPlayers = LobbyService:GetReadyPlayers()
        local playerCount = #readyPlayers

        -- If all players left the ready zone, abort countdown
        if playerCount == 0 then
            if LobbyService then
                LobbyService:UpdateStatusMessage("All players left!\n\nCountdown cancelled")
            end
            print("[RoundService] All players left ready zone - countdown aborted")
            return false
        end

        if playerCount < GameConfig.MIN_PLAYERS_TO_START then
            if LobbyService then
                LobbyService:UpdateStatusMessage("Not enough players!\n\nStep into the ready zone!")
            end
            print("[RoundService] Not enough ready players - countdown aborted")
            return false
        end
    end

    -- Countdown complete
    RoundEvents.CountdownUpdate:FireAllClients(0)
    return true
end

-- Start round and track players
function RoundService:StartRound()

    -- Track round start time for completion time calculation
    roundStartTime = os.clock()
    exitReachedFlag = false

    -- Ensure all ready players have alive characters before round starts
    local readyPlayers = LobbyService:GetReadyPlayers()
    for _, player in ipairs(readyPlayers) do
        if player.Character then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            -- If player is dead or character is broken, force respawn
            if not humanoid or humanoid.Health <= 0 then
                print("[RoundService] Force respawning", player.Name, "before round start")
                player:LoadCharacter()
                task.wait(0.5) -- Wait for character to load
            end
        else
            -- No character at all, force spawn
            print("[RoundService] Loading character for", player.Name)
            player:LoadCharacter()
            task.wait(0.5)
        end
    end

    -- Initialize player tracking (only for ready players)
    activePlayers = {}
    local readyPlayers = LobbyService:GetReadyPlayers()
    for _, player in ipairs(readyPlayers) do
        activePlayers[player] = {
            alive = true,
            survivalTime = 0,
            joinTime = os.clock()
        }
    end

    -- Clear ready zone after capturing players
    LobbyService:ClearReadyZone()

    -- Update status: Generating mansion
    if LobbyService then
        LobbyService:UpdateStatusMessage("Generating mansion...\n\nPlease wait...")
    end

    -- Generate mansion
    if MansionService then
        MansionService:GenerateNewMansion()
    end

    -- CRITICAL: Wait for mansion to replicate to clients (production fix)
    -- Without this, players teleport to mansion before floor loads on their client
    -- This is especially critical in production with real network latency
    if LobbyService then
        LobbyService:UpdateStatusMessage("Mansion ready!\n\nPreparing spawn...")
    end
    task.wait(0.5)

    -- Get spawn locations from mansion
    local spawnLocations = {}
    if MansionService then
        spawnLocations = MansionService:GetSpawnLocations()
    end

    -- === SETUP PHASE - DO EVERYTHING BEFORE TELEPORTING PLAYERS ===

    -- Spawn butler in the mansion to guide players
    if MansionService and #spawnLocations > 0 then
        local exitMarkerCFrame = MansionService:GetExitLocation()

        if exitMarkerCFrame then
            -- Spawn butler at first spawn location (same as player)
            local butlerSpawnCFrame = spawnLocations[1]

            -- Find mansion in Workspace
            local Workspace = game:GetService("Workspace")
            local mansion = Workspace:FindFirstChild("ProceduralMansion")

            if mansion then
                -- Spawn butler without starting movement (will start after player teleport)
                local success = ButlerNPC:SpawnButler(butlerSpawnCFrame, exitMarkerCFrame, mansion, false, false)

                if success then
                    mansionButler = ButlerNPC:GetButler()
                else
                    warn("[RoundService] ✗ Failed to spawn butler in mansion")
                end

                -- Get spawn locations for both monsters and ghosts
                local monsterSpawnLocations = MansionService:GetMonsterSpawnLocations(6) -- 6 monsters per level
                local ghostSpawnLocations = MansionService:GetMonsterSpawnLocations(6) -- 6 ghosts per level

                -- Get mansion's world position for calculating absolute Y positions
                local mansionWorldY = mansion:GetPivot().Position.Y

                -- Spawn all NPCs in parallel for faster loading
                local spawnThreads = {}

                -- Spawn monsters
                if #monsterSpawnLocations > 0 then
                    for i, spawnData in ipairs(monsterSpawnLocations) do
                        table.insert(spawnThreads, task.spawn(function()
                            local spawnPos = spawnData.cframe.Position
                            local monsterY = spawnPos.Y + MonsterConfig.MANSION_Y_OFFSET
                            local monsterSpawnCFrame = CFrame.new(spawnPos.X, monsterY, spawnPos.Z)

                            local monster = MonsterNPC:SpawnMonster(monsterSpawnCFrame, mansion)
                            if not monster then
                                warn("[RoundService] ✗ Failed to spawn monster", i, "in", spawnData.room.Name)
                            end
                        end))
                    end
                else
                    warn("[RoundService] ✗ No valid monster spawn locations found")
                end

                -- Spawn ghosts
                if #ghostSpawnLocations > 0 then
                    for i, spawnData in ipairs(ghostSpawnLocations) do
                        table.insert(spawnThreads, task.spawn(function()
                            -- Use the room's actual world Y position + half wall height
                            local WALL_HEIGHT = 16
                            local roomWorldY = spawnData.room:GetPivot().Position.Y
                            local ghostY = roomWorldY + (WALL_HEIGHT / 2) + GhostConfig.MANSION_Y_OFFSET

                            local spawnPos = spawnData.cframe.Position
                            local ghostSpawnCFrame = CFrame.new(spawnPos.X, ghostY, spawnPos.Z)

                            print(string.format("[RoundService] Spawning ghost in %s (level %d), roomY=%.1f, ghostY=%.1f",
                                spawnData.room.Name, spawnData.level, roomWorldY, ghostY))

                            local ghost = GhostNPC:SpawnGhost(ghostSpawnCFrame, mansion)
                            if not ghost then
                                warn("[RoundService] ✗ Failed to spawn ghost", i, "in", spawnData.room.Name)
                            end
                        end))
                    end
                else
                    warn("[RoundService] ✗ No valid ghost spawn locations found")
                end

                -- Spawn furniture throughout mansion
                MansionService:SpawnFurniture(nil) -- Pass nil for butler path (beds spawn anywhere)

            else
                warn("[RoundService] ✗ Mansion not found in Workspace")
            end
        else
            warn("[RoundService] ✗ No exit marker found, cannot spawn butler")
        end
    else
        warn("[RoundService] ✗ No spawn locations available")
    end

    -- === NOW TELEPORT PLAYERS (everything is ready) ===

    -- Get list of active players for teleportation
    local playersToTeleport = {}
    for player, _ in pairs(activePlayers) do
        if player and player.Parent then  -- Verify player still in game
            table.insert(playersToTeleport, player)
        end
    end

    -- Update status: Teleporting players
    if LobbyService then
        local playerCount = #playersToTeleport
        local playerWord = playerCount == 1 and "player" or "players"
        LobbyService:UpdateStatusMessage(string.format("Teleporting to mansion...\n\n%d %s entering", playerCount, playerWord))
    end

    -- Teleport all active players to mansion entrance
    if PlayerService and #spawnLocations > 0 then
        PlayerService:TeleportAllToMansion(playersToTeleport, spawnLocations)
    else
        warn("[RoundService] No spawn locations available for teleportation")
    end

    -- Play mansion background music (players are now in the mansion)
    if AmbientSoundManager then
        AmbientSoundManager:PlayMansionMusic()
    end

    -- Wait briefly for everything to settle
    task.wait(0.5)

    -- NOW start the butler's movement (players are in the mansion)
    if mansionButler then
        ButlerNPC:StartNavigation()
    end

    -- Start proximity checking (players must stay near butler)
    if ProximityService and mansionButler then
        task.wait(1) -- Give players time to see butler before starting countdown
        ProximityService:StartProximityCheck()
    end

    roundRunning = true
end

-- Run round with mansion gameplay and exit detection
-- Round ends when:
-- 1. Timer expires (ROUND_DURATION seconds)
-- 2. All players are dead
-- 3. At least one player reaches the exit
function RoundService:RunRound()

    local roundDuration = GameConfig.ROUND_DURATION
    local roundEndReason = "Timer expired" -- Default reason

    -- Get exit location for win condition
    local exitLocation = nil
    if MansionService then
        exitLocation = MansionService:GetExitLocation()
    end

    print("[RoundService] Round started - Duration:", roundDuration, "seconds")

    -- Round loop - check end conditions every second
    while os.clock() - roundStartTime < roundDuration do
        task.wait(1)

        local timeRemaining = math.ceil(roundDuration - (os.clock() - roundStartTime))
        local alivePlayers = self:GetAlivePlayers()
        local aliveCount = #alivePlayers

        -- END CONDITION 1: All players are dead
        if aliveCount == 0 then
            roundEndReason = "All players died"
            print("[RoundService] *** ROUND END: All players died ***")
            break
        end

        -- END CONDITION 2: Someone reached the exit
        if exitLocation and self:CheckExitReached(exitLocation) then
            exitReachedFlag = true
            roundEndReason = "Player reached exit"
            print("[RoundService] *** ROUND END: Player reached exit ***")
            break
        end

        -- Log status every 30 seconds
        if timeRemaining % 30 == 0 then
            print("[RoundService] Round status - Time remaining:", timeRemaining, "s | Alive players:", aliveCount)
        end
    end

    -- END CONDITION 3: Timer expired
    if not exitReachedFlag and #self:GetAlivePlayers() > 0 then
        print("[RoundService] *** ROUND END: Timer expired ***")
    end

    print("[RoundService] Round ended - Reason:", roundEndReason)
    roundRunning = false
end

-- Check if any player reached the exit
function RoundService:CheckExitReached(exitLocation)
    if not exitLocation then return false end

    local alivePlayers = self:GetAlivePlayers()

    for _, player in ipairs(alivePlayers) do
        local character = player.Character
        if character then
            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            if humanoidRootPart then
                -- Check if player is within 10 studs of exit
                local distance = (humanoidRootPart.Position - exitLocation.Position).Magnitude
                if distance < 10 then
                    return true
                end
            end
        end
    end

    return false
end

-- Show results screen
function RoundService:ShowResults()

    -- Calculate completion time
    local completionTime = os.clock() - roundStartTime

    -- Get alive players
    local alivePlayers = self:GetAlivePlayers()

    -- Calculate results using ResultsService
    if ResultsService then
        local results = ResultsService:CalculateRoundResults(alivePlayers, exitReachedFlag, completionTime)

        -- Award points to each player
        for _, result in ipairs(results) do
            if result.player and result.pointsEarned then
                ResultsService:AwardPoints(result.player, result.pointsEarned)
            end
        end

        -- Generate and broadcast leaderboard data
        local leaderboardData = ResultsService:GenerateLeaderboardData(results)
        ResultsService:BroadcastResults(results)

        -- Update lobby leaderboard for all clients
        local LeaderboardEvents = require(ReplicatedStorage.Remotes.LeaderboardEvents)
        local topPlayers = DataService:GetTopPlayers(10)
        LeaderboardEvents.LeaderboardUpdate:FireAllClients(topPlayers)

        -- Update lobby scoreboard display
        if LobbyService then
            LobbyService:RefreshScoreboard()
        end
    end

    -- Stop proximity checks
    if ProximityService then
        ProximityService:StopProximityCheck()
    end

    -- Cleanup sounds FIRST (before destroying mansion parts they're attached to)
    if AmbientSoundManager then
        AmbientSoundManager:CleanupSounds()
    end

    -- Cleanup mansion butler
    if mansionButler then
        ButlerNPC:Cleanup()
        mansionButler = nil
    end

    -- Cleanup monsters
    MonsterNPC:CleanupAll()

    -- Cleanup ghosts
    GhostNPC:CleanupAll()

    -- Cleanup mansion (destroy the structure)
    if MansionService then
        MansionService:CleanupMansion()
    end

    -- Results display duration
    task.wait(10)

    -- Teleport all players back to lobby
    if LobbyService then
        LobbyService:TeleportAllToLobby()
    end

    -- Play lobby background music
    if AmbientSoundManager then
        AmbientSoundManager:PlayLobbyMusic()
    end

end

-- Get alive players
function RoundService:GetAlivePlayers()
    local alive = {}
    for player, data in pairs(activePlayers) do
        if data.alive and player.Parent then -- Check player still in game
            table.insert(alive, player)
        end
    end
    return alive
end

-- Get total players in round
function RoundService:GetTotalPlayers()
    local count = 0
    for _ in pairs(activePlayers) do
        count += 1
    end
    return count
end

-- Handle player leaving during round (Pitfall 1 from RESEARCH.md)
function RoundService:HandlePlayerLeaving(player)
    if activePlayers[player] then
        activePlayers[player] = nil

        -- Check if round should end early
        if roundRunning and #self:GetAlivePlayers() == 0 then
            roundRunning = false
        end
    end
end

-- Main round loop
function RoundService:RunMainLoop()

    while true do
        -- Lobby state - wait for players
        self:SetState(RoundTypes.State.Lobby)
        self:WaitForPlayers()

        -- Countdown state
        self:SetState(RoundTypes.State.Countdown)

        -- Countdown will update its own display
        local countdownSuccess = self:RunCountdown(10) -- 10 second countdown

        if not countdownSuccess then
            -- Countdown cancelled, return to lobby
            continue
        end

        -- Playing state
        self:SetState(RoundTypes.State.Playing)

        -- Update status
        if LobbyService then
            LobbyService:UpdateStatusMessage("Round in progress...\n\nGood luck!")
        end

        self:StartRound()
        self:RunRound()

        -- Results state
        self:SetState(RoundTypes.State.Results)

        -- Update status
        if LobbyService then
            if exitReachedFlag then
                LobbyService:UpdateStatusMessage("Round complete!\n\nSomeone escaped!")
            else
                LobbyService:UpdateStatusMessage("Round complete!\n\nCalculating scores...")
            end
        end

        self:ShowResults()

        -- Brief pause before next round
        task.wait(2)
    end
end

-- Cleanup (for testing/shutdown)
function RoundService:Cleanup()
    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end
    connections = {}
    activePlayers = {}
    roundRunning = false
end

return RoundService
