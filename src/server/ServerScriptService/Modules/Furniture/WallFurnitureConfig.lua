--[[
	Wall Furniture Configuration

	Bookshelves, display cases, chairs, tables that go against walls
]]

local WallFurnitureConfig = {}

-- Category name for logging
WallFurnitureConfig.categoryName = "Wall Furniture"

-- Explicit model names from asset pack
-- Add the exact model names you want to use as wall furniture
WallFurnitureConfig.modelNames = {
	"Furniture_Bookshelf_A",
	"DiningRoom_Chair",
	"Furniture_FloorLamp_On",
	"Furniture_FloorLamp_Off",
}

-- Spawn rules
WallFurnitureConfig.spawnRules = {
	-- Where can this spawn? (floor, wall, ceiling)
	location = "wall",

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
	spawnChance = 0.5,
}

-- Positioning in room local space
WallFurnitureConfig.positioning = {
	-- Y position (floor=0.5)
	y = 0.5,

	-- Distance from wall (room walls at ±15)
	wallOffset = 12, -- 3 studs from wall

	-- Corner positions (for floor lamps)
	-- Room is 30x30, walls at ±15, corners at approximately ±11, ±11
	corners = {
		{x = -11, z = -11, rotation = 45},  -- NW corner
		{x = 11, z = -11, rotation = 315},  -- NE corner
		{x = 11, z = 11, rotation = 225},   -- SE corner
		{x = -11, z = 11, rotation = 135},  -- SW corner
	},

	-- Possible wall positions along each wall
	-- Avoid center (x=0 or z=0) where doorways are located
	walls = {
		-- North wall (Z = -12, facing south)
		north = {
			positions = {
				{x = -8, rotation = 0},  -- Left
				{x = 8, rotation = 0},   -- Right
			}
		},
		-- East wall (X = 12, facing west)
		east = {
			positions = {
				{z = -8, rotation = 270}, -- Top
				{z = 8, rotation = 270},  -- Bottom
			}
		},
		-- South wall (Z = 12, facing north)
		south = {
			positions = {
				{x = -8, rotation = 180}, -- Left
				{x = 8, rotation = 180},  -- Right
			}
		},
		-- West wall (X = -12, facing east)
		west = {
			positions = {
				{z = -8, rotation = 90}, -- Top
				{z = 8, rotation = 90},  -- Bottom
			}
		},
	},

	-- Additional Y offset
	yOffset = 0,
}

return WallFurnitureConfig
