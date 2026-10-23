--[[
2-zz-shortcutstoolbar-diagnostics.lua - TEMPORARY troubleshooting patch
Version 1.1.0

Changelog:
  1.1.0  - Shared perf core (the same block as the other diagnostics):
           Shortcuts Toolbar and Icon Tweaks timers that hold the screen
           80 ms+, flashes they ask for, timers left waiting at sleep, and
           a once-a-minute perf line, inside the 5-minute window. The
           24 hours now start per version (the state file keeps the
           version), so an update isn't already expired when it arrives.
  1.0.11 - One line per entry: messages and popups with line breaks are
           joined with " / " (they used to split into untagged lines), and
           the invisible text-direction marks around file paths are
           removed.
  1.0.10 - Bluetooth lookup check: logs where icon tweaks found the Kobo
           plugin's Bluetooth (or that it didn't), plus what's actually
           there: plugin entries named like "kobo", whether they carry the
           Bluetooth part, and the plugin's loaded Bluetooth modules.
  1.0.9 - Fix: a menu toggle reading "off" was logged as "unknown".
          Also times icon tweaks 1.14.1's Follow Bluetooth reads, and logs
          when a library Menu Action shortcut opens a second copy of the
          menu (the stuck-menu bug 1.14.1 fixes).
  1.0.8 - Times icon tweaks 1.14.0's Follow Menu Toggle: each read of a
          menu item's ✓ (e.g. Kobo plugin Bluetooth, which runs a D-Bus
          query), its result, and how many reads per toolbar build.
  1.0.7 - Watches icon tweaks 1.13.0's close-on-sleep: which top menus
          were open when the sleep screen was set up, how long closing
          them took, and flags any still open at sleep or on wake.
  1.0.6 - Shared-log rotation cap raised from 256 KB to 2 MB
          (SHARED_MAX_BYTES = 2 * 1024 * 1024, identical across all
          diagnostics per the shared-log contract).
  1.0.5 - Shared log contract v1: lines now go to the shared
          koreader/diagnostics.log with a [shortcutstoolbar] tag and
          2 MB rotation (older part kept as diagnostics.log.old).
          The +Nms timing column stays on the line content. The expiry
          stamp moved to shortcutstoolbar-diagnostics.state.
  1.0.4 - Shared notification contract v1: the "done" note now routes
          through shared_note() (Network Tweaks banner style, then
          ReadMastery notify style, then the stock Notification widget),
          never over the sleep screen.
  1.0.3 - Restored the SSH/Calibre event names dropped in 1.0.2: they ARE
          real KOReader broadcast handlers (SSH.koplugin implements
          onToggleSSHServer; calibre.koplugin implements
          onStartWirelessConnection / onCloseWirelessConnection), and the
          icon patch itself broadcasts them for toggle shortcuts. The
          1.0.2 removal was based on a frontend/-only grep that missed
          plugins/ -- corrected.
  1.0.2 - No timers of its own: the 5-minute window now closes on elapsed
          time checked at every hooked call (per the "No timers" spec).
          Dated log timestamps. Night-mode reading falls back the same
          way the icon patch does. Expiry stamp rides in the start banner.
          "Expired" line written once per start after expiry. Dropped the
          dead SSH/Calibre event names (not real KOReader events).
  1.0.1 - First version.

Watches 2-shortcutstoolbar-icon-tweaks.lua from the outside and writes
tagged lines ([shortcutstoolbar]) to the shared diagnostics log
(shared log contract v1):
    koreader/diagnostics.log
(Kobo: .adds/koreader/diagnostics.log)

It changes nothing in the icon patch or the toolbar. It records:
  • Toolbar builds: how long each took, memory before/after.
  • Redraws the icon patch asks for: which screen, and flags any aimed at
    a screen that isn't showing (wasted e-ink refresh = battery).
  • Timers the icon patch schedules, and any still pending at sleep.
  • Anything the icon patch does while the device is asleep (should be
    nothing) or right after wake.
  • Tap highlights on toolbar icons: flags an icon with no size info
    (the 1.5.4 crash) before KOReader trips over it.
  • Indicator icon paints: count and time.
  • Network / SSH / Calibre events and night mode toggles, so redraws can
    be matched to what caused them. (SSH/Calibre toggles are broadcast by
    the icon patch itself for system toggle shortcuts; the SSH and
    Calibre plugins implement the handlers.)
  • Icon patch warnings (button order mismatch) and Lua memory.
  • Menu Toggle / Bluetooth indicators (icon tweaks 1.14.0+): every read,
    what it returned and how long it took (flags > 50 ms).
  • Where the Follow Bluetooth indicator finds the Kobo plugin (once,
    when logging starts).
  • Library top menu opened again while it's already open (a second,
    unclosable copy: the bug icon tweaks 1.14.1 fixes).
  • Close-on-sleep (icon tweaks 1.13.0+): the top menus open when the sleep
    screen is set up, how long closing them took, and any menu still open
    at sleep or on wake (should be none).

Battery safety (in case you forget to delete it):
  • Logs for 5 minutes, starting the first time you open a toolbar after
    KOReader starts. Then it writes a summary and goes quiet until the
    next restart. One window per restart.
  • Stops for good 24 hours after it first runs: after that it loads,
    sees it's expired and does nothing else. The start time is kept in
    its own state file (shortcutstoolbar-diagnostics.state), so nothing
    is saved in KOReader's settings. Delete the state file (and the
    patch) for a fresh 24 hours.
  • No background polling and no timers of its own: the 5-minute window
    closes on elapsed time, checked at every hooked call. Nothing wakes
    the device. Lines go to the shared diagnostics.log (2 MB rotation,
    older part kept as diagnostics.log.old).

How to use:
  1. Put this file in koreader/patches/ next to the icon tweaks patch and
     restart KOReader.
  2. Open a toolbar, then within 5 minutes do whatever you want checked:
     tap/hold icons, toggle SSH, Wi-Fi, Calibre, night mode, close the
     menu, read a few pages, sleep and wake.
     Menu Toggle / Bluetooth icons: open the toolbar a few times and tap
     the icon from the library's top menu. The Bluetooth lookup is logged
     on the first toolbar open.
     Close-on-sleep: open the toolbar (reader, then library) and put the
     device to sleep with it open.
  3. Send diagnostics.log (filter the [shortcutstoolbar] lines).
  4. Delete this file and restart.
The "zz" makes it load after the icon tweaks patch.
]]

local DataStorage = require("datastorage")
local Device = require("device")
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local userpatch = require("userpatch")
local ok_time, ktime = pcall(require, "ui/time")

local DIAG_VERSION = "1.1.0"
local STATE = DataStorage:getDataDir() .. "/shortcutstoolbar-diagnostics.state"

-- Shared log contract v1: all diagnostics append timestamped, tagged lines
-- to ONE file (koreader/diagnostics.log) so a full test run reads as a
-- single chronological log. Rotation at 2 MB, older part kept as
-- diagnostics.log.old.
local DIAG_TAG = "shortcutstoolbar"
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
local WINDOW_S = 5 * 60
local EXPIRE_S = 24 * 60 * 60
local MAIN_TAG = "shortcutstoolbar-icon-tweaks"

-- --------------------------------------------------------------------------
-- Log, clock, expiry
-- --------------------------------------------------------------------------

local function now() return ok_time and ktime.now() or nil end
local function ms(since)
    if not (ok_time and since) then return -1 end
    local ok, v = pcall(function() return ktime.to_ms(ktime.since(since)) end)
    return ok and v or -1
end

local window_start      -- ktime when the 5-minute window opened
local window_start_s    -- os.time fallback when ui/time is unavailable
local window_open = false
local window_done = false

local function log(fmt, ...)
    -- shared_log adds the date, 12-hour time and [shortcutstoolbar] tag;
    -- the +Nms offset (time since the logging window opened) stays on the
    -- line content as before.
    local ok, line = pcall(string.format, fmt, ...)
    if not ok then line = tostring(fmt) end
    shared_log("%s", string.format("+%7dms  ", window_start and ms(window_start) or 0) .. line)
end

local function q(v) return v == nil and "(nil)" or tostring(v) end

-- --------------------------------------------------------------------------
-- Shared notification contract v1
-- --------------------------------------------------------------------------
-- User-facing status notes use one style, resolved in priority order at
-- call time (so patch load order doesn't matter): Network Tweaks' banner
-- style, then ReadMastery notify's style, then this patch's own default.
local function shared_note(banner_text, minimal_text, timeout)
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

-- Expiry is counted from the first time this patch ran, stored as a stamp
-- in its own state file (the log is shared now, so the stamp can't ride in
-- the log's first line). (Not the file's date: copying a file usually
-- keeps the date it was made, which expired it before it ever ran.)
-- The stamp also rides inside the per-start banner line, as before.
local function readStamp()
    local f = io.open(STATE, "r")
    if not f then return nil end
    local line = f:read("*l")
    f:close()
    -- "<version> started <time>": another version (or an older stamp without
    -- one) starts a new 24 hours
    local v, t = (line or ""):match("^(%S+) started (%d+)")
    if v ~= DIAG_VERSION then return nil end
    return tonumber(t)
end

local started = readStamp()
if not started then
    started = os.time()
    local f = io.open(STATE, "w")
    if f then
        f:write(DIAG_VERSION .. " started " .. started .. "\n")
        f:close()
    end
    shared_log("==================== shortcutstoolbar diagnostics %s started ====================  [# started %d]", DIAG_VERSION, started)
end
if os.difftime(os.time(), started) > EXPIRE_S then
    -- One line per start, then return without hooking anything.
    shared_log("expired (first ran more than 24h ago): doing nothing. Delete this patch.")
    logger.info("shortcutstoolbar diagnostics: expired, inactive")
    return
end

-- No timers of its own: the window closes on elapsed time, checked every
-- time active() is consulted (every hooked call already asks).
local closeWindow -- forward declaration; assigned below
local function elapsedMs()
    if ok_time and window_start then return ms(window_start) end
    if window_start_s then return (os.time() - window_start_s) * 1000 end
    return -1
end

local function active()
    if window_open and elapsedMs() >= WINDOW_S * 1000 then
        closeWindow()
    end
    return window_open
end

-- --------------------------------------------------------------------------
-- Counters (summarised at window end and at sleep)
-- --------------------------------------------------------------------------

local stats = {
    builds = 0, build_ms = 0,
    dirty = 0, dirty_hidden = 0, dirty_asleep = 0,
    timers = 0, timers_asleep = 0,
    paints = 0, paint_ms = 0,
    warnings = 0, invert_bad = 0,
    menu_dupes = 0, menu_reads = 0, menu_read_ms = 0, menu_read_max = 0, menu_unknown = 0,
    sleeps = 0, menus_closed = 0, menus_left = 0, menus_on_wake = 0, close_ms = 0,
}

-- Open TouchMenus (reader / library top menus) in the window stack.
local function openMenus()
    local ok, TouchMenu = pcall(require, "ui/widget/touchmenu")
    local stack = UIManager._window_stack
    local list = {}
    if not ok or type(stack) ~= "table" then return list end
    for i = 1, #stack do
        local w = stack[i].widget
        local inner = type(w) == "table" and w[1]
        if type(inner) == "table" and inner.closeMenu ~= nil and inner.closeMenu == TouchMenu.closeMenu then
            local where = "menu"
            local okR, ReaderUI = pcall(require, "apps/reader/readerui")
            if okR and ReaderUI.instance and ReaderUI.instance.menu
                    and ReaderUI.instance.menu.menu_container == w then
                where = "reader menu"
            else
                local FM = package.loaded["apps/filemanager/filemanager"]
                if type(FM) == "table" and FM.instance and FM.instance.menu
                        and FM.instance.menu.menu_container == w then
                    where = "library menu"
                end
            end
            list[#list + 1] = where
        end
    end
    return list
end

local function mem() return collectgarbage("count") end

-- Was the caller (n levels up) code from the icon tweaks patch?
local function fromMain(level)
    local info = debug.getinfo(level + 1, "S")
    return info and info.source and info.source:find(MAIN_TAG, 1, true) ~= nil
end

local function srcOf(fn)
    local info = type(fn) == "function" and debug.getinfo(fn, "S")
    return info and info.source or ""
end

-- Topmost real screen (skips notes/banners), for "is that screen showing?".
local function screenWindow()
    local stack = UIManager._window_stack
    if type(stack) ~= "table" then return nil end
    for i = #stack, 1, -1 do
        local w = stack[i].widget
        if w and not w.invisible and not w.toast then return w end
    end
end

local function name(w)
    if type(w) ~= "table" then return q(w) end
    return w.name or w.title or (w.text and tostring(w.text):sub(1, 40)) or (tostring(w):gsub("table: ", "#"))
end

local function pendingMainTasks()
    local n, list = 0, {}
    for _i, t in ipairs(UIManager._task_queue or {}) do
        if srcOf(t.action):find(MAIN_TAG, 1, true) then
            n = n + 1
            if #list < 5 then
                local info = debug.getinfo(t.action, "S")
                table.insert(list, "line " .. q(info and info.linedefined))
            end
        end
    end
    return n, table.concat(list, ", ")
end

local function summary(why)
    local n, where = pendingMainTasks()
    log("---- summary (%s) ----", why)
    log("toolbar builds: %d, avg %dms", stats.builds, stats.builds > 0 and math.floor(stats.build_ms / stats.builds) or 0)
    log("redraws asked by icon patch: %d | at hidden screen: %d | while asleep: %d",
        stats.dirty, stats.dirty_hidden, stats.dirty_asleep)
    log("timers scheduled by icon patch: %d | while asleep: %d | pending now: %d%s",
        stats.timers, stats.timers_asleep, n, n > 0 and (" (" .. where .. ")") or "")
    log("indicator icon paints: %d, total %dms", stats.paints, stats.paint_ms)
    log("menu toggle / bluetooth reads: %d, total %dms, slowest %dms | unknown (not found / no plugin): %d",
        stats.menu_reads, stats.menu_read_ms, stats.menu_read_max, stats.menu_unknown)
    log("library menu opened twice (stuck menu): %d", stats.menu_dupes)
    log("tap highlights on icons without size info: %d | icon patch warnings: %d", stats.invert_bad, stats.warnings)
    log("sleeps: %d | top menus closed for sleep: %d (%d ms) | left open at sleep: %d | open on wake: %d",
        stats.sleeps, stats.menus_closed, stats.close_ms, stats.menus_left, stats.menus_on_wake)
    log("Lua memory: %d KB", math.floor(mem()))
    local verdict = (stats.dirty_hidden == 0 and stats.dirty_asleep == 0 and stats.timers_asleep == 0
        and stats.invert_bad == 0 and stats.menus_left == 0 and stats.menus_on_wake == 0
        and stats.menu_dupes == 0)
        and "OK: no wasted redraws, nothing while asleep, no menu left open over sleep"
        or "CHECK the flagged lines above"
    log("verdict: %s", verdict)
end

-- --------------------------------------------------------------------------
-- The 5-minute window: opens on the first toolbar build after start
-- --------------------------------------------------------------------------

closeWindow = function()
    if not window_open then return end
    summary("5 minutes up")
    log("logging stopped until next restart (delete this patch when done)")
    window_open, window_done = false, true
    if not shared_note("Diagnostics: done, log written") then
        pcall(function()
            require("ui/widget/notification"):notify("Diagnostics: done, log written")
        end)
    end
end

local menu_toggle_watch = false
local state_reads -- icon tweaks' shared readers (1.14.1+)

-- Where Follow Bluetooth looks, and what's really there.
local function bluetoothProbe()
    local how = "icon tweaks < 1.14.3 (no lookup report)"
    if type(state_reads) == "table" and type(state_reads.bluetooth_source) == "function" then
        local ok, v = pcall(state_reads.bluetooth_source)
        how = ok and q(v) or ("ERROR " .. q(v))
    end
    log("bluetooth lookup: %s", how)
    for _i, path in ipairs({ "apps/reader/readerui", "apps/filemanager/filemanager" }) do
        local mod = package.loaded[path]
        local ui = type(mod) == "table" and mod.instance
        if type(ui) == "table" then
            local found = {}
            for k, v in pairs(ui) do
                if type(k) == "string" and type(v) == "table"
                        and (k:lower():find("kobo", 1, true) or rawget(v, "kobo_bluetooth") ~= nil) then
                    local bt = rawget(v, "kobo_bluetooth")
                    local fn = type(bt) == "table" and bt.isBluetoothEnabled or nil
                    table.insert(found, string.format("ui.%s (kobo_bluetooth: %s, isBluetoothEnabled: %s)",
                        k, type(bt), type(fn)))
                end
            end
            log("  %s: %s", path:match("[^/]+$"), #found > 0 and table.concat(found, "; ") or "no kobo plugin entry")
        end
    end
    local mods = {}
    for k in pairs(package.loaded) do
        if type(k) == "string" and k:lower():find("bluetooth", 1, true) then table.insert(mods, k) end
    end
    table.sort(mods)
    log("  bluetooth modules loaded: %s", #mods > 0 and table.concat(mods, ", ") or "none")
end

local function openWindow()
    if window_open or window_done then return end
    window_open = true
    window_start = now()
    window_start_s = os.time()
    log("==================== shortcutstoolbar diagnostics %s started ====================", DIAG_VERSION)
    -- Icon patch version, from its own header.
    local f = io.open("patches/" .. "2-" .. MAIN_TAG .. ".lua", "r")
    if f then
        local head = f:read(400) or ""
        f:close()
        log("icon tweaks %s", q(head:match("Version:%s*([%d%.]+)")))
    else
        log("icon tweaks patch file not found in patches/ (renamed?)")
    end
    local s = G_reader_settings:readSetting("shortcutstoolbar_icon_tweaks") or {}
    local n, states = 0, {}
    for _k, v in pairs(s.keys or {}) do
        n = n + 1
        if type(v) == "table" and v.state then states[v.state] = (states[v.state] or 0) + 1 end
    end
    local st = {}
    for k, v in pairs(states) do table.insert(st, k .. "=" .. v) end
    log("tweaked shortcuts: %d | indicators: %s | global colour: %s",
        n, #st > 0 and table.concat(st, " ") or "none", q(s.mode or "default"))
    log("menu toggle / bluetooth timing: %s", menu_toggle_watch and "on"
        or "not available (icon tweaks < 1.14.0)")
    -- Same fallback the icon patch itself uses.
    pcall(bluetoothProbe)
    log("night mode: %s | Lua memory: %d KB",
        q(Device.screen.night_mode or G_reader_settings:isTrue("night_mode")), math.floor(mem()))
    -- No timer: the window closes on elapsed time, checked by active()
    -- at every hooked call.
end

-- --------------------------------------------------------------------------
-- Toolbar builds (wraps the icon patch's wrapper: plugin funcs run in order)
-- --------------------------------------------------------------------------

-- Close-on-sleep: wrapped here, after the icon patch has wrapped it, so this
-- sees the menus before the patch closes them and the result after.
local function watchSleepClose()
    local ok, Screensaver = pcall(require, "ui/screensaver")
    if not ok or type(Screensaver) ~= "table" or Screensaver.__stb_diag_sleep then return end
    Screensaver.__stb_diag_sleep = true
    local patched = Screensaver.__stb_close_menus == true
    local orig = Screensaver.setup
    Screensaver.setup = function(...)
        if not active() then return orig(...) end
        stats.sleeps = stats.sleeps + 1
        local before = openMenus()
        local t = now()
        local res = { pcall(orig, ...) }
        local took = ms(t)
        local after = openMenus()
        local closed = math.max(0, #before - #after)
        stats.menus_closed = stats.menus_closed + closed
        stats.close_ms = stats.close_ms + math.max(0, took)
        log("sleep screen setup: open menus before %s, after %s | close-on-sleep %s | %d ms (incl. sleep screen setup)%s",
            #before > 0 and table.concat(before, ", ") or "none",
            #after > 0 and table.concat(after, ", ") or "none",
            patched and "on" or "NOT installed (icon tweaks < 1.13.0?)", took,
            #after > 0 and "  CHECK" or "")
        if not res[1] then error(res[2], 0) end
        return unpack(res, 2)
    end
end

-- Menu Toggle / Bluetooth reads (icon tweaks 1.14.1+ shares its readers;
-- 1.14.0 shared only the menu one).
local function wrapRead(tbl, field, what)
    local orig = tbl[field]
    if type(orig) ~= "function" then return false end
    tbl[field] = function(key, ...)
        if not active() then return orig(key, ...) end
        local t = now()
        local res = { pcall(orig, key, ...) }
        local took = math.max(ms(t), 0)
        stats.menu_reads = stats.menu_reads + 1
        stats.menu_read_ms = stats.menu_read_ms + took
        if took > stats.menu_read_max then stats.menu_read_max = took end
        local v
        if res[1] then v = res[2] end
        if res[1] and v == nil then stats.menu_unknown = stats.menu_unknown + 1 end
        log("%s read %s: %s, %dms%s", what, q(key),
            not res[1] and ("ERROR " .. q(res[2])) or (v == nil and "unknown (shown as on)" or (v and "on" or "off")),
            took, took > 50 and "  SLOW" or "")
        if not res[1] then error(res[2], 0) end
        return unpack(res, 2)
    end
    return true
end

local function watchMenuToggle(HC)
    local sr = HC.__stb_state_reads
    state_reads = sr
    if type(sr) == "table" and not sr.__stb_diag then
        sr.__stb_diag = true
        local a = wrapRead(sr, "menu", "menu toggle")
        local b = wrapRead(sr, "bluetooth", "bluetooth")
        return a or b
    end
    local mt = HC.__stb_menu_toggle -- 1.14.0
    if type(mt) == "table" and not mt.__stb_diag then
        mt.__stb_diag = true
        return wrapRead(mt, "read", "menu toggle")
    end
    return false
end

-- A second library top menu while one is already showing: the copy the
-- toolbar plugin opened to run a menu action, leaving the first stuck.
local function watchLibraryMenu()
    local ok, FMM = pcall(require, "apps/filemanager/filemanagermenu")
    if not ok or type(FMM) ~= "table" or type(FMM.onShowMenu) ~= "function" or FMM.__stb_diag then return end
    FMM.__stb_diag = true
    local orig = FMM.onShowMenu
    FMM.onShowMenu = function(self, ...)
        if active() and self.menu_container and UIManager.isWidgetShown then
            local ok_s, shown = pcall(UIManager.isWidgetShown, UIManager, self.menu_container)
            if ok_s and shown then
                stats.menu_dupes = stats.menu_dupes + 1
                log("LIBRARY MENU OPENED TWICE: a second copy over the open one (it won't close)  CHECK")
            end
        end
        return orig(self, ...)
    end
end

userpatch.registerPatchPluginFunc("shortcutstoolbar", function()
    pcall(watchSleepClose)
    pcall(watchLibraryMenu)
    local ok, HC = pcall(require, "home_content")
    if not ok or type(HC) ~= "table" or HC.__stb_diag then return end
    HC.__stb_diag = true
    local ok_mt, watching = pcall(watchMenuToggle, HC)
    menu_toggle_watch = ok_mt and watching
    for _i, fname in ipairs({ "createHomeContent", "createShortcutsBar" }) do
        local orig = HC[fname]
        if type(orig) == "function" then
            HC[fname] = function(...)
                openWindow()
                if not active() then return orig(...) end
                local t, m0 = now(), mem()
                local res = { pcall(orig, ...) }
                local took = ms(t)
                stats.builds = stats.builds + 1
                stats.build_ms = stats.build_ms + math.max(took, 0)
                local cfg = select(2, ...)
                log("toolbar built (%s, view %s): %dms, memory %+d KB%s", fname,
                    q(type(cfg) == "table" and cfg.view), took, math.floor(mem() - m0),
                    took > 150 and "  SLOW" or "")
                if not res[1] then
                    log("toolbar build ERROR: %s", q(res[2]))
                    error(res[2], 0)
                end
                return unpack(res, 2)
            end
        end
    end
end)

-- --------------------------------------------------------------------------
-- Redraws and timers the icon patch asks for
-- --------------------------------------------------------------------------

local orig_setDirty = UIManager.setDirty
UIManager.setDirty = function(self, widget, ...)
    if active() and fromMain(2) then
        stats.dirty = stats.dirty + 1
        local top = screenWindow()
        local asleep = Device.screen_saver_mode
        local hidden = type(widget) == "table" and widget ~= top
        if asleep then stats.dirty_asleep = stats.dirty_asleep + 1 end
        if hidden then stats.dirty_hidden = stats.dirty_hidden + 1 end
        local line = debug.getinfo(2, "l")
        log("redraw from icon patch (line %s) -> %s%s%s", q(line and line.currentline), name(widget),
            hidden and ("  WASTED: showing is " .. name(top)) or "",
            asleep and "  WHILE ASLEEP" or "")
    end
    return orig_setDirty(self, widget, ...)
end

local function watchTimer(fname)
    local orig = UIManager[fname]
    UIManager[fname] = function(self, a, b, ...)
        if active() and fromMain(2) then
            stats.timers = stats.timers + 1
            local asleep = Device.screen_saver_mode
            if asleep then stats.timers_asleep = stats.timers_asleep + 1 end
            local line = debug.getinfo(2, "l")
            log("timer from icon patch (line %s): %s%s", q(line and line.currentline),
                fname == "nextTick" and "next tick" or (q(a) .. "s"),
                asleep and "  WHILE ASLEEP" or "")
        end
        return orig(self, a, b, ...)
    end
end
watchTimer("scheduleIn")
watchTimer("nextTick")

-- --------------------------------------------------------------------------
-- Tap highlight (the icon invert on tap) and indicator paints
-- --------------------------------------------------------------------------

local orig_invert = UIManager.widgetInvert
if type(orig_invert) == "function" then
    UIManager.widgetInvert = function(self, widget, ...)
        if active() and type(widget) == "table" and widget.dimen == nil then
            stats.invert_bad = stats.invert_bad + 1
            log("TAP HIGHLIGHT on an icon with no size info (would crash): file %s", q(widget.file))
        end
        return orig_invert(self, widget, ...)
    end
end

local IconButton = require("ui/widget/iconbutton")
local orig_btn_paint = IconButton.paintTo
IconButton.paintTo = function(self, ...)
    if not (active() and self._stb_tracks_screen) then return orig_btn_paint(self, ...) end
    local t = now()
    local r = orig_btn_paint(self, ...)
    local took = ms(t)
    stats.paints = stats.paints + 1
    stats.paint_ms = stats.paint_ms + math.max(took, 0)
    if took > 50 then log("SLOW indicator paint: %dms (icon %s)", took, q(self.icon)) end
    return r
end

-- --------------------------------------------------------------------------
-- Events: network, SSH/Calibre, night mode, sleep / wake
-- --------------------------------------------------------------------------

local WATCH_EVENTS = {
    onNetworkConnecting = "Wi-Fi connecting",
    onNetworkConnected = "Wi-Fi connected",
    onNetworkDisconnected = "Wi-Fi disconnected",
    onNetworkTweaksStateChanged = "SSH/Calibre state changed (Network Tweaks)",
    onToggleNightMode = "night mode toggled",
    onSetNightMode = "night mode set",
    -- Real handlers, implemented by core plugins and broadcast by the icon
    -- patch itself for system toggle shortcuts (its STAY_OPEN map):
    -- SSH.koplugin implements onToggleSSHServer; calibre.koplugin
    -- implements onStartWirelessConnection / onCloseWirelessConnection.
    onToggleSSHServer = "SSH toggle",
    onStartWirelessConnection = "Calibre connect",
    onCloseWirelessConnection = "Calibre disconnect",
}

local orig_broadcast = UIManager.broadcastEvent
UIManager.broadcastEvent = function(self, event, ...)
    local h = type(event) == "table" and event.handler
    if active() and h then
        if h == "onSuspend" then
            local left = openMenus()
            if #left > 0 then
                stats.menus_left = stats.menus_left + #left
                log("SLEEP: top menu still open: %s  CHECK", table.concat(left, ", "))
            end
            local n, where = pendingMainTasks()
            log("SLEEP: icon patch timers still pending: %d%s", n, n > 0 and ("  (" .. where .. ")") or "")
            summary("going to sleep")
        elseif h == "onResume" then
            local open = openMenus()
            if #open > 0 then
                stats.menus_on_wake = stats.menus_on_wake + #open
                log("WAKE: top menu open on wake: %s  CHECK", table.concat(open, ", "))
            else
                log("WAKE: no top menu open (anything the icon patch does next is logged)")
            end
        elseif WATCH_EVENTS[h] then
            log("event: %s", WATCH_EVENTS[h])
        end
    end
    return orig_broadcast(self, event, ...)
end

local orig_close = UIManager.close
UIManager.close = function(self, w, ...)
    if active() and type(w) == "table" and not w.toast and w == screenWindow() then
        log("screen closed: %s", name(w))
    end
    return orig_close(self, w, ...)
end

-- Icon patch warnings (e.g. "button order mismatch").
local orig_warn = logger.warn
logger.warn = function(...)
    if active() then
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
        local line = table.concat(parts, " ")
        if line:find("shortcutstoolbar icon tweaks", 1, true) then
            stats.warnings = stats.warnings + 1
            log("ICON PATCH WARNING: %s", line)
        end
    end
    return orig_warn(...)
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

-- Shortcuts Toolbar (Icon Tweaks): its timers that hold the screen 80 ms+, flashes it asks for, and
-- timers it leaves waiting at sleep, plus a once-a-minute perf line, all
-- inside the 5-minute window.
DiagCore.client({
    name = "Shortcuts Toolbar (Icon Tweaks)",
    targets = { "2-shortcutstoolbar-icon-tweaks.lua", "shortcutstoolbar.koplugin/" },
    on = function() return active() end,
    log = log,
    errors = false, -- its warnings are caught above
})

logger.info("shortcutstoolbar diagnostics " .. DIAG_VERSION .. " loaded (5 min window on first toolbar open)")
