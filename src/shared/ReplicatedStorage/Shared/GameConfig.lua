--[[
    GameConfig

    Central configuration for game constants.
    All configurable values should live here to avoid magic numbers in code.

    Performance budgets from PERFORMANCE_BUDGET.md are enforced here.
]]

local GameConfig = {
    --[[
        PERFORMANCE LIMITS
        Based on PERFORMANCE_BUDGET.md
    ]]
    MAX_PARTS_TOTAL = 10000,        -- Total parts allowed in Workspace
    MAX_PARTS_PER_MANSION = 500,    -- Parts per mansion model
    TARGET_FPS_MOBILE = 30,         -- Minimum acceptable FPS on mobile
    MAX_MEMORY_MB = 500,            -- Memory limit on mobile devices
    MAX_NETWORK_KB_PER_SEC = 50,    -- Network bandwidth per player

    --[[
        GAME SETTINGS
    ]]
    MIN_PLAYERS_TO_START = 1,       -- Minimum players to start a round (set to 1 for solo testing)
    MAX_PLAYERS_PER_GAME = 8,       -- Maximum players in a game
    ROUND_DURATION = 600,           -- Round time limit in seconds (10 minutes)

    --[[
        SEPARATION MECHANICS
        Placeholder values for Phase 3 implementation
        These will need playtesting/balancing during Phase 3
    ]]
    MAX_SEPARATION_DISTANCE = 50,   -- Studs before separation warning triggers
    DEATH_TIMER_DURATION = 10,      -- Seconds until death after separation
    SEPARATION_WARNING_TIME = 5,    -- Warning time before death timer starts
    REUNION_GRACE_PERIOD = 2,       -- Seconds player has to rejoin group

    --[[
        CONTENT RATING
        Based on game.toml configuration
    ]]
    CONTENT_MATURITY = "Mild",      -- Roblox content rating
    MIN_AGE = 10,                   -- Minimum recommended age
    MAX_AGE = 14,                   -- Maximum target age

    --[[
        MONETIZATION
        Placeholder for Phase 4 implementation
    ]]
    REVIVE_TOKEN_PRICE = 25,        -- Robux per revive token (placeholder)
    FREE_TOKENS_PER_DAY = 1,        -- Free tokens earned daily (placeholder)

    --[[
        MANSION PROGRESSION
        Difficulty scaling configuration
    ]]
    STARTING_MANSION_ID = 1,        -- First mansion unlocked
    TOTAL_MANSIONS = 3,             -- Total mansions at launch

    --[[
        POINTS SYSTEM
    ]]
    POINTS_PER_SURVIVOR = 100,      -- Points awarded per living teammate
    POINTS_FOR_COMPLETION = 500,    -- Bonus for completing mansion
    POINTS_SPEED_BONUS_MAX = 200,   -- Max bonus for fast completion

    --[[
        RATE LIMITING
        Security configuration
    ]]
    MAX_REMOTE_CALLS_PER_SECOND = 10,  -- Rate limit for RemoteEvents
}

-- Freeze the table to prevent modifications at runtime
-- This ensures config values can't be changed by exploiters
table.freeze(GameConfig)

return GameConfig
