--[[
    Sleep Guard
    Version: 1.0.0

    Versioning: 1.0.x = fixes, 1.x.0 = new features, 2.0.0 = a change to
    how it works that you'd notice.

    Makes sure a Kobo with auto standby on still goes to sleep on time.

    With auto standby on (Settings > Device > Power saving), KOReader puts
    the Kobo into a light standby whenever nothing is happening, with a
    wake-up alarm for the next thing it has to do (the auto-suspend after
    10 minutes, for one). Everything hangs on that alarm: if it doesn't go
    off, or nothing happened to be scheduled (the alarm is then set to
    "never"), the standby just lasts until the screen is touched. Seen on a
    Kobo Sage: one standby lasted 8.4 hours instead of going to sleep after
    10 minutes, using about 1.3% an hour instead of about 0.1%.

    What it does (Kobo only, and only while auto standby is on):
    1) No standby lasts longer than 5 minutes. When nothing's due, the
       Kobo wakes for a moment and goes straight back into standby, which
       costs next to nothing, so a missing alarm can't strand it for hours.
    2) After every standby, if the Kobo hasn't been touched for longer than
       the auto-suspend time (plus 30 seconds' grace) and isn't already on
       the sleep screen, it goes to sleep then. That also covers KOReader's
       own auto-suspend timer having gone missing.
    3) When a standby lasts much longer than its alarm, it's noted in
       crash.log (up to 5 notes a start), so it's clear whether the alarm
       itself is what fails on that Kobo.

    What it leaves alone: suspend itself (it never touches sleep that
    already works), sleeping while charging (KOReader holds that back on
    purpose), auto-suspend turned off, and a Kobo that keeps waking itself
    up at night (KOReader gives up putting it back to sleep on purpose; the
    sleep screen is left alone, so there's no sleep/wake loop).

    No menu, no settings, no timers: it only runs right after a standby
    ends. To stop it, delete this file and restart.
    https://github.com/BrownTigerz/-KOReader.patches

    Changelog:
    1.0.0  2026-11-11  First release.
]]

local PATCH_VERSION = "1.0.0"

local logger = require("logger")
local Device = require("device")

local MAX_STANDBY = 5 * 60   -- seconds: the longest a single standby may last
local GRACE = 30             -- seconds past the auto-suspend time before acting
local LATE = 60              -- seconds past its alarm before a standby counts as late
local MAX_NOTES = 5          -- late-standby notes in crash.log per start

local function apply()
    if not (Device.isKobo and Device:isKobo()) then
        logger.info("Sleep guard " .. PATCH_VERSION .. ": not a Kobo, nothing to do")
        return
    end
    if type(Device.standby) ~= "function" or Device.__sleep_guard then return end
    Device.__sleep_guard = true

    local UIManager = require("ui/uimanager")
    local time = require("ui/time")
    local notes = 0

    -- KOReader's AutoSuspend plugin, from whichever screen is open
    local function autoSuspend()
        for _i, mod in ipairs({ "apps/reader/readerui", "apps/filemanager/filemanager" }) do
            local ok, M = pcall(require, mod)
            local ui = ok and type(M) == "table" and M.instance
            if ui and type(ui.autosuspend) == "table" then return ui.autosuspend end
        end
    end

    local function charging()
        local ok, pd = pcall(Device.getPowerDevice, Device)
        if not (ok and pd) then return false end
        local okc, c = pcall(pd.isCharging, pd)
        local okd, d = pcall(pd.isCharged, pd)
        return (okc and c) and not (okd and d)
    end

    -- Untouched past the auto-suspend time and not asleep yet: go to sleep now
    local function sleepIfOverdue()
        local as = autoSuspend()
        if not as then return end
        local timeout = tonumber(as.auto_suspend_timeout_seconds) or 0
        if timeout <= 0 then return end                -- auto-suspend off
        if as.going_to_suspend or Device.screen_saver_mode then return end
        local okp, PluginShare = pcall(require, "pluginshare")
        if okp and type(PluginShare) == "table" and PluginShare.pause_auto_suspend then return end
        if charging() then return end
        if not as.last_action_time then return end
        local idle = time.to_number(UIManager:getElapsedTimeSinceBoot() - as.last_action_time)
        if idle < timeout + GRACE then return end
        logger.warn(string.format("Sleep guard: untouched %d min, auto-suspend is %d min and hadn't run: going to sleep now",
            math.floor(idle / 60 + 0.5), math.floor(timeout / 60 + 0.5)))
        UIManager:suspend()
    end

    local orig_standby = Device.standby
    Device.standby = function(self, max_duration, ...)
        local alarm = max_duration
        if type(alarm) ~= "number" or alarm > MAX_STANDBY then alarm = MAX_STANDBY end
        local before = self.total_standby_time
        local ok, err = pcall(orig_standby, self, alarm, ...)
        if not ok then
            logger.warn("Sleep guard: standby failed:", tostring(err))
            return
        end
        -- Longer than its alarm by a minute or more: the alarm didn't wake it
        -- (measured from the running total, so a standby that was skipped,
        -- e.g. while charging, counts as 0)
        local slept = 0
        if before and self.total_standby_time then slept = time.to_number(self.total_standby_time - before) end
        if slept > alarm + LATE and notes < MAX_NOTES then
            notes = notes + 1
            logger.warn(string.format("Sleep guard: a standby lasted %.1f min, its wake-up alarm was set for %.1f min (it woke late)",
                slept / 60, alarm / 60))
        end
        -- Let anything that was due run first (KOReader's own auto-suspend
        -- among them), then check
        UIManager:tickAfterNext(function()
            local okc, errc = pcall(sleepIfOverdue)
            if not okc then logger.warn("Sleep guard: check failed:", tostring(errc)) end
        end)
    end

    logger.info("Sleep guard " .. PATCH_VERSION .. " loaded"
        .. ((Device.canStandby and Device:canStandby()) and "" or " (this Kobo can't standby: nothing to do)"))
end

local ok, err = pcall(apply)
if not ok then
    logger.warn("Sleep guard " .. PATCH_VERSION .. " couldn't start:", tostring(err))
end
