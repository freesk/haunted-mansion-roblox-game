--[[
	Ceiling Light Furniture Configuration

	Lights/lamps/chandeliers that hang from ceiling or stand on floor
]]

local LightConfig = {}

-- Category name for logging
LightConfig.categoryName = "Lights"

-- Explicit model names from asset pack
-- Add the exact model names you want to use as ceiling lights
LightConfig.modelNames = {
	"CeilingLight",
	"CeilingLight_Off",
}

-- Spawn rules
LightConfig.spawnRules = {
	-- Where can this spawn? (floor, wall, ceiling)
	location = "ceiling", -- All lights in this config hang from ceiling

	-- Can spawn in stairs rooms?
	allowStairs = false,

	-- Can spawn in dead-end rooms?
	allowDeadEnds = true,

	-- Can spawn in hallway rooms?
	allowHallways = true,

	-- Any number of connections
	minConnections = nil,
	maxConnections = nil,

	-- Spawn chance (0-1)
	spawnChance = 0.4,
}

-- Positioning in room local space
LightConfig.positioning = {
	-- Ceiling lights hang from center of room
	y = 14, -- Hanging 1.5 studs below ceiling (ceiling bottom is at 15.5)
	xMin = -2,
	xMax = 2,
	zMin = -2,
	zMax = 2,
	yOffset = 0,
}

return LightConfig
