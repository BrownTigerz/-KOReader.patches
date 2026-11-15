--[[
2-debugging-menu.lua
Version 1.5.0

Adds Add-ons > Debugging (library only) to switch your diagnostic patches on
and off, and to tidy up their logs. Your diagnostic patches are never edited.

  • Turn Off All Debug: every diagnostic off (from the next restart), plus
    the debug switches inside patches and plugins: OrbitShelf's
    Diagnostics, and any patch that lists its
    own in package.loaded.debug_switches (debug switch contract v1:
    [id] = { label, is_on(), off() }). Those go off at once. With the Test
    Mode patch on, it asks first whether to switch that off too.
  • Test Mode (2-zz-test-mode.lua), when it's there, gets its own switch in
    a section at the bottom, moved like a diagnostic. Not part of All on/off;
    Turn Off All Debug asks about it. While that patch is running (1.0.2+),
    its menu sits at the top of this one.
  • One toggle for all diagnostics, plus one checkbox per diagnostic.
  • All diagnostics write to one shared log: koreader/diagnostics.log.
    Each line is tagged with the diagnostic's short name, so a full test
    run reads as a single chronological file. The menu shows its size once.
  • Switching moves the file: on = in patches/, off = in patches/debug/.
    KOReader only loads patches sitting directly in patches/, so an off
    diagnostic doesn't load and costs nothing, and the folder stays tidy.
    Changes apply after a restart (asked once). Old-style ".lua.disabled"
    diagnostics in patches/ are moved into debug/ the first time.
  • Combine Logs: writes the shared diagnostics log once, plus the end
    of crash.log, into one file: koreader/debug-all.log.
  • Delete All Logs: removes every .log file except version.log and
    crash.log, plus the diagnostics' stamp/state files (this also
    restarts their time windows), plus orphaned .state files left
    behind by removed patches. Asks first. Clearing crash.log stays
    a separate option below.
  • Hold a diagnostic: filter its lines out of the shared log, or delete
    its log lines and the patch itself.
  • Logging Time / Stop After (debug timing contract v1): how long each
    diagnostic logs after a start, and how many days after its first run it
    stops for good, for all of them at once or (hold one) one by one; Each
    Its Own keeps a diagnostic's own times. They apply from the next start.
    End Logging Now stops every diagnostic's log at once (until the next
    start); Restart Timers starts their time windows again, logs kept.
  • Crash.log: shows its size, "Clear Crash.log" empties it (asks first).
    version.log (KOReader's update history) is never touched.

Diagnostics are found automatically: any patch with "diagnostic" or
"buildtime" in its name. On the very first start, all of them are switched
off (from the next restart); logs are left alone.

Without the Add-ons patch (2-tweaks-menu.lua), or when Debugging is hidden
there, it shows up as Tools > Debugging instead.

Changelog
1.5.0  Logging Time and Stop After for all diagnostics (Each Its Own, or
       5 / 15 / 30 / 60 / 120 min; 1 / 3 / 7 days), and per diagnostic
       (hold it: Follow All, Its Own, or a time). Each diagnostic row shows
       its times. End Logging Now stops their logging straight away (also
       one by one, and Turn Off All Debug does it too); Restart Timers
       starts their windows again without deleting logs. The diagnostics
       read the times at start (debug timing contract v1, diagnostics
       updated with it); nothing set = their own times, as before.
       Lighter start: it only lists the patch folders at start (each
       diagnostic file is read when the menu opens, not at every start).
1.4.5  Pill Colour Trace is no longer a switch here: BookOrbit Tweaks 2.15.18
       moved it into the BookOrbit diagnostic, which Turn Off All Debug
       already switches off. A Pill Colour Trace setting left saved by an
       older BookOrbit Tweaks no longer counts as "on".
1.4.4  Test Mode's menu (on/off, Reset Test Books) sits at the top while
       the Test Mode patch is running (Test Mode 1.0.2 moves it here from
       Add-ons); not there when the patch is off. Turn Off All Debug always
       asks to restart when it switched a patch off (it said "restart to
       apply" after the first time), and after the Test Mode question closes.
1.4.3  Test Mode is now a patch switch like the diagnostics, in its own
       section at the bottom: the checkbox moves 2-zz-test-mode.lua between
       patches/ and patches/debug/ (applies after a restart). Its own menu
       is no longer copied in here (1.4.1). Turn Off All Debug with that
       patch on asks whether to switch it off too; yes also turns Test Mode
       itself off first (its Reset Test Books question comes up).
1.4.2  Turn Off All Debug with Test Mode on asks first: Turn Off Test Mode
       Too (everything off; Test Mode then offers to reset its books) or
       Keep Test Mode (debug off, Test Mode stays on). Test Mode off: no
       question. The item says when Test Mode is on.
1.4.1  Test Mode (2-zz-test-mode.lua) shows in its own section at the bottom,
       the same menu as in Add-ons. Turn Off All Debug leaves it alone.
1.4.0  Turn Off All Debug at the top: switches every diagnostic off and
       the debug switches inside patches and plugins (Pill Colour Trace,
       OrbitShelf Diagnostics, and any patch that registers one). Shows
       how many are on; one note says what went off.
1.3.6  Wording only, no behavior change: "Combine Logs" (was "Combine
       Crash And Diagnostics Log For Review"), "No diagnostics found"
       (was "No Diagnostics Found In Patches/"), and plainer
       notifications ("Diagnostics change on restart", "has only
       crash.log", "log and state files", "switched off on next
       restart").
1.3.5  1.3.4 only reached Delete Log on one diagnostic: Delete All Logs
       gathers its own list and still skipped those files (the log after
       Delete All Logs showed none of them deleted). It now takes every
       file each diagnostic owns, the same list Delete Log uses.
1.3.4  Delete All Logs (and Delete Log on one diagnostic) now also take the
       files a diagnostic names after itself, not only after its log:
       sleepscreen-banner-diagnostics.log.firstload, tweaks-menu-
       diagnostics.stamp, readmastery-diagnostics-meta.lua. Since those
       diagnostics moved to the shared log, nothing pointed at them, so
       they were left behind and their time windows never restarted (the
       Sleep Screen Banner diagnostic stayed expired after Delete All Logs).
1.3.3  Menu items use title case (first letter of every word capitalized).
1.3.2  Combine moved to the very bottom of the menu and renamed to
       "Combine Crash And Diagnostics Log For Review" so its purpose
       is obvious.
1.3.1  Delete all logs now removes every .log except version.log and
       crash.log, plus state files (including orphaned .state files
       from removed patches); Clear crash.log stays separate.
1.3.0  Shared log contract v1: diagnostics write tagged lines to one
       shared koreader/diagnostics.log instead of individual files. The
       menu shows the shared log once, Combine includes it once, hold ->
       Delete log filters one diagnostic's lines out by tag. State files
       still found per diagnostic so Delete all logs restarts time windows.
1.2.3  "All on" / "All off" merged into a single toggle (any off -> all
       on, all on -> all off).
1.2.2  Status notes go through the shared notification contract v1
       (Network Tweaks / ReadMastery style when installed, stock popup
       otherwise). Menus and dialogs untouched.
1.2.1  Combine logs scans the patch list once (was twice). Header version
       corrected (was stale at 1.0.0).
1.2.0  Hold a diagnostic to delete its log, or its log and patch.
1.1.0  Off diagnostics live in patches/debug/ instead of being renamed.
1.0.0  First version.
]]

local DataStorage = require("datastorage")
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")

local VERSION = "1.5.0"
local DATA = DataStorage:getDataDir()
local PATCHES = DATA .. "/patches"
local OFF_DIR = PATCHES .. "/debug"
local SETTINGS_DIR = DataStorage:getSettingsDir()
local CRASH = DATA .. "/crash.log"
local COMBINED = DATA .. "/debug-all.log"
local SHARED_LOG = DATA .. "/diagnostics.log"  -- shared log contract v1:
    -- every diagnostic appends tagged lines here instead of its own file
local FIRST_RUN_KEY = "debugging_menu_first_run_done"
local CRASH_TAIL = 300   -- lines of crash.log added to the combined log

-- Friendlier names for the diagnostics we know; others get a tidied file name.
local NAMES = {
    ["simpleui"]                   = "SimpleUI",
    ["shortcutstoolbar"]           = "Shortcuts Toolbar",
    ["shortcutstoolbar-buildtime"] = "Shortcuts Toolbar build time",
    ["entity-footnotes"]           = "Entity footnotes",
    ["network-tweaks"]             = "Network tweaks",
    ["shelfsync-tweaks"]           = "ShelfSync tweaks",
    ["track-reading-location"]     = "Track reading location",
    ["backup-patches"]             = "Backup patches",
    ["readinginsights-tweaks"]     = "Reading Insights tweaks",
    ["readmastery"]                = "ReadMastery",
    ["sleepscreen-banner"]         = "Sleep screen banner",
    ["tweaks-menu"]                = "Add-ons menu",
    ["xray-direct-lookup"]         = "X-Ray direct lookup",
}

-- ---------------------------------------------------------------------------
-- Debug timing contract v1
-- ---------------------------------------------------------------------------
-- G_reader_settings "debug_timing" = { all = { window_min = n, expire_days = n },
-- per = { [stem] = { window_min = n | "own", expire_days = n | "own" } } }: a
-- diagnostic reads it at start (its own value, else all's, else its default; "own" =
-- its default). package.loaded.debug_timing_ended ["*"] or [stem]: End Logging Now,
-- until the next start. Each diagnostic's own times, as shipped (window: minutes
-- per start, nil when it logs per session / per sleep instead; expire: days):
local DT_KEY = "debug_timing"
local DT_DEFAULTS = {
    ["backup-patches"]               = { window = 15, expire = 3 },
    ["bookorbit"]                    = { window = 30, expire = 3 },
    ["debugging"]                    = { window = 15, expire = 1 },
    ["network-tweaks"]               = { window = 5, expire = 1 },
    ["readinginsights-tweaks"]       = { window = 10, expire = 2, per = "per session" },
    ["readinglog-tweaks"]            = { window = 15, expire = 1 },
    ["readmastery"]                  = { window = 5 * 1440, expire = 10 },
    ["shelfsync-tweaks"]             = { window = 10, expire = 1 },
    ["shortcutstoolbar"]             = { window = 5, expire = 1 },
    ["shortcutstoolbar-quick-shelf"] = { window = 15, expire = 1 },
    ["simpleui"]                     = { window = 30, expire = 3 },
    ["sleepscreen-banner"]           = { expire = 1 / 24, per = "after each sleep" },
    ["track-reading-location"]       = { expire = 5, per = "per session" },
    ["tweaks-menu"]                  = { window = 10, expire = 3 },
}
local WINDOW_CHOICES = { 5, 15, 30, 60, 120 }
local EXPIRE_CHOICES = { 1, 3, 7 }

local function dtRead()
    local t = G_reader_settings:readSetting(DT_KEY)
    t = type(t) == "table" and t or {}
    t.all = type(t.all) == "table" and t.all or {}
    t.per = type(t.per) == "table" and t.per or {}
    return t
end

local function dtSave(t)
    for k, v in pairs(t.per) do if next(v) == nil then t.per[k] = nil end end
    if next(t.all) == nil and next(t.per) == nil then
        G_reader_settings:delSetting(DT_KEY)
    else
        G_reader_settings:saveSetting(DT_KEY, { all = next(t.all) and t.all or nil,
            per = next(t.per) and t.per or nil })
    end
    pcall(G_reader_settings.flush, G_reader_settings)
end

local function fmtMinutes(m)
    m = tonumber(m)
    if not m then return "?" end
    if m >= 1440 then
        local d = m / 1440
        return string.format("%g day%s", d, d == 1 and "" or "s")
    end
    return string.format("%d min", m)
end

local function fmtDays(d)
    d = tonumber(d)
    if not d then return "?" end
    if d < 1 then return fmtMinutes(math.floor(d * 1440 + 0.5)) end
    return string.format("%g day%s", d, d == 1 and "" or "s")
end

-- the time a diagnostic gets for key ("window_min" | "expire_days"), and from where:
-- "own" (its default), "all" or "set" (its own setting)
local function dtEffective(stem, key)
    local def = DT_DEFAULTS[stem] or {}
    local default = key == "window_min" and def.window or def.expire
    if key == "window_min" and not def.window then return nil, "own" end
    local t = dtRead()
    local per = t.per[stem] and t.per[stem][key]
    if per == "own" then return default, "own" end
    if tonumber(per) then return tonumber(per), "set" end
    if tonumber(t.all[key]) then return tonumber(t.all[key]), "all" end
    return default, "own"
end

local function dtEnded(stem)
    local e = package.loaded.debug_timing_ended
    return type(e) == "table" and (e["*"] or e[stem]) and true or false
end

local function dtEnd(stem)
    local e = package.loaded.debug_timing_ended
    if type(e) ~= "table" then
        e = {}
        package.loaded.debug_timing_ended = e
    end
    e[stem or "*"] = true
end

-- ---------------------------------------------------------------------------
-- Finding diagnostics and their files
-- ---------------------------------------------------------------------------

local function isDiagnostic(name)
    local base = name:match("^(%d+%-.+)%.lua$") or name:match("^(%d+%-.+)%.lua%.disabled$")
    if not base then return nil end
    local low = base:lower()
    if low:find("debugging%-menu") then return nil end
    if low:find("diagnostic") or low:find("buildtime") then return base end
    return nil
end

local function stemOf(base)
    return (base:gsub("^%d+%-", ""):gsub("^zz%-", ""):gsub("%-diagnostics?$", ""))
end

-- Menu items use title case: the first letter of every word capitalized
-- ("clear crash.log" -> "Clear Crash.log").
local function titlecase(s)
    return (s:gsub("%S+", function(w)
        local i = w:find("%a")
        if i and w:sub(i, i):match("%l") then
            return w:sub(1, i - 1) .. w:sub(i, i):upper() .. w:sub(i + 1)
        end
        return w
    end))
end

local function prettyName(stem)
    if NAMES[stem] then return titlecase(NAMES[stem]) end
    return titlecase(stem:gsub("[-_]", " "))
end

local function fileSize(path)
    return lfs.attributes(path, "size")
end

-- Log names the patch writes, read from its own source: "/something.log".
-- Remembered per diagnostic, so each source is read once per session.
local log_cache = {}
local function logNamesFrom(base, path)
    if log_cache[base] then return log_cache[base] end
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
    log_cache[base] = names
    return names
end

-- State files (e.g. "/simpleui-diagnostics.state") keep each diagnostic's
-- time window; Delete all logs removes them to restart the windows.
-- Remembered per diagnostic, like the log names.
local state_cache = {}
local function stateNamesFrom(base, path)
    if state_cache[base] then return state_cache[base] end
    local f = io.open(path, "r")
    if not f then return {} end
    local src = f:read("*a") or ""
    f:close()
    local names, seen = {}, {}
    for n in src:gmatch('"/([%w_%.%-]+%.state)"') do
        if not seen[n] then
            seen[n] = true
            names[#names + 1] = n
        end
    end
    state_cache[base] = names
    return names
end

-- True when the diagnostic reads the Debugging menu's times (debug timing contract v1).
local timing_cache = {}
local function readsTiming(base, path)
    if timing_cache[base] == nil then
        local f = io.open(path, "r")
        local src = f and f:read("*a") or ""
        if f then f:close() end
        timing_cache[base] = src:find("Debug timing contract v1", 1, true) ~= nil
    end
    return timing_cache[base]
end

-- True when the diagnostic writes to the shared log instead of its own file.
local function isShared(d)
    return #d.logs == 1 and d.logs[1] == "diagnostics.log"
end

-- Where a diagnostic is now: on (patches/x.lua) beats off copies.
local function locate(base)
    local function f(p) return lfs.attributes(p, "mode") == "file" and p or nil end
    local p = f(PATCHES .. "/" .. base .. ".lua")
    if p then return true, p end
    p = f(OFF_DIR .. "/" .. base .. ".lua") or f(OFF_DIR .. "/" .. base .. ".lua.disabled")
        or f(PATCHES .. "/" .. base .. ".lua.disabled")
    if p then return false, p end
    return nil
end

-- { { base=, stem=, name=, on=, path=, logs={...}, prefixes={...} }, ... }
local function scan()
    local list, seen = {}, {}
    local ok = pcall(function()
        for _i, dir in ipairs({ PATCHES, OFF_DIR }) do
            if lfs.attributes(dir, "mode") == "directory" then
                for entry in lfs.dir(dir) do
                    local base = isDiagnostic(entry)
                    if base and not seen[base] then
                        local on, path = locate(base)
                        if path then
                            seen[base] = true
                            local stem = stemOf(base)
                            list[#list + 1] = { base = base, stem = stem, name = prettyName(stem),
                                                on = on, path = path }
                        end
                    end
                end
            end
        end
    end)
    if not ok then return {} end
    for _i, d in ipairs(list) do
        d.logs = logNamesFrom(d.base, d.path)
        if #d.logs == 0 then d.logs = { d.base:gsub("^%d+%-", ""):gsub("^zz%-", "") .. ".log" } end
        d.states = stateNamesFrom(d.base, d.path)
        -- every file starting with a log's name (minus .log) belongs to it:
        -- .log, .log.old, .log.firstload, .stamp, .state, -meta.lua ...
        d.prefixes = {}
        for _j, n in ipairs(d.logs) do d.prefixes[#d.prefixes + 1] = n:gsub("%.log$", "") end
        -- and every file named after the diagnostic itself (its markers and
        -- stamps outlive its own log name once it writes to the shared log)
        local own = d.base:gsub("^%d+%-", ""):gsub("^zz%-", "")
        local have = false
        for _j, p in ipairs(d.prefixes) do if p == own then have = true break end end
        if not have then d.prefixes[#d.prefixes + 1] = own end
    end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    return list
end

local function startsWithAny(name, prefixes)
    for _i, p in ipairs(prefixes) do
        if name:sub(1, #p) == p then
            local rest = name:sub(#p + 1)
            -- only the prefix itself followed by "." or "-" (not "simpleui-diagnosticsX")
            if rest == "" or rest:find("^[%.%-]") then return true end
        end
    end
    return false
end

-- Every leftover file of a diagnostic, in koreader/ and koreader/settings/.
local function filesOf(d)
    local out, seen = {}, {}
    local function add(p)
        if not seen[p] then seen[p] = true out[#out + 1] = p end
    end
    for _i, dir in ipairs({ DATA, SETTINGS_DIR }) do
        pcall(function()
            for entry in lfs.dir(dir) do
                if entry ~= "crash.log" and entry ~= "version.log"
                   and entry ~= "diagnostics.log" and entry ~= "diagnostics.log.old"
                   and startsWithAny(entry, d.prefixes)
                   and lfs.attributes(dir .. "/" .. entry, "mode") == "file" then
                    add(dir .. "/" .. entry)
                end
            end
        end)
    end
    -- state files are named per diagnostic even with the shared log, so
    -- Delete all logs still restarts their time windows
    for _i, n in ipairs(d.states or {}) do
        for _j, dir in ipairs({ DATA, SETTINGS_DIR }) do
            local p = dir .. "/" .. n
            if lfs.attributes(p, "mode") == "file" then add(p) end
        end
    end
    return out
end

-- Remove one diagnostic's lines from the shared log, matched by "[tag]".
-- The tag is the diagnostic's filename stem (see stemOf).
local function deleteTagLines(tag)
    local f = io.open(SHARED_LOG, "r")
    if not f then return 0 end
    local src = f:read("*a") or ""
    f:close()
    local marker = "[" .. tag .. "]"
    local kept, dropped = {}, 0
    for line in (src .. "\n"):gmatch("([^\n]*)\n") do
        if line:find(marker, 1, true) then dropped = dropped + 1
        else kept[#kept + 1] = line end
    end
    if dropped > 0 then
        local out = io.open(SHARED_LOG, "w")
        if out then out:write(table.concat(kept, "\n")) out:close() end
    end
    return dropped
end

local function logSize(d)
    local total, any = 0, false
    for _i, n in ipairs(d.logs) do
        for _j, p in ipairs({ DATA .. "/" .. n, DATA .. "/" .. n .. ".old" }) do
            local s = fileSize(p)
            if s then total, any = total + s, true end
        end
    end
    return any and total or nil
end

local function fmtSize(bytes)
    if not bytes then return nil end
    if bytes < 1024 then return bytes .. " B" end
    if bytes < 1024 * 1024 then return string.format("%.0f KB", bytes / 1024) end
    return string.format("%.1f MB", bytes / 1024 / 1024)
end

-- ---------------------------------------------------------------------------
-- Switching
-- ---------------------------------------------------------------------------

local function setOn(d, on)
    local to = on and (PATCHES .. "/" .. d.base .. ".lua") or (OFF_DIR .. "/" .. d.base .. ".lua")
    if d.path == to then d.on = on return true end
    if not on and lfs.attributes(OFF_DIR, "mode") ~= "directory" then lfs.mkdir(OFF_DIR) end
    -- the copy being moved is the current one; an older copy at the target goes
    if lfs.attributes(to, "mode") then os.remove(to) end
    local ok, err = os.rename(d.path, to)
    if not ok then
        logger.warn("debugging menu: move failed", d.path, err)
        return false
    end
    d.on, d.path = on, to
    return true
end

-- Old-style "x.lua.disabled" diagnostics in patches/ move into debug/.
local function migrate()
    for _i, d in ipairs(scan()) do
        if not d.on and d.path:sub(-9) == ".disabled" then setOn(d, false) end
    end
end

-- What was switched on when KOReader started (to mark pending changes).
local loaded = {}
-- at start only which diagnostics are on: the folders listed, no file read
pcall(function()
    for _i, dir in ipairs({ PATCHES, OFF_DIR }) do
        if lfs.attributes(dir, "mode") == "directory" then
            for entry in lfs.dir(dir) do
                local base = isDiagnostic(entry)
                if base and loaded[base] == nil then
                    local on, path = locate(base)
                    if path then loaded[base] = on end
                end
            end
        end
    end
end)
do
    local on_t, path_t = locate("2-zz-test-mode")
    if path_t then loaded["2-zz-test-mode"] = on_t end
end

-- Shared notification contract v1: user-facing status notes use one style,
-- resolved in priority order: Network Tweaks' banner/corner note if
-- installed, ReadMastery notify's style if installed, otherwise the
-- patch's own default below. Checks run at call time, so patch load
-- order doesn't matter. Never shows over the sleep screen.
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

local function notify(text)
    if shared_note(text, text) then return end
    local ok, Notification = pcall(require, "ui/widget/notification")
    if ok then Notification:notify(text) end
end

local asked_restart = false
local function changed(always)
    if asked_restart and not always then
        notify("Debugging: restart KOReader to apply")
        return
    end
    asked_restart = true
    UIManager:askForRestart("Diagnostics change on restart.")
end

local function confirm(text, ok_text, fn)
    local ConfirmBox = require("ui/widget/confirmbox")
    UIManager:show(ConfirmBox:new{ text = text, ok_text = ok_text, ok_callback = fn })
end

-- ---------------------------------------------------------------------------
-- Logs
-- ---------------------------------------------------------------------------

local function readAll(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

local function tailLines(text, n)
    local lines = {}
    for l in (text .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = l end
    if lines[#lines] == "" then lines[#lines] = nil end
    local first = math.max(1, #lines - n + 1)
    return table.concat(lines, "\n", first), #lines - first + 1
end

local function combine()
    local out = io.open(COMBINED, "w")
    if not out then notify("Debugging: couldn't write debug-all.log") return end
    local Device = require("device")
    out:write("debug-all.log  (Debugging menu ", VERSION, ")\n")
    out:write("Written ", os.date("%Y-%m-%d %I:%M:%S %p"), "  device ",
        tostring(Device.model or "?"), "\n\n")
    local count = 0
    local list = scan()
    for _i, d in ipairs(list) do
        out:write(string.format("%-32s %s\n", d.name, d.on and "on" or "off"))
    end
    -- unique log files: with the shared log every diagnostic lists
    -- diagnostics.log, but it goes in exactly once
    local seen, uniq = {}, {}
    for _i, d in ipairs(list) do
        for _j, n in ipairs(d.logs) do
            if not seen[n] then
                seen[n] = true
                uniq[#uniq + 1] = { name = n,
                    label = (n == "diagnostics.log") and "diagnostics" or d.name }
            end
        end
    end
    for _i, f in ipairs(uniq) do
        for _k, p in ipairs({ DATA .. "/" .. f.name .. ".old", DATA .. "/" .. f.name }) do
            local text = readAll(p)
            if text and text ~= "" then
                count = count + 1
                local when = lfs.attributes(p, "modification")
                out:write("\n\n==================== ", f.label, ": ", p:match("[^/]+$"),
                    "  (", fmtSize(#text), ", last written ",
                    when and os.date("%Y-%m-%d %I:%M %p", when) or "?", ") ====================\n")
                out:write(text)
                if text:sub(-1) ~= "\n" then out:write("\n") end
            end
        end
    end
    local crash = readAll(CRASH)
    if crash and crash ~= "" then
        local tail, n = tailLines(crash, CRASH_TAIL)
        out:write("\n\n==================== crash.log (last ", n, " lines) ====================\n")
        out:write(tail, "\n")
    end
    out:close()
    if count == 0 then
        notify("Debugging: no diagnostic logs yet (debug-all.log has only crash.log)")
    else
        notify(string.format("Debugging: %d log%s combined into debug-all.log",
            count, count == 1 and "" or "s"))
    end
end

local function allLeftovers()
    -- every .log file except version.log and crash.log, plus each
    -- diagnostic's state files (deleting those restarts time windows),
    -- plus orphaned .state files no current diagnostic owns
    -- (left behind after a patch file was deleted outright)
    local files, seen = {}, {}
    local function add(p)
        if not seen[p] then seen[p] = true files[#files + 1] = p end
    end
    local diags = scan()
    for _i, dir in ipairs({ DATA, SETTINGS_DIR }) do
        pcall(function()
            for entry in lfs.dir(dir) do
                local low = entry:lower()
                if (low:sub(-4) == ".log" or low:sub(-8) == ".log.old")
                   and entry ~= "version.log" and entry ~= "crash.log"
                   and lfs.attributes(dir .. "/" .. entry, "mode") == "file" then
                    add(dir .. "/" .. entry)
                end
            end
        end)
    end
    for _i, d in ipairs(diags) do
        for _j, n in ipairs(d.states or {}) do
            for _k, dir in ipairs({ DATA, SETTINGS_DIR }) do
                local p = dir .. "/" .. n
                if lfs.attributes(p, "mode") == "file" then add(p) end
            end
        end
        -- and everything else it owns (markers, stamps, -meta files named
        -- after it): the same files Delete Log takes for one diagnostic
        for _j, p in ipairs(filesOf(d)) do add(p) end
    end
    for _i, dir in ipairs({ DATA, SETTINGS_DIR }) do
        pcall(function()
            for entry in lfs.dir(dir) do
                local low = entry:lower()
                if low:sub(-6) == ".state"
                   and (low:find("diagnostic", 1, true) or low:find("buildtime", 1, true))
                   and lfs.attributes(dir .. "/" .. entry, "mode") == "file" then
                    local is_owned = false
                    for _j, d in ipairs(diags) do
                        for _k, n in ipairs(d.states or {}) do
                            if entry == n then is_owned = true break end
                        end
                        if not is_owned then
                            for _k, p in ipairs(d.prefixes or {}) do
                                if entry:sub(1, #p) == p then is_owned = true break end
                            end
                        end
                        if is_owned then break end
                    end
                    if not is_owned then add(dir .. "/" .. entry) end
                end
            end
        end)
    end
    return files
end

local function deleteAll()
    local files = allLeftovers()
    if #files == 0 then notify("Debugging: no logs to delete") return end
    confirm(string.format("Delete %d log and state file%s?\n\nOnly version.log and crash.log are kept.",
        #files, #files == 1 and "" or "s"), "Delete", function()
        local n = 0
        for _i, p in ipairs(files) do
            if os.remove(p) then n = n + 1 end
        end
        notify(string.format("Debugging: deleted %d file%s", n, n == 1 and "" or "s"))
    end)
end

local function clearCrash()
    if not fileSize(CRASH) or fileSize(CRASH) == 0 then
        notify("Debugging: crash.log is already empty")
        return
    end
    confirm("Empty crash.log?", "Clear", function()
        -- emptied in place: KOReader keeps writing to the same file
        local f = io.open(CRASH, "w")
        if f then f:close() notify("Debugging: crash.log cleared")
        else notify("Debugging: couldn't clear crash.log") end
    end)
end

local function refresh(tm)
    if tm and tm.updateItems then tm:updateItems() end
end

local function deleteFiles(files)
    local n = 0
    for _i, p in ipairs(files) do if os.remove(p) then n = n + 1 end end
    return n
end

-- Every copy of the patch: on, off, old-style .disabled.
local function patchCopies(base)
    local out = {}
    for _i, p in ipairs({ PATCHES .. "/" .. base .. ".lua", OFF_DIR .. "/" .. base .. ".lua",
                          OFF_DIR .. "/" .. base .. ".lua.disabled", PATCHES .. "/" .. base .. ".lua.disabled" }) do
        if lfs.attributes(p, "mode") == "file" then out[#out + 1] = p end
    end
    return out
end

-- Logging Time / Stop After: for all diagnostics (stem nil) or one. The current
-- choice has a dot.
local function timingChoices(stem, key, name, on_done)
    local ButtonDialog = require("ui/widget/buttondialog")
    local dlg
    local t = dtRead()
    local fmt = key == "window_min" and fmtMinutes or fmtDays
    local list = key == "window_min" and WINDOW_CHOICES or EXPIRE_CHOICES
    local cur
    if stem then cur = t.per[stem] and t.per[stem][key] else cur = t.all[key] end
    local function set(v)
        local t2 = dtRead()
        if stem then
            t2.per[stem] = t2.per[stem] or {}
            t2.per[stem][key] = v
        else
            t2.all[key] = v
        end
        dtSave(t2)
        UIManager:close(dlg)
        if on_done then on_done() end
    end
    local function mark(text, on) return (on and "• " or "") .. text end
    local rows = {}
    if stem then
        local def = DT_DEFAULTS[stem] or {}
        local own = key == "window_min" and def.window or def.expire
        local all_v = tonumber(t.all[key])
        rows[#rows + 1] = {{ text = mark("Follow All (" .. (all_v and titlecase(fmt(all_v)) or "Its Own") .. ")", cur == nil),
            callback = function() set(nil) end }}
        rows[#rows + 1] = {{ text = mark("Its Own (" .. (own and titlecase(fmt(own)) or "?") .. ")", cur == "own"),
            callback = function() set("own") end }}
    else
        rows[#rows + 1] = {{ text = mark("Each Its Own", cur == nil), callback = function() set(nil) end }}
    end
    local row = {}
    for _i, v in ipairs(list) do
        row[#row + 1] = { text = mark(titlecase(fmt(v)), tonumber(cur) == v), callback = function() set(v) end }
        if #row == 3 then
            rows[#rows + 1] = row
            row = {}
        end
    end
    if #row > 0 then rows[#rows + 1] = row end
    rows[#rows + 1] = {{ text = "Cancel", callback = function() UIManager:close(dlg) end }}
    dlg = ButtonDialog:new{
        title = (key == "window_min" and "Logging Time" or "Stop After") .. (name and (": " .. name) or " (All)"),
        title_align = "center",
        buttons = rows,
    }
    UIManager:show(dlg)
end

-- Restart Timers: every diagnostic's stamp / state files (not its logs), so each
-- starts a fresh window and a fresh stop-after count at the next start
local function timerFiles()
    local files, seen = {}, {}
    local function add(p)
        if not seen[p] and lfs.attributes(p, "mode") == "file" then
            seen[p] = true
            files[#files + 1] = p
        end
    end
    for _i, d in ipairs(scan()) do
        for _j, n in ipairs(d.states or {}) do
            for _k, dir in ipairs({ DATA, SETTINGS_DIR }) do add(dir .. "/" .. n) end
        end
        for _j, p in ipairs(filesOf(d)) do
            local low = p:lower()
            if not (low:find("%.log$") or low:find("%.log%.old$")) then add(p) end
        end
    end
    return files
end

local function restartTimers()
    local files = timerFiles()
    if #files == 0 then notify("Debugging: no timers to restart") return end
    confirm(string.format("Start every diagnostic's time window again?\n\n%d stamp file%s deleted; logs are kept.",
        #files, #files == 1 and "" or "s"), "Restart Timers", function()
        local n = 0
        for _i, p in ipairs(files) do if os.remove(p) then n = n + 1 end end
        notify(string.format("Debugging: %d timer%s restarted", n, n == 1 and "" or "s"))
        changed(true)
    end)
end

local function holdMenu(d, tm)
    local ButtonDialog = require("ui/widget/buttondialog")
    local dlg
    local running = loaded[d.base] == true
    local rows = {}
    if readsTiming(d.base, d.path) then
        local function done() refresh(tm) changed() end
        if (DT_DEFAULTS[d.stem] or {}).window then
            rows[#rows + 1] = {{ text = "Logging Time…", callback = function()
                UIManager:close(dlg)
                timingChoices(d.stem, "window_min", d.name, done)
            end }}
        end
        rows[#rows + 1] = {{ text = "Stop After…", callback = function()
            UIManager:close(dlg)
            timingChoices(d.stem, "expire_days", d.name, done)
        end }}
        if running and not dtEnded(d.stem) then
            rows[#rows + 1] = {{ text = "End Logging Now", callback = function()
                UIManager:close(dlg)
                dtEnd(d.stem)
                notify("Debugging: " .. d.name .. " stopped logging (until the next start)")
                refresh(tm)
            end }}
        end
    end
    for _i, r in ipairs({
            {{ text = "Delete Log", callback = function()
                UIManager:close(dlg)
                local files = filesOf(d)
                local n = deleteFiles(files)
                -- with the shared log, filter this diagnostic's tagged lines out
                local dropped = isShared(d) and deleteTagLines(d.stem) or 0
                if n == 0 and dropped == 0 then
                    notify("Debugging: " .. d.name .. " has no log") return
                end
                notify(string.format("Debugging: %s log cleared (%d file%s%s)", d.name,
                    n, n == 1 and "" or "s",
                    dropped > 0 and (", " .. dropped .. " lines") or ""))
                refresh(tm)
            end }},
            {{ text = "Delete Log And Patch", callback = function()
                UIManager:close(dlg)
                confirm(string.format("Delete %s and its log?\n\n%s", d.name,
                    d.base .. ".lua"), "Delete", function()
                    local files = filesOf(d)
                    for _i, p in ipairs(patchCopies(d.base)) do files[#files + 1] = p end
                    local n = deleteFiles(files)
                    if isShared(d) then deleteTagLines(d.stem) end
                    notify(string.format("Debugging: %s deleted (%d file%s)", d.name, n, n == 1 and "" or "s"))
                    refresh(tm)
                    -- it keeps running (and may write a new log) until restart
                    if running then changed() end
                end)
            end }},
            {{ text = "Cancel", callback = function() UIManager:close(dlg) end }},
        }) do rows[#rows + 1] = r end
    dlg = ButtonDialog:new{
        title = d.name,
        title_align = "center",
        buttons = rows,
    }
    UIManager:show(dlg)
end

-- ---------------------------------------------------------------------------
-- Menu
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Debug switches inside patches and plugins
-- ---------------------------------------------------------------------------
-- Debug switch contract v1: a patch lists its own in package.loaded.debug_switches,
-- [id] = { label = "...", is_on = function, off = function }. One is known here
-- too: OrbitShelf's Diagnostics (plugin setting, live through its core module).
local function settingSwitch(key, field, label)
    return {
        label = label,
        is_on = function()
            local t = G_reader_settings:readSetting(key)
            return type(t) == "table" and t[field] == true
        end,
        off = function()
            local t = G_reader_settings:readSetting(key)
            if type(t) ~= "table" then return end
            t[field] = false
            G_reader_settings:saveSetting(key, t)
        end,
    }
end

local function debugSwitches()
    local list, seen = {}, {}
    local reg = package.loaded.debug_switches
    if type(reg) == "table" then
        for id, sw in pairs(reg) do
            if type(sw) == "table" and type(sw.is_on) == "function" and type(sw.off) == "function" then
                list[#list + 1] = { id = id, label = tostring(sw.label or id), is_on = sw.is_on, off = sw.off }
                seen[id] = true
            end
        end
    end
    if not seen.orbitshelf_diagnostics then
        local O = package.loaded["orbitshelf_core"]
        if type(O) == "table" and type(O.cfg) == "table" then
            list[#list + 1] = { id = "orbitshelf_diagnostics", label = "OrbitShelf Diagnostics",
                is_on = function() return O.cfg.diagnostics == true end,
                off = function()
                    O.cfg.diagnostics = false
                    if type(O.saveConfig) == "function" then O.saveConfig() end
                end }
        else
            local sw = settingSwitch("orbitshelf_tweaks", "diagnostics", "OrbitShelf Diagnostics")
            sw.id = "orbitshelf_diagnostics"
            list[#list + 1] = sw
        end
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

local function debugOnCount()
    local n = 0
    for _i, d in ipairs(scan()) do if d.on then n = n + 1 end end
    for _i, sw in ipairs(debugSwitches()) do
        local ok, on = pcall(sw.is_on)
        if ok and on then n = n + 1 end
    end
    return n
end

local function turnOffAllDebug(tm)
    local names, moved = {}, 0
    migrate()
    dtEnd() -- the ones running stop logging now, not only from the next start
    for _i, d in ipairs(scan()) do
        if d.on and setOn(d, false) then moved = moved + 1 end
    end
    for _i, sw in ipairs(debugSwitches()) do
        local ok, on = pcall(sw.is_on)
        if ok and on then
            local okO, err = pcall(sw.off)
            if okO then
                names[#names + 1] = sw.label
            else
                logger.warn("debugging menu: couldn't turn off", sw.label, err)
            end
        end
    end
    refresh(tm)
    if moved == 0 and #names == 0 then
        notify("Debugging: nothing was on")
        return
    end
    local parts = {}
    if moved > 0 then
        parts[#parts + 1] = string.format("%d diagnostic%s", moved, moved == 1 and "" or "s")
    end
    for _i, n in ipairs(names) do parts[#parts + 1] = n end
    logger.info("debugging menu: turned off " .. table.concat(parts, ", "))
    if moved > 0 then
        notify("Debug off: " .. table.concat(parts, ", "))
        changed(true)
    else
        notify("Debug off: " .. table.concat(parts, ", "))
    end
end

-- Test Mode (2-zz-test-mode.lua): a patch switched like a diagnostic, kept apart
-- from them. Switching it off while Test Mode itself is on turns that off first,
-- through its own toggle, so its Reset Test Books question still comes.
local TEST_BASE = "2-zz-test-mode"

local function testPatch()
    local on, path = locate(TEST_BASE)
    if not path then return nil end
    return { base = TEST_BASE, name = "Test Mode", on = on, path = path }
end

local function testModeActive()
    return G_reader_settings:isTrue("test_mode")
end

local function testModeOff()
    for _i, mod in ipairs({ "apps/filemanager/filemanager", "apps/reader/readerui" }) do
        local M = package.loaded[mod]
        if type(M) == "table" and type(M.onToggleTestMode) == "function" then
            local ok, err = pcall(M.onToggleTestMode)
            if not ok then logger.warn("debugging menu: couldn't turn Test Mode off", err) end
            return
        end
    end
end

-- off: Test Mode itself first (when on), then the patch
local function setTestPatch(on)
    local d = testPatch()
    if not d or d.on == on then return false end
    if not on and testModeActive() then testModeOff() end
    return setOn(d, on)
end

local function buildItems()
    migrate()
    local items = {}
    -- Test Mode's own menu, while its patch is running and on
    local tm_menu = package.loaded.test_mode_menu
    local tp = testPatch()
    if type(tm_menu) == "function" and tp and tp.on then
        local ok_m, m = pcall(tm_menu)
        if ok_m and type(m) == "table" then
            m.separator = true
            items[#items + 1] = m
        end
    end
    items[#items + 1] = {
        text_func = function()
            local n = debugOnCount()
            local t = testPatch()
            return "Turn Off All Debug  ·  " .. (n == 0 and "all off" or (n .. " on"))
                .. ((t and t.on) and "  ·  Test Mode on" or "")
        end,
        help_text = "Switches off every diagnostic (from the next restart) and the debug switches inside your patches and plugins: OrbitShelf Diagnostics and any other patch that lists one. Those go off straight away. With the Test Mode patch on, it asks whether to switch that off too.",
        keep_menu_open = true,
        callback = function(tm)
            local t = testPatch()
            if not (t and t.on) then
                turnOffAllDebug(tm)
                return
            end
            local ConfirmBox = require("ui/widget/confirmbox")
            UIManager:show(ConfirmBox:new{
                text = "The Test Mode patch is on too. Switch it off as well?",
                ok_text = "Turn Off Test Mode Too",
                cancel_text = "Keep Test Mode",
                -- after the question has closed, so the restart question is on top
                ok_callback = function()
                    UIManager:nextTick(function()
                        local moved = setTestPatch(false)
                        if moved then
                            logger.info("debugging menu: Test Mode patch switched off")
                            -- a restart question even when nothing else moved
                            local before = asked_restart
                            turnOffAllDebug(tm)
                            if asked_restart == before then changed(true) end
                        else
                            turnOffAllDebug(tm)
                        end
                    end)
                end,
                cancel_callback = function()
                    UIManager:nextTick(function() turnOffAllDebug(tm) end)
                end,
            })
        end,
        separator = true,
    }
    local function setAll(on, tm)
        local any = false
        for _i, d in ipairs(scan()) do
            if d.on ~= on and setOn(d, on) then any = true end
        end
        refresh(tm)
        if any then changed() end
    end
    -- single toggle: any off -> all on, all on -> all off
    local function allOn()
        local n = 0
        for _i, d in ipairs(scan()) do
            n = n + 1
            if not d.on then return false end
        end
        return n > 0
    end
    items[#items + 1] = {
        text_func = function() return allOn() and "All off" or "All on" end,
        checked_func = allOn,
        keep_menu_open = true,
        callback = function(tm) setAll(not allOn(), tm) end,
        separator = true,
    }

    -- debug timing contract v1: times for all diagnostics, End Logging Now, Restart Timers
    items[#items + 1] = {
        text_func = function()
            local v = tonumber(dtRead().all.window_min)
            return "Logging Time  ·  " .. (v and titlecase(fmtMinutes(v)) or "Each Its Own")
        end,
        help_text = "How long every diagnostic logs after each KOReader start (from the next start). Each Its Own keeps each one's own time. Hold a diagnostic below to give it its own. Diagnostics that log per session or after each sleep keep doing that.",
        keep_menu_open = true,
        callback = function(tm) timingChoices(nil, "window_min", nil, function() refresh(tm) changed() end) end,
    }
    items[#items + 1] = {
        text_func = function()
            local v = tonumber(dtRead().all.expire_days)
            return "Stop After  ·  " .. (v and titlecase(fmtDays(v)) or "Each Its Own")
        end,
        help_text = "How many days after its first run a diagnostic stops for good (until Restart Timers or Delete All Logs). Each Its Own keeps each one's own limit. Hold a diagnostic below to give it its own.",
        keep_menu_open = true,
        callback = function(tm) timingChoices(nil, "expire_days", nil, function() refresh(tm) changed() end) end,
    }
    items[#items + 1] = {
        text_func = function() return "End Logging Now" .. (dtEnded("*") and "  ·  Ended" or "") end,
        help_text = "Every diagnostic that's running stops writing to its log now, until the next start. Hold a diagnostic below to end just that one.",
        enabled_func = function() return not dtEnded("*") end,
        keep_menu_open = true,
        callback = function(tm)
            dtEnd()
            notify("Debugging: diagnostics stopped logging (until the next start)")
            refresh(tm)
        end,
    }
    items[#items + 1] = {
        text = "Restart Timers",
        help_text = "Starts every diagnostic's time window again (and its days until it stops for good), from the next start. Logs are kept; Delete All Logs does this too.",
        keep_menu_open = true,
        callback = function(tm) restartTimers() refresh(tm) end,
        separator = true,
    }

    local list = scan()
    if #list == 0 then
        items[#items + 1] = { text = "No diagnostics found", enabled = false, separator = true }
    end
    for idx, d0 in ipairs(list) do
        local base = d0.base
        -- current state straight from disk (cheap: one file check)
        local function cur()
            local on, path = locate(base)
            if not path then return nil end
            d0.on, d0.path = on, path
            return d0
        end
        items[#items + 1] = {
            text_func = function()
                local d = cur()
                if not d then return d0.name .. "  ·  deleted" end
                local pending = loaded[base] ~= nil and loaded[base] ~= d.on
                -- with the shared log there is no per-diagnostic size to show
                local logpart
                if not isShared(d) then
                    local size = fmtSize(logSize(d))
                    logpart = size and ("log " .. size) or "no log"
                end
                -- its times (debug timing contract v1): window, then stop-after
                local times
                if readsTiming(d.base, d.path) then
                    local def = DT_DEFAULTS[d.stem] or {}
                    local w = dtEffective(d.stem, "window_min")
                    local e = dtEffective(d.stem, "expire_days")
                    times = (w and fmtMinutes(w) or def.per or "own window") .. ", stops after " .. fmtDays(e)
                    if loaded[base] and dtEnded(d.stem) then times = times .. ", ended" end
                else
                    times = "own times"
                end
                return titlecase(d.name .. "  ·  " .. times .. (logpart and ("  ·  " .. logpart) or "")
                    .. (pending and "  (after restart)" or ""))
            end,
            checked_func = function() local d = cur() return d and d.on end,
            enabled_func = function() return cur() ~= nil end,
            keep_menu_open = true,
            hold_callback = function(tm)
                local d = cur()
                if d then holdMenu(d, tm) end
            end,
            callback = function(tm)
                local d = cur()
                if d and setOn(d, not d.on) then refresh(tm) changed() end
            end,
            separator = (idx == #list) or nil,
        }
    end

    items[#items + 1] = {
        text_func = function()
            return "Diagnostics Log  ·  " .. (fmtSize(fileSize(SHARED_LOG)) or "none")
        end,
        enabled = false,
    }
    items[#items + 1] = { text = "Delete All Logs", keep_menu_open = true,
        callback = function(tm) deleteAll() refresh(tm) end, separator = true }
    items[#items + 1] = {
        text_func = function()
            return "Crash.log  ·  " .. (fmtSize(fileSize(CRASH)) or "none")
        end,
        enabled = false,
    }
    items[#items + 1] = { text = "Clear Crash.log", keep_menu_open = true,
        callback = function(tm) clearCrash() refresh(tm) end }
    items[#items + 1] = { text = "Combine Logs", keep_menu_open = true,
        callback = function() combine() end }
    -- Test Mode patch, on its own (not a diagnostic)
    if testPatch() then
        items[#items].separator = true
        items[#items + 1] = {
            text_func = function()
                local t = testPatch()
                if not t then return "Test Mode  ·  deleted" end
                local pending = loaded[TEST_BASE] ~= nil and loaded[TEST_BASE] ~= t.on
                return "Test Mode Patch" .. (pending and "  (after restart)" or "")
            end,
            help_text = "Switches the Test Mode patch on or off (after a restart), like a diagnostic. Switching it off while Test Mode is on turns Test Mode off first, so you can reset your test books.",
            checked_func = function() local t = testPatch() return t and t.on end,
            enabled_func = function() return testPatch() ~= nil end,
            keep_menu_open = true,
            callback = function(tm)
                local t = testPatch()
                if t and setTestPatch(not t.on) then refresh(tm) changed() end
            end,
        }
    end
    return items
end

local function menu()
    return { text = "Debugging", sub_item_table_func = buildItems }
end

-- Add-ons > Debugging, library only.
local TM = package.loaded.tweaks_mods or {}
package.loaded.tweaks_mods = TM
TM.entries = TM.entries or {}
TM.entries.debugging_menu = {
    text  = "Debugging",
    order = 900,
    where = "filemanager",
    build = menu,
    test_mode_home = true, -- Test Mode 1.0.2+ puts its menu here instead of Add-ons
}

-- Fallback: Tools > Debugging when the Add-ons patch isn't there (or hides us).
local function addToOrder()
    local ok, order = pcall(require, "ui/elements/filemanager_menu_order")
    if not ok or type(order) ~= "table" or type(order.tools) ~= "table" then return end
    for _i, v in ipairs(order.tools) do if v == "debugging_menu" then return end end
    local pos = #order.tools + 1
    for i, v in ipairs(order.tools) do
        if type(v) == "string" and v:find("^%-%-%-") then pos = i break end
    end
    table.insert(order.tools, pos, "debugging_menu")
end

local ok_fm, FileManagerMenu = pcall(require, "apps/filemanager/filemanagermenu")
if ok_fm and type(FileManagerMenu) == "table" and type(FileManagerMenu.setUpdateItemTable) == "function" then
    local orig = FileManagerMenu.setUpdateItemTable
    FileManagerMenu.setUpdateItemTable = function(self, ...)
        local in_addons = TM.active and (type(TM.shows) ~= "function" or TM.shows("debugging_menu"))
        if self.menu_items and not in_addons then
            addToOrder()
            local m = menu()
            m.sorting_hint = "tools"
            self.menu_items.debugging_menu = m
        end
        return orig(self, ...)
    end
end

-- First start: switch every diagnostic off (from the next restart), logs kept.
-- Done after start-up, once every patch has loaded, so nothing is renamed
-- while KOReader is still loading patches.
if not G_reader_settings:isTrue(FIRST_RUN_KEY) then
    UIManager:nextTick(function()
        migrate()
        local n = 0
        for _i, d in ipairs(scan()) do
            if d.on and setOn(d, false) then n = n + 1 end
        end
        G_reader_settings:saveSetting(FIRST_RUN_KEY, true)
        if n > 0 then
            notify(string.format("Debugging: %d diagnostic%s switched off on next restart",
                n, n == 1 and "" or "s"))
        end
    end)
end

logger.info("debugging menu " .. VERSION .. " loaded")
