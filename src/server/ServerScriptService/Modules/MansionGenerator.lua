--[[
	Simple Mansion Generator

	Creates 3 levels of 3x6 rooms with stairs connecting them
	- Random start point (spawn)
	- Random connection points between levels (opposite sides)
	- Final teleport marker at end
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MansionConfig = require(ReplicatedStorage.Shared.MansionConfig)

local MansionGenerator = {}

-- Use shared mansion configuration
local GRID_WIDTH = MansionConfig.GRID_WIDTH
local GRID_DEPTH = MansionConfig.GRID_DEPTH
local NUM_LEVELS = MansionConfig.NUM_LEVELS
local ROOM_SIZE = MansionConfig.ROOM_SIZE
local WALL_HEIGHT = MansionConfig.WALL_HEIGHT
local WALL_THICKNESS = MansionConfig.WALL_THICKNESS
local LEVEL_HEIGHT = MansionConfig.LEVEL_HEIGHT
local DOORWAY_WIDTH = MansionConfig.DOORWAY_WIDTH
local DOORWAY_HEIGHT = MansionConfig.DOORWAY_HEIGHT
local WALL_TEXTURES = MansionConfig.WALL_TEXTURES
local WALL_COLORS = MansionConfig.WALL_COLORS

--[[
	Applies a wallpaper texture to a wall part (only if valid texture ID)
	@param wall Part - The wall to apply texture to
	@param textureId string - The texture asset ID
	@param face Enum.NormalId - Which face to apply to
]]
local function ApplyWallTexture(wall, textureId, face)
	-- Only apply if it's a valid texture ID (not placeholder)
	if textureId and not textureId:match("YOUR_TEXTURE_ID") then
		local decal = Instance.new("Decal")
		decal.Texture = textureId
		decal.Face = face
		decal.Color3 = Color3.fromRGB(255, 255, 255)
		decal.Transparency = 0
		decal.Parent = wall
	end
end

--[[
	Creates a basic room with 4 walls, floor, and ceiling
]]
local function CreateRoom(x, z, level)
	local room = Instance.new("Model")
	room.Name = string.format("Room_L%d_X%d_Z%d", level, x, z)

	-- Pick a random wallpaper style for this room
	local styleIndex = math.random(1, #WALL_TEXTURES)
	local wallTextureId = WALL_TEXTURES[styleIndex]
	local wallColor = WALL_COLORS[styleIndex]
	room:SetAttribute("WallTextureId", wallTextureId)
	room:SetAttribute("WallColor", wallColor)

	-- Floor (0.5 thick, positioned at bottom of room)
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(ROOM_SIZE, 0.5, ROOM_SIZE)
	floor.CFrame = CFrame.new(0, 0.25, 0) -- Positioned so bottom is at Y=0, top at Y=0.5
	floor.Color = Color3.fromRGB(120, 90, 60) -- Lighter brown wood color
	floor.Material = Enum.Material.WoodPlanks
	floor.Anchored = true
	floor.Parent = room

	-- Ceiling (0.5 thick, positioned at top of room)
	local ceiling = Instance.new("Part")
	ceiling.Name = "Ceiling"
	ceiling.Size = Vector3.new(ROOM_SIZE, 0.5, ROOM_SIZE)
	ceiling.CFrame = CFrame.new(0, WALL_HEIGHT - 0.25, 0) -- Positioned so bottom is at Y=15.5, top at Y=16
	ceiling.Color = Color3.fromRGB(40, 40, 50) -- Darker gray stone color
	ceiling.Material = Enum.Material.Slate
	ceiling.Anchored = true
	ceiling.Parent = room

	-- North Wall
	local northWall = Instance.new("Part")
	northWall.Name = "WallNorth"
	northWall.Size = Vector3.new(ROOM_SIZE, WALL_HEIGHT, WALL_THICKNESS)
	northWall.CFrame = CFrame.new(0, WALL_HEIGHT/2, -ROOM_SIZE/2)
	northWall.Color = wallColor
	northWall.Material = Enum.Material.SmoothPlastic
	northWall.Anchored = true
	northWall.Parent = room
	ApplyWallTexture(northWall, wallTextureId, Enum.NormalId.Back) -- Inside face

	-- South Wall
	local southWall = Instance.new("Part")
	southWall.Name = "WallSouth"
	southWall.Size = Vector3.new(ROOM_SIZE, WALL_HEIGHT, WALL_THICKNESS)
	southWall.CFrame = CFrame.new(0, WALL_HEIGHT/2, ROOM_SIZE/2)
	southWall.Color = wallColor
	southWall.Material = Enum.Material.SmoothPlastic
	southWall.Anchored = true
	southWall.Parent = room
	ApplyWallTexture(southWall, wallTextureId, Enum.NormalId.Front) -- Inside face

	-- East Wall
	local eastWall = Instance.new("Part")
	eastWall.Name = "WallEast"
	eastWall.Size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, ROOM_SIZE)
	eastWall.CFrame = CFrame.new(ROOM_SIZE/2, WALL_HEIGHT/2, 0)
	eastWall.Color = wallColor
	eastWall.Material = Enum.Material.SmoothPlastic
	eastWall.Anchored = true
	eastWall.Parent = room
	ApplyWallTexture(eastWall, wallTextureId, Enum.NormalId.Left) -- Inside face

	-- West Wall
	local westWall = Instance.new("Part")
	westWall.Name = "WallWest"
	westWall.Size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, ROOM_SIZE)
	westWall.CFrame = CFrame.new(-ROOM_SIZE/2, WALL_HEIGHT/2, 0)
	westWall.Color = wallColor
	westWall.Material = Enum.Material.SmoothPlastic
	westWall.Anchored = true
	westWall.Parent = room
	ApplyWallTexture(westWall, wallTextureId, Enum.NormalId.Right) -- Inside face

	-- Set PrimaryPart to floor so pivot calculations use floor as reference
	-- This prevents Roblox from auto-calculating pivot at geometric center
	room.PrimaryPart = floor

	return room
end

--[[
	Cuts a window in an outer wall with a cross frame
]]
local function CutWindow(room, wallName)
	local wall = room:FindFirstChild(wallName)
	if not wall then return end

	-- Get the wallpaper style for this room
	local wallTextureId = room:GetAttribute("WallTextureId")
	local wallColor = room:GetAttribute("WallColor") or Color3.fromRGB(80, 80, 100)

	local WINDOW_WIDTH = MansionConfig.WINDOW_WIDTH
	local WINDOW_HEIGHT = MansionConfig.WINDOW_HEIGHT
	local WINDOW_Y_OFFSET = MansionConfig.WINDOW_Y_OFFSET
	local FRAME_THICKNESS = 0.3 -- Window frame border thickness
	local FRAME_DEPTH = WALL_THICKNESS + 0.6 -- Frame extends 0.3 studs on each side

	wall:Destroy()

	local roomPivot = room:GetPivot()

	if wallName == "WallNorth" or wallName == "WallSouth" then
		local zPos = (wallName == "WallNorth") and -ROOM_SIZE/2 or ROOM_SIZE/2
		local insideFace = (wallName == "WallNorth") and Enum.NormalId.Back or Enum.NormalId.Front
		local wallSegmentWidth = (ROOM_SIZE - WINDOW_WIDTH) / 2

		-- Left segment (full height)
		local left = Instance.new("Part")
		left.Name = wallName .. "Left"
		left.Size = Vector3.new(wallSegmentWidth, WALL_HEIGHT, WALL_THICKNESS)
		left.CFrame = roomPivot * CFrame.new(-ROOM_SIZE/2 + wallSegmentWidth/2, WALL_HEIGHT/2, zPos)
		left.Color = wallColor
		left.Material = Enum.Material.SmoothPlastic
		left.Anchored = true
		left.Parent = room
		ApplyWallTexture(left, wallTextureId, insideFace)

		-- Right segment (full height)
		local right = Instance.new("Part")
		right.Name = wallName .. "Right"
		right.Size = Vector3.new(wallSegmentWidth, WALL_HEIGHT, WALL_THICKNESS)
		right.CFrame = roomPivot * CFrame.new(ROOM_SIZE/2 - wallSegmentWidth/2, WALL_HEIGHT/2, zPos)
		right.Color = wallColor
		right.Material = Enum.Material.SmoothPlastic
		right.Anchored = true
		right.Parent = room
		ApplyWallTexture(right, wallTextureId, insideFace)

		-- Bottom segment (below window)
		local bottom = Instance.new("Part")
		bottom.Name = wallName .. "Bottom"
		bottom.Size = Vector3.new(WINDOW_WIDTH, WINDOW_Y_OFFSET, WALL_THICKNESS)
		bottom.CFrame = roomPivot * CFrame.new(0, WINDOW_Y_OFFSET/2, zPos)
		bottom.Color = wallColor
		bottom.Material = Enum.Material.SmoothPlastic
		bottom.Anchored = true
		bottom.Parent = room
		ApplyWallTexture(bottom, wallTextureId, insideFace)

		-- Top segment (above window)
		local topHeight = WALL_HEIGHT - WINDOW_Y_OFFSET - WINDOW_HEIGHT
		local top = Instance.new("Part")
		top.Name = wallName .. "Top"
		top.Size = Vector3.new(WINDOW_WIDTH, topHeight, WALL_THICKNESS)
		top.CFrame = roomPivot * CFrame.new(0, WINDOW_Y_OFFSET + WINDOW_HEIGHT + topHeight/2, zPos)
		top.Color = wallColor
		top.Material = Enum.Material.SmoothPlastic
		top.Anchored = true
		top.Parent = room
		ApplyWallTexture(top, wallTextureId, insideFace)

		-- Window cross frame - vertical bar
		local crossVertical = Instance.new("Part")
		crossVertical.Name = wallName .. "CrossV"
		crossVertical.Size = Vector3.new(0.5, WINDOW_HEIGHT, FRAME_DEPTH)
		crossVertical.CFrame = roomPivot * CFrame.new(0, WINDOW_Y_OFFSET + WINDOW_HEIGHT/2, zPos)
		crossVertical.Color = Color3.fromRGB(60, 60, 60)
		crossVertical.Material = Enum.Material.Metal
		crossVertical.Anchored = true
		crossVertical.Parent = room

		-- Window cross frame - horizontal bar
		local crossHorizontal = Instance.new("Part")
		crossHorizontal.Name = wallName .. "CrossH"
		crossHorizontal.Size = Vector3.new(WINDOW_WIDTH, 0.5, FRAME_DEPTH)
		crossHorizontal.CFrame = roomPivot * CFrame.new(0, WINDOW_Y_OFFSET + WINDOW_HEIGHT/2, zPos)
		crossHorizontal.Color = Color3.fromRGB(60, 60, 60)
		crossHorizontal.Material = Enum.Material.Metal
		crossHorizontal.Anchored = true
		crossHorizontal.Parent = room

		-- Window frame - left border
		local frameLeft = Instance.new("Part")
		frameLeft.Name = wallName .. "FrameLeft"
		frameLeft.Size = Vector3.new(FRAME_THICKNESS, WINDOW_HEIGHT, FRAME_DEPTH)
		frameLeft.CFrame = roomPivot * CFrame.new(-WINDOW_WIDTH/2, WINDOW_Y_OFFSET + WINDOW_HEIGHT/2, zPos)
		frameLeft.Color = Color3.fromRGB(60, 60, 60)
		frameLeft.Material = Enum.Material.Metal
		frameLeft.Anchored = true
		frameLeft.Parent = room

		-- Window frame - right border
		local frameRight = Instance.new("Part")
		frameRight.Name = wallName .. "FrameRight"
		frameRight.Size = Vector3.new(FRAME_THICKNESS, WINDOW_HEIGHT, FRAME_DEPTH)
		frameRight.CFrame = roomPivot * CFrame.new(WINDOW_WIDTH/2, WINDOW_Y_OFFSET + WINDOW_HEIGHT/2, zPos)
		frameRight.Color = Color3.fromRGB(60, 60, 60)
		frameRight.Material = Enum.Material.Metal
		frameRight.Anchored = true
		frameRight.Parent = room

		-- Window frame - top border
		local frameTop = Instance.new("Part")
		frameTop.Name = wallName .. "FrameTop"
		frameTop.Size = Vector3.new(WINDOW_WIDTH + FRAME_THICKNESS * 2, FRAME_THICKNESS, FRAME_DEPTH)
		frameTop.CFrame = roomPivot * CFrame.new(0, WINDOW_Y_OFFSET + WINDOW_HEIGHT, zPos)
		frameTop.Color = Color3.fromRGB(60, 60, 60)
		frameTop.Material = Enum.Material.Metal
		frameTop.Anchored = true
		frameTop.Parent = room

		-- Window frame - bottom border
		local frameBottom = Instance.new("Part")
		frameBottom.Name = wallName .. "FrameBottom"
		frameBottom.Size = Vector3.new(WINDOW_WIDTH + FRAME_THICKNESS * 2, FRAME_THICKNESS, FRAME_DEPTH)
		frameBottom.CFrame = roomPivot * CFrame.new(0, WINDOW_Y_OFFSET, zPos)
		frameBottom.Color = Color3.fromRGB(60, 60, 60)
		frameBottom.Material = Enum.Material.Metal
		frameBottom.Anchored = true
		frameBottom.Parent = room

		-- Glass pane with spooky horizon image
		local glass = Instance.new("Part")
		glass.Name = wallName .. "Glass"
		glass.Size = Vector3.new(WINDOW_WIDTH, WINDOW_HEIGHT, 0.1)
		glass.CFrame = roomPivot * CFrame.new(0, WINDOW_Y_OFFSET + WINDOW_HEIGHT/2, zPos)
		glass.Color = Color3.fromRGB(200, 220, 255)
		glass.Material = Enum.Material.Glass
		glass.Transparency = 1 -- Completely invisible so particles are visible
		glass.Anchored = true
		glass.CanCollide = false
		glass.Parent = room

		-- Window glow light (subtle, sharp illumination)
		local glowLight = Instance.new("SpotLight")
		glowLight.Name = "WindowGlow"
		glowLight.Color = Color3.fromRGB(100, 160, 180) -- Blue-green tint
		glowLight.Brightness = 2 -- Reduced brightness
		glowLight.Range = 15 -- Shorter, sharper range
		glowLight.Angle = 60 -- Focused beam
		glowLight.Face = Enum.NormalId.Back -- Point into room from window
		glowLight.Shadows = true
		glowLight.Parent = glass

		-- Create rain emitters along a line above the window
		local NUM_EMITTERS = 5 -- Number of rain emitter points along window width
		local RAIN_HEIGHT_OFFSET = 3 -- How much higher than window top
		local exteriorZOffset = (wallName == "WallNorth") and -5 or 5

		for i = 0, NUM_EMITTERS - 1 do
			-- Position along window width (left to right)
			local xOffset = -WINDOW_WIDTH/2 + (WINDOW_WIDTH / (NUM_EMITTERS - 1)) * i
			local yOffset = WINDOW_HEIGHT/2 + RAIN_HEIGHT_OFFSET

			local rainAttachment = Instance.new("Attachment")
			rainAttachment.Name = "RainEmitter" .. i
			rainAttachment.Position = Vector3.new(xOffset, yOffset, exteriorZOffset)
			rainAttachment.Parent = glass

			local rain = Instance.new("ParticleEmitter")
			rain.Name = "Rain"
			rain.Texture = "rbxasset://textures/particles/smoke_main.dds"
			rain.Color = ColorSequence.new(Color3.fromRGB(180, 200, 220))
			rain.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(1, 0.5)
			})
			rain.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.4),
				NumberSequenceKeypoint.new(1, 0.3)
			})
			rain.Lifetime = NumberRange.new(1.5, 2.5)
			rain.Rate = 20 -- Lower per emitter since we have multiple
			rain.Speed = NumberRange.new(40, 50)
			rain.SpreadAngle = Vector2.new(5, 5) -- Tight spread for vertical rain
			rain.Rotation = NumberRange.new(0, 0)
			rain.RotSpeed = NumberRange.new(0, 0)
			rain.VelocityInheritance = 0
			rain.EmissionDirection = Enum.NormalId.Bottom
			rain.Acceleration = Vector3.new(0, -20, 0)
			rain.Parent = rainAttachment
		end

	elseif wallName == "WallEast" or wallName == "WallWest" then
		local xPos = (wallName == "WallEast") and ROOM_SIZE/2 or -ROOM_SIZE/2
		local insideFace = (wallName == "WallEast") and Enum.NormalId.Left or Enum.NormalId.Right
		local wallSegmentWidth = (ROOM_SIZE - WINDOW_WIDTH) / 2

		-- North segment (full height)
		local north = Instance.new("Part")
		north.Name = wallName .. "North"
		north.Size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, wallSegmentWidth)
		north.CFrame = roomPivot * CFrame.new(xPos, WALL_HEIGHT/2, -ROOM_SIZE/2 + wallSegmentWidth/2)
		north.Color = wallColor
		north.Material = Enum.Material.SmoothPlastic
		north.Anchored = true
		north.Parent = room
		ApplyWallTexture(north, wallTextureId, insideFace)

		-- South segment (full height)
		local south = Instance.new("Part")
		south.Name = wallName .. "South"
		south.Size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, wallSegmentWidth)
		south.CFrame = roomPivot * CFrame.new(xPos, WALL_HEIGHT/2, ROOM_SIZE/2 - wallSegmentWidth/2)
		south.Color = wallColor
		south.Material = Enum.Material.SmoothPlastic
		south.Anchored = true
		south.Parent = room
		ApplyWallTexture(south, wallTextureId, insideFace)

		-- Bottom segment (below window)
		local bottom = Instance.new("Part")
		bottom.Name = wallName .. "Bottom"
		bottom.Size = Vector3.new(WALL_THICKNESS, WINDOW_Y_OFFSET, WINDOW_WIDTH)
		bottom.CFrame = roomPivot * CFrame.new(xPos, WINDOW_Y_OFFSET/2, 0)
		bottom.Color = wallColor
		bottom.Material = Enum.Material.SmoothPlastic
		bottom.Anchored = true
		bottom.Parent = room
		ApplyWallTexture(bottom, wallTextureId, insideFace)

		-- Top segment (above window)
		local topHeight = WALL_HEIGHT - WINDOW_Y_OFFSET - WINDOW_HEIGHT
		local top = Instance.new("Part")
		top.Name = wallName .. "Top"
		top.Size = Vector3.new(WALL_THICKNESS, topHeight, WINDOW_WIDTH)
		top.CFrame = roomPivot * CFrame.new(xPos, WINDOW_Y_OFFSET + WINDOW_HEIGHT + topHeight/2, 0)
		top.Color = wallColor
		top.Material = Enum.Material.SmoothPlastic
		top.Anchored = true
		top.Parent = room
		ApplyWallTexture(top, wallTextureId, insideFace)

		-- Window cross frame - vertical bar
		local crossVertical = Instance.new("Part")
		crossVertical.Name = wallName .. "CrossV"
		crossVertical.Size = Vector3.new(FRAME_DEPTH, WINDOW_HEIGHT, 0.5)
		crossVertical.CFrame = roomPivot * CFrame.new(xPos, WINDOW_Y_OFFSET + WINDOW_HEIGHT/2, 0)
		crossVertical.Color = Color3.fromRGB(60, 60, 60)
		crossVertical.Material = Enum.Material.Metal
		crossVertical.Anchored = true
		crossVertical.Parent = room

		-- Window cross frame - horizontal bar
		local crossHorizontal = Instance.new("Part")
		crossHorizontal.Name = wallName .. "CrossH"
		crossHorizontal.Size = Vector3.new(FRAME_DEPTH, 0.5, WINDOW_WIDTH)
		crossHorizontal.CFrame = roomPivot * CFrame.new(xPos, WINDOW_Y_OFFSET + WINDOW_HEIGHT/2, 0)
		crossHorizontal.Color = Color3.fromRGB(60, 60, 60)
		crossHorizontal.Material = Enum.Material.Metal
		crossHorizontal.Anchored = true
		crossHorizontal.Parent = room

		-- Window frame - north border
		local frameNorth = Instance.new("Part")
		frameNorth.Name = wallName .. "FrameNorth"
		frameNorth.Size = Vector3.new(FRAME_DEPTH, WINDOW_HEIGHT, FRAME_THICKNESS)
		frameNorth.CFrame = roomPivot * CFrame.new(xPos, WINDOW_Y_OFFSET + WINDOW_HEIGHT/2, -WINDOW_WIDTH/2)
		frameNorth.Color = Color3.fromRGB(60, 60, 60)
		frameNorth.Material = Enum.Material.Metal
		frameNorth.Anchored = true
		frameNorth.Parent = room

		-- Window frame - south border
		local frameSouth = Instance.new("Part")
		frameSouth.Name = wallName .. "FrameSouth"
		frameSouth.Size = Vector3.new(FRAME_DEPTH, WINDOW_HEIGHT, FRAME_THICKNESS)
		frameSouth.CFrame = roomPivot * CFrame.new(xPos, WINDOW_Y_OFFSET + WINDOW_HEIGHT/2, WINDOW_WIDTH/2)
		frameSouth.Color = Color3.fromRGB(60, 60, 60)
		frameSouth.Material = Enum.Material.Metal
		frameSouth.Anchored = true
		frameSouth.Parent = room

		-- Window frame - top border
		local frameTop = Instance.new("Part")
		frameTop.Name = wallName .. "FrameTop"
		frameTop.Size = Vector3.new(FRAME_DEPTH, FRAME_THICKNESS, WINDOW_WIDTH + FRAME_THICKNESS * 2)
		frameTop.CFrame = roomPivot * CFrame.new(xPos, WINDOW_Y_OFFSET + WINDOW_HEIGHT, 0)
		frameTop.Color = Color3.fromRGB(60, 60, 60)
		frameTop.Material = Enum.Material.Metal
		frameTop.Anchored = true
		frameTop.Parent = room

		-- Window frame - bottom border
		local frameBottom = Instance.new("Part")
		frameBottom.Name = wallName .. "FrameBottom"
		frameBottom.Size = Vector3.new(FRAME_DEPTH, FRAME_THICKNESS, WINDOW_WIDTH + FRAME_THICKNESS * 2)
		frameBottom.CFrame = roomPivot * CFrame.new(xPos, WINDOW_Y_OFFSET, 0)
		frameBottom.Color = Color3.fromRGB(60, 60, 60)
		frameBottom.Material = Enum.Material.Metal
		frameBottom.Anchored = true
		frameBottom.Parent = room

		-- Glass pane with spooky horizon image
		local glass = Instance.new("Part")
		glass.Name = wallName .. "Glass"
		glass.Size = Vector3.new(0.1, WINDOW_HEIGHT, WINDOW_WIDTH)
		glass.CFrame = roomPivot * CFrame.new(xPos, WINDOW_Y_OFFSET + WINDOW_HEIGHT/2, 0)
		glass.Color = Color3.fromRGB(200, 220, 255)
		glass.Material = Enum.Material.Glass
		glass.Transparency = 1 -- Completely invisible so particles are visible
		glass.Anchored = true
		glass.CanCollide = false
		glass.Parent = room

		-- Window glow light (subtle, sharp illumination)
		local glowLight = Instance.new("SpotLight")
		glowLight.Name = "WindowGlow"
		glowLight.Color = Color3.fromRGB(100, 160, 180) -- Blue-green tint
		glowLight.Brightness = 2 -- Reduced brightness
		glowLight.Range = 15 -- Shorter, sharper range
		glowLight.Angle = 60 -- Focused beam
		glowLight.Face = (wallName == "WallEast") and Enum.NormalId.Left or Enum.NormalId.Right
		glowLight.Shadows = true
		glowLight.Parent = glass

		-- Create rain emitters along a line above the window
		local NUM_EMITTERS = 5 -- Number of rain emitter points along window width
		local RAIN_HEIGHT_OFFSET = 3 -- How much higher than window top
		local exteriorXOffset = (wallName == "WallEast") and 5 or -5

		for i = 0, NUM_EMITTERS - 1 do
			-- Position along window width (north to south for East/West walls)
			local zOffset = -WINDOW_WIDTH/2 + (WINDOW_WIDTH / (NUM_EMITTERS - 1)) * i
			local yOffset = WINDOW_HEIGHT/2 + RAIN_HEIGHT_OFFSET

			local rainAttachment = Instance.new("Attachment")
			rainAttachment.Name = "RainEmitter" .. i
			rainAttachment.Position = Vector3.new(exteriorXOffset, yOffset, zOffset)
			rainAttachment.Parent = glass

			local rain = Instance.new("ParticleEmitter")
			rain.Name = "Rain"
			rain.Texture = "rbxasset://textures/particles/smoke_main.dds"
			rain.Color = ColorSequence.new(Color3.fromRGB(180, 200, 220))
			rain.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(1, 0.5)
			})
			rain.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.4),
				NumberSequenceKeypoint.new(1, 0.3)
			})
			rain.Lifetime = NumberRange.new(1.5, 2.5)
			rain.Rate = 20 -- Lower per emitter since we have multiple
			rain.Speed = NumberRange.new(40, 50)
			rain.SpreadAngle = Vector2.new(5, 5) -- Tight spread for vertical rain
			rain.Rotation = NumberRange.new(0, 0)
			rain.RotSpeed = NumberRange.new(0, 0)
			rain.VelocityInheritance = 0
			rain.EmissionDirection = Enum.NormalId.Bottom
			rain.Acceleration = Vector3.new(0, -20, 0)
			rain.Parent = rainAttachment
		end
	end
end

--[[
	Cuts a doorway in a wall and creates a connection marker
	@param neighborRoomName string - Name of the connected room (optional)
]]
local function CutDoorway(room, wallName, neighborRoomName)
	local wall = room:FindFirstChild(wallName)
	if not wall then return end

	-- Get the wallpaper style for this room
	local wallTextureId = room:GetAttribute("WallTextureId")
	local wallColor = room:GetAttribute("WallColor") or Color3.fromRGB(80, 80, 100)

	wall:Destroy()

	local wallSegmentWidth = (ROOM_SIZE - DOORWAY_WIDTH) / 2
	local roomPivot = room:GetPivot()

	if wallName == "WallNorth" or wallName == "WallSouth" then
		local zPos = (wallName == "WallNorth") and -ROOM_SIZE/2 or ROOM_SIZE/2
		local insideFace = (wallName == "WallNorth") and Enum.NormalId.Back or Enum.NormalId.Front

		-- Create connection marker at doorway center (middle of opening)
		if neighborRoomName then
			local connection = Instance.new("Part")
			connection.Name = "Connection_" .. wallName
			connection.Size = Vector3.new(1, 1, 1)
			connection.Transparency = 1
			connection.CanCollide = false
			connection.Anchored = true
			connection:SetAttribute("ConnectsTo", neighborRoomName)
			-- Position at center of doorway opening (Y = middle of doorway height)
			connection.CFrame = roomPivot * CFrame.new(0, DOORWAY_HEIGHT/2, zPos)
			connection.Parent = room
		end

		-- Left segment (full height)
		local left = Instance.new("Part")
		left.Name = wallName .. "Left"
		left.Size = Vector3.new(wallSegmentWidth, WALL_HEIGHT, WALL_THICKNESS)
		left.CFrame = roomPivot * CFrame.new(-ROOM_SIZE/2 + wallSegmentWidth/2, WALL_HEIGHT/2, zPos)
		left.Color = wallColor
		left.Material = Enum.Material.SmoothPlastic
		left.Anchored = true
		left.Parent = room
		ApplyWallTexture(left, wallTextureId, insideFace)

		-- Right segment (full height)
		local right = Instance.new("Part")
		right.Name = wallName .. "Right"
		right.Size = Vector3.new(wallSegmentWidth, WALL_HEIGHT, WALL_THICKNESS)
		right.CFrame = roomPivot * CFrame.new(ROOM_SIZE/2 - wallSegmentWidth/2, WALL_HEIGHT/2, zPos)
		right.Color = wallColor
		right.Material = Enum.Material.SmoothPlastic
		right.Anchored = true
		right.Parent = room
		ApplyWallTexture(right, wallTextureId, insideFace)

		-- Top segment above doorway
		local topHeight = WALL_HEIGHT - DOORWAY_HEIGHT
		local top = Instance.new("Part")
		top.Name = wallName .. "Top"
		top.Size = Vector3.new(DOORWAY_WIDTH, topHeight, WALL_THICKNESS)
		top.CFrame = roomPivot * CFrame.new(0, DOORWAY_HEIGHT + topHeight/2, zPos)
		top.Color = wallColor
		top.Material = Enum.Material.SmoothPlastic
		top.Anchored = true
		top.Parent = room
		ApplyWallTexture(top, wallTextureId, insideFace)

	elseif wallName == "WallEast" or wallName == "WallWest" then
		local xPos = (wallName == "WallEast") and ROOM_SIZE/2 or -ROOM_SIZE/2
		local insideFace = (wallName == "WallEast") and Enum.NormalId.Left or Enum.NormalId.Right

		-- Create connection marker at doorway center (middle of opening)
		if neighborRoomName then
			local connection = Instance.new("Part")
			connection.Name = "Connection_" .. wallName
			connection.Size = Vector3.new(1, 1, 1)
			connection.Transparency = 1
			connection.CanCollide = false
			connection.Anchored = true
			connection:SetAttribute("ConnectsTo", neighborRoomName)
			-- Position at center of doorway opening (Y = middle of doorway height)
			connection.CFrame = roomPivot * CFrame.new(xPos, DOORWAY_HEIGHT/2, 0)
			connection.Parent = room
		end

		-- North segment (full height)
		local north = Instance.new("Part")
		north.Name = wallName .. "North"
		north.Size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, wallSegmentWidth)
		north.CFrame = roomPivot * CFrame.new(xPos, WALL_HEIGHT/2, -ROOM_SIZE/2 + wallSegmentWidth/2)
		north.Color = wallColor
		north.Material = Enum.Material.SmoothPlastic
		north.Anchored = true
		north.Parent = room
		ApplyWallTexture(north, wallTextureId, insideFace)

		-- South segment (full height)
		local south = Instance.new("Part")
		south.Name = wallName .. "South"
		south.Size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, wallSegmentWidth)
		south.CFrame = roomPivot * CFrame.new(xPos, WALL_HEIGHT/2, ROOM_SIZE/2 - wallSegmentWidth/2)
		south.Color = wallColor
		south.Material = Enum.Material.SmoothPlastic
		south.Anchored = true
		south.Parent = room
		ApplyWallTexture(south, wallTextureId, insideFace)

		-- Top segment above doorway
		local topHeight = WALL_HEIGHT - DOORWAY_HEIGHT
		local top = Instance.new("Part")
		top.Name = wallName .. "Top"
		top.Size = Vector3.new(WALL_THICKNESS, topHeight, DOORWAY_WIDTH)
		top.CFrame = roomPivot * CFrame.new(xPos, DOORWAY_HEIGHT + topHeight/2, 0)
		top.Color = wallColor
		top.Material = Enum.Material.SmoothPlastic
		top.Anchored = true
		top.Parent = room
		ApplyWallTexture(top, wallTextureId, insideFace)
	end
end

--[[
	Removes floor from a room
]]
local function RemoveFloor(room)
	local floor = room:FindFirstChild("Floor")
	if floor then
		local floorPos = floor.Position
		floor:Destroy()
		-- Mark this room as having no floor so furniture doesn't spawn here
		room:SetAttribute("NoFloor", true)
	end
end

--[[
	Cuts a rectangular stairwell opening in the ceiling for spiral stairs
]]
local function CutStairwellOpening(room)
	local ceiling = room:FindFirstChild("Ceiling")
	if not ceiling then
		warn(string.format("[CutStairwellOpening] No ceiling found in %s", room.Name))
		return
	end

	local ceilingPos = ceiling.Position

	-- Remove original ceiling
	local ceilingCFrame = ceiling.CFrame
	ceiling:Destroy()

	-- Rectangular opening for spiral stairs
	local OPENING_WIDTH = 14
	local OPENING_DEPTH = 14
	local sideWidth = (ROOM_SIZE - OPENING_WIDTH) / 2
	local sideDepth = (ROOM_SIZE - OPENING_DEPTH) / 2

	-- Create 4 ceiling pieces around the rectangular opening (0.5 thick to match main ceiling)
	-- Left piece
	local left = Instance.new("Part")
	left.Name = "CeilingLeft"
	left.Size = Vector3.new(sideWidth, 0.5, ROOM_SIZE)
	left.CFrame = ceilingCFrame * CFrame.new(-ROOM_SIZE/2 + sideWidth/2, 0, 0)
	left.Color = Color3.fromRGB(40, 40, 50) -- Darker gray stone color
	left.Material = Enum.Material.Slate
	left.Anchored = true
	left.Parent = room

	-- Right piece
	local right = Instance.new("Part")
	right.Name = "CeilingRight"
	right.Size = Vector3.new(sideWidth, 0.5, ROOM_SIZE)
	right.CFrame = ceilingCFrame * CFrame.new(ROOM_SIZE/2 - sideWidth/2, 0, 0)
	right.Color = Color3.fromRGB(40, 40, 50) -- Darker gray stone color
	right.Material = Enum.Material.Slate
	right.Anchored = true
	right.Parent = room

	-- Front piece (above opening)
	local front = Instance.new("Part")
	front.Name = "CeilingFront"
	front.Size = Vector3.new(OPENING_WIDTH, 0.5, sideDepth)
	front.CFrame = ceilingCFrame * CFrame.new(0, 0, -ROOM_SIZE/2 + sideDepth/2)
	front.Color = Color3.fromRGB(40, 40, 50) -- Darker gray stone color
	front.Material = Enum.Material.Slate
	front.Anchored = true
	front.Parent = room

	-- Back piece (below opening)
	local back = Instance.new("Part")
	back.Name = "CeilingBack"
	back.Size = Vector3.new(OPENING_WIDTH, 0.5, sideDepth)
	back.CFrame = ceilingCFrame * CFrame.new(0, 0, ROOM_SIZE/2 - sideDepth/2)
	back.Color = Color3.fromRGB(40, 40, 50) -- Darker gray stone color
	back.Material = Enum.Material.Slate
	back.Anchored = true
	back.Parent = room

end

--[[
	Adds spiral stairs to a room (positioned relative to room's pivot)
]]
local function AddStairs(room)
	local NUM_STEPS = MansionConfig.NUM_STEPS
	local STEP_RISE = MansionConfig.STEP_RISE
	local SPIRAL_RADIUS = 6 -- Distance from center to middle of step
	local STEP_HEIGHT = 0.8 -- Vertical thickness of each step
	local STEP_LENGTH = 6 -- Radial length (from center outward)
	local STEP_WIDTH = 5 -- Tangential width

	-- Mark this room as having stairs so furniture doesn't spawn here
	room:SetAttribute("HasStairs", true)

	local roomPivot = room:GetPivot()

	-- Central pole for the spiral - stretches from floor to ceiling
	local pole = Instance.new("Part")
	pole.Name = "CentralPole"
	pole.Size = Vector3.new(2.5, WALL_HEIGHT, 2.5) -- 2.5×height×2.5 studs
	pole.CFrame = roomPivot * CFrame.new(0, WALL_HEIGHT/2, 0)
	pole.Color = Color3.fromRGB(60, 40, 20)
	pole.Material = Enum.Material.Wood
	pole.Anchored = true
	pole.Parent = room

	-- Create spiral steps
	for i = 0, NUM_STEPS - 1 do
		local step = Instance.new("Part")
		step.Name = "Step" .. (i + 1)
		step.Size = Vector3.new(STEP_WIDTH, STEP_HEIGHT, STEP_LENGTH) -- Width, Height, Length

		-- Calculate height - start at floor level
		local yPos = i * STEP_RISE + STEP_HEIGHT/2

		-- Calculate angle for continuous spiral
		-- Each step rotates by 18 degrees (360 / 20 = 18°)
		local angle = i * 18 -- degrees

		-- Position step at radius
		local angleRad = math.rad(angle)
		local xOffset = math.cos(angleRad) * SPIRAL_RADIUS
		local zOffset = math.sin(angleRad) * SPIRAL_RADIUS

		-- Build CFrame using lookAt - step points radially outward
		local position = roomPivot.Position + Vector3.new(xOffset, yPos, zOffset)
		local lookAtTarget = position + Vector3.new(math.cos(angleRad), 0, math.sin(angleRad))

		step.CFrame = CFrame.lookAt(position, lookAtTarget) * CFrame.Angles(0, math.rad(-90), 0)
		step.Color = Color3.fromRGB(139, 90, 43)
		step.Material = Enum.Material.WoodPlanks
		step.Anchored = true
		step.Parent = room
	end

end

--[[
	Adds spawn location to room (positioned relative to room's pivot)
]]
local function AddSpawn(room)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlayerSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Color = Color3.fromRGB(100, 100, 120)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Transparency = 1.0 -- Fully transparent
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Enabled = false
	spawn.Parent = room

	-- Position relative to room's current pivot
	spawn.CFrame = room:GetPivot() * CFrame.new(0, 0.5, 0)

	-- Mark this room as having player spawn (for monster spawn exclusion)
	room:SetAttribute("HasPlayerSpawn", true)
end

--[[
	Adds exit marker to room (positioned relative to room's pivot)
]]
local function AddExitMarker(room)
	local roomPivot = room:GetPivot()

	local marker = Instance.new("Part")
	marker.Name = "ExitMarker"
	marker.Size = Vector3.new(10, 1, 10)
	marker.CFrame = roomPivot * CFrame.new(0, 1.5, 0)
	marker.Color = Color3.fromRGB(50, 255, 50)
	marker.Material = Enum.Material.Neon
	marker.Transparency = 0.3
	marker.Anchored = true
	marker.CanCollide = false
	marker.Parent = room

	local pillar = Instance.new("Part")
	pillar.Name = "ExitPillar"
	pillar.Size = Vector3.new(2, 20, 2)
	pillar.CFrame = roomPivot * CFrame.new(0, 11, 0)
	pillar.Color = Color3.fromRGB(100, 255, 100)
	pillar.Material = Enum.Material.Neon
	pillar.Transparency = 0.5
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.Parent = room
end

--[[
	Generates the complete mansion
]]
function MansionGenerator:GenerateMansion()

	local mansion = Instance.new("Model")
	mansion.Name = "ProceduralMansion"

	-- Store all rooms by level
	local rooms = {}
	for level = 1, NUM_LEVELS do
		rooms[level] = {}
	end

	-- Create all rooms
	for level = 1, NUM_LEVELS do
		for x = 0, GRID_WIDTH - 1 do
			for z = 0, GRID_DEPTH - 1 do
				local room = CreateRoom(x, z, level)

				-- Position room in world
				-- Floor is at local Y=0, so we position pivot at the floor level
				local worldX = x * ROOM_SIZE
				local worldY = (level - 1) * LEVEL_HEIGHT
				local worldZ = z * ROOM_SIZE
				room:PivotTo(CFrame.new(worldX, worldY, worldZ))
				room.Parent = mansion

				-- Store room
				if not rooms[level][x] then
					rooms[level][x] = {}
				end
				rooms[level][x][z] = room
			end
		end
	end

	-- Generate maze using recursive backtracking for each level
	for level = 1, NUM_LEVELS do
		local visited = {}
		for x = 0, GRID_WIDTH - 1 do
			visited[x] = {}
			for z = 0, GRID_DEPTH - 1 do
				visited[x][z] = false
			end
		end

		-- Recursive backtracking maze generation
		local function carveMaze(x, z)
			visited[x][z] = true

			-- Get all neighbors in random order
			local directions = {
				{dx = 1, dz = 0, wall = "WallEast", neighborWall = "WallWest"},
				{dx = -1, dz = 0, wall = "WallWest", neighborWall = "WallEast"},
				{dx = 0, dz = 1, wall = "WallSouth", neighborWall = "WallNorth"},
				{dx = 0, dz = -1, wall = "WallNorth", neighborWall = "WallSouth"}
			}

			-- Shuffle directions
			for i = #directions, 2, -1 do
				local j = math.random(i)
				directions[i], directions[j] = directions[j], directions[i]
			end

			-- Try each direction
			for _, dir in ipairs(directions) do
				local nx, nz = x + dir.dx, z + dir.dz

				-- Check if neighbor is valid and unvisited
				if nx >= 0 and nx < GRID_WIDTH and nz >= 0 and nz < GRID_DEPTH then
					if not visited[nx][nz] then
						-- Cut doorway between current and neighbor (BOTH sides)
						local currentRoom = rooms[level][x][z]
						local neighborRoom = rooms[level][nx][nz]

						-- Pass neighbor room name to create connection marker
						CutDoorway(currentRoom, dir.wall, neighborRoom.Name)
						CutDoorway(neighborRoom, dir.neighborWall, currentRoom.Name)

						-- Recursively carve from neighbor
						carveMaze(nx, nz)
					end
				end
			end
		end

		-- Start maze from random position on each level
		local startX = math.random(0, GRID_WIDTH - 1)
		local startZ = math.random(0, GRID_DEPTH - 1)
		carveMaze(startX, startZ)

	end

	-- Add windows to outer rooms randomly
	for level = 1, NUM_LEVELS do
		for x = 0, GRID_WIDTH - 1 do
			for z = 0, GRID_DEPTH - 1 do
				local room = rooms[level][x][z]

				-- Check if room is on outer edge and randomly add windows (50% chance)
				if x == 0 and math.random() > 0.5 then
					CutWindow(room, "WallWest")
				end
				if x == GRID_WIDTH - 1 and math.random() > 0.5 then
					CutWindow(room, "WallEast")
				end
				if z == 0 and math.random() > 0.5 then
					CutWindow(room, "WallNorth")
				end
				if z == GRID_DEPTH - 1 and math.random() > 0.5 then
					CutWindow(room, "WallSouth")
				end
			end
		end
	end

	-- Pick random start point on level 1
	local startX = math.random(0, GRID_WIDTH - 1)
	local startZ = math.random(0, GRID_DEPTH - 1)
	local startRoom = rooms[1][startX][startZ]
	AddSpawn(startRoom)

	-- Pick random end point on opposite side for L1→L2 connection
	local endZ1 = (startZ < GRID_DEPTH / 2) and math.random(math.floor(GRID_DEPTH * 0.6), GRID_DEPTH - 1)
	                                         or math.random(0, math.floor(GRID_DEPTH * 0.4))
	local endX1 = math.random(0, GRID_WIDTH - 1)
	local lowerRoom1 = rooms[1][endX1][endZ1]
	local upperRoom1 = rooms[2][endX1][endZ1]

	CutStairwellOpening(lowerRoom1)
	AddStairs(lowerRoom1)
	RemoveFloor(upperRoom1)

	-- Pick random end point on opposite side for L2→L3 connection
	local endZ2 = (endZ1 < GRID_DEPTH / 2) and math.random(math.floor(GRID_DEPTH * 0.6), GRID_DEPTH - 1)
	                                         or math.random(0, math.floor(GRID_DEPTH * 0.4))
	local endX2 = math.random(0, GRID_WIDTH - 1)
	local lowerRoom2 = rooms[2][endX2][endZ2]
	local upperRoom2 = rooms[3][endX2][endZ2]

	CutStairwellOpening(lowerRoom2)
	AddStairs(lowerRoom2)
	RemoveFloor(upperRoom2)

	-- Pick final exit point on opposite side of L3
	local exitZ = (endZ2 < GRID_DEPTH / 2) and math.random(math.floor(GRID_DEPTH * 0.6), GRID_DEPTH - 1)
	                                         or math.random(0, math.floor(GRID_DEPTH * 0.4))
	local exitX = math.random(0, GRID_WIDTH - 1)
	local exitRoom = rooms[3][exitX][exitZ]
	AddExitMarker(exitRoom)
	
	return mansion
end

return MansionGenerator
