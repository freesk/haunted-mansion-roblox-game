--[[
    SecurityService

    Handles RemoteEvent validation and rate limiting to prevent exploits.

    Key patterns:
    - Rate limiting per player (max 10 calls/second)
    - Type validation helpers
    - NaN detection
    - Instance blocking (can't serialize)
    - ValidateAndExecute wrapper for RemoteEvents

    Usage:
        SecurityService:ValidateAndExecute(remoteEvent, function(player, ...)
            -- Validation
            assert(type(arg1) == "string", "Invalid type")

            -- Server-authoritative logic
            local serverValue = SERVER_CONSTANTS[arg1]
            -- Process with server value, never trust client
        end)
]]

local SecurityService = {}
SecurityService.__index = SecurityService

-- Configuration
local MAX_CALLS_PER_SECOND = 10
local RATE_LIMIT_WINDOW = 1 -- seconds

-- Rate limiting storage
-- Structure: { [player] = { calls = number, lastReset = tick() } }
local rateLimitData = {}

--[[
    Type validation helpers
]]

function SecurityService:ValidateString(value, fieldName, maxLength)
    if type(value) ~= "string" then
        return false, string.format("%s must be a string", fieldName or "Value")
    end

    if maxLength and #value > maxLength then
        return false, string.format("%s exceeds max length of %d", fieldName or "Value", maxLength)
    end

    return true, value
end

function SecurityService:ValidateNumber(value, fieldName, min, max)
    if type(value) ~= "number" then
        return false, string.format("%s must be a number", fieldName or "Value")
    end

    -- NaN detection: NaN is the only value where value ~= value
    if value ~= value then
        return false, string.format("%s is NaN (not a number)", fieldName or "Value")
    end

    if min and value < min then
        return false, string.format("%s must be at least %d", fieldName or "Value", min)
    end

    if max and value > max then
        return false, string.format("%s must be at most %d", fieldName or "Value", max)
    end

    return true, value
end

function SecurityService:ValidateTable(value, fieldName)
    if type(value) ~= "table" then
        return false, string.format("%s must be a table", fieldName or "Value")
    end

    return true, value
end

function SecurityService:ValidateBoolean(value, fieldName)
    if type(value) ~= "boolean" then
        return false, string.format("%s must be a boolean", fieldName or "Value")
    end

    return true, value
end

--[[
    Checks if value is an Instance (which can't be serialized safely)
    Instances should never be passed through RemoteEvents
]]
function SecurityService:IsInstance(value)
    return typeof(value) == "Instance"
end

function SecurityService:ValidateNoInstances(data, path)
    path = path or "data"

    if self:IsInstance(data) then
        return false, string.format("%s contains Instance object (not allowed)", path)
    end

    if type(data) == "table" then
        for key, value in pairs(data) do
            if self:IsInstance(value) then
                return false, string.format("%s.%s contains Instance object (not allowed)", path, tostring(key))
            end

            if type(value) == "table" then
                local success, err = self:ValidateNoInstances(value, path .. "." .. tostring(key))
                if not success then
                    return false, err
                end
            end
        end
    end

    return true, nil
end

--[[
    Rate limiting per player
    Returns: (isAllowed: boolean, reason: string?)
]]
function SecurityService:CheckRateLimit(player)
    local userId = player.UserId
    local now = tick()

    -- Initialize or reset rate limit data
    if not rateLimitData[userId] then
        rateLimitData[userId] = { calls = 0, lastReset = now }
    end

    local data = rateLimitData[userId]

    -- Reset window if enough time has passed
    if now - data.lastReset >= RATE_LIMIT_WINDOW then
        data.calls = 0
        data.lastReset = now
    end

    -- Check if rate limit exceeded
    if data.calls >= MAX_CALLS_PER_SECOND then
        return false, "Rate limit exceeded"
    end

    -- Increment call count
    data.calls = data.calls + 1

    return true, nil
end

--[[
    Cleans up rate limit data when player leaves
]]
function SecurityService:CleanupPlayer(player)
    local userId = player.UserId
    rateLimitData[userId] = nil
end

--[[
    ValidateAndExecute wrapper for RemoteEvents

    This is the main pattern to use for all RemoteEvents:

    Example:
        SecurityService:ValidateAndExecute(MyRemote, function(player, data)
            -- Your validation
            assert(type(data) == "table", "Invalid data type")
            assert(type(data.action) == "string", "Invalid action")

            -- NaN check
            if type(data.value) == "number" then
                assert(data.value == data.value, "NaN detected")
            end

            -- Server-authoritative logic
            local serverValue = SERVER_CONSTANTS[data.action]
            -- Process with serverValue, never use data.value directly
        end)

    The wrapper automatically:
    - Rate limits the player
    - Catches validation errors
    - Logs security violations
    - Prevents execution on failed validation
]]
function SecurityService:ValidateAndExecute(remoteEvent, handler)
    remoteEvent.OnServerEvent:Connect(function(player, ...)
        -- Rate limiting check
        local allowed, reason = self:CheckRateLimit(player)
        if not allowed then
            warn(string.format("[SecurityService] Rate limit exceeded for %s (%s)", player.Name, reason))
            return
        end

        -- Execute handler with pcall to catch validation errors
        local success, err = pcall(handler, player, ...)

        if not success then
            warn(string.format("[SecurityService] Validation failed for %s: %s", player.Name, tostring(err)))
            -- Could track repeated violations here for kick/ban
        end
    end)
end

--[[
    Initialize SecurityService
]]
function SecurityService:Init()
    print("[SecurityService] Initialized - rate limit: " .. MAX_CALLS_PER_SECOND .. " calls/second")

    -- Clean up rate limit data when players leave
    game.Players.PlayerRemoving:Connect(function(player)
        self:CleanupPlayer(player)
    end)
end

return SecurityService
