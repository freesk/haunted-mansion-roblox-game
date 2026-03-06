--[[
    ResultsService - Round results calculation and leaderboard generation

    Calculates points based on survival, completion, and speed.
    Generates leaderboard data and broadcasts results to clients.
    Awards points to players via DataService.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local ResultsService = {}
ResultsService.__index = ResultsService

-- Reference to other services (set during Init)
local DataService = nil
local RoundEvents = nil

function ResultsService:Init()
    print("[ResultsService] Initializing...")

    -- Get references to services
    DataService = require(ServerScriptService.Services.DataService)
    RoundEvents = require(ReplicatedStorage.Remotes.RoundEvents)

    print("[ResultsService] Initialized")
end

-- Calculate round results based on survival and completion
function ResultsService:CalculateRoundResults(alivePlayers, exitReached, completionTime)
    print("[ResultsService] Calculating results...")
    print("  Alive players:", #alivePlayers)
    print("  Exit reached:", exitReached)
    print("  Completion time:", completionTime)

    local results = {}
    local survivorCount = #alivePlayers  -- Calculate once for team survival multiplier

    for _, player in ipairs(alivePlayers) do
        local pointsEarned = 0

        -- Base points for survival (scales with team survival)
        local teamSurvivalPoints = GameConfig.POINTS_PER_SURVIVOR * survivorCount
        pointsEarned += teamSurvivalPoints

        -- Completion bonus if exit reached
        if exitReached then
            pointsEarned += GameConfig.POINTS_FOR_COMPLETION

            -- Speed bonus based on completion time
            -- Faster completion = higher bonus (max 200 points)
            -- Formula: max bonus * (1 - (time / maxTime))
            -- Example: 120 seconds = 200 * (1 - 120/600) = 160 points
            local maxTime = GameConfig.ROUND_DURATION
            local speedFactor = 1 - (completionTime / maxTime)
            speedFactor = math.max(0, math.min(1, speedFactor)) -- Clamp 0-1
            local speedBonus = math.floor(GameConfig.POINTS_SPEED_BONUS_MAX * speedFactor)
            pointsEarned += speedBonus
        end

        -- Store result
        table.insert(results, {
            player = player,
            playerName = player.Name,
            alive = true,
            pointsEarned = pointsEarned,
            completionTime = exitReached and completionTime or nil
        })

        print("  " .. player.Name .. " earned " .. pointsEarned .. " points (" ..
              teamSurvivalPoints .. " survival + " .. (pointsEarned - teamSurvivalPoints) .. " bonus)")
    end

    return results
end

-- Generate leaderboard data sorted by points
function ResultsService:GenerateLeaderboardData(results)
    print("[ResultsService] Generating leaderboard data...")

    -- Sort results by points descending
    table.sort(results, function(a, b)
        return a.pointsEarned > b.pointsEarned
    end)

    -- Format leaderboard data for clients
    local leaderboardData = {}
    for _, result in ipairs(results) do
        table.insert(leaderboardData, {
            playerName = result.playerName,
            status = result.alive and "Survived" or "Dead",
            pointsEarned = result.pointsEarned
        })
    end

    return leaderboardData
end

-- Award points to player via DataService
function ResultsService:AwardPoints(player, points)
    if not player or not player.Parent then
        warn("[ResultsService] Cannot award points to invalid player")
        return false
    end

    if not DataService then
        warn("[ResultsService] DataService not initialized")
        return false
    end

    -- Update player points using DataService
    local success = DataService:UpdatePlayerData(player, function(data)
        data.Points = data.Points + points
    end)

    if success then
        print("[ResultsService] Awarded " .. points .. " points to " .. player.Name)

        -- Update leaderstats if exists
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
            local pointsValue = leaderstats:FindFirstChild("Points")
            if pointsValue then
                local profile = DataService:GetProfile(player)
                if profile and profile.Data then
                    pointsValue.Value = profile.Data.Points
                end
            end
        end
    else
        warn("[ResultsService] Failed to award points to " .. player.Name)
    end

    return success
end

-- Broadcast results to all clients
function ResultsService:BroadcastResults(results)
    if not RoundEvents then
        warn("[ResultsService] RoundEvents not initialized")
        return
    end

    print("[ResultsService] Broadcasting results to all clients...")

    -- Calculate totals for summary
    local totalSurvivors = 0
    local totalPointsAwarded = 0

    for _, result in ipairs(results) do
        if result.alive then
            totalSurvivors += 1
        end
        totalPointsAwarded += result.pointsEarned
    end

    -- Format results data for clients
    local resultsData = {
        results = results,
        totalSurvivors = totalSurvivors,
        totalPointsAwarded = totalPointsAwarded
    }

    -- Fire to all clients
    RoundEvents.RoundResults:FireAllClients(resultsData)

    print("[ResultsService] Results broadcast complete")
end

return ResultsService
