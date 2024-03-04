# GlassmorphicUI

Glassmorphic UI in Roblox

![image](https://github.com/boatbomber/GlassmorphicUI/assets/40185666/8db526c2-40e3-4936-9a66-91fa030ba0f4)

## Installation

Via [wally](https://wally.run):

```toml
[dependencies]
GlassmorphicUI = "boatbomber/glassmorphicui@0.1.0"
```

Alternatively, grab the `.rbxm` standalone model from the latest [release.](https://github.com/boatbomber/GlassmorphicUI/releases)

## Usage

```Lua
function GlassmorphicUI.new(): ImageLabel
```

Returns an ImageLabel with a glassmorphic effect.
Use BackgroundTransparency and BackgroundColor3 to modify the glassmorphic effect.
Compatible with UICorners and all other ImageLabel properties.

```lua
local GlassmorphicUI = require(Path.To.GlassmorphicUI)

local blurryWindow = GlassmorphicUI.new()
blurryWindow.BackgroundTransparency = 0.5
blurryWindow.BackgroundColor3 = Color3.fromRGB(7, 48, 84)
blurryWindow.Size = UDim2.fromScale(0.3, 0.3)
blurryWindow.Position = UDim2.fromScale(0.5, 0.5)
blurryWindow.AnchorPoint = Vector2.new(0.5, 0.5)
blurryWindow.Parent = ScreenGui
```
