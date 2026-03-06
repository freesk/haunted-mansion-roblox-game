--[[
	MonsterConfig - Configuration for wandering monster NPCs

	All constants and tunable values for the monster system.
]]

local MonsterConfig = {}

-- Monster model configuration
MonsterConfig.ASSET_ID = 139856226151338
MonsterConfig.ANIM_IDLE = 133400548576175
MonsterConfig.ANIM_WALK = 89456474863232
MonsterConfig.SCALE = 0.07

-- Spawn configuration
MonsterConfig.MANSION_Y_OFFSET = -2.9 -- Y offset when spawning in mansion (relative to spawn point)

-- Movement configuration
MonsterConfig.WALK_SPEED = 8 -- Studs per second
MonsterConfig.TURN_SPEED = 2 -- Radians per second (currently unused)

-- Wandering AI parameters
MonsterConfig.ENABLE_WANDERING = true -- Set to false to keep monster stationary for debugging
MonsterConfig.INITIAL_WAIT = 3 -- Seconds to wait before starting to wander (so players can see spawn location)
MonsterConfig.WANDER_MIN_WAIT = 2 -- Min seconds between direction changes
MonsterConfig.WANDER_MAX_WAIT = 5 -- Max seconds between direction changes
MonsterConfig.WALK_CHANCE = 0.7 -- Probability to walk (0.0-1.0), vs staying idle
MonsterConfig.WANDER_MIN_DISTANCE = 10 -- Min studs to walk
MonsterConfig.WANDER_MAX_DISTANCE = 20 -- Max studs to walk

-- Health and display
MonsterConfig.HEALTH = 100
MonsterConfig.MAX_HEALTH = 100

-- Physical properties (opposite of butler - monster is physical)
MonsterConfig.ENABLE_COLLISION = true -- Monster collides with walls
MonsterConfig.ENABLE_SHADOWS = true -- Monster casts shadows
MonsterConfig.ANCHORED = false -- Parts should not be anchored

return MonsterConfig
