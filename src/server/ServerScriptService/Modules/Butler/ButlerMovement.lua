--[[
	ButlerMovement - Handles smooth butler movement along paths

	Responsible for:
	- Moving butler smoothly through waypoints
	- Updating butler rotation to face movement direction
	- Lantern automatically follows via weld constraint
]]

local RunService = game:GetService("RunService")
local ButlerConfig = require(script.Parent.ButlerConfig)

local ButlerMovement = {}

--[[
	Starts smooth movement through a path of waypoints

	@param butler Model - The butler model
	@param path table - Array of waypoints with position and type
	@param onComplete function - Called when path is complete
	@return function - Cleanup function to stop movement
]]
function ButlerMovement:StartMovement(butler, path, onComplete)
	if not butler.PrimaryPart then
		warn("[ButlerMovement] Butler missing primary part")
		return function() end
	end

	local primaryPart = butler.PrimaryPart
	local currentWaypointIndex = 1
	local isActive = true

	local connection
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		if not isActive or not butler or not butler.Parent then
			if not butler then
				warn("[ButlerMovement] Butler was destroyed!")
			elseif not butler.Parent then
				warn("[ButlerMovement] Butler parent was removed!")
			end
			connection:Disconnect()
			return
		end

		-- Check if finished
		if currentWaypointIndex > #path then
			connection:Disconnect()
			if onComplete then
				onComplete()
			end
			return
		end

		-- Get current waypoint
		local waypoint = path[currentWaypointIndex]
		local currentPos = butler:GetPivot().Position
		local targetPos = waypoint.position

		-- Check if this is a stair climb (vertical movement)
		local isStairClimb = waypoint.isStairs or false

		-- Calculate distance
		local offset = targetPos - currentPos
		local distance = offset.Magnitude

		-- Check if reached waypoint
		local reachDistance = ButlerConfig.WAYPOINT_REACH_DISTANCE
		if distance < reachDistance then
			print(string.format("[ButlerMovement] Reached waypoint %d/%d (type: %s, isStairs: %s, Y: %.1f, room: %s)",
			currentWaypointIndex, #path, waypoint.type or "unknown", tostring(isStairClimb), targetPos.Y, waypoint.roomName or "unknown"))

			-- CRITICAL: When leaving stairs, snap to target Y to prevent levitation
			if currentWaypointIndex < #path then
				local nextWaypoint = path[currentWaypointIndex + 1]
				if isStairClimb and not nextWaypoint.isStairs then
					-- Just finished stairs, next waypoint is on floor - snap Y now
					print(string.format("[ButlerMovement] Transitioning from stairs to floor - snapping Y from %.1f to %.1f",
						currentPos.Y, targetPos.Y))
					butler:PivotTo(CFrame.new(currentPos.X, targetPos.Y, currentPos.Z))
				end
			end

			currentWaypointIndex = currentWaypointIndex + 1
			return
		end

		-- Move toward target
		local newPos
		if isStairClimb then
			-- Stair climb: Move in 3D (including Y)
			local direction = offset.Unit
			local moveAmount = math.min(ButlerConfig.WALK_SPEED * deltaTime, distance)
			newPos = currentPos + (direction * moveAmount)
		else
			-- Normal movement: Move only on horizontal plane (X, Z), lock Y
			local horizontalOffset = Vector3.new(offset.X, 0, offset.Z)
			local horizontalDistance = horizontalOffset.Magnitude

			if horizontalDistance < 0.1 then
				-- Very close horizontally, snap to target Y
				newPos = targetPos
			else
				local horizontalDirection = horizontalOffset.Unit
				local moveAmount = math.min(ButlerConfig.WALK_SPEED * deltaTime, horizontalDistance)
				local horizontalMove = currentPos + (horizontalDirection * moveAmount)

				-- CRITICAL FIX: Use target waypoint Y, not current position Y
				-- This prevents levitation after stairs when waypoint Y differs from position Y
				newPos = Vector3.new(horizontalMove.X, targetPos.Y, horizontalMove.Z)
			end
		end

		-- Face movement direction (horizontal plane only)
		local lookDirection = Vector3.new(offset.X, 0, offset.Z)
		if lookDirection.Magnitude > 0.01 then
			local newCFrame = CFrame.lookAt(newPos, newPos + lookDirection)
			butler:PivotTo(newCFrame)
		else
			butler:PivotTo(CFrame.new(newPos))
		end

		-- Lantern automatically follows via weld constraint (no manual update needed)
	end)

	-- Return cleanup function
	return function()
		isActive = false
		if connection then
			connection:Disconnect()
		end
	end
end

return ButlerMovement
