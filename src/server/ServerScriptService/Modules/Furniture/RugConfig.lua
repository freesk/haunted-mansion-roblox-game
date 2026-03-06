--[[
	Rug Furniture Configuration

	Defines how rugs should be spawned in the mansion
]]

local RugConfig = {}

-- Category name for logging
RugConfig.categoryName = "Rugs"

-- Explicit model names from asset pack
-- Add the exact model names you want to use as rugs
RugConfig.modelNames = {
	"Rug 2",
	"Rug 4",
}

-- Spawn rules
RugConfig.spawnRules = {
	-- Where can this spawn? (floor, wall, ceiling)
	location = "floor",

	-- Can spawn in stairs rooms?
	allowStairs = false,

	-- Can spawn in dead-end rooms?
	allowDeadEnds = true,

	-- Can spawn in hallway rooms?
	allowHallways = true,

	-- Minimum connections required (nil = any)
	minConnections = nil,
	maxConnections = nil,

	-- Spawn chance (0-1)
	spawnChance = 0.5, -- Increased from 0.3 to make rugs more common
}

-- Positioning in room local space
RugConfig.positioning = {
	-- Y position (floor=0.5, ceiling=15.5)
	y = 0.5,

	-- X offset range from room center
	xMin = -8,
	xMax = 8,

	-- Z offset range from room center
	zMin = -8,
	zMax = 8,

	-- Rotation options (in degrees)
	rotations = {0, 45, 90, 135, 180, 225, 270, 315}, -- Any angle

	-- Additional Y offset (for fine-tuning)
	yOffset = 0.1, -- Slightly above floor to prevent z-fighting
}

return RugConfig
