--[[
2-zz-sleepscreen-banner-diagnostics.lua - TEMPORARY troubleshooting patch
Version 1.1.0

CHANGELOG
1.1.0 - The 0.25 s heartbeat is gone: it was a timer of its own running
        for a minute after every sleep and wake. The shared perf core
        (the same block as the other diagnostics) does the job without
        one: in the minute after a sleep or wake it logs any timer that
        holds the screen 250 ms+ and any tap or event that takes 1 s+,
        plus the banner patch's own timers 80 ms+, flashes it asks for,
        timers left waiting at sleep, and a perf line once a minute when
        it did anything. The 60 minutes now start per version (the marker
        keeps the version), so an update isn't already expired.
1.0.8 - One line per entry: messages and popups with line breaks are
        joined with " / " (they used to split into untagged lines), and
        the invisible text-direction marks around file paths are removed.
1.0.7 - shared-log rotation cap raised from 256 KB to 2 MB (identical
         value across all diagnostics per contract)
1.0.6 - count eligible highlights from the open book's live annotations
         (like the banner patch) instead of only the sidecar on disk;
         ALLOWED_HL_STYLES / FALLBACK_QUOTES_PATH now read live from the
         banner patch's exposed settings instead of hardcoded copies
1.0.5 - NOT FOUND message-container log line now says the sleep-screen
         message is disabled when that's the case, instead of warning about
         a layout change on every sleep
1.0.4 - shared log contract v1: tagged lines now go to
         koreader/diagnostics.log (tag: sleepscreen-banner, rotation at
         2 MB keeps diagnostics.log.old); the individual
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
Rotation at 2 MB, older part kept as diagnostics.log.old.

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
                       call, plus (shared perf core, no timer) anything
                       that holds the screen 250 ms+ in the minute after a
                       sleep or wake.
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

local DIAG_VERSION = "1.1.0"

-- Shared log contract v1: all diagnostics append timestamped, tagged lines
-- to ONE file (koreader/diagnostics.log) so a full test run reads as a
-- single chronological log. Rotation at 2 MB, older part kept as
-- diagnostics.log.old.
local DIAG_TAG = "sleepscreen-banner"
local SHARED_LOG = DataStorage:getDataDir() .. "/diagnostics.log"
local SHARED_MAX_BYTES = 2 * 1024 * 1024
-- One line per entry: line breaks (multi-line popups and messages) are
-- joined with " / ", and the invisible text-direction marks KOReader puts
-- around file paths are removed, so every line keeps its time and tag.
local DIAG_BIDI = { "\226\129\166", "\226\129\167", "\226\129\168", "\226\129\169",
    "\226\128\170", "\226\128\171", "\226\128\172", "\226\128\173", "\226\128\174" }
local function diagOneLine(s)
    s = tostring(s)
    for _i, m in ipairs(DIAG_BIDI) do s = s:gsub(m, "") end
    s = s:gsub("%s*[\r\n]+%s*", " / ")
    return s
end

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
        f:write(os.date("%Y-%m-%d %I:%M:%S %p  "), "[", DIAG_TAG, "] ", diagOneLine(line), "\n")
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

-- read live from the banner patch (2-kobo-style-sleepscreen-banner.lua),
-- which exposes them as _G.__sleepscreen_banner_settings; fall back to
-- these defaults when the banner patch isn't installed
local _banner_settings = _G.__sleepscreen_banner_settings
local ALLOWED_HL_STYLES = (_banner_settings and _banner_settings.allowed_hl_styles)
    or { lighten = true, underscore = true }
local FALLBACK_QUOTES_PATH = (_banner_settings and _banner_settings.quotes_file_path)
    or "/mnt/onboard/Famous Quotes.txt"

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

local first_load
local function minutesSinceFirstLoad()
    -- version on line 1, first load on line 2: another version (or an old
    -- marker with just a time) starts a new window
    local f = io.open(STATE_FILE, "r")
    if f then
        local v, stamp = f:read("*l"), tonumber(f:read("*l") or "")
        f:close()
        if v == DIAG_VERSION and stamp and stamp <= os.time() then
            first_load = stamp
            return (os.time() - stamp) / 60
        end
    end
    -- no marker for this version yet -- this is the first load, write it now
    local wf = io.open(STATE_FILE, "w")
    if wf then
        first_load = os.time()
        wf:write(DIAG_VERSION, "\n", first_load, "\n")
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

log("==================== sleepscreen-banner diagnostics %s started ====================", DIAG_VERSION)
log("window: %.0f of %d minutes used (persists across restarts)", elapsed_minutes, TTL_MINUTES)

-- --------------------------------------------------------------------------
-- Watch window after each sleep event (no timer: the perf core below logs
-- anything that holds the screen while it's open)
-- --------------------------------------------------------------------------

local suspended = false   -- true between Suspend and Resume

local function touch()
    active_until = math.max(active_until, os.time() + PER_SLEEP_ACTIVE_S)
end

-- --------------------------------------------------------------------------
-- Read-only correctness checks: what SHOULD show, independent of the
-- banner patch's own (unreadable-from-here) internal state.
-- --------------------------------------------------------------------------

local function countEligibleHighlights(fp)
    --prefer the open book's live annotations, exactly like the banner patch:
    --highlights made this session may not be flushed to the sidecar yet
    local ok_ru, ReaderUI = pcall(require, "apps/reader/readerui")
    local reader = ok_ru and ReaderUI and ReaderUI.instance or nil
    local live = reader and reader.document and fp and reader.document.file == fp
    local annotations, source_err
    if live and reader.annotation then
        annotations = reader.annotation.annotations
        source_err = "no annotations in the open book"
    else
        local DocSettings = require("docsettings")
        if not (fp and DocSettings:hasSidecarFile(fp)) then
            return 0, "no sidecar for this book"
        end
        local ok_ds, ds = pcall(DocSettings.open, DocSettings, fp)
        if not (ok_ds and ds) then return 0, "sidecar unreadable" end
        local ok_a, ann = pcall(ds.readSetting, ds, "annotations")
        annotations = ok_a and ann or nil
        source_err = "no annotations in sidecar"
    end
    local n = 0
    if type(annotations) == "table" then
        for _, a in ipairs(annotations) do
            if type(a) == "table" and type(a.text) == "string" and a.drawer
                    and ALLOWED_HL_STYLES[a.drawer] and util.trim(a.text) ~= "" then
                n = n + 1
            end
        end
        return n, nil
    end
    return 0, source_err
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
        log("pre-call message container: NOT FOUND at the expected widget path (widget[1][1][2])" ..
            ((ok_me and message_enabled) and " -- KOReader's ScreenSaver layout may have changed"
                                           or " -- expected: sleep-screen message is disabled"))
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

-- Suspend/Resume: logged so they line up with everything else, and the
-- tap window re-opens on wake. KOReader broadcasts these as events; depending on version/device
-- they can arrive via broadcastEvent or sendEvent, so both are watched.
local function onPowerEvent(handler)
    if handler == "onSuspend" and not suspended then
        suspended = true
        if t0 then log("Suspend") end
    elseif handler == "onResume" and suspended then
        suspended = false
        if t0 then
            touch()   -- re-open the window so the wake tap gets logged
            log("Resume (watching %ds for taps and anything holding the screen)", PER_SLEEP_ACTIVE_S)
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

-- --------------------------------------------------------------------------
-- Shared perf core v1 (the same block in every diagnostic that uses it)
-- The first diagnostic to load installs it; the others plug into it. One
-- copy of KOReader's timer loop with each timer timed, one watch on screen
-- updates, sleep, input events and warnings, handed to whichever
-- diagnostics are logging right now. With none logging, every hook passes
-- straight through. No timers of its own; it's installed on the first pass
-- of the main loop, after every patch, so its hooks are the outermost.
-- --------------------------------------------------------------------------
local DiagCore
do
    local CORE_VERSION = 1
    DiagCore = package.loaded["diag_perf_core"]
    if type(DiagCore) ~= "table" then
        DiagCore = { version = CORE_VERSION, clients = {} }
        package.loaded["diag_perf_core"] = DiagCore
        local UIM = require("ui/uimanager")
        local ok_time, ktime = pcall(require, "ui/time")
        local function nowMs()
            if ok_time and type(ktime) == "table" and ktime.now and ktime.to_ms then
                return ktime.to_ms(ktime.now())
            end
            return math.floor(os.clock() * 1000)
        end
        DiagCore.now_ms = nowMs
        local function pk(...) return { n = select("#", ...), ... } end

        -- "plugins/x.koplugin/main.lua:12" for a function or a debug.getinfo
        local function short(src, line)
            src = tostring(src or "?"):gsub("^@", ""):gsub("^%./", ""):gsub("^.-plugins/", "plugins/")
                :gsub("^.-patches/", "patches/")
            return line and (src .. ":" .. tostring(line)) or src
        end
        function DiagCore.where(fn)
            if type(fn) ~= "function" then return tostring(fn) end
            local info = debug.getinfo(fn, "S")
            if not info then return "?" end
            return short(info.source, info.linedefined)
        end
        local function caller(level)
            local info = debug.getinfo(level + 1, "Sl")
            if not info then return "?" end
            return short(info.source, info.currentline)
        end

        local function anyOn()
            for _i, c in ipairs(DiagCore.clients) do
                local ok, v = pcall(c.on)
                if ok and v then return true end
            end
            return false
        end
        local function emit(kind, ...)
            for _i, c in ipairs(DiagCore.clients) do
                local ok, v = pcall(c.on)
                if ok and v then pcall(c.handle, kind, ...) end
            end
        end

        local function install()
            -- Timers: KOReader's _checkTasks loop, each task timed.
            local orig_tasks = UIM._checkTasks
            if ok_time and type(orig_tasks) == "function" and type(UIM._task_queue) == "table" then
                UIM._checkTasks = function(self)
                    if not anyOn() then return orig_tasks(self) end
                    self._now = ktime.now()
                    local wait_until = nil
                    self._task_queue_dirty = false
                    while self._task_queue[1] do
                        local task_time = self._task_queue[#self._task_queue].time
                        if task_time <= self._now then
                            local task = table.remove(self._task_queue)
                            local t0 = nowMs()
                            if type(task.args) == "table" then
                                task.action(unpack(task.args, 1, task.args.n))
                            else
                                task.action()
                            end
                            emit("timer", task.action, nowMs() - t0)
                        else
                            wait_until = task_time
                            break
                        end
                    end
                    return wait_until, self._now
                end
            end

            -- Screen updates: who asked, and which kind (a flash or not).
            local orig_sd = UIM.setDirty
            if type(orig_sd) == "function" then
                UIM.setDirty = function(self, widget, refresh, ...)
                    if not anyOn() then return orig_sd(self, widget, refresh, ...) end
                    local src = caller(2)
                    if type(refresh) == "function" then
                        local f = refresh
                        refresh = function(...)
                            local r = pk(f(...))
                            emit("dirty", src, r[1])
                            return unpack(r, 1, r.n)
                        end
                    else
                        emit("dirty", src, refresh)
                    end
                    return orig_sd(self, widget, refresh, ...)
                end
            end

            -- Input events: slow ones (taps, swipes) are reported.
            local orig_send = UIM.sendEvent
            if type(orig_send) == "function" then
                UIM.sendEvent = function(self, event, ...)
                    if not anyOn() then return orig_send(self, event, ...) end
                    local t0 = nowMs()
                    local res = pk(orig_send(self, event, ...))
                    local dt = nowMs() - t0
                    if dt >= 15 and type(event) == "table" then
                        local h = tostring(event.handler or "?"):gsub("^on", "")
                        local ges = h == "Gesture" and event.args and event.args[1]
                        if type(ges) == "table" and ges.ges then h = "Gesture " .. tostring(ges.ges) end
                        emit("event", h, dt)
                    end
                    return unpack(res, 1, res.n)
                end
            end

            -- Sleep: the timers still waiting after every plugin handled it.
            local orig_bc = UIM.broadcastEvent
            if type(orig_bc) == "function" then
                UIM.broadcastEvent = function(self, event, ...)
                    local h = type(event) == "table" and event.handler
                    if not (anyOn() and (h == "onSuspend" or h == "onResume")) then
                        return orig_bc(self, event, ...)
                    end
                    local res = pk(orig_bc(self, event, ...))
                    if h == "onSuspend" then
                        local actions = {}
                        for _i, task in ipairs(self._task_queue or {}) do actions[#actions + 1] = task.action end
                        emit("sleep", actions)
                    else
                        emit("wake")
                    end
                    return unpack(res, 1, res.n)
                end
            end

            -- Warnings and errors, with the file that wrote them.
            local ok_l, logger = pcall(require, "logger")
            if ok_l and type(logger) == "table" then
                for _i, lvl in ipairs({ "warn", "err" }) do
                    local orig = logger[lvl]
                    if type(orig) == "function" then
                        logger[lvl] = function(...)
                            if anyOn() then
                                local src = caller(2)
                                local parts = {}
                                for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
                                local msg = table.concat(parts, " ")
                                if #msg > 300 then msg = msg:sub(1, 300) .. "..." end
                                emit("warn", lvl, src, msg)
                            end
                            return orig(...)
                        end
                    end
                end
            end
        end
        UIM:nextTick(function() pcall(install) end)
    end

    function DiagCore.register(client)
        table.insert(DiagCore.clients, client)
    end

    -- A standard client: everything the core sees that comes from the
    -- patch's own files (o.targets: parts of a path, e.g. "2-network-tweaks.lua").
    --   o.name     label in the lines ("ShelfSync Tweaks")
    --   o.log, o.on  the diagnostic's own log and "logging now?" functions
    --   o.errors   also log the patch's warnings/errors (when the
    --              diagnostic doesn't catch them itself)
    --   o.busy     optional: while it returns true, a timer of anyone's that
    --              holds the screen 250 ms+ or a tap/swipe 1 s+ is logged
    --              (replaces a freeze heartbeat; the patch was busy then, it
    --              isn't necessarily the cause)
    --   o.extra    optional: a few words added to the once-a-minute line
    --   o.summary  optional: where the once-a-minute line goes (default
    --              o.log; a diagnostic that only writes inside its own
    --              windows passes a function that drops it otherwise)
    function DiagCore.client(o)
        local SLOW_MS = o.slow_ms or 80
        local BUSY_TIMER_MS, BUSY_EVENT_MS = o.busy_timer_ms or 250, o.busy_event_ms or 1000
        local function mine(src)
            src = tostring(src or "")
            for _i, t in ipairs(o.targets) do
                if src:find(t, 1, true) then return true end
            end
            return false
        end
        local st = { since = os.time(), runs = 0, ms = 0, max = 0, max_src = nil, dirty = 0, flashes = 0 }
        local function summary(force)
            if not force and os.time() - st.since < 60 then return end
            if st.runs > 0 or st.dirty > 0 then
                local extra = o.extra and o.extra() or nil
                ;(o.summary or o.log)("perf (last %d s): %s timers ran %d times, %d ms in all, slowest %d ms%s | screen updates asked %d, flashes %d | Lua memory %.1f MB%s",
                    os.time() - st.since, o.name, st.runs, st.ms, st.max,
                    st.max_src and (" (" .. st.max_src .. ")") or "", st.dirty, st.flashes,
                    collectgarbage("count") / 1024, extra and (" | " .. extra) or "")
            end
            st.since, st.runs, st.ms, st.max, st.max_src, st.dirty, st.flashes = os.time(), 0, 0, 0, nil, 0, 0
        end
        local FLASH = { flashui = true, full = true, flashpartial = true }
        local client = { on = o.on }
        function client.handle(kind, a, b, c)
            if kind == "timer" then
                local src = DiagCore.where(a)
                if mine(src) then
                    st.runs, st.ms = st.runs + 1, st.ms + b
                    if b > st.max then st.max, st.max_src = b, src end
                    if b >= SLOW_MS then o.log("slow: %s timer %s took %d ms", o.name, src, b) end
                elseif o.busy and b >= BUSY_TIMER_MS and o.busy() then
                    o.log("screen held %d ms by timer %s while %s was busy", b, src, o.name)
                end
            elseif kind == "dirty" then
                if mine(a) then
                    st.dirty = st.dirty + 1
                    if FLASH[b] then
                        st.flashes = st.flashes + 1
                        o.log("FLASH %s asked by %s", tostring(b), a)
                    end
                end
            elseif kind == "event" then
                if o.busy and b >= BUSY_EVENT_MS and o.busy() then
                    o.log("screen held %d ms by a %s while %s was busy", b, a, o.name)
                end
            elseif kind == "sleep" then
                summary(true)
                local by, n = {}, 0
                for _i, fn in ipairs(a or {}) do
                    local src = DiagCore.where(fn)
                    if mine(src) then by[src] = (by[src] or 0) + 1; n = n + 1 end
                end
                if n == 0 then
                    o.log("going to sleep: no %s timers left waiting", o.name)
                else
                    local bits = {}
                    for src, k in pairs(by) do bits[#bits + 1] = k .. " x " .. src end
                    table.sort(bits)
                    o.log("going to sleep: %d %s timers still waiting (!): %s", n, o.name, table.concat(bits, ", "))
                end
                return
            elseif kind == "warn" then
                -- a = level, b = the file that wrote it, c = the message
                if o.errors and mine(b) then
                    o.log("%s from %s: %s", a == "err" and "ERROR" or "warning", b, tostring(c))
                end
            end
            summary(false)
        end
        DiagCore.register(client)
        return client
    end
end

-- The banner patch's own file, plus (busy) anything of anyone's that holds
-- the screen in the minute after a sleep or wake: what the heartbeat used
-- to catch, with no timer of our own.
DiagCore.client({
    name = "Sleep Screen Banner",
    targets = { "2-kobo-style-sleepscreen-banner.lua" },
    on = function() return first_load ~= nil and os.time() - first_load < TTL_MINUTES * 60 end,
    log = log,
    busy = function() return active() and not suspended end,
    errors = false,
})

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
