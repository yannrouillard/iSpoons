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

obj._currentAlert = nil

local arrows = {
    left = "←",
    right = "→",
    up = "↑",
    down = "↓"
}

local FORCE_ONSCREEN_SPLIT_MODIFIER = "alt"

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
        local nextScreen = hs.window.focusedWindow():screen():next()
        windowToPlace:moveToScreen(nextScreen)
        windowToPlace:maximize()
        windowToPlace:raise()
    end
end

function isVerticalScreenLayout()
    local screenPositions = hs.screen.screenPositions()
    if #screenPositions > 1 then
        return screenPositions[1].x == screenPositions[2].x
    else
        return false
    end
end

function findMainWindowOncreen(screen)
    local screenId = screen:id()
    local windowFound = hs.fnutils.find(hs.window.orderedWindows(), function(window)
        return window:screen():id() == screenId
    end)
    return windowFound
end

function getSecondaryScreen()
    local primaryScreen = hs.screen.primaryScreen()
    return first(hs.fnutils.filter(hs.screen.allScreens(), function(screen)
        return screen ~= primaryScreen
    end))
end

function getScreenRelativePosition(screen)
    local primaryScreenSize = hs.screen.primaryScreen():currentMode()
    local screenSize = screen:currentMode()
    local x, y = screen:position()
    local position

    if x == 0 and y <= -1 then
        position = "up"
    elseif x == 0 and y >= 1 then
        position = "down"
    elseif x >= 1 and y == 0 then
        position = "right"
    else
        position = "left"
    end
    return position
end

function setScreenRelativePosition(screen, position)
    local primaryScreenSize = hs.screen.primaryScreen():currentMode()
    local secondaryScreenSize = screen:currentMode()

    local x = 0
    local y = 0

    if position == "up" then
        x = (primaryScreenSize.w - secondaryScreenSize.w) // 2
        y = 0 - secondaryScreenSize.h
    elseif position == "down" then
        x = (primaryScreenSize.w - secondaryScreenSize.w) // 2
        y = primaryScreenSize.h
    elseif position == "right" then
        x = primaryScreenSize.w
        y = (primaryScreenSize.h - secondaryScreenSize.h) // 2
    elseif position == "left" then
        x = 0 - secondaryScreenSize.w
        y = (primaryScreenSize.h - secondaryScreenSize.h) // 2
    end

    screen:setOrigin(x, y)
end

--- MoveWindowsOnScreens:moveWindowLeft()
--- Method
--- Move the current window on the left screen and maximize it
---
--- Parameters:
---  * None
---
function obj:moveWindowLeftOrDown()
    if isVerticalScreenLayout() then
        hs.window.focusedWindow():moveOneScreenSouth(false, true, 0)
    else
        hs.window.focusedWindow():moveOneScreenWest(false, true, 0)
    end
    hs.window.focusedWindow():maximize()
end

--- MoveWindowsOnScreens:moveWindowRight()
--- Method
--- Move the current window on the right screen and maximize it
---
--- Parameters:
---  * None
---
function obj:moveWindowRightOrUp()
    if isVerticalScreenLayout() then
        hs.window.focusedWindow():moveOneScreenNorth(false, true, 0)
    else
        hs.window.focusedWindow():moveOneScreenEast(false, true, 0)
    end
    hs.window.focusedWindow():maximize()
end

--- MoveWindowsOnScreens:focusWindowLeft()
--- Method
--- Focus the window which is on the left scren
---
--- Parameters:
---  * None
---
function obj:focusWindowLeftOrDown()
    if isVerticalScreenLayout() then
        hs.window.focusedWindow():focusWindowSouth(nil, true)
    else
        hs.window.focusedWindow():focusWindowWest(nil, true)
    end
end

--- MoveWindowsOnScreens:focusWindowRight()
--- Method
--- Focus the window which is on the right scren
---
--- Parameters:
---  * None
---
function obj:focusWindowRightOrUp()
    if isVerticalScreenLayout() then
        hs.window.focusedWindow():focusWindowNorth(nil, true)
    else
        hs.window.focusedWindow():focusWindowEast(nil, true)
    end
end

--- MoveWindowsOnScreens:switchWindowLeftAndRight()
--- Method
--- Switch the screen of the current window and the window of the left/right screen
---
--- Parameters:
---  * None
---
function obj:switchWindowWithNextScreen()
    local currentWindow = hs.window.focusedWindow()
    local currentScreen = currentWindow:screen()
    local nextScreen = currentScreen:next()
    local windowOnNextScreen = findMainWindowOncreen(nextScreen)

    if currentWindow ~= nil then
        currentWindow:moveToScreen(nextScreen)
        currentWindow:maximize()
        currentWindow:focus()
    end

    if windowOnNextScreen ~= nil then
        windowOnNextScreen:moveToScreen(currentScreen)
        windowOnNextScreen:maximize()
    end
end

--- MoveWindowsOnScreens:placeSelectedWindowOnTheRight()
--- Method
--- Open a chooser to select a window to place on the right screen and maximize it
---
--- Parameters:
---  * None
---
function obj:placeSelectedWindowOnNextScreen()
    local availableWindows = hs.fnutils.map(listOtherWindows(), mapWindowToChoice)
    local windowChooser = hs.chooser.new(placeChosenWindow):placeholderText("Choose window to place on the next screen")
    windowChooser:choices(availableWindows):show()
end

function obj:focusWindowOnNextScreen()
    local nextScreen = hs.window.focusedWindow():screen():next()
    local windowOnNextScreen = findMainWindowOncreen(nextScreen)
    if windowOnNextScreen ~= nil then
        windowOnNextScreen:focus()
    end
end

function obj:moveWindowOnNextScreen()
    local currentWindow = hs.window.focusedWindow()
    local nextScreen = currentWindow:screen():next()
    currentWindow:moveToScreen(nextScreen)
    currentWindow:maximize()
end

function obj:moveSecondaryScreenAround()
    local availablePositions = {"up", "right", "down", "left"}

    local secondaryScreen = getSecondaryScreen()
    if secondaryScreen == nil then
        obj._currentAlert = hs.alert.show("No Secondary Screen 🖥️ ")
        return
    end
    local position = getScreenRelativePosition(secondaryScreen)

    local nextPosition = availablePositions[hs.fnutils.indexOf(availablePositions, position) % #availablePositions + 1]

    obj.logger.d("Moving secondary screen from " .. position .. " to " .. nextPosition)
    setScreenRelativePosition(secondaryScreen, nextPosition)
    if obj._currentAlert ~= nil then
        hs.alert.closeSpecific(obj._currentAlert)
    end
    obj._currentAlert = hs.alert.show("Screen 🖥️ " .. nextPosition .. " " .. arrows[nextPosition])

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
        moveWindowLeftOrDown = hs.fnutils.partial(self.moveWindowLeftOrDown, self),
        moveWindowRightOrUp = hs.fnutils.partial(self.moveWindowRightOrUp, self),
        focusWindowLeftOrDown = hs.fnutils.partial(self.focusWindowLeftOrDown, self),
        focusWindowRightOrUp = hs.fnutils.partial(self.focusWindowRightOrUp, self),
        switchWindowWithNextScreen = hs.fnutils.partial(self.switchWindowWithNextScreen, self),
        placeSelectedWindowOnNextScreen = hs.fnutils.partial(self.placeSelectedWindowOnNextScreen, self),
        focusWindowOnNextScreen = hs.fnutils.partial(self.focusWindowOnNextScreen, self),
        moveWindowOnNextScreen = hs.fnutils.partial(self.moveWindowOnNextScreen, self),
        moveSecondaryScreenAround = hs.fnutils.partial(self.moveSecondaryScreenAround, self)
    }
    hs.spoons.bindHotkeysToSpec(spec, mapping)
    return self
end

return obj
