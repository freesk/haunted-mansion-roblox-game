--[[
	MonsterMovement - Handles monster wandering and animation control

	Responsible for:
	- Random wandering behavior
	- Animation state management (idle/walk)
	- CFrame-based movement for custom rigs
]]

local MonsterConfig = require(script.Parent.MonsterConfig)
local MonsterPathfinding = require(script.Parent.MonsterPathfinding)

local MonsterMovement = {}

--[[
	Starts random wandering behavior for the monster

	@param monster Model - The monster model
	@param idleTrack AnimationTrack - Idle animation
	@param walkTrack AnimationTrack - Walk animation
	@return function - Cleanup function to stop movement
]]
function MonsterMovement:StartWandering(monster, idleTrack, walkTrack)

	local running = true
	local currentState = "idle"

	-- Check if wandering is disabled
	if not MonsterConfig.ENABLE_WANDERING then
		return function()
			running = false
		end
	end

	-- Wandering loop
	task.spawn(function()
		-- Initial wait before wandering starts (so players can see spawn location)
		task.wait(MonsterConfig.INITIAL_WAIT)

		while running and monster and monster.Parent do
			-- Wait random duration
			local waitTime = math.random() * (MonsterConfig.WANDER_MAX_WAIT - MonsterConfig.WANDER_MIN_WAIT) + MonsterConfig.WANDER_MIN_WAIT
			task.wait(waitTime)

			-- Decide: walk or idle?
			if math.random() < MonsterConfig.WALK_CHANCE then
				-- WALK
				currentState = self:WalkToRandomLocation(monster, idleTrack, walkTrack, currentState)
			else
				-- IDLE
				if currentState ~= "idle" then
					self:SwitchToIdle(idleTrack, walkTrack)
					currentState = "idle"
				end
			end
		end

		-- Cleanup on exit
		if idleTrack then pcall(function() idleTrack:Stop() end) end
		if walkTrack then pcall(function() walkTrack:Stop() end) end
	end)

	-- Return cleanup function
	return function()
		running = false
	end
end

--[[
	Walks monster to a random room using pathfinding
]]
function MonsterMovement:WalkToRandomLocation(monster, idleTrack, walkTrack, currentState)
	local mansion = monster.Parent
	if not mansion then
		warn("[MonsterMovement] Monster not in mansion!")
		return "idle"
	end

	-- Find path to random room
	local waypoints = MonsterPathfinding:FindRandomPath(monster, mansion)
	if not waypoints or #waypoints == 0 then
		warn("[MonsterMovement] No path found!")
		return "idle"
	end


	-- Switch to walking animation
	self:SwitchToWalk(idleTrack, walkTrack)

	-- Walk through each waypoint
	for i, targetPos in ipairs(waypoints) do
		local rootPart = monster.PrimaryPart or monster:FindFirstChildWhichIsA("BasePart")
		if not rootPart or not monster.Parent then
			break
		end

		local currentPos = rootPart.Position
		local direction = (targetPos - currentPos).Unit
		local distance = (targetPos - currentPos).Magnitude
		local moveTime = distance / MonsterConfig.WALK_SPEED
		local startTime = tick()

		-- Move to this waypoint
		while tick() - startTime < moveTime and monster.Parent do
			local elapsed = tick() - startTime
			local alpha = elapsed / moveTime

			-- Calculate new position
			local newPos = currentPos + (direction * distance * alpha)

			-- Rotate to face movement direction (flip direction if model faces backward)
			local lookAt = CFrame.lookAt(newPos, newPos - direction)

			-- Update position
			monster:PivotTo(CFrame.new(newPos) * (lookAt - lookAt.Position))

			task.wait(0.03) -- ~30 FPS movement
		end
	end

	-- Switch back to idle after completing path
	self:SwitchToIdle(idleTrack, walkTrack)

	return "idle"
end

--[[
	Switches to idle animation
]]
function MonsterMovement:SwitchToIdle(idleTrack, walkTrack)
	if walkTrack then
		pcall(function() walkTrack:Stop() end)
	end
	if idleTrack then
		pcall(function() idleTrack:Play() end)
	end
end

--[[
	Switches to walk animation
]]
function MonsterMovement:SwitchToWalk(idleTrack, walkTrack)
	if idleTrack then
		pcall(function() idleTrack:Stop() end)
	end
	if walkTrack then
		pcall(function() walkTrack:Play() end)
	end
end

return MonsterMovement
