--[[
    LeaderboardEvents - RemoteEvents for leaderboard communication

    Client-server communication for leaderboard updates and results display
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create Remotes folder if it doesn't exist
local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not RemotesFolder then
    RemotesFolder = Instance.new("Folder")
    RemotesFolder.Name = "Remotes"
    RemotesFolder.Parent = ReplicatedStorage
end

-- Create RemoteEvents
local LeaderboardEvents = {}

-- LeaderboardUpdate: Server sends full leaderboard data to clients
LeaderboardEvents.LeaderboardUpdate = RemotesFolder:FindFirstChild("LeaderboardUpdate")
if not LeaderboardEvents.LeaderboardUpdate then
    LeaderboardEvents.LeaderboardUpdate = Instance.new("RemoteEvent")
    LeaderboardEvents.LeaderboardUpdate.Name = "LeaderboardUpdate"
    LeaderboardEvents.LeaderboardUpdate.Parent = RemotesFolder
end

-- ResultsDisplay: Server sends end-of-round results to clients
LeaderboardEvents.ResultsDisplay = RemotesFolder:FindFirstChild("ResultsDisplay")
if not LeaderboardEvents.ResultsDisplay then
    LeaderboardEvents.ResultsDisplay = Instance.new("RemoteEvent")
    LeaderboardEvents.ResultsDisplay.Name = "ResultsDisplay"
    LeaderboardEvents.ResultsDisplay.Parent = RemotesFolder
end

return LeaderboardEvents
