--- === InputSourceAutoSwitch ===
---
--- Automatically switch Input Source depending on the current application running
---
local obj = {}
obj.__index = obj

-- Metadata
obj.name = "InputSourceAutoSwitch"
obj.version = "1.0"
obj.author = "Yann Rouillard <yann@pleiades.fr.eu.org>"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- InputSourceAutoSwitch.logger
-- Variable
-- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('InputSourceAutoSwtich', 'info')

-- InputSourceAutoSwitch.logger
-- Variable
-- Mapping between application names and input sources to use when the application is focused. 
--
-- Notes:
-- Exemple of configuration:
--   {
--     ["iTerm2"] = "US",
--     ["Firefox"] = "USInternational-PC",
--     ["Slack"] = "USInternational-PC",  
--   } 
obj.inputSourcePerApplication = {}

function obj:_setApplicationInputSource(appName, inputSource, event)
    event = event or hs.window.filter.windowFocused

    local setInputSourceFunction = function()
        self.logger.d("Setting input source to " .. inputSource .. " for application " .. appName)
        hs.keycodes.currentSourceID("com.apple.keylayout." .. inputSource)
    end

    hs.window.filter.new(appName):subscribe(event, setInputSourceFunction)
end

function obj:start()
    self.logger.d("Starting InputSourceAutoSwitch mode")
    for appName, inputSource in pairs(obj.inputSourcePerApplication) do
        self:_setApplicationInputSource(appName, inputSource)
    end
end

return obj
