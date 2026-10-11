--[[
2-zz-sleepscreen-banner-diagnostics.lua - TEMPORARY troubleshooting patch
Version 1.0.4

CHANGELOG
1.0.4 - shared log contract v1: tagged lines now go to
         koreader/diagnostics.log (tag: sleepscreen-banner, rotation at
         256 KB keeps diagnostics.log.old); the individual
         sleepscreen-banner-diagnostics.log file is retired
1.0.3 - status notification now goes through the shared notification
         contract v1 (Network Tweaks style > ReadMastery style > default)
1.0.2 - log timestamps now include the date (per diagnostics standard);
         start line matches the standard format;
         highlight-eligibility check is pcall-wrapped so a failure can't
         break the sleep screen; an unwritable first-load marker now fails
         closed (expired) instead of installing hooks forever; TTL
         comparison is >= instead of >
1.0.1 - heartbeat now pauses on Suspend and restarts on Resume, so the
         time the device spends asleep no longer gets logged as a false
         "SCREEN FROZEN"; Suspend/Resume are logged so you can line them
         up with everything else; the tap-watch window re-opens on Resume
         (before, a sleep longer than 60s closed it, so the wake tap was
         never logged)
1.0.0 - baseline

Watches 2-kobo-style-sleepscreen-banner.lua from OUTSIDE (it never requires
or edits that file) and writes tagged lines to:
    koreader/diagnostics.log   (shared log contract v1, tag: sleepscreen-banner)
(Kobo: .adds/koreader/diagnostics.log)
Rotation at 256 KB, older part kept as diagnostics.log.old.

How to use:
  1. Put this file in koreader/patches/ next to
     2-kobo-style-sleepscreen-banner.lua and restart KOReader.
  2. Let the device sleep and wake a few times -- ideally once on a book
     with eligible highlights, once on a book with none (to exercise the
     quotes.txt fallback), and once with Wi-Fi/other things going on so
     timing isn't artificially clean.
  3. Send koreader/diagnostics.log (look for lines tagged [sleepscreen-banner]).
  4. Delete this file and restart. It changes nothing about the banner
     patch, it only reads settings/sidecars and logs what it sees.

SELF-EXPIRY: so this can't be left running indefinitely if you forget to
delete it, it records the first time it loaded in a tiny marker file
(sleepscreen-banner-diagnostics.log.firstload) and checks that on EVERY
restart. Once TTL_MINUTES has passed since that first load, it installs
no hooks at all -- zero runtime cost -- even if the file is still sitting
in patches/. Delete both files to reset it, or just delete this one when
you're done; the marker is harmless on its own.

What it checks, roughly mapped to an audit's usual sections:
  sleep_state       - did the intercept conditions (message type "banner",
                       wallpaper cover/random_image/document_cover) actually
                       hold, and did the widget tree end up looking replaced?
  performance       - ms spent inside the (possibly patched) UIManager.show
                       call, plus a freeze-heartbeat for anything that hangs
                       the screen after a sleep/wake.
  resume behavior    - taps/holds received for a short window after each
                       sleep, so a busted layout swallowing the wake tap
                       would show up as "gesture received very late" or
                       "no gesture logged at all".
  correctness        - eligible highlight count and quotes.txt line count,
                       read independently here, to compare against what the
                       banner actually shows on screen.
  resources          - collectgarbage("count") before/after, so a real leak
                       (in this patch or anything else) would trend upward
                       across many sleep events instead of staying flat.
]]

local DataStorage = require("datastorage")
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")
local util = require("util")
local ok_time, ktime = pcall(require, "ui/time")

-- Shared log contract v1: all diagnostics append timestamped, tagged lines
-- to ONE file (koreader/diagnostics.log) so a full test run reads as a
-- single chronological log. Rotation at 256 KB, older part kept as
-- diagnostics.log.old.
local DIAG_TAG = "sleepscreen-banner"
local SHARED_LOG = DataStorage:getDataDir() .. "/diagnostics.log"
local SHARED_MAX_BYTES = 256 * 1024
local function shared_log(fmt, ...)
    local ok, line = pcall(string.format, fmt, ...)
    if not ok then line = tostring(fmt) end
    pcall(function()
        if (lfs.attributes(SHARED_LOG, "size") or 0) > SHARED_MAX_BYTES then
            os.remove(SHARED_LOG .. ".old")
            os.rename(SHARED_LOG, SHARED_LOG .. ".old")
        end
        local f = io.open(SHARED_LOG, "a")
        if not f then return end
        f:write(os.date("%Y-%m-%d %I:%M:%S %p  "), "[", DIAG_TAG, "] ", line, "\n")
        f:close()
    end)
end

-- first-load marker keeps its old name (it is a TTL marker, not a log file);
-- the Debugging Menu only scans for quoted "/<name>.log" strings, and this
-- ends in ".firstload", so it can't be mistaken for a log target.
local STATE_FILE = DataStorage:getDataDir() .. "/sleepscreen-banner-diagnostics.log.firstload"

local TTL_MINUTES = 60   -- stops installing hooks this long after first load,
                          -- persisted across restarts -- see header. Several
                          -- sleep/wake cycles usually fit in this window;
                          -- shorten it if you only need a quick check.
local PER_SLEEP_ACTIVE_S = 60 -- how long after each sleep event to keep
                               -- watching for the wake tap / freezes, so
                               -- normal reading in between sleeps doesn't
                               -- get logged at all.

-- keep these two in sync with the main patch if you change them there --
-- this file reads them independently rather than requiring the patch.
local ALLOWED_HL_STYLES = { lighten = true, underscore = true }
local FALLBACK_QUOTES_PATH = "/mnt/onboard/Famous Quotes.txt"

-- --------------------------------------------------------------------------
-- Log + timing helpers
-- --------------------------------------------------------------------------

local t0
local active_until = 0

local function now()
    return ok_time and ktime.now() or nil
end

local function ms(since)
    if not (ok_time and since) then return -1 end
    local ok, v = pcall(function() return ktime.to_ms(ktime.since(since)) end)
    return ok and v or -1
end

local function active()
    return t0 ~= nil and os.time() <= active_until
end

local function log(fmt, ...)
    local ok, line = pcall(string.format, fmt, ...)
    if not ok then line = tostring(fmt) end
    -- date/time and [sleepscreen-banner] tag are added by shared_log; the
    -- +NNms offset (time since the ScreenSaver show) is content, kept here.
    shared_log("+%6dms  %s", t0 and ms(t0) or 0, line)
end

local function q(v) return v == nil and "(nil)" or tostring(v) end

-- --------------------------------------------------------------------------
-- Shared notification contract v1: user-facing status notes resolve style
-- in priority order -- (1) Network Tweaks' note, (2) ReadMastery's note,
-- (3) this patch's own default. Checks happen at call time, so patch load
-- order doesn't matter.
-- --------------------------------------------------------------------------

local function shared_note(banner_text, minimal_text, timeout)
    local Device = require("device")
    if Device.screen_saver_mode then return true end -- never over the sleep screen
    local NetworkMgr = require("ui/network/manager")
    if type(NetworkMgr.__network_tweaks_note) == "function" then
        local ok, handled = pcall(NetworkMgr.__network_tweaks_note, banner_text, minimal_text, timeout)
        if ok and handled then return true end
    end
    local rm = _G.__readmastery_note
    if type(rm) == "function" then
        local ok, handled = pcall(rm, banner_text or minimal_text, timeout)
        if ok and handled then return true end
    end
    return false
end

-- --------------------------------------------------------------------------
-- Self-expiry: first-load marker persisted across restarts
-- --------------------------------------------------------------------------

local function minutesSinceFirstLoad()
    local f = io.open(STATE_FILE, "r")
    if f then
        local stamp = tonumber(f:read("*a"))
        f:close()
        if stamp then
            return (os.time() - stamp) / 60
        end
    end
    -- no marker yet -- this is the first load, write it now
    local wf = io.open(STATE_FILE, "w")
    if wf then
        wf:write(tostring(os.time()))
        wf:close()
        return 0
    end
    -- marker unwritable: fail closed (no expiry window can be tracked),
    -- so the caller treats this as expired and installs nothing
    return nil
end

local elapsed_minutes = minutesSinceFirstLoad()
local expired = (elapsed_minutes == nil) or (elapsed_minutes >= TTL_MINUTES)

if expired then
    if elapsed_minutes == nil then
        log("diagnostics DISABLED: could not write the first-load marker -- " ..
            "refusing to install hooks with no expiry. Delete this file when done.")
    else
        log("diagnostics window expired (%.0f min since first load, TTL %d min) " ..
            "-- no hooks installed. Delete this file (and the matching " ..
            ".firstload marker if you want a fresh window).", elapsed_minutes, TTL_MINUTES)
    end
    return
end

log("==================== sleepscreen-banner diagnostics 1.0.4 started ====================")
log("window: %.0f of %d minutes used (persists across restarts)", elapsed_minutes, TTL_MINUTES)

-- --------------------------------------------------------------------------
-- Frozen-screen heartbeat, active only in the window after a sleep event
-- --------------------------------------------------------------------------

local beat_last
local suspended = false   -- true between Suspend and Resume: the scheduler
                          -- is frozen while asleep, so any gap measured
                          -- across it is sleep time, not a hang
local function beat()
    if suspended or not active() then beat_last = nil; return end
    local gap = beat_last and ms(beat_last) or 0
    if gap > 750 then log("SCREEN FROZEN for ~%dms since the last heartbeat", gap - 250) end
    beat_last = now()
    UIManager:scheduleIn(0.25, beat)
end

local function touch()
    active_until = math.max(active_until, os.time() + PER_SLEEP_ACTIVE_S)
end

-- --------------------------------------------------------------------------
-- Read-only correctness checks: what SHOULD show, independent of the
-- banner patch's own (unreadable-from-here) internal state.
-- --------------------------------------------------------------------------

local function countEligibleHighlights(fp)
    local DocSettings = require("docsettings")
    if not (fp and DocSettings:hasSidecarFile(fp)) then
        return 0, "no sidecar for this book"
    end
    local ok_ds, ds = pcall(DocSettings.open, DocSettings, fp)
    if not (ok_ds and ds) then return 0, "sidecar unreadable" end
    local ok_a, ann = pcall(ds.readSetting, ds, "annotations")
    local n = 0
    if ok_a and type(ann) == "table" then
        for _, a in ipairs(ann) do
            if type(a) == "table" and type(a.text) == "string" and a.drawer
                    and ALLOWED_HL_STYLES[a.drawer] and util.trim(a.text) ~= "" then
                n = n + 1
            end
        end
    end
    return n, nil
end

local function countQuoteLines(path)
    local f = io.open(path, "r")
    if not f then return 0, "file not found or unreadable at this path" end
    local n = 0
    for line in f:lines() do
        if util.trim(line) ~= "" then n = n + 1 end
    end
    f:close()
    return n, nil
end

-- Best-effort read of the sleep-screen message container, mirroring the
-- same structural assumption the banner patch itself makes. Returns the
-- container table (so we can re-read it after the call) plus a snapshot
-- of what it looked like beforehand.
local function snapshotContainer(widget)
    local ok, container = pcall(function() return widget[1][1][2] end)
    if not (ok and type(container) == "table") then return nil end
    local w = container.widget
    return {
        container = container,
        pre_hpos = container.horizontal_position,
        pre_widget_ref = w,
        pre_text = w and w.text and tostring(w.text):sub(1, 40) or nil,
    }
end

-- --------------------------------------------------------------------------
-- The actual watch: wraps whatever UIManager.show currently is (the real
-- engine function if the banner patch isn't installed, or the banner
-- patch's own wrapper if it loaded first -- either way this file never
-- calls into the banner patch directly, it only observes the outcome).
-- --------------------------------------------------------------------------

local orig_show = UIManager.show
UIManager.show = function(self, widget, ...)
    if type(widget) ~= "table" or widget.name ~= "ScreenSaver" then
        return orig_show(self, widget, ...)
    end

    t0 = now()
    touch()
    UIManager:unschedule(beat)
    beat_last = now()
    UIManager:scheduleIn(0.25, beat)

    log("---- ScreenSaver shown ----")

    local ok_st, screensaver_type = pcall(G_reader_settings.readSetting, G_reader_settings, "screensaver_type")
    local ok_me, message_enabled = pcall(G_reader_settings.isTrue, G_reader_settings, "screensaver_show_message")
    local ok_mc, message_type = pcall(G_reader_settings.readSetting, G_reader_settings, "screensaver_message_container")
    log("settings: screensaver_type=%s  message_enabled=%s  message_container=%s",
        q(ok_st and screensaver_type), q(ok_me and message_enabled), q(ok_mc and message_type))

    local conditions_met = ok_me and message_enabled and ok_mc and message_type == "banner"
        and ok_st and (screensaver_type == "cover" or screensaver_type == "random_image"
                        or screensaver_type == "document_cover")
    log("banner patch SHOULD intercept this sleep: %s", tostring(conditions_met))

    local ok_lf, last_file = pcall(G_reader_settings.readSetting, G_reader_settings, "lastfile")
    last_file = ok_lf and last_file or nil
    log("current book: %s", q(last_file))

    -- pcall-wrapped: this check must never break the sleep screen,
    -- even if the sidecar module fails to load
    local ok_hl, hl_n, hl_e = pcall(countEligibleHighlights, last_file)
    local hl_count, hl_err
    if ok_hl then
        hl_count, hl_err = hl_n, hl_e
    else
        hl_count, hl_err = 0, "highlight check failed: " .. tostring(hl_n)
    end
    log("eligible highlights in this book (lighten/underscore): %d%s",
        hl_count, hl_err and ("  (" .. hl_err .. ")") or "")

    if hl_count == 0 then
        local q_count, q_err = countQuoteLines(FALLBACK_QUOTES_PATH)
        log("fallback quotes.txt (%s): %d lines%s", FALLBACK_QUOTES_PATH, q_count,
            q_err and ("  (" .. q_err .. ")") or "")
    end

    local pre = snapshotContainer(widget)
    if pre then
        log("pre-call message container: horizontal_position=%s  text=\"%s\"",
            q(pre.pre_hpos), q(pre.pre_text))
    else
        log("pre-call message container: NOT FOUND at the expected widget path " ..
            "(widget[1][1][2]) -- KOReader's ScreenSaver layout may have changed")
    end

    local mem_before = collectgarbage("count")
    local t = now()
    local res = { pcall(orig_show, self, widget, ...) }
    local elapsed = ms(t)
    local mem_after = collectgarbage("count")

    if not res[1] then
        log("UIManager.show ERRORED: %s", q(res[2]))
    end
    log("UIManager.show took %dms  |  lua heap %.1fKB -> %.1fKB (delta %.1fKB)",
        elapsed, mem_before, mem_after, mem_after - mem_before)
    if elapsed > 500 then
        log("SLOW: sleep-screen took over half a second to show -- worth a closer look")
    end

    if pre then
        local post_widget = pre.container.widget
        local post_hpos = pre.container.horizontal_position
        local replaced = post_widget ~= pre.pre_widget_ref
        local looks_like_banner_frame = type(post_widget) == "table" and post_widget.bordersize ~= nil
        local intercepted = replaced and post_hpos == 0 and looks_like_banner_frame
        log("post-call message container: horizontal_position=%s  widget replaced=%s  " ..
            "looks like our FrameContainer=%s  => intercepted=%s",
            q(post_hpos), tostring(replaced), tostring(looks_like_banner_frame), tostring(intercepted))
        if conditions_met and not intercepted then
            log("MISMATCH: settings say the banner patch should have intercepted this, " ..
                "but the widget doesn't look replaced -- check patch load order and the " ..
                "widget[1][1][2] path assumption against your KOReader version")
        elseif not conditions_met and intercepted then
            log("MISMATCH: widget looks replaced even though settings say it shouldn't be " ..
                "-- unexpected, worth a look")
        end
    end

    if not res[1] then error(res[2], 0) end
    return unpack(res, 2)
end

-- Taps/holds during the active window after a sleep event, to confirm
-- waking the device still works normally against the replaced widget.
local orig_send = UIManager.sendEvent
UIManager.sendEvent = function(self, ev, ...)
    if active() and type(ev) == "table" and ev.handler == "onGesture" then
        local g = ev.args and ev.args[1]
        if type(g) == "table" and (g.ges == "tap" or g.ges == "hold") then
            log("%s at %s,%s", g.ges, q(g.pos and g.pos.x), q(g.pos and g.pos.y))
        end
    end
    return orig_send(self, ev, ...)
end

-- Suspend/Resume: pause the heartbeat across the actual sleep so it isn't
-- reported as a freeze, then restart it (and re-open the tap window) on
-- wake. KOReader broadcasts these as events; depending on version/device
-- they can arrive via broadcastEvent or sendEvent, so both are watched.
local function onPowerEvent(handler)
    if handler == "onSuspend" and not suspended then
        suspended = true
        UIManager:unschedule(beat)
        beat_last = nil
        if t0 then log("Suspend (heartbeat paused)") end
    elseif handler == "onResume" and suspended then
        suspended = false
        if t0 then
            touch()   -- re-open the window so the wake tap gets logged
            log("Resume (heartbeat restarted, watching %ds for taps/freezes)", PER_SLEEP_ACTIVE_S)
            UIManager:unschedule(beat)
            beat_last = now()
            UIManager:scheduleIn(0.25, beat)
        end
    end
end

local orig_broadcast = UIManager.broadcastEvent
UIManager.broadcastEvent = function(self, ev, ...)
    if type(ev) == "table" then onPowerEvent(ev.handler) end
    return orig_broadcast(self, ev, ...)
end

local send_with_gestures = UIManager.sendEvent
UIManager.sendEvent = function(self, ev, ...)
    if type(ev) == "table" then onPowerEvent(ev.handler) end
    return send_with_gestures(self, ev, ...)
end

log("hooks installed, watching for ScreenSaver shows")

UIManager:nextTick(function()
    local msg = string.format("Diagnostics: writing diagnostics.log [sleepscreen-banner] (%.0f/%d min used)",
        elapsed_minutes, TTL_MINUTES)
    if not shared_note(msg, "Banner diagnostics: logging", nil) then
        pcall(function()
            require("ui/widget/notification"):notify(msg)
        end)
    end
end)
