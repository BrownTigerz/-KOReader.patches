--[[
2-zz-shelfsync-tweaks-diagnostics.lua - TEMPORARY troubleshooting patch
Version 1.1.0

Watches ShelfSync and ShelfSync tweaks from the outside and writes what it
sees as [shelfsync]-tagged lines to the SHARED diagnostics log
(shared log contract v1):
    koreader/diagnostics.log
(Kobo: .adds/koreader/diagnostics.log)

It changes nothing: every hook calls the real function and only writes a
line. It doesn't touch 2-shelfsync-tweaks.lua. The "zz" makes it load after
it, so it sees the tweaks' hooks too.

Changelog:
  1.1.0  Shared perf core (same block as the other diagnostics): every
         timer from ShelfSync and the tweaks is timed (slow ones logged),
         screen updates and flashes they ask for, the timers they leave
         waiting when the device sleeps, and a once-a-minute perf line with
         Lua memory and isActive() calls. The 0.25 s freeze heartbeat and
         the 60 s memory timer are gone (no-timers rule): while ShelfSync
         is busy, a timer holding the screen 250 ms+ (with its file) or a
         tap 1 s+ is logged instead.
  1.0.7  One line per entry: messages and popups with line breaks are
         joined with " / " (they used to split into untagged lines), and
         the invisible text-direction marks around file paths are removed.
  1.0.6  Shared log rotation cap raised from 256 KB to 2 MB
         (SHARED_MAX_BYTES = 2 * 1024 * 1024), per TK — all 12 diagnostics
         use the identical value.
  1.0.5  Shared log contract v1: tagged lines now go to the shared
         koreader/diagnostics.log (rotation to diagnostics.log.old at
         256 KB) instead of a per-patch log file.
  1.0.4  Spec alignment: date in every timestamp, spec-format start line,
         LOG_NAME as one plain quoted string; memSample no longer keeps its
         60 s chain alive while the device sleeps (parks and resumes on
         wake); mask() also masks token-ish URL query params (?token=,
         &api_key=).
  1.0.0-1.0.3  Earlier drafts (no changelog kept).

Switches itself off, in case it's forgotten:
  - logs for the first 10 minutes after each KOReader start (long enough to
    open a book, let autolink finish on every provider, sync, sleep and
    wake), then goes quiet: every hook passes straight through, nothing is
    written, no timers run.
  - 24 hours after it was first installed it hooks nothing at all and shows
    "ShelfSync diagnostics expired: delete …" on each start. Copying the
    file in again starts a fresh 24 hours.
  - The shared log rotates at 2 MB (older part kept as
    diagnostics.log.old).
  - Nothing runs while the device sleeps. No repeating timers: only the
    one-off 90 s book-open summary and the 2.5 min Wi-Fi watch, which stop
    when the logging window ends and never wake the device.

What it logs (date + 12-hour clock, [shelfsync] tag, +ms = time since the current test began):
  - Startup: which tweaks hooks are in place (so a ShelfSync update that
    breaks one shows up as MISSING), ShelfSync version, which providers are
    enabled / signed in / hidden.
  - Book open: per provider, active or not, already linked or not, link
    method (ID / ISBN / Title / Manual), autolink allowed, Wikipedia skip.
    Then each autolink step per provider (identifier, ISBN, title) with how
    long it took and whether it matched, and a summary 90 s after opening:
    what linked, what didn't.
  - Progress updates: per provider, start, result, reason, how long. Which
    action started it (ShelfSync All / built-in update all / page turn).
  - Wi-Fi: connecting / connected / disconnected, how long connecting took,
    and WIFI LEFT ON (!) if an update action turned Wi-Fi on and it was
    still on 2.5 minutes later.
  - Re-login and relink-on-connect from the tweaks.
  - Sleep and wake: Wi-Fi state, any sync still running when the device
    went to sleep (!), notes drawn over the sleep screen (!), pending
    timers (to spot leaks).
  - Taps, tap-through on banners/notes and touch highlights (invert) under
    a banner/note (!).
  - Performance: slow redraws (over 250 ms), how long ShelfSync menus take
    to build, and (shared perf core) every ShelfSync / tweaks timer timed,
    slow ones named; screen updates and flashes they ask for; timers they
    leave waiting at sleep; while ShelfSync is busy, any timer holding the
    screen 250 ms+ (with its file) or tap 1 s+; once a minute: timers, flashes,
    isActive() calls (hot path check) and Lua memory.
  - ShelfSync's own log lines (turn on ShelfSync > Settings > Verbose
    logging for the detailed ones). Cookie/token-looking strings are
    masked.

How to use:
  1. Put this file in koreader/patches/ next to 2-shelfsync-tweaks.lua
     and restart KOReader.
  2. Within 10 minutes: open a book you've never opened (and one that's
     already linked), wait about a minute, run ShelfSync All: Update
     progress with Wi-Fi off, open Link & Update, put the device to sleep
     and wake it.
  3. Send koreader/diagnostics.log, then delete this file and
     restart.
]]

local ACTIVE_MINUTES = 10  -- logging window after each KOReader start
local EXPIRES_HOURS = 24   -- after first install: no hooks at all

local DataStorage = require("datastorage")
local Device = require("device")
local NetworkMgr = require("ui/network/manager")
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local userpatch = require("userpatch")
local ok_time, ktime = pcall(require, "ui/time")

local VERSION = "1.1.0"
-- Shared log contract v1: all diagnostics append timestamped, tagged lines
-- to ONE file (koreader/diagnostics.log) so a full test run reads as a
-- single chronological log. Rotation at 2 MB, older part kept as
-- diagnostics.log.old.
local DIAG_TAG = "shelfsync"
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
local FILE_NAME = "2-zz-shelfsync-tweaks-diagnostics.lua"

-- --------------------------------------------------------------------------
-- Expiry
-- --------------------------------------------------------------------------

-- Keyed to this file's timestamp: copying a fresh copy in starts a new 24h.
local FIRST_KEY = "shelfsync_tweaks_diagnostics_first_run"
local me = DataStorage:getDataDir() .. "/patches/" .. FILE_NAME
local mtime = lfs.attributes(me, "modification") or 0
local stamp = G_reader_settings:readSetting(FIRST_KEY)
if type(stamp) ~= "table" or stamp.mtime ~= mtime then
    stamp = { first = os.time(), mtime = mtime }
    G_reader_settings:saveSetting(FIRST_KEY, stamp)
end
local first = stamp.first
if os.time() - first > EXPIRES_HOURS * 3600 then
    UIManager:nextTick(function()
        pcall(function()
            require("ui/widget/notification"):notify("ShelfSync diagnostics expired: delete " .. FILE_NAME)
        end)
    end)
    return -- no hooks at all
end

local stop_at = os.time() + ACTIVE_MINUTES * 60
local function on() return os.time() <= stop_at end

-- --------------------------------------------------------------------------
-- Log
-- --------------------------------------------------------------------------

local t0 -- start of the current test

local function now() return ok_time and ktime.now() or nil end

local function ms(since)
    if not (ok_time and since) then return -1 end
    local ok, v = pcall(function() return ktime.to_ms(ktime.since(since)) end)
    return ok and v or -1
end

-- Mask anything that looks like a cookie, token or password-ish blob.
local function mask(s)
    s = tostring(s)
    -- Only long values: keeps "token (code=nil)" / "cookie (length: 722)" readable
    local function long(prefix, v) if #v >= 20 then return prefix .. "<masked>" end end
    s = s:gsub("([Cc]ookie[%s:=]+)([^%s|;]+)", long)
    s = s:gsub("([Tt]oken[%s:=]+)([^%s|;]+)", long)
    -- Token-ish values inside URLs (?token= / &api_key=) pass the "/" check below.
    s = s:gsub("([?&]%w*[Tt]oken=)([^%s&;]+)", long)
    s = s:gsub("([?&]api[_%-]?[Kk]ey=)([^%s&;]+)", long)
    s = s:gsub("[%w%+/_%-%%]+%=*", function(w)
        if #w >= 40 and not w:find("^https?") and not w:find("/") then return "<masked>" end
    end)
    return s
end

local function log(fmt, ...)
    local ok, line = pcall(string.format, fmt, ...)
    if not ok then line = tostring(fmt) end
    -- Test-relative timing column stays in the line; shared_log adds date/time/tag.
    shared_log("%s", string.format("+%6dms  ", t0 and ms(t0) or 0) .. line)
end

local function q(v) return v == nil and "(nil)" or tostring(v) end
local function yn(v) return v and "yes" or "no" end

local function safe(fn, ...)
    local ok, v = pcall(fn, ...)
    if ok then return v end
    return "err"
end

local function wifiState()
    local on_ = safe(NetworkMgr.isWifiOn, NetworkMgr)
    local conn = safe(NetworkMgr.isConnected, NetworkMgr)
    return string.format("Wi-Fi %s%s", on_ == true and "on" or "off",
        on_ == true and (conn == true and " (connected)" or " (not connected)") or "")
end

local function describe(w)
    if type(w) ~= "table" then return q(w) end
    local text = w.text or w.title or w.name or ""
    text = tostring(text):gsub("\n", " "):sub(1, 70)
    local kind = w.toast and "note/banner" or (w.buttons and "dialog" or (w.name or "widget"))
    return string.format("%s \"%s\"", kind, mask(text))
end

local function topWidget()
    local st = UIManager._window_stack
    return st and st[#st] and st[#st].widget
end

local function toastArea()
    local w = topWidget()
    if not (w and w.toast) then return nil end
    return (w.frame and w.frame.dimen) or w.dimen, w
end

local function inside(pos, d)
    return pos and d and d.x and pos.x >= d.x and pos.x < d.x + d.w and pos.y >= d.y and pos.y < d.y + d.h
end

local function taskCount()
    local tq = UIManager._task_queue
    return type(tq) == "table" and #tq or -1
end

local function startTest(what)
    t0 = now()
    log("==================== %s ====================", what)
end

-- --------------------------------------------------------------------------
-- Freeze detector + memory sample (only while logging is on and awake)
-- --------------------------------------------------------------------------

-- While ShelfSync is busy (a sync, autolink), a timer holding the screen
-- 250 ms+ or a tap 1 s+ is logged by the shared perf core (end of this
-- file), with its file. No heartbeat timer.
local busy_until = 0
local function busy(seconds)
    busy_until = math.max(busy_until, os.time() + (seconds or 20))
end

-- isActive() calls are counted and reported in the once-a-minute perf line
-- (shared perf core, end of this file), with Lua memory. No minute timer.
local is_active_calls = 0

log("==================== shelfsync-tweaks diagnostics %s started ====================", VERSION)
log("logging for %d min (until %s) | expires %s | log: %s",
    ACTIVE_MINUTES, os.date("%I:%M %p", stop_at),
    os.date("%b %d %I:%M %p", first + EXPIRES_HOURS * 3600), "diagnostics.log")
log("device %s | %s", q(Device.model), wifiState())

-- --------------------------------------------------------------------------
-- ShelfSync's own log lines (and the tweaks' warnings)
-- --------------------------------------------------------------------------

local LABELS = { "StoryGraph", "Goodreads", "Hardcover", "Fable", "Pagebound", "ShelfSync" }
local function relevant(s)
    for _i, l in ipairs(LABELS) do if s:find(l, 1, true) then return true end end
    return false
end
for _i, level in ipairs({ "info", "warn", "err" }) do
    local orig = logger[level]
    if type(orig) == "function" then
        logger[level] = function(...)
            if on() then
                local parts = {}
                for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
                local s = table.concat(parts, " ")
                if relevant(s) then
                    log("[%s] %s", level:upper(), mask(s):sub(1, 400))
                end
            end
            return orig(...)
        end
    end
end

-- --------------------------------------------------------------------------
-- Wi-Fi and sleep / wake
-- --------------------------------------------------------------------------

local connect_started
local inflight = {}       -- [label] = start time of a progress update in progress
local wifi_watch           -- { at, turned_on } set by update actions

local orig_bc = UIManager.broadcastEvent
UIManager.broadcastEvent = function(self, ev, ...)
    local h = on() and type(ev) == "table" and ev.handler
    if h == "onNetworkConnecting" then
        connect_started = now()
        log("event: Wi-Fi connecting")
    elseif h == "onNetworkConnected" then
        log("event: Wi-Fi connected%s", connect_started and string.format(" (took %dms)", ms(connect_started)) or "")
        connect_started = nil
    elseif h == "onNetworkDisconnected" then
        log("event: Wi-Fi disconnected")
    elseif h == "onSuspend" then
        startTest("going to sleep")
        local running = {}
        for l in pairs(inflight) do running[#running + 1] = l end
        log("before sleep | %s | timers queued %d%s", wifiState(), taskCount(),
            #running > 0 and (" | SYNC STILL RUNNING: " .. table.concat(running, ", ") .. " (!)") or "")
        local t = now()
        local r = orig_bc(self, ev, ...)
        log("sleep handled in %dms | %s", ms(t), wifiState())
        return r
    elseif h == "onResume" then
        startTest("woke up")
        local r = orig_bc(self, ev, ...)
        log("wake handled | %s | timers queued %d", wifiState(), taskCount())
        return r
    end
    return orig_bc(self, ev, ...)
end

local function watchWifiAfterAction(name)
    local was_on = safe(NetworkMgr.isWifiOn, NetworkMgr) == true
    wifi_watch = { at = os.time(), was_on = was_on }
    local this = wifi_watch
    UIManager:scheduleIn(150, function()
        if wifi_watch ~= this or not on() then return end
        if not this.was_on and safe(NetworkMgr.isWifiOn, NetworkMgr) == true then
            log("WIFI LEFT ON (!) 2.5 min after %s turned it on", name)
        else
            log("Wi-Fi check 2.5 min after %s: ok (%s)", name, wifiState())
        end
    end)
end

-- --------------------------------------------------------------------------
-- Screen: notes, popups, taps, tap-through, highlights, slow redraws
-- --------------------------------------------------------------------------

local orig_show = UIManager.show
UIManager.show = function(self, w, ...)
    if on() and type(w) == "table" and (w.text or w.title) then
        local d = describe(w)
        if relevant(d) or d:find("[Pp]rogress") or d:find("[Ss]ync") or d:find("[Ll]og") or d:find("Wi%-Fi") then
            log("show %s%s", d, Device.screen_saver_mode and "  <-- OVER THE SLEEP SCREEN (!)" or "")
        end
    end
    return orig_show(self, w, ...)
end

local last_tap = { at = 0 }
local orig_send = UIManager.sendEvent
UIManager.sendEvent = function(self, ev, ...)
    if on() and type(ev) == "table" and ev.handler == "onGesture" then
        local g = ev.args and ev.args[1]
        if type(g) == "table" and (g.ges == "tap" or g.ges == "hold") then
            local area, toast = toastArea()
            local on_toast = inside(g.pos, area)
            last_tap = { at = os.time(), on_toast = on_toast, toast = toast }
            if on_toast then
                log("%s on %s at %s,%s", g.ges, describe(toast), q(g.pos and g.pos.x), q(g.pos and g.pos.y))
            end
            busy()
        end
    end
    return orig_send(self, ev, ...)
end

local function leakCheck(kind, label)
    if on() and last_tap.on_toast and os.time() - last_tap.at <= 1 then
        log("TAP WENT THROUGH %s to %s \"%s\" underneath (!)", describe(last_tap.toast), kind, q(label))
    end
end
local ok_b, Button = pcall(require, "ui/widget/button")
if ok_b and type(Button) == "table" and Button.onTapSelectButton then
    local orig = Button.onTapSelectButton
    Button.onTapSelectButton = function(self, ...)
        leakCheck("button", self.text or self.icon)
        return orig(self, ...)
    end
end

local orig_invert = UIManager.widgetInvert
if type(orig_invert) == "function" then
    UIManager.widgetInvert = function(self, w, x, y, wd, ht, ...)
        if on() then
            local area, toast = toastArea()
            local d = { x = x or (w and w.dimen and w.dimen.x), y = y or (w and w.dimen and w.dimen.y) }
            if area and inside(d, area) and w ~= toast then
                log("TOUCH HIGHLIGHT under %s (a tap reached the screen behind it) (!)", describe(toast))
            end
        end
        return orig_invert(self, w, x, y, wd, ht, ...)
    end
end

local orig_repaint = UIManager._repaint
if type(orig_repaint) == "function" then
    UIManager._repaint = function(self, ...)
        if not on() or os.time() > busy_until then return orig_repaint(self, ...) end
        local t = now()
        local r = orig_repaint(self, ...)
        local d = ms(t)
        if d > 250 then log("slow redraw: %dms (on top: %s)", d, describe(topWidget())) end
        return r
    end
end

-- --------------------------------------------------------------------------
-- ShelfSync internals (hooked once, after 2-shelfsync-tweaks.lua)
-- --------------------------------------------------------------------------

local function timed(tbl, name, label_of, fmt_result)
    local orig = tbl and tbl[name]
    if type(orig) ~= "function" then
        log("hook point %s MISSING (ShelfSync changed?)", name)
        return
    end
    tbl[name] = function(self, ...)
        if not on() then return orig(self, ...) end
        local t = now()
        local r = { pcall(orig, self, ...) }
        local lbl = label_of and safe(label_of, self) or "?"
        if r[1] then
            log("%s: %s -> %s (%dms)", q(lbl), name, fmt_result and fmt_result(r) or q(r[2]), ms(t))
            busy()
            return unpack(r, 2)
        end
        log("%s: %s THREW: %s (!)", q(lbl), name, mask(q(r[2])))
        error(r[2], 0)
    end
end

local hooked = false
local function hookShelfSync(plugin)
    if hooked then return end
    hooked = true

    local ok_se, SyncEngine = pcall(require, "shelfsync/lib/common/sync_engine")
    local ok_bp, BaseProvider = pcall(require, "shelfsync/lib/common/base_provider")
    local ok_pv, PROVIDERS = pcall(require, "shelfsync/lib/common/constants/providers")
    local ok_meta, meta = pcall(dofile, (plugin and plugin.path or "plugins/shelfsync.koplugin") .. "/_meta.lua")

    -- Which tweaks hooks are in place
    local checks = {
        { "SyncEngine hide/progress/relink hooks", ok_se and SyncEngine.__ss_hide_patched },
        { "Settings toggles (CommonMenu)", (function()
            local ok, m = pcall(require, "shelfsync/lib/common/menu"); return ok and m.__ss_tweaks_patched end)() },
        { "Goodreads login menu", (function()
            local ok, m = pcall(require, "shelfsync/lib/goodreads/menu"); return ok and m.__ss_login_patched end)() },
        { "StoryGraph saved login", (function()
            local ok, m = pcall(require, "shelfsync/lib/storygraph/menu"); return ok and m.__ss_login_patched end)() },
        { "Goodreads WAF workaround", (function()
            local ok, m = pcall(require, "shelfsync/lib/goodreads/api"); return ok and m.__ss_waf_patched end)() },
        { "Hardcover token dialog", (function()
            local ok, m = pcall(require, "shelfsync/lib/hardcover/menu"); return ok and m.__ss_token_patched end)() },
        { "Auto re-login (Goodreads)", (function()
            local ok, m = pcall(require, "shelfsync/lib/goodreads/api"); return ok and m.__ss_relogin_patched end)() },
        { "Auto re-login (StoryGraph)", (function()
            local ok, m = pcall(require, "shelfsync/lib/storygraph/api"); return ok and m.__ss_relogin_patched end)() },
        { "Link & Update hub", plugin and plugin.__ss_hub_patched },
    }
    log("ShelfSync %s | tweaks hooks:", ok_meta and type(meta) == "table" and q(meta.version) or "?")
    for _i, c in ipairs(checks) do
        log("   %-34s %s", c[1], c[2] and "ok" or "MISSING (!)")
    end
    local tw = DataStorage:getSettingsDir() .. "/shelfsync_tweaks.lua"
    local ok_ls, LuaSettings = pcall(require, "luasettings")
    if ok_ls then
        local d = LuaSettings:open(tw).data or {}
        local parts = {}
        for k, v in pairs(d) do parts[#parts + 1] = k .. "=" .. tostring(v) end
        table.sort(parts)
        log("tweaks toggles: %s", #parts > 0 and table.concat(parts, " ") or "(all defaults)")
    end

    if ok_se and SyncEngine then
        local orig_isActive = SyncEngine.isActive
        SyncEngine.isActive = function(self, ...)
            if on() then is_active_calls = is_active_calls + 1 end
            return orig_isActive(self, ...)
        end

        -- Book open snapshot per provider
        local last_open_ui
        local orig_ready = SyncEngine.onReaderReady
        if type(orig_ready) == "function" then
            SyncEngine.onReaderReady = function(self, ...)
                if on() then
                    local file = self.ui and self.ui.document and self.ui.document.file
                    -- One header per opened book (first provider to report it)
                    if self.ui ~= last_open_ui then
                        last_open_ui = self.ui
                        startTest("book opened: " .. q(file and file:match("[^/]+$")))
                        log("%s | timers queued %d", wifiState(), taskCount())
                        busy(30)
                    end
                    local active = safe(self.isActive, self)
                    local linked = safe(self.settings.bookLinked, self.settings)
                    local method = file and safe(self.settings.readBookSetting, self.settings, file, "link_method")
                    local wiki = self.isWikipediaDocument and safe(self.isWikipediaDocument, self)
                    log("%-10s active=%s linked=%s method=%s autolink=%s wikipedia=%s",
                        q(self.label), yn(active == true), yn(linked == true), q(method),
                        yn(safe(self.settings.autolinkEnabled, self.settings) == true), yn(wiki == true))
                    -- Summary once autolink has had time to finish
                    local engine = self
                    UIManager:scheduleIn(90, function()
                        if not on() or Device.screen_saver_mode then return end
                        if not (engine.ui and engine.ui.document and engine.ui.document.file == file) then return end
                        local a = safe(engine.isActive, engine) == true
                        if not a then return end
                        local l = safe(engine.settings.bookLinked, engine.settings) == true
                        local title = l and safe(engine.settings.getLinkedTitle, engine.settings)
                        local m = safe(engine.settings.readBookSetting, engine.settings, file, "link_method")
                        log("SUMMARY %-10s %s", q(engine.label),
                            l and string.format("LINKED (%s): %s", q(m), mask(q(title))) or "NOT LINKED (!)")
                    end)
                end
                local t = now()
                local r = { orig_ready(self, ...) }
                if on() then log("%s: onReaderReady done (%dms)", q(self.label), ms(t)) end
                return unpack(r)
            end
        end

        -- Progress updates
        local orig_up = SyncEngine.onUpdateProgress
        SyncEngine.onUpdateProgress = function(self, cb, ...)
            if not on() then return orig_up(self, cb, ...) end
            local label = q(self.label)
            local t = now()
            inflight[label] = t
            log("%s: progress update started | %s", label, wifiState())
            busy(60)
            local reported = false
            local wrapped = function(result, reason, ...)
                if not reported then
                    reported = true
                    inflight[label] = nil
                    log("%s: progress update %s%s (%dms)", label, result and "OK" or "FAILED",
                        reason and (" -- " .. mask(q(reason))) or "", ms(t))
                end
                if cb then return cb(result, reason, ...) end
            end
            local ok, err = pcall(orig_up, self, wrapped, ...)
            if not ok then
                inflight[label] = nil
                log("%s: progress update THREW: %s (!)", label, mask(q(err)))
                error(err, 0)
            end
            if not cb then
                -- No callback from the caller (page-turn sync): can't see the result here
                UIManager:scheduleIn(60, function()
                    if inflight[label] == t then inflight[label] = nil end
                end)
            end
        end

        local orig_conn = SyncEngine.onNetworkConnected
        SyncEngine.onNetworkConnected = function(self, ...)
            if on() then
                log("%s: onNetworkConnected (startup work already ran: %s, linked: %s)", q(self.label),
                    yn(self.state and self.state.read_cache_started), yn(safe(self.settings.bookLinked, self.settings) == true))
            end
            return orig_conn(self, ...)
        end

        timed(SyncEngine, "startReadCache", function(s) return s.label end, function() return "started" end)
        timed(SyncEngine, "flushPendingUpdates", function(s) return s.label end, function() return "ran" end)
        for _i, n in ipairs({ "onSuspend", "onResume" }) do
            if type(SyncEngine[n]) == "function" then
                timed(SyncEngine, n, function(s) return s.label end, function() return "done" end)
            end
        end
    else
        log("SyncEngine not found (!)")
    end

    if ok_bp and BaseProvider then
        local function linked(r) return "linked=" .. q(r[2]) end
        local orig_try = BaseProvider.tryAutolink
        BaseProvider.tryAutolink = function(self, done, ...)
            if not on() then return orig_try(self, done, ...) end
            local t = now()
            local label = q(self.label)
            log("%s: autolink starting | %s", label, wifiState())
            busy(60)
            return orig_try(self, function(...)
                local l = self.settings and safe(self.settings.bookLinked, self.settings) == true
                log("%s: autolink finished -> %s (%dms)", label, l and "LINKED" or "not linked", ms(t))
                if done then return done(...) end
            end, ...)
        end
        timed(BaseProvider, "linkBookByIdentifier", function(s) return s.label end, linked)
        timed(BaseProvider, "linkBookByIsbn", function(s) return s.label end, linked)
        timed(BaseProvider, "linkBookByTitle", function(s) return s.label end, linked)
    end

    -- Menu build times (performance)
    local function timeMenu(path, name)
        local ok, M = pcall(require, path)
        if ok and type(M) == "table" and type(M[name]) == "function" then
            local orig = M[name]
            M[name] = function(self, ...)
                if not on() then return orig(self, ...) end
                local t = now()
                local r = { orig(self, ...) }
                local d = ms(t)
                if d > 50 then log("menu %s.%s built in %dms%s", path:match("[^/]+/[^/]+$"), name, d,
                    d > 300 and " (slow)" or "") end
                return unpack(r)
            end
        end
    end
    timeMenu("shelfsync/lib/common/menu", "getSubMenuItems")
    for _i, p in ipairs({ "goodreads", "storygraph", "hardcover" }) do
        timeMenu("shelfsync/lib/" .. p .. "/menu", "getSubMenuItems")
        timeMenu("shelfsync/lib/" .. p .. "/menu", "getAuthSubMenuItems")
    end

    -- Re-login visibility
    for _i, p in ipairs({ "goodreads", "storygraph" }) do
        local ok, Api = pcall(require, "shelfsync/lib/" .. p .. "/api")
        if ok and type(Api) == "table" and type(Api.notifyAuthFailure) == "function" then
            local orig = Api.notifyAuthFailure
            Api.notifyAuthFailure = function(self, ...)
                if on() then log("%s: SESSION EXPIRED (auth failure) | %s", p, wifiState()) end
                return orig(self, ...)
            end
        end
    end

    if not ok_pv then log("providers list not found (!)") end
end

-- Action entry points (patched per plugin instance, so done every re-init)
local function hookPlugin(plugin)
    if type(plugin) ~= "table" or plugin.__ss_diag then return end
    plugin.__ss_diag = true
    for _i, name in ipairs({ "onShelfSyncAllUpdateProgress", "onShelfSyncUpdateAllProgress",
            "onShelfSyncHub", "onShelfSyncHubLink", "onShelfSyncHubStatus" }) do
        local orig = plugin[name]
        if type(orig) == "function" then
            plugin[name] = function(self, ...)
                if on() then
                    startTest("action: " .. name:sub(3))
                    log("%s | timers queued %d", wifiState(), taskCount())
                    busy(90)
                    if name:find("Progress") then watchWifiAfterAction(name:sub(3)) end
                end
                return orig(self, ...)
            end
        end
    end
    if on() and type(plugin.engines) == "table" then
        local parts = {}
        for key, e in pairs(plugin.engines) do
            parts[#parts + 1] = string.format("%s=%s", key, safe(e.isActive, e) == true and "active" or "off")
        end
        table.sort(parts)
        log("ShelfSync instance created | providers: %s", table.concat(parts, " "))
    end
end

userpatch.registerPatchPluginFunc("shelfsync", function(plugin)
    local ok, err = pcall(function()
        hookShelfSync(plugin)
        hookPlugin(plugin)
    end)
    if not ok then log("diagnostics hook error: %s", q(err)) end
end)

-- One notice so you know it's on.
UIManager:nextTick(function()
    pcall(function()
        require("ui/widget/notification"):notify(string.format(
            "ShelfSync diagnostics: logging until %s", os.date("%I:%M %p", stop_at)))
    end)
end)

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
                o.log("perf (last %d s): %s timers ran %d times, %d ms in all, slowest %d ms%s | screen updates asked %d, flashes %d | Lua memory %.1f MB%s",
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

-- ShelfSync's own files and the tweaks patch
DiagCore.client({
    name = "ShelfSync",
    targets = { "2-shelfsync-tweaks.lua", "shelfsync.koplugin/" },
    log = log,
    on = on,
    errors = false, -- ShelfSync's own log lines are caught above
    busy = function() return os.time() <= busy_until end,
    extra = function()
        local n = is_active_calls
        is_active_calls = 0
        return "isActive() calls " .. n
    end,
})
