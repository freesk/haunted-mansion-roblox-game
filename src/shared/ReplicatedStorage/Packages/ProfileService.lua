--[[
	ProfileService - A simplified session-locked data store wrapper for Roblox
	This is a minimal implementation for basic data persistence with session locking
--]]

local ProfileService = {}

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local ProfileStores = {}
local ActiveProfiles = {}

-- Profile object
local Profile = {}
Profile.__index = Profile

function Profile.new(key, data, profileStore)
	local self = setmetatable({}, Profile)
	self.Key = key
	self.Data = data
	self._profileStore = profileStore
	self._released = false
	return self
end

function Profile:Release()
	if self._released then
		return
	end

	self._released = true
	self._profileStore:_ReleaseProfile(self)
end

function Profile:IsActive()
	return not self._released
end

-- ProfileStore object
local ProfileStore = {}
ProfileStore.__index = ProfileStore

function ProfileStore.new(storeName, template)
	local self = setmetatable({}, ProfileStore)
	self._storeName = storeName
	self._template = template

	-- Try to get DataStore, fall back to mock if unavailable (Studio without API access)
	local success, dataStore = pcall(function()
		return DataStoreService:GetDataStore(storeName)
	end)

	if success then
		self._dataStore = dataStore
		self._mockMode = false
		print("[ProfileService] Using real DataStore: " .. storeName)
	else
		warn("[ProfileService] DataStore unavailable - using MOCK mode (data won't persist)")
		self._dataStore = nil
		self._mockMode = true
		self._mockData = {} -- In-memory storage for testing
	end

	self._activeProfiles = {}
	return self
end

function ProfileStore:_DeepCopy(tbl)
	local copy = {}
	for key, value in pairs(tbl) do
		if type(value) == "table" then
			copy[key] = self:_DeepCopy(value)
		else
			copy[key] = value
		end
	end
	return copy
end

function ProfileStore:_GetDefaultData()
	return self:_DeepCopy(self._template)
end

function ProfileStore:LoadProfileAsync(key, notReleasedHandler)
	-- Check if profile already loaded
	if self._activeProfiles[key] then
		warn("[ProfileService] Profile " .. key .. " is already loaded in this server")
		return nil
	end

	local data

	if self._mockMode then
		-- Mock mode: use in-memory storage
		data = self._mockData[key]
		if not data then
			data = self:_GetDefaultData()
			self._mockData[key] = data
		end
		print("[ProfileService] Loaded mock profile: " .. key)
	else
		-- Real DataStore mode
		local success, result = pcall(function()
			return self._dataStore:GetAsync(key)
		end)

		if not success then
			warn("[ProfileService] Failed to load profile " .. key .. ": " .. tostring(result))
			return nil
		end

		-- If no data exists, use default template
		if not result then
			data = self:_GetDefaultData()
		else
			data = result
		end
	end

	-- Create profile object
	local profile = Profile.new(key, data, self)
	self._activeProfiles[key] = profile

	return profile
end

function ProfileStore:_ReleaseProfile(profile)
	if not profile._released then
		profile._released = true
	end

	-- Save data before releasing
	if self._mockMode then
		-- Mock mode: save to in-memory storage
		self._mockData[profile.Key] = profile.Data
		print("[ProfileService] Saved mock profile: " .. profile.Key)
	else
		-- Real DataStore mode
		local success, err = pcall(function()
			self._dataStore:UpdateAsync(profile.Key, function(oldData)
				return profile.Data
			end)
		end)

		if not success then
			warn("[ProfileService] Failed to save profile " .. profile.Key .. ": " .. tostring(err))
		end
	end

	-- Remove from active profiles
	self._activeProfiles[profile.Key] = nil
end

function ProfileStore:ViewProfileAsync(key)
	local success, data = pcall(function()
		return self._dataStore:GetAsync(key)
	end)

	if not success then
		warn("[ProfileService] Failed to view profile " .. key .. ": " .. tostring(data))
		return nil
	end

	return data or self:_GetDefaultData()
end

-- ProfileService API
function ProfileService.GetProfileStore(storeName, template)
	if ProfileStores[storeName] then
		return ProfileStores[storeName]
	end

	local store = ProfileStore.new(storeName, template)
	ProfileStores[storeName] = store
	return store
end

-- Auto-save active profiles periodically
task.spawn(function()
	while true do
		task.wait(60) -- Auto-save every 60 seconds

		for storeName, store in pairs(ProfileStores) do
			for key, profile in pairs(store._activeProfiles) do
				if profile:IsActive() then
					pcall(function()
						store._dataStore:UpdateAsync(key, function(oldData)
							return profile.Data
						end)
					end)
				end
			end
		end
	end
end)

return ProfileService
