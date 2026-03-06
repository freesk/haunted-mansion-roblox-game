--[[
	GhostConfig - Configuration for ghost NPCs

	All constants and tunable values for the ghost system.
	Ghosts float through walls and don't use animations.
]]

local GhostConfig = {}

-- Ghost model configuration
GhostConfig.ASSET_ID = 92620712102887
GhostConfig.SCALE = 5.5 -- Scaled to proper size (calibrated via debug UI)
GhostConfig.ROTATION_OFFSET = CFrame.Angles(math.rad(90), math.rad(0), math.rad(90 + 180)) -- Rotate upright on X axis, then 90 degrees counterclockwise on Y axis

-- Sound configuration
GhostConfig.SOUND_ID = "rbxassetid://140647300371466" -- Ghost whisper/moan sound

-- Spawn configuration
GhostConfig.MANSION_Y_OFFSET = -1 -- Y offset when spawning in mansion

-- Movement configuration
GhostConfig.FLOAT_SPEED = 6 -- Studs per second (slower than monster)
GhostConfig.FLOAT_HEIGHT_VARIATION = 1 -- Studs up/down amplitude while floating
GhostConfig.FLOAT_BOB_SPEED = 0.5 -- Cycles per second for up/down bobbing (higher = faster bobbing)

-- Floating AI parameters
GhostConfig.ENABLE_WANDERING = true
GhostConfig.INITIAL_WAIT = 2 -- Seconds to wait before starting to wander
GhostConfig.WANDER_MIN_WAIT = 3 -- Min seconds between direction changes
GhostConfig.WANDER_MAX_WAIT = 7 -- Max seconds between direction changes
GhostConfig.FLOAT_CHANCE = 0.8 -- Probability to float (vs staying idle)
GhostConfig.WANDER_MIN_DISTANCE = 15 -- Min studs to float
GhostConfig.WANDER_MAX_DISTANCE = 30 -- Max studs to float

-- Physical properties (ghosts phase through walls)
GhostConfig.ENABLE_COLLISION = false -- Ghost phases through walls
GhostConfig.ENABLE_SHADOWS = false -- Ghosts don't cast shadows
GhostConfig.ANCHORED = false
GhostConfig.CAN_COLLIDE = false -- All parts non-collidable
GhostConfig.TRANSPARENCY_ADJUSTMENT = 0.0 -- No transparency adjustment for debugging visibility

return GhostConfig
