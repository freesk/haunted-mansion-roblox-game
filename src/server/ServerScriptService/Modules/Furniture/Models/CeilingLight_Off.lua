return {
	-- Model name (must match asset pack exactly)
	modelName = "CeilingLight_Off",

	-- Category for spawning logic
	category = "ceilingLight",

	-- Where to spawn
	locationType = "ceiling",

	-- Position offsets from room center
	position = {
		xMin = -2,
		xMax = 2,
		zMin = -2,
		zMax = 2,
		y = 15, -- Hanging from ceiling
	},

	-- Rotation (ceiling lights typically don't need rotation)
	rotations = {0},

	-- Spawn conditions
	conditions = {
		allowStairs = false,
		requiresDeadEnd = false,
	}
}
