--- === WorkOnOff ===
---
--- Easily start/stop applications, open URLs and start/stop Spoons when you start/stop working
---
local obj = {}
obj.__index = obj

-- Metadata
obj.name = "WorkOnOff"
obj.version = "1.0"
obj.author = "Yann Rouillard <yann@pleiades.fr.eu.org>"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- WorkOnOff.logger
-- Variable
-- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('WorkOnOff', 'info')

-- WorkOnOff.applications
-- Variable
-- List of applications to start/stop when starting/finishing a work day
-- The applications to start/stop should be under the `startstop` key
-- The applications to stop at the end of the work day, but to not start
-- automatically should be under the `stop` key
obj.applications = {
    startstop = {},
    stop = {}
}

-- WorkOnOff.urls
-- Variable
-- List of URLs to open when the work day starts
obj.urls = {}

-- WorkOnOff.spoons
-- Variable
-- List of spoons to start when then the work day starts
-- They must have been already loaded and passed as `spoon.<SPOON_NAME>`
obj.spoons = {}

-- WorkOnOff.functions
-- Variable
-- List of functions to run when the work days starts/stops
-- The function must be under the keys `start` or `stop` 
obj.functions = {
    start = {},
    stop = {}
}

--- WorkOnOff:workOn()
--- Method
--- Start everything (applications, spoons, urls...) that are required to start the work day
---
--- Parameters:
---  * None
---
function obj:workOn()
    hs.fnutils.ieach(self.applications.startstop, function(app)
        hs.application.launchOrFocus(app)
    end)

    hs.fnutils.ieach(self.urls, function(url)
        hs.urlevent.openURL(url)
    end)

    hs.fnutils.ieach(self.spoons, function(spoon)
        spoon:start()
    end)

    if obj.functions.on ~= nil then
        hs.fnutils.ieach(self.functions.start, function(workOnFunction)
            workOnFunction()
        end)
    end
end

--- WorkOnOff:workOff()
--- Method
--- Stop everything (applications, spoons...) that are work-related
---
--- Parameters:
---  * None
---
function obj:workOff()
    local appsToKill = hs.fnutils.concat(hs.fnutils.copy(self.applications.startstop), self.applications.stop)

    hs.fnutils.ieach(appsToKill, function(appName)
        local app = hs.application.find(appName)
        if app ~= nil then
            app:kill()
        end
    end)

    hs.fnutils.ieach(self.spoons, function(spoon)
        spoon:stop()
    end)

    if self.functions.off ~= nil then
        hs.fnutils.ieach(self.functions.stop, function(workOffFunction)
            workOffFunction()
        end)
    end

end

--- WorkOnOff:bindHotkeys(mapping) -> self
--- Method
--- Binds hotkeys to WorkOnOff methods
---
--- Parameters:
---  * mapping - A table containing hotkey modifier/key details for each available operation
---
--- Returns:
---  * The WorkOnOff object
function obj:bindHotkeys(mapping)
    local spec = {
        workOn = hs.fnutils.partial(self.workOn, self),
        workOff = hs.fnutils.partial(self.workOff, self)
    }
    hs.spoons.bindHotkeysToSpec(spec, mapping)
    return self
end

function obj:init()
    self.sealActions = {
        ["Work Off"] = {
            fn = hs.fnutils.partial(self.workOff, self),
            image = hs.image.imageFromPath(hs.spoons.resourcePath("icons/work_off.png"))
        },
        ["Work On"] = {
            fn = hs.fnutils.partial(self.workOn, self),
            image = hs.image.imageFromPath(hs.spoons.resourcePath("icons/work_on.png"))
        }
    }
end

return obj
