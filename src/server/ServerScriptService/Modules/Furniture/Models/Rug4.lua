return {
	-- Model name (must match asset pack exactly)
	modelName = "Rug 4",

	-- Category for spawning logic
	category = "rug",

	-- Where to spawn (floor, wall, ceiling, corner)
	locationType = "floor",

	-- Position offsets from room center (room space)
	position = {
		xMin = -4,
		xMax = 4,
		zMin = -4,
		zMax = 4,
		y = 0.6, -- Floor position + slight offset
	},

	-- Rotation options (degrees)
	rotations = {0, 45, 90, 135, 180, 225, 270, 315},

	-- Spawn conditions
	conditions = {
		allowStairs = false,
		requiresDeadEnd = false,
	}
}
