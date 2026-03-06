--[[
	Debug script to check stair openings between levels
	Run this after generating a mansion to see what's blocking the stairs
]]

local Workspace = game:GetService("Workspace")

local mansion = Workspace:FindFirstChild("ProceduralMansion")
if not mansion then
	warn("No mansion found in workspace")
	return
end

print("=== Checking Stair Openings ===")

-- Find rooms with stairs
for _, room in ipairs(mansion:GetChildren()) do
	local hasStairs = room:FindFirstChild("Step1")

	if hasStairs then
		print(string.format("\nFound stair room: %s", room.Name))

		-- Check if ceiling exists
		local ceiling = room:FindFirstChild("Ceiling")

		-- Check if floor exists
		local floor = room:FindFirstChild("Floor")

		-- Try to find the room above
		local levelMatch = room.Name:match("Room_L(%d+)")
		if levelMatch then
			local currentLevel = tonumber(levelMatch)
			local xMatch, zMatch = room.Name:match("X(%d+)_Z(%d+)")

			if xMatch and zMatch then
				local upperRoomName = string.format("Room_L%d_X%s_Z%s", currentLevel + 1, xMatch, zMatch)
				local upperRoom = mansion:FindFirstChild(upperRoomName)

				if upperRoom then
					print(string.format("  Found upper room: %s", upperRoomName))

					local upperFloor = upperRoom:FindFirstChild("Floor")
					if upperFloor then
						print("    ⚠️ UPPER FLOOR STILL EXISTS - should be removed!")
						print(string.format("       Position: %s", tostring(upperFloor.Position)))
						print(string.format("       Size: %s", tostring(upperFloor.Size)))
					else
						print("    ✓ Upper floor removed")
					end
				else
					print(string.format("  ⚠️ Upper room not found: %s", upperRoomName))
				end
			end
		end
	end
end

print("\n=== Check Complete ===")
