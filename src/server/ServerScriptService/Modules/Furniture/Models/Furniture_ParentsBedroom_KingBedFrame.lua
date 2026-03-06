return {
	-- Model name (must match asset pack exactly)
	modelName = "Furniture_ParentsBedroom_KingBedFrame",

	-- Category for spawning logic
	category = "bed",

	-- Where to spawn
	locationType = "center",

	-- Center position (bed spawns in center of room)
	centerPosition = {
		x = 0,
		z = 0,
	},

	-- Rotation options (choose one randomly)
	rotations = {0, 90, 180, 270},

	-- Y position
	position = {
		y = 1.5, -- Floor level
	},

	-- Spawn conditions
	conditions = {
		allowStairs = false,
		requiresDeadEnd = true, -- Only in dead-end rooms (must spawn)
	}
}
