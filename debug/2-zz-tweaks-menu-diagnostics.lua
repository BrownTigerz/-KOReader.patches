--[[
2-zz-tweaks-menu-diagnostics.lua - TEMPORARY troubleshooting patch
Version 1.1.1

Watches the Add-ons menu patch (2-tweaks-menu.lua) from outside and writes
tagged lines (shared log contract v1) to the shared diagnostics log:
    koreader/diagnostics.log
(Kobo: .adds/koreader/diagnostics.log)

What it checks:
  Load         Add-ons patch version, menu hook in place, patch entries that
               registered, your saved Add-ons choices, screen size/rotation
  Performance  every menu build: total time, split into the Add-ons part vs
               KOReader's own sort, and Lua memory before/after. Menu page
               draw times. How long each tap/hold in a menu took to handle.
  Correctness  items KOReader had to tack on as "NEW:" (an id in a menu with
               no place in the order), the same item in two places, empty
               submenus, where Add-ons ended up and how many rows it has
  Sleep        suspend/resume, time asleep, and whether the Add-ons patch
               wrote settings or rebuilt a menu right before sleep / after wake
  Flash        settings writes caused by the Add-ons patch (and which keys)
  Touch        tap/hold position, rotation and what was on top, so a tap that
               lands on the wrong row shows up
  Night mode   inverted screen on/off at start and whenever it's toggled

How to use (within 10 minutes of restarting):
  1. Put this file in koreader/patches/ next to 2-tweaks-menu.lua, restart.
  2. File browser: open the menu > Tools > Add-ons. Open a few add-ons.
  3. Open "Arrange Add-ons" ("Choose what's in Add-ons" before 1.1.0). Tap an item, then tap it again to put
     it back. Hold an item, then close the group picker (or pick the
     "(default)" group). Say no to the restart prompts.
  4. Open a book, open the menu, Tools > Add-ons again.
  5. Toggle night mode, open Add-ons again.
  6. Sleep the device for ~30 seconds, wake it, open the menu once more.
  7. Send diagnostics.log (look for the [tweaks-menu] tagged lines).
  8. Delete this file and tweaks-menu-diagnostics.stamp, restart.

In case you forget it:
  - Logs only for 10 min after KOReader starts. Using a menu adds 3 min,
    never past 20 min. After that every hook is a single time check and
    nothing is written. No timers at all: the end-of-window summary is
    written by the next menu build after the window closes.
  - 3 days after it first ran it stops logging for good and only shows a
    short "delete me" notice at startup.
  - Its own lines are capped at 256 KB (it stops writing, keeping the
    start). The shared file itself rotates at 2 MB, older part kept as
    diagnostics.log.old.

It doesn't change 2-tweaks-menu.lua. To time the Add-ons part separately it
wraps two of that patch's internal functions in memory while it runs; it also
wraps the menu builder, menu page draws, taps/holds, sleep/wake/night-mode
events and settings writes from the outside. Outside the logging window every
hook just passes straight through. The "zz" makes it load after
2-tweaks-menu.lua.

Changelog:
  1.1.1  2026-10-30  Finds Add-ons 1.1.0's "Arrange Add-ons" entry as well
                     as the older "Choose what's in Add-ons".
  1.1.0  2026-10-23  Shared perf core (the same block as the other
                     diagnostics): Add-ons timers that hold the screen
                     80 ms+, flashes it asks for, timers left waiting at
                     sleep, and a once-a-minute perf line, inside the
                     logging window. The 3 days now start per version (the
                     .stamp keeps the version), so an update isn't already
                     expired when it arrives.
  1.0.6  2026-10-22  One line per entry: messages and popups with line
                     breaks are joined with " / " (they used to split into
                     untagged lines), and the invisible text-direction
                     marks around file paths are removed.
  1.0.5  2026-10-12  Shared-log rotation cap raised from 256 KB to 2 MB
                      (SHARED_MAX_BYTES = 2 * 1024 * 1024, identical in all
                      12 diagnostics). Per-patch 256 KB write cap unchanged.
  1.0.4  2026-10-11  Correctness walk now descends each tab page (the built
                      menu is an array of tab-content arrays, so the old walk
                      never reached the Add-ons chooser); chooser detection
                      matches the title-case "Choose What's In Add-ons" from
                      Tweaks Menu v1.0.4 as well as the old sentence case.
  1.0.3  2026-10-11  Shared log contract v1: log lines go to the shared
                      koreader/diagnostics.log tagged [tweaks-menu] instead
                      of tweaks-menu-diagnostics.log; per-patch 256 KB write
                      cap kept, the shared file rotates to diagnostics.log.old.
  1.0.2  2026-10-11  Shared notification contract v1: status notes first try
                      Network Tweaks' then ReadMastery's notification style,
                      falling back to the stock notification; nothing is shown
                      over the sleep screen.
  1.0.1  2026-10-11  Spec compliance: date on every log line; first line in
                      the prescribed "started" format; expiry writes one line
                      to the diagnostics log; no scheduleIn — the end-of-window
                      summary is written by the next menu build after the
                      window closes; header documents every pass-through hook;
                      build-timing state saved/restored around re-entrant
                      menu builds.
  1.0.0  2026-10-08  First release.
]]

local PATCH_VERSION = "1.1.1"

local WINDOW_S  = 10 * 60          -- logging window after KOReader starts
local EXTEND_S  = 3 * 60           -- menu use keeps it open this much longer
local MAX_S     = 20 * 60          -- never past this, whatever happens
local EXPIRE_S  = 3 * 24 * 3600    -- stop for good this long after first run
local MAX_BYTES = 256 * 1024       -- log size cap
local SLOW_BUILD_MS = 300          -- flag menu builds slower than this
local SLOW_TAP_MS   = 500          -- flag taps/holds handled slower than this
local SLOW_DRAW_MS  = 250          -- log any menu page draw slower than this

local logger = require("logger")
local TAG = "tweaks-menu-diag:"

local ok_setup, setup_err = pcall(function()

local DataStorage = require("datastorage")
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")
local _ = require("gettext")
local ok_time, ktime = pcall(require, "ui/time")

local DIR   = DataStorage:getDataDir()
local STAMP = DIR .. "/tweaks-menu-diagnostics.stamp"

-- Shared log contract v1: all diagnostics append timestamped, tagged lines
-- to ONE file (koreader/diagnostics.log) so a full test run reads as a
-- single chronological log. Rotation at 2 MB, older part kept as
-- diagnostics.log.old.
local DIAG_TAG = "tweaks-menu"
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

local function pack(...) return { n = select("#", ...), ... } end
local function q(v) return v == nil and "(nil)" or tostring(v) end

-- Shared notification contract v1: user-facing status notes first try the
-- installed patches' styles (Network Tweaks, then ReadMastery notify),
-- falling back to the stock notification below. Checked at call time, so
-- patch load order doesn't matter. Returns true when the note was handled
-- (or deliberately hidden, e.g. over the sleep screen).
local function shared_note(banner_text, minimal_text, timeout)
    local okd, Device = pcall(require, "device")
    if okd and Device.screen_saver_mode then return true end -- never over the sleep screen
    local okn, NetworkMgr = pcall(require, "ui/network/manager")
    if okn and type(NetworkMgr) == "table"
        and type(NetworkMgr.__network_tweaks_note) == "function" then
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
    UIManager:nextTick(function()
        if not shared_note(text, text) then
            pcall(function() require("ui/widget/notification"):notify(text) end)
        end
    end)
end

-- ---- Expiry: 3 days after first run, stop for good --------------------------------
local started = os.time()
local first_run
do
    -- version on line 1, first run on line 2: another version (or an older
    -- stamp with just a time) starts a new 3 days
    local f = io.open(STAMP, "r")
    if f then
        local v, t = f:read("*l"), tonumber(f:read("*l") or "")
        f:close()
        if v == PATCH_VERSION and t and t <= started then first_run = t end
    end
    if not first_run then
        first_run = started
        f = io.open(STAMP, "w")
        if f then f:write(PATCH_VERSION, "\n", first_run, "\n"); f:close() end
    end
end
if started - first_run > EXPIRE_S then
    shared_log("diagnostics expired (3 days since first run), not logging; delete 2-zz-tweaks-menu-diagnostics.lua")
    logger.info(TAG, "v" .. PATCH_VERSION .. " expired, not logging")
    notify("Add-ons diagnostics expired: delete 2-zz-tweaks-menu-diagnostics.lua")
    return
end

-- ---- Log + window ---------------------------------------------------------------
local deadline = started + WINDOW_S
local hard_end = started + MAX_S
local closed = false
local t_start = ok_time and ktime.now() or nil

local function now() return ok_time and ktime.now() or nil end

local function ms(since)
    if not (ok_time and since) then return -1 end
    local ok, v = pcall(function() return ktime.to_ms(ktime.since(since)) end)
    return ok and v or -1
end

local function active()
    return not closed and os.time() <= deadline
end

local function extend()
    if active() then
        deadline = math.min(hard_end, math.max(deadline, os.time() + EXTEND_S))
    end
end

local bytes = 0   -- counts only this patch's lines toward its 256 KB cap

local log_full = false
local function log(fmt, ...)
    if log_full then return end
    local ok, line = pcall(string.format, fmt, ...)
    if not ok then line = tostring(fmt) end
    line = string.format("+%6.1fs  ", ms(t_start) / 1000) .. line
    shared_log("%s", line)
    bytes = bytes + #line
    if bytes > MAX_BYTES then
        log_full = true
        shared_log("---- log full (256 KB), stopped writing ----")
    end
end

local stats = {
    builds = 0, build_total = 0, build_max = 0,
    addons_total = 0, addons_max = 0, addons_n = 0,
    tap_max = 0, taps = 0, draw_max = 0, draws = 0,
    flushes = 0, suspends = 0, warnings = 0,
}
local function warn(fmt, ...)
    stats.warnings = stats.warnings + 1
    log("WARNING: " .. fmt, ...)
end

-- ---- What's loaded ----------------------------------------------------------------
local function count(t, skip_prefix)
    local n = 0
    if type(t) == "table" then
        for k in pairs(t) do
            if not (skip_prefix and type(k) == "string" and k:sub(1, #skip_prefix) == skip_prefix) then n = n + 1 end
        end
    end
    return n
end

local function keys(t)
    local out = {}
    if type(t) == "table" then for k in pairs(t) do out[#out + 1] = tostring(k) end end
    table.sort(out)
    return table.concat(out, ", ")
end

local function nightMode()
    return G_reader_settings and G_reader_settings:isTrue("night_mode")
end

local Screen
do
    local ok, Device = pcall(require, "device")
    Screen = ok and Device and Device.screen
end
local function rotation()
    if not Screen then return "?" end
    local ok, r = pcall(Screen.getRotationMode, Screen)
    return ok and q(r) or "?"
end

local kover = "?"
pcall(function() kover = require("version"):getCurrentRevision() end)
local model = "?"
pcall(function() model = require("device").model end)

log("==================== tweaks-menu diagnostics v%s started ====================", PATCH_VERSION)
log("KOReader %s on %s | logging until %s (up to %s if menus are in use)",
    q(kover), q(model), os.date("%I:%M %p", deadline), os.date("%I:%M %p", hard_end))
log("diagnostics first ran %s, stops for good %s",
    os.date("%b %d %I:%M %p", first_run), os.date("%b %d %I:%M %p", first_run + EXPIRE_S))

local TM = package.loaded.tweaks_mods
local ok_ms, MenuSorter = pcall(require, "ui/menusorter")
if not (type(TM) == "table" and TM.active) then
    log("Add-ons patch (2-tweaks-menu.lua) isn't loaded: nothing to watch")
    notify("Add-ons diagnostics: 2-tweaks-menu.lua isn't loaded")
    return
end
if not (ok_ms and type(MenuSorter) == "table") then
    log("couldn't load KOReader's menu sorter: nothing to watch")
    return
end

log("Add-ons patch %s | menu hook in place: %s",
    TM.version and ("v" .. TM.version) or "(older than 1.0.1, no version)", q(MenuSorter._tweaks_mods_hooked))
if not MenuSorter._tweaks_mods_hooked then warn("Add-ons patch couldn't hook the menu sorter, so it does nothing") end

do
    local list = {}
    for id, e in pairs(TM.entries or {}) do
        list[#list + 1] = string.format("%s (%s%s)", tostring(id),
            type(e) == "table" and q(e.where or "both") or "?",
            (type(e) == "table" and type(e.build) == "function") and "" or ", NO build()")
    end
    table.sort(list)
    log("patch entries registered: %d%s", #list, #list > 0 and (" - " .. table.concat(list, ", ")) or "")
end

if G_reader_settings then
    local ex = G_reader_settings:readSetting("addons_menu_excluded")
    local gr = G_reader_settings:readSetting("addons_menu_groups")
    local kn = G_reader_settings:readSetting("addons_menu_known")
    local nw = G_reader_settings:readSetting("addons_menu_new")
    log("saved: turned off %d [%s] | moved to another group %d [%s]", count(ex), keys(ex), count(gr), keys(gr))
    log("saved: add-ons known %d | still marked New %d [%s] | first-run done: fm %s, reader %s",
        count(kn, "@"), count(nw), keys(nw),
        q(type(kn) == "table" and kn["@first_run_done:filemanager"]),
        q(type(kn) == "table" and kn["@first_run_done:reader"]))
end

local mem_start = collectgarbage("count")
log("screen %sx%s, rotation %s | night mode (inverted) %s | Lua memory %.0f KB",
    Screen and q(Screen:getWidth()) or "?", Screen and q(Screen:getHeight()) or "?",
    rotation(), nightMode() and "ON" or "off", mem_start)

-- ---- Timing the Add-ons part vs KOReader's own sort -------------------------------
-- Both are upvalues of the Add-ons patch's MenuSorter.sort wrapper. If they
-- can't be found (another patch wrapped sort after it, or names changed),
-- only the total build time is logged.
local cur          -- the build in progress: { where, addons_ms, stock_ms, rows, hidden }

local function findUpvalue(fn, name)
    if type(fn) ~= "function" or type(debug) ~= "table" or not debug.getupvalue then return end
    for i = 1, 64 do
        local n, v = debug.getupvalue(fn, i)
        if n == nil then return end
        if n == name then return i, v end
    end
end

local sort_wrapper = MenuSorter.sort
local i_inject, inject = findUpvalue(sort_wrapper, "inject")
local i_stock, stock_sort = findUpvalue(sort_wrapper, "orig_sort")
local split = false

if i_inject and type(inject) == "function" then
    debug.setupvalue(sort_wrapper, i_inject, function(where, items, order)
        if not (active() and cur) then return inject(where, items, order) end
        local t = now()
        local ok, res = pcall(inject, where, items, order)
        local d = ms(t)
        cur.addons_ms = (cur.addons_ms or 0) + d
        if not ok then
            warn("Add-ons build FAILED in %s (menu left as is): %s", q(where), q(res))
            error(res, 0)   -- the Add-ons patch catches this, same as without diagnostics
        end
        if type(res) == "table" then
            local rows, seps = 0, 0
            for _i, v in ipairs(res[TM.menu_id or "tweaks_mods"] or {}) do
                if type(v) == "string" and v:find("^%-%-%-") then seps = seps + 1 else rows = rows + 1 end
            end
            cur.rows, cur.seps = rows, seps
            local before = type(order["KOMenu:disabled"]) == "table" and #order["KOMenu:disabled"] or 0
            local after = type(res["KOMenu:disabled"]) == "table" and #res["KOMenu:disabled"] or 0
            cur.hidden = after - before
        else
            cur.rows = "none (menu left as is)"
        end
        return res
    end)
    split = true
end
if i_stock and type(stock_sort) == "function" then
    debug.setupvalue(sort_wrapper, i_stock, function(self, item_table, order, ...)
        if not (active() and cur) then return stock_sort(self, item_table, order, ...) end
        local t = now()
        local r = pack(stock_sort(self, item_table, order, ...))
        cur.stock_ms = (cur.stock_ms or 0) + ms(t)
        return unpack(r, 1, r.n)
    end)
else
    split = false
end
log("build timing split (Add-ons vs KOReader): %s", split and "yes" or "no, totals only")

-- ---- Checking the built menu ------------------------------------------------------
-- "Choose what's in Add-ons" (title-cased in v1.0.4) became "Arrange Add-ons"
-- in v1.1.0; match any form so detection works before and after
local CHOOSER_TEXTS = { [_("Choose what's in Add-ons"):lower()] = true, [_("Arrange Add-ons"):lower()] = true }
local function isChooser(it)
    return type(it) == "table" and type(it.text) == "string"
        and CHOOSER_TEXTS[it.text:lower()] == true
end

local function itemName(it)
    if type(it) ~= "table" then return q(it) end
    if type(it.text) == "string" then return it.text end
    if it.text_func then return "(dynamic text)" end
    if it.icon then return "[" .. tostring(it.icon) .. "]" end
    return "?"
end

local function checkMenu(where, menu)
    if type(menu) ~= "table" then return end
    local where_seen, total = {}, 0
    local news, dups, empties = {}, {}, {}
    local addons_path, addons_rows
    local function walk(list, path, depth)
        if depth > 8 then return end
        for _i, it in ipairs(list) do
            if type(it) == "table" then
                local name = itemName(it)
                if where_seen[it] then
                    dups[#dups + 1] = string.format("\"%s\" in %s and %s", name, where_seen[it], path)
                else
                    where_seen[it] = path
                    total = total + 1
                    if type(it.text) == "string" and it.text:find("^NEW:") then news[#news + 1] = path .. " > " .. it.text end
                    if isChooser(it) then addons_path, addons_rows = path, #list end
                    local sub = it.sub_item_table
                    if type(sub) == "table" then
                        if #sub == 0 then empties[#empties + 1] = path .. " > " .. name end
                        walk(sub, path .. " > " .. name, depth + 1)
                    end
                end
            end
        end
    end
    -- the built menu is a list of tab pages (one array of items per tab);
    -- walk each page's items (a page itself has no .text/.sub_item_table)
    for _i, page in ipairs(menu) do
        if type(page) == "table" then walk(page, where, 1) end
    end

    log("  menu has %d items | Add-ons: %s", total,
        addons_path and string.format("%s (%d rows incl. headers + chooser)", addons_path, addons_rows) or "NOT FOUND")
    if not addons_path then warn("Add-ons menu not found in the %s menu", q(where)) end
    if #news > 0 then warn("%d item(s) KOReader added as NEW: (no place in the menu order): %s", #news, table.concat(news, " | ")) end
    if #dups > 0 then warn("same item in two places: %s", table.concat(dups, " | ")) end
    if #empties > 0 then log("  empty submenus (may be normal for some plugins): %s", table.concat(empties, " | ")) end
end

-- ---- Menu builds ------------------------------------------------------------------
local last_build, last_flush, asleep_since, woke_at   -- os.time() stamps
local close  -- forward declaration; defined in the end-of-window section below

local orig_mas = MenuSorter.mergeAndSort
MenuSorter.mergeAndSort = function(self, prefix, ...)
    if not active() then
        if not closed then close() end
        return orig_mas(self, prefix, ...)
    end
    local prev_cur = cur
    cur = { where = prefix }
    local mem0 = collectgarbage("count")
    local t = now()
    local r = pack(pcall(orig_mas, self, prefix, ...))
    local total = ms(t)
    local b = cur
    cur = prev_cur
    if not r[1] then
        warn("menu build for %s crashed: %s", q(prefix), q(r[2]))
        error(r[2], 0)
    end

    stats.builds = stats.builds + 1
    stats.build_total = stats.build_total + total
    stats.build_max = math.max(stats.build_max, total)
    if b.addons_ms then
        stats.addons_n = stats.addons_n + 1
        stats.addons_total = stats.addons_total + b.addons_ms
        stats.addons_max = math.max(stats.addons_max, b.addons_ms)
    end
    local after_wake = woke_at and (os.time() - woke_at) <= 5
    log("menu build #%d (%s)%s: %dms total%s | Add-ons rows %s, separators %s, built-in submenus hidden %s | Lua memory %+.0f KB",
        stats.builds, q(prefix), after_wake and " right after wake" or "", total,
        split and string.format(" = Add-ons %dms + KOReader sort %dms + merge %dms",
            b.addons_ms or 0, b.stock_ms or 0, total - (b.addons_ms or 0) - (b.stock_ms or 0)) or "",
        q(b.rows), q(b.seps), q(b.hidden), collectgarbage("count") - mem0)
    if total > SLOW_BUILD_MS then warn("slow menu build: %dms", total) end
    checkMenu(prefix, r[2])
    last_build = os.time()
    extend()
    return unpack(r, 2, r.n)
end

-- ---- Menu page draws --------------------------------------------------------------
local ok_tm, TouchMenu = pcall(require, "ui/widget/touchmenu")
if ok_tm and type(TouchMenu) == "table" and type(TouchMenu.updateItems) == "function" then
    local orig_update = TouchMenu.updateItems
    TouchMenu.updateItems = function(self, ...)
        if not active() then return orig_update(self, ...) end
        local t = now()
        local r = pack(orig_update(self, ...))
        local d = ms(t)
        stats.draws = stats.draws + 1
        stats.draw_max = math.max(stats.draw_max, d)
        local page, is_addons = self.item_table, false
        if type(page) == "table" then
            for _i, it in ipairs(page) do
                if isChooser(it) then is_addons = true break end
            end
        end
        if is_addons or d > SLOW_DRAW_MS then
            log("menu page drawn%s: %d rows, %dms", is_addons and " (Add-ons)" or "",
                type(page) == "table" and #page or -1, d)
        end
        return unpack(r, 1, r.n)
    end
end

-- ---- Sleep, night mode, taps ------------------------------------------------------
local WATCH = { onSuspend = true, onResume = true, onToggleNightMode = true, onSetNightMode = true }

local function since(t) return t and string.format("%ds ago", os.time() - t) or "never" end

local function watched(handler, phase)
    if handler == "onSuspend" and phase == "before" then
        stats.suspends = stats.suspends + 1
        asleep_since = os.time()
        log("SLEEP: going to sleep | last menu build %s | last Add-ons settings write %s",
            since(last_build), since(last_flush))
        if last_flush and os.time() - last_flush <= 2 then warn("Add-ons wrote settings right before sleep") end
    elseif handler == "onResume" and phase == "after" then
        woke_at = os.time()
        log("WAKE: asleep %s | window %s", asleep_since and ((os.time() - asleep_since) .. "s") or "?",
            os.time() <= deadline and "still open" or "over, closing")
        asleep_since = nil
        extend()
    elseif (handler == "onToggleNightMode" or handler == "onSetNightMode") and phase == "after" then
        log("night mode (inverted) now %s", nightMode() and "ON" or "off")
        extend()
    end
end

local function watchedEvent(orig)
    return function(self, ev, ...)
        local h = type(ev) == "table" and ev.handler
        if not (h and WATCH[h] and (active() or (h == "onResume" and asleep_since))) then
            return orig(self, ev, ...)
        end
        watched(h, "before")
        local r = pack(orig(self, ev, ...))
        watched(h, "after")
        return unpack(r, 1, r.n)
    end
end
UIManager.broadcastEvent = watchedEvent(UIManager.broadcastEvent)

local function describe(w)
    if type(w) ~= "table" then return q(w) end
    if type(w[1]) == "table" and type(w[1].item_table) == "table" then return "main menu" end
    if type(w.item_table) == "table" then return "menu" end
    local text = w.title or w.text
    if text then
        text = tostring(text):gsub("\n", " "):sub(1, 60)
        return string.format("%s \"%s\"", w.buttons and "dialog" or "popup", text)
    end
    return q(w.name or "widget")
end

local orig_send = UIManager.sendEvent
local send_watch = watchedEvent(orig_send)
UIManager.sendEvent = function(self, ev, ...)
    if not active() or type(ev) ~= "table" then return send_watch(self, ev, ...) end
    if ev.handler ~= "onGesture" then return send_watch(self, ev, ...) end
    local g = ev.args and ev.args[1]
    if type(g) ~= "table" or (g.ges ~= "tap" and g.ges ~= "hold") then return orig_send(self, ev, ...) end
    local top = self._window_stack and self._window_stack[#self._window_stack]
    local w = top and top.widget
    -- only overlays (menus, dialogs), not page turns in the book or file list
    if type(w) == "table" and (w.name == "ReaderUI" or w.name == "filemanager") then
        return orig_send(self, ev, ...)
    end
    local on = describe(w)
    local t = now()
    local r = pack(orig_send(self, ev, ...))
    local d = ms(t)
    stats.taps = stats.taps + 1
    stats.tap_max = math.max(stats.tap_max, d)
    log("%s at %s,%s (rotation %s) on %s: handled in %dms", g.ges,
        q(g.pos and g.pos.x), q(g.pos and g.pos.y), rotation(), on, d)
    if d > SLOW_TAP_MS then warn("slow %s: %dms", g.ges, d) end
    extend()
    return unpack(r, 1, r.n)
end

local orig_show = UIManager.show
UIManager.show = function(self, w, ...)
    if active() and type(w) == "table" and (w.text or w.title) then log("show %s", describe(w)) end
    return orig_show(self, w, ...)
end

-- ---- Settings writes from the Add-ons patch ---------------------------------------
local function fromAddons()
    for level = 3, 14 do
        local info = debug.getinfo(level, "S")
        if not info then return false end
        if info.source and info.source:find("2%-tweaks%-menu%.lua") then return true end
    end
    return false
end

if G_reader_settings and type(G_reader_settings.flush) == "function" then
    local orig_flush = G_reader_settings.flush
    G_reader_settings.flush = function(s, ...)
        if active() and fromAddons() then
            stats.flushes = stats.flushes + 1
            last_flush = os.time()
            log("settings written to flash by Add-ons (#%d)", stats.flushes)
        end
        return orig_flush(s, ...)
    end
    local orig_save = G_reader_settings.saveSetting
    G_reader_settings.saveSetting = function(s, key, ...)
        if active() and type(key) == "string" and key:find("^addons_menu_") then
            log("setting saved: %s", key)
        end
        return orig_save(s, key, ...)
    end
end

-- ---- End of window: summary -------------------------------------------------------
-- No timers: the summary is written by the first menu build after the window
-- closes (see the mergeAndSort wrapper above).
function close()
    if closed then return end
    closed = true
    local avg = function(total, n) return n > 0 and math.floor(total / n + 0.5) or 0 end
    log("==================== summary ====================")
    log("menu builds %d: avg %dms, max %dms | Add-ons part avg %dms, max %dms",
        stats.builds, avg(stats.build_total, stats.builds), stats.build_max,
        avg(stats.addons_total, stats.addons_n), stats.addons_max)
    log("menu taps/holds %d, slowest %dms | menu page draws %d, slowest %dms",
        stats.taps, stats.tap_max, stats.draws, stats.draw_max)
    log("Add-ons settings writes to flash %d | sleeps %d | warnings %d",
        stats.flushes, stats.suspends, stats.warnings)
    log("Lua memory %.0f KB at start, %.0f KB now", mem_start, collectgarbage("count"))
    log("logging stopped. Delete this patch and the .stamp file when done.")
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

-- The Add-ons patch's own file: its timers that hold the screen 80 ms+,
-- flashes it asks for, timers it leaves waiting at sleep, and a
-- once-a-minute perf line, all inside the logging window.
DiagCore.client({
    name = "Add-ons menu",
    targets = { "2-tweaks-menu.lua" },
    on = function() return active() end,
    log = log,
    errors = false, -- its warnings are watched above
})

logger.info(TAG, "v" .. PATCH_VERSION .. " loaded, logging to " .. SHARED_LOG)
notify("Add-ons diagnostics: logging for 10 min")

end)

if not ok_setup then
    logger.warn(TAG, "v" .. PATCH_VERSION .. " couldn't start:", setup_err)
end
