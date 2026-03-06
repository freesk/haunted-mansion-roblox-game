--[[
	MonsterNPC - Main monster orchestrator

	A clean, simple interface for spawning and managing wandering monster NPCs.
	Uses modular components for spawning and movement.

	Usage:
		MonsterNPC:SpawnMonster(spawnCFrame, parent)
		MonsterNPC:CleanupAll()
]]

local MonsterConfig = require(script.Parent.Monster.MonsterConfig)
local MonsterSpawner = require(script.Parent.Monster.MonsterSpawner)
local MonsterMovement = require(script.Parent.Monster.MonsterMovement)
local AmbientSoundManager = require(script.Parent.AmbientSoundManager)

local MonsterNPC = {}

-- Active monsters state
local activeMonsters = {} -- {monster = Model, cleanup = function}

--[[
	Cleans up all monster NPCs
]]
function MonsterNPC:CleanupAll()
	for _, monsterData in ipairs(activeMonsters) do
		if monsterData.cleanup then
			monsterData.cleanup()
		end
		if monsterData.monster and monsterData.monster.Parent then
			monsterData.monster:Destroy()
		end
	end

	activeMonsters = {}
end

--[[
	Spawns a wandering monster NPC

	@param spawnCFrame CFrame - Where to spawn the monster
	@param parent Instance - Parent to attach monster to
	@return Model - Monster model or nil on failure
]]
function MonsterNPC:SpawnMonster(spawnCFrame, parent)
	-- Load monster model
	local monster, idleTrack, walkTrack = MonsterSpawner:LoadMonsterModel(spawnCFrame)
	if not monster then
		return nil
	end

	monster.Parent = parent

	-- Add kill zone for collision detection (reactive to debug toggle)
	MonsterSpawner:AddKillZone(monster)

	-- Add monster roar sound (proximity-based)
	AmbientSoundManager:AddMonsterSound(monster)

	-- Start wandering behavior
	local cleanup = MonsterMovement:StartWandering(monster, idleTrack, walkTrack)

	-- Track active monster
	table.insert(activeMonsters, {
		monster = monster,
		cleanup = cleanup
	})

	return monster
end

--[[
	Gets all active monster instances

	@return table - Array of monster models
]]
function MonsterNPC:GetActiveMonsters()
	local monsters = {}
	for _, monsterData in ipairs(activeMonsters) do
		if monsterData.monster and monsterData.monster.Parent then
			table.insert(monsters, monsterData.monster)
		end
	end
	return monsters
end

return MonsterNPC
