--[[
2-zz-xray-direct-lookup-diagnostics.lua - TEMPORARY troubleshooting patch
Version 1.2.5

Watches xray.koplugin AND 2-xray-direct-lookup.lua from OUTSIDE. It never edits
either one: every hook calls the original and returns all of its results, and
all of this file's own logging is wrapped in pcall so it cannot break them.
Its log lines go to the shared koreader/diagnostics.log, each tagged
[xray-direct-lookup] (shared log contract v1) - there is no individual log
file.

Changelog
1.2.5  Shared-log rotation cap raised from 256 KB to 2 MB
       (SHARED_MAX_BYTES = 2 * 1024 * 1024), per TK — all 12
       diagnostics use the identical value.
1.2.4  ">>> MISSED" no longer false-positives on deliberate passthroughs:
       drag/multi-word selections, select_mode, and multi-word text are
       filtered outright; when the lookupAll probe finds no stored X-Ray
       entity it logs a soft note instead (default menu flow expected).
       MISSED now fires only when X-Ray HAS data but the main patch made
       no decision — an actual miss.
1.2.3  Shared log contract v1: log lines now go to the shared
       koreader/diagnostics.log tagged [xray-direct-lookup] (256 KB
       rotation to diagnostics.log.old); the individual
       xray-direct-lookup-diagnostics.log is gone. Window, 256 KB size
       cap, and 2-day expiry gating unchanged.
1.2.2  The start-up status note now goes through the shared notification
       contract v1 (Network Tweaks style, else ReadMastery style, else the
       existing Notification widget); never over the sleep screen.
1.2.1  Review fixes, verified against xray.koplugin source: instrument()
       also wraps lookup_manager by name (it is built as
       LookupManager:new(self), so no .plugin backref is needed); the log
       mirror recognises "swallowed" so the watchdog's late release no
       longer false-positives ">>> MISSED"; snapshot() skips the extra
       lookupAll probe when the toggle is off; the RH hook-check pattern is
       anchored to the main patch's filename; the logger.info override
       restores the original once the window closes (still no timers). The
       settings.json on-disk check was verified correct against
       AIHelper:saveSettings - no change.
1.2.0  Rebuilt to the diagnostics house rules: logging window starts at
       start-up (20 min) and then every hook passes straight through; hard
       expiry after 2 days; no timers or polling at all (the heartbeat and
       memory ticker are gone - everything is measured from hooked events);
       size cap stops logging instead of rolling over; date + 12-hour
       timestamps; one notification per start.
1.1.2  Raw touch sequence (hold / hold_release / tap).
1.1.1  Time from hold-release to first paint; onHold timing.
1.1.0  Times every X-Ray function; ENV dump; summary table.
1.0.x  Direct-lookup decision logging.

What it watches (only while the window is open)
  - ENV: X-Ray settings (API keys shown only as <set>/<empty>), provider and
    model, X-Ray mode, direct-lookup toggle, this book's X-Ray files.
  - The direct-lookup patch's own decisions ([main] lines: reroute, passthrough
    with reason, dismissed, dictionary button, release watchdog).
  - Which ReaderHighlight path fired for each word select, the lookupAll match
    count and time, and ">>> MISSED" when the patch made no decision.
  - Raw touch events (hold, hold_release, tap), and how long the screen took
    to respond after a touch ("screen response").
  - Every X-Ray function (plugin, lookup manager, AI helper): calls over 50ms
    are logged, all calls are totalled in a SUMMARY table (calls, total ms,
    max, average; times include nested calls).
  - fetchSingleWord start and AI round-trip time.
  - KOReader main-loop stages that run long: events, scheduled tasks, paints,
    window show/close; suspend, resume, power, charging, network events.
  - Lua memory at every word select, summary and book close.

How to use
  1. Switch it on in Add-ons > Debugging (or leave it in koreader/patches/)
     and restart KOReader. A 20 minute window opens at start-up.
  2. Within 20 minutes: long-press names X-Ray knows and ones it doesn't,
     open the picker, tap Dictionary, turn pages, sleep and wake, open and
     close a book.
  3. Use Debugging > Combine logs, or send diagnostics.log (this patch's lines
     are tagged [xray-direct-lookup]).
  4. Switch it off in Debugging, or delete the file.

How it shuts itself off
  - Window: 20 minutes after start-up. After that every hook just calls the
    original; nothing is logged, not even a single event.
  - Size cap: at 256 KB it writes one line and stops logging.
  - Hard expiry: 2 days after the first run (kept in the .state file). After
    that it writes one line per start to the log and hooks nothing.
  - No timers: nothing is scheduled, nothing polls, nothing wakes the device
    (one single nextTick shows the start-up note).

Files written (all in koreader/)
  diagnostics.log                   the shared diagnostics log (this patch's lines
                                    are tagged [xray-direct-lookup])
  diagnostics.log.old               older half of the shared log after rotation
  xray-direct-lookup-diagnostics.state  first-run time for the 2-day expiry
It never touches crash.log or version.log, and never moves or deletes any
patch file. "Delete all logs" in the Debugging menu removes both files and
restarts the window and the 2-day clock.
--]]

local ok_userpatch, userpatch = pcall(require, "userpatch")
if not ok_userpatch or not userpatch or not userpatch.registerPatchPluginFunc then
    local ok_lb, lb = pcall(require, "logger")
    if ok_lb then lb.warn("xray-direct-lookup-diagnostics: userpatch API not available, skipping") end
    return
end

local DataStorage = require("datastorage")
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")
local ok_time, ktime = pcall(require, "ui/time")
local logger = require("logger")

local VERSION = "1.2.5"
-- Shared log contract v1: all diagnostics append timestamped, tagged lines
-- to ONE file (koreader/diagnostics.log) so a full test run reads as a
-- single chronological log. Rotation at 2 MB, older part kept as
-- diagnostics.log.old.
local DIAG_TAG = "xray-direct-lookup"
local SHARED_LOG = DataStorage:getDataDir() .. "/diagnostics.log"
local SHARED_MAX_BYTES = 2 * 1024 * 1024
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
local STATE = DataStorage:getDataDir() .. "/xray-direct-lookup-diagnostics.state"
local WINDOW_S = 20 * 60          -- logging window after start-up
local EXPIRY_S = 2 * 24 * 3600    -- hard expiry after first run
local MAX_BYTES = 256 * 1024      -- log size cap

-- ---- Hard expiry ----------------------------------------------------------
local function readFirstRun()
    local f = io.open(STATE, "r")
    if not f then return nil end
    local txt = f:read("*a") or ""
    f:close()
    return tonumber(txt:match("first_run=(%d+)"))
end

local start_s = os.time()
local first_run = readFirstRun()
if not first_run then
    first_run = start_s
    pcall(function()
        local f = io.open(STATE, "w")
        if f then
            f:write("first_run=", tostring(first_run), "\n")
            f:close()
        end
    end)
end
if start_s - first_run > EXPIRY_S then
    shared_log("xray-direct-lookup diagnostics %s: expired (first ran %s) - not hooking anything. Delete this diagnostic's log to start a new 2 days.",
        VERSION, os.date("%Y-%m-%d", first_run))
    return
end

-- ---- Window / logging -----------------------------------------------------
local window_end = start_s + WINDOW_S
local capped = false

local function active()
    return not capped and os.time() <= window_end
end

local function now()
    return ok_time and ktime.now() or nil
end

local function ms(since)
    if not (ok_time and since) then return -1 end
    local ok, v = pcall(function() return ktime.to_ms(ktime.since(since)) end)
    return ok and v or -1
end

local function log(fmt, ...)
    if not active() then return end
    local ok, line = pcall(string.format, fmt, ...)
    if not ok then line = tostring(fmt) end
    pcall(function()
        if (lfs.attributes(SHARED_LOG, "size") or 0) > MAX_BYTES then
            capped = true
            shared_log("log size cap reached (%d KB) - logging stopped", math.floor(MAX_BYTES / 1024))
            return
        end
        shared_log("%s", line)
    end)
end

log("==================== xray-direct-lookup diagnostics %s started ====================", VERSION)
log("logging window: %d minutes from now", math.floor(WINDOW_S / 60))

-- Shared notification contract v1: user-facing status notes resolve style
-- in priority order - Network Tweaks' style if installed, ReadMastery's if
-- installed, otherwise the caller's own default. Checks run at call time,
-- so patch load order does not matter. Never over the sleep screen.
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

-- ---- Stats -----------------------------------------------------------------
local stats = {}
local slow_logged = {}
local SLOW_CALL_MS, SLOW_LINES_PER_KEY = 50, 20
local SLOW_EVENT_MS, SLOW_TASK_MS, SLOW_PAINT_MS, SLOW_WIDGET_MS = 80, 100, 150, 60
local SLOW_RESPONSE_MS = 250
local SUMMARY_EVERY_S = 300
local last_summary_s = start_s

local function record(key, d)
    local e = stats[key]
    if not e then e = { n = 0, total = 0, max = 0 }; stats[key] = e end
    e.n = e.n + 1
    e.total = e.total + d
    if d > e.max then e.max = d end
end

local function dumpSummary(why, top_n)
    if not active() then return end
    last_summary_s = os.time()
    local rows = {}
    for k, e in pairs(stats) do rows[#rows + 1] = { k = k, e = e } end
    table.sort(rows, function(a, b) return a.e.total > b.e.total end)
    log("-------------------- SUMMARY (%s) --------------------", why)
    log("%-44s %6s %9s %7s %7s", "function (inclusive time)", "calls", "total ms", "max", "avg")
    for i = 1, math.min(top_n or 25, #rows) do
        local r = rows[i]
        log("%-44s %6d %9d %7d %7.1f", r.k:sub(1, 44), r.e.n, r.e.total, r.e.max, r.e.total / r.e.n)
    end
    if #rows == 0 then log("(no X-Ray functions were called yet)") end
    log("lua mem %.1fMB", collectgarbage("count") / 1024)
end

-- Event-driven only: no timer, so a summary is written when a hooked event
-- happens and the last one is old enough.
local function maybeSummary()
    if active() and os.time() - last_summary_s >= SUMMARY_EVERY_S then
        dumpSummary("periodic", 12)
    end
end

local function slow(key, d, limit_lines)
    local n = (slow_logged[key] or 0) + 1
    slow_logged[key] = n
    if n <= (limit_lines or SLOW_LINES_PER_KEY) then
        log("SLOW %s: %d ms", key, d)
    elseif n == (limit_lines or SLOW_LINES_PER_KEY) + 1 then
        log("(further SLOW %s lines suppressed - see SUMMARY)", key)
    end
end

-- ---- Generic safe hook ------------------------------------------------------
-- before(...)  runs first (errors ignored);  after(ctx, ms)  runs last.
-- The original is always called, and ALL of its results are returned.
local function finish(after, ctx, t, ...)
    if after then
        local d = ms(t)
        pcall(after, ctx, d)
    end
    return ...
end

local function hook(tbl, name, before, after)
    local orig = tbl[name]
    if type(orig) ~= "function" then return false end
    tbl[name] = function(...)
        if not active() then return orig(...) end
        local ctx
        if before then
            local ok, c = pcall(before, ...)
            if ok then ctx = c end
        end
        local t = now()
        return finish(after, ctx, t, orig(...))
    end
    return true
end

-- ---- Touch -> screen response (replaces any polling heartbeat) -------------
local input_t, input_name = nil, nil
local susp_seen = false
local env_dumped = false

-- ---- UIManager main-loop hooks ----------------------------------------------
local INTERESTING = {
    Suspend = true, Resume = true, PowerRelease = true, Charging = true,
    NotCharging = true, NetworkConnected = true, NetworkDisconnected = true,
    CloseDocument = true, ReaderReady = true,
}

if not UIManager.__dxr_diag_wrapped then
    UIManager.__dxr_diag_wrapped = true

    hook(UIManager, "sendEvent",
        function(_, event)
            local name = event and (event.name or tostring(event.handler):gsub("^on", "")) or "?"
            if name == "Suspend" or name == "Resume" then susp_seen = true end
            if name == "CloseDocument" then dumpSummary("book closed") end
            if name == "Gesture" then
                local g = event.args and event.args[1]
                local gt = type(g) == "table" and g.ges
                if gt == "hold" or gt == "hold_release" or gt == "tap" or gt == "double_tap" then
                    log("touch: %s at (%s,%s)", gt, tostring(g.pos and g.pos.x), tostring(g.pos and g.pos.y))
                    input_t, input_name = now(), gt
                    if gt == "hold_release" then
                        log("lua mem %.1fMB", collectgarbage("count") / 1024)
                        maybeSummary()
                    end
                elseif gt == "swipe" then
                    input_t, input_name = now(), gt
                end
            end
            return name
        end,
        function(name, d)
            if d >= SLOW_EVENT_MS then
                slow("event " .. tostring(name), d, 10)
            elseif INTERESTING[name] then
                log("event %s (%d ms)", tostring(name), d)
            end
        end)

    hook(UIManager, "_checkTasks", nil, function(_, d)
        if d >= SLOW_TASK_MS then slow("scheduled tasks", d, 20) end
    end)

    hook(UIManager, "_repaint", nil, function(_, d)
        if input_t then
            local resp = ms(input_t)
            if resp >= SLOW_RESPONSE_MS then
                log("screen response: %d ms after %s (that paint took %d ms)", resp, tostring(input_name), d)
            end
            input_t = nil
        end
        if d >= SLOW_PAINT_MS then
            local top = UIManager:getTopmostVisibleWidget()
            slow(string.format("paint (top=%s)", tostring(top and (top.name or top.id) or "?")), d, 30)
        end
    end)

    for _, name in ipairs({ "show", "close" }) do
        hook(UIManager, name,
            function(_, widget)
                return tostring(widget and (widget.name or widget.id) or "?")
            end,
            function(wname, d)
                if d >= SLOW_WIDGET_MS then slow("UIManager:" .. name .. "(" .. tostring(wname) .. ")", d, 20) end
            end)
    end
end

-- ---- Generic X-Ray instrumentation -------------------------------------------
local SKIP_FN = { init = true, new = true, extend = true, log = true, t = true, _t = true, tr = true }
local wrapped_tbl = setmetatable({}, { __mode = "k" })

local function wrapTable(tbl, label)
    if type(tbl) ~= "table" or wrapped_tbl[tbl] then return end
    wrapped_tbl[tbl] = true
    local names = {}
    for k, v in pairs(tbl) do
        if type(k) == "string" and type(v) == "function" and not SKIP_FN[k] and not k:find("^__") then
            names[#names + 1] = k
        end
    end
    for _, k in ipairs(names) do
        local key = label .. "." .. k
        hook(tbl, k, nil, function(_, d)
            record(key, d)
            if d >= SLOW_CALL_MS then slow(key, d) end
        end)
    end
end

-- Only helper objects that point back at the plugin; never KOReader's own
-- ui/document objects. lookup_manager is matched by name too: X-Ray builds
-- it as LookupManager:new(self), with no .plugin backref to find.
local function instrument(plugin)
    local names = { "xray(class)" }
    wrapTable(plugin, "xray")
    for k, v in pairs(plugin) do
        if type(k) == "string" and type(v) == "table" and k ~= "ui"
                and (v.plugin == plugin or k == "ai_helper" or k == "lookup_manager") then
            wrapTable(v, "xray." .. k)
            names[#names + 1] = k
            local mt = getmetatable(v)
            if mt and type(mt.__index) == "table" then
                wrapTable(mt.__index, "xray." .. k)
            end
        end
    end
    log("instrumented helpers: %s", table.concat(names, ", "))
end

local function dumpEnv(x)
    local Device_ok, Device = pcall(require, "device")
    log("ENV device=%s | x-ray mode_enabled=%s | last_pageno=%s",
        Device_ok and tostring(Device.model) or "?", tostring(x.xray_mode_enabled), tostring(x.last_pageno))
    pcall(function()
        local NetworkMgr = require("ui/network/manager")
        log("ENV wifi on=%s", tostring(NetworkMgr:isWifiOn()))
    end)
    local st = x.ai_helper and x.ai_helper.settings
    if type(st) == "table" then
        local keys = {}
        for k in pairs(st) do keys[#keys + 1] = tostring(k) end
        table.sort(keys)
        for _, k in ipairs(keys) do
            local v = st[k]
            if k:lower():find("key") or k:lower():find("token") or k:lower():find("secret") then
                v = (v and v ~= "") and "<set>" or "<empty>"
            elseif type(v) == "table" then
                v = string.format("{provider=%s model=%s}", tostring(v.provider), tostring(v.model))
            end
            log("ENV setting %s = %s", k, tostring(v):sub(1, 60))
        end
    end
    pcall(function()
        local DocSettings = require("docsettings")
        local file = x.ui and x.ui.document and x.ui.document.file
        log("ENV book = %s", tostring(file))
        local dir = file and DocSettings:getSidecarDir(file)
        if dir and lfs.attributes(dir, "mode") == "directory" then
            for e in lfs.dir(dir) do
                if e:lower():find("xray") then
                    local a = lfs.attributes(dir .. "/" .. e)
                    if a and a.mode == "file" then
                        log("ENV sidecar %s  %.1f KB  age %d min", e, a.size / 1024,
                            math.floor((os.time() - a.modification) / 60))
                    end
                end
            end
        end
    end)
end

-- ---- Direct-lookup state snapshot ---------------------------------------------
local function findXRay(hl)
    local ui = hl and hl.ui
    if not ui then return nil, "no hl.ui" end
    if type(ui.xray) == "table" then return ui.xray, "ui.xray" end
    return nil, "not found in ui"
end

local function settingsOnDisk()
    local f = io.open(DataStorage:getSettingsDir() .. "/xray/settings.json", "r")
    if not f then return "settings.json missing" end
    local txt = f:read("*a") or ""
    f:close()
    return "settings.json key=" .. tostring(txt:match('"xray_direct_lookup"%s*:%s*(%a+)'))
end

local decision_seen = false
-- Last lookupAll probe match count from snapshot(), so the MISSED check can
-- tell "no X-Ray data" (correct passthrough) from a real miss.
local snapshot_matches = nil

local function snapshot(hl, word)
    snapshot_matches = nil
    local x, how = findXRay(hl)
    if not x then
        log("  STATE: xray plugin instance NOT FOUND (%s) | %s", how, settingsOnDisk())
        return
    end
    if not env_dumped then env_dumped = true; pcall(dumpEnv, x) end
    local st = x.ai_helper and x.ai_helper.settings or {}
    log("  STATE: instance via %s | mode_enabled=%s | lookup_manager=%s | toggle in memory=%s | %s",
        how, tostring(x.xray_mode_enabled), tostring(x.lookup_manager ~= nil),
        tostring(st.xray_direct_lookup), settingsOnDisk())
    -- The probe only matters when the toggle is on: with it off every word
    -- is a silent passthrough and the extra lookup buys nothing.
    if word and word ~= "" and x.lookup_manager and st.xray_direct_lookup == true then
        local t = now()
        local ok, res = pcall(function() return x.lookup_manager:lookupAll(word) end)
        if ok then snapshot_matches = #res end
        log("  STATE: lookupAll('%s') -> %s matches in %d ms%s", word:sub(1, 40),
            ok and tostring(#res) or "ERROR", ms(t), ok and "" or (" " .. tostring(res)))
        if ok and #res == 0 then
            log("  STATE: X-Ray has NO stored entity for this word (check spelling / alias / nickname)")
        end
    end
end

-- ---- Mirror the direct-lookup patch's own log lines ----------------------------
local orig_logger_info = logger.info
local info_restored = false
logger.info = function(msg, ...)
    if not active() then
        -- Window closed: put the original back so this override does not
        -- live for the rest of the session. No timer needed - the first
        -- info call after the window does the restore.
        if not info_restored then
            info_restored = true
            logger.info = orig_logger_info
        end
        return orig_logger_info(msg, ...)
    end
    if type(msg) == "string" and msg:find("DirectXRay:", 1, true) then
        pcall(function()
            if msg:find("passthrough", 1, true) or msg:find("lookup via", 1, true)
                    or msg:find("reroute", 1, true) or msg:find("finishing", 1, true)
                    or msg:find("swallowed", 1, true) then
                decision_seen = true
            end
            log("[main] %s", (msg:gsub("^DirectXRay:%s*", "")))
        end)
    end
    return orig_logger_info(msg, ...)
end

-- ---- ReaderHighlight paths -------------------------------------------------------
do
    local ok_rh, RH = pcall(require, "apps/reader/modules/readerhighlight")
    if ok_rh and type(RH) == "table" and not RH.__dxr_diag_wrapped then
        RH.__dxr_diag_wrapped = true
        for _, name in ipairs({ "onHold", "onHoldRelease", "onShowHighlightMenu", "lookupDictWord" }) do
            local f = RH[name]
            local info = type(f) == "function" and debug.getinfo(f, "S") or nil
            local src = info and info.source or "missing"
            -- Anchored to the main patch's own filename: this file's name
            -- (2-zz-xray-direct-lookup-diagnostics.lua) also contains
            -- "xray-direct-lookup", so an unanchored match would lie.
            log("hook check: RH.%s defined in %s%s", name, src:sub(-48),
                src:find("2%-xray%-direct%-lookup%.lua$") and "  [main patch hook OK]" or "  [original KOReader]")
        end
        local function watch(name, top)
            hook(RH, name,
                function(hl, a1)
                    local sel = hl.selected_text
                    local txt = sel and sel.text or ""
                    log("RH.%s  text='%s'  word_sel=%s select_mode=%s index=%s",
                        name, tostring(txt):sub(1, 40), tostring(hl.is_word_selection),
                        tostring(hl.select_mode), tostring(type(a1) ~= "table" and a1 or nil))
                    if top then
                        decision_seen = false
                        snapshot(hl, txt)
                    end
                    return { txt = txt, word_sel = hl.is_word_selection, select_mode = hl.select_mode }
                end,
                function(ctx, d)
                    log("RH.%s returned after %d ms", name, d)
                    if top and type(ctx) == "table" and ctx.txt ~= "" and not decision_seen then
                        -- Deliberate passthroughs: the main patch only acts on
                        -- single-word selections outside select_mode. Filter
                        -- these so MISSED keeps meaning an actual miss.
                        if not ctx.word_sel then
                            log("  (no X-Ray action: drag/multi-word selection, patch handles single words only)")
                        elseif ctx.select_mode then
                            log("  (no X-Ray action: select_mode active)")
                        elseif ctx.txt:find("%s") then
                            log("  (no X-Ray action: multi-word text)")
                        elseif snapshot_matches == 0 then
                            log("  (no X-Ray action: no stored X-Ray entity for this word — default menu flow expected)")
                        elseif snapshot_matches and snapshot_matches > 0 then
                            log("  >>> MISSED: the direct-lookup patch made NO decision for '%s' (%d X-Ray matches!)",
                                tostring(ctx.txt):sub(1, 40), snapshot_matches)
                        else
                            log("  (no X-Ray decision for '%s' — probe unavailable, unable to verify)",
                                tostring(ctx.txt):sub(1, 40))
                        end
                    elseif top and type(ctx) == "string" and ctx ~= "" and not decision_seen then
                        -- Back-compat: pre-hook previously returned the bare text.
                        log("  >>> MISSED: the direct-lookup patch made NO decision for '%s'", tostring(ctx):sub(1, 40))
                    end
                end)
        end
        watch("onHold")
        watch("onHoldRelease", true)
        watch("onShowHighlightMenu")
        watch("lookupDictWord")
    end
end

-- ---- X-Ray plugin ------------------------------------------------------------------
userpatch.registerPatchPluginFunc("xray", function(XRayPlugin)
    if XRayPlugin.__dxr_diag_patched then return end
    XRayPlugin.__dxr_diag_patched = true

    pcall(wrapTable, XRayPlugin, "xray")

    local orig_init = XRayPlugin.init
    local function after_init(self)
        instrument(self)
        -- AI round trip for words X-Ray has to fetch.
        if not self.__dxr_diag_fsw_wrapped then
            self.__dxr_diag_fsw_wrapped = true
            local word, t_fetch
            hook(self, "fetchSingleWord",
                function(_, text)
                    word, t_fetch = tostring(text), now()
                    log("fetchSingleWord start: '%s'", word:sub(1, 40))
                end, nil)
            hook(self, "_processSingleWordResult", nil, function()
                if t_fetch then
                    log("fetchSingleWord round-trip: %d ms for '%s'", ms(t_fetch), tostring(word):sub(1, 40))
                    t_fetch = nil
                end
            end)
        end
    end
    -- init's results are returned untouched (LuaJIT-safe vararg pass-through).
    local function pass_init(self, ...)
        pcall(after_init, self)
        return ...
    end
    function XRayPlugin:init(...)
        return pass_init(self, orig_init(self, ...))
    end

    log("diagnostics mounted on the X-Ray plugin class")
end)

-- One note per start, only while logging. A single nextTick (not a loop).
UIManager:nextTick(function()
    if active() then
        local msg = string.format("X-Ray direct lookup diagnostics: logging for %d min",
            math.floor(WINDOW_S / 60))
        if not shared_note(msg) then
            pcall(function()
                require("ui/widget/notification"):notify(msg)
            end)
        end
    end
end)
