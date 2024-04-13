--- === Toggler ===
---
--- Export various toggle methods
---
local obj = {}
obj.__index = obj

-- Metadata
obj.name = "Toggler"
obj.version = "1.0"
obj.author = "Yann Rouillard <yann@pleiades.fr.eu.org>"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Toggler.logger
-- Variable
-- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('Toggler', 'info')

--- Toggler:toggleSidecar()
--- Method
--- Enable/disable Dark Mode both at the system level and in Hammerspoon
---
--- Parameters:
---  * None
---
function obj:toggleDarkMode()
    hs.osascript.applescript([[
        tell application "System Events" to tell appearance preferences to set dark mode to not dark mode
    ]])
    local currentMode = hs.preferencesDarkMode()
    hs.preferencesDarkMode(not currentMode)
    hs.console.darkMode(not currentMode)
    hs.console.consoleCommandColor({
        white = (not currentMode and 1) or 0
    })
end

--- Toggler:toggleSidecar()
--- Method
--- Enable/disable Sidecar (iPad as second display)
---
--- Parameters:
---  * None
---
function obj:toggleSidecar()
    local lunarPath = os.getenv("HOME") .. "/.local/bin/lunar"
    if hs.fs.displayName(lunarPath) == nil then
        obj.logger.e("Unable to toggle sidecar: " .. hs.inspect.inspect(err))
        hs.notify.show("Lunar CLI not found!",
            "Please install Lunar from https://lunar.fyi/ and run /Applications/Lunar.app/Contents/MacOS/Lunar install-cli",
            "")
    end
    hs.task.new(lunarPath, nil, {"toggle-connection", "sidecar"}):start()
end

--- Toggler:bindHotkeys(mapping) -> self
--- Method
--- Binds hotkeys to Toggler methods
---
--- Parameters:
---  * mapping - A table containing hotkey modifier/key details for each available operation
---
--- Returns:
---  * The Toggler object
function obj:bindHotkeys(mapping)
    local spec = {
        toggleSidecar = hs.fnutils.partial(self.toggleSidecar, self),
        toggleDarkMode = hs.fnutils.partial(self.toggleDarkMode, self)
    }
    hs.spoons.bindHotkeysToSpec(spec, mapping)
    return self
end

function obj:init()
    self.sealActions = {
        ["Toggle Dark Mode"] = {
            fn = hs.fnutils.partial(self.toggleDarkMode, self),
            image = hs.image.imageFromPath(hs.spoons.resourcePath("icons/dark_mode.png"))
        },
        ["Toggle Sidecar"] = {
            fn = hs.fnutils.partial(self.toggleSidecar, self),
            image = hs.image.imageFromPath(hs.spoons.resourcePath("icons/sidecar.png"))
        }
    }
end

return obj
