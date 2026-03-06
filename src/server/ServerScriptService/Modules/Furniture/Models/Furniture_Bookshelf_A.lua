return {
	-- Model name (must match asset pack exactly)
	modelName = "Furniture_Bookshelf_A",

	-- Category for spawning logic
	category = "wallFurniture",

	-- Where to spawn
	locationType = "wall",

	-- Wall offset from center (will be placed on walls without doorways)
	position = {
		wallOffset = 2, -- 3 studs from wall (walls at ±15)
		y = 7, -- Raised above floor level
	},

	-- Wall-specific rotations (will be set based on which wall)
	wallRotations = {
		north = 180, -- Rotated 180 deg
		east = 90,   -- Rotated 180 deg
		south = 0,   -- Rotated 180 deg
		west = 270,  -- Rotated 180 deg
	},

	-- Spawn conditions
	conditions = {
		allowStairs = false,
		requiresDeadEnd = false,
		avoidDoorways = true, -- Only spawn on walls without doorways
		avoidWindows = true, -- Only spawn on walls without windows
	}
}
