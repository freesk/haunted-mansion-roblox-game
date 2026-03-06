return {
	-- Model name (must match asset pack exactly)
	modelName = "Furniture_FloorLamp_On",

	-- Category for spawning logic
	category = "floorLamp",

	-- Where to spawn
	locationType = "corner",

	-- Corner positions (one will be chosen randomly)
	cornerPositions = {
		{x = -11, z = -11, rotation = 45, name = "NW"},
		{x = 11, z = -11, rotation = 315, name = "NE"},
		{x = 11, z = 11, rotation = 225, name = "SE"},
		{x = -11, z = 11, rotation = 135, name = "SW"},
	},

	-- Y position
	position = {
		y = 3.5, -- Floor level
	},

	-- Spawn conditions
	conditions = {
		allowStairs = false,
		requiresDeadEnd = false,
	}
}
