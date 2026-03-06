--[[
	ProximityUIModule - Return to Butler Warning UI Component

	Creates a responsive warning modal that displays when player is too far from butler.
	- Max 20% of screen height
	- Max 30% of screen width
	- Positioned at top with padding
]]

local TweenService = game:GetService("TweenService")

local ProximityUIModule = {}

-- UI element references
local screenGui = nil
local overlay = nil
local warningContainer = nil
local warningLabel = nil
local countdownLabel = nil
local pulseTween = nil

-- Configuration
local CONFIG = {
	MAX_WIDTH_PERCENT = 0.4,  -- 40% of screen width
	MAX_HEIGHT_PERCENT = 0.25, -- 25% of screen height
	TOP_PADDING_PERCENT = 0.05, -- 5% from top of screen (responsive)
	CORNER_RADIUS = 4,        -- Subtle rounded corners
	CONTENT_PADDING = 0.07,   -- 7% internal padding
}

-- Pulse animation info
local pulseInfo = TweenInfo.new(
	0.5,
	Enum.EasingStyle.Sine,
	Enum.EasingDirection.InOut,
	-1,
	true,
	0
)

-- Create the UI elements
function ProximityUIModule:CreateUI(playerGui)
	-- Create ScreenGui
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ProximityUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 100
	screenGui.Parent = playerGui

	-- Create full-screen overlay
	overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.Position = UDim2.new(0, 0, 0, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 1
	overlay.Visible = false
	overlay.Parent = screenGui

	-- Add UIGradient for vignette effect
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0.9)
	})
	gradient.Rotation = 90
	gradient.Parent = overlay

	-- Create warning container (fully responsive sizing)
	warningContainer = Instance.new("Frame")
	warningContainer.Name = "WarningContainer"
	-- Use UDim2 with scale for full responsiveness
	warningContainer.Size = UDim2.new(CONFIG.MAX_WIDTH_PERCENT, 0, CONFIG.MAX_HEIGHT_PERCENT, 0)
	warningContainer.Position = UDim2.new(0.5, 0, CONFIG.TOP_PADDING_PERCENT, 0)
	warningContainer.AnchorPoint = Vector2.new(0.5, 0) -- Center horizontally, anchor to top
	warningContainer.BackgroundTransparency = 0.4
	warningContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	warningContainer.BorderSizePixel = 0
	warningContainer.ZIndex = 10
	warningContainer.Visible = false
	warningContainer.Parent = screenGui

	-- Add corner radius
	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, CONFIG.CORNER_RADIUS)
	containerCorner.Parent = warningContainer

	-- Add padding to container
	local containerPadding = Instance.new("UIPadding")
	containerPadding.PaddingTop = UDim.new(CONFIG.CONTENT_PADDING, 0)
	containerPadding.PaddingBottom = UDim.new(CONFIG.CONTENT_PADDING, 0)
	containerPadding.PaddingLeft = UDim.new(CONFIG.CONTENT_PADDING, 0)
	containerPadding.PaddingRight = UDim.new(CONFIG.CONTENT_PADDING, 0)
	containerPadding.Parent = warningContainer

	-- Warning text
	warningLabel = Instance.new("TextLabel")
	warningLabel.Name = "WarningLabel"
	warningLabel.Size = UDim2.new(1, 0, 0.35, 0) -- Increased height for full text
	warningLabel.Position = UDim2.new(0.5, 0, 0.02, 0)
	warningLabel.AnchorPoint = Vector2.new(0.5, 0)
	warningLabel.BackgroundTransparency = 1
	warningLabel.Text = "RETURN TO BUTLER!"
	warningLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	warningLabel.TextScaled = true
	warningLabel.Font = Enum.Font.GothamBold
	warningLabel.TextStrokeTransparency = 0
	warningLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	warningLabel.TextXAlignment = Enum.TextXAlignment.Center
	warningLabel.TextYAlignment = Enum.TextYAlignment.Center
	warningLabel.ZIndex = 11
	warningLabel.Parent = warningContainer

	-- Text size constraint with larger max
	local warningTextConstraint = Instance.new("UITextSizeConstraint")
	warningTextConstraint.MaxTextSize = 80
	warningTextConstraint.MinTextSize = 12
	warningTextConstraint.Parent = warningLabel

	-- Countdown number
	countdownLabel = Instance.new("TextLabel")
	countdownLabel.Name = "CountdownLabel"
	countdownLabel.Size = UDim2.new(1, 0, 0.55, 0) -- Adjusted for better fit
	countdownLabel.Position = UDim2.new(0.5, 0, 0.65, 0) -- Center position
	countdownLabel.AnchorPoint = Vector2.new(0.5, 0.5) -- Center anchor for scaling from center
	countdownLabel.BackgroundTransparency = 1
	countdownLabel.Text = "10"
	countdownLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
	countdownLabel.TextScaled = true
	countdownLabel.Font = Enum.Font.GothamBold
	countdownLabel.TextStrokeTransparency = 0
	countdownLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	countdownLabel.TextXAlignment = Enum.TextXAlignment.Center
	countdownLabel.TextYAlignment = Enum.TextYAlignment.Center
	countdownLabel.ZIndex = 11
	countdownLabel.Parent = warningContainer

	-- Text size constraint with larger range
	local countdownTextConstraint = Instance.new("UITextSizeConstraint")
	countdownTextConstraint.MaxTextSize = 200
	countdownTextConstraint.MinTextSize = 30
	countdownTextConstraint.Parent = countdownLabel

	return screenGui
end

-- Update countdown display
function ProximityUIModule:UpdateCountdown(timeLeft, active)
	if not warningContainer or not countdownLabel or not overlay then
		warn("[ProximityUIModule] UI not initialized")
		return
	end

	if active and timeLeft > 0 then
		-- Show overlay and countdown container
		overlay.Visible = true
		warningContainer.Visible = true
		countdownLabel.Text = tostring(timeLeft)

		-- Change color based on urgency
		if timeLeft <= 3 then
			countdownLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
			warningContainer.BackgroundColor3 = Color3.fromRGB(60, 0, 0)
			warningContainer.BackgroundTransparency = 0.3
			overlay.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
			overlay.BackgroundTransparency = 0.5
		elseif timeLeft <= 5 then
			countdownLabel.TextColor3 = Color3.fromRGB(255, 100, 0)
			warningContainer.BackgroundColor3 = Color3.fromRGB(40, 0, 0)
			warningContainer.BackgroundTransparency = 0.35
			overlay.BackgroundColor3 = Color3.fromRGB(50, 0, 0)
			overlay.BackgroundTransparency = 0.7
		else
			countdownLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
			warningContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
			warningContainer.BackgroundTransparency = 0.4
			overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			overlay.BackgroundTransparency = 0.85
		end

		-- Start pulse animation (scales from center due to AnchorPoint 0.5, 0.5)
		if not pulseTween then
			pulseTween = TweenService:Create(
				countdownLabel,
				pulseInfo,
				{Size = UDim2.new(1.1, 0, 0.65, 0)} -- Pulse by growing from center
			)
			pulseTween:Play()
		end
	else
		-- Hide everything
		overlay.Visible = false
		warningContainer.Visible = false

		if pulseTween then
			pulseTween:Cancel()
			pulseTween = nil
			-- Reset size to original
			countdownLabel.Size = UDim2.new(1, 0, 0.55, 0)
		end
	end
end

-- Handle death (hide UI)
function ProximityUIModule:OnDeath()
	if overlay then
		overlay.Visible = false
	end

	if warningContainer then
		warningContainer.Visible = false
	end

	if pulseTween then
		pulseTween:Cancel()
		pulseTween = nil
		-- Reset size to original
		if countdownLabel then
			countdownLabel.Size = UDim2.new(1, 0, 0.55, 0)
		end
	end
end

-- Cleanup
function ProximityUIModule:Destroy()
	if pulseTween then
		pulseTween:Cancel()
		pulseTween = nil
	end

	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end

	overlay = nil
	warningContainer = nil
	warningLabel = nil
	countdownLabel = nil
end

return ProximityUIModule
