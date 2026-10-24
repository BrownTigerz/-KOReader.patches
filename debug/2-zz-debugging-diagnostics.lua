--[[
2-zz-debugging-diagnostics.lua - TEMPORARY troubleshooting patch
Version 1.2.1

Watches 2-debugging-menu.lua from the outside and writes what it sees to:
    koreader/debugging-diagnostics.log
(Kobo: .adds/koreader/debugging-diagnostics.log)
Its one other file is koreader/debugging-diagnostics.state (version and
first-run time).

It changes nothing in the Debugging menu or in any other diagnostic. It
records:
  • Start-up check: the Debugging menu's version (header vs code), whether
    its first-start switch-off has run, and where the menu shows (Add-ons
    or Tools).
  • Every diagnostic the menu should find, on or off, plus anything it
    would trip over: a copy both on and off, old ".lua.disabled" leftovers,
    a regular patch sitting in patches/debug/ (it won't load there), a
    diagnostic named so the menu can't see it, no log path in a
    diagnostic's source (the menu then guesses one).
  • Log files: size of each, leftovers no diagnostic owns ("Delete all
    logs" won't remove them), and log names that overlap (deleting one
    would take the other's files too).
  • Every file the menu moves, deletes or writes, and whether it worked.
    Flags anything it shouldn't touch: version.log, crash.log deleted
    instead of emptied, a non-diagnostic patch moved or deleted, files
    outside koreader/.
  • Menu opens: how long the list took to build, folder scans and file
    checks, memory before/after.
  • Combine logs: size of debug-all.log and whether every log went in.
  • Restart prompts, timers the menu sets, and anything it does while
    asleep (should be nothing).

How it shuts itself off:
  • Logs for 15 minutes after KOReader starts (time asleep counts). The
    first hooked call after that writes a summary, then every hook passes
    straight through until the next restart.
  • 24 hours after its first run it stops hooking anything at all (one
    line per start says so). Delete debugging-diagnostics.state for
    another 24 hours. ("Delete all logs" in the menu deletes it too.)
  • No timers of its own, no polling. Log capped at 2 MB (older part
    kept as debugging-diagnostics.log.old).

How to use (within 15 minutes of starting KOReader):
  1. Put this file in koreader/patches/ and restart KOReader. It shows up
     in the Debugging menu itself as "Debugging"; leave it on. ("All off"
     switches it off too, from the next restart.)
  2. Open Debugging and try: switch a diagnostic off and on, All off /
     All on, hold one and Delete log, Combine logs, Clear crash.log if you
     want, sleep and wake. "Delete all logs" deletes this log too (a fresh
     one starts right after), so do that last.
  3. Send debugging-diagnostics.log (or Combine logs and send debug-all.log).
  4. Delete this file and restart.
The "zz" makes it load after the Debugging menu and Add-ons patches.

Note: the Debugging menu finds a diagnostic's log names by scanning its
source for quoted log paths that start with a slash. debug-all.log is the
menu's own file, so its path below is joined without that slash in the
quotes; otherwise the menu would count it as this diagnostic's log.

Changelog
  1.2.1 (2026-10-23) - Same rule as Debugging menu 1.3.4: files named after
                       a diagnostic itself (.log.firstload, .stamp, -meta.lua)
                       belong to it, so they're no longer flagged ORPHAN and
                       its delete checks expect them to go.
  1.2.0 (2026-10-23) - Shared perf core (the same block as the other
                       diagnostics): Debugging menu timers that hold the
                       screen 80 ms+, flashes it asks for, timers left
                       waiting at sleep, and a once-a-minute perf line,
                       inside the 15-minute window, in this log. The 24
                       hours now start per version (the state file keeps
                       the version), so an update isn't already expired
                       when it arrives.
  1.1.8 (2026-10-22) - One line per entry: messages and popups with line
                       breaks are joined with " / " (they used to split
                       into untagged lines), and the invisible text-
                       direction marks around file paths are removed.
  1.1.7  Fix: sourceStates() was called inside collect() before its local
         declaration, hitting a nil global ("attempt to call a nil value")
         and killing the diagnostics inventory + delete-safety checks.
         Forward-declared now.
  1.1.6  Log cap 256 KB -> 2 MB (shared-log headroom for all-on runs).
  1.1.5  Orphaned diagnostic .state deletes are legitimate now (menu
         sweeps them) — no longer flagged.
  1.1.4  Delete all logs now removes any .log except version.log/crash.log:
         no longer flags those deletes as unexpected; state files count as
         owned; orphan note reworded.
  1.1.3  Shared log contract v1: the menu rewriting diagnostics.log (tag
         filtering) is a recognized write, not unexpected; Combine check
         counts the shared log once; identical log prefixes no longer flag
         as overlaps.
  1.1.2  The one status note goes through the shared notification
         contract v1 (Network Tweaks / ReadMastery style when installed,
         stock popup otherwise).
  1.1.1  Wraps lfs.mkdir too (the menu creates patches/debug/ on the first
         switch-off); the ownership scan is cached across a delete burst;
         start-up line uses Device.screen.night_mode (Device.night_mode
         was a dead argument).
  1.1.0  Diagnostic standard: 15-minute window from start-up (was 5 minutes
         from the first menu open), 24h expiry kept in
         debugging-diagnostics.state with one line per start once expired,
         no timers of its own, date + 12-hour time on every line, standard
         start line, one note per start, own logging can't break the menu.
  1.0.0  First version.
]]

local DataStorage = require("datastorage")
local Device = require("device")
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local ok_time, ktime = pcall(require, "ui/time")

local DIAG_VERSION = "1.2.1"
local LOG = DataStorage:getDataDir() .. "/debugging-diagnostics.log"
local DATA = DataStorage:getDataDir()
local STATE = DATA .. "/debugging-diagnostics.state"
local SETTINGS_DIR = DataStorage:getSettingsDir()
local PATCHES = DATA .. "/patches"
local OFF_DIR = PATCHES .. "/debug"
local MAIN_FILE = PATCHES .. "/2-debugging-menu.lua"
local MAIN_TAG = "debugging-menu"
local FIRST_RUN_KEY = "debugging_menu_first_run_done"
local COMBINED = string.format("%s/%s", DATA, "debug-all.log")
local CRASH = DATA .. "/crash.log"
local VERSION_LOG = DATA .. "/version.log"
local SHARED = DATA .. "/diagnostics.log"  -- shared log contract v1

local MAX_BYTES = 2 * 1024 * 1024
local WINDOW_MIN = 15
local WINDOW_S = WINDOW_MIN * 60
local EXPIRE_S = 24 * 60 * 60

local SELF_NAME = ((debug.getinfo(1, "S") or {}).source or ""):match("[^/]+$") or ""

-- --------------------------------------------------------------------------
-- Log, clock, expiry, window
-- --------------------------------------------------------------------------

local function now() return ok_time and ktime.now() or nil end
local function ms(since)
    if not (ok_time and since) then return -1 end
    local ok, v = pcall(function() return ktime.to_ms(ktime.since(since)) end)
    return ok and v or -1
end

-- writes regardless of the window (start line, expiry line, closing summary)
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

local function write(line)
    pcall(function()
        if (lfs.attributes(LOG, "size") or 0) > MAX_BYTES then
            os.remove(LOG .. ".old")
            os.rename(LOG, LOG .. ".old")
        end
        local f = io.open(LOG, "a")
        if not f then return end
        f:write(os.date("%Y-%m-%d %I:%M:%S %p  "), diagOneLine(line), "\n")
        f:close()
    end)
end

local function fmt(f, ...)
    local ok, line = pcall(string.format, f, ...)
    return ok and line or tostring(f)
end

local function q(v) return v == nil and "(nil)" or tostring(v) end

do
    -- version on line 1, first run on line 2: another version (or an old
    -- state file with just a time) starts a new 24 hours
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
        write(fmt("debugging diagnostics %s expired (first run %s): not watching anything. "
            .. "Delete this patch, or delete debugging-diagnostics.state for 24 more hours.",
            DIAG_VERSION, os.date("%Y-%m-%d %I:%M %p", first)))
        logger.info("debugging diagnostics: expired, inactive")
        return
    end
end

write("==================== debugging diagnostics " .. DIAG_VERSION .. " started ====================")

local load_time = os.time()
local logging = true
local closeWindow  -- set below

-- true while logging; the first call after the window ends closes it
local function on()
    if not logging then return false end
    if os.difftime(os.time(), load_time) > WINDOW_S then
        logging = false
        pcall(closeWindow)
        return false
    end
    return true
end

local function log(f, ...)
    if on() then write(fmt(f, ...)) end
end

local function mem() return collectgarbage("count") end

-- --------------------------------------------------------------------------
-- Counters
-- --------------------------------------------------------------------------

local stats = {
    opens = 0, open_ms = 0, open_max = 0,
    scans = 0, checks = 0, reads = 0,
    moves = 0, moves_failed = 0, removes = 0, removes_failed = 0,
    writes = 0, combines = 0, crash_clears = 0,
    restart_prompts = 0, timers = 0,
    asleep = 0, flagged = 0,
}

local function flag(f, ...)
    stats.flagged = stats.flagged + 1
    log(f, ...)
end

local function sleepNote()
    if Device.screen_saver_mode then
        stats.asleep = stats.asleep + 1
        stats.flagged = stats.flagged + 1
        return "  WHILE ASLEEP"
    end
    return ""
end

-- Was the caller (n levels up) code from the Debugging menu patch?
local function fromMain(level)
    local info = debug.getinfo(level + 1, "S")
    return info and info.source and info.source:find(MAIN_TAG, 1, true) ~= nil
end

local function srcOf(fn)
    local info = type(fn) == "function" and debug.getinfo(fn, "S")
    return info and info.source or ""
end

local function kb(bytes)
    if not bytes then return "none" end
    if bytes < 1024 then return bytes .. " B" end
    return string.format("%.0f KB", bytes / 1024)
end

local function baseName(p) return (tostring(p):match("[^/]+$")) or tostring(p) end
local function dirOf(p) return (tostring(p):match("^(.*)/[^/]*$")) end

-- --------------------------------------------------------------------------
-- Independent copy of how the menu recognises diagnostics and their files
-- --------------------------------------------------------------------------

local function isDiag(name)
    local b = name:match("^(%d+%-.+)%.lua$") or name:match("^(%d+%-.+)%.lua%.disabled$")
    if not b then return nil end
    local low = b:lower()
    if low:find("debugging%-menu") then return nil end
    if low:find("diagnostic") or low:find("buildtime") then return b end
    return nil
end

local function sourceLogs(path)
    local f = io.open(path, "r")
    if not f then return {} end
    local src = f:read("*a") or ""
    f:close()
    local names, seen = {}, {}
    for n in src:gmatch('"/([%w_%.%-]+%.log)"') do
        if not seen[n] and n ~= "crash.log" and n ~= "version.log" then
            seen[n] = true
            names[#names + 1] = n
        end
    end
    return names
end

local function startsWith(name, p)
    if name:sub(1, #p) ~= p then return false end
    local rest = name:sub(#p + 1)
    return rest == "" or rest:find("^[%.%-]") ~= nil
end

-- Forward declaration: collect() (above) calls sourceStates(), which is
-- defined below. Without this, the call would hit a nil global.
local sourceStates

local function collect()
    local diags, order, hidden, stray = {}, {}, {}, {}
    for _i, dir in ipairs({ PATCHES, OFF_DIR }) do
        if lfs.attributes(dir, "mode") == "directory" then
            pcall(function()
                for entry in lfs.dir(dir) do
                    local full = dir .. "/" .. entry
                    if lfs.attributes(full, "mode") == "file" then
                        local b = isDiag(entry)
                        local low = entry:lower()
                        if b then
                            if not diags[b] then
                                diags[b] = { base = b, copies = {} }
                                order[#order + 1] = b
                            end
                            table.insert(diags[b].copies, full)
                        elseif low:find("%.lua") and (low:find("diagnostic") or low:find("buildtime"))
                                and not low:find("debugging%-menu") then
                            hidden[#hidden + 1] = full
                        elseif dir == OFF_DIR then
                            stray[#stray + 1] = entry
                        end
                    end
                end
            end)
        end
    end
    table.sort(order)
    for _i, b in ipairs(order) do
        local d = diags[b]
        local on_path = PATCHES .. "/" .. b .. ".lua"
        d.on = lfs.attributes(on_path, "mode") == "file"
        d.logs = sourceLogs(d.on and on_path or d.copies[1])
        d.guessed = #d.logs == 0
        if d.guessed then d.logs = { (b:gsub("^%d+%-", ""):gsub("^zz%-", "")) .. ".log" } end
        d.prefixes = {}
        for _j, n in ipairs(d.logs) do d.prefixes[#d.prefixes + 1] = (n:gsub("%.log$", "")) end
        -- files named after the diagnostic itself (menu 1.3.4)
        local own = (b:gsub("^%d+%-", ""):gsub("^zz%-", ""))
        local have = false
        for _j, p in ipairs(d.prefixes) do if p == own then have = true break end end
        if not have then d.prefixes[#d.prefixes + 1] = own end
        d.states = sourceStates(d.on and on_path or d.copies[1])
    end
    return diags, order, hidden, stray
end

local function ownedBy(name, diags)
    for _b, d in pairs(diags) do
        for _i, p in ipairs(d.prefixes) do
            if startsWith(name, p) then return d.base end
        end
        for _i, s in ipairs(d.states or {}) do
            if name == s then return d.base end
        end
    end
    return nil
end

-- State files keep each diagnostic's time window; the menu finds them
-- per diagnostic so Delete all logs restarts the windows.
function sourceStates(path)
    local f = io.open(path, "r")
    if not f then return {} end
    local src = f:read("*a") or ""
    f:close()
    local names, seen = {}, {}
    for n in src:gmatch('"/([%w_%.%-]+%.state)"') do
        if not seen[n] then seen[n] = true names[#names + 1] = n end
    end
    return names
end

local function copiesOf(b)
    local n = 0
    for _i, p in ipairs({ PATCHES .. "/" .. b .. ".lua", OFF_DIR .. "/" .. b .. ".lua",
                          OFF_DIR .. "/" .. b .. ".lua.disabled", PATCHES .. "/" .. b .. ".lua.disabled" }) do
        if lfs.attributes(p, "mode") == "file" then n = n + 1 end
    end
    return n
end

-- Ownership lookups during a delete burst reuse one scan; a move clears it.
local diags_cache = nil
local function cachedDiags()
    if not diags_cache then diags_cache = collect() end
    return diags_cache
end

local function inventory(why)
    local diags, order, hidden, stray = collect()
    log("---- diagnostics found (%s) ----", why)
    local n_on, all = 0, {}
    for _i, b in ipairs(order) do
        local d = diags[b]
        if d.on then n_on = n_on + 1 end
        local sizes = {}
        for _j, n in ipairs(d.logs) do
            local s = lfs.attributes(DATA .. "/" .. n, "size")
            local so = lfs.attributes(DATA .. "/" .. n .. ".old", "size")
            sizes[#sizes + 1] = n .. " " .. kb(s) .. (so and (" + .old " .. kb(so)) or "")
        end
        log("%s: %s | %s", b, d.on and "ON" or "off", table.concat(sizes, ", "))
        if #d.copies > 1 then
            local names = {}
            for _j, c in ipairs(d.copies) do names[#names + 1] = c:sub(#PATCHES + 2) end
            flag("  DUPLICATE: %d copies (%s); the menu uses the patches/ one and deletes the other on the next switch",
                #d.copies, table.concat(names, ", "))
        end
        for _j, c in ipairs(d.copies) do
            if c:find("%.disabled$") then
                log("  old-style copy %s (the menu moves it into debug/ next time it opens)", c:sub(#PATCHES + 2))
            end
        end
        if d.guessed then flag("  no log path in its source: the menu guesses %s", d.logs[1]) end
        for _j, p in ipairs(d.prefixes) do all[#all + 1] = { p = p, b = b } end
    end
    for _i, h in ipairs(hidden) do
        flag("HIDDEN from the menu (needs a number prefix like 2-): %s", h:sub(#PATCHES + 2))
    end
    for _i, s in ipairs(stray) do
        flag("in patches/debug/ but not a diagnostic: %s (won't load there, not listed in the menu)", s)
    end
    for _i, a in ipairs(all) do
        for _j, c in ipairs(all) do
            -- identical prefixes mean the shared log, not an overlap
            if a.b ~= c.b and a.p ~= c.p and startsWith(c.p, a.p) then
                flag("OVERLAP: deleting %s's log also takes %s's files (%s.* covers %s.*)", a.b, c.b, a.p, c.p)
            end
        end
    end
    for _i, dir in ipairs({ DATA, SETTINGS_DIR }) do
        pcall(function()
            for entry in lfs.dir(dir) do
                local low = entry:lower()
                if (low:find("diagnostic") or low:find("buildtime"))
                        and lfs.attributes(dir .. "/" .. entry, "mode") == "file"
                        and not ownedBy(entry, diags) then
                    flag("ORPHAN: %s/%s (%s); no diagnostic owns it (leftover or stray)",
                        dir == DATA and "koreader" or "settings", entry, kb(lfs.attributes(dir .. "/" .. entry, "size")))
                end
            end
        end)
    end
    log("%d diagnostics: %d on, %d off", #order, n_on, #order - n_on)
end

-- --------------------------------------------------------------------------
-- Summary and window end
-- --------------------------------------------------------------------------

local function pendingMainTasks()
    local n = 0
    for _i, t in ipairs(UIManager._task_queue or {}) do
        if srcOf(t.action):find(MAIN_TAG, 1, true) then n = n + 1 end
    end
    return n
end

local function summaryLines(why)
    return {
        fmt("---- summary (%s) ----", why),
        fmt("menu opens: %d, avg %dms, slowest %dms", stats.opens,
            stats.opens > 0 and math.floor(stats.open_ms / stats.opens) or 0, stats.open_max),
        fmt("folder scans by the menu: %d | file checks: %d | file reads: %d", stats.scans, stats.checks, stats.reads),
        fmt("moves: %d (failed %d) | deletes: %d (failed %d) | writes: %d",
            stats.moves, stats.moves_failed, stats.removes, stats.removes_failed, stats.writes),
        fmt("combines: %d | crash.log clears: %d | restart prompts: %d | timers: %d (pending now: %d)",
            stats.combines, stats.crash_clears, stats.restart_prompts, stats.timers, pendingMainTasks()),
        fmt("done while asleep: %d | Lua memory: %d KB", stats.asleep, math.floor(mem())),
        fmt("verdict: %s", stats.flagged == 0 and "OK: nothing flagged"
            or (stats.flagged .. " flagged line(s) above, worth a look")),
    }
end

-- called once by on() when the window has run out (logging is already off)
closeWindow = function()
    for _i, line in ipairs(summaryLines(WINDOW_MIN .. " minutes up")) do write(line) end
    write("==== logging stopped, every hook passes straight through until the next restart ====")
end

-- --------------------------------------------------------------------------
-- Start-up check
-- --------------------------------------------------------------------------

local function mainVersions()
    local f = io.open(MAIN_FILE, "r")
    if not f then return nil end
    local src = f:read("*a") or ""
    f:close()
    local head = src:match("^%-%-%[%[(.-)%]%]") or src:sub(1, 600)
    return head:match("Version:?%s*([%d%.]+)"), src:match('local%s+VERSION%s*=%s*"([%d%.]+)"'), true
end

pcall(function()
    log("logging for %d minutes", WINDOW_MIN)
    local hv, cv, found = mainVersions()
    if not found then
        flag("2-debugging-menu.lua not found in patches/ (renamed?)")
    else
        log("Debugging menu: header Version %s | code VERSION %s", q(hv), q(cv))
        if hv ~= cv then flag("VERSION MISMATCH: header says %s, code says %s", q(hv), q(cv)) end
    end
    log("first-start switch-off done: %s", tostring(G_reader_settings:isTrue(FIRST_RUN_KEY)))
    local TM = package.loaded.tweaks_mods
    local registered = type(TM) == "table" and type(TM.entries) == "table" and TM.entries.debugging_menu ~= nil
    local addons = type(TM) == "table" and TM.active and true or false
    local shows = false
    if addons then
        if type(TM.shows) ~= "function" then shows = true
        else
            local ok, v = pcall(TM.shows, "debugging_menu")
            shows = ok and v and true or false
        end
    end
    log("registered with Add-ons: %s | Add-ons patch active: %s | menu shows in: %s",
        tostring(registered), tostring(addons), shows and "Add-ons" or "Tools (fallback)")
    if not registered then flag("Debugging menu didn't register (did it load? check crash.log)") end
    log("device %s | night mode %s | Lua memory %d KB", q(Device.model), q(Device.screen.night_mode), math.floor(mem()))
    inventory("at start-up")
end)

-- --------------------------------------------------------------------------
-- Things checked on the next event instead of a timer
-- --------------------------------------------------------------------------

local pending_combine = false

local function checkCombined()
    pending_combine = false
    local f = io.open(COMBINED, "r")
    if not f then flag("debug-all.log missing right after Combine logs") return end
    local text = f:read("*a") or ""
    f:close()
    local sections = 0
    for _ in text:gmatch("\n==================== ") do sections = sections + 1 end
    local diags, order = collect()
    -- unique log names: with the shared log every diagnostic lists
    -- diagnostics.log, but it counts once
    local seen_names, expected = {}, 0
    for _i, b in ipairs(order) do
        for _j, n in ipairs(diags[b].logs) do
            if not seen_names[n] then
                seen_names[n] = true
                for _k, p in ipairs({ DATA .. "/" .. n .. ".old", DATA .. "/" .. n }) do
                    if (lfs.attributes(p, "size") or 0) > 0 then expected = expected + 1 end
                end
            end
        end
    end
    local crash = (lfs.attributes(CRASH, "size") or 0) > 0
    local want = expected + (crash and 1 or 0)
    log("debug-all.log: %s, %d sections (expected %d: %d diagnostic log file%s%s)", kb(#text), sections,
        want, expected, expected == 1 and "" or "s", crash and " + crash.log" or "")
    if sections ~= want then flag("  combined log has %s sections than expected", sections < want and "fewer" or "more") end
end

local function runPending()
    if pending_combine then pcall(checkCombined) end
end

-- --------------------------------------------------------------------------
-- Menu opens: lfs.dir from the menu = it's building its list
-- --------------------------------------------------------------------------

local noted = false
-- Shared notification contract v1: see 2-debugging-menu.lua. Same priority
-- order (Network Tweaks, then ReadMastery, then the stock popup below).
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
local function noteOnce()
    if noted then return end
    noted = true
    local left = math.max(1, math.ceil((WINDOW_S - os.difftime(os.time(), load_time)) / 60))
    local text = string.format("Debugging diagnostics: logging for %d min", left)
    if shared_note(text, text) then return end
    pcall(function()
        require("ui/widget/notification"):notify(text)
    end)
end

local orig_dir = lfs.dir
lfs.dir = function(path, ...)
    if on() and fromMain(2) then stats.scans = stats.scans + 1 end
    return orig_dir(path, ...)
end

local orig_attr = lfs.attributes
lfs.attributes = function(...)
    if on() and fromMain(2) then stats.checks = stats.checks + 1 end
    return orig_attr(...)
end

local orig_mkdir = lfs.mkdir
lfs.mkdir = function(path, ...)
    if on() and fromMain(2) then
        pcall(log, "created directory %s%s", tostring(path), sleepNote())
    end
    return orig_mkdir(path, ...)
end

local function wrapMenuTable(m, where)
    if type(m) ~= "table" or m.__dbg_diag or type(m.sub_item_table_func) ~= "function" then return m end
    m.__dbg_diag = true
    local orig = m.sub_item_table_func
    m.sub_item_table_func = function(...)
        if not on() then return orig(...) end
        local c0, s0, t, m0 = stats.checks, stats.scans, now(), mem()
        local res = { pcall(orig, ...) }
        pcall(function()
            local took = ms(t)
            stats.opens = stats.opens + 1
            stats.open_ms = stats.open_ms + math.max(took, 0)
            stats.open_max = math.max(stats.open_max, took)
            local items = res[1] and type(res[2]) == "table" and #res[2] or -1
            log("menu opened (%s): %d items, %dms, %d folder scans, %d file checks, memory %+d KB%s%s",
                where, items, took, stats.scans - s0, stats.checks - c0, math.floor(mem() - m0),
                took > 300 and "  SLOW" or "", sleepNote())
            if not res[1] then flag("menu build ERROR: %s", q(res[2])) end
            noteOnce()
        end)
        if not res[1] then error(res[2], 0) end
        return unpack(res, 2)
    end
    return m
end

-- Add-ons path
do
    local TM = package.loaded.tweaks_mods
    local e = type(TM) == "table" and type(TM.entries) == "table" and TM.entries.debugging_menu
    if type(e) == "table" and type(e.build) == "function" then
        local orig_build = e.build
        e.build = function(...)
            local m = orig_build(...)
            pcall(wrapMenuTable, m, "Add-ons")
            return m
        end
    end
end

-- Tools fallback path (the menu's own wrapper runs inside ours)
do
    local ok_fm, FMM = pcall(require, "apps/filemanager/filemanagermenu")
    if ok_fm and type(FMM) == "table" and type(FMM.setUpdateItemTable) == "function" then
        local orig = FMM.setUpdateItemTable
        FMM.setUpdateItemTable = function(self, ...)
            local res = { orig(self, ...) }
            pcall(function()
                if type(self.menu_items) == "table" and self.menu_items.debugging_menu then
                    wrapMenuTable(self.menu_items.debugging_menu, "Tools")
                end
            end)
            return unpack(res)
        end
    end
end

-- --------------------------------------------------------------------------
-- File moves, deletes and writes done by the menu
-- --------------------------------------------------------------------------

-- Why a file the menu touched is suspicious, or nil if it's fine.
local function concern(kind, p)
    p = tostring(p)
    if p == VERSION_LOG then return "version.log should never be touched" end
    if p == CRASH and kind ~= "write" then return "crash.log should only be emptied" end
    if p:sub(1, #DATA + 1) ~= DATA .. "/" then return "outside koreader/" end
    local d, n = dirOf(p), baseName(p)
    if d == PATCHES or d == OFF_DIR then
        if n:find("%.lua") and not isDiag(n) then return "not a diagnostic patch" end
        return nil
    end
    if d ~= DATA and d ~= SETTINGS_DIR then return "unexpected folder" end
    return nil
end

local function selfNote(p)
    local n = baseName(p):gsub("%.disabled$", "")
    return n == SELF_NAME and "  (that's this diagnostic: applies after restart, keeps logging now)" or ""
end

local orig_rename = os.rename
os.rename = function(from, to)
    if not (on() and fromMain(2)) then return orig_rename(from, to) end
    local res = { orig_rename(from, to) }
    pcall(function()
        diags_cache = nil  -- a move changes which copies exist
        stats.moves = stats.moves + 1
        local td = dirOf(to)
        local where = td == PATCHES and "ON (patches/)" or td == OFF_DIR and "off (patches/debug/)" or q(td)
        if res[1] then
            local landed = lfs.attributes(to, "mode") == "file"
            local gone = lfs.attributes(from, "mode") == nil
            log("moved %s -> %s%s%s", baseName(from), where, selfNote(to), sleepNote())
            if not (landed and gone) then
                flag("  CHECK: after the move the file is %s and the old one is %s",
                    landed and "there" or "MISSING", gone and "gone" or "STILL THERE")
            end
            local b = isDiag(baseName(to))
            if b and copiesOf(b) > 1 then flag("  DUPLICATE left behind: %d copies of %s", copiesOf(b), b) end
        else
            stats.moves_failed = stats.moves_failed + 1
            flag("MOVE FAILED %s -> %s: %s", baseName(from), where, q(res[2]))
        end
        local c = concern("move", from) or concern("move", to)
        if c then flag("  UNEXPECTED move (%s): %s", c, tostring(from)) end
    end)
    return unpack(res, 1, 3)
end

local orig_remove = os.remove
os.remove = function(path)
    if not (on() and fromMain(2)) then return orig_remove(path) end
    local p = tostring(path)
    local size = lfs.attributes(p, "size")
    local res = { orig_remove(path) }
    pcall(function()
        stats.removes = stats.removes + 1
        if res[1] then
            local own = (p == LOG or p == LOG .. ".old") and "  (this diagnostic's own log: a fresh one starts here)"
                or p == STATE and "  (this diagnostic's state: its 24h restart from the next start)" or ""
            log("deleted %s (%s)%s%s%s", baseName(p), kb(size), own, selfNote(p), sleepNote())
        else
            stats.removes_failed = stats.removes_failed + 1
            flag("DELETE FAILED %s: %s", baseName(p), q(res[2]))
        end
        local c = concern("delete", p)
        local d = dirOf(p)
        if not c and (d == DATA or d == SETTINGS_DIR) and p ~= COMBINED then
            -- Delete all logs removes any .log except version.log/crash.log,
            -- plus orphaned diagnostic .state files left by removed patches
            local low = baseName(p):lower()
            local is_log = low:sub(-4) == ".log" or low:sub(-8) == ".log.old"
            local is_state = low:sub(-6) == ".state"
                and (low:find("diagnostic", 1, true) or low:find("buildtime", 1, true))
            if not is_log and not is_state then
                local diags = cachedDiags()
                if not ownedBy(baseName(p), diags) then c = "no diagnostic owns this file" end
            end
        end
        if c then flag("  UNEXPECTED delete (%s): %s", c, p) end
    end)
    return unpack(res, 1, 3)
end

local orig_open = io.open
io.open = function(path, mode, ...)
    if on() and fromMain(2) then
        pcall(function()
            local m = mode or "r"
            local p = tostring(path)
            if m:find("[wa+]") then
                stats.writes = stats.writes + 1
                if p == COMBINED then
                    stats.combines = stats.combines + 1
                    pending_combine = true  -- checked when the menu's "combined" note shows
                    log("writing debug-all.log (Combine logs)%s", sleepNote())
                elseif p == CRASH then
                    stats.crash_clears = stats.crash_clears + 1
                    log("crash.log emptied (was %s)%s", kb(lfs.attributes(p, "size")), sleepNote())
                elseif p == SHARED then
                    log("shared diagnostics.log rewritten by the menu (tag lines filtered)%s", sleepNote())
                else
                    flag("UNEXPECTED write by the menu: %s", p)
                end
            else
                stats.reads = stats.reads + 1
            end
        end)
    end
    return orig_open(path, mode, ...)
end

-- --------------------------------------------------------------------------
-- Restart prompts, timers the menu sets, notes, sleep / wake
-- --------------------------------------------------------------------------

if type(UIManager.askForRestart) == "function" then
    local orig = UIManager.askForRestart
    UIManager.askForRestart = function(self, ...)
        if on() and fromMain(2) then
            pcall(function()
                stats.restart_prompts = stats.restart_prompts + 1
                log("restart prompt shown%s", sleepNote())
            end)
        end
        return orig(self, ...)
    end
end

for _i, fname in ipairs({ "scheduleIn", "nextTick" }) do
    local orig = UIManager[fname]
    if type(orig) == "function" then
        UIManager[fname] = function(self, a, ...)
            if on() and fromMain(2) then
                pcall(function()
                    stats.timers = stats.timers + 1
                    log("timer from the menu: %s%s", fname == "nextTick" and "next tick" or (q(a) .. "s"), sleepNote())
                end)
            end
            return orig(self, a, ...)
        end
    end
end

-- The menu shows a note right after closing debug-all.log: check it then.
local orig_show = UIManager.show
UIManager.show = function(self, ...)
    if pending_combine and on() then runPending() end
    return orig_show(self, ...)
end

local orig_send = UIManager.sendEvent
UIManager.sendEvent = function(self, ...)
    if pending_combine and on() then runPending() end
    return orig_send(self, ...)
end

local orig_broadcast = UIManager.broadcastEvent
UIManager.broadcastEvent = function(self, event, ...)
    if on() then
        pcall(function()
            local h = type(event) == "table" and event.handler
            if h == "onSuspend" then
                runPending()
                log("SLEEP: menu timers still pending: %d", pendingMainTasks())
                for _i, line in ipairs(summaryLines("going to sleep")) do log("%s", line) end
            elseif h == "onResume" then
                log("WAKE (anything the menu does next is logged)")
            end
        end)
    end
    return orig_broadcast(self, event, ...)
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

-- The Debugging menu's own file: its timers that hold the screen 80 ms+,
-- flashes it asks for, timers it leaves waiting at sleep, and a
-- once-a-minute perf line, all inside the 15-minute window.
DiagCore.client({
    name = "Debugging menu",
    targets = { "2-debugging-menu.lua" },
    on = function() return on() end,
    log = log,
    errors = false,
})

logger.info("debugging diagnostics " .. DIAG_VERSION .. " loaded (logging for " .. WINDOW_MIN .. " min)")
