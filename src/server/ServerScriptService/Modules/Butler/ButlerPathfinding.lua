--[[
	ButlerPathfinding - Handles pathfinding logic for butler NPC

	Responsible for:
	- Analyzing mansion room structure
	- Building room connection graphs
	- Finding paths through the mansion using BFS
	- Converting room sequences to waypoints
]]

local ButlerConfig = require(script.Parent.ButlerConfig)

local ButlerPathfinding = {}

-- Helper function for sign
local function sign(x)
	if x > 0 then return 1
	elseif x < 0 then return -1
	else return 0 end
end

--[[
	Gets all rooms with their metadata (connections, floor, position, etc)

	@param mansion Model - The mansion model
	@return rooms table - Array of room info
	@return roomsByName table - Lookup table by room name
]]
function ButlerPathfinding:GetAllRoomsWithInfo(mansion)
	local rooms = {}
	local roomsByName = {}

	for _, room in ipairs(mansion:GetChildren()) do
		if room:IsA("Model") and room.Name:match("Room_") then
			local cf, size = room:GetBoundingBox()
			local center = cf.Position

			local hasStairs = room:FindFirstChild("Step1") ~= nil

			-- Parse floor from room name: Room_L{level}_X{x}_Z{z}
			local levelStr = room.Name:match("Room_L(%d+)_")
			local floor = tonumber(levelStr) or 1

			local roomInfo = {
				model = room,
				name = room.Name,
				center = center,
				hasStairs = hasStairs,
				floor = floor,
				size = size,
				connections = {}
			}

			table.insert(rooms, roomInfo)
			roomsByName[room.Name] = roomInfo
		end
	end

	-- Build room connections graph
	local totalConnections = 0
	for _, room in ipairs(rooms) do
		local level, x, z = room.name:match("Room_L(%d+)_X(%d+)_Z(%d+)")
		if level and x and z then
			level, x, z = tonumber(level), tonumber(x), tonumber(z)

			-- Check 4 adjacent rooms on same floor
			local adjacentRooms = {
				{name = string.format("Room_L%d_X%d_Z%d", level, x + 1, z), wall = "WallEast"},
				{name = string.format("Room_L%d_X%d_Z%d", level, x - 1, z), wall = "WallWest"},
				{name = string.format("Room_L%d_X%d_Z%d", level, x, z + 1), wall = "WallSouth"},
				{name = string.format("Room_L%d_X%d_Z%d", level, x, z - 1), wall = "WallNorth"}
			}

			for _, adjacent in ipairs(adjacentRooms) do
				local adjacentRoom = roomsByName[adjacent.name]
				if adjacentRoom then
					local wall = room.model:FindFirstChild(adjacent.wall)
					if not wall then
						if not table.find(room.connections, adjacent.name) then
							table.insert(room.connections, adjacent.name)
							totalConnections = totalConnections + 1
						end
					end
				end
			end

			-- Connect stair rooms to adjacent floors
			if room.hasStairs then
				local roomAbove = roomsByName[string.format("Room_L%d_X%d_Z%d", level + 1, x, z)]
				if roomAbove then
					table.insert(room.connections, roomAbove.name)
					totalConnections = totalConnections + 1
				end

				local roomBelow = roomsByName[string.format("Room_L%d_X%d_Z%d", level - 1, x, z)]
				if roomBelow then
					table.insert(room.connections, roomBelow.name)
					totalConnections = totalConnections + 1
				end
			end
		end
	end

	return rooms, roomsByName
end

--[[
	Finds room containing a position

	@param rooms table - Array of room info
	@param position Vector3 - Position to search for
	@return table - Room info or nil
]]
function ButlerPathfinding:FindRoomAtPosition(rooms, position)
	local closestRoom = nil
	local closestDistance = math.huge

	for _, room in ipairs(rooms) do
		local distance = (room.center - position).Magnitude
		if distance < closestDistance then
			closestDistance = distance
			closestRoom = room
		end
	end

	return closestRoom
end

--[[
	Uses BFS to find path from start room to exit room

	@param startRoom table - Starting room info
	@param exitRoom table - Exit room info
	@param roomsByName table - Lookup table of rooms
	@return table - Sequence of rooms from start to exit
]]
function ButlerPathfinding:BFSFindPath(startRoom, exitRoom, roomsByName)
	local queue = {{room = startRoom, path = {startRoom}}}
	local visited = {[startRoom.name] = true}

	while #queue > 0 do
		local current = table.remove(queue, 1)
		local currentRoom = current.room
		local currentPath = current.path

		if currentRoom.name == exitRoom.name then
			return currentPath
		end

		for _, connectedRoomName in ipairs(currentRoom.connections) do
			if not visited[connectedRoomName] then
				visited[connectedRoomName] = true

				local connectedRoom = roomsByName[connectedRoomName]
				if connectedRoom then
					local newPath = {}
					for _, r in ipairs(currentPath) do
						table.insert(newPath, r)
					end
					table.insert(newPath, connectedRoom)

					table.insert(queue, {room = connectedRoom, path = newPath})
				end
			end
		end
	end

	warn("[ButlerPathfinding] BFS could not find path!")
	return nil
end

--[[
	Gets the doorway position between two adjacent rooms

	@param fromRoom table - Room info for source room
	@param toRoom table - Room info for destination room
	@return Vector3 - Position of doorway center
	@return string - Direction of doorway ("north", "south", "east", "west")
]]
function ButlerPathfinding:GetDoorwayPosition(fromRoom, toRoom)
	local fromCenter = fromRoom.center
	local toCenter = toRoom.center
	local fromSize = fromRoom.size

	-- Determine which wall connects them
	local deltaX = toCenter.X - fromCenter.X
	local deltaZ = toCenter.Z - fromCenter.Z

	local doorwayPos = nil
	local direction = ""

	if math.abs(deltaX) > math.abs(deltaZ) then
		-- East or West connection
		if deltaX > 0 then
			-- East - doorway on east side of fromRoom
			doorwayPos = Vector3.new(fromCenter.X + fromSize.X/2, fromCenter.Y, fromCenter.Z)
			direction = "east"
		else
			-- West - doorway on west side of fromRoom
			doorwayPos = Vector3.new(fromCenter.X - fromSize.X/2, fromCenter.Y, fromCenter.Z)
			direction = "west"
		end
	else
		-- North or South connection
		if deltaZ > 0 then
			-- South - doorway on south side of fromRoom
			doorwayPos = Vector3.new(fromCenter.X, fromCenter.Y, fromCenter.Z + fromSize.Z/2)
			direction = "south"
		else
			-- North - doorway on north side of fromRoom
			doorwayPos = Vector3.new(fromCenter.X, fromCenter.Y, fromCenter.Z - fromSize.Z/2)
			direction = "north"
		end
	end

	return doorwayPos, direction
end

--[[
	Creates waypoints following a spiral staircase path

	@param stairRoomCenter Vector3 - Center of the stair room
	@param startY number - Starting Y coordinate (bottom of stairs)
	@param endY number - Ending Y coordinate (top of stairs)
	@return table - Array of waypoints following the spiral stairs
]]
function ButlerPathfinding:CreateSpiralStairPath(stairRoomCenter, startY, endY)
	local MansionConfig = require(game:GetService("ReplicatedStorage").Shared.MansionConfig)
	local waypoints = {}

	local NUM_STEPS = MansionConfig.NUM_STEPS
	local SPIRAL_RADIUS = 6 -- Same as in MansionGenerator
	local STEP_HEIGHT = 0.8 -- Same as in MansionGenerator
	local totalHeight = endY - startY

	-- Butler positioning on stairs
	local BUTLER_RADIUS = SPIRAL_RADIUS + 0.5 -- Move butler further from center (6.5 studs)
	local BUTLER_ELEVATION_OFFSET = 2.0 -- Extra height while on stairs (2 studs)

	-- Create waypoints for every 2 steps (10 waypoints total for smoother animation)
	local waypointInterval = 2
	local numWaypoints = math.floor(NUM_STEPS / waypointInterval)

	for i = 0, numWaypoints do
		local stepIndex = i * waypointInterval
		if stepIndex > NUM_STEPS then
			stepIndex = NUM_STEPS
		end

		-- Calculate height - progress from startY to endY
		local progress = stepIndex / NUM_STEPS
		local yPos = startY + (totalHeight * progress)

		-- Add extra elevation while on stairs (but taper at start/end)
		-- Use sine curve to smoothly add elevation in the middle of climb
		local elevationMultiplier = math.sin(progress * math.pi) -- 0 at start/end, 1.0 at middle
		yPos = yPos + (BUTLER_ELEVATION_OFFSET * elevationMultiplier)

		-- Calculate angle for spiral (18 degrees per step)
		local angle = stepIndex * 18 -- degrees
		local angleRad = math.rad(angle)

		-- Position on the spiral (further from center for better visibility)
		local xOffset = math.cos(angleRad) * BUTLER_RADIUS
		local zOffset = math.sin(angleRad) * BUTLER_RADIUS

		local position = Vector3.new(
			stairRoomCenter.X + xOffset,
			yPos,
			stairRoomCenter.Z + zOffset
		)

		table.insert(waypoints, {
			position = position,
			type = "spiral_stairs",
			isStairs = true, -- Mark as stairs so movement handles Y
			stepIndex = stepIndex
		})
	end

	return waypoints
end

--[[
	Creates a smooth curved path between two waypoints

	@param startPos Vector3 - Starting position
	@param endPos Vector3 - Ending position
	@param currentY number - Current Y coordinate
	@return table - Array of waypoint positions forming a curve
]]
function ButlerPathfinding:CreateCurvedPath(startPos, endPos, currentY)
	local waypoints = {}

	-- Check if it's a straight line (aligned on X or Z axis)
	local deltaX = math.abs(endPos.X - startPos.X)
	local deltaZ = math.abs(endPos.Z - startPos.Z)

	if deltaX < 2 or deltaZ < 2 then
		-- Straight line - no curve needed
		table.insert(waypoints, {
			position = Vector3.new(endPos.X, currentY, endPos.Z),
			type = "straight",
			isStairs = false
		})
		return waypoints
	end

	-- Need a curve - use cubic Bezier with two control points for very gradual turns
	-- This creates a wide, sweeping arc instead of a sharp turn

	local dx = endPos.X - startPos.X
	local dz = endPos.Z - startPos.Z

	-- Control points positioned 40% along the path, offset outward to create wide arc
	local offsetAmount = 8 -- Studs to offset for wider curve

	-- First control point - close to start, offset perpendicular
	local ctrl1 = Vector3.new(
		startPos.X + dx * 0.3 - dz * 0.15,
		currentY,
		startPos.Z + dz * 0.3 + dx * 0.15
	)

	-- Second control point - close to end, offset perpendicular
	local ctrl2 = Vector3.new(
		startPos.X + dx * 0.7 - dz * 0.15,
		currentY,
		startPos.Z + dz * 0.7 + dx * 0.15
	)

	-- Create 12 points along the curve for very smooth motion
	local numPoints = 12
	for i = 1, numPoints do
		local t = i / numPoints

		-- Cubic Bezier: B(t) = (1-t)^3*P0 + 3(1-t)^2*t*P1 + 3(1-t)*t^2*P2 + t^3*P3
		local oneMinusT = 1 - t
		local oneMinusT2 = oneMinusT * oneMinusT
		local oneMinusT3 = oneMinusT2 * oneMinusT
		local t2 = t * t
		local t3 = t2 * t

		local pos = Vector3.new(
			oneMinusT3 * startPos.X + 3 * oneMinusT2 * t * ctrl1.X + 3 * oneMinusT * t2 * ctrl2.X + t3 * endPos.X,
			currentY,
			oneMinusT3 * startPos.Z + 3 * oneMinusT2 * t * ctrl1.Z + 3 * oneMinusT * t2 * ctrl2.Z + t3 * endPos.Z
		)

		table.insert(waypoints, {
			position = pos,
			type = "curved",
			isStairs = false
		})
	end

	return waypoints
end

--[[
	Builds a path through rooms from start to exit

	@param startPos Vector3 - Starting position
	@param exitPos Vector3 - Exit position
	@param rooms table - Array of room info
	@param roomsByName table - Lookup by name
	@param mansionBaseY number - The Y coordinate of the mansion base (floor 1)
	@return table - Array of waypoints with positions
]]
function ButlerPathfinding:BuildPathThroughRooms(startPos, exitPos, rooms, roomsByName, mansionBaseY)
	local path = {}

	-- Find start and end rooms
	local startRoom = self:FindRoomAtPosition(rooms, startPos)
	local exitRoom = self:FindRoomAtPosition(rooms, exitPos)

	if not startRoom or not exitRoom then
		warn("[ButlerPathfinding] Could not find start or exit room")
		return path
	end

	-- Use BFS to find room sequence
	local roomSequence = self:BFSFindPath(startRoom, exitRoom, roomsByName)
	if not roomSequence or #roomSequence == 0 then
		warn("[ButlerPathfinding] No path found")
		return path
	end

	-- Set up floor tracking
	local baseY = (mansionBaseY or 0) + ButlerConfig.MANSION_Y_OFFSET
	local currentFloorNum = roomSequence[1].floor
	local relativeFloorY = ButlerConfig.FLOOR_Y_COORDINATES[currentFloorNum] or 0
	local currentY = baseY + relativeFloorY

	print(string.format("[ButlerPathfinding] Butler Y setup: mansionBaseY=%.1f, MANSION_Y_OFFSET=%.1f, baseY=%.1f",
		mansionBaseY or 0, ButlerConfig.MANSION_Y_OFFSET, baseY))
	print(string.format("[ButlerPathfinding] Floor %d: relativeFloorY=%.1f, currentY=%.1f",
		currentFloorNum, relativeFloorY, currentY))

	-- Check actual floor part Y position
	local firstRoom = roomSequence[1]
	if firstRoom and firstRoom.model then
		local floor = firstRoom.model:FindFirstChild("Floor")
		if floor and floor:IsA("BasePart") then
			local floorTop = floor.Position.Y + floor.Size.Y/2
			print(string.format("[ButlerPathfinding] Actual floor top Y=%.1f, Butler walking Y=%.1f, Difference=%.1f studs",
				floorTop, currentY, currentY - floorTop))
		end
	end

	-- Start position
	local currentPos = Vector3.new(startPos.X, currentY, startPos.Z)

	-- Build path from doorway to doorway (or stair to stair)
	for i = 1, #roomSequence - 1 do
		local currentRoom = roomSequence[i]
		local nextRoom = roomSequence[i + 1]

		-- Check if we're changing floors (stairs)
		if currentRoom.floor ~= nextRoom.floor then
			print(string.format("[ButlerPathfinding] Climbing stairs from floor %d (Y=%.1f) to floor %d",
				currentRoom.floor, currentY, nextRoom.floor))

			-- Move to stairs in current room (center)
			local stairPos = Vector3.new(currentRoom.center.X, currentY, currentRoom.center.Z)

			-- Create curved path to stairs
			local curveToStairs = self:CreateCurvedPath(currentPos, stairPos, currentY)
			for _, waypoint in ipairs(curveToStairs) do
				waypoint.roomName = currentRoom.name
				table.insert(path, waypoint)
			end

			-- Calculate start and end Y for stairs
			local startY = currentY
			currentFloorNum = nextRoom.floor
			local newRelativeY = ButlerConfig.FLOOR_Y_COORDINATES[currentFloorNum] or 0
			local newY = baseY + newRelativeY
			local endY = newY

			print(string.format("[ButlerPathfinding] Spiral stairs: startY=%.1f, endY=%.1f (new floor Y)", startY, endY))

			-- Create spiral staircase waypoints
			local spiralWaypoints = self:CreateSpiralStairPath(currentRoom.center, startY, endY)
			for _, waypoint in ipairs(spiralWaypoints) do
				waypoint.roomName = nextRoom.name
				table.insert(path, waypoint)
			end

			-- CRITICAL: Update currentY to new floor level AFTER creating waypoints
			currentY = newY

			-- Set current position to top of stairs (should match new floor Y)
			local lastWaypoint = spiralWaypoints[#spiralWaypoints]
			currentPos = lastWaypoint.position

			print(string.format("[ButlerPathfinding] After stairs: currentPos.Y=%.1f, currentY=%.1f",
				currentPos.Y, currentY))

			-- Verify they match
			if math.abs(currentPos.Y - currentY) > 0.5 then
				warn(string.format("[ButlerPathfinding] Y mismatch after stairs! pos.Y=%.1f, currentY=%.1f",
					currentPos.Y, currentY))
			end
		else
			-- Same floor - find doorway position
			local doorwayPos, direction = self:GetDoorwayPosition(currentRoom, nextRoom)
			doorwayPos = Vector3.new(doorwayPos.X, currentY, doorwayPos.Z)

			print(string.format("[ButlerPathfinding] Moving on floor %d: from (%.1f,%.1f,%.1f) to (%.1f,%.1f,%.1f), currentY=%.1f",
				currentRoom.floor, currentPos.X, currentPos.Y, currentPos.Z,
				doorwayPos.X, doorwayPos.Y, doorwayPos.Z, currentY))

			-- Create curved path to doorway
			local curveToDoor = self:CreateCurvedPath(currentPos, doorwayPos, currentY)
			for _, waypoint in ipairs(curveToDoor) do
				waypoint.roomName = currentRoom.name
				table.insert(path, waypoint)
			end

			currentPos = doorwayPos
		end
	end

	-- Final destination (exit)
	local finalCurve = self:CreateCurvedPath(currentPos, Vector3.new(exitPos.X, currentY, exitPos.Z), currentY)
	for _, waypoint in ipairs(finalCurve) do
		waypoint.roomName = roomSequence[#roomSequence].name
		table.insert(path, waypoint)
	end

	return path
end

return ButlerPathfinding
