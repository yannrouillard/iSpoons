--- === Seal.plugins.apps ===
---
--- A plugin to add launchable apps/scripts, making Seal act as a launch bar
local obj = {}
obj.__index = obj
obj.__name = "seal_apps"
obj.appCache = {}

--- Seal.plugins.apps.appSearchPaths
--- Variable
--- Table containing the paths to search for launchable items
---
--- Notes:
---  * If you change this, you will need to call `spoon.Seal.plugins.apps:restart()` to force Spotlight to search for new items.
obj.appSearchPaths = {"/Applications", "/System/Applications", "~/Applications", "/Developer/Applications",
                      "/Applications/Xcode.app/Contents/Applications", "/System/Library/PreferencePanes",
                      "/Library/PreferencePanes", "~/Library/PreferencePanes",
                      "/System/Library/CoreServices/Applications", "/System/Library/CoreServices/", "/usr/local/Cellar",
                      "/Library/Scripts", "~/Library/Scripts"}

local queryMatchText = function(queryWords, text)
    for _, word in ipairs(queryWords) do
        if not string.find(string.lower(text), word, 1, true) then
            return false
        end
    end
    return true
end

local modifyNameMap = function(info, add)
    for _, item in ipairs(info) do
        icon = nil
        local displayname = "Unknown"
        if item.kMDItemDisplayName or item.kMDItemPath then
            displayname = item.kMDItemDisplayName or hs.fs.displayName(item.kMDItemPath)
        end
        displayname = displayname:gsub("%.app$", "", 1)
        if string.find(item.kMDItemPath, "%.prefPane$") then
            displayname = displayname .. " preferences"
            if add then
                icon = hs.image.iconForFile(item.kMDItemPath)
            end
        end
        if add then
            bundleID = item.kMDItemCFBundleIdentifier
            if (not icon) and (bundleID) then
                icon = hs.image.imageFromAppBundle(bundleID)
            end
            obj.appCache[displayname] = {
                path = item.kMDItemPath,
                bundleID = bundleID,
                icon = icon
            }
        else
            obj.appCache[displayname] = nil
        end
    end
end

local updateNameMap = function(obj, msg, info)
    if info then
        -- all three can occur in either message, so check them all!
        if info.kMDQueryUpdateAddedItems then
            modifyNameMap(info.kMDQueryUpdateAddedItems, true)
        end
        if info.kMDQueryUpdateChangedItems then
            modifyNameMap(info.kMDQueryUpdateChangedItems, true)
        end
        if info.kMDQueryUpdateRemovedItems then
            modifyNameMap(info.kMDQueryUpdateRemovedItems, false)
        end
    else
        -- shouldn't happen for didUpdate or inProgress
        print("~~~ userInfo from SpotLight was empty for " .. msg)
    end
end

local getApplicationWindows = function(app)
    local appWindows = {}
    if app["bundleID"] then
        local instances = hs.application.applicationsForBundleID(app["bundleID"])
        for _, instance in ipairs(instances) do
            appWindows = hs.fnutils.concat(appWindows, instance:allWindows())
        end
    end
    return appWindows
end

local extendAppCacheWithWindows = function(appCache)
    local appCacheWithWindows = {}
    for name, app in pairs(appCache) do
        local appWindows = getApplicationWindows(app)
        if #appWindows == 0 then
            appCacheWithWindows[name] = app
        else
            for _, window in ipairs(appWindows) do
                local nameWithWindow = name .. " - " .. window:title()
                local appWithWindow = hs.fnutils.copy(app)
                appWithWindow["window"] = window
                appCacheWithWindows[nameWithWindow] = appWithWindow
            end
        end
    end
    return appCacheWithWindows
end

--- Seal.plugins.apps:start()
--- Method
--- Starts the Spotlight app searcher
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * This is called automatically when the plugin is loaded
function obj:start()
    obj.spotlight = hs.spotlight.new():queryString(
        [[ (kMDItemContentType = "com.apple.application-bundle") || (kMDItemContentType = "com.apple.systempreference.prefpane")  || (kMDItemContentType = "com.apple.applescript.text")  || (kMDItemContentType = "com.apple.applescript.script") ]])
        :callbackMessages("didUpdate", "inProgress"):setCallback(updateNameMap):searchScopes(obj.appSearchPaths):start()
end

--- Seal.plugins.apps:stop()
--- Method
--- Stops the Spotlight app searcher
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function obj:stop()
    obj.spotlight:stop()
    obj.spotlight = nil
    obj.appCache = {}
end

--- Seal.plugins.apps:restart()
--- Method
--- Restarts the Spotlight app searcher
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function obj:restart()
    self:stop()
    self:start()
end

hs.application.enableSpotlightForNameSearches(true)
obj:start()

function obj:commands()
    return {
        kill = {
            cmd = "kill",
            fn = obj.choicesKillCommand,
            plugin = obj.__name,
            name = "Kill",
            description = "Kill an application"
        },
        reveal = {
            cmd = "reveal",
            fn = obj.choicesRevealCommand,
            plugin = obj.__name,
            name = "Reveal",
            description = "Reveal an application in the Finder"
        }
    }
end

function obj:bare()
    return self.choicesApps
end

function obj.choicesApps(query)
    local choices = {}
    if query == nil or query == "" then
        return choices
    end
    local queryWords = hs.fnutils.split(query:lower(), "%s+")
    local appWithWindows = extendAppCacheWithWindows(obj.appCache)

    for name, app in pairs(appWithWindows) do
        if queryMatchText(queryWords, name) then
            local choice = {}
            choice["subText"] = app["path"]
            if app["icon"] then
                choice["image"] = app["icon"]
            end
            choice["path"] = app["path"]
            choice["uuid"] = obj.__name .. "__" .. (app["bundleID"] or name)
            choice["plugin"] = obj.__name
            choice["type"] = "launchOrFocus"
            choice["text"] = name
            choice["window"] = app["window"]
            table.insert(choices, choice)
        end
    end

    return choices
end

function obj.choicesKillCommand(query)
    local choices = {}
    if query == nil then
        return choices
    end
    local apps = hs.application.runningApplications()
    for k, app in pairs(apps) do
        local name = app:name()
        if string.match(name:lower(), query:lower()) and app:mainWindow() then
            local choice = {}
            choice["text"] = "Kill " .. name
            choice["subText"] = app:path() .. " PID: " .. app:pid()
            choice["pid"] = app:pid()
            choice["plugin"] = obj.__name
            choice["type"] = "kill"
            choice["image"] = hs.image.imageFromAppBundle(app:bundleID())
            table.insert(choices, choice)
        end
    end
    return choices
end

function obj.choicesRevealCommand(query)
    local choices = {}
    if query == nil then
        return choices
    end
    local apps = obj.choicesApps(query)
    for k, app in pairs(apps) do
        local name = app.text
        if string.match(name:lower(), query:lower()) then
            local choice = {}
            choice["text"] = "Reveal " .. name
            choice["path"] = app.path
            choice["subText"] = app.path
            choice["plugin"] = obj.__name
            choice["type"] = "reveal"
            if app.image then
                choice["image"] = app.image
            end
            table.insert(choices, choice)
        end
    end
    return choices
end

function obj.completionCallback(rowInfo)
    if rowInfo["type"] == "launchOrFocus" then
        if rowInfo["window"] ~= nil then
            rowInfo["window"]:focus()
        elseif string.find(rowInfo["path"], "%.applescript$") or string.find(rowInfo["path"], "%.scpt$") then
            hs.task.new("/usr/bin/osascript", nil, {rowInfo["path"]}):start()
        else
            hs.task.new("/usr/bin/open", nil, {rowInfo["path"]}):start()
        end
    elseif rowInfo["type"] == "kill" then
        hs.application.get(rowInfo["pid"]):kill()
    elseif rowInfo["type"] == "reveal" then
        hs.osascript.applescript(string.format([[tell application "Finder" to reveal (POSIX file "%s")]],
            rowInfo["path"]))
        hs.application.launchOrFocus("Finder")
    end
end

return obj
