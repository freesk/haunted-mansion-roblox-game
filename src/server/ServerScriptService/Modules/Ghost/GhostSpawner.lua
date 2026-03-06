--[[
	GhostSpawner - Handles ghost model loading and setup

	Responsible for:
	- Loading ghost model from asset ID
	- Scaling and positioning
	- Making ghost semi-transparent and non-collidable (phases through walls)
]]

local InsertService = game:GetService("InsertService")
local ServerScriptService = game:GetService("ServerScriptService")

local GhostConfig = require(script.Parent.GhostConfig)
local DebugService = require(ServerScriptService.Services.DebugService)

local GhostSpawner = {}

--[[
	Loads the ghost model from Roblox asset ID

	@param spawnCFrame CFrame - Where to spawn
	@return Model - Ghost model
]]
function GhostSpawner:LoadGhostModel(spawnCFrame)

	-- Load from asset
	local model = nil
	local success, result = pcall(function()
		local assetModel = InsertService:LoadAsset(GhostConfig.ASSET_ID)
		local children = assetModel:GetChildren()

		for _, child in ipairs(children) do
			if child:IsA("Model") then
				model = child:Clone()
				child.Parent = nil
				break
			end
		end
		assetModel:Destroy()
	end)

	if not success then
		error("[Ghost] Failed to load asset: " .. tostring(result))
	end

	if not model then
		error("[Ghost] No Model found in asset")
	end

	model.Name = "GhostNPC"

	-- Setup primary part
	local primaryPart = model.PrimaryPart or self:FindPrimaryPart(model)
	if primaryPart then
		model.PrimaryPart = primaryPart
	else
		warn("[Ghost] Could not find primary part, using first part")
		for _, child in ipairs(model:GetChildren()) do
			if child:IsA("BasePart") then
				model.PrimaryPart = child
				break
			end
		end
	end

	-- Position and rotate ghost BEFORE scaling (important for non-rigged models)
	-- Apply rotation offset to make ghost upright (if configured)
	local finalCFrame = spawnCFrame
	if GhostConfig.ROTATION_OFFSET and typeof(GhostConfig.ROTATION_OFFSET) == "CFrame" then
		finalCFrame = spawnCFrame * GhostConfig.ROTATION_OFFSET
	end
	model:PivotTo(finalCFrame)

	-- Scale model (manual scaling for non-rigged models)
	if GhostConfig.SCALE ~= 1.0 then
		local scaleFactor = GhostConfig.SCALE

		-- Get pivot point for scaling relative to center
		local pivotCFrame = model:GetPivot()

		-- Scale all parts relative to pivot
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				-- Scale size
				descendant.Size = descendant.Size * scaleFactor

				-- Scale position relative to pivot using CFrame to preserve rotation
				local relativeCFrame = pivotCFrame:Inverse() * descendant.CFrame
				local scaledOffset = relativeCFrame.Position * scaleFactor
				local scaledCFrame = pivotCFrame * CFrame.new(scaledOffset) * (relativeCFrame - relativeCFrame.Position)
				descendant.CFrame = scaledCFrame
			end
		end
	end

	-- Setup ghost properties: transparent, non-collidable, phases through walls
	local partCount = 0
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			partCount = partCount + 1

			-- Make ghost phase through walls
			part.CanCollide = false
			part.Anchored = true
			part.Massless = true
			part.CastShadow = false

			-- Make ghost semi-transparent and ethereal
			local originalTransparency = part.Transparency
			part.Transparency = math.min(1, originalTransparency + 0.3) -- Make more transparent

			-- Give ghost a spooky glow
			if not part:FindFirstChildOfClass("PointLight") then
				local light = Instance.new("PointLight")
				light.Brightness = 3
				light.Color = Color3.fromRGB(180, 200, 255) -- Eerie pale blue glow
				light.Range = 10 -- Prominent glow effect
				light.Shadows = false
				light.Parent = part
			end
		end
	end

	print(string.format("[GhostSpawner] ✓ Ghost spawned at (%.1f, %.1f, %.1f) with %d parts",
		spawnCFrame.Position.X, spawnCFrame.Position.Y, spawnCFrame.Position.Z, partCount))

	return model
end

--[[
	Finds a suitable primary part for the model
]]
function GhostSpawner:FindPrimaryPart(model)
	local primaryPart = model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChild("Root")
		or model:FindFirstChild("Torso")
		or model:FindFirstChild("LowerTorso")
		or model:FindFirstChild("RootPart")

	if not primaryPart then
		-- If no standard parts, use first BasePart
		for _, child in ipairs(model:GetChildren()) do
			if child:IsA("BasePart") then
				return child
			end
		end
	end

	return primaryPart
end

--[[
	Adds kill zone to ghost (triggers when player touches)

	@param ghost Model - The ghost model
]]
function GhostSpawner:AddKillZone(ghost)
	if not ghost.PrimaryPart then
		warn("[GhostSpawner] Cannot add kill zone - no primary part")
		return
	end

	local killZone = Instance.new("Part")
	killZone.Name = "KillZone"
	killZone.Size = Vector3.new(4.2, 5.6, 4.2) -- Detection area around ghost (70% of original 6x8x6)
	killZone.Transparency = DebugService.ShowKillZones and 0.7 or 1 -- Visible when debug enabled
	killZone.Color = Color3.fromRGB(255, 0, 0) -- Red for visibility
	killZone.Material = Enum.Material.Neon -- Glowing effect
	killZone.CanCollide = true -- Must be true for Touched events to fire
	killZone.Anchored = true -- Match ghost anchoring
	killZone.Massless = true
	killZone.CastShadow = false

	killZone.Parent = ghost

	-- Position kill zone at ghost position and update it every frame
	local RunService = game:GetService("RunService")
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if ghost and ghost.Parent and ghost.PrimaryPart then
			killZone.CFrame = ghost.PrimaryPart.CFrame
		else
			-- Ghost destroyed, disconnect
			if connection then
				connection:Disconnect()
			end
			if killZone and killZone.Parent then
				killZone:Destroy()
			end
		end
	end)

	-- Track players we've already killed to prevent double-kills
	local killedPlayers = {}

	-- Touch event for player death (reactive to debug state)
	killZone.Touched:Connect(function(hit)
		-- Check debug state on every touch (reactive)
		if not DebugService.MonsterDeathEnabled then
			return
		end

		if not hit or not hit.Parent then return end

		-- Check if hit a player character
		local character = hit.Parent
		local humanoid = character:FindFirstChild("Humanoid")
		local player = game:GetService("Players"):GetPlayerFromCharacter(character)

		if player and humanoid and humanoid.Health > 0 then
			-- Prevent killing the same player multiple times
			if killedPlayers[player] then
				return
			end
			killedPlayers[player] = true

			-- Kill the player
			print("[GhostSpawner] Ghost killed player:", player.Name)

			-- Use ProximityService to kill player (proper death handling)
			local ProximityService = require(game:GetService("ServerScriptService").Services.ProximityService)
			ProximityService:KillPlayer(player)
		end
	end)

	print("[GhostSpawner] Added kill zone to ghost")
end

return GhostSpawner
