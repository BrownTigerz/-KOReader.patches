--[[
2-zz-track-reading-location-diagnostics.lua - TEMPORARY troubleshooting patch
Version 1.1.6

Changelog:
  1.1.6 - Shared-log rotation cap raised 256 KB -> 2 MB
          (SHARED_MAX_BYTES = 2 * 1024 * 1024, identical across all 12
          diagnostics).
  1.1.5 - Long watch: active window 30 awake-min -> 5 wall-clock days
          from first run (WATCH_DAYS; hooks go idle after), per-start
          awake-minutes backstop raised to 5 days, hard expiry 3 -> 10
          days (CAP_DAYS). For tracking location behavior across many
          real reading sessions.
  1.1.4 - Menu-injection check (HIGH from the diagnostics coverage audit):
          hooks ReaderLink.addToMainMenu and verifies the tracker's
          "Reading Location" group entry actually landed in menu_items with
          its 3 rows, and that reader_menu_order.navi contains the key.
          Previously only the Dispatcher handlers were hooked, which exist
          even when the menu hook silently fails (readermenu.lua wraps every
          addToMainMenu call in pcall).
  1.1.3 - Shared log contract v1: writes tagged lines to the shared
          koreader/diagnostics.log (tag [track-reading-location]) instead of
          its own file, with the 2 MB rotation now applied to the shared
          file. The old individual LOG const is gone.
  1.1.2 - Follows the Debugging-menu diagnostics contract:
          - no more 250ms poll loop. The auto-dismiss firing is caught by
            wrapping the scheduled dismiss action (unschedule calls are
            translated so cancelling the timer still removes the wrapper);
            the frozen-screen detector is gone - the contract forbids
            heartbeats. Screen set-up is sampled at hooked events instead.
          - the 3-day cap is checked before anything is hooked: after expiry
            this file writes one line to the log and returns.
          - first line per start is the contract banner; every timestamp now
            includes the date (os.date("%Y-%m-%d %I:%M:%S %p")).
          - the first-run stamp lives in
            track-reading-location-diagnostics.state (the old
            G_reader_settings key is deleted on load).
          - suspend goes through the window system instead of writing
            straight to disk.
  1.1.1 - timer_set_at local moved above the onSuspend hook; zonesAhead
          pcall-wrapped in onTap; gs_range.rate zones skipped; the
          VERSION-keyed stamp restarts the 3-day cap for a new version.
  1.1.0 - Also logged: the screen set-up at the start of every window (night
          mode, rotation, touch / reading-order inversion, footer), a line
          whenever night mode or rotation changes, sleep and wake (how long
          the device slept and what the auto-dismiss timer did across it),
          which touch zones sit in front of the popup when a tap misses it,
          memory use, and how much time this patch itself uses.

Watches Track Reading Location from the outside and writes what it sees as
tagged lines to the shared log (shared log contract v1):
    koreader/diagnostics.log  (tag [track-reading-location])
(Kobo: .adds/koreader/diagnostics.log)

How to use:
  1. Put this file in koreader/patches/ next to 2-track-reading-location.lua
     and restart KOReader. (The "zz" makes it load after that patch.)
  2. Just read. Ordinary silent page turns write nothing - the last 40 are
     kept in memory only. A detailed 90s window opens by itself whenever
     something interesting happens: a popup shows or hides, a jump, the
     auto-dismiss timer, a tap on the popup, a go-back / set-anchor, a
     reflow, a slow page update, or one of the checks below fails. The
     turns that led up to it are written first.
  3. Optional: bind "Reading location diagnostics: mark this moment" to a
     gesture (Taps and gestures). Use it right after you see something odd
     that didn't flag itself: it writes the last 40 turns plus the next 90s.
  4. Send diagnostics.log (and say roughly what time it happened - every
     line has a date and clock time, tagged [track-reading-location]).
  5. Unbind the gesture if you made one, delete this file, restart. It
     changes nothing in the tracker, it only writes the log.

What it checks after every page turn (each reported once when it starts
being wrong, and "cleared" when it stops):
  - the popup matches the rule (backward > 1 page, forward > 2 pages)
  - a forward popup always has its auto-dismiss timer, and only then
  - a timer and the "pending promotion" flag never exist together
  - the tracker saw the page KOReader reported (its hook didn't error)
  - the anchor is inside the book, and (EPUB etc.) its xpointer still
    resolves to the anchor page
  - the saved anchor on disk matches the live one after a save / suspend
  - the timer is gone once the book closes
  - a tap inside the popup actually changes something (touch-zone clashes)
  - any warning the tracker itself logs (errors it swallows)
It also times page updates and paints with and without the popup.

When the reader menu is built it also checks the tracker's menu injection:
the "Reading Location" group entry is in menu_items with its 3 rows, and
reader_menu_order.navi contains its key (the Dispatcher handlers hooked
above exist even when the menu hook silently fails).

Also logged: the screen set-up at the start of every window (night mode,
rotation, touch / reading-order inversion, footer), a line whenever night
mode or rotation changes, sleep and wake (how long the device slept and what
the auto-dismiss timer did across it), which touch zones sit in front of the
popup when a tap misses it, memory use, and how much time this patch itself
uses.

AUTO-STOP: it turns itself off so it can't be forgotten.
  - After 5 days of wall-clock time (WATCH_DAYS below) it writes a summary,
    shows "safe to delete" once, and every hook becomes a plain pass-through.
    A per-start backstop of EXPIRE_MIN awake minutes also exists (the
    scheduler clock doesn't tick while asleep). The "mark this moment"
    gesture re-arms the per-start timer.
  - For good after 10 days (CAP_DAYS) from the first run of this version.
    Nothing restarts it; a new version of this file starts a new 10 days.

It only wraps things, then calls the originals. Everything it does is
wrapped in pcall, so a bug in here can't break reading. While no window is
open it does a few microseconds of bookkeeping per page turn and writes
nothing to disk.
]]

local DataStorage = require("datastorage")
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local Device = require("device")
local ReaderUI = require("apps/reader/readerui")
local ReaderView = require("apps/reader/modules/readerview")
local ok_time, ktime = pcall(require, "ui/time")
local ok_bd, BD = pcall(require, "ui/bidi")

local VERSION = "1.1.6"
local STATE = DataStorage:getDataDir() .. "/track-reading-location-diagnostics.state"

-- Shared log contract v1: all diagnostics append timestamped, tagged lines
-- to ONE file (koreader/diagnostics.log) so a full test run reads as a
-- single chronological log. Rotation at 2 MB, older part kept as
-- diagnostics.log.old.
local DIAG_TAG = "track-reading-location"
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
local SESSION_S = 90        -- how long a detailed window stays open
local RING_MAX = 40         -- quiet turns kept in memory for the lead-up
local SLOW_TURN_MS = 80     -- a page update slower than this is flagged
local EXPIRE_MIN = 7200      -- awake minutes before it switches itself off (5 days; the wall-clock watch below normally ends the watch first)
local WATCH_DAYS = 5         -- active watch: wall-clock days from the first run, then hooks go idle
local CAP_DAYS = 10          -- hard stop, counted from the first run
local MEM_FLAG_KB = 1024    -- memory growth over one window that gets flagged

local function pack(...) return { n = select("#", ...), ... } end
local function q(v) return v == nil and "(nil)" or tostring(v) end
local function yn(b) return b and "yes" or "no" end
local function d(n) return math.floor((n or 0) + 0.5) end
local function short(v)
    local t = tostring(v)
    return #t > 70 and (t:sub(1, 67) .. "...") or t
end

-- --------------------------------------------------------------------------
-- Clock, log file, quiet ring buffer, detailed window ("session")
-- --------------------------------------------------------------------------

local function now() return ok_time and ktime.now() or nil end

local function ms(since)
    if not (ok_time and since) then return -1 end
    local ok, v = pcall(function() return ktime.to_ms(ktime.since(since)) end)
    return ok and v or -1
end

local function us(since)
    if not (ok_time and since) then return 0 end
    local ok, v = pcall(function() return ktime.to_us(ktime.since(since)) end)
    return ok and v or 0
end

local expired = false
local rearm
local ovh = { n = 0, us = 0, max = 0, wr_n = 0, wr_us = 0 }   -- this patch's own cost
local function spent(since)
    local u = us(since)
    ovh.n, ovh.us = ovh.n + 1, ovh.us + u
    if u > ovh.max then ovh.max = u end
end

local t0                    -- start of the open window
local active_until = 0
local ring = {}
local counters = { turns = 0, logged = 0, anomalies = 0 }
local paint = {}
local current_ui            -- the reader we're watching
local summary               -- defined below

local function active() return not expired and t0 ~= nil and os.time() <= active_until end
local function clock() return os.date("%Y-%m-%d %I:%M:%S %p") end

-- The gating (expired / force) stays here; the append itself is shared_log.
-- Callers already embed the clock date into their lines, so the leading
-- timestamp is stripped here (shared_log adds date, time, and tag itself) -
-- line content is otherwise unchanged.
local function write(line, force)
    if expired and not force then return end
    local wt = now()
    shared_log("%s", tostring(line):gsub("^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d %a%a%s*", ""))
    ovh.wr_n, ovh.wr_us = ovh.wr_n + 1, ovh.wr_us + us(wt)
end

-- Inside a window: write it. Outside: keep it in memory for the lead-up.
local function event(text)
    if expired then return end
    if active() then
        active_until = math.max(active_until, os.time() + 15)
        write(string.format("%s +%6dms  %s", clock(), d(ms(t0)), text))
    else
        ring[#ring + 1] = string.format("%s  (before)  %s", clock(), text)
        if #ring > RING_MAX then table.remove(ring, 1) end
    end
end

-- --------------------------------------------------------------------------
-- Hard cap: 3 days from the first run of this version. Checked BEFORE any
-- hooking - after expiry this file writes one line to the log and returns.
-- --------------------------------------------------------------------------

do
    -- v1.1.1 kept the stamp in G_reader_settings; the contract wants it in
    -- the log's first line or a state file. Clean up the old key if present.
    pcall(function()
        if G_reader_settings and G_reader_settings.delSetting then
            G_reader_settings:delSetting("readingloc_diag_first_run")
        end
    end)
    local function readStamp()
        local f = io.open(STATE, "r")
        if not f then return nil end
        local v = f:read("*l")
        local t = tonumber(f:read("*l"))
        f:close()
        if v == VERSION and t and t <= os.time() then return t end
        return nil
    end
    local first = readStamp()
    if not first then
        first = os.time()
        local f = io.open(STATE, "w")
        if f then f:write(VERSION, "\n", first, "\n") f:close() end
    end
    if os.time() - first > CAP_DAYS * 86400 then
        expired = true
        write(string.format("%s  diagnostics v%s: the %d-day limit has passed - doing nothing. Delete this file.",
            clock(), VERSION, CAP_DAYS), true)
        return
    end
    if os.time() - first > WATCH_DAYS * 86400 then
        expired = true
        write(string.format("%s  diagnostics v%s: the %d-day watch is up - hooks now idle (hard expiry at %d days). Delete this file when done.",
            clock(), VERSION, WATCH_DAYS, CAP_DAYS), true)
        return
    end
end

-- --------------------------------------------------------------------------
-- Reading the tracker's state (it lives on the ReaderUI as ui._rlt_*)
-- --------------------------------------------------------------------------

local function getUI() return ReaderUI.instance or current_ui end

local function snap(ui)
    local s = {}
    if type(ui) ~= "table" then return s end
    local ov = ui._rlt_overlay
    s.anchor = ui._rlt_anchor
    s.cur = ui._rlt_current_page
    s.rolling = ui._rlt_is_rolling
    s.has_xp = ui._rlt_anchor_xpointer ~= nil
    s.pending = ui._rlt_forward_dismiss_pending and true or false
    s.timer = ui._rlt_forward_dismiss_task ~= nil
    s.dirty = ui._rlt_anchor_dirty and true or false
    s.burst_start = ui._rlt_burst_start_page
    s.shown = (ov and ov.visible) and true or false
    s.side = ov and ov.side
    s.preview = (ov and ov.preview_both_sides) and true or false
    return s
end

local function popupName(s)
    if not s.shown then return "off" end
    if s.side == "bottom_left" then return "fwd(L)" end
    if s.side == "bottom_right" then return "back(R)" end
    return q(s.side)
end

local function fmtState(s)
    return string.format("anchor=%s cur=%s popup=%s timer=%s pending=%s unsaved=%s%s",
        q(s.anchor), q(s.cur), popupName(s), yn(s.timer), yn(s.pending), yn(s.dirty),
        s.preview and " (settings preview on)" or "")
end

local function setting(key)
    local v = G_reader_settings and G_reader_settings:readSetting(key)
    return v == nil and "default" or tostring(v)
end

local function buttonEnabled()
    return not (G_reader_settings and G_reader_settings:readSetting("readingloc_show_floating_button") == false)
end

local function forwardDismissOn()
    return not (G_reader_settings and G_reader_settings:readSetting("readingloc_forward_dismiss_seconds") == false)
end

local function settingsLine()
    return string.format("settings: button=%s full_text=%s page_no=%s dismiss_x=%s percent=%s shadow=%s"
        .. " auto_dismiss=%s burst_pages=%s burst_ms=%s offset(bottom/side)=%s/%s radius=%s",
        setting("readingloc_show_floating_button"), setting("readingloc_show_full_text"),
        setting("readingloc_show_page_number"), setting("readingloc_show_dismiss_button"),
        setting("readingloc_mode_percentage"), setting("readingloc_show_shadow"),
        setting("readingloc_forward_dismiss_seconds"), setting("readingloc_burst_pages"),
        setting("readingloc_burst_interval_ms"), setting("readingloc_offset_bottom"),
        setting("readingloc_offset_side"), setting("readingloc_button_radius"))
end

-- Screen set-up that changes where taps land or what the popup looks like.
local function envLine(ui)
    local parts = {}
    pcall(function()
        local Screen = Device.screen
        parts[#parts + 1] = "night_mode=" .. q(Screen.night_mode)
        parts[#parts + 1] = "rotation=" .. q(Screen:getRotationMode())
        parts[#parts + 1] = string.format("screen=%sx%s", q(Screen:getWidth()), q(Screen:getHeight()))
    end)
    pcall(function()
        parts[#parts + 1] = string.format("touch(mirror_x/mirror_y/switch_xy)=%s/%s/%s",
            q(Device.touch_mirrored_x), q(Device.touch_mirrored_y), q(Device.touch_switch_xy))
    end)
    pcall(function()
        parts[#parts + 1] = "mirrored_ui=" .. q(ok_bd and BD.mirroredUILayout())
        local view = ui and ui.view
        if view then
            parts[#parts + 1] = "inverse_reading_order=" .. q(view.inverse_reading_order)
            parts[#parts + 1] = "footer_visible=" .. q(view.footer_visible)
            parts[#parts + 1] = "reclaim_height=" .. q(view.footer and view.footer.reclaim_height)
        end
    end)
    return table.concat(parts, " ")
end

local function memKB() return collectgarbage("count") end
local mem_start, last_env

-- --------------------------------------------------------------------------
-- Opening a detailed window, and reporting problems
-- --------------------------------------------------------------------------

local function startSession(why, ui)
    if t0 then summary() end
    t0 = now()
    active_until = os.time() + SESSION_S
    counters.logged = 0
    paint = { pop_n = 0, pop_ms = 0, pop_max = 0, no_n = 0, no_ms = 0, no_max = 0 }
    write("")
    write(string.format("%s ==================== %s ====================", clock(), why))
    write("    " .. settingsLine())
    last_env = envLine(ui)
    write("    screen: " .. last_env)
    mem_start = memKB()
    write(string.format("    memory: %.0f KB in use (Lua heap)", mem_start))
    if type(ui) == "table" then
        local doc = ui.document
        local pc
        if doc then
            local ok, v = pcall(function() return doc:getPageCount() end)
            pc = ok and v or nil
        end
        local kind = ui._rlt_is_rolling == true and "reflowable"
            or (ui._rlt_is_rolling == false and "paginated" or "?")
        write(string.format("    book: %s | %s | %s pages", q(doc and doc.file), kind, q(pc)))
        write("    state: " .. fmtState(snap(ui)))
    end
    for _i, l in ipairs(ring) do write(l) end
    ring = {}
end

local function trigger(text, ui)
    if expired then return end
    if active() then event(text) else startSession(text, ui or getUI()) end
end

-- Each check is reported once when it starts failing, and "cleared" later.
local anoms = {}
local function check(key, bad, msg, why)
    if bad then
        if not anoms[key] then
            anoms[key] = true
            counters.anomalies = counters.anomalies + 1
            why[#why + 1] = "ANOMALY: " .. msg
        end
    elseif anoms[key] then
        anoms[key] = nil
        event("cleared: " .. key)
    end
end

local function flush(why, ui)
    for _i, w in ipairs(why) do trigger(w, ui) end
end

local function avg(n, total) return n > 0 and d(total / n) or 0 end

summary = function()
    write(string.format("%s +%6dms  window closed | page turns logged: %d | paints with popup: %d (avg %dms, max %dms)"
        .. " | without popup: %d (avg %dms, max %dms)",
        clock(), d(ms(t0)), counters.logged,
        paint.pop_n or 0, avg(paint.pop_n or 0, paint.pop_ms or 0), d(paint.pop_max),
        paint.no_n or 0, avg(paint.no_n or 0, paint.no_ms or 0), d(paint.no_max)))
    local grown = mem_start and (memKB() - mem_start) or 0
    write(string.format("    memory now %.0f KB (%+.0f KB over this window)%s | this patch's own cost so far: %d hooks,"
        .. " %.1fms total, worst %.2fms, %d log writes = %.1fms",
        memKB(), grown, grown > MEM_FLAG_KB and "   <-- ANOMALY: heap grew a lot (could be normal GC timing)" or "",
        ovh.n, ovh.us / 1000, ovh.max / 1000, ovh.wr_n, ovh.wr_us / 1000))
    if grown > MEM_FLAG_KB then counters.anomalies = counters.anomalies + 1 end
    t0 = nil
end

-- --------------------------------------------------------------------------
-- Catching the auto-dismiss timer FIRING without polling: when the tracker
-- schedules its dismiss task we schedule a wrapper instead, which logs the
-- moment it fires and then runs the original. Unschedule calls are
-- translated so cancelling the timer still removes the wrapper (otherwise a
-- cancelled timer would fire later and run code the tracker stood down).
-- --------------------------------------------------------------------------

local orig_schedule = UIManager.scheduleIn
local orig_unschedule = UIManager.unschedule

local dismiss_wrappers = {}   -- original action -> list of wrappers

local function wrapDismiss(orig_action)
    local list = dismiss_wrappers[orig_action]
    if not list then list = {}; dismiss_wrappers[orig_action] = list end
    local wrapper
    wrapper = function(...)
        local l = dismiss_wrappers[orig_action]
        if l then
            for i = #l, 1, -1 do
                if l[i] == wrapper then table.remove(l, i) break end
            end
            if #l == 0 then dismiss_wrappers[orig_action] = nil end
        end
        local r = pack(orig_action(...))
        if not expired then
            pcall(function()
                local u = getUI()
                local s = u and snap(u) or {}
                trigger("forward auto-dismiss FIRED"
                    .. (s.pending and " (anchor stays until the next page change)" or ""), u)
            end)
        end
        return unpack(r, 1, r.n)
    end
    list[#list + 1] = wrapper
    return wrapper
end

local function dropWrappers(self, orig_action)
    local list = dismiss_wrappers[orig_action]
    if not list then return end
    for _, w in ipairs(list) do
        pcall(function() orig_unschedule(self, w) end)
    end
    dismiss_wrappers[orig_action] = nil
end

-- --------------------------------------------------------------------------
-- Page turns (the same hook the tracker uses; we load after it, so we see
-- the state after it has run)
-- --------------------------------------------------------------------------

local last_turn_t, last_page_count, last_noxp

local function onTurn(ui, before, new_page_no, t, kind)
    if type(ui) ~= "table" or type(new_page_no) ~= "number" then return end
    if ui ~= current_ui then
        current_ui, last_page_count, last_noxp, last_turn_t, anoms = ui, nil, nil, nil, {}
    end
    counters.turns = counters.turns + 1
    local after = snap(ui)
    local took = ms(t)
    local dt = last_turn_t and ms(last_turn_t) or -1
    last_turn_t = now()
    local prev = before.cur
    local step = prev and (new_page_no - prev) or 0
    local why = {}

    -- Screen set-up is sampled at hooked events (no polling): night mode and
    -- rotation also have direct hooks below, this catches the rest (footer,
    -- touch inversion, reading order...).
    local env_now = envLine(ui)
    if last_env == nil then
        last_env = env_now
    elseif env_now ~= last_env then
        why[#why + 1] = "SCREEN SET-UP CHANGED: " .. env_now
        last_env = env_now
    end

    -- what happened
    if prev and math.abs(step) > 2 then why[#why + 1] = string.format("jump of %+d pages", step) end
    if before.shown ~= after.shown or (after.shown and before.side ~= after.side) then
        why[#why + 1] = "popup " .. popupName(before) .. " -> " .. popupName(after)
    end
    if before.timer ~= after.timer then
        why[#why + 1] = "auto-dismiss timer " .. (after.timer and "started" or "stopped")
    end
    if before.pending and not after.pending then why[#why + 1] = "pending promotion consumed" end
    if before.anchor ~= after.anchor then
        local silent = after.anchor == new_page_no and step >= 0 and step <= 2
        if not silent then
            local label = ""
            if before.anchor and after.anchor and after.anchor < before.anchor
               and after.anchor == after.burst_start then
                label = " (burst rollback)"
            end
            why[#why + 1] = string.format("anchor %s -> %s%s", q(before.anchor), q(after.anchor), label)
        end
    end
    if took > SLOW_TURN_MS then why[#why + 1] = string.format("slow page update (%dms)", d(took)) end

    -- what should be true now
    if not after.preview then
        local exp
        if buttonEnabled() and after.anchor and after.cur then
            if after.anchor - after.cur > 1 then
                exp = "bottom_right"
            elseif after.cur - after.anchor > 2 and not after.pending then
                exp = "bottom_left"
            end
        end
        check("popup_state", (after.shown ~= (exp ~= nil)) or (after.shown and after.side ~= exp),
            string.format("popup is %s but anchor=%s cur=%s pending=%s says it should be %s",
                popupName(after), q(after.anchor), q(after.cur), yn(after.pending),
                exp == "bottom_left" and "fwd(L)" or (exp == "bottom_right" and "back(R)" or "off")), why)
        local fwd = after.shown and after.side == "bottom_left"
        check("timer_missing", fwd and forwardDismissOn() and not after.timer,
            "forward popup is up but no auto-dismiss timer is scheduled"
            .. " (expected right after changing that setting while a popup is up)", why)
        check("timer_stray", after.timer and not fwd,
            "auto-dismiss timer is scheduled but no forward popup is showing", why)
        check("pending_with_timer", after.pending and after.timer,
            "promotion is pending and a timer is still scheduled", why)
        check("pending_with_popup", after.pending and fwd,
            "promotion is pending but the forward popup is showing", why)
    end
    check("current_page", after.cur ~= new_page_no,
        string.format("tracker thinks the current page is %s but KOReader reported %s"
            .. " (its hook may have errored - see TRACKER lines)", q(after.cur), q(new_page_no)), why)

    local doc = ui.document
    if doc then
        local ok, pc = pcall(function() return doc:getPageCount() end)
        if ok and type(pc) == "number" then
            if last_page_count and pc ~= last_page_count then
                why[#why + 1] = string.format("page count changed %d -> %d (re-layout / reflow)", last_page_count, pc)
            end
            last_page_count = pc
            check("anchor_range", after.anchor and (after.anchor < 1 or after.anchor > pc),
                string.format("anchor %s is outside 1..%d", q(after.anchor), pc), why)
        end
        if after.rolling then
            local xp = ui._rlt_anchor_xpointer
            if xp then
                local ok2, p = pcall(function() return doc:getPageFromXPointer(xp) end)
                check("xpointer_roundtrip", ok2 and type(p) == "number" and p ~= after.anchor,
                    string.format("anchor page is %s but its xpointer resolves to page %s", q(after.anchor), q(p)), why)
            elseif after.anchor and last_noxp ~= after.anchor then
                last_noxp = after.anchor
                event(string.format("note: no xpointer for anchor page %s (page-number fallback in use)", q(after.anchor)))
            end
        end
    end

    local line = string.format("%s -> p%s (%s)%s | anchor %s -> %s | popup %s | timer %s pending %s"
        .. " | burst_start=%s span=%s | %dms",
        prev and ("p" .. tostring(prev)) or "start", q(new_page_no), prev and string.format("%+d", step) or "first",
        dt >= 0 and string.format(" +%dms", d(dt)) or "",
        q(before.anchor), q(after.anchor), popupName(after), yn(after.timer), yn(after.pending),
        q(after.burst_start), after.burst_start and q(new_page_no - after.burst_start) or "(nil)", d(took))
    if #why > 0 then
        if not active() then
            local banner = why[1]
            for _i, w in ipairs(why) do
                if w:find("^ANOMALY") then banner = w break end
            end
            startSession(banner, ui)
        end
        event(line .. "   <-- " .. table.concat(why, "; "))
    else
        event(line)
    end
    if active() then counters.logged = counters.logged + 1 end
end

local function hookPageUpdate(module_name, kind)
    local ok, Module = pcall(require, module_name)
    if not ok or type(Module) ~= "table" or type(Module.onPageUpdate) ~= "function" then
        write(string.format("%s  note: could not hook %s", clock(), module_name))
        return
    end
    local orig = Module.onPageUpdate
    Module.onPageUpdate = function(self, new_page_no, ...)
        if expired then return orig(self, new_page_no, ...) end
        local ui = type(self) == "table" and self.ui or nil
        local before = {}
        local ot = now()
        pcall(function() before = snap(ui) end)
        local own = us(ot)
        local t = now()
        local r = pack(orig(self, new_page_no, ...))
        ot = now()
        pcall(onTurn, ui, before, new_page_no, t, kind)
        local u = own + us(ot)
        ovh.n, ovh.us = ovh.n + 1, ovh.us + u
        if u > ovh.max then ovh.max = u end
        return unpack(r, 1, r.n)
    end
end

hookPageUpdate("apps/reader/modules/readerpaging", "paging")
hookPageUpdate("apps/reader/modules/readerrolling", "rolling")

-- --------------------------------------------------------------------------
-- The tracker's other entry points
-- --------------------------------------------------------------------------

local function hookUI(name, h)
    local orig = ReaderUI[name]
    if type(orig) ~= "function" then
        write(string.format("%s  note: ReaderUI.%s not found (not hooked)", clock(), name))
        return
    end
    ReaderUI[name] = function(self, ...)
        if expired then return orig(self, ...) end
        local ctx
        if h.before then pcall(function() ctx = h.before(self) end) end
        local r = pack(orig(self, ...))
        if h.after then pcall(function() h.after(self, ctx) end) end
        return unpack(r, 1, r.n)
    end
end

-- Compares what's saved on disk with what's live. Returns a short summary.
local function persistedCheck(ui, why, when)
    local ds = ui.doc_settings
    if not ds then return "no doc_settings" end
    local saved, live = ds:readSetting("readingloc_anchor"), ui._rlt_anchor
    check("persist_page_" .. when, live ~= nil and saved ~= live,
        string.format("after %s the saved anchor is %s but the live anchor is %s", when, q(saved), q(live)), why)
    local info = string.format("saved anchor=%s", q(saved))
    if ui._rlt_is_rolling then
        local sx, lx = ds:readSetting("readingloc_anchor_xpointer"), ui._rlt_anchor_xpointer
        check("persist_xp_" .. when, tostring(sx) ~= tostring(lx),
            string.format("after %s the saved xpointer is %s but the live one is %s",
                when, short(sx), short(lx)), why)
        info = info .. string.format(" xpointer=%s", sx and "present" or "(nil)")
    end
    return info
end

hookUI("onGoToFurthestReadingLocation", {
    before = function(ui)
        trigger("gesture: go to furthest reading location", ui)
        event("before: " .. fmtState(snap(ui)))
    end,
    after = function(ui) event("after:  " .. fmtState(snap(ui))) end,
})

hookUI("onSetCurrentPageAsReadingLocation", {
    before = function(ui)
        trigger("gesture: set current page as reading location", ui)
        event("before: " .. fmtState(snap(ui)))
    end,
    after = function(ui) event("after:  " .. fmtState(snap(ui))) end,
})

-- Menu injection check. The tracker adds its "Reading Location" rows via
-- ReaderLink.addToMainMenu plus a reader_menu_order.navi position injection;
-- the Dispatcher handlers hooked above exist regardless, so a silently
-- failed menu hook (readermenu.lua wraps every addToMainMenu call in pcall)
-- would otherwise produce zero anomalies. We wrap after the tracker, so by
-- the time our check runs its injection has run too.
do
    local ok_rl, ReaderLink = pcall(require, "apps/reader/modules/readerlink")
    local orig = ok_rl and ReaderLink and ReaderLink.addToMainMenu
    if type(orig) ~= "function" then
        write(string.format("%s  note: ReaderLink.addToMainMenu not found (menu check not hooked)", clock()))
    else
        ReaderLink.addToMainMenu = function(self, menu_items, ...)
            local r = pack(orig(self, menu_items, ...))
            if not expired then
                pcall(function()
                    local ui = (type(self) == "table" and self.ui) or getUI()
                    local why = {}
                    local entry = (type(menu_items) == "table"
                        and menu_items.go_to_furthest_reading_location) or nil
                    check("menu_entry", type(entry) ~= "table",
                        "addToMainMenu ran but menu_items.go_to_furthest_reading_location is missing"
                        .. " - the tracker's menu hook didn't inject its rows", why)
                    if type(entry) == "table" then
                        local sub = entry.sub_item_table
                        local n = type(sub) == "table" and #sub or 0
                        check("menu_rows", n ~= 3,
                            string.format("the Reading Location group has %d rows, expected 3", n), why)
                    end
                    local ok_o, order = pcall(require, "ui/elements/reader_menu_order")
                    local in_navi = false
                    if ok_o and order and type(order.navi) == "table" then
                        for _, k in ipairs(order.navi) do
                            if k == "go_to_furthest_reading_location" then in_navi = true break end
                        end
                    end
                    check("menu_navi", not in_navi,
                        "go_to_furthest_reading_location is missing from reader_menu_order.navi"
                        .. " - the tracker's position injection didn't run", why)
                    if #why > 0 then
                        trigger("menu injection check", ui)
                        flush(why, ui)
                    end
                end)
            end
            return unpack(r, 1, r.n)
        end
    end
end

local timer_set_at, timer_secs   -- when the auto-dismiss timer was last scheduled, and for how long
local slept = {}   -- what things looked like when the device went to sleep

hookUI("onSuspend", {
    before = function(ui)
        local s = snap(ui)
        slept = { snap = s, real = os.time(), mono = now(), timer_left = nil }
        if s.timer and timer_set_at and timer_secs then
            slept.timer_left = timer_secs - ms(timer_set_at) / 1000
        end
        return s
    end,
    after = function(ui, s)
        local a, why = snap(ui), {}
        check("suspend_unsaved", s and s.dirty and a.dirty,
            "the anchor was unsaved before suspend and still is after", why)
        local info = persistedCheck(ui, why, "suspend")
        -- through the window system, not straight to disk: this opens a
        -- window (or joins the lead-up ring) like any other event.
        trigger(string.format("device suspend | unsaved before: %s, after: %s | %s | %s%s",
            yn(s and s.dirty), yn(a.dirty), info, fmtState(a),
            slept.timer_left and string.format(" | auto-dismiss timer had ~%.0fs awake-time left", slept.timer_left) or ""), ui)
        flush(why, ui)
    end,
})

-- Wake-up. (ReaderView has the onResume handler; the scheduler clock does not
-- tick while asleep, so the timer should pick up where it left off.)
do
    local orig = ReaderView.onResume
    ReaderView.onResume = function(self, ...)
        local r = pack(type(orig) == "function" and orig(self, ...) or nil)
        if expired or not slept.real then return unpack(r, 1, r.n) end
        pcall(function()
            local ui = self.ui or getUI()
            local real = os.time() - slept.real
            local awake = ms(slept.mono) / 1000
            local asleep = math.max(0, real - awake)
            local a, b = snap(ui), slept.snap or {}
            local text = string.format("device resumed | wall clock %ds, of which asleep ~%ds | %s%s",
                real, d(asleep), fmtState(a),
                slept.timer_left and string.format(" | timer had ~%.0fs left when it slept", slept.timer_left) or "")
            if b.shown or b.timer or a.shown or a.timer then trigger(text, ui) else event(text) end
            event("screen: " .. envLine(ui))
            local why = {}
            check("resume_popup", b.shown ~= nil and (a.shown ~= b.shown or a.side ~= b.side),
                string.format("popup changed across sleep: %s -> %s", popupName(b), popupName(a)), why)
            check("resume_anchor", b.anchor ~= nil and a.anchor ~= b.anchor,
                string.format("anchor changed across sleep: %s -> %s", q(b.anchor), q(a.anchor)), why)
            check("resume_timer", b.timer ~= nil and a.timer ~= b.timer,
                string.format("auto-dismiss timer changed across sleep: %s -> %s", yn(b.timer), yn(a.timer)), why)
            flush(why, ui)
            slept = {}
        end)
        return unpack(r, 1, r.n)
    end
end

-- Night mode and rotation: log the moment they change, with the new set-up.
for _i, spec in ipairs({ { "toggleNightMode", "night mode toggled" },
                         { "setRotationMode", "screen rotation changed" } }) do
    local Screen = Device.screen
    local orig = Screen and Screen[spec[1]]
    if type(orig) == "function" then
        Screen[spec[1]] = function(self, ...)
            local r = pack(orig(self, ...))
            if not expired then
                pcall(function()
                    local ui = getUI()
                    last_env = envLine(ui)
                    trigger(spec[2] .. " | " .. last_env, ui)
                end)
            end
            return unpack(r, 1, r.n)
        end
    end
end

hookUI("saveSettings", {
    after = function(ui)
        local why = {}
        event("saveSettings: " .. persistedCheck(ui, why, "periodic save"))
        flush(why, ui)
    end,
})

hookUI("onCloseDocument", {
    after = function(ui)
        local a, why = snap(ui), {}
        check("close_timer", a.timer, "auto-dismiss timer is still scheduled after the book closed", why)
        flush(why, ui)
        write(string.format("%s  book closed | page turns since startup: %d | anomalies since startup: %d | %s",
            clock(), counters.turns, counters.anomalies, fmtState(a)))
        current_ui, last_page_count, last_noxp, last_turn_t, anoms = nil, nil, nil, nil, {}
    end,
})

-- --------------------------------------------------------------------------
-- Auto-stop: WATCH_DAYS of wall-clock time from the first run (checked at
-- load, before any hooking), a per-start backstop of EXPIRE_MIN awake
-- minutes (the scheduler clock doesn't tick while asleep), and a hard stop
-- CAP_DAYS after the first run of this version. Expired = every hook above
-- just calls through, nothing is written.
-- --------------------------------------------------------------------------

local function notice(text)
    pcall(function() require("ui/widget/notification"):notify(text) end)
end

local expire_task
local function expire(reason)
    if expired then return end
    if t0 then summary() end
    write(string.format("%s  diagnostics EXPIRED: %s | page turns seen: %d | anomalies: %d | memory %.0f KB"
        .. " | own cost in total: %d hooks, %.1fms, worst %.2fms, %d log writes = %.1fms"
        .. " | now doing nothing - safe to delete this file", clock(), reason, counters.turns,
        counters.anomalies, memKB(), ovh.n, ovh.us / 1000, ovh.max / 1000, ovh.wr_n, ovh.wr_us / 1000), true)
    expired = true
    notice("Reading-location diagnostics finished - safe to delete the diagnostics patch")
end

expire_task = function()
    expire(string.format("%d days of use are up", EXPIRE_MIN / 1440))
end

local function arm()
    orig_unschedule(UIManager, expire_task)
    orig_schedule(UIManager, EXPIRE_MIN * 60, expire_task)
end

rearm = function()
    expired = false
    arm()
    write(string.format("%s  diagnostics re-armed for another %d days (mark gesture)", clock(), EXPIRE_MIN / 1440), true)
end

-- --------------------------------------------------------------------------
-- Optional gesture: mark a moment you want a closer look at
-- --------------------------------------------------------------------------

local ok_d, Dispatcher = pcall(require, "dispatcher")
if ok_d and type(Dispatcher) == "table" then
    Dispatcher:registerAction("track_reading_location_diag_mark", {
        category = "none",
        event = "TrackReadingLocationDiagMark",
        title = "Reading location diagnostics: mark this moment",
        reader = true,
    })
    ReaderUI.onTrackReadingLocationDiagMark = function(self)
        pcall(function()
            if expired then rearm() end
            trigger("MARK - you flagged this moment", self)
            event("state: " .. fmtState(snap(self)))
            require("ui/widget/notification"):notify("Reading-location diagnostics: moment marked")
        end)
        return true
    end
end

-- --------------------------------------------------------------------------
-- Around the tracker: its warnings, its timer, its notifications, taps on the
-- popup, and paint timing
-- --------------------------------------------------------------------------

-- Errors the tracker catches itself end up here instead of nowhere.
local function hookLogger(level)
    local orig = logger[level]
    if type(orig) ~= "function" then return end
    logger[level] = function(...)
        local first = ...
        if not expired and type(first) == "string" and first:find("ReadingLocationTracker", 1, true) then
            local args = pack(...)
            pcall(function()
                local parts = {}
                for i = 1, args.n do parts[#parts + 1] = tostring(args[i]) end
                counters.anomalies = counters.anomalies + 1
                trigger("TRACKER " .. level:upper() .. ": " .. table.concat(parts, " "), getUI())
            end)
        end
        return orig(...)
    end
end
hookLogger("warn")
hookLogger("err")

-- The auto-dismiss timer: when it's scheduled (and for how long) and cancelled.
-- The scheduled action is wrapped so the moment it FIRES is logged too - no
-- polling needed. Unschedule calls are translated to drop the wrapper, so a
-- cancelled timer can never fire late and run code the tracker stood down.
UIManager.scheduleIn = function(self, seconds, action, ...)
    local wrapped = nil
    if action ~= nil and not expired then
        pcall(function()
            local ui = getUI()
            if ui and ui._rlt_forward_dismiss_task == action then
                timer_set_at, timer_secs = now(), tonumber(seconds)
                wrapped = wrapDismiss(action)
                event(string.format("auto-dismiss timer scheduled: %ss", q(seconds)))
            end
        end)
    end
    if wrapped then
        return orig_schedule(self, seconds, wrapped, ...)
    end
    return orig_schedule(self, seconds, action, ...)
end

UIManager.unschedule = function(self, action, ...)
    if not expired then
        pcall(function()
            local ui = getUI()
            if action ~= nil and ui and ui._rlt_forward_dismiss_task == action then
                event("auto-dismiss timer cancelled")
            end
        end)
    end
    local r = pack(orig_unschedule(self, action, ...))
    -- Translation runs even when expired: a wrapper left scheduled while the
    -- tracker thinks the timer is cancelled would change behaviour.
    pcall(function()
        if action == nil then
            for orig in pairs(dismiss_wrappers) do dropWrappers(self, orig) end
        else
            dropWrappers(self, action)
        end
    end)
    return unpack(r, 1, r.n)
end

-- The tracker's own notifications ("Current page set...", "already at...").
local orig_show = UIManager.show
UIManager.show = function(self, w, ...)
    if not expired and type(w) == "table" and type(w.text) == "string" and w.text:lower():find("reading location", 1, true) then
        pcall(function()
            if active() then event("notification: " .. w.text) else startSession("notification: " .. w.text, getUI()) end
        end)
    end
    return orig_show(self, w, ...)
end

-- Touch zones that come before ours in the dispatch order and also match this
-- gesture. KOReader hands a tap to the first zone whose handler returns true,
-- so any zone listed here is a candidate for having taken the tap.
local function zonesAhead(ui, g)
    local names = {}
    for _i, z in ipairs(ui._ordered_touch_zones or {}) do
        local id = z.def and z.def.id
        if type(id) == "string" and id:find("^readingloc_") then break end
        if z.gs_range and not z.gs_range.rate and z.gs_range:match(g) then names[#names + 1] = q(id) end
    end
    return #names > 0 and table.concat(names, ", ") or "none"
end

-- Taps and holds while the popup is up: did it land inside the button?
local function onTap(g)
    local ui = getUI()
    local ov = ui and ui._rlt_overlay
    if not (ov and ov.visible) then return end
    local b, p = ov.box_dimen, g.pos
    local inside = type(b) == "table" and type(p) == "table" and p.x and p.y and b.x and b.y and b.w and b.h
        and p.x >= b.x and p.x <= b.x + b.w and p.y >= b.y and p.y <= b.y + b.h
    local box = type(b) == "table" and string.format("%s,%s %sx%s", q(b.x), q(b.y), q(b.w), q(b.h)) or "(not drawn yet)"
    local near = false
    if not inside and type(b) == "table" and type(p) == "table" and p.x and p.y and b.x and b.y and b.w and b.h then
        near = p.x >= b.x - 60 and p.x <= b.x + b.w + 60 and p.y >= b.y - 60 and p.y <= b.y + b.h + 60
    end
    if inside and not active() then startSession("popup " .. g.ges, ui) end
    local ahead = ""
    if inside or near then
        local ok, z = pcall(zonesAhead, ui, g)
        ahead = " | zones ahead of ours that match: " .. (ok and z or ("(lookup failed: " .. tostring(z) .. ")"))
    end
    event(string.format("%s at %s,%s (screen %sx%s) | popup box %s | %s%s%s", g.ges, q(p and p.x), q(p and p.y),
        q(Device.screen:getWidth()), q(Device.screen:getHeight()), box,
        inside and "INSIDE the popup" or (near and "just OUTSIDE the popup (within 60px)" or "outside the popup"),
        ov.preview_both_sides and " (settings preview)" or "", ahead))
    -- A tap on the button always does something (go back, or accept the page).
    -- If nothing changed shortly after, another touch zone probably took it.
    -- (Holds are skipped: with the X showing, a hold does nothing by design.)
    if inside and g.ges == "tap" and not ov.preview_both_sides then
        local was = snap(ui)
        orig_schedule(UIManager, 0.8, function()
            pcall(function()
                local u = getUI()
                if not u then return end
                local a = snap(u)
                if a.shown == was.shown and a.side == was.side and a.anchor == was.anchor and a.cur == was.cur then
                    counters.anomalies = counters.anomalies + 1
                    event("ANOMALY: a tap inside the popup changed nothing after 0.8s"
                        .. " - another touch zone may have taken it (see 'zones ahead' on the tap line above)")
                end
            end)
        end)
    end
end

local orig_send = UIManager.sendEvent
UIManager.sendEvent = function(self, ev, ...)
    if not expired and type(ev) == "table" and ev.handler == "onGesture" then
        local g = ev.args and ev.args[1]
        if type(g) == "table" and (g.ges == "tap" or g.ges == "hold") then
            local ot = now()
            pcall(onTap, g)
            spent(ot)
        end
    end
    return orig_send(self, ev, ...)
end

-- Paint timing, only while a window is open: with the popup vs without it.
local orig_paint = ReaderView.paintTo
ReaderView.paintTo = function(self, ...)
    if not active() then return orig_paint(self, ...) end
    local t = now()
    local r = pack(orig_paint(self, ...))
    pcall(function()
        local took = ms(t)
        local ov = self.ui and self.ui._rlt_overlay
        local k = (ov and ov.visible) and "pop" or "no"
        paint[k .. "_n"] = (paint[k .. "_n"] or 0) + 1
        paint[k .. "_ms"] = (paint[k .. "_ms"] or 0) + took
        paint[k .. "_max"] = math.max(paint[k .. "_max"] or 0, took)
    end)
    return unpack(r, 1, r.n)
end

-- --------------------------------------------------------------------------
-- Startup line, and one notice so you know it's on
-- --------------------------------------------------------------------------

write("==================== track-reading-location diagnostics " .. VERSION .. " started ====================")
write("    " .. settingsLine())
write(string.format("    Track Reading Location detected: %s | watches %d days, hard expiry %d days",
    yn(type(ReaderUI.onGoToFurthestReadingLocation) == "function"), WATCH_DAYS, CAP_DAYS))
arm()
UIManager:nextTick(function()
    notice(string.format("Diagnostics watching for %d days: writing koreader/diagnostics.log", WATCH_DAYS))
end)
