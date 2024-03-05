# GlassmorphicUI

Glassmorphic UI in Roblox.

[Please consider supporting my work.](https://github.com/sponsors/boatbomber)

![image](https://github.com/boatbomber/GlassmorphicUI/assets/40185666/8db526c2-40e3-4936-9a66-91fa030ba0f4)

## Installation

Via [wally](https://wally.run):

```toml
[dependencies]
GlassmorphicUI = "boatbomber/glassmorphicui@0.2.0"
```

Alternatively, grab the `.rbxm` standalone model from the latest [release.](https://github.com/boatbomber/GlassmorphicUI/releases/latest)

## Usage

```Lua
function GlassmorphicUI.new(): ImageLabel
```

Returns an ImageLabel with a glassmorphic effect.
Use BackgroundTransparency and BackgroundColor3 to modify the glassmorphic effect.
Compatible with UICorners and all other ImageLabel properties.

```lua
local GlassmorphicUI = require(Path.To.GlassmorphicUI)

local glassyimage = GlassmorphicUI.new()
glassyimage.BackgroundTransparency = 0.5
glassyimage.BackgroundColor3 = Color3.fromRGB(7, 48, 84)
glassyimage.Size = UDim2.fromScale(0.3, 0.3)
glassyimage.Position = UDim2.fromScale(0.5, 0.5)
glassyimage.AnchorPoint = Vector2.new(0.5, 0.5)
glassyimage.Parent = ScreenGui
```

```Lua
function GlassmorphicUI.applyGlassToImageLabel(ImageLabel: ImageLabel): ()
```

Takes an existing ImageLabel and applies the glassmorphic effect to it.
Useful for integrating GlassmorphicUI with existing UI systems.

```lua
local GlassmorphicUI = require(Path.To.GlassmorphicUI)

local glassyimage = Instance.new("ImageLabel")
glassyimage.BackgroundTransparency = 0.5
glassyimage.BackgroundColor3 = Color3.fromRGB(7, 48, 84)
glassyimage.Size = UDim2.fromScale(0.3, 0.3)
glassyimage.Position = UDim2.fromScale(0.5, 0.5)
glassyimage.AnchorPoint = Vector2.new(0.5, 0.5)
glassyimage.Parent = ScreenGui

GlassmorphicUI.applyGlassToImageLabel(glassyimage)
```


```Lua
function GlassmorphicUI.addGlassBackground(GuiObject: GuiObject): ImageLabel
```

Takes an existing GuiObject (such as a Frame) and parents a glassy ImageLabel inside it.
The ImageLabel will have a very low ZIndex as to appear as the background of the GuiObject.
The GuiObject will be forced to have a BackgroundTransparency of 1, otherwise the effect would just show your GuiObject's background behind the glass.
Useful for integrating GlassmorphicUI with existing UI systems.

```lua
local GlassmorphicUI = require(Path.To.GlassmorphicUI)

local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(0.2, 0.2)
frame.Parent = script.Parent

local glassyimage = GlassmorphicUI.addGlassBackground(frame)
glassyimage.BackgroundTransparency = 0.5
glassyimage.BackgroundColor3 = Color3.fromRGB(7, 48, 84)
```
