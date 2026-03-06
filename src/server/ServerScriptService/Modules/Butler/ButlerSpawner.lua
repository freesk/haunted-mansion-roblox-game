--[[
	ButlerSpawner - Handles butler model loading and setup

	Responsible for:
	- Loading butler model from asset ID
	- Setting up animations
	- Attaching lantern to right hand (no lights)
	- Scaling and positioning
]]

local InsertService = game:GetService("InsertService")
local ButlerConfig = require(script.Parent.ButlerConfig)

local ButlerSpawner = {}

--[[
	Loads the butler model from Roblox asset ID

	@param spawnCFrame CFrame - Where to spawn
	@param useYOffset boolean - Whether to apply Y offset
	@return Model - Butler model
	@return AnimationTrack - Walk animation track
]]
function ButlerSpawner:LoadButlerModel(spawnCFrame, useYOffset)

	-- Load from asset
	local model = nil
	local success, result = pcall(function()
		local assetModel = InsertService:LoadAsset(ButlerConfig.ASSET_ID)
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
		error("[ButlerSpawner] Failed to load butler asset (ID: " .. ButlerConfig.ASSET_ID .. "): " .. tostring(result))
	end

	if not model then
		error("[ButlerSpawner] No Model found in asset (ID: " .. ButlerConfig.ASSET_ID .. "). The asset may not contain a Model instance.")
	end

	model.Name = "ButlerNPC"

	-- Setup primary part
	local primaryPart = model.PrimaryPart or self:FindPrimaryPart(model)
	if primaryPart then
		model.PrimaryPart = primaryPart
	else
		error("[ButlerSpawner] Could not find primary part")
	end

	-- Setup animation
	local walkTrack = self:SetupAnimation(model)

	-- Scale model
	if ButlerConfig.SCALE ~= 1.0 then
		if model.ScaleTo then
			model:ScaleTo(ButlerConfig.SCALE)
		else
			for _, descendant in ipairs(model:GetDescendants()) do
				if descendant:IsA("BasePart") then
					descendant.Size = descendant.Size * ButlerConfig.SCALE
				end
			end
		end
	end

	-- Position butler
	local adjustedSpawnCFrame = spawnCFrame
	if useYOffset then
		-- Lobby mode: apply Y offset to raise butler above ground
		adjustedSpawnCFrame = spawnCFrame * CFrame.new(0, ButlerConfig.LOBBY_Y_OFFSET, 0)
	else
		-- Mansion mode: apply Y offset for fine-tuning height
		adjustedSpawnCFrame = spawnCFrame * CFrame.new(0, ButlerConfig.MANSION_Y_OFFSET, 0)
	end
	model:PivotTo(adjustedSpawnCFrame)

	-- Make non-physical (no collisions)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Anchored = true
			part.Massless = true
			part.CastShadow = true  -- Enable shadow casting
		end
	end

	-- Add lantern to right hand
	self:AddLantern(model)

	return model, walkTrack
end

--[[
	Finds a suitable primary part for the model
]]
function ButlerSpawner:FindPrimaryPart(model)
	local primaryPart = model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChild("Root")
		or model:FindFirstChild("Torso")
		or model:FindFirstChild("LowerTorso")

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
	Sets up animation controller and loads walk animation
]]
function ButlerSpawner:SetupAnimation(model)
	local animController = model:FindFirstChildOfClass("AnimationController")
	if not animController then
		animController = Instance.new("AnimationController")
		animController.Parent = model
	end

	local animator = animController:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = animController
	end

	local walkAnimation = Instance.new("Animation")
	walkAnimation.AnimationId = "rbxassetid://" .. ButlerConfig.ANIMATION_ID
	walkAnimation.Name = "ButlerWalkAnimation"

	local walkTrack = nil
	local success, result = pcall(function()
		walkTrack = animator:LoadAnimation(walkAnimation)
		walkTrack.Looped = true
		walkTrack.Priority = Enum.AnimationPriority.Action
		walkTrack:Play()
	end)

	if success and walkTrack then
	else
		warn("[ButlerSpawner] Animation failed:", result)
	end

	return walkTrack
end

--[[
	Adds lantern to the butler
]]
function ButlerSpawner:AddLantern(model)
	-- Find right hand bone by exact name
	local rightHand = model:FindFirstChild("mixamorig:RightHand", true)
	if not rightHand then
		warn("[ButlerSpawner] Could not find mixamorig:RightHand bone")
		return
	end

	-- Load lantern asset
	local success, assetModel = pcall(function()
		return InsertService:LoadAsset(ButlerConfig.LANTERN_ASSET_ID)
	end)
	if not success then
		warn("[ButlerSpawner] Failed to load lantern")
		return
	end

	-- Debug: Print what's in the asset
	print("[ButlerSpawner] Asset children:")
	for _, child in ipairs(assetModel:GetChildren()) do
		print("  - " .. child.Name .. " (" .. child.ClassName .. ")")
	end

	-- Find Model or BasePart (skip Tools)
	local lantern = nil
	for _, child in ipairs(assetModel:GetChildren()) do
		if child:IsA("Model") or child:IsA("BasePart") then
			lantern = child:Clone()
			print("[ButlerSpawner] Using: " .. child.Name .. " (" .. child.ClassName .. ")")
			break
		end
	end
	assetModel:Destroy()

	if not lantern then
		warn("[ButlerSpawner] No Model or BasePart found in lantern asset")
		return
	end

	-- Make all parts non-collidable and anchored
	for _, part in ipairs(lantern:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Anchored = true
			part.Transparency = 0
			print("[ButlerSpawner] Part: " .. part.Name .. " Size: " .. tostring(part.Size))
		end
		if part:IsA("PointLight") or part:IsA("SpotLight") then
			part.Enabled = true
			part.Brightness = ButlerConfig.LANTERN_LIGHT_BRIGHTNESS
			part.Range = ButlerConfig.LANTERN_LIGHT_RANGE
			print("[ButlerSpawner] Light: " .. part.ClassName)
		end
	end

	-- Set PrimaryPart if Model
	if lantern:IsA("Model") and not lantern.PrimaryPart then
		local firstPart = lantern:FindFirstChildWhichIsA("BasePart", true)
		if firstPart then
			lantern.PrimaryPart = firstPart
			print("[ButlerSpawner] Set PrimaryPart to: " .. firstPart.Name)
		end
	end

	lantern.Parent = model

	-- Initial position
	local targetCFrame = rightHand.WorldCFrame * CFrame.new(
		ButlerConfig.LANTERN_OFFSET_X,
		ButlerConfig.LANTERN_OFFSET_Y,
		ButlerConfig.LANTERN_OFFSET_Z
	) * CFrame.Angles(
		math.rad(ButlerConfig.LANTERN_ROTATION_X),
		math.rad(ButlerConfig.LANTERN_ROTATION_Y),
		math.rad(ButlerConfig.LANTERN_ROTATION_Z)
	)

	if lantern:IsA("Model") then
		lantern:PivotTo(targetCFrame)
	else
		lantern.CFrame = targetCFrame
	end

	-- Continuously update lantern position as butler moves/animates
	local RunService = game:GetService("RunService")
	RunService.Heartbeat:Connect(function()
		if not model.Parent or not rightHand.Parent or not lantern.Parent then
			return
		end

		local updatedCFrame = rightHand.WorldCFrame * CFrame.new(
			ButlerConfig.LANTERN_OFFSET_X,
			ButlerConfig.LANTERN_OFFSET_Y,
			ButlerConfig.LANTERN_OFFSET_Z
		) * CFrame.Angles(
			math.rad(ButlerConfig.LANTERN_ROTATION_X),
			math.rad(ButlerConfig.LANTERN_ROTATION_Y),
			math.rad(ButlerConfig.LANTERN_ROTATION_Z)
		)

		if lantern:IsA("Model") then
			lantern:PivotTo(updatedCFrame)
		else
			lantern.CFrame = updatedCFrame
		end
	end)

	print("[ButlerSpawner] Lantern attached with continuous update")
end

return ButlerSpawner
