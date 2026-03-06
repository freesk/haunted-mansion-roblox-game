--[[
	MonsterSpawner - Handles monster model loading and setup

	Responsible for:
	- Loading monster model from asset ID
	- Setting up animations (idle + walk)
	- Scaling and positioning
	- Physical collision setup
]]

local InsertService = game:GetService("InsertService")
local ServerScriptService = game:GetService("ServerScriptService")

local MonsterConfig = require(script.Parent.MonsterConfig)
local DebugService = require(ServerScriptService.Services.DebugService)

local MonsterSpawner = {}

--[[
	Loads the monster model from Roblox asset ID

	@param spawnCFrame CFrame - Where to spawn
	@return Model - Monster model
	@return AnimationTrack - Idle animation track
	@return AnimationTrack - Walk animation track
]]
function MonsterSpawner:LoadMonsterModel(spawnCFrame)

	-- Load from asset
	local model = nil
	local success, result = pcall(function()
		local assetModel = InsertService:LoadAsset(MonsterConfig.ASSET_ID)
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
		error("[Monster] Failed to load asset: " .. tostring(result))
	end

	if not model then
		error("[Monster] No Model found in asset")
	end

	model.Name = "MonsterNPC"

	-- Setup primary part
	local primaryPart = model.PrimaryPart or self:FindPrimaryPart(model)
	if primaryPart then
		model.PrimaryPart = primaryPart
	else
		error("[Monster] Could not find primary part")
	end

	-- Setup animations (idle + walk)
	local idleTrack, walkTrack = self:SetupAnimations(model)

	-- Scale model
	if MonsterConfig.SCALE ~= 1.0 then
		if model.ScaleTo then
			model:ScaleTo(MonsterConfig.SCALE)
		else
			for _, descendant in ipairs(model:GetDescendants()) do
				if descendant:IsA("BasePart") then
					descendant.Size = descendant.Size * MonsterConfig.SCALE
				end
			end
		end
	end

	-- Position monster (Y offset should be applied by caller, not here)
	model:PivotTo(spawnCFrame)

	-- Setup parts like butler (anchored, no collision for now)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Anchored = true
			part.Massless = true
			part.CastShadow = MonsterConfig.ENABLE_SHADOWS
		end
	end

	return model, idleTrack, walkTrack
end

--[[
	Finds a suitable primary part for the model
]]
function MonsterSpawner:FindPrimaryPart(model)
	local primaryPart = model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChild("Root")
		or model:FindFirstChild("Torso")
		or model:FindFirstChild("LowerTorso")
		or model:FindFirstChild("RootPart")

	if not primaryPart then
		for _, child in ipairs(model:GetDescendants()) do
			if child:IsA("BasePart") and child.Name:lower():find("root") then
				return child
			end
		end
	end

	if not primaryPart then
		primaryPart = model:FindFirstChildOfClass("BasePart")
	end

	return primaryPart
end

--[[
	Sets up animation controller and loads idle + walk animations
]]
function MonsterSpawner:SetupAnimations(model)
	local animController = model:FindFirstChildOfClass("AnimationController")
	if not animController then
		animController = Instance.new("AnimationController")
		animController.Parent = model
	end

	local animator = animController:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = animController
		task.wait(0.1)
	end

	-- Set root part if available
	local rootPart = model:FindFirstChild("RootPart") or model.PrimaryPart
	if rootPart then
		pcall(function()
			animController.RootPart = rootPart
		end)
	end

	-- Load idle animation
	local idleAnimation = Instance.new("Animation")
	idleAnimation.AnimationId = "rbxassetid://" .. MonsterConfig.ANIM_IDLE
	idleAnimation.Name = "MonsterIdleAnimation"

	local idleTrack = nil
	local success, result = pcall(function()
		idleTrack = animator:LoadAnimation(idleAnimation)
		idleTrack.Looped = true
		idleTrack.Priority = Enum.AnimationPriority.Action
		idleTrack:Play()
	end)

	if success and idleTrack then
	else
		warn("[MonsterSpawner] Idle animation failed:", result)
	end

	-- Load walk animation
	local walkAnimation = Instance.new("Animation")
	walkAnimation.AnimationId = "rbxassetid://" .. MonsterConfig.ANIM_WALK
	walkAnimation.Name = "MonsterWalkAnimation"

	local walkTrack = nil
	success, result = pcall(function()
		walkTrack = animator:LoadAnimation(walkAnimation)
		walkTrack.Looped = true
		walkTrack.Priority = Enum.AnimationPriority.Action
	end)

	return idleTrack, walkTrack
end

--[[
	Adds a collision detection part to kill players on touch

	@param monster Model - The monster model
]]
function MonsterSpawner:AddKillZone(monster)
	if not monster or not monster.PrimaryPart then
		warn("[MonsterSpawner] Invalid monster for kill zone")
		return
	end

	-- Create an invisible collision part around the monster
	local killZone = Instance.new("Part")
	killZone.Name = "KillZone"
	killZone.Size = Vector3.new(4, 5, 4)  -- 4x5x4 stud collision box (not scaled with monster)
	killZone.CFrame = monster.PrimaryPart.CFrame * CFrame.new(0, 2.5, 0) -- Raised by half height to center on monster
	killZone.Transparency = DebugService.ShowKillZones and 0.7 or 1  -- Visible when debug enabled
	killZone.Color = Color3.fromRGB(255, 0, 0) -- Red for visibility
	killZone.Material = Enum.Material.Neon -- Glowing effect
	killZone.CanCollide = false  -- Ghost through walls
	killZone.Anchored = false
	killZone.Massless = true
	killZone.Parent = monster

	-- Weld to monster so it follows
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = monster.PrimaryPart
	weld.Part1 = killZone
	weld.Parent = killZone

	-- Track players we've already killed to prevent double-kills
	local killedPlayers = {}

	-- Set up touch detection (reactive to debug state)
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
			print("[MonsterSpawner] Monster killed player:", player.Name)

			-- Use ProximityService to kill player (proper death handling)
			local ProximityService = require(game:GetService("ServerScriptService").Services.ProximityService)
			ProximityService:KillPlayer(player)
		end
	end)

	print("[MonsterSpawner] Added kill zone to monster")
end

return MonsterSpawner
