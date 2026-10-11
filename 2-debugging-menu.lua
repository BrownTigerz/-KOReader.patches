--[[
2-debugging-menu.lua
Version 1.3.1

Adds Add-ons > Debugging (library only) to switch your diagnostic patches on
and off, and to tidy up their logs. Your diagnostic patches are never edited.

  • One toggle for all diagnostics, plus one checkbox per diagnostic.
  • All diagnostics write to one shared log: koreader/diagnostics.log.
    Each line is tagged with the diagnostic's short name, so a full test
    run reads as a single chronological file. The menu shows its size once.
  • Switching moves the file: on = in patches/, off = in patches/debug/.
    KOReader only loads patches sitting directly in patches/, so an off
    diagnostic doesn't load and costs nothing, and the folder stays tidy.
    Changes apply after a restart (asked once). Old-style ".lua.disabled"
    diagnostics in patches/ are moved into debug/ the first time.
  • Combine logs for sending: writes the shared diagnostics log (once),
    plus the end of crash.log, into one file: koreader/debug-all.log.
  • Delete all logs: removes every .log file except version.log and
    crash.log, plus the diagnostics' stamp/state files (this also
    restarts their time windows), plus orphaned .state files left
    behind by removed patches. Asks first. Clearing crash.log stays
    a separate option below.
  • Hold a diagnostic: filter its lines out of the shared log, or delete
    its log lines and the patch itself.
  • crash.log: shows its size, "Clear crash.log" empties it (asks first).
    version.log (KOReader's update history) is never touched.

Diagnostics are found automatically: any patch with "diagnostic" or
"buildtime" in its name. On the very first start, all of them are switched
off (from the next restart); logs are left alone.

Without the Add-ons patch (2-tweaks-menu.lua), or when Debugging is hidden
there, it shows up as Tools > Debugging instead.

Changelog
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

local VERSION = "1.3.1"
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

local function prettyName(stem)
    if NAMES[stem] then return NAMES[stem] end
    local s = stem:gsub("[-_]", " ")
    return (s:gsub("^%l", string.upper))
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
for _i, d in ipairs(scan()) do loaded[d.base] = d.on end

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
local function changed()
    if asked_restart then
        notify("Debugging: restart KOReader to apply")
        return
    end
    asked_restart = true
    UIManager:askForRestart("Diagnostics change after a restart.")
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
        notify("Debugging: no diagnostic logs yet (debug-all.log has crash.log only)")
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
    confirm(string.format("Delete %d log/state file%s?\n\nOnly version.log and crash.log are kept.",
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

local function holdMenu(d, tm)
    local ButtonDialog = require("ui/widget/buttondialog")
    local dlg
    local running = loaded[d.base] == true
    dlg = ButtonDialog:new{
        title = d.name,
        title_align = "center",
        buttons = {
            {{ text = "Delete log", callback = function()
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
            {{ text = "Delete log and patch", callback = function()
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
        },
    }
    UIManager:show(dlg)
end

-- ---------------------------------------------------------------------------
-- Menu
-- ---------------------------------------------------------------------------

local function buildItems()
    migrate()
    local items = {}
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

    local list = scan()
    if #list == 0 then
        items[#items + 1] = { text = "No diagnostics found in patches/", enabled = false, separator = true }
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
                if isShared(d) then
                    logpart = "shared log"
                else
                    local size = fmtSize(logSize(d))
                    logpart = size and ("log " .. size) or "no log"
                end
                return d.name .. "  ·  " .. logpart
                    .. (pending and "  (after restart)" or "")
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
            return "Diagnostics log  ·  " .. (fmtSize(fileSize(SHARED_LOG)) or "none")
        end,
        enabled = false,
    }
    items[#items + 1] = { text = "Combine logs for sending", keep_menu_open = true,
        callback = function() combine() end }
    items[#items + 1] = { text = "Delete all logs", keep_menu_open = true,
        callback = function(tm) deleteAll() refresh(tm) end, separator = true }
    items[#items + 1] = {
        text_func = function()
            return "crash.log  ·  " .. (fmtSize(fileSize(CRASH)) or "none")
        end,
        enabled = false,
    }
    items[#items + 1] = { text = "Clear crash.log", keep_menu_open = true,
        callback = function(tm) clearCrash() refresh(tm) end }
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
            notify(string.format("Debugging: %d diagnostic%s switched off from next restart",
                n, n == 1 and "" or "s"))
        end
    end)
end

logger.info("debugging menu " .. VERSION .. " loaded")
