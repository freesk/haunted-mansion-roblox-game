--[[
	PathValidator Module

	Implements breadth-first search to validate entrance-to-exit connectivity.
	Pattern 5 from RESEARCH.md: Simple Room Graph Validation

	Usage:
		local PathValidator = require(script.Parent.PathValidator)
		local isValid = PathValidator:ValidatePath(connections, "Entrance", "Exit")
]]

local PathValidator = {}

--[[
	Validates that a path exists from start to end room using BFS.

	@param connections table - Graph structure: {roomId = {connectedRoomIds}}
	@param startRoom string - Starting room identifier
	@param endRoom string - Target room identifier
	@return boolean - True if path exists, false otherwise
]]
function PathValidator:ValidatePath(connections, startRoom, endRoom)
	-- Validate input
	if not connections or type(connections) ~= "table" then
		warn("[PathValidator] Invalid connections table")
		return false
	end

	if not startRoom or not endRoom then
		warn("[PathValidator] Start or end room not specified")
		return false
	end

	-- Check if start and end rooms exist in graph
	if not connections[startRoom] then
		warn("[PathValidator] Start room not in connections:", startRoom)
		return false
	end

	if not connections[endRoom] then
		warn("[PathValidator] End room not in connections:", endRoom)
		return false
	end

	-- Breadth-first search implementation
	local visited = {}
	local queue = {startRoom}
	visited[startRoom] = true

	while #queue > 0 do
		local current = table.remove(queue, 1)

		-- Check if we reached the destination
		if current == endRoom then
			return true
		end

		-- Visit all connected rooms
		local neighbors = connections[current]
		if neighbors then
			for _, neighbor in ipairs(neighbors) do
				if not visited[neighbor] then
					visited[neighbor] = true
					table.insert(queue, neighbor)
				end
			end
		end
	end

	-- No path found
	return false
end

return PathValidator
