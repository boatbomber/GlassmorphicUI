--!strict
--!native
--!optimize 2

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local EditableImageBlur, PixelColorApproximation
local Packages = script:FindFirstChild("Packages") or script.Parent
local EditableImageBlurModule = Packages:FindFirstChild("EditableImageBlur")
local PixelColorApproximationModule = Packages:FindFirstChild("PixelColorApproximation")

if
	EditableImageBlurModule
	and EditableImageBlurModule:IsA("ModuleScript")
	and PixelColorApproximationModule
	and PixelColorApproximationModule:IsA("ModuleScript")
then
	EditableImageBlur = require(EditableImageBlurModule)
	PixelColorApproximation = require(PixelColorApproximationModule)
end

if not EditableImageBlur or not PixelColorApproximation then
	error("Could not find required packages")
end

local EMPTY_TABLE = {}

type GlassObject = {
	Window: ImageLabel,
	EditableImage: EditableImage,
	Pixels: { number },
	PixelIndex: number,
	InterlaceOffsetFlag: boolean,
	Resolution: Vector2,
	ResolutionInverse: Vector2,
	WindowSizeX: number,
	WindowSizeY: number,
	WindowPositionX: number,
	WindowPositionY: number,
	WindowColor: { number },
	BlurRadius: number,
	Paused: boolean,
}

local GlassmorphicUI = {}

GlassmorphicUI._glassObjects = {} :: { GlassObject }
GlassmorphicUI._glassObjectUpdateIndex = 1
GlassmorphicUI._windowToObject = setmetatable({} :: { [ImageLabel]: GlassObject }, { __mode = "k" })

GlassmorphicUI.MAX_AXIS_SAMPLING_RES = 39
GlassmorphicUI.UPDATE_TIME_BUDGET = 3e-3
GlassmorphicUI.RADIUS = 5
GlassmorphicUI.TEMPORAL_SMOOTHING = 0.75
GlassmorphicUI.TAG_NAME = "GlassmorphicUI"
GlassmorphicUI.BLUR_RADIUS_ATTRIBUTE_NAME = "BlurRadius"

function GlassmorphicUI.new(): ImageLabel
	local Window = Instance.new("ImageLabel")
	-- Some reasonable defaults
	Window.Size = UDim2.fromScale(50, 30)
	Window.BackgroundColor3 = Color3.fromRGB(130, 215, 255)
	Window.BorderSizePixel = 0
	Window.BackgroundTransparency = 0.8
	Window.Name = "GlassmorphicUI"
	Window:AddTag(GlassmorphicUI.TAG_NAME)

	GlassmorphicUI._setupGlassWindow(Window)

	return Window
end

function GlassmorphicUI.setDefaultBlurRadius(radius: number)
	if type(radius) ~= "number" then
		return
	end
	GlassmorphicUI.RADIUS = math.clamp(math.round(radius), 1, GlassmorphicUI.MAX_AXIS_SAMPLING_RES / 2)
end

function GlassmorphicUI.applyGlassToImageLabel(ImageLabel: ImageLabel)
	if typeof(ImageLabel) == "Instance" and ImageLabel:IsA("ImageLabel") then
		ImageLabel:AddTag(GlassmorphicUI.TAG_NAME)
	end
end

function GlassmorphicUI.addGlassBackground(GuiObject: GuiObject): ImageLabel
	if typeof(GuiObject) ~= "Instance" or not GuiObject:IsA("GuiObject") then
		error("Expected GuiObject, got " .. typeof(GuiObject))
	end

	-- Ensure the glass isn't obstructed by the object
	GuiObject.BackgroundTransparency = 1
	GuiObject:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function()
		GuiObject.BackgroundTransparency = 1
	end)

	local glassBackground = GlassmorphicUI.new()
	glassBackground.Size = UDim2.fromScale(1, 1)
	glassBackground.Position = UDim2.fromScale(0, 0)
	glassBackground.ZIndex = -999999
	glassBackground.Parent = GuiObject

	return glassBackground
end

function GlassmorphicUI.forceUpdate(Window: ImageLabel): ImageLabel
	local glassObject = GlassmorphicUI._windowToObject[Window]
	if glassObject then
		GlassmorphicUI._totalUpdate(glassObject)
	end
	return Window
end

function GlassmorphicUI.pauseUpdates(Window: ImageLabel): ImageLabel
	local glassObject = GlassmorphicUI._windowToObject[Window]
	if glassObject then
		glassObject.Paused = true
		local index = table.find(GlassmorphicUI._glassObjects, glassObject)
		if index then
			table.remove(GlassmorphicUI._glassObjects, index)
		end
	end
	return Window
end

function GlassmorphicUI.resumeUpdates(Window: ImageLabel): ImageLabel
	local glassObject = GlassmorphicUI._windowToObject[Window]
	if glassObject then
		glassObject.Paused = false
		if not table.find(GlassmorphicUI._glassObjects, glassObject) then
			table.insert(GlassmorphicUI._glassObjects, glassObject)
		end
	end
	return Window
end

function GlassmorphicUI._totalUpdate(glassObject: GlassObject)
	-- Perform a complete update
	local startPixel = glassObject.PixelIndex
	while true do
		GlassmorphicUI._processNextPixel(glassObject, true)
		if glassObject.PixelIndex == startPixel then
			break
		end
	end
	EditableImageBlur({
		image = glassObject.EditableImage,
		pixelData = glassObject.Pixels,
		blurRadius = glassObject.BlurRadius,
		downscaleFactor = 1,
		skipAlpha = true,
	})
end

function GlassmorphicUI._getGlassObject(Window: ImageLabel): GlassObject
	local glassObject = GlassmorphicUI._windowToObject[Window]
	if not glassObject then
		local EditableImage: EditableImage
		local ExistingEditableImage = Window:FindFirstChildWhichIsA("EditableImage")
		if ExistingEditableImage then
			EditableImage = ExistingEditableImage
		else
			EditableImage = Instance.new("EditableImage")
			EditableImage.Parent = Window
		end

		glassObject = {
			Window = Window,
			EditableImage = EditableImage,
			Pixels = {},
			PixelIndex = 1,
			InterlaceOffsetFlag = true,
			Resolution = Vector2.one,
			ResolutionInverse = Vector2.one,
			WindowSizeX = 1,
			WindowSizeY = 1,
			WindowPositionX = 0,
			WindowPositionY = 0,
			WindowColor = {
				Window.BackgroundColor3.R,
				Window.BackgroundColor3.G,
				Window.BackgroundColor3.B,
				1 - Window.BackgroundTransparency,
			},
			BlurRadius = GlassmorphicUI.RADIUS,
			Paused = false,
		}
		GlassmorphicUI._windowToObject[Window] = glassObject
	end
	return glassObject
end

function GlassmorphicUI._setupGlassWindow(Window: ImageLabel)
	if GlassmorphicUI._windowToObject[Window] then
		-- This window is already set up
		return Window
	end

	local glassObject = GlassmorphicUI._getGlassObject(Window)
	GlassmorphicUI._watchProperties(glassObject)

	Window.Destroying:Connect(function()
		GlassmorphicUI._removeInstance(Window)
	end)

	GlassmorphicUI._onInitialParented(Window, function()
		GlassmorphicUI._updateWindowColor(glassObject)
		GlassmorphicUI._updateWindowPosition(glassObject)
		GlassmorphicUI._updateWindowSize(glassObject)
		GlassmorphicUI._updateWindowBlurRadius(glassObject)

		GlassmorphicUI._totalUpdate(glassObject)

		if not glassObject.Paused then
			table.insert(GlassmorphicUI._glassObjects, glassObject)
		end
	end)

	return Window
end

function GlassmorphicUI._onInitialParented(Object: GuiObject, callback: () -> nil)
	if Object:IsDescendantOf(game) then
		task.spawn(callback)
	else
		local initializeConnection
		initializeConnection = Object.AncestryChanged:Connect(function()
			if not Object:IsDescendantOf(game) then
				return
			end

			initializeConnection:Disconnect()

			-- Wait for window properties to load in engine
			if
				Object.Size.X.Offset == 0
				and Object.Size.Y.Offset == 0
				and Object.Size.X.Scale == 0
				and Object.Size.Y.Scale == 0
			then
				-- I don't know how to tell if it loaded since the expected size is actually 0
				task.wait()
			else
				local absoluteSize = Object.AbsoluteSize
				while task.wait() do
					if absoluteSize.X ~= 0 or absoluteSize.Y ~= 0 then
						break
					end
					absoluteSize = Object.AbsoluteSize
				end
			end

			callback()
		end)
	end
end

function GlassmorphicUI._watchProperties(glassObject: GlassObject)
	local Window = glassObject.Window

	Window:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
		GlassmorphicUI._updateWindowPosition(glassObject)
	end)
	Window:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		GlassmorphicUI._updateWindowSize(glassObject)
	end)
	Window:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
		GlassmorphicUI._updateWindowColor(glassObject)
	end)
	Window:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function()
		GlassmorphicUI._updateWindowColor(glassObject)
	end)
	Window:GetAttributeChangedSignal(GlassmorphicUI.BLUR_RADIUS_ATTRIBUTE_NAME):Connect(function(radius)
		GlassmorphicUI._updateWindowBlurRadius(glassObject, radius)
	end)
end

function GlassmorphicUI._updateWindowBlurRadius(glassObject: GlassObject, radius: number?)
	if not radius then
		radius = glassObject.Window:GetAttribute(GlassmorphicUI.BLUR_RADIUS_ATTRIBUTE_NAME)
	end
	if type(radius) ~= "number" then
		return
	end
	glassObject.BlurRadius = math.clamp(math.round(radius), 1, GlassmorphicUI.MAX_AXIS_SAMPLING_RES / 2)
end

function GlassmorphicUI._updateWindowPosition(glassObject: GlassObject)
	local Window = glassObject.Window
	local absolutePosition = Window.AbsolutePosition
	glassObject.WindowPositionX = absolutePosition.X
	glassObject.WindowPositionY = absolutePosition.Y
end

function GlassmorphicUI._updateWindowColor(glassObject: GlassObject)
	local Window = glassObject.Window
	local windowAlpha = 1 - Window.BackgroundTransparency
	local windowColor = Window.BackgroundColor3
	glassObject.WindowColor[1] = windowColor.R
	glassObject.WindowColor[2] = windowColor.G
	glassObject.WindowColor[3] = windowColor.B
	glassObject.WindowColor[4] = windowAlpha
end

function GlassmorphicUI._updateWindowSize(glassObject: GlassObject)
	local Window = glassObject.Window

	local absoluteSize = Window.AbsoluteSize
	local windowSizeX, windowSizeY = absoluteSize.X, absoluteSize.Y

	if windowSizeX == 0 or windowSizeY == 0 then
		return
	end

	glassObject.WindowSizeX = windowSizeX
	glassObject.WindowSizeY = windowSizeY

	local maxAxis = math.max(windowSizeX, windowSizeY)
	local samplerSize = maxAxis / math.min(GlassmorphicUI.MAX_AXIS_SAMPLING_RES, maxAxis)

	local resolutionX, resolutionY = windowSizeX // samplerSize, windowSizeY // samplerSize
	local inverseResX, inverseResY = 1 / resolutionX, 1 / resolutionY

	glassObject.Resolution = Vector2.new(resolutionX, resolutionY)
	glassObject.ResolutionInverse = Vector2.new(inverseResX, inverseResY)
	glassObject.EditableImage.Size = glassObject.Resolution

	-- Ensure the pixels array is correct size
	local Pixels = glassObject.Pixels
	local WindowColor = glassObject.WindowColor

	local pixelsArrayLength = resolutionX * resolutionY * 4
	local pixelsArrayCurrentLength = #Pixels
	if pixelsArrayCurrentLength > pixelsArrayLength then
		-- Remove extra pixel data by moving empties in after the pixelsArrayLength
		table.move(EMPTY_TABLE, 1, pixelsArrayCurrentLength - pixelsArrayLength, pixelsArrayLength + 1, Pixels)
	elseif pixelsArrayCurrentLength < pixelsArrayLength then
		-- Add new pixels
		for i = pixelsArrayCurrentLength + 1, pixelsArrayLength do
			local mod4 = i % 4
			if mod4 == 0 then
				-- Fully opaque alpha channel
				Pixels[i] = 1
			else
				Pixels[i] = WindowColor[mod4] or 1
			end
		end
	end

	-- Move index back to start if new size is smaller
	if glassObject.PixelIndex > pixelsArrayLength then
		glassObject.PixelIndex = if glassObject.InterlaceOffsetFlag then 1 else 5
	end
end

function GlassmorphicUI._processNextPixel(glassObject: GlassObject, skipTween: boolean?)
	local Window = glassObject.Window
	if (not Window) or not Window.Parent then
		return
	end

	local Pixels, PixelIndex = glassObject.Pixels, glassObject.PixelIndex
	local WindowColor = glassObject.WindowColor

	if WindowColor[4] == 1 then
		-- Our window is not transparent, so there's no need to sample underneath
		-- (It's also not glassmorphic anymore, but that's not our problem)

		-- Set entire image to window color
		local r, g, b = WindowColor[1], WindowColor[2], WindowColor[3]
		for i = 1, #Pixels, 4 do
			Pixels[i] = r
			Pixels[i + 1] = g
			Pixels[i + 2] = b
		end

		-- Move index back to start
		glassObject.PixelIndex = if glassObject.InterlaceOffsetFlag then 1 else 5
		return
	end

	local Resolution = glassObject.Resolution
	local ResolutionInverse = glassObject.ResolutionInverse
	local WindowSizeX, WindowSizeY = glassObject.WindowSizeX, glassObject.WindowSizeY
	local WindowPositionX, WindowPositionY = glassObject.WindowPositionX, glassObject.WindowPositionY

	-- Sample color at the center of our sample
	local indexFloor4 = PixelIndex // 4
	local color = PixelColorApproximation:GetColor(
		Vector2.new(
			(ResolutionInverse.X * (indexFloor4 % Resolution.X) * WindowSizeX + WindowPositionX)
				+ (WindowSizeX * ResolutionInverse.X / 2),
			(ResolutionInverse.Y * (indexFloor4 // Resolution.X) * WindowSizeY + WindowPositionY)
				+ (WindowSizeY * ResolutionInverse.Y / 2)
		),
		Window
	)

	-- Blend window color on top
	local windowAlpha = WindowColor[4]
	color[1] = (1 - windowAlpha) * color[1] + windowAlpha * WindowColor[1]
	color[2] = (1 - windowAlpha) * color[2] + windowAlpha * WindowColor[2]
	color[3] = (1 - windowAlpha) * color[3] + windowAlpha * WindowColor[3]

	if skipTween then
		Pixels[PixelIndex] = color[1]
		Pixels[PixelIndex + 1] = color[2]
		Pixels[PixelIndex + 2] = color[3]
	else
		local prevR, prevG, prevB = Pixels[PixelIndex], Pixels[PixelIndex + 1], Pixels[PixelIndex + 2]
		Pixels[PixelIndex] = prevR + (color[1] - prevR) * GlassmorphicUI.TEMPORAL_SMOOTHING
		Pixels[PixelIndex + 1] = prevG + (color[2] - prevG) * GlassmorphicUI.TEMPORAL_SMOOTHING
		Pixels[PixelIndex + 2] = prevB + (color[3] - prevB) * GlassmorphicUI.TEMPORAL_SMOOTHING
	end

	PixelIndex += 8
	if PixelIndex > #Pixels then
		glassObject.InterlaceOffsetFlag = not glassObject.InterlaceOffsetFlag
		PixelIndex = if glassObject.InterlaceOffsetFlag then 1 else 5
	end

	glassObject.PixelIndex = PixelIndex
end

function GlassmorphicUI._update()
	local totalGlassObjects = #GlassmorphicUI._glassObjects
	if totalGlassObjects == 0 then
		return
	end

	local estimatedBlurTime = (totalGlassObjects * 3e-4)
	local allottedPixelProcessingTime = math.max(GlassmorphicUI.UPDATE_TIME_BUDGET - estimatedBlurTime, 1e-3)

	local startClock = os.clock()

	-- Process pixels until time is up
	local updatedGlassObjects = {}
	while os.clock() - startClock < allottedPixelProcessingTime do
		local glassObject = GlassmorphicUI._glassObjects[GlassmorphicUI._glassObjectUpdateIndex]
		if glassObject then
			GlassmorphicUI._processNextPixel(glassObject, false)
			updatedGlassObjects[GlassmorphicUI._glassObjectUpdateIndex] = glassObject
		end
		GlassmorphicUI._glassObjectUpdateIndex += 1

		if GlassmorphicUI._glassObjectUpdateIndex > totalGlassObjects then
			GlassmorphicUI._glassObjectUpdateIndex = 1
		end
	end

	-- Blur and apply the pixels for the updated objects
	for _, glassObject in updatedGlassObjects do
		EditableImageBlur({
			image = glassObject.EditableImage,
			pixelData = glassObject.Pixels,
			blurRadius = glassObject.BlurRadius,
			downscaleFactor = 1,
			skipAlpha = true,
		})
	end
end

function GlassmorphicUI._addInstance(Instance: Instance)
	if Instance:IsA("ImageLabel") then
		GlassmorphicUI._setupGlassWindow(Instance)
	elseif Instance:IsA("GuiObject") then
		GlassmorphicUI.addGlassBackground(Instance)
	end
end

function GlassmorphicUI._removeInstance(Instance: Instance)
	if Instance:IsA("ImageLabel") then
		local glassObject = GlassmorphicUI._windowToObject[Instance]
		if glassObject then
			GlassmorphicUI._windowToObject[Instance] = nil

			local index = table.find(GlassmorphicUI._glassObjects, glassObject)
			if index then
				table.remove(GlassmorphicUI._glassObjects, index)
			end

			table.clear(glassObject)
			table.freeze(glassObject)
		end
	end
end

CollectionService:GetInstanceRemovedSignal(GlassmorphicUI.TAG_NAME):Connect(GlassmorphicUI._removeInstance)
CollectionService:GetInstanceAddedSignal(GlassmorphicUI.TAG_NAME):Connect(GlassmorphicUI._addInstance)
for _, Instance in CollectionService:GetTagged(GlassmorphicUI.TAG_NAME) do
	GlassmorphicUI._addInstance(Instance)
end

RunService.Heartbeat:Connect(function()
	GlassmorphicUI._update()
end)

return table.freeze({
	new = GlassmorphicUI.new,
	applyGlassToImageLabel = GlassmorphicUI.applyGlassToImageLabel,
	addGlassBackground = GlassmorphicUI.addGlassBackground,
	forceUpdate = GlassmorphicUI.forceUpdate,
	pauseUpdates = GlassmorphicUI.pauseUpdates,
	resumeUpdates = GlassmorphicUI.resumeUpdates,
	setDefaultBlurRadius = GlassmorphicUI.setDefaultBlurRadius,
})
