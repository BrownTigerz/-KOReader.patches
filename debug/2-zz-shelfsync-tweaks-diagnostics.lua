--[[
2-zz-shelfsync-tweaks-diagnostics.lua - TEMPORARY troubleshooting patch
Version 1.0.6

Watches ShelfSync and ShelfSync tweaks from the outside and writes what it
sees as [shelfsync]-tagged lines to the SHARED diagnostics log
(shared log contract v1):
    koreader/diagnostics.log
(Kobo: .adds/koreader/diagnostics.log)

It changes nothing: every hook calls the real function and only writes a
line. It doesn't touch 2-shelfsync-tweaks.lua. The "zz" makes it load after
it, so it sees the tweaks' hooks too.

Changelog:
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
  - Nothing runs while the device sleeps; the once-a-minute memory sample
    and the freeze check only run while logging is on and awake.
  - Timers are bounded and self-terminating only: the freeze check (0.25 s
    while busy), the memory sample (60 s), the 90 s book-open summary and
    the 2.5 min Wi-Fi watch. All stop when the logging window ends, none
    run while asleep, none wake the device.

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
  - Performance: slow redraws (over 250 ms), SCREEN FROZEN when nothing
    could be tapped for a while, how long ShelfSync menus take to build,
    how often isActive() runs (hot path check), Lua memory once a minute.
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

local VERSION = "1.0.6"
-- Shared log contract v1: all diagnostics append timestamped, tagged lines
-- to ONE file (koreader/diagnostics.log) so a full test run reads as a
-- single chronological log. Rotation at 2 MB, older part kept as
-- diagnostics.log.old.
local DIAG_TAG = "shelfsync"
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

local busy_until = 0
local beat_last
local function beat()
    if not on() or os.time() > busy_until or Device.screen_saver_mode then
        beat_last = nil
        return
    end
    local gap = beat_last and ms(beat_last) or 0
    if gap > 750 then log("SCREEN FROZEN for ~%dms (nothing could be tapped)", gap - 250) end
    beat_last = now()
    UIManager:scheduleIn(0.25, beat)
end

local function busy(seconds)
    local was = os.time() <= busy_until
    busy_until = math.max(busy_until, os.time() + (seconds or 20))
    if not was then
        beat_last = now()
        UIManager:unschedule(beat)
        UIManager:scheduleIn(0.25, beat)
    end
end

local is_active_calls = 0
local mem_base
local mem_due = false -- a sample was skipped while asleep; take it on wake
local function memSample()
    if not on() then mem_due = false; return end
    if Device.screen_saver_mode then
        mem_due = true -- park: no timer chain while asleep, onResume restarts it
        return
    end
    mem_due = false
    collectgarbage("step", 0)
    local kb = collectgarbage("count")
    mem_base = mem_base or kb
    log("memory %.0f KB (%+.0f KB since start) | timers queued %d | isActive() calls last min %d",
        kb, kb - mem_base, taskCount(), is_active_calls)
    is_active_calls = 0
    UIManager:scheduleIn(60, memSample)
end

log("==================== shelfsync-tweaks diagnostics %s started ====================", VERSION)
log("logging for %d min (until %s) | expires %s | log: %s",
    ACTIVE_MINUTES, os.date("%I:%M %p", stop_at),
    os.date("%b %d %I:%M %p", first + EXPIRES_HOURS * 3600), "diagnostics.log")
log("device %s | %s", q(Device.model), wifiState())
UIManager:scheduleIn(60, memSample)

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
        if mem_due and on() then
            mem_due = false
            UIManager:scheduleIn(60, memSample) -- restart the parked memory sample
        end
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
