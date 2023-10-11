--- === Iterm2 ===
---
--- Provides helper functions to interact with iTerm2 through its AppleScript API.
---
--- It requires the installation of the AutoLaunch script hammerspoon_interface.py
--- in iTerm2. This can be done by running the following command:
--- ```
---   ln -s ~/.hammerspoon/Spoons/Iterm2.spoon/hammerspoon_interface.py \
---         ~/"Application Support/iTerm2/Scripts/AutoLaunch/hammerspoon_interface.py"
--- ``` 
local obj = {}
obj.__index = obj

-- Metadata
obj.name = "Iterm2"
obj.version = "1.0"
obj.author = "Yann Rouillard <yann@pleiades.fr.eu.org>"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Iterm2.logger
-- Variable
-- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new("Iterm2")

function callItermAPI(method, parameters)
    obj.logger.d("Calling iTerm2 API with method: " .. method .. " and parameters: " .. hs.inspect(parameters))

    local formattedParameters = {}
    for key, value in pairs(parameters) do
        table.insert(formattedParameters, key .. ": \\\"" .. value .. "\\\"")
    end
    local script = [[
tell application "iTerm2"
  invoke API expression "]] .. method .. [[(]] .. table.concat(formattedParameters, ", ") .. [[)"
end tell
]]

    obj.logger.d("Invoking iTerm2 API through applescript: " .. script)
    local success, result, rawOutput = hs.osascript.applescript(script)
    if not success then
        obj.logger.e("Error while invoking iTerm2 API: " .. hs.inspect(rawOutput))
        return nil
    end

    obj.logger.d("iTerm2 API call result: " .. hs.inspect(result))
    if result == "(null)" then
        return nil
    else
        return hs.json.decode(result)
    end
end

--- Iterm2:getActiveTab(mapping)
--- Method
--- Return information about the currently active tab in iTerm2
---
--- Parameters:
---  * None
---
--- Returns:
---  * A Table containing the following information about the tab
---    - working_directory: The working directory of the tab
---    - title: the title of the tab
---    - id: the id of the tab  
---     
function obj.getActiveTab()
    return callItermAPI("get_active_tab", {})
end

--- Iterm2:closeMatchinTabs(workingDirectoryPrefix)
--- Method
--- Close all tabs whose working directory starts with the given prefix
---
--- Parameters:
---  * the absolute path to a directory prefix
function obj.closeMatchingTabs(workingDirectoryPrefix)
    callItermAPI("close_matching_tabs", {
        working_directory_prefix = workingDirectoryPrefix
    })
end

--- Iterm2:openOrActivateTab(workingDirectory)
--- Method
--- Open a new tab or activate an existing one with the given working directory
---
--- Parameters:
---  * the absolute path to a directory
function obj.openOrActivateTab(workingDirectory)
    callItermAPI("open_or_activate_tab", {
        working_directory = workingDirectory
    })
end

return obj
