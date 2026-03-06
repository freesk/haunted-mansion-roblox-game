--[[
    LeaderboardUIController - Client UI for leaderboard and results display

    Displays end-of-round results, lobby leaderboard, and overhead point displays
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LeaderboardEvents = require(ReplicatedStorage.Remotes.LeaderboardEvents)

local LeaderboardUIController = {}
LeaderboardUIController.__index = LeaderboardUIController

-- UI references
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local resultsUI = nil
local lobbyLeaderboardUI = nil
local overheadDisplays = {} -- [player] = BillboardGui

-- Horror theme colors
local COLORS = {
    background = Color3.fromRGB(20, 20, 25),
    text = Color3.fromRGB(220, 220, 220),
    accent = Color3.fromRGB(180, 50, 50),
    survived = Color3.fromRGB(80, 180, 80),
    dead = Color3.fromRGB(180, 60, 60)
}

function LeaderboardUIController:Init()
    -- Connect to RemoteEvents
    LeaderboardEvents.ResultsDisplay.OnClientEvent:Connect(function(resultsData)
        self:ShowResults(resultsData)
    end)
end

-- Create end-of-round results UI
function LeaderboardUIController:CreateResultsUI()
    -- Remove existing results UI if present
    if resultsUI then
        resultsUI:Destroy()
    end

    -- Create ScreenGui
    resultsUI = Instance.new("ScreenGui")
    resultsUI.Name = "ResultsUI"
    resultsUI.ResetOnSpawn = false
    resultsUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    resultsUI.Parent = playerGui

    -- Semi-transparent background
    local background = Instance.new("Frame")
    background.Name = "Background"
    background.Size = UDim2.new(1, 0, 1, 0)
    background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    background.BackgroundTransparency = 0.4
    background.BorderSizePixel = 0
    background.Parent = resultsUI

    -- Main results container
    local container = Instance.new("Frame")
    container.Name = "Container"
    container.Size = UDim2.new(0, 600, 0, 400)
    container.AnchorPoint = Vector2.new(0.5, 0.5)
    container.Position = UDim2.new(0.5, 0, 0.5, 0)
    container.BackgroundColor3 = COLORS.background
    container.BorderSizePixel = 0
    container.Parent = resultsUI

    -- Add corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = container

    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -40, 0, 50)
    title.Position = UDim2.new(0, 20, 0, 20)
    title.BackgroundTransparency = 1
    title.Text = "ROUND COMPLETE"
    title.TextColor3 = COLORS.text
    title.Font = Enum.Font.GothamBold
    title.TextSize = 32
    title.Parent = container

    -- Results table container
    local tableContainer = Instance.new("ScrollingFrame")
    tableContainer.Name = "TableContainer"
    tableContainer.Size = UDim2.new(1, -40, 0, 280)
    tableContainer.Position = UDim2.new(0, 20, 0, 90)
    tableContainer.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    tableContainer.BorderSizePixel = 0
    tableContainer.ScrollBarThickness = 6
    tableContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
    tableContainer.Parent = container

    local tableCorner = Instance.new("UICorner")
    tableCorner.CornerRadius = UDim.new(0, 4)
    tableCorner.Parent = tableContainer

    -- UIListLayout for results
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 2)
    listLayout.Parent = tableContainer

    return resultsUI, tableContainer
end

-- Show results screen with data
function LeaderboardUIController:ShowResults(resultsData)
    print("[LeaderboardUIController] Showing results...")

    local ui, tableContainer = self:CreateResultsUI()

    -- Populate results table
    if resultsData and resultsData.results then
        for i, result in ipairs(resultsData.results) do
            local row = self:CreateResultRow(result, i)
            row.Parent = tableContainer
        end

        -- Update canvas size
        tableContainer.CanvasSize = UDim2.new(0, 0, 0, #resultsData.results * 42 + 10)
    end

    -- Auto-hide after 10 seconds
    task.delay(10, function()
        if resultsUI then
            -- Fade out
            local tween = TweenService:Create(resultsUI.Background, TweenInfo.new(0.5), {
                BackgroundTransparency = 1
            })
            tween:Play()

            task.wait(0.5)
            resultsUI:Destroy()
            resultsUI = nil
        end
    end)
end

-- Create a single result row
function LeaderboardUIController:CreateResultRow(result, index)
    local row = Instance.new("Frame")
    row.Name = "Row" .. index
    row.Size = UDim2.new(1, -10, 0, 40)
    row.BackgroundColor3 = index % 2 == 0 and Color3.fromRGB(20, 20, 25) or Color3.fromRGB(25, 25, 30)
    row.BorderSizePixel = 0
    row.LayoutOrder = index

    -- Player name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.Size = UDim2.new(0.4, 0, 1, 0)
    nameLabel.Position = UDim2.new(0, 10, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = result.playerName or "Unknown"
    nameLabel.TextColor3 = COLORS.text
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextSize = 18
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = row

    -- Status
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "Status"
    statusLabel.Size = UDim2.new(0.3, 0, 1, 0)
    statusLabel.Position = UDim2.new(0.4, 0, 0, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = result.alive and "Survived" or "Dead"
    statusLabel.TextColor3 = result.alive and COLORS.survived or COLORS.dead
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 16
    statusLabel.TextXAlignment = Enum.TextXAlignment.Center
    statusLabel.Parent = row

    -- Points earned
    local pointsLabel = Instance.new("TextLabel")
    pointsLabel.Name = "Points"
    pointsLabel.Size = UDim2.new(0.3, -10, 1, 0)
    pointsLabel.Position = UDim2.new(0.7, 0, 0, 0)
    pointsLabel.BackgroundTransparency = 1
    pointsLabel.Text = "+" .. tostring(result.pointsEarned or 0) .. " pts"
    pointsLabel.TextColor3 = COLORS.accent
    pointsLabel.Font = Enum.Font.GothamBold
    pointsLabel.TextSize = 18
    pointsLabel.TextXAlignment = Enum.TextXAlignment.Right
    pointsLabel.Parent = row

    return row
end

-- Removed lobby leaderboard UI (uses physical screen in lobby instead)
-- Removed overhead displays

return LeaderboardUIController
