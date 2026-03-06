--[[
	FurnitureSpawner - Data-driven furniture spawning system

	Loads furniture configurations and spawns items according to their rules.
	Each furniture type has its own config file defining:
	- Model patterns to match
	- Spawn rules (where, when, conditions)
	- Positioning (offsets, rotations, placement)
]]

local InsertService = game:GetService("InsertService")
local ServerScriptService = game:GetService("ServerScriptService")

local RoomFurnitureSpawner = require(ServerScriptService.Modules.RoomFurnitureSpawner)

local FurnitureSpawner = {}

-- Configuration
local ASSET_PACK_ID = 10847897579

-- Load all individual model configs
local FurnitureFolder = ServerScriptService.Modules.Furniture
local ModelsFolder = FurnitureFolder.Models

-- Map of modelName -> config
local MODEL_CONFIGS = {}

-- Load all model configs from Models/ folder
for _, configModule in ipairs(ModelsFolder:GetChildren()) do
	if configModule:IsA("ModuleScript") then
		local config = require(configModule)
		if config.modelName then
			MODEL_CONFIGS[config.modelName] = config
		end
	end
end

-- Loaded models cache
local loadedModels = {}

-- Categorized models for room spawner
local categorizedModels = {
	ceilingLights = {},
	rugs = {},
	floorLamps = {},
	wallFurniture = {},
	beds = {}
}

--[[
	Loads the asset pack and categorizes models by config
]]
function FurnitureSpawner:LoadAssetPack()
	local success, pack = pcall(function()
		return InsertService:LoadAsset(ASSET_PACK_ID)
	end)

	if not success then
		warn("[FurnitureSpawner] Failed to load asset pack:", pack)
		return false
	end

	if not pack then
		warn("[FurnitureSpawner] LoadAsset returned nil for asset pack:", ASSET_PACK_ID)
		return false
	end

	-- Get all models from pack (recursively)
	local allDescendants = pack:GetDescendants()

	-- Clear categories
	categorizedModels.ceilingLights = {}
	categorizedModels.rugs = {}
	categorizedModels.floorLamps = {}
	categorizedModels.wallFurniture = {}
	categorizedModels.beds = {}

	-- Cache all models and categorize
	for _, descendant in pairs(allDescendants) do
		if descendant:IsA("Model") then
			loadedModels[descendant.Name] = descendant:Clone()

			-- Check if this model has a config
			local config = MODEL_CONFIGS[descendant.Name]
			if config then
				-- Categorize based on config.category
				if config.category == "ceilingLight" then
					table.insert(categorizedModels.ceilingLights, descendant.Name)
				elseif config.category == "rug" then
					table.insert(categorizedModels.rugs, descendant.Name)
				elseif config.category == "floorLamp" then
					table.insert(categorizedModels.floorLamps, descendant.Name)
				elseif config.category == "wallFurniture" then
					table.insert(categorizedModels.wallFurniture, descendant.Name)
				elseif config.category == "bed" then
					table.insert(categorizedModels.beds, descendant.Name)
				end
			end
		end
	end

	pack:Destroy()
	return true
end

--[[
	Gets a clone of a cached model
]]
function FurnitureSpawner:GetModel(modelName)
	if loadedModels[modelName] then
		return loadedModels[modelName]:Clone()
	end
	warn("[FurnitureSpawner] Model not found:", modelName)
	return nil
end

--[[
	Gets the config for a specific model
]]
function FurnitureSpawner:GetModelConfig(modelName)
	return MODEL_CONFIGS[modelName]
end

--[[
	Determines if a room is a dead-end (exactly 1 connection)
]]
local function IsDeadEndRoom(room)
	local connectionCount = 0
	for _, child in ipairs(room:GetChildren()) do
		if child.Name:match("^Connection_") then
			connectionCount = connectionCount + 1
		end
	end
	return connectionCount == 1
end

--[[
	Spawns all furniture in the mansion
]]
function FurnitureSpawner:SpawnAllFurniture(mansion, rooms, butlerPath)
	-- Ensure models are loaded
	if not next(loadedModels) then
		local success = self:LoadAssetPack()
		if not success then
			warn("[FurnitureSpawner] Cannot spawn furniture - asset pack failed to load")
			return
		end
	end

	-- Furnish each room individually
	for _, room in pairs(rooms) do
		-- Skip stairs rooms
		if room.Name:find("Stairs") then
			continue
		end

		-- Skip rooms with stairs or no floor (connecting rooms above stairs)
		if room:GetAttribute("HasStairs") or room:GetAttribute("NoFloor") then
			continue
		end

		-- Determine if this is a dead-end room
		local isDeadEnd = IsDeadEndRoom(room)

		-- Use RoomFurnitureSpawner to furnish this room
		RoomFurnitureSpawner:FurnishRoom(
			room,
			categorizedModels,
			function(modelName) return self:GetModel(modelName) end,
			function(modelName) return self:GetModelConfig(modelName) end,
			mansion,
			isDeadEnd
		)
	end
end

--[[
	Clears cached models
]]
function FurnitureSpawner:Cleanup()
	for name, model in pairs(loadedModels) do
		model:Destroy()
	end
	loadedModels = {}
	categorizedModels.ceilingLights = {}
	categorizedModels.rugs = {}
	categorizedModels.floorLamps = {}
	categorizedModels.wallFurniture = {}
	categorizedModels.beds = {}
end

return FurnitureSpawner
