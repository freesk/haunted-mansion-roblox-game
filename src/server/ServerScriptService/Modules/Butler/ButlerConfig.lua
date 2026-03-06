--[[
	ButlerConfig - Configuration for butler NPC behavior

	All constants and tunable values for the butler system.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MansionConfig = require(ReplicatedStorage.Shared.MansionConfig)

local ButlerConfig = {}

-- Butler model configuration
ButlerConfig.ASSET_ID = 83066860631288
ButlerConfig.ANIMATION_ID = 137664043559370
ButlerConfig.MODEL_NAME = "OldButlerNpc"
ButlerConfig.SCALE = 0.17

ButlerConfig.MANSION_Y_OFFSET = 0.0 -- Y offset in mansion

-- Movement configuration
ButlerConfig.WALK_SPEED = 4 -- Studs per second
ButlerConfig.WAYPOINT_REACH_DISTANCE = 2 -- Distance to consider waypoint reached

-- Lantern configuration
ButlerConfig.LANTERN_ASSET_ID = 11865884168 -- Lantern model asset ID
ButlerConfig.LANTERN_OFFSET_X = 0.07 -- Right/Left offset from hand
ButlerConfig.LANTERN_OFFSET_Y = 0.01 -- Up/Down offset from hand
ButlerConfig.LANTERN_OFFSET_Z = -0.14 -- Forward/Back offset from hand
ButlerConfig.LANTERN_ROTATION_X = -105 -- Pitch rotation (degrees)
ButlerConfig.LANTERN_ROTATION_Y = -42 -- Yaw rotation (degrees)
ButlerConfig.LANTERN_ROTATION_Z = -72 -- Roll rotation (degrees)
ButlerConfig.LANTERN_LIGHT_BRIGHTNESS = 2 -- Light brightness
ButlerConfig.LANTERN_LIGHT_RANGE = 20 -- Light range in studs

-- Floor Y coordinates (relative to mansion base)
-- These define where the butler walks on each floor
-- Uses LEVEL_HEIGHT from shared MansionConfig
ButlerConfig.FLOOR_Y_COORDINATES = {
	[1] = 0,                                       -- Floor 1: ground level
	[2] = MansionConfig.LEVEL_HEIGHT,              -- Floor 2: one level up (16)
	[3] = MansionConfig.LEVEL_HEIGHT * 2,          -- Floor 3: two levels up (32)
}

return ButlerConfig
