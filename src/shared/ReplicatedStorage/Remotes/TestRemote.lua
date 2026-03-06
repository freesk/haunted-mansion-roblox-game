--[[
    TestRemote

    Example RemoteEvent demonstrating SecurityService validation pattern.

    This shows how to properly validate client data and use server-authoritative values.

    Key principles:
    1. Server validates ALL parameters
    2. Server never trusts client-provided values
    3. Server looks up authoritative values from constants
    4. Use NaN checks for numbers
    5. Block Instance objects

    IMPORTANT: Never pass prices, points, or critical game values through remotes.
    Always look them up server-side from authoritative constants.
]]

-- This would be initialized on the server like this:
--[[
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local SecurityService = require(script.Parent.Parent.Services.SecurityService)
    local TestRemote = ReplicatedStorage.Remotes.TestRemote

    -- Example server constants (never trust client values)
    local SERVER_CONSTANTS = {
        ["action_a"] = 100,
        ["action_b"] = 250,
        ["action_c"] = 500
    }

    SecurityService:ValidateAndExecute(TestRemote, function(player, data)
        -- Step 1: Validate structure
        assert(type(data) == "table", "Invalid data type")
        assert(type(data.action) == "string", "Invalid action")
        assert(type(data.value) == "number", "Invalid value type")

        -- Step 2: NaN check
        assert(data.value == data.value, "NaN detected")

        -- Step 3: Validate action exists
        local serverValue = SERVER_CONSTANTS[data.action]
        assert(serverValue ~= nil, "Unknown action")

        -- Step 4: Process with SERVER value, ignore client value
        -- This is critical: client said data.value but we use serverValue
        print(string.format("Player %s triggered %s worth %d points",
            player.Name, data.action, serverValue))

        -- Award the SERVER-AUTHORITATIVE value
        -- PlayerService:AddPlayerPoints(player, serverValue)
    end)
]]

-- RemoteEvent creation (this creates the actual RemoteEvent instance)
local TestRemote = Instance.new("RemoteEvent")
TestRemote.Name = "TestRemote"

return TestRemote
