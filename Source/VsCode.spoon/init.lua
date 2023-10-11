--- === VsCode ===
---
--- Provides helper functions to interact with iTerm2 through its AppleScript API.
---
local obj = {}
obj.__index = obj

-- Metadata
obj.name = "VsCode"
obj.version = "1.0"
obj.author = "Yann Rouillard <yann@pleiades.fr.eu.org>"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- VsCode.logger
-- Variable
-- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new("VsCode")

-- VsCode.sourceCodeRootDirectories
-- Variable
-- A table containing the root directories of the source code opened in VsCode
-- It is required to be able to find the absolute path of the working directory
-- of each VsCode window.
obj.sourceCodeRootDirectories = {}

function isDirectory(path)
    local attributes = hs.fs.attributes(path)
    return attributes and attributes.mode == "directory"
end

function findWorkspaceFolderFromBasename(name)
    for _, rootDirectory in ipairs(obj.sourceCodeRootDirectories) do
        if not string.match(rootDirectory, "/$") then
            rootDirectory = rootDirectory .. "/"
        end

        local candidateFolder = rootDirectory .. name
        if isDirectory(candidateFolder) then
            return hs.fs.pathToAbsolute(candidateFolder)
        end
    end
end

function extractWorkspaceInfo(codeWindow)
    local windowTitleParts = hs.fnutils.split(codeWindow:title(), " —+ ")
    if #windowTitleParts > 1 then
        return {
            window = codeWindow,
            workspaceFolder = findWorkspaceFolderFromBasename(windowTitleParts[2]),
            filename = windowTitleParts[1]
        }
    else
        return {
            window = codeWindow,
            workspaceFolder = findWorkspaceFolderFromBasename(windowTitleParts[1]),
            filename = nil
        }
    end
end

--- VsCode.getWindowInfo(window)
--- Method
--- Extracts information about the specified Visual Studio Code window.
---
--- Parameters:
---  * window - The window to extract information from.
---
--- Returns:
---  * A table containing the following information about the window:
---    - window: The window object
---    - workspaceFolder: the absolute path to the workspace folder of the window
---    - filename: the name of the file opened in the window (or nil if no file is opened)
function obj.getWindowInfo(window)
    return extractWorkspaceInfo(window)
end

--- VsCode.listWindows()
--- Method
--- Returns a list of all Visual Code windows with some additional information
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table containing the list of Visual Studio Code window with the following 
---    information about all Code windows:
---    - window: The window object
---    - workspaceFolder: the absolute path to the workspace folder of the window
---    - filename: the name of the file opened in the window (or nil if no file is opened)
function obj.listWindows()
    local vscodeApp = hs.application.get("Code")
    if vscodeApp then
        local windows = vscodeApp:allWindows()
        return hs.fnutils.imap(windows, extractWorkspaceInfo)
    else
        return {}
    end
end

--- VsCode.closeMatchingWindows(workingDirectoryPrefix)
--- Method
--- Closes all Visual Studio Code windows whose workspace folder matches the specified prefix.
---
--- Parameters:
---  * workingDirectoryPrefix - A string containing the prefix to match against the workspace folder of each window.
---
--- Returns:
---  * None
function obj.closeMatchingWindows(workingDirectoryPrefix)
    local foundWindows = hs.fnutils.filter(obj.listWindows(), function(window)
        return window.workspaceFolder and string.match(window.workspaceFolder, "^" .. workingDirectoryPrefix)
    end)
    hs.fnutils.each(foundWindows, function(window)
        window.window:close()
    end)
end

return obj
