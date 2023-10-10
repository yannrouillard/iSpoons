--- === VideoConfAutoSound ===
---
--- Automatically stop/start music and increase/decrease volume when entering/leaving a video conference
---
local obj = {}
obj.__index = obj

-- Metadata
obj.name = "VideoConfAutoSound"
obj.version = "1.0"
obj.author = "Yann Rouillard <yann@pleiades.fr.eu.org>"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- VideoConfAutoSound.logger
-- Variable
-- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('VideoConfAutoSound', 'info')

-- VideoConfAutoSound.videoConferenceVolume
-- Variable
-- Volume level to set when  a video conference is started
obj.videoConferenceVolume = 95

local delayedTimer = nil
local soundChangeDelay = 0.2

local currentInputDevice = nil

local videoConferenceVolume = 95

local soundState = {}

local findSleepPreventAssertions = function(filterFunction)
    local foundAssertions = {}
    for _, assertions in pairs(hs.caffeinate.currentAssertions()) do
        foundAssertions = hs.fnutils.concat(foundAssertions, hs.fnutils.filter(assertions, filterFunction))
    end
    return foundAssertions
end

local isFirefoxSleepPreventAssertion = function(assertion)
    return assertion.AssertName == "audio-playing" and assertion["Process Name"] == "firefox"
end

local isFirefoxPlaying = function()
    local firefoxAudioOutSleepPreventAssertions = findSleepPreventAssertions(isFirefoxSleepPreventAssertion)
    return #firefoxAudioOutSleepPreventAssertions > 0
end

local onInputDeviceChanged = function(callback)
    hs.audiodevice.watcher.setCallback(function(event)
        if event == "dIn " and hs.audiodevice.defaultInputDevice() ~= currentInputDevice then
            local newInputDevice = hs.audiodevice.defaultInputDevice()
            obj.logger.d("Input device change detected from " .. (currentInputDevice:name() or "nil") .. " to " ..
                             (newInputDevice:name() or "nil"))
            currentInputDevice = newInputDevice
            callback()
        end
    end)
    hs.audiodevice.watcher.start()
end

local saveSoundState = function()
    soundState = {
        spotifyPlaying = hs.spotify.isPlaying(),
        firefoxPlaying = isFirefoxPlaying(),
        soundVolume = hs.audiodevice.defaultOutputDevice():volume()
    }
    obj.logger.i("SoundState: " .. hs.inspect.inspect(soundState))
end

local restoreSoundState = function()
    if next(soundState) ~= nil then
        obj.logger.d("Restoring volume sound to " .. soundState.soundVolume)
        hs.audiodevice.defaultOutputDevice():setVolume(soundState.soundVolume)
        if soundState.spotifyPlaying then
            -- we wait a small delay to not resume spotify before the volume is decreased
            delayedTimer = hs.timer.doAfter(soundChangeDelay, function()
                obj.logger.d("Resuming Spotify playing")
                hs.spotify.play()
            end)
        elseif soundState.firefoxPlaying then
            hs.eventtap.event.newSystemKeyEvent('PLAY', true):post()
        end
    end
end

local adjustSoundEnvironmentForVideoConference = function(uuid, eventName)
    obj.logger.d("inputDevice event " .. eventName .. " received for device uuid " .. uuid)
    if eventName == "gone" and hs.audiodevice.findDeviceByUID(uuid) == currentInputDevice then
        -- inputDevice is now in use, we probably entered a video conference
        if currentInputDevice:inUse() then
            obj.logger.i("Videoconference started, adjusting sound environment")
            saveSoundState()
            if soundState.spotifyPlaying then
                obj.logger.d("Pausing Spotify for Videoconference")
                hs.spotify.pause()
            elseif soundState.firefoxPlaying then
                hs.eventtap.event.newSystemKeyEvent('PLAY', true):post()
            end
            -- we wait a small delay to not increase sound while spotify is still playing
            delayedTimer = hs.timer.doAfter(soundChangeDelay, function()
                obj.logger.d("Setting volume to " .. videoConferenceVolume .. " for Videoconference")
                hs.audiodevice.defaultOutputDevice():setVolume(videoConferenceVolume)
            end)

            -- inputDevice stopped being used, we probably left the video conference 
        else
            obj.logger.i("Visioconference finished, restoring sound environment")
            restoreSoundState()
        end
    end
end

local configureInputDeviceStateWatcher = function()
    obj.logger.i("Watching new input device " .. currentInputDevice:name())
    currentInputDevice:watcherCallback(adjustSoundEnvironmentForVideoConference)
    currentInputDevice:watcherStart()
end

function obj:start()
    currentInputDevice = hs.audiodevice.defaultInputDevice()
    onInputDeviceChanged(configureInputDeviceStateWatcher)
    configureInputDeviceStateWatcher()
end

return obj
