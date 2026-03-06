--[[
	GhostMovement - Handles ghost floating and wandering behavior

	Ghosts float smoothly through walls in random directions with
	vertical bobbing motion for an eerie effect.
]]

local RunService = game:GetService("RunService")
local GhostConfig = require(script.Parent.GhostConfig)

local GhostMovement = {}

--[[
	Starts floating/wandering behavior for a ghost

	@param ghost Model - The ghost model
	@param mansion Model - The mansion model to constrain movement within
	@return function - Cleanup function to stop floating
]]
function GhostMovement:StartFloating(ghost, mansion)
	if not ghost or not ghost.PrimaryPart then
		warn("[GhostMovement] Ghost has no primary part")
		return function() end
	end

	local isActive = true
	local connections = {}

	-- Current movement state
	local currentTarget = nil
	local waitTimer = 0
	local bobbingTime = 0 -- Accumulator for bobbing sine wave animation

	-- Store initial spawn Y to maintain constant height per floor
	local constantY = ghost:GetPivot().Position.Y

	-- Calculate mansion bounds from all rooms
	local mansionBounds = nil
	if mansion then
		local minX, maxX = math.huge, -math.huge
		local minZ, maxZ = math.huge, -math.huge

		for _, room in ipairs(mansion:GetChildren()) do
			if room.Name:match("^Room_L%d") then
				local roomPos = room:GetPivot().Position
				local roomSize = 30 -- ROOM_SIZE from MansionConfig

				-- Expand bounds to include this room (only X and Z, Y is constant)
				minX = math.min(minX, roomPos.X - roomSize/2)
				maxX = math.max(maxX, roomPos.X + roomSize/2)
				minZ = math.min(minZ, roomPos.Z - roomSize/2)
				maxZ = math.max(maxZ, roomPos.Z + roomSize/2)
			end
		end

		mansionBounds = {
			minX = minX,
			maxX = maxX,
			minZ = minZ,
			maxZ = maxZ
		}

		print(string.format("[GhostMovement] Mansion bounds: X(%.1f, %.1f) Z(%.1f, %.1f), constant Y=%.1f",
			minX, maxX, minZ, maxZ, constantY))
	end

	--[[
		Picks a random point in the mansion to float toward (constant Y per floor)
	]]
	local function PickRandomTarget()
		local currentPos = ghost:GetPivot().Position

		-- Random direction (horizontal only)
		local angle = math.random() * math.pi * 2
		local distance = math.random(GhostConfig.WANDER_MIN_DISTANCE, GhostConfig.WANDER_MAX_DISTANCE)

		-- Use constant Y for this floor (no height variation)
		local targetPos = Vector3.new(
			currentPos.X + math.cos(angle) * distance,
			constantY,
			currentPos.Z + math.sin(angle) * distance
		)

		-- Clamp to mansion bounds if available (X and Z only)
		if mansionBounds then
			targetPos = Vector3.new(
				math.clamp(targetPos.X, mansionBounds.minX + 5, mansionBounds.maxX - 5),
				constantY,
				math.clamp(targetPos.Z, mansionBounds.minZ + 5, mansionBounds.maxZ - 5)
			)
		end

		return targetPos
	end

	-- Initial wait before starting to float
	task.delay(GhostConfig.INITIAL_WAIT, function()
		if not isActive then return end

		-- Pick first target
		if math.random() < GhostConfig.FLOAT_CHANCE then
			currentTarget = PickRandomTarget()
		end
	end)

	-- Main floating loop
	local connection = RunService.Heartbeat:Connect(function(deltaTime)
		if not isActive or not ghost or not ghost.Parent then
			return
		end

		-- Update bobbing animation (always runs, even when idle)
		bobbingTime = bobbingTime + deltaTime
		local verticalOffset = math.sin(bobbingTime * GhostConfig.FLOAT_BOB_SPEED * math.pi * 2) * GhostConfig.FLOAT_HEIGHT_VARIATION

		-- Wait timer countdown
		if waitTimer > 0 then
			waitTimer = waitTimer - deltaTime
			-- Ghost bobs up/down while idle
			local currentPos = ghost:GetPivot().Position
			local newPos = Vector3.new(currentPos.X, constantY + verticalOffset, currentPos.Z)
			local currentCFrame = ghost:GetPivot()
			ghost:PivotTo(CFrame.new(newPos) * (currentCFrame - currentCFrame.Position))
			return
		end

		-- If no target, pick new one
		if not currentTarget then
			if math.random() < GhostConfig.FLOAT_CHANCE then
				currentTarget = PickRandomTarget()
				print(string.format("[GhostMovement] Ghost floating to (%.1f, %.1f, %.1f)",
					currentTarget.X, currentTarget.Y, currentTarget.Z))
			else
				-- Stay idle
				waitTimer = math.random() * (GhostConfig.WANDER_MAX_WAIT - GhostConfig.WANDER_MIN_WAIT) + GhostConfig.WANDER_MIN_WAIT
			end
			return
		end

		-- Move toward target
		local currentPos = ghost:GetPivot().Position
		local offset = currentTarget - currentPos
		local distance = offset.Magnitude

		-- Check if reached target
		if distance < 2 then
			-- Reached target, wait before next move
			currentTarget = nil
			waitTimer = math.random() * (GhostConfig.WANDER_MAX_WAIT - GhostConfig.WANDER_MIN_WAIT) + GhostConfig.WANDER_MIN_WAIT
			return
		end

		-- Move toward target smoothly (horizontal movement)
		local direction = offset.Unit
		local moveAmount = math.min(GhostConfig.FLOAT_SPEED * deltaTime, distance)
		local newPos = currentPos + (direction * moveAmount)

		-- Apply bobbing motion to Y (sine wave oscillation around constantY)
		newPos = Vector3.new(newPos.X, constantY + verticalOffset, newPos.Z)

		-- Apply rotation to face movement direction while staying upright
		local newCFrame = CFrame.new(newPos)

		if offset.Magnitude > 0.01 then
			-- Calculate Y-axis rotation to face movement direction
			local angle = math.atan2(offset.X, offset.Z)
			-- Apply facing rotation on Y axis, then upright rotation on X axis
			newCFrame = newCFrame * CFrame.Angles(0, angle, 0) * GhostConfig.ROTATION_OFFSET
		else
			-- Not moving, just apply upright rotation
			newCFrame = newCFrame * GhostConfig.ROTATION_OFFSET
		end

		ghost:PivotTo(newCFrame)
	end)

	table.insert(connections, connection)

	-- Return cleanup function
	return function()
		isActive = false
		for _, conn in ipairs(connections) do
			if conn and conn.Connected then
				conn:Disconnect()
			end
		end
		print("[GhostMovement] Ghost floating stopped")
	end
end

return GhostMovement
