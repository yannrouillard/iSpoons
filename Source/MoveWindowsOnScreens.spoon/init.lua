--- === MoveWindowsOnScreens ===
---
--- Provide easy window functions and hotkeys to move window between screens
---
local obj = {}
obj.__index = obj

-- Metadata
obj.name = "MoveWindowsOnScreens"
obj.version = "1.0"
obj.author = "Yann Rouillard <yann@pleiades.fr.eu.org>"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- InputSourceAutoSwitch.logger
-- Variable
-- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('MoveWindowsOnScreens', 'info')

---
--- Constant
---

local FORCE_ONSCREEN_SPLIT_MODIFIER = "alt"

---
--- Helper functions
---

function first(table)
    if #table > 0 then
        return table[1]
    end
    return nil
end

function hasMultipleScreens()
    return #hs.screen.allScreens() > 1
end

function listOtherWindows(currentWindow)
    local isNotCurrentWindow = function(window)
        return window ~= currentWindow
    end
    return hs.fnutils.filter(hs.window.orderedWindows(), isNotCurrentWindow)
end

function mapWindowToChoice(window)
    local application = window:application()
    return {
        text = application:title(),
        subText = window:title(),
        image = hs.image.imageFromAppBundle(application:bundleID()),
        windowId = window:id()
    }
end

function placeChosenWindow(choice)
    if choice == nil then
        return
    end
    local windowToPlace = hs.window.find(choice.windowId)
    if windowToPlace == nil then
        return
    end

    if not hasMultipleScreens() or hs.eventtap.checkKeyboardModifiers()[FORCE_ONSCREEN_SPLIT_MODIFIER] then
        local currentWindow = hs.window.focusedWindow()
        hs.layout.apply({{nil, currentWindow, currentWindow:screen(), hs.layout.left50, nil, nil},
                         {nil, windowToPlace, currentWindow:screen(), hs.layout.right50, nil, nil}})
        windowToPlace:raise()
    else
        windowToPlace:moveOneScreenEast(false, true, 0)
        windowToPlace:maximize()
        windowToPlace:raise()
    end
end

---
--- Public interface
---

--- MoveWindowsOnScreens:moveWindowLeft()
--- Method
--- Move the current window on the left screen and maximize it
---
function obj:moveWindowLeft()
    hs.window.focusedWindow():moveOneScreenWest(false, true, 0)
    hs.window.focusedWindow():maximize()
end

--- MoveWindowsOnScreens:moveWindowRight()
--- Method
--- Move the current window on the right screen and maximize it
---
function obj:moveWindowRight()
    hs.window.focusedWindow():moveOneScreenEast(false, true, 0)
    hs.window.focusedWindow():maximize()
end

--- MoveWindowsOnScreens:focusWindowLeft()
--- Method
--- Focus the window which is on the left scren
---
function obj:focusWindowLeft()
    hs.window.focusedWindow():focusWindowWest(nil, true)
end

--- MoveWindowsOnScreens:focusWindowRight()
--- Method
--- Focus the window which is on the right scren
---
function obj:focusWindowRight()
    hs.window.focusedWindow():focusWindowEast(nil, true)
end

--- MoveWindowsOnScreens:switchWindowLeftAndRight()
--- Method
--- Switch the screen of the current window and the window of the left/right screen
---
function obj:switchWindowLeftAndRight()
    local currentWindow = hs.window.focusedWindow()
    local windowWest = first(currentWindow:windowsToWest(nil, true, true))
    local windowEast = first(currentWindow:windowsToEast(nil, true, true))

    if windowWest ~= nil then
        windowWest:moveOneScreenEast(false, true, 0)
        windowWest:maximize()
        currentWindow:moveOneScreenWest(false, true, 0)
        currentWindow:maximize()
        windowWest:focus()
    elseif windowEast ~= nil then
        windowEast:moveOneScreenWest(false, true, 0)
        windowEast:maximize()
        currentWindow:moveOneScreenEast(false, true, 0)
        currentWindow:maximize()
        windowEast:focus()
    end
end

--- MoveWindowsOnScreens:placeSelectedWindowOnTheRight()
--- Method
--- Open a chooser to select a window to place on the right screen and maximize it
---
function obj:placeSelectedWindowOnTheRight()
    local availableWindows = hs.fnutils.map(listOtherWindows(), mapWindowToChoice)
    local windowChooser = hs.chooser.new(placeChosenWindow):placeholderText("Choose window to place on the right")
    windowChooser:choices(availableWindows):show()
end

--- MoveWindowsOnScreens:bindHotkeys(mapping) -> self
--- Method
--- Binds hotkeys for MoveWindowsOnScreens
---
--- Parameters:
---  * mapping - A table containing hotkey modifier/key details for each available operation
---
--- Returns:
---  * The MoveWindowsOnScreens object
function obj:bindHotkeys(mapping)
    local spec = {
        moveWindowLeft = hs.fnutils.partial(self.moveWindowLeft, self),
        moveWindowRight = hs.fnutils.partial(self.moveWindowRight, self),
        focusWindowLeft = hs.fnutils.partial(self.focusWindowLeft, self),
        focusWindowRight = hs.fnutils.partial(self.focusWindowRight, self),
        switchWindowLeftAndRight = hs.fnutils.partial(self.switchWindowLeftAndRight, self),
        placeSelectedWindowOnTheRight = hs.fnutils.partial(self.placeSelectedWindowOnTheRight, self)
    }
    hs.spoons.bindHotkeysToSpec(spec, mapping)
    return self
end

return obj
