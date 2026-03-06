--[[
	MansionConfig - Shared mansion constants

	These constants define the physical structure of the mansion.
	Used by both MansionGenerator and Butler system to ensure consistency.
]]

local MansionConfig = {}

-- Grid configuration
MansionConfig.GRID_WIDTH = 3
MansionConfig.GRID_DEPTH = 6
MansionConfig.NUM_LEVELS = 3

-- Room dimensions
MansionConfig.ROOM_SIZE = 30
MansionConfig.WALL_HEIGHT = 16
MansionConfig.WALL_THICKNESS = 1
MansionConfig.LEVEL_HEIGHT = 16 -- Same as wall height so levels connect properly

-- Doorway size
MansionConfig.DOORWAY_WIDTH = 6
MansionConfig.DOORWAY_HEIGHT = 9.6 -- 60% of wall height

-- Window size (if used)
MansionConfig.WINDOW_WIDTH = 6
MansionConfig.WINDOW_HEIGHT = 7
MansionConfig.WINDOW_Y_OFFSET = 5

-- Stair configuration
MansionConfig.NUM_STEPS = 20
MansionConfig.STEP_WIDTH = 7
MansionConfig.STEP_RUN = 15 / MansionConfig.NUM_STEPS -- Horizontal depth per step

-- Calculated values
MansionConfig.STEP_RISE = MansionConfig.WALL_HEIGHT / MansionConfig.NUM_STEPS -- Height per step

-- Gothic wallpaper textures (Roblox asset IDs)
MansionConfig.WALL_TEXTURES = {
	"rbxassetid://8546348110",
	"rbxassetid://6734214691",
	"rbxassetid://6382588788",
	"rbxassetid://5683564977",
	"rbxassetid://7673806688",
}

-- Gothic color schemes (background colors for the wallpapers)
MansionConfig.WALL_COLORS = {
	Color3.fromRGB(60, 40, 50),   -- Dark maroon
	Color3.fromRGB(40, 50, 60),   -- Dark slate blue
	Color3.fromRGB(50, 40, 40),   -- Dark brown
	Color3.fromRGB(40, 60, 50),   -- Dark teal
	Color3.fromRGB(50, 50, 40),   -- Dark olive
}

return MansionConfig
