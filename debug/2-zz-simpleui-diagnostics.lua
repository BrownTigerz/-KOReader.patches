--[[
2-zz-simpleui-diagnostics.lua - TEMPORARY troubleshooting patch
Version 2.10.0

Shared log contract v1: writes tagged lines ("[simpleui]") to the ONE
shared diagnostics file:  koreader/diagnostics.log
(Kobo: .adds/koreader/diagnostics.log)

It only logs for the first 30 minutes after KOReader starts (WINDOW_MIN
below; time asleep counts). After that every hook it adds goes idle and
nothing more is written. 3 days after its first run it stops hooking
anything at all (one line per start says so); delete
simpleui-diagnostics.state for another 3 days. It changes nothing, it only
writes the log (and that one-line state file). No repeating timers.

What it logs:
  - Menu tab icons: which custom icon SimpleUI uses for each tab, whether it
    registered, and which file each tab actually draws.
  - Shortcuts Toolbar: whether it recognises the library / reader menu.
  - Sleep: on every sleep, the timers still waiting, grouped by the file that
    set them (a patch keeping the device busy shows up by name), and how long
    the device slept.
  - Performance: how long menus take to open and home screen modules take to
    build, any screen redraw slower than 100 ms, the time from a tap to the
    screen updating, and a summary every minute.
  - Night Mode: each toggle and how long the redraw after it takes.
  - Slowdowns: which plugin, timer, tap or window paint took the time
    (anything over 80 ms right away, a per-minute "where the time went"
    list), plugin start-up cost (all plugins restart each time a book
    closes), wake-up time until the screen is ready, Lua memory.
  - White flashes: each flashing screen refresh, where on screen, on which
    window, who asked for it, and whether it was KOReader's periodic full
    refresh (Full refresh rate setting) or a direct request.
  - Home screen hand-offs between SimpleUI, Bookshelf and the reader: every
    full-screen window shown or closed, the window stack and state right
    after (SimpleUI home live / set aside, book open / held behind
    Bookshelf, file browser), Bookshelf's "Close Bookshelf" and book-holding
    steps, SimpleUI's reader-to-home steps, how long closing a book blocks
    the screen, and SimpleUI / Bookshelf warnings and errors.
  - Reading Log for SimpleUI (simpleui_readinglog.koplugin): install check,
    which of its modules are on, every build (size, theme, night mode, tap
    regions, too tall for the page, size mismatch), every tap and the region
    it hit, every home screen refresh it asks for and why, refresh loops,
    and its own / Reading Log's warnings and errors.
  - Swipe tracer (home screen only): every swipe / pan on the home screen,
    which page SimpleUI is on before and after (a page turn), Reading Log's
    swipe card switching, and the timing from finger lift to the card
    rebuilt and the screen refreshed, plus any extra redraw within 3 s
    (covers or data landing after the switch).

It sets no timers of its own: summaries are written on the next redraw.

How to use (within 30 minutes of starting KOReader):
  1. Put this file in koreader/patches/ and restart KOReader.
  2. Use it normally: home screen, open the menu in the library and in a book,
     toggle Night Mode, put the device to sleep and wake it.
     When something goes wrong (e.g. stuck on the stock library), note the
     time and send the log straight away, before restarting.
  3. Send diagnostics.log. Delete this file when done.

The "zz" makes it load after every other patch, so it sees their changes.

Changelog
  2.10.0 Shared perf core: the timer timing (KOReader's timer loop) is now
         the one copy every diagnostic shares, so this and the other
         diagnostics no longer replace each other's. Same lines as before.
  2.9.1  Swipe tracer: page turns are timed to the redraw that shows them
         (Reading Log's page-turn flash is asked during that redraw), and
         empty redraws no longer end the trace. A tap ends the trace (tab
         switches after a swipe aren't counted as its redraws).
  2.9.0  Swipe tracer: home screen swipes and pans, page before/after,
         Reading Log swipe card timing (lift -> rebuilt -> on screen) and
         follow-up redraws (covers/data) within 3 s. Idle while reading.
  2.8.3  Sleep timer list is taken after every plugin has handled sleep, so
         it shows only timers that really stay pending (a plugin that
         cancels its timer on sleep no longer shows up). This patch's own
         timers are left out of the list.
  2.8.2  Reading Log for SimpleUI 1.6.0: expects 34 modules (new cards) and
         checks its 3 new kit files (host, menus, colourtext).
  2.8.1  One line per entry: window names and messages with line breaks
         (e.g. the "Screenshot saved to:" popup) are joined with " / ",
         and the invisible text-direction marks KOReader puts around file
         paths are removed.
  2.8.0  Reading Log for SimpleUI: install and module checks, and the
         plugin's own "readinglog:" lines (builds, taps, refreshes, refresh
         loops, night mode rebuilds) logged through this diagnostic.
         Warnings/errors tagged readinglog or almanac are caught too.
  2.7.7  New Books check also runs on the SimpleUI 2.7.5 release (once at
         start): its library scan's newest books and the newest files on
         disk, with the reason any are left out.
  2.7.6  New Books: logs SimpleUI's newly-added list whenever it changes,
         the newest books its library scan sees, and once per start the
         newest files on disk with the reason SimpleUI leaves any out
         (file type, hidden folder, too deep, scan cap). Books dropped as
         finished are logged too.
  2.7.5  SimpleUI Tweaks' Currently Reading swipe logs through this
         diagnostic ("swipe:" lines), only while it's logging.
  2.7.4  Shared-log rotation cap raised from 256 KB to 2 MB (identical
         value across all 12 diagnostics per TK).
  2.7.3  Night Mode timing fix: the toggle is now detected before the
         repaint runs, so the logged "first redraw after Night Mode
         toggle" is genuinely the first repaint that rendered it. Before,
         the toggle was detected after orig_repaint had already drawn it,
         so the logged time was actually the second repaint.
  2.7.2  Shared log contract v1: all lines now go to the shared
         koreader/diagnostics.log, tagged "[simpleui]"; rotation at
         2 MB (older part kept as diagnostics.log.old). The old
         per-file simpleui-diagnostics.log is no longer written.
  2.7.1  Guarded SimpleUI API reads (keepIconColorsInNight, getIcon) with
         pcall: a throw there ran inside userpatch's unguarded patchfunc
         call and could break SimpleUI's instantiation. Shortcuts Toolbar
         section now logs when the toolbar is loaded but its menu check
         isn't visible to diagnostics.
  2.7.0  Diagnostic standard: 3-day expiry (simpleui-diagnostics.state),
         standard start line.
  2.6.0  White flashes: every flashing e-ink refresh (full / flashui /
         flashpartial) with its area, what was on screen, the code that
         asked for it, and whether KOReader's periodic full refresh turned a
         normal update into a flash. Counted in the summary.
  2.5.0  Slowdown finder: time spent per plugin (each plugin's event
         handlers and start-up), per timer (by the file that set it), per
         input event and per window paint vs. the e-ink screen update; how
         long wake-up takes until the screen is ready; Lua memory. Anything
         slow is logged as it happens, the rest summed up every minute.
  2.4.1  Redraw counts are real now: only passes that actually painted or
         refreshed the screen count. Before, every main-loop pass counted
         while a covered window (e.g. the file browser under SimpleUI home)
         was waiting to be repainted, so the numbers were inflated.
  2.4.0  Who asks for redraws: the per-minute summary lists the code that
         requested the most screen updates (file:line).
  2.3.1  "Close Bookshelf" logs whether a book was actually held (2.3.0's
         label said so every time). Millisecond trace for 4 s after
         Bookshelf closes or a menu opens/closes: every window change and
         redraw, with what's on top. Menus logged. Instant book close read
         from Bookshelf itself.
  2.3.0  30-minute window. Home screen hand-offs (SimpleUI, Bookshelf,
         reader), book close timing, SimpleUI / Bookshelf warnings.
  2.2.0  Series folder checks removed (SimpleUI Tweaks 2.5.0 dropped Series
         folders).
  2.1.1  Series checks now see the file browser open (it was looked up by
         the wrong name, so nothing was logged).
  2.1.0  Series folders checks for SimpleUI Tweaks 2.4.0.
  2.0.0  5-minute logging window. Sleep timers, performance timings, Night
         Mode toggles, tap response, SimpleUI version.
  1.0.0  Tab icons and Shortcuts Toolbar checks.
]]

local DataStorage = require("datastorage")
local lfs = require("libs/libkoreader-lfs")

local WINDOW_MIN = 30                -- logging stops this many minutes after start
local WINDOW_S = WINDOW_MIN * 60
local EXPIRE_S = 3 * 24 * 3600      -- stops hooking anything after this
local STATE = DataStorage:getDataDir() .. "/simpleui-diagnostics.state"
local SLOW_REPAINT_MS = 100
local SLOW_TAP_MS = 300

local started = os.time()
local active = true

-- monotonic milliseconds (KOReader's clock if available)
local now_ms
do
    local ok, time = pcall(require, "ui/time")
    if ok and type(time) == "table" and time.now and time.to_ms then
        now_ms = function() return time.to_ms(time.now()) end
    else
        now_ms = function() return math.floor(os.clock() * 1000) end
    end
end

-- Shared log contract v1: all diagnostics append timestamped, tagged lines
-- to ONE file (koreader/diagnostics.log) so a full test run reads as a
-- single chronological log. Rotation at 2 MB, older part kept as
-- diagnostics.log.old.
local DIAG_TAG = "simpleui"
local SHARED_LOG = DataStorage:getDataDir() .. "/diagnostics.log"
local SHARED_MAX_BYTES = 2 * 1024 * 1024
-- Unicode bidi isolate / embedding marks (U+2066-2069, U+202A-202E) that
-- KOReader wraps around file paths in popups.
local BIDI = { "\226\129\166", "\226\129\167", "\226\129\168", "\226\129\169",
    "\226\128\170", "\226\128\171", "\226\128\172", "\226\128\173", "\226\128\174" }
local function oneLine(s)
    s = tostring(s)
    for _i, m in ipairs(BIDI) do s = s:gsub(m, "") end
    s = s:gsub("%s*[\r\n]+%s*", " / ")
    return s
end

local function shared_log(fmt, ...)
    local ok, line = pcall(string.format, fmt, ...)
    if not ok then line = tostring(fmt) end
    line = oneLine(line)
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

-- innermost file-append for every writer path (gated log() calls and the
-- direct write() calls for the expiry, start and window-close lines).
-- Pre-built lines go through "%s" so their content stays identical.
local function write(line)
    shared_log("%s", line)
end

-- true while logging; the first call after the window ends closes it for good
local function on()
    if not active then return false end
    if os.time() - started > WINDOW_S then
        active = false
        write("==== " .. WINDOW_MIN .. " minutes up: logging stopped, every hook is idle now ====")
        return false
    end
    return true
end

local function log(fmt, ...)
    if not on() then return end
    local ok, line = pcall(string.format, fmt, ...)
    write(ok and line or tostring(fmt))
end

local function q(v) return v == nil and "(none)" or tostring(v) end

local function fileInfo(path)
    if type(path) ~= "string" or path == "" then return "(no file)" end
    local mode = lfs.attributes(path, "mode")
    local ext = path:match("%.([^./]+)$")
    return string.format("%s [%s, %s]", path, ext and ext:lower() or "no extension",
        mode == "file" and "exists" or "MISSING")
end

local function upvalue(fn, name)
    if type(fn) ~= "function" then return nil end
    local i = 1
    while true do
        local n, v = debug.getupvalue(fn, i)
        if n == nil then return nil end
        if n == name then return v end
        i = i + 1
    end
end

-- "plugins/simpleui.koplugin/main.lua:120" style label for a function
local function where(fn)
    if type(fn) ~= "function" then return tostring(fn) end
    local info = debug.getinfo(fn, "S")
    if not info then return "?" end
    local src = (info.short_src or "?"):gsub("^%./", "")
    return src .. ":" .. tostring(info.linedefined or "?")
end

-- Hard expiry: first run kept in the state file.
do
    local first
    local f = io.open(STATE, "r")
    if f then first = tonumber(f:read("*l") or "") f:close() end
    if not first then
        first = os.time()
        local w = io.open(STATE, "w")
        if w then w:write(first, "\n") w:close() end
    end
    if os.difftime(os.time(), first) > EXPIRE_S then
        write("simpleui diagnostics 2.10.0 expired (first run " .. os.date("%Y-%m-%d %I:%M %p", first)
            .. "): not watching anything. Delete this patch, or delete simpleui-diagnostics.state for 3 more days.")
        return
    end
end

-- Other SimpleUI patches (SimpleUI Tweaks' Currently Reading swipe) log
-- through this, so their lines follow this diagnostic's window and expiry.
package.loaded["simpleui_diagnostics"] = { log = log }

write("==================== simpleui diagnostics 2.10.0 started (logging for " .. WINDOW_MIN .. " minutes) ====================")
do
    local dir = DataStorage:getDataDir() .. "/patches"
    local names = {}
    if lfs.attributes(dir, "mode") == "directory" then
        for f in lfs.dir(dir) do
            if f:match("%.lua$") then names[#names + 1] = f end
        end
    end
    table.sort(names)
    log("patches: %s", #names > 0 and table.concat(names, ", ") or "(none found)")
end

local userpatch = require("userpatch")

-- --------------------------------------------------------------------------
-- 1. SimpleUI: version, tab icon settings, registration, module build times
-- --------------------------------------------------------------------------
local sui_logged = false
userpatch.registerPatchPluginFunc("simpleui", function(plugin)
    if not on() then return end
    local S = package.loaded["features/sui_style"]
    if not sui_logged then
        sui_logged = true
        local ver = "?"
        pcall(function()
            local meta = dofile(plugin.path .. "/_meta.lua")
            ver = meta and meta.version or "?"
        end)
        log("SimpleUI version %s", ver)
        if type(S) == "table" then
            -- these run inside userpatch's unguarded patchfunc call: a throw
            -- here would break SimpleUI's instantiation, so read them safely
            local keep_txt = "(not in this version)"
            if type(S.keepIconColorsInNight) == "function" then
                local okk, keep = pcall(S.keepIconColorsInNight)
                keep_txt = okk and q(keep) or "(error reading it)"
            end
            log("SimpleUI 'Don't Invert Colored Icons in Night Mode': %s", keep_txt)
            if type(S.SLOTS) == "table" then
                for _i, s in ipairs(S.SLOTS) do
                    if s.tab_id then
                        local raw
                        if type(S.getIcon) == "function" then
                            local okr, r = pcall(S.getIcon, s.id)
                            if okr then raw = r end
                        end
                        log("SimpleUI tab slot %-22s (tab id %-20s) custom icon: %s",
                            s.id, s.tab_id, raw and fileInfo(raw) or "(none, stock icon)")
                    end
                end
            end
        end
    end
    if type(S) == "table" and type(S.registerTabIconName) == "function" and not S._diag_wrapped then
        S._diag_wrapped = true
        local orig = S.registerTabIconName
        S.registerTabIconName = function(slot_id, path, ...)
            local name = orig(slot_id, path, ...)
            if on() then
                local reason = ""
                if not name then
                    local ext = type(path) == "string" and path:match("%.([^./]+)$")
                    ext = ext and ext:lower()
                    if ext ~= "svg" and ext ~= "png" then
                        reason = "  <-- REJECTED: tab icons must be .svg or .png (this is ." .. q(ext) .. ")"
                    elseif lfs.attributes(path, "mode") ~= "file" then
                        reason = "  <-- REJECTED: source file is missing"
                    else
                        reason = "  <-- REJECTED: copy into koreader/icons failed"
                    end
                end
                log("SimpleUI register tab icon %s from %s -> %s%s", q(slot_id), fileInfo(path), q(name), reason)
            end
            return name
        end
    end
    -- time each home screen module build
    local E = package.loaded["engines/sui_screen_engine"]
    local SW = type(E) == "table" and upvalue(E._open, "ScreenWidget")
    if type(SW) == "table" and type(SW._buildModWidget) == "function" and not SW._diag_wrapped then
        SW._diag_wrapped = true
        local orig_build = SW._buildModWidget
        SW._buildModWidget = function(self, mod, ...)
            if not on() then return orig_build(self, mod, ...) end
            local t0 = now_ms()
            local res = { orig_build(self, mod, ...) }
            log("home screen module %-22s built in %d ms", q(type(mod) == "table" and mod.id), now_ms() - t0)
            return unpack(res)
        end
    end
end)

-- --------------------------------------------------------------------------
-- 2. Shortcuts Toolbar: can its menu check be seen?
-- --------------------------------------------------------------------------
local stb_menuConfig, stb_plugin
userpatch.registerPatchPluginFunc("shortcutstoolbar", function(plugin)
    stb_plugin = plugin
    stb_menuConfig = upvalue(plugin and plugin.onSwitchTab, "menuConfig")
        or upvalue(plugin and plugin.onMenuInit, "menuConfig")
    log("Shortcuts Toolbar loaded. Its menu check is visible to diagnostics: %s", q(stb_menuConfig ~= nil))
end)

-- --------------------------------------------------------------------------
-- 3. Menus: open time, each tab's id / icon name / file, toolbar decision
-- --------------------------------------------------------------------------
local ok_tm, TouchMenu = pcall(require, "ui/widget/touchmenu")
if ok_tm and type(TouchMenu) == "table" and type(TouchMenu.init) == "function" then
    local orig_init = TouchMenu.init
    TouchMenu.init = function(self, ...)
        if not on() then return orig_init(self, ...) end
        local t0 = now_ms()
        local res = { orig_init(self, ...) }
        local took = now_ms() - t0
        pcall(function()
            local R = package.loaded["apps/reader/readerui"]
            local place = (type(R) == "table" and R.instance) and "READER" or "LIBRARY"
            log("---- menu opened in %s (built in %d ms) ----", place, took)
            local tabs = self.tab_item_table or {}
            local widgets = self.bar and self.bar.icon_widgets or {}
            local stock_fb, stock_reader = false, false
            for k, tab in ipairs(tabs) do
                local img = widgets[k] and widgets[k].image
                log("  tab %d  id=%-20s icon name=%-34s shows file: %s", k, q(tab.id), q(tab.icon),
                    img and fileInfo(img.file) or "(no icon widget)")
                if tab.icon == "appbar.filebrowser" then stock_fb = true end
                if tab.icon == "appbar.navigation" or tab.icon == "appbar.typeset" then stock_reader = true end
            end
            log("  Shortcuts Toolbar sees (by tab icon name): library menu=%s, reader menu=%s", q(stock_fb), q(stock_reader))
            if stb_menuConfig then
                local okc, cfg = pcall(stb_menuConfig, self)
                local fb_cfg, rd_cfg = upvalue(stb_menuConfig, "fb_config"), upvalue(stb_menuConfig, "reader_config")
                local what = not okc and ("ERROR " .. tostring(cfg))
                    or (cfg == nil and "NOT RECOGNISED - toolbar will not show")
                    or (cfg == fb_cfg and "library toolbar")
                    or (cfg == rd_cfg and "reader toolbar")
                    or "recognised (other)"
                log("  Shortcuts Toolbar decides: %s", what)
            elseif stb_plugin == nil then
                log("  Shortcuts Toolbar: not loaded")
            else
                log("  Shortcuts Toolbar: loaded, but its menu check is not visible to diagnostics")
            end
        end)
        return unpack(res)
    end
end

-- --------------------------------------------------------------------------
-- 4. Redraws, taps, Night Mode, sleep
-- --------------------------------------------------------------------------
local ok_ui, UIManager = pcall(require, "ui/uimanager")
-- set by the redraw timer below: did the last _repaint really paint/refresh?
local PAINT = { real = false, painted = false, parts = nil }
-- extra lines for the per-minute summary (section 6 adds one)
local SUMMARY_EXTRA = {}
local Screen = require("device").screen

if ok_ui and type(UIManager) == "table" then
    -- per-minute summary, written on the next redraw (no timers)
    local stats = { n = 0, total = 0, max = 0, slow = 0, taps = 0, tap_total = 0, tap_max = 0 }
    local last_summary = os.time()
    local last_night = Screen.night_mode
    local pending_tap

    -- who asks for screen updates: setDirty callers, counted per minute
    local dirty_by = {}
    local function caller()
        for lvl = 3, 7 do
            local info = debug.getinfo(lvl, "Sl")
            if not info then break end
            local src = info.short_src or "?"
            if not src:find("uimanager%.lua") and not src:find("diagnostics") then
                return src:gsub("^%./", ""):gsub("^.-plugins/", "plugins/") .. ":" .. tostring(info.currentline)
            end
        end
        return "?"
    end
    if type(UIManager.setDirty) == "function" then
        local orig_sd = UIManager.setDirty
        UIManager.setDirty = function(self, ...)
            if on() then
                local ok, key = pcall(caller)
                if ok then dirty_by[key] = (dirty_by[key] or 0) + 1 end
            end
            return orig_sd(self, ...)
        end
    end

    local function summary()
        if stats.n == 0 and stats.taps == 0 then return end
        log("summary (last minute): %d redraws, average %d ms, slowest %d ms, %d over %d ms; "
            .. "%d taps, tap to screen average %d ms, slowest %d ms",
            stats.n, stats.n > 0 and math.floor(stats.total / stats.n) or 0, stats.max, stats.slow, SLOW_REPAINT_MS,
            stats.taps, stats.taps > 0 and math.floor(stats.tap_total / stats.taps) or 0, stats.tap_max)
        stats = { n = 0, total = 0, max = 0, slow = 0, taps = 0, tap_total = 0, tap_max = 0 }
        local list = {}
        for k, n in pairs(dirty_by) do list[#list + 1] = { k, n } end
        table.sort(list, function(a, b) return a[2] > b[2] end)
        local parts = {}
        for i = 1, math.min(6, #list) do parts[#parts + 1] = list[i][2] .. " x " .. list[i][1] end
        if #parts > 0 then log("  redraw requests by: %s", table.concat(parts, ", ")) end
        dirty_by = {}
        for _i, f in ipairs(SUMMARY_EXTRA) do pcall(f) end
    end

    local function topName()
        local stack = UIManager._window_stack
        local top = type(stack) == "table" and stack[#stack] and stack[#stack].widget
        return top and (top.name or top.title or (top.covers_fullscreen and "fullscreen window") or "window") or "?"
    end

    if type(Screen) == "table" and type(Screen.afterPaint) == "function" then
        local orig_ap = Screen.afterPaint
        Screen.afterPaint = function(...)
            PAINT.painted = true
            return orig_ap(...)
        end
    end
    if type(UIManager._repaint) == "function" then
        local orig_repaint = UIManager._repaint
        UIManager._repaint = function(self, ...)
            if not on() then return orig_repaint(self, ...) end
            -- KOReader calls this every loop; only time it when there's work
            local work = (type(self._dirty) == "table" and next(self._dirty) ~= nil)
                or (type(self._refresh_stack) == "table" and #self._refresh_stack > 0)
            if not work then PAINT.real = false return orig_repaint(self, ...) end
            -- KOReader keeps a covered window marked dirty until it's
            -- uncovered, and calls this on every main-loop pass; only count
            -- passes that actually painted something or refreshed the screen.
            local refreshes = type(self._refresh_stack) == "table" and #self._refresh_stack or 0
            PAINT.painted = false
            PAINT.parts = {}
            -- Check the Night Mode toggle BEFORE the repaint runs, so the
            -- repaint timed below is the first one that rendered it (2.7.3:
            -- the toggle was detected after orig_repaint had already drawn
            -- it, so the logged "first redraw" was actually the second).
            local night_toggled = Screen.night_mode ~= last_night
            if night_toggled then
                last_night = Screen.night_mode
                local S = package.loaded["features/sui_style"]
                log("Night Mode turned %s (SimpleUI 'Don't Invert Colored Icons': %s)",
                    last_night and "ON" or "OFF",
                    (type(S) == "table" and type(S.keepIconColorsInNight) == "function") and q(S.keepIconColorsInNight()) or "n/a")
            end
            local t0 = now_ms()
            local res = { orig_repaint(self, ...) }
            local took = now_ms() - t0
            local parts = PAINT.parts
            PAINT.parts = nil
            PAINT.real = PAINT.painted or refreshes > 0 or #(self._refresh_stack or {}) > 0
            if not PAINT.real then return unpack(res) end
            do
                stats.n = stats.n + 1
                stats.total = stats.total + took
                if took > stats.max then stats.max = took end
                if took > SLOW_REPAINT_MS then
                    stats.slow = stats.slow + 1
                    local painted, bits = 0, {}
                    for _i, p in ipairs(parts or {}) do
                        painted = painted + p[2]
                        if p[2] >= 5 then bits[#bits + 1] = p[1] .. " " .. p[2] end
                    end
                    log("slow redraw: %d ms (top window: %s) = drawing %d ms%s + screen update %d ms",
                        took, q(topName()), painted,
                        #bits > 0 and (" [" .. table.concat(bits, ", ") .. "]") or "",
                        math.max(0, took - painted))
                end
            end
            if pending_tap then
                local lag = now_ms() - pending_tap
                pending_tap = nil
                stats.taps = stats.taps + 1
                stats.tap_total = stats.tap_total + lag
                if lag > stats.tap_max then stats.tap_max = lag end
                if lag > SLOW_TAP_MS then log("slow tap response: %d ms from tap to screen", lag) end
            end
            if night_toggled then
                log("  first redraw after Night Mode toggle: %d ms", took)
            end
            if os.time() - last_summary >= 60 then
                last_summary = os.time()
                summary()
            end
            return unpack(res)
        end
    end

    if type(UIManager.sendEvent) == "function" then
        local orig_send = UIManager.sendEvent
        UIManager.sendEvent = function(self, event, ...)
            if on() and type(event) == "table" and event.handler == "onGesture" then
                local ges = event.args and event.args[1]
                if type(ges) == "table" and ges.ges == "tap" then pending_tap = now_ms() end
            end
            return orig_send(self, event, ...)
        end
    end

    -- Sleep: timers still waiting, by the file that set them; time asleep
    if type(UIManager.broadcastEvent) == "function" then
        local orig_bc = UIManager.broadcastEvent
        local slept_at
        UIManager.broadcastEvent = function(self, event, ...)
            local h = type(event) == "table" and event.handler
            if h == "onSuspend" and on() then
                slept_at = os.time()
                pcall(summary)
                -- let every plugin handle sleep first (cancel its timers),
                -- then list what is really still waiting
                orig_bc(self, event, ...)
                pcall(function()
                    local by, count = {}, 0
                    for _i, task in ipairs(self._task_queue or {}) do
                        local key = where(task.action)
                        if not key:find("diagnostics", 1, true) then
                            by[key] = (by[key] or 0) + 1
                            count = count + 1
                        end
                    end
                    log("---- going to sleep: %d timers still waiting (after plugins handled sleep) ----", count)
                    local keys = {}
                    for k in pairs(by) do keys[#keys + 1] = k end
                    table.sort(keys)
                    for _i, k in ipairs(keys) do log("  %d x %s", by[k], k) end
                end)
                return
            end
            if h == "onResume" and on() then
                pcall(log, "---- woke up after %s ----", slept_at
                    and (os.time() - slept_at) .. " s asleep" or "an unknown time")
            end
            return orig_bc(self, event, ...)
        end
    end
end

-- --------------------------------------------------------------------------
-- 5. Home screen hand-offs: SimpleUI <-> Bookshelf <-> reader
-- Only looks. Wraps are added once, and the window wrappers sit under
-- SimpleUI's own (they're installed before SimpleUI starts), so they see
-- the real show/close as it happens.
-- --------------------------------------------------------------------------
if ok_ui and type(UIManager) == "table" then
    local function wname(w)
        if type(w) ~= "table" then return tostring(w) end
        local FM = package.loaded["apps/filemanager/filemanager"]
        if type(FM) == "table" and FM.instance == w then return "file browser" end
        local RUI = package.loaded["apps/reader/readerui"]
        if type(RUI) == "table" and RUI.instance == w then return "reader" end
        if w.name == "homescreen" then return "SimpleUI home" end
        if w.name == "bookshelf" then return "Bookshelf" end
        local n = w.name or w.title or (type(w.title_bar) == "table" and w.title_bar.title)
        if n then return tostring(n) end
        if w.covers_fullscreen then return "(unnamed full-screen)" end
        if w.timeout then return "(toast)" end
        if type(w.item_table) == "table" or w.tab_item_table or (type(w[1]) == "table" and w[1].tab_item_table) then return "(menu)" end
        return "(dialog)"
    end

    local function park()
        local P = package.loaded["lib/bookshelf_reader_park"]
        if type(P) ~= "table" or type(P.isParked) ~= "function" then return nil end
        local ok, v = pcall(P.isParked)
        return ok and v or false
    end

    local function state()
        local parts = {}
        for _i, e in ipairs(UIManager._window_stack or {}) do
            parts[#parts + 1] = wname(e.widget)
        end
        local HS = package.loaded["screens/sui_homescreen"]
        local inst
        if type(HS) == "table" then pcall(function() inst = HS._instance end) end
        local hs = type(HS) ~= "table" and "not loaded"
            or not inst and "not live"
            or (inst._parked and "SET ASIDE (parked)" or "live")
        local RUI = package.loaded["apps/reader/readerui"]
        local FM = package.loaded["apps/filemanager/filemanager"]
        local p = park()
        return string.format("stack [%s] | SimpleUI home %s | book %s | file browser %s",
            table.concat(parts, " > "), hs,
            (type(RUI) == "table" and RUI.instance) and (p and "held behind Bookshelf" or "open") or "closed",
            (type(FM) == "table" and FM.instance) and "exists" or "none")
    end

    -- the state right after this event, once the current tick's work is done
    -- (one line per tick, however many windows changed in it)
    local pending_state = false
    local function stateSoon()
        if pending_state then return end
        pending_state = true
        UIManager:nextTick(function()
            pending_state = false
            if on() then log("  now: %s", state()) end
        end)
    end

    -- Millisecond trace for a few seconds after the moments that matter
    -- (Bookshelf closing, a menu opening/closing): what is on top at every
    -- redraw shows exactly what the screen was showing, and for how long.
    local TRACE_MS = 4000
    local trace_t0, trace_until
    local function startTrace(why)
        local t = now_ms()
        if trace_until and t <= trace_until then   -- already tracing: extend, keep the clock
            trace_until = t + TRACE_MS
            return
        end
        trace_t0, trace_until = t, t + TRACE_MS
        log("  -- trace start (%s) --", why)
    end
    local function tr()
        if trace_until and now_ms() <= trace_until then
            return string.format("+%4d ms  ", now_ms() - trace_t0)
        end
        trace_until = nil
        return ""
    end
    local function topNow()
        local st = UIManager._window_stack
        local top = type(st) == "table" and st[#st]
        local under = type(st) == "table" and st[#st - 1]
        return wname(top and top.widget) .. (under and ("  (under it: " .. wname(under.widget) .. ")") or "")
    end
    local function isMenu(w)
        return type(w) == "table" and not w.covers_fullscreen and wname(w) == "(menu)"
    end

    local orig_show2 = UIManager.show
    UIManager.show = function(self, w, ...)
        if on() and type(w) == "table" then
            if w.covers_fullscreen then
                log("%sSHOW  %s", tr(), wname(w))
                stateSoon()
            elseif isMenu(w) then
                startTrace("menu opened")
                log("%sSHOW  menu", tr())
            end
        end
        return orig_show2(self, w, ...)
    end

    local orig_close2 = UIManager.close
    UIManager.close = function(self, w, ...)
        if on() and type(w) == "table" then
            if w.covers_fullscreen or w.name == "bookshelf" then
                if w.name == "bookshelf" then startTrace("Bookshelf closing") end
                log("%sCLOSE %s", tr(), wname(w))
                stateSoon()
            elseif isMenu(w) then
                startTrace("menu closing")
                log("%sCLOSE menu", tr())
                stateSoon()
            end
        end
        return orig_close2(self, w, ...)
    end

    if type(UIManager._repaint) == "function" then
        local orig_rp = UIManager._repaint
        UIManager._repaint = function(self, ...)
            if trace_until and on() then
                local work = (type(self._dirty) == "table" and next(self._dirty) ~= nil)
                    or (type(self._refresh_stack) == "table" and #self._refresh_stack > 0)
                if work then
                    local prefix = tr()
                    if prefix ~= "" then
                        local t0 = now_ms()
                        local res = { orig_rp(self, ...) }
                        if PAINT.real then
                            log("%sredraw %d ms, top: %s", prefix, now_ms() - t0, topNow())
                        end
                        return unpack(res)
                    end
                end
            end
            return orig_rp(self, ...)
        end
    end

    -- SimpleUI / Bookshelf warnings and errors (they mostly pcall and log)
    local logger = require("logger")
    for _i, lvl in ipairs({ "warn", "err" }) do
        local orig = logger[lvl]
        if type(orig) == "function" then
            logger[lvl] = function(...)
                if on() then
                    local first = tostring((...))
                    local low = first:lower()
                    if low:find("simpleui") or low:find("bookshelf") or low:find("sui_")
                        or low:find("readinglog") or low:find("almanac") then
                        local bits = {}
                        for k = 1, math.min(select("#", ...), 6) do bits[#bits + 1] = tostring((select(k, ...))) end
                        log("%s: %s", lvl == "err" and "ERROR" or "warning", table.concat(bits, " "))
                    end
                end
                return orig(...)
            end
        end
    end

    local function timed(tbl, key, label, with_state)
        local f = type(tbl) == "table" and tbl[key]
        if type(f) ~= "function" or tbl["_diag_" .. key] then return end
        tbl["_diag_" .. key] = true
        tbl[key] = function(...)
            if not on() then return f(...) end
            log(">> %s", label)
            local t0 = now_ms()
            local res = { pcall(f, ...) }
            local took = now_ms() - t0
            if not res[1] then
                log("<< %s FAILED after %d ms: %s", label, took, tostring(res[2]))
                error(res[2], 0)
            end
            log("<< %s done in %d ms%s", label, took, with_state and ("; " .. state()) or "")
            return unpack(res, 2)
        end
    end

    -- Hooked lazily, when each module is first around (checked on every
    -- full-screen show; a no-op once done).
    local hooked = {}
    local function hookModules()
        if not hooked.park then
            local P = package.loaded["lib/bookshelf_reader_park"]
            if type(P) == "table" then
                hooked.park = true
                timed(P, "park", "Bookshelf: hold the book open behind the shelf (Instant book close)", true)
                if type(P.enabled) == "function" then
                    local okE, en = pcall(P.enabled)
                    log("Bookshelf Instant book close: %s", okE and (en and "ON" or "off") or "?")
                end
                -- called on every Close Bookshelf; true only when a book was held
                local cs = P.closeShelfToFileManager
                if type(cs) == "function" then
                    P.closeShelfToFileManager = function(...)
                        local held = park()
                        local res = { cs(...) }
                        if on() then
                            log("Bookshelf: Close Bookshelf -> %s", res[1]
                                and "a book WAS held: closing it, then going to the stock library"
                                or ("no book held: plain close" .. (held and " (but park said held?)" or "")))
                        end
                        return unpack(res)
                    end
                end
            end
        end
        if not hooked.sui then
            local Pt = package.loaded["infra/sui_patches"]
            if type(Pt) == "table" then
                hooked.sui = true
                timed(Pt, "closeReaderToHomescreen", "SimpleUI: close the book to the home screen", true)
                timed(Pt, "closeReaderToLibrary", "SimpleUI: close the book to the library", true)
            end
        end
        if not hooked.rui then
            local RUI = package.loaded["apps/reader/readerui"]
            if type(RUI) == "table" then
                hooked.rui = true
                timed(RUI, "onClose", "reader: close the book (screen blocked while it saves)", false)
            end
        end
    end
    local orig_show3 = UIManager.show
    UIManager.show = function(self, w, ...)
        if on() then pcall(hookModules) end
        return orig_show3(self, w, ...)
    end

    -- the toggle in Bookshelf's menu tab
    userpatch.registerPatchPluginFunc("bookshelf", function()
        if not on() then return end
        local sui_start = G_reader_settings and G_reader_settings:readSetting("start_with")
        log("Bookshelf loaded | KOReader start with: %s", q(sui_start))
        pcall(hookModules)
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

-- --------------------------------------------------------------------------
-- 6. Slowdown finder: where the time goes
-- Plugin event handlers and start-up, timers, input events, window paints,
-- wake-up. Things over SLOW_MS are logged as they happen; everything over
-- NOTE_MS is summed per source into the per-minute summary.
-- --------------------------------------------------------------------------
if ok_ui and type(UIManager) == "table" then
    local SLOW_MS, NOTE_MS = 80, 15
    local spent = {}   -- key -> { n, total, max }
    local function note(key, ms)
        if ms < NOTE_MS then return end
        local e = spent[key]
        if not e then e = { 0, 0, 0 }; spent[key] = e end
        e[1], e[2] = e[1] + 1, e[2] + ms
        if ms > e[3] then e[3] = ms end
    end
    local function pk(...) return { n = select("#", ...), ... } end
    local function short(src)
        return (tostring(src):gsub("^%./", ""):gsub("^.-plugins/", "plugins/"))
    end

    SUMMARY_EXTRA[#SUMMARY_EXTRA + 1] = function()
        local list = {}
        for k, e in pairs(spent) do list[#list + 1] = { k, e } end
        spent = {}
        table.sort(list, function(a, b) return a[2][2] > b[2][2] end)
        local bits = {}
        for i = 1, math.min(8, #list) do
            local k, e = list[i][1], list[i][2]
            bits[#bits + 1] = string.format("%s %d ms (%dx, max %d)", k, e[2], e[1], e[3])
        end
        if #bits > 0 then log("  where the time went: %s", table.concat(bits, "; ")) end
        log("  Lua memory: %.1f MB", collectgarbage("count") / 1024)
    end

    -- Plugins: every on<Event> handler of every plugin, timed per plugin.
    -- Wrapped on the instance; the class method is looked up at call time,
    -- so patches that change the class later still apply.
    local function wrapPlugin(cls, inst)
        if type(cls) ~= "table" or type(inst) ~= "table" or rawget(inst, "_diag_timed") then return end
        inst._diag_timed = true
        local name = tostring(cls.name or "?")
        for k, v in pairs(cls) do
            if type(k) == "string" and k:match("^on%u") and type(v) == "function" and rawget(inst, k) == nil then
                inst[k] = function(self, ...)
                    local f = cls[k] or v
                    if not on() then return f(self, ...) end
                    local t0 = now_ms()
                    local res = pk(f(self, ...))
                    local dt = now_ms() - t0
                    note(name .. ":" .. k:sub(3), dt)
                    if dt >= SLOW_MS then log("slow: plugin %s, %s took %d ms", name, k:sub(3), dt) end
                    return unpack(res, 1, res.n)
                end
            end
        end
    end

    local ok_pl, PluginLoader = pcall(require, "pluginloader")
    if ok_pl and type(PluginLoader) == "table" and type(PluginLoader.createPluginInstance) == "function" then
        local orig_create = PluginLoader.createPluginInstance
        local burst = nil
        PluginLoader.createPluginInstance = function(self, plugin, attr)
            if not on() then return orig_create(self, plugin, attr) end
            local t0 = now_ms()
            local res = pk(orig_create(self, plugin, attr))
            local dt = now_ms() - t0
            local name = tostring(type(plugin) == "table" and plugin.name or "?")
            if res[1] and type(res[2]) == "table" then pcall(wrapPlugin, plugin, res[2]) end
            -- one line per batch (all plugins start together when the file
            -- browser or a book opens)
            if not burst then
                burst = { n = 0, total = 0, list = {} }
                UIManager:nextTick(function()
                    local b = burst
                    burst = nil
                    if not b or not on() then return end
                    table.sort(b.list, function(x, y) return x[2] > y[2] end)
                    local top = {}
                    for i = 1, math.min(6, #b.list) do
                        if b.list[i][2] >= 5 then top[#top + 1] = b.list[i][1] .. " " .. b.list[i][2] end
                    end
                    local R = package.loaded["apps/reader/readerui"]
                    log("plugins started for the %s: %d in %d ms%s",
                        (type(R) == "table" and R.instance) and "book" or "file browser", b.n, b.total,
                        #top > 0 and (" (slowest: " .. table.concat(top, ", ") .. ")") or "")
                end)
            end
            burst.n, burst.total = burst.n + 1, burst.total + dt
            burst.list[#burst.list + 1] = { name, dt }
            note(name .. ":start", dt)
            return unpack(res, 1, res.n)
        end
    end

    -- Timers: timed by the shared perf core (one copy of KOReader's timer
    -- loop for every diagnostic, see above); every timer, whoever's.
    DiagCore.register({
        on = on,
        handle = function(kind, fn, dt)
            if kind ~= "timer" or dt < NOTE_MS then return end
            local w = short(where(fn))
            note("timer " .. w, dt)
            if dt >= SLOW_MS then log("slow: timer %s took %d ms", w, dt) end
        end,
    })

    -- Input events (taps, swipes, keys) and broadcasts (sleep, wake, ...)
    local function evName(event)
        if type(event) ~= "table" then return "?" end
        local h = tostring(event.handler or "?"):gsub("^on", "")
        if h == "Gesture" then
            local ges = event.args and event.args[1]
            if type(ges) == "table" and ges.ges then h = "Gesture " .. tostring(ges.ges) end
        end
        return h
    end
    local orig_send = UIManager.sendEvent
    if type(orig_send) == "function" then
        UIManager.sendEvent = function(self, event, ...)
            if not on() then return orig_send(self, event, ...) end
            local t0 = now_ms()
            local res = pk(orig_send(self, event, ...))
            local dt = now_ms() - t0
            local n = evName(event)
            note("event " .. n, dt)
            if dt >= SLOW_MS then log("slow: %s handled in %d ms", n, dt) end
            return unpack(res, 1, res.n)
        end
    end
    local woke_at
    local orig_bc = UIManager.broadcastEvent
    if type(orig_bc) == "function" then
        UIManager.broadcastEvent = function(self, event, ...)
            if not on() then return orig_bc(self, event, ...) end
            local t0 = now_ms()
            local res = pk(orig_bc(self, event, ...))
            local dt = now_ms() - t0
            local n = evName(event)
            note("broadcast " .. n, dt)
            if dt >= SLOW_MS then log("slow: broadcast %s took %d ms", n, dt) end
            if n == "Resume" then woke_at = t0 end
            return unpack(res, 1, res.n)
        end
    end

    -- Wake-up: from the Resume event to the first real screen update
    local orig_rp6 = UIManager._repaint
    if type(orig_rp6) == "function" then
        UIManager._repaint = function(self, ...)
            local res = pk(orig_rp6(self, ...))
            if woke_at and PAINT.real and on() then
                log("wake-up: screen ready %d ms after waking", now_ms() - woke_at)
                woke_at = nil
            end
            return unpack(res, 1, res.n)
        end
    end

    -- Window paints: each top-level window's drawing time, for the redraw
    -- breakdown (drawing vs. the e-ink screen update)
    local function wname6(w)
        if w.name == "homescreen" then return "SimpleUI home" end
        local FM = package.loaded["apps/filemanager/filemanager"]
        if type(FM) == "table" and FM.instance == w then return "file browser" end
        local n = w.name or w.title
        if n then return tostring(n) end
        if type(w[1]) == "table" and w[1].tab_item_table then return "menu" end
        return w.covers_fullscreen and "full-screen window" or "dialog"
    end
    local orig_show6 = UIManager.show
    UIManager.show = function(self, w, ...)
        if on() and type(w) == "table" and type(w.paintTo) == "function" and not rawget(w, "_diag_paint") then
            w._diag_paint = true
            local wn = wname6(w)
            local orig_paint = w.paintTo
            w.paintTo = function(this, ...)
                if not (PAINT.parts and on()) then return orig_paint(this, ...) end
                local t0 = now_ms()
                local res = pk(orig_paint(this, ...))
                local dt = now_ms() - t0
                PAINT.parts[#PAINT.parts + 1] = { wn, dt }
                note("draw " .. wn, dt)
                return unpack(res, 1, res.n)
            end
        end
        return orig_show6(self, w, ...)
    end
end

-- --------------------------------------------------------------------------
-- 7. White flashes: which refreshes flash, and why
-- KOReader flashes the panel (briefly white/black) for "full", "flashui"
-- and "flashpartial" refreshes. Some are asked for directly; others are
-- normal "partial" updates that KOReader promotes to a flash every N
-- updates (its Full refresh rate setting) to clear ghosting.
-- --------------------------------------------------------------------------
if ok_ui and type(UIManager) == "table" and type(UIManager._refresh) == "function" then
    local FLASH = { full = true, flashui = true, flashpartial = true }
    local logged = setmetatable({}, { __mode = "k" })
    local pending_src, func_src
    local flashes = {}
    local function pk7(...) return { n = select("#", ...), ... } end

    local function src(from)
        for lvl = from, from + 6 do
            local info = debug.getinfo(lvl, "Sl")
            if not info then break end
            local f = info.short_src or "?"
            if not f:find("uimanager%.lua") and not f:find("diagnostics") then
                return (f:gsub("^%./", ""):gsub("^.-plugins/", "plugins/")) .. ":" .. tostring(info.currentline)
            end
        end
        return "?"
    end

    local function onScreen()
        local st = UIManager._window_stack
        for i = #(st or {}), 1, -1 do
            local w = st[i].widget
            if type(w) == "table" and not w.invisible and not w.toast then
                if w.name == "homescreen" then return "SimpleUI home" end
                local FM = package.loaded["apps/filemanager/filemanager"]
                if type(FM) == "table" and FM.instance == w then return "file browser" end
                if w.name == "ReaderUI" then return "book" end
                if type(w[1]) == "table" and w[1].tab_item_table then return "menu" end
                return tostring(w.name or w.title or (w.covers_fullscreen and "full-screen window" or "dialog"))
            end
        end
        return "?"
    end

    do
        local avoid = G_reader_settings and G_reader_settings:isTrue("avoid_flashing_ui")
        log("screen settings: avoid flashing in menus/UI %s | full refresh every %s partial updates",
            avoid and "ON" or "off", tostring(UIManager.FULL_REFRESH_COUNT or "?"))
    end

    local orig_sd7 = UIManager.setDirty
    UIManager.setDirty = function(self, widget, refreshtype, ...)
        if not on() then return orig_sd7(self, widget, refreshtype, ...) end
        local where_from = src(3)
        if type(refreshtype) == "function" then
            local fn = refreshtype
            refreshtype = function(...)
                local r = pk7(fn(...))
                func_src = where_from
                return unpack(r, 1, r.n)
            end
        else
            pending_src = where_from
        end
        local res = pk7(orig_sd7(self, widget, refreshtype, ...))
        pending_src = nil
        return unpack(res, 1, res.n)
    end

    local orig_ref = UIManager._refresh
    UIManager._refresh = function(self, mode, region, ...)
        if not on() then return orig_ref(self, mode, region, ...) end
        local asked_by = pending_src or func_src or src(3)
        func_src = nil
        local res = { orig_ref(self, mode, region, ...) }
        for _i, r in ipairs(self._refresh_stack or {}) do
            if type(r) == "table" and FLASH[r.mode] and not logged[r] then
                logged[r] = true
                local rg = r.region
                local full = rg and rg.x == 0 and rg.y == 0 and rg.w >= Screen:getWidth() and rg.h >= Screen:getHeight()
                local why = FLASH[mode] and ("asked for " .. tostring(mode))
                    or (mode == "partial" and "KOReader's periodic full refresh (normal update promoted)")
                    or ("asked for " .. tostring(mode) .. ", merged into a flash")
                local area = full and "whole screen"
                    or (rg and string.format("%dx%d at %d,%d", rg.w, rg.h, rg.x, rg.y) or "?")
                local where_on = onScreen()
                log("FLASH %s: %s on %s | %s | by %s", tostring(r.mode), area, where_on, why, asked_by)
                local key = where_on .. ": " .. why .. " by " .. asked_by
                flashes[key] = (flashes[key] or 0) + 1
            end
        end
        return unpack(res)
    end

    SUMMARY_EXTRA[#SUMMARY_EXTRA + 1] = function()
        local list = {}
        for k, n in pairs(flashes) do list[#list + 1] = { k, n } end
        flashes = {}
        table.sort(list, function(a, b) return a[2] > b[2] end)
        local bits = {}
        for i = 1, math.min(6, #list) do bits[#bits + 1] = list[i][2] .. " x " .. list[i][1] end
        if #bits > 0 then log("  white flashes: %s", table.concat(bits, "; ")) end
    end
end

-- --------------------------------------------------------------------------
-- 8. New Books: why a newly added book does (or doesn't) show
--    What SimpleUI's "new_books" list returns (logged when it changes), the
--    newest books its library scan sees, and, once per start, the newest
--    files actually on disk under the home folder with the reason SimpleUI
--    leaves any of them out (file type, hidden folder, too deep, scan cap).
--    Plus each book the list drops as finished.
-- --------------------------------------------------------------------------
do
    local function day(t) return t and os.date("%Y-%m-%d %I:%M %p", t) or "?" end
    local function base(fp) return tostring(fp):match("([^/]+)$") or tostring(fp) end

    -- Independent walk: every file, hidden folders included, deeper than
    -- SimpleUI goes. Notes why SimpleUI's own scan would skip each one.
    local SIMPLEUI_EXTS = { epub = true, mobi = true, azw3 = true, azw = true, kfx = true,
        pdf = true, djvu = true, fb2 = true, cbz = true, cbr = true,
        doc = true, docx = true, rtf = true, txt = true }
    local NOT_BOOKS = { sdr = true, lua = true, json = true, jpg = true, jpeg = true, png = true,
        db = true, log = true, opf = true, calibre = true, old = true, xml = true, ini = true }
    local function diskNewest(home)
        local out, count = {}, 0
        local function walk(dir, depth, hidden)
            if depth > 12 or count > 40000 then return end
            local ok, iter, obj = pcall(lfs.dir, dir)
            if not ok or type(iter) ~= "function" then return end
            for e in iter, obj do
                count = count + 1
                if e ~= "." and e ~= ".." then
                    local fp = dir .. "/" .. e
                    local a = lfs.attributes(fp)
                    if a and a.mode == "directory" then
                        if e:sub(-4) ~= ".sdr" then walk(fp, depth + 1, hidden or e:sub(1, 1) == ".") end
                    elseif a and a.mode == "file" then
                        local ext = (e:match("%.([^%.]+)$") or ""):lower()
                        if not NOT_BOOKS[ext] and e:sub(1, 1) ~= "." then
                            local why
                            if not SIMPLEUI_EXTS[ext] then why = "file type ." .. ext .. " not in SimpleUI's list"
                            elseif hidden then why = "inside a hidden folder (name starts with .)"
                            elseif depth > 8 then why = "folder too deep (SimpleUI goes 8 levels)" end
                            out[#out + 1] = { fp = fp, mtime = a.modification or 0, why = why }
                        end
                    end
                end
            end
        end
        walk(home, 0, false)
        table.sort(out, function(x, y) return x.mtime > y.mtime end)
        return out, count
    end

    local disk_done = false
    local function reportScan()
        local okl, LS = pcall(require, "engines/sui_library_scan")
        if okl and type(LS) == "table" and type(LS.getRaw) == "function" then
            local okh, home = pcall(LS.resolveHomeDir)
            local okr, raw = pcall(LS.getRaw, okh and home or nil)
            if okr and type(raw) == "table" then
                table.sort(raw, function(x, y) return (x.mtime or 0) > (y.mtime or 0) end)
                local top = {}
                for i = 1, math.min(5, #raw) do
                    top[#top + 1] = string.format("%s (%s)", base(raw[i].fp), day(raw[i].mtime))
                end
                log("new books: SimpleUI's scan of %s sees %d books; newest: %s",
                    tostring(home), #raw, table.concat(top, " | "))
            end
            if not disk_done then
                disk_done = true
                local t1 = now_ms()
                local files, n = diskNewest(home)
                local seen = {}
                if okr and type(raw) == "table" then for _i, r in ipairs(raw) do seen[r.fp] = true end end
                log("new books: newest files on disk under %s (%d entries walked, %d ms):",
                    tostring(home), n, now_ms() - t1)
                for i = 1, math.min(8, #files) do
                    local f = files[i]
                    local status = f.why and ("SKIPPED: " .. f.why)
                        or (seen[f.fp] and "in SimpleUI's scan")
                        or "NOT in SimpleUI's scan (scan cap of 20000 entries reached, or scan not refreshed yet)"
                    log("  %d. %s (%s) - %s", i, f.fp, day(f.mtime), status)
                end
            end
        end
    end

    local function hookSources()
        local okS, Sources = pcall(require, "engines/sui_book_sources")
        if not okS or type(Sources) ~= "table" or type(Sources.get) ~= "function" then
            log("new books: SimpleUI without book sources (2.7.5 release): checking its library scan once")
            pcall(reportScan)
            return
        end
        local okg, src = pcall(Sources.get, "new_books")
        if not okg or type(src) ~= "table" or type(src.getFileList) ~= "function" then
            log("new books: no \"new_books\" source in SimpleUI")
            return
        end
        if src._sui_diag then return end
        src._sui_diag = true
        local last_list, dropped = nil, {}

        local orig_list = src.getFileList
        src.getFileList = function(...)
            local t0 = now_ms()
            local res = { orig_list(...) }
            if not on() then return unpack(res) end
            local list = res[1]
            local key = type(list) == "table" and table.concat(list, "\n") or tostring(list)
            if key ~= last_list then
                last_list = key
                local names = {}
                for i = 1, math.min(8, type(list) == "table" and #list or 0) do
                    local m = lfs.attributes(list[i], "modification")
                    names[#names + 1] = string.format("%d. %s (%s)", i, base(list[i]), day(m))
                end
                log("new books: list changed (%d candidates, %d ms): %s",
                    type(list) == "table" and #list or 0, now_ms() - t0,
                    #names > 0 and table.concat(names, " | ") or "(empty)")
                reportScan()
            end
            return unpack(res)
        end

        if type(src.filterItem) == "function" then
            local orig_filter = src.filterItem
            src.filterItem = function(fp, ...)
                local keep = orig_filter(fp, ...)
                if not keep and on() and not dropped[fp] then
                    dropped[fp] = true
                    log("new books: left out as finished: %s", base(fp))
                end
                return keep
            end
        end
        log("new books: watching SimpleUI's \"new_books\" list")
    end

    userpatch.registerPatchPluginFunc("simpleui", function()
        local ok, err = pcall(hookSources)
        if not ok then log("new books: couldn't hook (%s)", tostring(err)) end
    end)
end

-- --------------------------------------------------------------------------
-- 9. Reading Log for SimpleUI (simpleui_readinglog.koplugin)
--    The plugin logs its own builds, taps and refreshes through this file's
--    log (package.loaded["simpleui_diagnostics"]); these are the checks it
--    can't make about itself: is it installed whole, did its modules reach
--    SimpleUI's registry, which are switched on, and Reading Log's own
--    "[almanac]" notes.
-- --------------------------------------------------------------------------
do
    local RL_ID = "simpleui_readinglog"
    local RL_FILES = { "main.lua", "_meta.lua", "readinglog/almanac/init.lua", "readinglog/almanac/data.lua",
        "readinglog/almanac/panels.lua", "readinglog/almanac/settings.lua", "readinglog/almanac/modules.lua",
        "readinglog/almanac/host.lua", "readinglog/almanac/menus.lua", "readinglog/almanac/colourtext.lua" }

    -- Reading Log writes its notable events at info level, tagged "[almanac]"
    local logger = require("logger")
    local orig_info = logger.info
    if type(orig_info) == "function" then
        logger.info = function(...)
            if on() then
                local first = tostring((...))
                if first:find("almanac", 1, true) or first:find("readinglog", 1, true) then
                    local bits = {}
                    for k = 1, math.min(select("#", ...), 8) do bits[#bits + 1] = tostring((select(k, ...))) end
                    log("readinglog: kit note: %s", table.concat(bits, " "))
                end
            end
            return orig_info(...)
        end
    end

    local function registryCheck()
        local Reg = package.loaded["modules/moduleregistry"]
        if type(Reg) ~= "table" then
            log("readinglog: SimpleUI module registry not loaded yet")
            return
        end
        local okl, list = pcall(Reg.list)
        if not okl or type(list) ~= "table" then
            log("readinglog: couldn't list SimpleUI modules (%s)", tostring(list))
            return
        end
        local found, on_list = 0, {}
        for _i, m in ipairs(list) do
            if type(m) == "table" and type(m.id) == "string" and m.id:find("^readinglog_") then
                found = found + 1
                local oke, en = pcall(Reg.isEnabled, m, "simpleui_hs_")
                if oke and en then on_list[#on_list + 1] = m.id end
            end
        end
        log("readinglog: %d Reading Log modules in SimpleUI's registry (expected 34); switched on: %s",
            found, #on_list > 0 and table.concat(on_list, ", ") or "(none)")
        if found == 0 then
            log("readinglog: NOT REGISTERED - modules won't appear in SimpleUI's list")
        end
    end

    userpatch.registerPatchPluginFunc(RL_ID, function(plugin)
        if not on() then return end
        local path = type(plugin) == "table" and plugin.path
        local ver = "?"
        if path then pcall(function() ver = (dofile(path .. "/_meta.lua") or {}).version or "?" end) end
        log("readinglog: plugin %s at %s", tostring(ver), q(path))
        if path then
            local missing = {}
            for _i, f in ipairs(RL_FILES) do
                if lfs.attributes(path .. "/" .. f, "mode") ~= "file" then missing[#missing + 1] = f end
            end
            log("readinglog: files %s", #missing == 0 and "all present"
                or ("MISSING: " .. table.concat(missing, ", ") .. " (copy the whole folder again)"))
        end
        local settings = DataStorage:getSettingsDir() .. "/simpleui_readinglog.lua"
        log("readinglog: settings file %s", lfs.attributes(settings, "mode") == "file"
            and string.format("present (%d bytes)", lfs.attributes(settings, "size") or 0)
            or "not created yet (nothing changed from defaults)")
        local bs = DataStorage:getSettingsDir() .. "/bookshelf/micromodules/alm_dashboard.lua"
        if lfs.attributes(bs, "mode") == "file" then
            log("readinglog: Bookshelf copy of Reading Log also installed (fine: separate settings, they don't share)")
        end
        if not package.loaded["simpleui"] and not package.loaded["modules/moduleregistry"] then
            log("readinglog: SimpleUI not loaded when this plugin started (it registers on the next tick)")
        end
    end)

    -- Registry check once per start, when the SimpleUI home first shows
    -- (after the plugin's next-tick registration; no timer of our own).
    local ok_u, UIM = pcall(require, "ui/uimanager")
    if ok_u and type(UIM) == "table" then
        local checked = false
        local orig_show9 = UIM.show
        UIM.show = function(self, w, ...)
            local res = { orig_show9(self, w, ...) }
            if not checked and on() and type(w) == "table" and w.name == "homescreen" then
                checked = true
                self:nextTick(function() if on() then pcall(registryCheck) end end)
            end
            return unpack(res)
        end
    end
end

-- --------------------------------------------------------------------------
-- 10. Swipe tracer (home screen only)
--     Each swipe or pan on the SimpleUI home: direction, distance, speed,
--     the page before/after (a page turn), then Reading Log's redraw of its
--     swipe card: when it asked (+ms from lift), when the screen refresh
--     finished, and any further Reading Log redraw within 3 s (covers or
--     data landing). Nothing is hooked into the reader's own pages.
-- --------------------------------------------------------------------------
do
    local ok_u, UIM = pcall(require, "ui/uimanager")
    if ok_u and type(UIM) == "table" and type(UIM.sendEvent) == "function" then
        local TR = nil -- the swipe being traced
        local FOLLOW_MS = 3000

        local function topWidget()
            local st = UIM._window_stack
            local top = type(st) == "table" and st[#st]
            return type(top) == "table" and top.widget or nil
        end
        local function onHome()
            local w = topWidget()
            return type(w) == "table" and w.name == "homescreen", w
        end
        local function pageOf(w)
            return type(w) == "table" and tonumber(w._current_page) or nil
        end
        local function fromReadingLog()
            for lvl = 3, 6 do
                local info = debug.getinfo(lvl, "S")
                if not info then break end
                local src = info.source or ""
                if src:find("simpleui_readinglog", 1, true) then return true end
            end
            return false
        end
        local function expired()
            if TR and now_ms() - TR.t0 > FOLLOW_MS then
                if TR.redraws == 0 then
                    log("  swipe trace: no Reading Log redraw (%s)", TR.page_note or "page unchanged")
                end
                TR = nil
            end
        end

        local orig_send10 = UIM.sendEvent
        UIM.sendEvent = function(self, event, ...)
            if not (on() and type(event) == "table" and event.handler == "onGesture") then
                return orig_send10(self, event, ...)
            end
            local ges = event.args and event.args[1]
            local kind = type(ges) == "table" and ges.ges
            -- a tap starts something else: stop following the last swipe
            if kind == "tap" or kind == "hold" then TR = nil end
            if kind ~= "swipe" and kind ~= "pan_release" and kind ~= "two_finger_swipe" then
                return orig_send10(self, event, ...)
            end
            local home, w = onHome()
            if not home then return orig_send10(self, event, ...) end
            expired()
            local pos = type(ges.pos) == "table" and ges.pos or {}
            local dist = tonumber(ges.distance) or 0
            local before = pageOf(w)
            local t0 = now_ms()
            log("SWIPE %s %s from %s,%s, %d px | page %s",
                tostring(kind), tostring(ges.direction), tostring(pos.x), tostring(pos.y), dist, q(before))
            TR = { t0 = t0, dir = ges.direction, redraws = 0, asked = nil, painted = false }
            local res = { orig_send10(self, event, ...) }
            local handled_ms = now_ms() - t0
            local _h, w2 = onHome()
            local after = pageOf(w2)
            if before and after and before ~= after then
                TR.page_note = "SimpleUI turned page " .. before .. " -> " .. after
                log("  -> SimpleUI page turn %s -> %s (%d ms)", q(before), q(after), handled_ms)
            elseif handled_ms > 80 then
                log("  -> handled in %d ms", handled_ms)
            end
            return unpack(res)
        end

        local orig_sd10 = UIM.setDirty
        UIM.setDirty = function(self, widget, ...)
            if TR and on() then
                expired()
                if TR and fromReadingLog() then
                    TR.redraws = TR.redraws + 1
                    local dt = now_ms() - TR.t0
                    if TR.redraws == 1 then
                        TR.asked = now_ms()
                        log("  swipe trace: Reading Log redraw asked +%d ms after lift", dt)
                    else
                        log("  swipe trace: extra Reading Log redraw #%d +%d ms (covers/data landing?)", TR.redraws, dt)
                    end
                    TR.painted = false
                end
            end
            return orig_sd10(self, widget, ...)
        end

        local orig_rp10 = UIM._repaint
        if type(orig_rp10) == "function" then
            UIM._repaint = function(self, ...)
                -- a redraw asked for during this repaint (Reading Log's page
                -- turn flash is asked while the page is drawn) counts too
                if not (TR and not TR.painted and on()) then return orig_rp10(self, ...) end
                local t1 = now_ms()
                local res = { orig_rp10(self, ...) }
                local took = now_ms() - t1
                if TR and TR.asked and not TR.painted and took > 0 then
                    TR.painted = true
                    log("  swipe trace: on screen +%d ms after lift (this redraw %d ms)", now_ms() - TR.t0, took)
                end
                return unpack(res)
            end
        end
    end
end
