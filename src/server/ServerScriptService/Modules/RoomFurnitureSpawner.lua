--[[
	RoomFurnitureSpawner

	Spawns furniture in a single room with deterministic placement:
	- 1 ceiling light (center)
	- 1 rug (floor center)
	- UP TO 4 floor lamps (one per corner)
	- UP TO 4 wall furniture (one per wall without doorway)
	- 1 bed (dead-end rooms only, excluding starting room)
]]

local RoomFurnitureSpawner = {}

--[[
	Prepares a furniture model for placement (ensures PrimaryPart, makes joints)
]]
local function PrepareFurnitureModel(furniture)
	if not furniture:IsA("Model") then
		return false
	end

	-- Ensure model has a PrimaryPart
	if not furniture.PrimaryPart then
		-- Try to find the largest part as PrimaryPart
		local largest = nil
		local largestSize = 0
		for _, child in ipairs(furniture:GetDescendants()) do
			if child:IsA("BasePart") then
				local size = child.Size.Magnitude
				if size > largestSize then
					largest = child
					largestSize = size
				end
			end
		end
		if largest then
			furniture.PrimaryPart = largest
		else
			return false
		end
	end

	-- Make joints for any surface connections
	pcall(function()
		furniture:MakeJoints()
	end)

	return true
end

--[[
	Detects which walls have doorways
	Returns: {north = bool, east = bool, south = bool, west = bool}
]]
local function DetectDoorways(room)
	local doorways = {
		north = false,
		east = false,
		south = false,
		west = false
	}

	local roomPivot = room:GetPivot()

	for _, child in ipairs(room:GetChildren()) do
		if child.Name:match("^Connection_") and child:IsA("BasePart") then
			local relativePos = roomPivot:PointToObjectSpace(child.Position)

			-- Room is 30x30, walls at ±15
			if math.abs(relativePos.Z + 15) < 2 then
				doorways.north = true
			elseif math.abs(relativePos.Z - 15) < 2 then
				doorways.south = true
			elseif math.abs(relativePos.X - 15) < 2 then
				doorways.east = true
			elseif math.abs(relativePos.X + 15) < 2 then
				doorways.west = true
			end
		end
	end

	return doorways
end

--[[
	Detects which walls have windows
	Returns: {north = bool, east = bool, south = bool, west = bool}
]]
local function DetectWindows(room)
	local windows = {
		north = false,
		east = false,
		south = false,
		west = false
	}

	-- Check for window-specific parts (named like WallNorthGlass, WallSouthCrossV, etc.)
	for _, child in ipairs(room:GetChildren()) do
		if child:IsA("BasePart") then
			local name = child.Name
			-- Check if this part is a window component by looking for specific patterns
			if name:match("Glass") or name:match("Cross") or name:match("Frame") then
				-- Determine which wall based on the part name
				if name:match("WallNorth") then
					windows.north = true
				elseif name:match("WallSouth") then
					windows.south = true
				elseif name:match("WallEast") then
					windows.east = true
				elseif name:match("WallWest") then
					windows.west = true
				end
			end
		end
	end

	return windows
end

--[[
	Spawns all furniture in one room

	@param room Model - The room to furnish
	@param availableModels table - {
		ceilingLights = {modelName1, modelName2, ...},
		rugs = {modelName1, ...},
		floorLamps = {modelName1, ...},
		wallFurniture = {modelName1, ...},
		beds = {modelName1, ...}
	}
	@param getModelFunc function - Function to get a model by name
	@param getConfigFunc function - Function to get a model's config by name
	@param mansion Model - Parent to attach furniture to
	@param isDeadEnd bool - Whether this room is a dead-end

	@return number - Total items spawned
]]
function RoomFurnitureSpawner:FurnishRoom(room, availableModels, getModelFunc, getConfigFunc, mansion, isDeadEnd)
	if not room.PrimaryPart then
		return 0
	end

	local spawned = 0
	local roomPivot = room:GetPivot()
	local doorways = DetectDoorways(room)
	local windows = DetectWindows(room)

	-- 1. CEILING LIGHT (center of room)
	if availableModels.ceilingLights and #availableModels.ceilingLights > 0 then
		local modelName = availableModels.ceilingLights[math.random(1, #availableModels.ceilingLights)]
		local furniture = getModelFunc(modelName)
		local config = getConfigFunc(modelName)

		if furniture and config and PrepareFurnitureModel(furniture) then
			-- Use config position data
			local x = config.position.xMin and math.random(config.position.xMin, config.position.xMax) or 0
			local z = config.position.zMin and math.random(config.position.zMin, config.position.zMax) or 0
			local y = config.position.y or 14

			-- Use config rotation data
			local rotation = 0
			if config.rotations and #config.rotations > 0 then
				rotation = config.rotations[math.random(1, #config.rotations)]
			end

			local cframe = roomPivot * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(rotation), 0)
			furniture:PivotTo(cframe)
			furniture.Parent = mansion
			spawned += 1
		end
	end

	-- 2. RUG (center of floor)
	if availableModels.rugs and #availableModels.rugs > 0 then
		local modelName = availableModels.rugs[math.random(1, #availableModels.rugs)]
		local furniture = getModelFunc(modelName)
		local config = getConfigFunc(modelName)

		if furniture and config and PrepareFurnitureModel(furniture) then
			-- Use config position data
			local x = math.random(config.position.xMin, config.position.xMax)
			local z = math.random(config.position.zMin, config.position.zMax)
			local y = config.position.y or 0.6

			-- Use config rotation data
			local rotation = 0
			if config.rotations and #config.rotations > 0 then
				rotation = config.rotations[math.random(1, #config.rotations)]
			end

			local cframe = roomPivot * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(rotation), 0)
			furniture:PivotTo(cframe)
			furniture.Parent = mansion
			spawned += 1
		end
	end

	-- 3. FLOOR LAMPS (spawn 0-2 lamps randomly in corners)
	if availableModels.floorLamps and #availableModels.floorLamps > 0 then
		-- Randomly decide how many lamps to spawn (0-2)
		local lampsToSpawn = math.random(0, 2)

		if lampsToSpawn > 0 then
			-- Get a random lamp model to get its config
			local sampleModelName = availableModels.floorLamps[1]
			local sampleConfig = getConfigFunc(sampleModelName)

			-- Use corner positions from config (all lamps should have same corners)
			local corners = sampleConfig and sampleConfig.cornerPositions or {
				{x = -11, z = -11, rotation = 45, name = "NW"},
				{x = 11, z = -11, rotation = 315, name = "NE"},
				{x = 11, z = 11, rotation = 225, name = "SE"},
				{x = -11, z = 11, rotation = 135, name = "SW"},
			}

			-- Shuffle corners to pick random ones
			local shuffledCorners = {}
			for _, corner in ipairs(corners) do
				table.insert(shuffledCorners, corner)
			end

			for i = #shuffledCorners, 2, -1 do
				local j = math.random(i)
				shuffledCorners[i], shuffledCorners[j] = shuffledCorners[j], shuffledCorners[i]
			end

			-- Spawn lamps in selected corners (no duplicates)
			for i = 1, lampsToSpawn do
				local corner = shuffledCorners[i]
				local modelName = availableModels.floorLamps[math.random(1, #availableModels.floorLamps)]
				local furniture = getModelFunc(modelName)
				local config = getConfigFunc(modelName)

				if furniture and config and PrepareFurnitureModel(furniture) then
					local y = config.position.y or 0.5
					local rotation = corner.rotation or 0
					local cframe = roomPivot * CFrame.new(corner.x, y, corner.z) * CFrame.Angles(0, math.rad(rotation), 0)
					furniture:PivotTo(cframe)
					furniture.Parent = mansion
					spawned += 1
				end
			end
		end
	end

	-- 4. WALL FURNITURE (one per wall without doorway or window)
	if availableModels.wallFurniture and #availableModels.wallFurniture > 0 then
		local walls = {
			{name = "north", hasDoorway = doorways.north, hasWindow = windows.north},
			{name = "east", hasDoorway = doorways.east, hasWindow = windows.east},
			{name = "south", hasDoorway = doorways.south, hasWindow = windows.south},
			{name = "west", hasDoorway = doorways.west, hasWindow = windows.west},
		}

		for _, wall in ipairs(walls) do
			-- Check if wall should be skipped (has doorway or window)
			local shouldSkip = false
			local skipReason = ""

			if wall.hasDoorway then
				shouldSkip = true
				skipReason = "has doorway"
			elseif wall.hasWindow then
				shouldSkip = true
				skipReason = "has window"
			end

			if not shouldSkip then
				local modelName = availableModels.wallFurniture[math.random(1, #availableModels.wallFurniture)]
				local furniture = getModelFunc(modelName)
				local config = getConfigFunc(modelName)

				if furniture and config and PrepareFurnitureModel(furniture) then
					-- Use wall offset from config (distance from wall into room)
					local wallOffset = config.position.wallOffset or 12
					local y = config.position.y or 0.5

					-- Use wall-specific rotation from config
					local rotation = 0
					if config.wallRotations and config.wallRotations[wall.name] then
						rotation = config.wallRotations[wall.name]
					end

					-- Calculate position: start at wall, offset toward room center
					-- Room is 30x30, walls at ±15, wallOffset moves furniture from wall toward center
					local x, z = 0, 0
					if wall.name == "north" then
						-- North wall at Z = -15, offset south (toward center) is +Z
						x, z = 0, -15 + wallOffset
					elseif wall.name == "east" then
						-- East wall at X = 15, offset west (toward center) is -X
						x, z = 15 - wallOffset, 0
					elseif wall.name == "south" then
						-- South wall at Z = 15, offset north (toward center) is -Z
						x, z = 0, 15 - wallOffset
					elseif wall.name == "west" then
						-- West wall at X = -15, offset east (toward center) is +X
						x, z = -15 + wallOffset, 0
					end

					local cframe = roomPivot * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(rotation), 0)
					furniture:PivotTo(cframe)
					furniture.Parent = mansion
					spawned += 1
				end
			end
		end
	end

	-- 5. BED (dead-end rooms only, center of room, but not in starting room or exit room)
	-- Check if this is the starting room (has PlayerSpawn) or exit room (has ExitMarker)
	local isStartingRoom = room:FindFirstChild("PlayerSpawn") ~= nil
	local isExitRoom = room:FindFirstChild("ExitMarker") ~= nil

	if isDeadEnd and not isStartingRoom and not isExitRoom and availableModels.beds and #availableModels.beds > 0 then
		local modelName = availableModels.beds[math.random(1, #availableModels.beds)]
		local furniture = getModelFunc(modelName)
		local config = getConfigFunc(modelName)

		if furniture and config and PrepareFurnitureModel(furniture) then
			-- Spawn at center of room with random rotation
			local x = config.centerPosition and config.centerPosition.x or 0
			local z = config.centerPosition and config.centerPosition.z or 0
			local y = config.position.y or 2.5

			-- Pick a random rotation from config
			local rotation = 0
			if config.rotations and #config.rotations > 0 then
				rotation = config.rotations[math.random(1, #config.rotations)]
			end

			local cframe = roomPivot * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(rotation), 0)
			furniture:PivotTo(cframe)
			furniture.Parent = mansion
			spawned += 1
		end
	end

	return spawned
end

return RoomFurnitureSpawner
