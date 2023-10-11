--- === SmartAppSwitcher ===
---
--- Easily switch between your most used applications with one key assigned to each app,
--- and automatically activate the most relevant window/tab in the target application
--- when possible.
---
--- For instance, when switching from iTerm2 to Visual Studio Code while on a source
--- code repository, SmartAppSwitcher will automatically activate or open a Visual Studio
--- Code window on the source code repository.
---
--- Notes:
---  * The window/tab auto-select feature requires some helper spoons for eligible applications
---    (currently only iTerm2 and Visual Studio Code are supported)
---
--- Examples configuration:
--- ```
--- hs.loadSpoon("SmartAppSwitcher")
--- spoon.SmartAppSwitcher.modifier = {"cmd", "alt"}
--- spoon.SmartAppSwitcher.helperSpoons = {
---   ["iTerm"] = spoon.Iterm2,
---   ["Visual Studio Code"] = spoon.VsCode
--- }
--- spoon.SmartAppSwitcher.bindHotkeys({
---   c = "Visual Studio Code",
---   o = "Obsidian",
---   f = "Firefox",
---   k = "Slack",
---   s = "Spotify",
---   i = "iTerm"
--- })
--- ```
---
local obj = {}
obj.__index = obj

-- Metadata
obj.name = "SmartAppSwitcher"
obj.version = "1.0"
obj.author = "Yann Rouillard <yann@pleiades.fr.eu.org>"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- SmartAppSwitcher.logger
-- Variable
-- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new("SmartAppSwitcher", "info")

-- SmartAppSwitcher.modifiers
-- Variable
-- Modifier keys used when launching apps
obj.modifiers = {}

-- SmartAppSwitcher.helperSpoons
-- Variable
-- A table containings helper spoons required to enable the window/tab auto-select feature
-- for some applications. Only iTerm and Visual Studio Code are supported for now.
obj.helperSpoons = {
    iTerm = nil,
    Code = nil
}

local KNOWN_APP_ALIASES = {
    Code = "Visual Studio Code",
    iTerm2 = "iTerm"
}

function vscodeGetCurrentView(window)
    local windowInfo = obj.helperSpoons["Visual Studio Code"].getWindowInfo(window)
    local viewInfo = {
        window = windowInfo.window,
        workingDirectory = windowInfo.workspaceFolder
    }
    return viewInfo
end

function vscodeActivateMatchingView(view)
    if not view.workingDirectory then
        return
    end
    local vsCodeWindows = obj.helperSpoons["Visual Studio Code"].listWindows()
    local matchingWindows = hs.fnutils.filter(vsCodeWindows, function(windowInfo)
        return view.workingDirectory == windowInfo.workspaceFolder
    end)
    if #matchingWindows > 0 then
        matchingWindows[1].window:focus()
    else
        hs.task.new("/usr/bin/open", nil, {view.workingDirectory, "-a", "Visual Studio Code"}):start()
    end
end

function itermGetCurrentView(window)
    local tabInfo = obj.helperSpoons["iTerm"].getActiveTab()
    obj.logger.d("Current iTerm2 tab info: " .. hs.inspect(tabInfo))
    local viewInfo = {
        window = window,
        workingDirectory = tabInfo.working_directory
    }
    return viewInfo
end

function itermActivateMatchingView(view)
    if view.workingDirectory ~= nil then
        obj.helperSpoons["iTerm"].openOrActivateTab(view.workingDirectory)
    end
end

local appsWithSelectableView = {
    ["Visual Studio Code"] = {
        requireHelperSpoon = true,
        getCurrentView = vscodeGetCurrentView,
        activateMatchingView = vscodeActivateMatchingView
    },
    ["iTerm"] = {
        requireHelperSpoon = true,
        getCurrentView = itermGetCurrentView,
        activateMatchingView = itermActivateMatchingView
    }
}

function obj:_supportSelectableView(applicationName)
    local result = appsWithSelectableView[applicationName] ~= nil and
                       (not appsWithSelectableView[applicationName].requireHelperSpoon or
                           self.helperSpoons[applicationName] ~= nil)

    self.logger.d("Application " .. applicationName .. " supports selectable views: " .. tostring(result))
    return result
end

function obj:_switchApp(targetApplicationName)
    local currentWindow = hs.window.focusedWindow()
    if currentWindow == nil then
        hs.application.launchOrFocus(targetApplicationName)
        return
    end

    local currentApplicationName = currentWindow:application():title()
    local realApplicationName = KNOWN_APP_ALIASES[currentApplicationName] or currentApplicationName

    self.logger.d("Switching from " .. realApplicationName .. " to " .. targetApplicationName)

    -- If we find a matching view in the target application that seems related
    -- to the current view, we activate it automatically
    if self:_supportSelectableView(realApplicationName) and self:_supportSelectableView(targetApplicationName) then
        self.logger.d("Both applications support selectableView, trying to activate matching view...")
        local currentView = appsWithSelectableView[realApplicationName].getCurrentView(currentWindow)
        appsWithSelectableView[targetApplicationName].activateMatchingView(currentView)
    end
    hs.application.launchOrFocus(targetApplicationName)
end

--- SmartAppSwitcher:bindHotkeys(mapping)
--- Method
--- Binds hotkey to each application
---
--- Parameters:
---  * mapping - A table containing single characters with their associated app
---
function obj:bindHotkeys(mapping)
    for key, app in pairs(mapping) do
        hs.hotkey.bind(obj.modifiers, key, hs.fnutils.partial(self._switchApp, self, app))
    end
end

return obj

