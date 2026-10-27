--[[
2-zz-bookorbit-diagnostics.lua - TEMPORARY troubleshooting patch for BookOrbit
Version 1.3.1

For the hang where opening BookOrbit does nothing and KOReader has to be
restarted, and for the freeze after sleep. It changes nothing about how
BookOrbit runs: it only writes lines to the shared log, so the last line
before a freeze shows exactly where it stopped.

Changelog
  1.3.1 Wording only: header and log text rewritten direct and plain;
        no functionality, behavior, or menu changes.
  1.3.0 Shared perf core (the same block the SimpleUI and other
        diagnostics use): it times every BookOrbit and BookOrbit Tweaks
        timer, logs slow ones with their file, logs screen updates and
        flashes with who asked for them (so the tweaks' ghosting flash
        shows up as FLASH lines), logs timers left waiting when the
        device sleeps, and writes a once-a-minute line with Lua memory
        and covers built. The 10-second heartbeat timer is gone (no
        timers rule): while the catalog is open, a timer holding the
        screen 250 ms+ or a tap 1 s+ is logged instead. Freeze time is
        now the last line written. Suspend / Resume still log the full
        window stack.
  1.2.0 Window stack and early return: Suspend, Resume, heartbeat,
        openCatalogBrowser exit and onCloseWidget exit now log the
        full window stack by name (bottom to top), the topmost visible
        window, and where the BookOrbit catalog sits in the stack (or
        that it is absent). openCatalogBrowser now logs explicitly
        when it early-returns because a catalog already exists -- the
        "nothing happens" case: the call finishes in ~0 ms, shows
        nothing, and leaves whatever was on top (e.g. the SimpleUI
        home screen after wake) on top. Paint-time board-cover logging
        is NOT in this version (that was a separate, not-yet-approved
        offer); creation-time board-cover logging from v1.1.0 stays.
  1.1.0 Sleep/wake and covers: Suspend and Resume are now logged (via
        UIManager broadcast/sendEvent, plus BookOrbit's own _onSuspend /
        _onResume when it handles them), and the heartbeat pauses while
        asleep, so a sleep gap no longer looks like a freeze. The
        catalog-open flag is fixed: it is set on a successful
        openCatalogBrowser, not read off the plugin instance (v1.0.0's
        "catalog browser=absent" was wrong). Cover building is logged:
        buildCoverWidget (path, state, KOReader night mode, the tweaks
        toggle state, and the finished image's original_in_nightmode
        flag) for the first 8 covers and every 50th after, plus the
        first 3 dashboard board cover creations. The tweaks toggle state is also
        logged at plugin instantiation. v1.0.0's premise note: KOReader
        core's ImageWidget already defaults original_in_nightmode to
        true, so the tweaks toggle setting it to true is a no-op on
        current core -- the cover logging here is what shows where an
        inverted cover actually comes from.

Shared log contract v1: writes tagged lines ("[bookorbit]") to the ONE
shared diagnostics file:  koreader/diagnostics.log
(Kobo: .adds/koreader/diagnostics.log)

It logs for the first 30 minutes after KOReader starts (WINDOW_MIN
below; time asleep counts). After that it goes quiet. Three days
after its first run it stops completely (one line per start says
so); delete bookorbit-diagnostics.state for another 3 days. It writes the log (and
that one-line state file), nothing else. No repeating timers: when the
device freezes, the last line written is the evidence.

What it logs, all on the open path and everything around it:
  - Start: this patch loaded, which patches are installed, which
    BookOrbit modules are already loaded, whether the plugin folder
    is present, and the plugin version once it instantiates.
  - Plugin instantiation: logged-in state, server host only (never the
    full URL, never a username, password or userkey), and whether
    KOReader thinks Wi-Fi is connected at that moment.
  - Every open step, timed, with an enter line BEFORE it runs and an
    exit line after: Open BookOrbit, browseCatalog, openCatalogBrowser,
    openSignIn, promptLogin, openMenuSheet, openSettings, openSyncStatus,
    and the manual sync triggers (sweep, progress push/pull, update
    check). If a step never gets its exit line, that step is where it
    hung. A step that throws logs FAILED with the error, then rethrows
    it, so BookOrbit still sees the same error it would have.
  - Catalog construction and refresh, timed: init, initialDashboardContext,
    refreshDashboardOnOpen, hydrateOnDeviceMaps, scheduleThumbnailDownloads,
    goDashboard, cancelThumbnailJobs, cleanLegacyThumbnails, onCloseWidget.
  - Every BookOrbit API call, timed, with method and path only (query
    strings stripped, bodies and headers never logged): request and
    requestBlocking, plus download and downloadBlocking. If a blocking network call never comes back, that's the freeze — its
    enter line with no exit line shows it.
  - BookOrbit warnings and errors from KOReader's logger, with any
    credential-looking values scrubbed out.
  - Performance (shared perf core): BookOrbit timers timed, screen updates
    and flashes with who asked, slow taps while the catalog is open, timers
    left waiting at sleep, and a per-minute summary with Lua memory.
  - Sleep/wake: Suspend and Resume events, BookOrbit's own suspend and
    resume handlers when they run, and how long the device slept.
  - Covers: every catalog cover build (first 8, then every 50th) with
    KOReader night mode on or off, the BookOrbit Tweaks toggle state,
    and the finished image widget's original_in_nightmode flag -- plus
    the first 3 dashboard board cover creations. If covers still come out
    inverted, these lines show whether the flag, the toggle, or the
    rendering path is the cause.

What it does NOT do, on purpose:
  - It never logs a username, password, userkey, auth header, request
    body, or response body. Paths are logged without their query string.
  - It never swallows an error, never retries a call, never touches
    Wi-Fi, and never changes a BookOrbit setting.
  - Every hook is guarded: if a function does not exist on your plugin
    version (the code was read against main 2.0.0, your device plugin
    may be 1.5.4), it logs "not found" instead of breaking anything.
    That missing-function list is itself useful: it shows what your
    version actually has.

How to use (within 30 minutes of starting KOReader):
  1. Put this file in koreader/patches/ and restart KOReader.
  2. Try to open BookOrbit exactly as it normally hangs. Do NOT restart
     yet if you can avoid it: note the clock time when it freezes.
  3. If KOReader is fully stuck, restart it, then send
     koreader/diagnostics.log straight away, before doing anything
     else with BookOrbit (a new run appends to the same log, and the
     lines from the frozen run are the ones that matter).
  4. Delete this file when done. The Debugging Menu can also switch it
     off (it moves to patches/debug/).

The "zz" makes it load after every other patch, so it sees their changes.
BookOrbit Tweaks v2.11.1 and this diagnostic v1.3.1 are on GitHub.
Future patch pushes still need TK's go-ahead each time.
]]

local DataStorage = require("datastorage")
local lfs = require("libs/libkoreader-lfs")

local WINDOW_MIN = 30
local WINDOW_S = WINDOW_MIN * 60
local EXPIRE_S = 3 * 24 * 3600
local STATE = DataStorage:getDataDir() .. "/bookorbit-diagnostics.state"
local DIAG_VERSION = "1.3.1"
local DIAG_TAG = "bookorbit"
local SHARED_LOG = DataStorage:getDataDir() .. "/diagnostics.log"
local SHARED_MAX_BYTES = 2 * 1024 * 1024
local HEARTBEAT_S = 10

local started = os.time()
local active = true
local catalog_open = false
local catalog_widget = nil
local suspended = false
local windowStackText
local suspend_started = nil
local cover_count = 0
local board_paint_count = 0

if package.loaded["bookorbit_diagnostics_patch"] then
    return
end
package.loaded["bookorbit_diagnostics_patch"] = true

local now_ms
do
    local ok, time = pcall(require, "ui/time")
    if ok and type(time) == "table" and time.now and time.to_ms then
        now_ms = function() return time.to_ms(time.now()) end
    else
        now_ms = function() return math.floor(os.clock() * 1000) end
    end
end

local BIDI = { "\226\129\166", "\226\129\167", "\226\129\168", "\226\129\169",
    "\226\128\170", "\226\128\171", "\226\128\172", "\226\128\173", "\226\128\174" }

-- Scrub anything credential-shaped before it can reach the log.
local function scrub(s)
    s = tostring(s)
    s = s:gsub("userkey%s*=%s*[^,%s}]+", "userkey=[redacted]")
    s = s:gsub("password%s*=%s*[^,%s}]+", "password=[redacted]")
    s = s:gsub("x%-auth%-key%s*:%s*[^,%s}]+", "x-auth-key: [redacted]")
    s = s:gsub("Authorization%s*:%s*[^,%s}]+", "Authorization: [redacted]")
    if #s > 1200 then s = s:sub(1, 1200) .. "...(truncated)" end
    return s
end

local function oneLine(s)
    s = scrub(s)
    for i = 1, #BIDI do s = s:gsub(BIDI[i], "") end
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

local function write(line)
    shared_log("%s", line)
end

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

local function connected()
    local ok, NetworkMgr = pcall(require, "ui/network/manager")
    if not ok or type(NetworkMgr) ~= "table" or type(NetworkMgr.isConnected) ~= "function" then
        return "?"
    end
    local ok2, val = pcall(NetworkMgr.isConnected, NetworkMgr)
    if not ok2 then return "?" end
    return val and "yes" or "no"
end

-- Server host only: "https://books.example.com:8443/x" -> "https://books.example.com:8443".
-- Never the path, query, username or key.
local function serverHost(url)
    if type(url) ~= "string" or url == "" then return "(none)" end
    local host = url:match("^(https?://[^/%?#]+)")
    return host or "(unparsable)"
end

local function serverUrlOf(plugin)
    if type(plugin) ~= "table" then return nil end
    if type(plugin.server_url) == "string" then return plugin.server_url end
    if type(plugin.settings) == "table" and type(plugin.settings.server_url) == "string" then
        return plugin.settings.server_url
    end
    return nil
end

-- Hard expiry: version on line 1, first run on line 2.
do
    local first
    local f = io.open(STATE, "r")
    if f then
        local v, t = f:read("*l"), tonumber(f:read("*l") or "")
        f:close()
        if v == DIAG_VERSION and t and t <= os.time() then first = t end
    end
    if not first then
        first = os.time()
        local w = io.open(STATE, "w")
        if w then w:write(DIAG_VERSION, "\n", first, "\n") w:close() end
    end
    if os.difftime(os.time(), first) > EXPIRE_S then
        write("bookorbit diagnostics " .. DIAG_VERSION .. " expired (first run " .. os.date("%Y-%m-%d %I:%M %p", first)
            .. "): not watching anything. Delete this patch, or delete bookorbit-diagnostics.state for 3 more days.")
        return
    end
end

package.loaded["bookorbit_diagnostics"] = { log = log, on = on }

write("==================== bookorbit diagnostics " .. DIAG_VERSION .. " started (logging for " .. WINDOW_MIN .. " minutes) ====================")

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
    local plugin_main = DataStorage:getDataDir() .. "/plugins/bookorbit.koplugin/main.lua"
    log("plugin file %s: %s", plugin_main,
        lfs.attributes(plugin_main, "mode") == "file" and "exists" or "MISSING")
    local loaded = {}
    for name in pairs(package.loaded) do
        if type(name) == "string" and name:find("bookorbit", 1, true) then
            loaded[#loaded + 1] = name
        end
    end
    table.sort(loaded)
    log("bookorbit modules already loaded: %s", #loaded > 0 and table.concat(loaded, ", ") or "(none yet)")
end

-- No heartbeat timer (no-timers rule); the shared perf core at the end of this
-- file logs slow timers and taps while the catalog is open instead.

-- Suspend/Resume, via the same broadcast/sendEvent path KOReader itself
-- uses (Device:_beforeSuspend -> broadcastEvent "Suspend"). Logged before
-- the event is delivered, so a freeze in a suspend handler shows as
-- "Suspend" with no matching "Resume" -- and a freeze on wake shows as
-- "Resume" with nothing after it.
local function onPowerEvent(handler)
    if handler == "onSuspend" and not suspended then
        suspended = true
        suspend_started = os.time()
        if on() then
            log("Suspend: wifi connected=%s, catalog open=%s, stack=%s",
                connected(), catalog_open and "yes" or "no", windowStackText())
        end
    elseif handler == "onResume" and suspended then
        suspended = false
        local slept = suspend_started and (os.time() - suspend_started) or nil
        suspend_started = nil
        if on() then
            log("Resume: slept %s seconds, wifi connected=%s, catalog open=%s, stack=%s",
                slept and tostring(slept) or "?", connected(), catalog_open and "yes" or "no", windowStackText())
        end
    end
end
do
    local ok, UIManager = pcall(require, "ui/uimanager")
    if ok and type(UIManager) == "table" then
        if type(UIManager.broadcastEvent) == "function" and not UIManager._bookorbit_diag_broadcast then
            UIManager._bookorbit_diag_broadcast = true
            local orig = UIManager.broadcastEvent
            UIManager.broadcastEvent = function(self, ev, ...)
                if type(ev) == "table" then onPowerEvent(ev.handler) end
                return orig(self, ev, ...)
            end
        end
        if type(UIManager.sendEvent) == "function" and not UIManager._bookorbit_diag_send then
            UIManager._bookorbit_diag_send = true
            local orig = UIManager.sendEvent
            UIManager.sendEvent = function(self, ev, ...)
                if type(ev) == "table" then onPowerEvent(ev.handler) end
                return orig(self, ev, ...)
            end
        end
    end
end

-- BookOrbit warnings and errors from KOReader's logger. Other plugins'
-- lines are left alone.
do
    local ok, logger = pcall(require, "logger")
    if ok and type(logger) == "table" then
        for i = 1, 2 do
            local lvl = i == 1 and "warn" or "err"
            local orig = logger[lvl]
            if type(orig) == "function" and not logger["_bookorbit_diag_" .. lvl] then
                logger["_bookorbit_diag_" .. lvl] = true
                logger[lvl] = function(...)
                    if on() then
                        local first = tostring((...))
                        if first:lower():find("bookorbit", 1, true) then
                            local bits = {}
                            for k = 1, math.min(select("#", ...), 6) do
                                bits[#bits + 1] = tostring((select(k, ...)))
                            end
                            log("%s: %s", lvl == "err" and "ERROR" or "warning", table.concat(bits, " "))
                        end
                    end
                    return orig(...)
                end
            end
        end
    end
end

-- Generic timed wrapper: enter line, exit line with ms, FAILED + rethrow.
-- Missing functions are logged, never wrapped, so version differences
-- show up instead of breaking anything.
local function timed(tbl, key, label, state_fn)
    if type(tbl) ~= "table" then return false end
    local f = tbl[key]
    if type(f) ~= "function" then
        log("hook %s: not found (not in this plugin version)", label)
        return false
    end
    if tbl["_bookorbit_diag_" .. key] then return true end
    tbl["_bookorbit_diag_" .. key] = true
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
        local extra = ""
        if type(state_fn) == "function" then
            local ok, s = pcall(state_fn)
            if ok and s then extra = "; " .. tostring(s) end
        end
        log("<< %s done in %d ms%s", label, took, extra)
        return unpack(res, 2)
    end
    log("hook %s: applied", label)
    return true
end

-- API wrapper: same timing, plus method + path (query stripped, no body).
local function timedApi(tbl, key, label)
    if type(tbl) ~= "table" then return false end
    local f = tbl[key]
    if type(f) ~= "function" then
        log("hook %s: not found (not in this plugin version)", label)
        return false
    end
    if tbl["_bookorbit_diag_" .. key] then return true end
    tbl["_bookorbit_diag_" .. key] = true
    tbl[key] = function(self, method, path, ...)
        if not on() then return f(self, method, path, ...) end
        local clean_path = type(path) == "string" and path:gsub("%?.*$", "") or q(path)
        log(">> %s %s %s (wifi connected=%s)", label, q(method), clean_path, connected())
        local t0 = now_ms()
        local res = { pcall(f, self, method, path, ...) }
        local took = now_ms() - t0
        if not res[1] then
            log("<< %s %s FAILED after %d ms: %s", label, q(method), took, tostring(res[2]))
            error(res[2], 0)
        end
        local second = res[3]
        local second_txt = second == nil and "(nil)" or
            (type(second) == "number" and tostring(second)) or
            (type(second) == "string" and (#second <= 120 and second or second:sub(1, 120) .. "...")) or
            ("(" .. type(second) .. ")")
        log("<< %s %s done in %d ms, result=%s", label, q(method), took, second_txt)
        return unpack(res, 2)
    end
    log("hook %s: applied", label)
    return true
end

local function openState(plugin)
    -- v1.1.0 fix: the catalog flag is the diagnostics' own flag, set on a
    -- successful openCatalogBrowser. Reading plugin.catalog_browser was
    -- wrong in v1.0.0: the plugin instance the diagnostics hook sees is
    -- not the one opening the catalog, so it always read "absent".
    local parts = { "wifi connected=" .. connected(),
        "catalog open=" .. (catalog_open and "yes" or "no") }
    if type(plugin) == "table" then
        local ok, logged_in = pcall(function() return plugin:isLoggedIn() end)
        if ok then parts[#parts + 1] = "logged in=" .. tostring(logged_in) end
    end
    return table.concat(parts, ", ")
end

-- BookOrbit Tweaks toggle state, read live (not copied): the toggle is
-- what v1.0.0's cover fix depends on, so a cover line without it is
-- useless. Returns "on", "off", or "absent (tweaks not installed / no saved setting)".
local function tweaksToggle()
    local ok, saved = pcall(function()
        return G_reader_settings and G_reader_settings:readSetting("bookorbit_tweaks") or nil
    end)
    if not ok or type(saved) ~= "table" then return "absent" end
    if saved.no_invert_catalog_covers == true then return "on" end
    if saved.no_invert_catalog_covers == false then return "off" end
    return "absent"
end

local function nightMode()
    local ok, Screen = pcall(require, "device")
    if ok and type(Screen) == "table" and type(Screen.screen) == "table" then
        return Screen.screen.night_mode and "yes" or "no"
    end
    return "?"
end

-- Window stack, by name, bottom to top. KOReader widgets carry no class
-- name, so the name is built from what they do carry: id, name, title,
-- or text, plus fullscreen/modal/toast/invisible flags. The BookOrbit
-- catalog instance captured at open time is marked CATALOG, and the
-- topmost visible window is marked TOP. If the catalog is in the stack
-- but not on top, it is hidden underneath whatever is on top -- the
-- exact "SimpleUI home after wake" case. If it is absent from the stack
-- while catalog_open is still true, the flag is stale (the catalog was
-- removed without onCloseWidget firing).
local function widgetName(widget)
    if widget == catalog_widget then return "BookOrbit catalog" end
    if type(widget) ~= "table" then return tostring(widget) end
    local base = nil
    if type(widget.id) == "string" and widget.id ~= "" then base = widget.id
    elseif type(widget.name) == "string" and widget.name ~= "" then base = widget.name
    elseif type(widget.title) == "string" and widget.title ~= "" then base = "title=" .. widget.title
    elseif type(widget.text) == "string" and widget.text ~= "" then
        base = "text=" .. widget.text:sub(1, 40)
    else
        base = "widget@" .. tostring(widget):match("0x%x+")
    end
    local flags = ""
    if widget.covers_fullscreen then flags = flags .. ",fullscreen" end
    if widget.modal then flags = flags .. ",modal" end
    if widget.toast then flags = flags .. ",toast" end
    if widget.invisible then flags = flags .. ",invisible" end
    return base .. flags
end

windowStackText = function()
    local ok, UIManager = pcall(require, "ui/uimanager")
    if not ok or type(UIManager) ~= "table" or type(UIManager._window_stack) ~= "table" then
        return "(unknown)"
    end
    local stack = UIManager._window_stack
    local top = nil
    if type(UIManager.getTopmostVisibleWidget) == "function" then
        local ok_top, top_widget = pcall(UIManager.getTopmostVisibleWidget, UIManager)
        if ok_top then top = top_widget end
    end
    local parts = {}
    local catalog_pos = nil
    for i = 1, #stack do
        local widget = stack[i].widget
        if widget == catalog_widget then catalog_pos = i end
        local name = widgetName(widget)
        if widget == top then name = name .. " [TOP]" end
        parts[#parts + 1] = tostring(i) .. ":" .. name
    end
    local summary = #parts > 0 and table.concat(parts, " | ") or "(empty)"
    if catalog_widget ~= nil then
        if catalog_pos ~= nil then
            summary = summary .. string.format(" ; catalog at position %d of %d", catalog_pos, #stack)
        else
            summary = summary .. " ; catalog NOT in stack (flag stale)"
        end
    end
    return summary
end

-- Walk numeric children to depth 4 for a widget carrying an image file,
-- the same shape CatalogWidgets.buildCoverWidget returns (FrameContainer
-- > CenterContainer > ImageWidget). Returns nil for text-only covers.
local function findCoverImage(widget, depth)
    if type(widget) ~= "table" or depth <= 0 then return nil end
    if type(widget.file) == "string" and widget.scale_factor ~= nil then
        return widget
    end
    for i = 1, #widget do
        local found = findCoverImage(widget[i], depth - 1)
        if found then return found end
    end
    return nil
end

local function basename(path)
    if type(path) ~= "string" then return "(none)" end
    return path:match("([^/]+)$") or path
end

local function hookPlugin(plugin)
    if type(plugin) ~= "table" then
        log("plugin instantiation: plugin object was not a table, nothing hooked")
        return
    end
    if plugin._bookorbit_diag_hooked then
        log("plugin instantiation: already hooked, skipping")
        return
    end
    plugin._bookorbit_diag_hooked = true

    local version = plugin.PLUGIN_VERSION or plugin.plugin_version or "(unknown)"
    local ok_login, logged_in = pcall(function() return plugin:isLoggedIn() end)
    local logged_in_txt = ok_login and tostring(logged_in) or ("error: " .. tostring(logged_in))
    -- The settings-nil error at this point is expected, not a bug: the
    -- userpatch function runs before the plugin finishes loading its
    -- settings, so isLoggedIn cannot read them yet.
    if not ok_login and tostring(logged_in):find("settings", 1, true) then
        logged_in_txt = "not yet loaded (settings nil at instantiation, expected)"
    end
    log("plugin instantiated: version=%s, logged in=%s, server=%s, wifi connected=%s, tweaks toggle=%s, tweaks patch loaded=%s",
        q(version), logged_in_txt, serverHost(serverUrlOf(plugin)), connected(),
        tweaksToggle(), package.loaded["bookorbit_tweaks_patch"] and "yes" or "no")

    -- Open path on the plugin itself (MainMenu methods are installed onto it).
    local plugin_methods = {
        "openBookOrbit", "browseCatalog", "openCatalogBrowser", "openSignIn",
        "promptLogin", "openMenuSheet", "openSettings", "openSyncStatus",
        "requestSweep", "requestManualBookSync", "requestProgressPush",
        "requestProgressPull", "requestUpdateCheck", "requestAnnotationExchange",
    }
    for i = 1, #plugin_methods do
        local name = plugin_methods[i]
        if name == "openCatalogBrowser" then
            -- Track catalog presence for the perf core busy check, on top of timing.
            local f = plugin[name]
            if type(f) == "function" and not plugin["_bookorbit_diag_" .. name] then
                plugin["_bookorbit_diag_" .. name] = true
                plugin[name] = function(...)
                    if not on() then return f(...) end
                    -- Early-return detection: upstream openCatalogBrowser
                    -- returns at once, showing nothing, if a catalog
                    -- browser already exists. The call-time self is the
                    -- instance that actually owns the catalog, unlike
                    -- the hook-time plugin instance (v1.0.0 lesson).
                    local caller = select(1, ...)
                    local already = type(caller) == "table" and caller.catalog_browser ~= nil
                    if already then
                        log(">> plugin:openCatalogBrowser EARLY-RETURN RISK: catalog already present, upstream will return without showing anything")
                    else
                        log(">> plugin:openCatalogBrowser")
                    end
                    local t0 = now_ms()
                    local res = { pcall(f, ...) }
                    local took = now_ms() - t0
                    if not res[1] then
                        log("<< plugin:openCatalogBrowser FAILED after %d ms: %s", took, tostring(res[2]))
                        error(res[2], 0)
                    end
                    if already then
                        if catalog_widget == nil and type(caller) == "table" then
                            catalog_widget = caller.catalog_browser
                        end
                        log("<< plugin:openCatalogBrowser EARLY RETURN in %d ms: catalog already present, nothing shown, stack=%s",
                            took, windowStackText())
                    else
                        -- v1.1.0 fix: success itself means the catalog is
                        -- open. Reading plugin.catalog_browser was wrong
                        -- (v1.0.0 always read "absent" for this instance).
                        catalog_open = true
                        if type(caller) == "table" then catalog_widget = caller.catalog_browser end
                        log("<< plugin:openCatalogBrowser done in %d ms; %s; stack=%s",
                            took, openState(plugin), windowStackText())
                    end
                    return unpack(res, 2)
                end
                log("hook plugin:openCatalogBrowser: applied")
            else
                log("hook plugin:openCatalogBrowser: not found (not in this plugin version)")
            end
        else
            timed(plugin, name, "plugin:" .. name, function() return openState(plugin) end)
        end
    end

    -- Catalog construction and refresh.
    local ok_cat, Catalog = pcall(require, "bookorbit_catalog")
    if ok_cat and type(Catalog) == "table" then
        local catalog_methods = {
            "init", "initialDashboardContext", "refreshDashboardOnOpen",
            "hydrateOnDeviceMaps", "scheduleThumbnailDownloads", "goDashboard",
            "cancelThumbnailJobs", "cleanLegacyThumbnails", "onCloseWidget",
        }
        for i = 1, #catalog_methods do
            local name = catalog_methods[i]
            if name == "onCloseWidget" then
                local f = Catalog[name]
                if type(f) == "function" and not Catalog["_bookorbit_diag_" .. name] then
                    Catalog["_bookorbit_diag_" .. name] = true
                    Catalog[name] = function(...)
                        if not on() then return f(...) end
                        log(">> catalog:onCloseWidget")
                        local res = { pcall(f, ...) }
                        if res[1] then catalog_open = false; catalog_widget = nil end
                        log("<< catalog:onCloseWidget %s; stack=%s",
                            res[1] and "done" or ("FAILED: " .. tostring(res[2])), windowStackText())
                        if not res[1] then error(res[2], 0) end
                        return unpack(res, 2)
                    end
                    log("hook catalog:onCloseWidget: applied")
                else
                    log("hook catalog:onCloseWidget: not found (not in this plugin version)")
                end
            else
                timed(Catalog, name, "catalog:" .. name)
            end
        end
    else
        log("catalog module: bookorbit_catalog could not be loaded (%s), catalog hooks skipped", tostring(Catalog))
    end

    -- Dashboard page module, if it exists as its own module in this version.
    local ok_dash, Dashboard = pcall(require, "bookorbit_catalog_dashboard")
    if ok_dash and type(Dashboard) == "table" then
        for i = 1, #({ "loadDashboard", "refreshDashboard", "fetchDashboard" }) do
            local name = ({ "loadDashboard", "refreshDashboard", "fetchDashboard" })[i]
            timed(Dashboard, name, "dashboard:" .. name)
        end
    else
        log("dashboard module: bookorbit_catalog_dashboard not loaded as a separate module, dashboard hooks skipped")
    end

    -- API calls: the blocking network path.
    local ok_api, Api = pcall(require, "bookorbit_api")
    if ok_api and type(Api) == "table" then
        timedApi(Api, "request", "api:request")
        timedApi(Api, "requestBlocking", "api:requestBlocking")
        timed(Api, "download", "api:download")
        timed(Api, "downloadBlocking", "api:downloadBlocking")
    else
        log("api module: bookorbit_api could not be loaded (%s), api hooks skipped", tostring(Api))
    end

    -- BookOrbit's own suspend/resume handlers. These only run when a
    -- book is open and auto-sync is on (registerEvents gates them), so
    -- the broadcastEvent Suspend/Resume lines above are the ones that
    -- always fire; these show whether BookOrbit itself did work on
    -- sleep/wake, and whether that work finished.
    timed(plugin, "_onSuspend", "plugin:_onSuspend")
    timed(plugin, "_onResume", "plugin:_onResume")
    timed(plugin, "_onCloseDocument", "plugin:_onCloseDocument")
    timed(plugin, "_onNetworkConnected", "plugin:_onNetworkConnected")
    timed(plugin, "_onNetworkDisconnecting", "plugin:_onNetworkDisconnecting")

    -- Covers: catalog cover building, with the tweaks toggle and the
    -- finished image flag. Diagnostics loads after the tweaks patch
    -- ("zz"), so this wrapper sits outside the tweaks wrapper: the
    -- flag logged here is the flag after tweaks ran, which is the one
    -- that actually paints. First 8 covers, then every 50th, so a
    -- full catalog does not flood the log.
    local ok_cw, CW = pcall(require, "bookorbit_catalog_widgets")
    if ok_cw and type(CW) == "table" and type(CW.buildCoverWidget) == "function"
            and not CW._bookorbit_diag_buildCoverWidget then
        CW._bookorbit_diag_buildCoverWidget = true
        local orig_cover = CW.buildCoverWidget
        CW.buildCoverWidget = function(book, width, height, path, state, opts)
            local widget = orig_cover(book, width, height, path, state, opts)
            if on() then
                cover_count = cover_count + 1
                if cover_count <= 8 or cover_count % 50 == 0 then
                    local image = findCoverImage(widget, 4)
                    local image_txt = "(no image widget found)"
                    if image then
                        image_txt = string.format("file=%s, original_in_nightmode=%s, is_icon=%s, scale_factor=%s",
                            basename(image.file), tostring(image.original_in_nightmode),
                            tostring(image.is_icon), tostring(image.scale_factor))
                    end
                    log("cover #%d: path=%s, state=%s, night_mode=%s, tweaks toggle=%s, %s",
                        cover_count, basename(path), q(state), nightMode(), tweaksToggle(), image_txt)
                end
            end
            return widget
        end
        log("hook catalog:buildCoverWidget: applied")
    else
        log("hook catalog:buildCoverWidget: not found (not in this plugin version)")
    end

    -- Dashboard board covers: first 3 creations only. BoardCover is a
    -- local inside bookorbit_board_ui (not exported), so it cannot be
    -- wrapped directly; BoardUI.cover is the exported constructor that
    -- builds it. BoardCover paints directly (blit + invertRect in night
    -- mode) instead of using an ImageWidget, so if dashboard covers
    -- invert while catalog covers do not (or the reverse), these lines
    -- separate the two paths.
    local ok_board, BoardUI = pcall(require, "bookorbit_board_ui")
    if ok_board and type(BoardUI) == "table" and type(BoardUI.cover) == "function"
            and not BoardUI._bookorbit_diag_cover then
        BoardUI._bookorbit_diag_cover = true
        local orig_cover_fn = BoardUI.cover
        BoardUI.cover = function(book, w, h, o)
            local widget = orig_cover_fn(book, w, h, o)
            if on() and board_paint_count < 3 then
                board_paint_count = board_paint_count + 1
                log("board cover #%d: path=%s, night_mode=%s, tweaks toggle=%s, size=%sx%s",
                    board_paint_count, basename(o and o.path), nightMode(), tweaksToggle(),
                    tostring(w), tostring(h))
            end
            return widget
        end
        log("hook board:BoardUI.cover: applied")
    else
        log("hook board:BoardUI.cover: not found (not in this plugin version)")
    end

    log("plugin hooks done")
end

do
    local ok, userpatch = pcall(require, "userpatch")
    if ok and userpatch and type(userpatch.registerPatchPluginFunc) == "function" then
        userpatch.registerPatchPluginFunc("bookorbit", hookPlugin)
        userpatch.registerPatchPluginFunc("BookOrbit", hookPlugin)
        log("waiting for BookOrbit plugin instantiation (registered for bookorbit + BookOrbit)")
    else
        log("userpatch.registerPatchPluginFunc unavailable, plugin hooks not registered")
    end
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

-- BookOrbit's own files and the tweaks patch
DiagCore.client({
    name = "BookOrbit",
    targets = { "2-bookorbit-tweaks.lua", "bookorbit.koplugin/" },
    log = log,
    on = on,
    errors = false, -- BookOrbit's own warnings and errors are caught above
    busy = function() return catalog_open end,
    extra = function() return "covers built " .. cover_count end,
})
