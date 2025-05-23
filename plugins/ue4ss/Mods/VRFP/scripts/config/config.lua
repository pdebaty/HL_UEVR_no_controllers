--[[
Locomotion Mode
0 = Manual direction mode
1 = Head/HMD based direction mode
2 = Hand/Controller direction mode
]]--
locomotionMode = 1

--[[
Target Mode
0 = Manual targeting
1 = Auto targeting
]]--
targetingMode = 1

--[[	
Controller Mode
0 = Basic control mode
1 = Enhanced control mode (Spells can be cast with right trigger + right thumbstick)
]]--
controlMode = 1

--[[
Gesture Mode
0 = No gestures
1 = Spells can be cast by drawing glyphs. Wrist flick casts previous spell
]]--
gestureMode = 1

--[[
Use Crosshair 
true = Show Crosshair
false = No crosshair
]]--
useCrossHair = false

--[[
Manual hide wand 
false = Default gameplay method. Wand is hidden after some period of disuse
true = Wand will only hide when you holster it by putting your hand down to your side and pressing grip
]]--
manualHideWand = true

--[[
Show Hands 
false = No hands will be shown
true = Hands will be visible
]]--
showHands = true

--[[
Player offset 
X - Positive values forward, Negative values backward
Y - Positive values right, Negative values left
Z - Positive values up, Negative values down
]]--
playerOffset = {X=19, Y=-3, Z=70}

--[[
Broom Mount offset 
X - Positive values forward, Negative values backward
Y - Positive values right, Negative values left
Z - Positive values up, Negative values down
]]--
broomMountOffset = {X=-15, Y=0, Z=75}

--[[
Graphorn Mount offset 
X - Positive values forward, Negative values backward
Y - Positive values right, Negative values left
Z - Positive values up, Negative values down
]]--
graphornMountOffset = {X=0, Y=0, Z=40}

--[[
Hippogriff Mount offset 
X - Positive values forward, Negative values backward
Y - Positive values right, Negative values left
Z - Positive values up, Negative values down
]]--
hippogriffMountOffset = {X=0, Y=0, Z=30}

--[[
Hippogriff FlyingMount offset 
X - Positive values forward, Negative values backward
Y - Positive values right, Negative values left
Z - Positive values up, Negative values down
]]--
hippogriffFlyingMountOffset = {X=30, Y=0, Z=30}

--[[
Use Volumetric Fog 
nil = Don't affect game fog at all
true = Turn on in-game fog
false = Turn off in-game fog
]]--
useVolumetricFog = nil

--[[
Use Flicker Fixer 
true = Turn on Flicker Fixer. No reason to not use it until UEVR is fixed
false = Turn off Flicker Fixer
]]--
useFlickerFixer = true


configDefinition = {
	{
		layout = 
		{
			{
				widgetType = "combo",
				id = "locomotionMode",
				selections = {"Manual","Head/HMD","Hand/Controller"},
				label = "Locomotion Mode",
				initialValue = locomotionMode
			},
			{
				widgetType = "combo",
				id = "targetingMode",
				selections = {"Manual targeting","Auto targeting"},
				label = "Target Mode",
				initialValue = targetingMode
			},
			{
				widgetType = "combo",
				id = "controlMode",
				selections = {"Basic control mode","Enhanced control mode"},
				label = "Controller Mode",
				initialValue = controlMode
			},
			{
				widgetType = "combo",
				id = "gestureMode",
				selections = {"No gestures","Spells cast with drawn glyphs"},
				label = "Gesture Mode",
				initialValue = gestureMode
			},
			{
				widgetType = "checkbox",
				id = "useCrossHair",
				label = "Use crosshair",
				initialValue = useCrossHair
			},
			{
				widgetType = "checkbox",
				id = "manualHideWand",
				label = "Manual Hide Wand",
				initialValue = manualHideWand
			},
			{
				widgetType = "checkbox",
				id = "showHands",
				label = "Show Hands",
				initialValue = showHands
			}
		}
	}
}
