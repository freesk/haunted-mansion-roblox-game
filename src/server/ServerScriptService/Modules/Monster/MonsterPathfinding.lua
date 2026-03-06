--[[
	MonsterPathfinding - Pathfinding for monsters through mansion rooms

	Uses room connections (doorways) to find valid paths.
	Per MONSTER_WANDERING_REQUIREMENTS.md: Only picks ADJACENT rooms.
]]

local MonsterPathfinding = {}

--[[
	Analyzes all rooms and their connections
	Returns rooms table and connections map
]]
function MonsterPathfinding:AnalyzeRooms(mansion)
	local rooms = {}
	local connections = {} -- [roomName] = {connectedRoomName1, connectedRoomName2, ...}

	-- Collect all rooms
	for _, room in ipairs(mansion:GetChildren()) do
		if room.Name:match("^Room_L%d") then
			table.insert(rooms, room)
			connections[room.Name] = {}
		end
	end

	-- Find connections between rooms
	for _, room in ipairs(rooms) do
		for _, connection in ipairs(room:GetChildren()) do
			if connection.Name:match("^Connection_") then
				-- Connection name format: Connection_X or Connection_Z
				local connectedRoomName = connection:GetAttribute("ConnectsTo")
				if connectedRoomName and connections[room.Name] then
					table.insert(connections[room.Name], connectedRoomName)
				end
			end
		end
	end

	return rooms, connections
end

--[[
	Finds current room based on position
]]
function MonsterPathfinding:FindCurrentRoom(rooms, position)
	local closestRoom = nil
	local minDist = math.huge

	for _, room in ipairs(rooms) do
		local roomCenter = room:GetPivot().Position
		local dist = (roomCenter - position).Magnitude
		if dist < minDist then
			minDist = dist
			closestRoom = room
		end
	end

	return closestRoom
end

--[[
	Finds the doorway connection between two adjacent rooms
	Returns the doorway position (middle of the doorway)
]]
function MonsterPathfinding:FindDoorwayPosition(currentRoom, targetRoomName)
	-- Find the Connection object that points to target room
	for _, child in ipairs(currentRoom:GetChildren()) do
		if child.Name:match("^Connection_") then
			local connectsTo = child:GetAttribute("ConnectsTo")
			if connectsTo == targetRoomName then
				-- Return the doorway position (where the connection marker is)
				return child.Position
			end
		end
	end
	return nil
end

--[[
	Builds waypoints from current position to target room
	Returns array of Vector3 positions: [start, doorway, target]

	Per requirements: 3-point navigation
	1. Starting point (current position)
	2. Middle of the doorway point
	3. Final point (random position in target room with wall offset)
]]
function MonsterPathfinding:BuildWaypoints(currentRoom, targetRoom, currentPos)
	local waypoints = {}

	-- Find the actual doorway position between the two rooms
	local doorwayPos = self:FindDoorwayPosition(currentRoom, targetRoom.Name)
	if not doorwayPos then
		warn("[MonsterPathfinding] Could not find doorway between", currentRoom.Name, "and", targetRoom.Name)
		return nil
	end

	-- Waypoint 2: Middle of doorway (preserve Y coordinate)
	local doorwayWaypoint = Vector3.new(doorwayPos.X, currentPos.Y, doorwayPos.Z)
	table.insert(waypoints, doorwayWaypoint)

	-- Waypoint 3: Random position in target room with wall offset
	local WALL_OFFSET = 3 -- Stay 3 studs away from walls

	-- Get room bounding box to know room size
	local cf, size = targetRoom:GetBoundingBox()
	local roomCenter = targetRoom:GetPivot().Position
	local halfSizeX = size.X / 2
	local halfSizeZ = size.Z / 2

	-- Calculate valid area (inset from walls)
	local maxOffsetX = halfSizeX - WALL_OFFSET
	local maxOffsetZ = halfSizeZ - WALL_OFFSET

	-- Ensure room is large enough for wall offset
	if maxOffsetX < 1 or maxOffsetZ < 1 then
		warn("[MonsterPathfinding] Room", targetRoom.Name, "too small for wall offset, using center")
		maxOffsetX = math.max(1, maxOffsetX)
		maxOffsetZ = math.max(1, maxOffsetZ)
	end

	-- Pick random position within valid area (inset from walls)
	local randomX = (math.random() - 0.5) * 2 * maxOffsetX
	local randomZ = (math.random() - 0.5) * 2 * maxOffsetZ

	local targetPos = Vector3.new(
		roomCenter.X + randomX,
		currentPos.Y, -- Keep same Y
		roomCenter.Z + randomZ
	)
	table.insert(waypoints, targetPos)

	return waypoints
end

--[[
	Finds a random ADJACENT room and builds a path to it
	Returns waypoints array or nil if no path found

	Per MONSTER_WANDERING_REQUIREMENTS.md:
	- Picks ADJACENT room only (directly connected via doorway)
	- Random point in target room with offset from walls
	- Path goes through doorway (not through walls)
	- Does NOT follow butler's exit path
	- Does NOT pick any random room on the level
]]
function MonsterPathfinding:FindRandomPath(monster, mansion)
	local rootPart = monster.PrimaryPart or monster:FindFirstChildWhichIsA("BasePart")
	if not rootPart then
		warn("[MonsterPathfinding] No root part found")
		return nil
	end

	local currentPos = rootPart.Position

	-- Analyze rooms and connections
	local rooms, connections = self:AnalyzeRooms(mansion)

	-- Find current room
	local currentRoom = self:FindCurrentRoom(rooms, currentPos)
	if not currentRoom then
		return nil
	end

	-- Get adjacent rooms (directly connected via doorways)
	local adjacentRoomNames = connections[currentRoom.Name]
	if not adjacentRoomNames or #adjacentRoomNames == 0 then
		return nil
	end

	-- Pick a random ADJACENT room
	local targetRoomName = adjacentRoomNames[math.random(1, #adjacentRoomNames)]
	local targetRoom = mansion:FindFirstChild(targetRoomName)
	if not targetRoom then
		return nil
	end

	-- Build 3-point waypoints: start -> doorway -> target
	local waypoints = self:BuildWaypoints(currentRoom, targetRoom, currentPos)

	return waypoints
end

return MonsterPathfinding
