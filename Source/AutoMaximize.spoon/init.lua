--- === AutoMaximize ===
---
--- Automatically maximize new windows
---
local obj = {}
obj.__index = obj

-- Metadata
obj.name = "AutoMaximize"
obj.version = "1.0"
obj.author = "Yann Rouillard <yann@pleiades.fr.eu.org>"
obj.license = "MIT - https://opensource.org/licenses/MIT"

---
--- Configurable parameters
---

-- AutoMaximize.logger
-- Variable
-- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('AutoMaximize', 'info')

--- AutoMaximize.exclusions
--- Variable
--- List of application names for which the AutoMaximize mode should not be applied.
---
--- Notes:
---  * Default value: `{}`
obj.exclusions = {}

---
--- Private data
---

obj._windowFilter = nil

---
--- Private methods
---

function obj:_maximizeWindow(window, applicationName)
    local windowTitle = window:title()
    self.logger.d("Window filter triggered for window " .. windowTitle .. " from application " .. applicationName)
    if not hs.fnutils.contains(obj.exclusions, applicationName) then
        if window:isMaximizable() then
            self.logger.d("Maximiming window " .. windowTitle .. " from application " .. applicationName)
            window:maximize()
        end
    end
end

---
--- Public interface
---

function obj:init()
    self._windowFilter = hs.window.filter.new()
end

function obj:start()
    obj.logger.d("Starting AutoMaximize mode")
    self._windowFilter:subscribe(hs.window.filter.windowCreated, hs.fnutils.partial(self._maximizeWindow, self))
end

function obj:stop()
    self.logger.d("Stopping AutoMaximize mode")
    self._windowFilter:unsubscribeall()
end

return obj
