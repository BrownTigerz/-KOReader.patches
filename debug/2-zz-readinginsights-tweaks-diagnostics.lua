--[[
2-zz-readinginsights-tweaks-diagnostics.lua - TEMPORARY troubleshooting patch
Version 2.1.1

Watches Reading Insights Tweaks from outside and writes what it sees as
tagged lines to the SHARED diagnostics log (shared log contract v1):
    koreader/diagnostics.log   (TAG "readinginsights-tweaks")
(Kobo: .adds/koreader/diagnostics.log)
So a full test run with other diagnostics patches reads as one
chronological log; the tag identifies this patch's lines.

What it records:
  Startup   KOReader/device/screen, night mode, Tweaks version, which hooks
            applied, every toggle, Reading Insights version, database sizes.
  Windows   every popup shown/closed with its stack position; "SHOWN BEHIND"
            when one lands under a modal popup.
  Touch     each tap/hold/swipe, which window got it, and how long until the
            screen actually updated (tap-to-screen latency).
  Speed     build time of the book calendar and suspend handling; cover
            scaling (count + time); database queries (count + time).
  Screen    e-ink refreshes by type per session (full/flash refreshes are the
            ones that cost battery and flicker).
  Sleep     suspend/resume, time asleep, whether Reading Insights' sleep screen
            showed, timers still pending at suspend (anything from Tweaks that
            would wake or run around sleep), connections left open.
  Memory    Lua heap + process RSS at the start and end of each session, so a
            leak shows as steady growth.
  Warnings  every "RI tweaks:" warning the main patch logs.
  Perf      (shared perf core) for the whole 48 hours: a Tweaks or Reading
            Insights timer that holds the screen 80 ms+, a flash either
            asks for, and their timers still waiting when the device sleeps
            each open a session; inside a session, a once-a-minute perf
            line (their timers, screen updates, flashes, Lua memory).

How to use:
  1. Put this file in koreader/patches/ next to 2-readinginsights-tweaks.lua
     and restart KOReader.
  2. Open each view the patch changes: Book progress calendar (page a month),
     heatmap, Records (tap a cover), KOReader's Statistics calendar view.
     Sleep and wake once or twice.
  3. Send diagnostics.log (grep the [readinginsights-tweaks] tag).
  4. Delete this file and restart.

Safety nets in case you forget to delete it:
  - A session only logs while you're using these popups: it starts when one
    opens (or at suspend), ends 2 minutes after the last activity, and never
    runs longer than 10 minutes. Outside a session each hook is one flag check.
  - It expires 48 hours after this version first loaded (a new version
    starts a new 48 hours): from then on it installs no
    hooks at all, writes one line to the log per start, and shows a one-time
    "delete me" notice at startup.
  - The shared log rotates at 2 MB (older part kept as diagnostics.log.old).
It never changes the main patch's behaviour. The "zz" makes it load after it.

Changelog
  1.0.0  2026-10-04  First release.
  1.1.0  2026-10-08  Tap-to-screen latency, e-ink refresh counts, query and
                     cover-scaling timings, sleep/resume checks (time asleep,
                     timers pending at suspend, sleep card on top), 10-minute
                     session cap, 48-hour auto-expiry.
  1.1.1  2026-10-09  Reports the tall_fit hook (Tweaks 1.1.3).
  1.1.2  2026-10-11  Convention fixes: removed the 4Hz frozen-screen heartbeat
                     (no-timers rule; freeze detection dropped, tap-to-screen
                     latency still catches interaction stalls); timestamps now
                     include the date; startup first line matches the required
                     format; expiry writes one log line per start; touch() is
                     pcall-wrapped so it can never throw past the originals.
  1.1.3  2026-10-11  Shared notification contract v1: the two status notes
                     (startup logging note, expiry delete-me note) resolve
                     style through Network Tweaks' note, then ReadMastery's,
                     then the default Notification widget.
  1.1.4  2026-10-11  Shared log contract v1: all lines now go to the shared
                     koreader/diagnostics.log (tagged "readinginsights-tweaks",
                     256 KB rotation to diagnostics.log.old) instead of the
                     patch's own ri-tweaks-diagnostics.log; line content and
                     all gating unchanged.
  1.1.5  2026-10-12  Shared-log rotation cap raised from 256 KB to 2 MB
                     (TK-approved; identical cap across all diagnostics).
  2.0.0  2026-10-16  For Tweaks 2.0.0: dropped the streak calendar grid/tap and
                     sleep card watchers (those features were removed); hook
                     report lists book_header and stats_calendar only; the
                     suspend check reads Reading Insights 8's sleep screen
                     field (_screensaver_widgets, falls back to the old name).
  2.0.1  2026-10-22  One line per entry: messages and popups with line breaks
                     are joined with " / " (they used to split into untagged
                     lines), and the invisible text-direction marks around
                     file paths are removed. Header reads "Version" like the
                     other diagnostics.
  2.1.0  2026-10-23  Shared perf core (the same block as the other
                     diagnostics): slow timers, flashes and timers left
                     waiting at sleep from Reading Insights Tweaks and
                     Reading Insights, plus a once-a-minute perf line while
                     a session is open. The 48 hours now start per version
                     (kept in readinginsights-tweaks-diagnostics.state; the
                     old setting is removed), so an update isn't already
                     expired when it arrives.
  2.1.1  2026-10-23  "db open ... (open now: N)" only counts connections whose
                     close it can actually see. On this KOReader a connection
                     doesn't take the close watcher, so the count only ever
                     went up (52 after a few minutes) and looked like a leak.
                     Those opens now say "(closes can't be watched here)" and
                     the suspend line says so instead of a number.
]]

local DataStorage = require("datastorage")
local Device = require("device")
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local ok_time, ktime = pcall(require, "ui/time")
local ok_up, userpatch = pcall(require, "userpatch")

local DIAG_VERSION = "2.1.1"

-- ---- Shared log contract v1 ---------------------------------------------------------------
-- All diagnostics append timestamped, tagged lines to ONE file
-- (koreader/diagnostics.log) so a full test run reads as a single
-- chronological log. Rotation at 2 MB, older part kept as diagnostics.log.old.
local DIAG_TAG = "readinginsights-tweaks"
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

local IDLE_S = 120          -- a session ends this long after the last activity
local SESSION_MAX_S = 600   -- and never runs longer than this
local EXPIRE_H = 48         -- the whole patch goes inert this long after first load
local HOOK_NAME = "ri_tweaks_hook"
local SETTINGS_KEY = "ri_cover_calendar"
local FIRST_LOAD_KEY = "ri_tweaks_diag_first_load" -- before 2.1.0; removed on load
local STATE = DataStorage:getDataDir() .. "/readinginsights-tweaks-diagnostics.state"

-- ---- Shared notification contract v1 --------------------------------------------------------
-- Status notes resolve style in priority order: Network Tweaks' note, then
-- ReadMastery's, then the default Notification widget. Checked at call time,
-- so patch load order doesn't matter. Requires adapted to pcall (file convention).
local function shared_note(banner_text, minimal_text, timeout)
    if Device.screen_saver_mode then return true end -- never over the sleep screen
    local ok_nm, NetworkMgr = pcall(require, "ui/network/manager")
    if ok_nm and type(NetworkMgr) == "table" and type(NetworkMgr.__network_tweaks_note) == "function" then
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

-- KOReader's PluginLoader wraps every plugin on* handler in a HandlerSandbox
-- (a callable table, not a function) before userpatch callbacks run, so a bare
-- type() == "function" check silently misses them. Accept any callable.
local function isCallable(v)
    if type(v) == "function" then return true end
    if type(v) == "table" then
        local mt = getmetatable(v)
        return type(mt) == "table" and type(mt.__call) == "function"
    end
    return false
end

-- ---- Auto-expiry ---------------------------------------------------------------------------
-- First load of THIS version, in a state file: version on line 1, time on
-- line 2. Another version (or no file) starts a new 48 hours.
pcall(function()
    if G_reader_settings:readSetting(FIRST_LOAD_KEY) ~= nil then G_reader_settings:delSetting(FIRST_LOAD_KEY) end
end)
local first_load
do
    local f = io.open(STATE, "r")
    if f then
        local v, t = f:read("*l"), tonumber(f:read("*l") or "")
        f:close()
        if v == DIAG_VERSION and t and t <= os.time() then first_load = t end
    end
    if not first_load then
        first_load = os.time()
        local w = io.open(STATE, "w")
        if w then w:write(DIAG_VERSION, "\n", first_load, "\n") w:close() end
    end
end
if os.time() - first_load > EXPIRE_H * 3600 then
    -- Expired: one line in the log per start, then no hooks, no logging.
    pcall(function()
        shared_log("ri-tweaks diagnostics %s expired; delete 2-zz-readinginsights-tweaks-diagnostics.lua", DIAG_VERSION)
    end)
    UIManager:nextTick(function()
        if not shared_note("RI Tweaks diagnostics expired. Delete 2-zz-readinginsights-tweaks-diagnostics.lua") then
            pcall(function()
                require("ui/widget/notification"):notify(
                    "RI Tweaks diagnostics expired. Delete 2-zz-readinginsights-tweaks-diagnostics.lua")
            end)
        end
    end)
    return
end

-- ---- Log + session clock -------------------------------------------------------------------
local t0, session_start, active_until = nil, 0, 0
local stats = {}

local function now() return ok_time and ktime.now() or nil end

local function ms(since)
    if not (ok_time and since) then return -1 end
    local ok, v = pcall(function() return ktime.to_ms(ktime.since(since)) end)
    return ok and v or -1
end

local function active()
    return t0 ~= nil and os.time() <= active_until and os.time() - session_start <= SESSION_MAX_S
end

local function q(v) return v == nil and "(nil)" or tostring(v) end

local function log(fmt, ...)
    local ok, line = pcall(string.format, fmt, ...)
    if not ok then line = tostring(fmt) end
    -- shared_log adds the date+time timestamp and tag; the +Nms session
    -- offset is this file's own content and is kept verbatim.
    shared_log("+%7dms  %s", t0 and ms(t0) or 0, line)
end

local function memory()
    local lua_kb = math.floor(collectgarbage("count"))
    local rss = "?"
    local f = io.open("/proc/self/status", "r")
    if f then
        for l in f:lines() do
            local v = l:match("^VmRSS:%s*(%d+)")
            if v then rss = v break end
        end
        f:close()
    end
    return string.format("lua heap %d KB, process RSS %s KB", lua_kb, rss)
end

local function resetStats()
    stats = { refresh = {}, queries = 0, query_ms = 0, scales = 0, scale_ms = 0, repaints = 0, repaint_ms = 0 }
end
resetStats()

-- Tasks still queued in UIManager that came from Tweaks / this file / Reading Insights.
local function pendingTasks()
    local out = {}
    for _i, task in ipairs(UIManager._task_queue or {}) do
        local info = type(task.action) == "function" and debug.getinfo(task.action, "S")
        local src = info and info.source or ""
        local who = (src:find("readinginsights-tweaks.lua", 1, true) and not src:find("diagnostics", 1, true) and "Tweaks")
            or (src:find("readinginsights.koplugin", 1, true) and "Reading Insights")
        if who then
            local ok_s, in_s = pcall(function() return math.floor(ktime.to_ms(task.time - ktime.now()) / 1000) end)
            if not ok_s then in_s = "?" end
            out[#out + 1] = string.format("%s:%s in %ss", who, q(info.linedefined), q(in_s))
        end
    end
    return out
end

local function summary()
    local r = {}
    for mode, n in pairs(stats.refresh) do r[#r + 1] = mode .. "=" .. n end
    table.sort(r)
    log("summary | refreshes: %s | repaints %d (%dms) | db queries %d (%dms) | covers scaled %d (%dms)",
        #r > 0 and table.concat(r, " ") or "none", stats.repaints, stats.repaint_ms,
        stats.queries, stats.query_ms, stats.scales, stats.scale_ms)
end

local function endSession(why)
    if not t0 then return end
    summary()
    local pend = pendingTasks()
    log("session ended (%s) | %s | pending tasks: %s", why, memory(), #pend > 0 and table.concat(pend, ", ") or "none")
    t0 = nil
end

-- pcall-wrapped: touch() runs before the original in several wrappers,
-- so it must never throw past them and break the real UI.
local function touch(what)
    pcall(function()
        if not active() then
            if t0 then endSession("restart") end
            t0 = now()
            session_start = os.time()
            resetStats()
            log("==================== session: %s ====================", what or "?")
            log("memory at start | %s", memory())
        end
        active_until = os.time() + IDLE_S
    end)
end

-- ---- Describing windows --------------------------------------------------------------------
local function classSource(w)
    local mt = getmetatable(w)
    local cls = mt and mt.__index
    for _i = 1, 4 do
        if type(cls) ~= "table" then break end
        for _k, v in pairs(cls) do
            if type(v) == "function" then
                local info = debug.getinfo(v, "S")
                local src = info and info.source or ""
                local short = src:match("([^/]+%.koplugin/[^/]+%.lua)$") or src:match("([^/]+%.lua)$")
                if short then return short end
            end
        end
        local cmt = getmetatable(cls)
        cls = cmt and cmt.__index
    end
    return "?"
end

local function describe(w)
    if type(w) ~= "table" then return q(w) end
    local text = w.text or w.title or w.title_text
    text = text and tostring(text):gsub("\n", " / "):sub(1, 60) or ""
    local flags = {}
    if w.modal then flags[#flags + 1] = "modal" end
    if w.toast then flags[#flags + 1] = "toast" end
    if w.covers_fullscreen then flags[#flags + 1] = "fullscreen" end
    return string.format("%s [%s]%s", w.name or classSource(w), table.concat(flags, ","),
        text ~= "" and (" \"" .. text .. "\"") or "")
end

local function stackIndex(w)
    local stack = UIManager._window_stack or {}
    for i = #stack, 1, -1 do
        if stack[i].widget == w then return i, #stack end
    end
    return nil, #stack
end

local function isOurs(src)
    return src:find("readinginsights", 1, true) or src:find("statistics.koplugin", 1, true)
        or src:find("calendarview", 1, true)
end

-- ---- Startup snapshot ----------------------------------------------------------------------
local function snapshot()
    log("==================== ri-tweaks diagnostics %s started ====================", DIAG_VERSION)
    log("expires in %dh | shared log rotates at 2 MB",
        math.max(0, math.floor((first_load + EXPIRE_H * 3600 - os.time()) / 3600)))
    local ok_v, ver = pcall(function() return require("version"):getCurrentRevision() end)
    log("KOReader %s | device %s | screen %sx%s dpi %s", ok_v and q(ver) or "?",
        q(Device.model), q(Device.screen:getWidth()), q(Device.screen:getHeight()), q(Device.screen:getDPI()))
    log("night mode %s | touch %s | keys %s", q(G_reader_settings:isTrue("night_mode")),
        q(Device:isTouchDevice()), q(Device:hasKeys()))
    local H = package.loaded[HOOK_NAME]
    if not H then
        log("MAIN PATCH NOT LOADED (2-readinginsights-tweaks.lua missing or failed; check crash.log)")
    else
        log("Reading Insights Tweaks %s", q(H.version or "(pre-1.1.1, no version field)"))
    end
    local s = G_reader_settings:readSetting(SETTINGS_KEY)
    if type(s) == "table" then
        local parts = {}
        for k, v in pairs(s) do parts[#parts + 1] = k .. "=" .. tostring(v) end
        table.sort(parts)
        log("saved settings: %s", table.concat(parts, " "))
    else
        log("saved settings: none (all defaults)")
    end
    local dir = DataStorage:getSettingsDir()
    log("statistics.sqlite3 %s KB | bookinfo_cache.sqlite3 %s KB",
        q(math.floor((lfs.attributes(dir .. "/statistics.sqlite3", "size") or 0) / 1024)),
        q(math.floor((lfs.attributes(dir .. "/bookinfo_cache.sqlite3", "size") or 0) / 1024)))
    local disabled = G_reader_settings:readSetting("plugins_disabled") or {}
    log("plugins disabled: readinginsights=%s statistics=%s coverbrowser=%s",
        q(disabled.readinginsights == true), q(disabled.statistics == true), q(disabled.coverbrowser == true))
    log("memory | %s", memory())
end

local function logCaps(when)
    local H = package.loaded[HOOK_NAME]
    if not H or type(H.caps) ~= "table" then return end
    local want = { "book_header", "stats_calendar" }
    local parts = {}
    for _i, k in ipairs(want) do parts[#parts + 1] = k .. "=" .. (H.caps[k] and "yes" or "NO") end
    log("hooks (%s): %s", when, table.concat(parts, " "))
end

local function riVersion(plugin)
    local v = plugin and plugin.version
    if not v then
        local ok, meta = pcall(dofile, (plugin and plugin.path or "") .. "/_meta.lua")
        v = ok and type(meta) == "table" and meta.version or nil
    end
    return q(v)
end

-- ---- Main patch warnings -------------------------------------------------------------------
local orig_warn = logger.warn
logger.warn = function(...)
    if (...) == "RI tweaks:" then
        local parts = {}
        for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
        log("MAIN PATCH WARNING: %s", table.concat(parts, " "))
    end
    return orig_warn(...)
end

-- ---- Windows: show / close -----------------------------------------------------------------
local orig_show = UIManager.show
UIManager.show = function(self, w, ...)
    local info = debug.getinfo(2, "S")
    local src = info and info.source or ""
    if type(w) == "table" and isOurs(src) then touch("popup opened") end
    local r = { orig_show(self, w, ...) }
    if active() and type(w) == "table" then
        local i, n = stackIndex(w)
        local behind = ""
        if i and i < n then
            local stack = UIManager._window_stack
            for j = i + 1, n do
                local above = stack[j].widget
                if above.modal and not above.toast then
                    behind = "  <-- SHOWN BEHIND modal " .. describe(above)
                    break
                end
            end
        end
        log("show %s at stack %s/%s%s", describe(w), q(i), q(n), behind)
    end
    return unpack(r)
end

local orig_close = UIManager.close
UIManager.close = function(self, w, ...)
    if active() and type(w) == "table" then log("close %s", describe(w)) end
    return orig_close(self, w, ...)
end

-- ---- Touch: who got it, and tap-to-screen latency ------------------------------------------
local pending_input -- { t = time, what = "tap" }

local orig_send = UIManager.sendEvent
UIManager.sendEvent = function(self, ev, ...)
    if active() and type(ev) == "table" and ev.handler == "onGesture" then
        local g = ev.args and ev.args[1]
        if type(g) == "table" and (g.ges == "tap" or g.ges == "hold" or g.ges == "swipe") then
            local stack = self._window_stack or {}
            local top
            for i = #stack, 1, -1 do
                if not stack[i].widget.toast then top = stack[i].widget break end
            end
            log("%s %s at %s,%s -> received by %s", g.ges, q(g.direction or ""), q(g.pos and g.pos.x),
                q(g.pos and g.pos.y), top and describe(top) or "?")
            pending_input = { t = now(), what = g.ges }
            touch()
        end
    end
    return orig_send(self, ev, ...)
end

if type(UIManager._repaint) == "function" then
    local orig_repaint = UIManager._repaint
    UIManager._repaint = function(self, ...)
        if not active() then return orig_repaint(self, ...) end
        local t = now()
        local r = { orig_repaint(self, ...) }
        local d = ms(t)
        stats.repaints = stats.repaints + 1
        stats.repaint_ms = stats.repaint_ms + math.max(0, ms(t))
        if d > 300 then log("slow repaint %dms", d) end
        if pending_input then
            log("%s -> screen updated in %dms", pending_input.what, ms(pending_input.t))
            pending_input = nil
        end
        return unpack(r)
    end
end

if type(UIManager._refresh) == "function" then
    local orig_refresh = UIManager._refresh
    UIManager._refresh = function(self, mode, ...)
        if active() then
            local m = tostring(mode or "?")
            stats.refresh[m] = (stats.refresh[m] or 0) + 1
        end
        return orig_refresh(self, mode, ...)
    end
end

-- ---- Build timings (wraps the main patch's hook table at runtime, not its file) -----------
local function timed(label, fn)
    return function(...)
        touch(label)
        local t = now()
        local r = { pcall(fn, ...) }
        log("%s took %dms%s", label, ms(t), r[1] and "" or ("  ERROR: " .. q(r[2])))
        if not r[1] then error(r[2], 0) end
        return unpack(r, 2)
    end
end

local H = package.loaded[HOOK_NAME]
if H then
    if type(H.bookCal) == "function" then
        local w = H.bookCal
        H.bookCal = function(r, h)
            local rb, hb = w(r, h)
            return timed("book calendar build", rb), hb
        end
    end
end

-- ---- Cover scaling -------------------------------------------------------------------------
local ok_ri, RenderImage = pcall(require, "ui/renderimage")
if ok_ri and type(RenderImage) == "table" and type(RenderImage.scaleBlitBuffer) == "function" then
    local orig_scale = RenderImage.scaleBlitBuffer
    RenderImage.scaleBlitBuffer = function(...)
        if not active() then return orig_scale(...) end
        local t = now()
        local r = { orig_scale(...) }
        stats.scales = stats.scales + 1
        stats.scale_ms = stats.scale_ms + math.max(0, ms(t))
        return unpack(r)
    end
end

-- ---- Databases -----------------------------------------------------------------------------
local ok_sq, SQ3 = pcall(require, "lua-ljsqlite3/init")
local open_conns = 0
local untracked = 0 -- opened, but their close couldn't be watched
if ok_sq and type(SQ3) == "table" and type(SQ3.open) == "function" then
    local orig_open = SQ3.open
    SQ3.open = function(path, ...)
        local conn, err = orig_open(path, ...)
        if active() and type(path) == "string"
           and (path:find("statistics.sqlite3", 1, true) or path:find("bookinfo_cache", 1, true)) then
            local name = path:match("[^/]+$")
            local watched = false
            if conn then
                watched = pcall(function()
                    local orig_c, orig_e = conn.close, conn.exec
                    conn.close = function(c, ...)
                        open_conns = math.max(0, open_conns - 1)
                        if active() then log("db close %s (open now: %d)", name, open_conns) end
                        return orig_c(c, ...)
                    end
                    conn.exec = function(c, ...)
                        local t = now()
                        local r = { orig_e(c, ...) }
                        stats.queries = stats.queries + 1
                        stats.query_ms = stats.query_ms + math.max(0, ms(t))
                        return unpack(r)
                    end
                end)
            end
            if watched then
                open_conns = open_conns + 1
                log("db open %s -> ok (open now: %d)", name, open_conns)
            elseif conn then
                untracked = untracked + 1
                log("db open %s -> ok (closes can't be watched here)", name)
            else
                log("db open %s -> FAILED %s", name, q(err))
            end
        end
        return conn, err
    end
end

-- ---- Sleep / resume and plugin-level hooks -------------------------------------------------
local suspended_at

if ok_up and type(userpatch) == "table" and type(userpatch.registerPatchPluginFunc) == "function" then
    userpatch.registerPatchPluginFunc("readinginsights", function(plugin)
        if plugin._ri_diag_patched then return end
        plugin._ri_diag_patched = true
        log("Reading Insights %s loaded", riVersion(plugin))
        logCaps("Reading Insights loaded")
        if isCallable(plugin.onSuspend) then
            local orig = plugin.onSuspend
            plugin.onSuspend = function(self, ...)
                touch("suspend")
                local t = now()
                local r = { orig(self, ...) }
                log("suspend handling took %dms | Reading Insights sleep screen %s", ms(t),
                    (self._screensaver_widgets or self._screensaver_widget) and "shown" or "not shown")
                local pend = pendingTasks()
                log("timers pending at suspend: %s", #pend > 0 and table.concat(pend, ", ") or "none")
                if untracked > 0 then
                    log("db connections open at suspend: unknown (%d opened since start; their closes can't be watched here)", untracked)
                else
                    log("db connections open at suspend: %d%s", open_conns, open_conns > 0 and "  <-- LEFT OPEN" or "")
                end
                suspended_at = os.time()
                endSession("suspend")
                return unpack(r)
            end
        end
        if isCallable(plugin.onResume) then
            local orig = plugin.onResume
            plugin.onResume = function(self, ...)
                touch("resume")
                log("resume | asleep %s",
                    suspended_at and ((os.time() - suspended_at) .. "s") or "?")
                suspended_at = nil
                local t = now()
                local r = { orig(self, ...) }
                log("resume handling took %dms", ms(t))
                return unpack(r)
            end
        end
    end)
    userpatch.registerPatchPluginFunc("statistics", function()
        logCaps("Statistics loaded")
    end)
    userpatch.registerPatchPluginFunc("coverbrowser", function()
        local ok_b, BIM = pcall(require, "bookinfomanager")
        if not ok_b or type(BIM) ~= "table" or BIM._ri_diag_patched then return end
        BIM._ri_diag_patched = true
        local orig_get = BIM.getBookInfo
        if type(orig_get) == "function" then
            BIM.getBookInfo = function(self, path, get_cover, ...)
                local bi = orig_get(self, path, get_cover, ...)
                if active() and get_cover then
                    local state = not bi and "not indexed"
                        or (bi.cover_fetched ~= "Y" and "cover not fetched yet")
                        or (bi.cover_bb and "cover ok" or "book has no cover")
                    log("cover lookup %s -> %s", q(type(path) == "string" and path:match("[^/]+$") or path), state)
                end
                return bi
            end
        end
        local orig_ext = BIM.extractInBackground
        if type(orig_ext) == "function" then
            BIM.extractInBackground = function(self, files, ...)
                if active() then log("background cover extraction started for %d book(s)", #(files or {})) end
                return orig_ext(self, files, ...)
            end
        end
    end)
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

-- Reading Insights Tweaks' own file and the Reading Insights plugin. A
-- problem (slow timer, flash, timer left waiting at sleep) opens a session
-- like any other activity; "nothing left at sleep" and the perf line are
-- only written inside one.
local function perfLine(fmt, ...)
    local ok, line = pcall(string.format, fmt, ...)
    return ok and line or tostring(fmt)
end
DiagCore.client({
    name = "Reading Insights (Tweaks)",
    targets = { "2-readinginsights-tweaks.lua", "readinginsights.koplugin/" },
    on = function() return true end, -- expired: this file returned before here
    log = function(fmt, ...)
        local line = perfLine(fmt, ...)
        if line:find("^going to sleep: no ") then
            if active() then log("%s", line) end
        else
            touch("perf")
            log("%s", line)
        end
    end,
    summary = function(fmt, ...)
        if active() then log("%s", perfLine(fmt, ...)) end
    end,
    errors = false, -- the main patch's warnings are caught above
})

-- ---- Go ------------------------------------------------------------------------------------
local ok_snap, snap_err = pcall(snapshot)
if not ok_snap then log("startup snapshot incomplete: %s", q(snap_err)) end
UIManager:nextTick(function()
    logCaps("first UI tick")
    if not shared_note("Diagnostics: writing diagnostics.log (readinginsights-tweaks)") then
        pcall(function()
            require("ui/widget/notification"):notify("Diagnostics: writing diagnostics.log (readinginsights-tweaks)")
        end)
    end
end)
