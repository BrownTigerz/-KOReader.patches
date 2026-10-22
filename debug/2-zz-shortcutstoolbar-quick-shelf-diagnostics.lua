--[[
2-zz-shortcutstoolbar-quick-shelf-diagnostics.lua - TEMPORARY troubleshooting patch
Version 1.1.1

Changelog:
  1.1.1 - One line per entry: messages and popups with line breaks are
          joined with " / " (they used to split into untagged lines), and
          the invisible text-direction marks around file paths are
          removed.
  1.1.0 - Renamed with the patch (Quick Shelf, was Recent Books): new file
          name, [shortcutstoolbar-quick-shelf] tag and state file. Delete
          2-zz-shortcutstoolbar-recent-books-diagnostics.lua.
  1.0.2 - Cover time no longer counted twice when SimpleUI's cover lookup
          itself reads CoverBrowser's cache (it showed more cover time
          than the whole strip took).
  1.0.1 - Logs the refresh type each page change asks for (flashui =
          ghost-free). Swipes that change nothing are no longer expected.
  1.0.0 - First version.

Watches 2-shortcutstoolbar-quick-shelf.lua from the outside and writes
tagged lines ([shortcutstoolbar-quick-shelf]) to the shared diagnostics log
(shared log contract v1):
    koreader/diagnostics.log
(Kobo: .adds/koreader/diagnostics.log)

It changes nothing in the patch or the toolbar. It records:
  • Hook status: whether the patch found the plugin's book panel.
  • Every reader toolbar build: the plugin's book panel time vs the time the
    patch adds on top (should be ~0: the strip isn't built until a swipe).
  • Every swipe: direction, page change, and for the first swipe of a menu
    open, where the strip's build time goes:
      - the book list: reading-status lookups (and how many had to read a
        book's sidecar file), the To Be Read list
      - covers: SimpleUI's covers, CoverBrowser's cache, scaling, and how
        many books had no saved thumbnail (title tile instead)
      - text layout
    plus the memory it allocated.
  • The redraw each swipe asks for (refresh type, area) and how long the
    toolbar row took to paint afterwards.
  • Taps on a book (switch requested).
  • Anything the patch has pending when the device goes to sleep (should be
    nothing), and the patch's own warnings.
  • A summary with hints: what the log suggests could be made faster.

Battery safety (in case you forget to delete it):
  • Logs for 15 minutes, starting the first time a reader toolbar is built
    after KOReader starts. Then it writes a summary and goes quiet until the
    next restart. One window per restart.
  • Stops for good 24 hours after it first runs: after that it loads, sees
    it's expired and does nothing else. The start time is kept in its own
    state file (shortcutstoolbar-quick-shelf-diagnostics.state), so nothing
    is saved in KOReader's settings. Delete the state file for a fresh 24h.
  • No background polling and no timers of its own: the window closes on
    elapsed time, checked at every hooked call. Lines go to the shared
    diagnostics.log (2 MB rotation, older part kept as diagnostics.log.old).

How to use:
  1. Put this file in koreader/patches/ next to the Quick Shelf patch and
     restart KOReader.
  2. Open a book. Within 15 minutes: open the reader menu, swipe left and
     right on the book row a few times, close and reopen the menu and swipe
     again, switch Quick Shelf Shows to the other list and swipe, tap a book.
  3. Send diagnostics.log (the [shortcutstoolbar-quick-shelf] lines).
  4. Delete this file and restart.
The "zz" makes it load after the Quick Shelf patch.
]]

local DataStorage = require("datastorage")
local Device = require("device")
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local userpatch = require("userpatch")
local ok_time, ktime = pcall(require, "ui/time")

local DIAG_VERSION = "1.1.1"
local DIAG_TAG = "shortcutstoolbar-quick-shelf"   -- = the filename stem (Debugging Menu)
local DATA = DataStorage:getDataDir()
local STATE = DATA .. "/" .. DIAG_TAG .. "-diagnostics.state"
local MAIN_FILE = DATA .. "/patches/2-shortcutstoolbar-quick-shelf.lua"
local MAIN_TAG = "shortcutstoolbar-quick-shelf.lua"   -- in the patch's source path
local WINDOW_S = 15 * 60
local EXPIRE_S = 24 * 60 * 60

-- --------------------------------------------------------------------------
-- Shared log contract v1
-- --------------------------------------------------------------------------

local SHARED_LOG = DATA .. "/diagnostics.log"
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

-- --------------------------------------------------------------------------
-- Shared notification contract v1
-- --------------------------------------------------------------------------

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

-- --------------------------------------------------------------------------
-- Expiry (state file) and the logging window (no timers)
-- --------------------------------------------------------------------------

local function readStamp()
    local f = io.open(STATE, "r")
    if not f then return nil end
    local line = f:read("*l")
    f:close()
    return tonumber((line or ""):match("started (%d+)"))
end

local started = readStamp()
if not started then
    started = os.time()
    local f = io.open(STATE, "w")
    if f then f:write("started " .. started .. "\n") f:close() end
    shared_log("==================== quick shelf diagnostics %s first run ====================  [# started %d]",
        DIAG_VERSION, started)
end
if os.difftime(os.time(), started) > EXPIRE_S then
    shared_log("expired (first ran more than 24h ago): doing nothing. Delete this patch.")
    logger.info("shortcutstoolbar quick shelf diagnostics: expired, inactive")
    return
end

local function now() return ok_time and ktime.now() or nil end
local function us(since)
    if not (ok_time and since) then return 0 end
    local ok, v = pcall(function() return ktime.to_us(ktime.since(since)) end)
    return ok and v or 0
end
local function f1(u) return string.format("%.1f", (u or 0) / 1000) end
local function q(v) return v == nil and "(nil)" or tostring(v) end

local window_start, window_start_s
local window_open, window_done = false, false
local closeWindow

local function elapsedS()
    if window_start_s then return os.time() - window_start_s end
    return 0
end

local function log(fmt, ...)
    local ok, line = pcall(string.format, fmt, ...)
    if not ok then line = tostring(fmt) end
    local off = window_start and math.floor(us(window_start) / 1000) or 0
    shared_log("%s", string.format("+%7dms  ", off) .. line)
end

local function active()
    if window_open and elapsedS() >= WINDOW_S then closeWindow() end
    return window_open
end

-- --------------------------------------------------------------------------
-- Counters
-- --------------------------------------------------------------------------

local stats = {
    builds = 0, build_plugin = 0, build_patch = 0,
    swipes = 0, strips = 0, strip_us = 0, strip_max = 0,
    info_calls = 0, info_uncached = 0, info_us = 0,
    covers_sh = 0, covers_bim = 0, covers_tile = 0, cover_us = 0, cover_max = 0,
    paints = 0, paint_us = 0, paint_max = 0,
    taps = 0, warnings = 0, asleep_actions = 0,
}

-- Per-swipe record while a strip is being built.
local cur

local function mem() return collectgarbage("count") end

local function fromMain(level)
    local info = debug.getinfo(level + 1, "S")
    return info and info.source and info.source:find(MAIN_TAG, 1, true) ~= nil
end

local function pendingMainTasks()
    local n = 0
    for _i, t in ipairs(UIManager._task_queue or {}) do
        local info = type(t.action) == "function" and debug.getinfo(t.action, "S")
        if info and info.source and info.source:find(MAIN_TAG, 1, true) then n = n + 1 end
    end
    return n
end

local function avg(total, n) return n > 0 and f1(total / n) or "0.0" end

local function summary(why)
    log("---- summary (%s) ----", why)
    log("reader toolbar builds: %d | plugin book panel avg %s ms | added by patch avg %s ms",
        stats.builds, avg(stats.build_plugin, stats.builds), avg(stats.build_patch, stats.builds))
    log("swipes: %d | strips built: %d, avg %s ms, slowest %s ms",
        stats.swipes, stats.strips, avg(stats.strip_us, stats.strips), f1(stats.strip_max))
    log("reading-status lookups: %d (%d read a sidecar file), total %s ms",
        stats.info_calls, stats.info_uncached, f1(stats.info_us))
    log("covers: SimpleUI %d, CoverBrowser %d, title tile (no thumbnail) %d | avg %s ms, slowest %s ms",
        stats.covers_sh, stats.covers_bim, stats.covers_tile,
        avg(stats.cover_us, stats.covers_sh + stats.covers_bim + stats.covers_tile), f1(stats.cover_max))
    log("toolbar row paints after a swipe: %d, avg %s ms, slowest %s ms",
        stats.paints, avg(stats.paint_us, stats.paints), f1(stats.paint_max))
    log("book taps: %d | patch warnings: %d | actions while asleep: %d | pending at last sleep: see SLEEP line",
        stats.taps, stats.warnings, stats.asleep_actions)
    log("Lua memory: %d KB", math.floor(mem()))

    -- Hints: what the numbers suggest could be improved.
    local hints = {}
    if stats.builds > 0 and stats.build_patch / stats.builds > 3000 then
        hints[#hints + 1] = "the patch adds >3 ms to every menu open: something runs before any swipe"
    end
    if stats.strips > 0 and stats.strip_us / stats.strips > 250000 then
        hints[#hints + 1] = string.format("strip build is slow (avg %s ms)", avg(stats.strip_us, stats.strips))
    end
    if stats.info_uncached > 0 and stats.info_us > 0.4 * stats.strip_us then
        hints[#hints + 1] = "reading-status lookups are most of the strip time (sidecar reads): caching the list until history changes would help"
    end
    if stats.cover_us > 0.4 * stats.strip_us and stats.strips > 0 then
        hints[#hints + 1] = "covers are most of the strip time: keeping the cover images across menu opens would help"
    end
    if stats.covers_tile > 0 then
        hints[#hints + 1] = string.format("%d book(s) had no saved thumbnail: browsing them once in a cover view (SimpleUI / CoverBrowser) saves one", stats.covers_tile)
    end
    if stats.strips > 1 and stats.strips >= stats.builds and stats.builds > 1 then
        hints[#hints + 1] = "the strip was rebuilt on every menu open: keeping it while the history is unchanged would skip that"
    end
    if stats.paints > 0 and stats.paint_us / stats.paints > 80000 then
        hints[#hints + 1] = "repaint after a swipe is slow: smaller covers or fewer books would help"
    end
    if stats.asleep_actions > 0 or stats.warnings > 0 then
        hints[#hints + 1] = "CHECK the flagged lines above"
    end
    if #hints == 0 then hints[1] = "nothing to improve: all within budget" end
    for i, h in ipairs(hints) do log("hint %d: %s", i, h) end
end

closeWindow = function()
    if not window_open then return end
    window_open = false -- before summary: summary's log() mustn't re-enter
    summary("15 minutes up")
    log("logging stopped until next restart (delete this patch when done)")
    window_done = true
    if not shared_note("Diagnostics: done, log written") then
        pcall(function() require("ui/widget/notification"):notify("Diagnostics: done, log written") end)
    end
end

local function openWindow()
    if window_open or window_done then return end
    window_open = true
    window_start = now()
    window_start_s = os.time()
    log("==================== quick shelf diagnostics %s: 15-minute window ====================", DIAG_VERSION)
    local f = io.open(MAIN_FILE, "r")
    if f then
        local head = f:read(400) or ""
        f:close()
        log("Quick Shelf patch %s", q(head:match("Version:%s*([%d%.]+)")))
    else
        log("Quick Shelf patch not found at %s (renamed?)", MAIN_FILE)
    end
    local s = G_reader_settings:readSetting("shortcutstoolbar_quick_shelf")
        or G_reader_settings:readSetting("shortcutstoolbar_recent_books")
    log("quick shelf shows: %s | SimpleUI covers: %s | CoverBrowser cache: %s | Lua memory: %d KB",
        (type(s) == "table" and s.source == "tbr") and "To Be Read" or "Books In Progress",
        package.loaded["modules/module_books_shared"] and "yes" or "no",
        package.loaded["bookinfomanager"] and "yes" or "no",
        math.floor(mem()))
end

-- --------------------------------------------------------------------------
-- Timing wrappers for what the strip build calls (only while one runs)
-- --------------------------------------------------------------------------

local function wrapField(tbl, name, on_call)
    if type(tbl) ~= "table" or type(tbl[name]) ~= "function" then return end
    if rawget(tbl, "__stbrd_" .. name) then return end
    local orig = tbl[name]
    rawset(tbl, "__stbrd_" .. name, true)
    tbl[name] = function(...)
        if not cur then return orig(...) end
        return on_call(orig, ...)
    end
end

local function timedCall(orig, ...)
    local t = now()
    local res = { pcall(orig, ...) }
    local took = us(t)
    if not res[1] then error(res[2], 0) end
    return took, unpack(res, 2)
end

local function hookStripPieces()
    local ok_bl, BookList = pcall(require, "ui/widget/booklist")
    if ok_bl then
        wrapField(BookList, "getBookInfo", function(orig, fp, ...)
            local cached = type(BookList.hasBookInfoCache) == "function" and BookList.hasBookInfoCache(fp)
            local took, info = timedCall(orig, fp, ...)
            cur.info_calls = cur.info_calls + 1
            cur.info_us = cur.info_us + took
            if not cached then cur.info_uncached = cur.info_uncached + 1 end
            return info
        end)
    end
    local ok_tbr, TBR = pcall(require, "modules/module_tbr")
    if ok_tbr then
        wrapField(TBR, "getTBRList", function(orig, ...)
            local took, list = timedCall(orig, ...)
            cur.tbr_us = (cur.tbr_us or 0) + took
            return list
        end)
    end
    local SH = package.loaded["modules/module_books_shared"]
    wrapField(SH, "getBookCover", function(orig, fp, ...)
        cur.in_cover = true
        local took, wd = timedCall(orig, fp, ...)
        cur.in_cover = nil
        cur.cover_us = cur.cover_us + took
        cur.cover_max = math.max(cur.cover_max, took)
        cur.pending_cover = wd and "sh" or nil
        return wd
    end)
    wrapField(SH, "getBookData", function(orig, ...)
        local took, bd = timedCall(orig, ...)
        cur.data_us = (cur.data_us or 0) + took
        return bd
    end)
    local BIM = package.loaded["bookinfomanager"]
    wrapField(BIM, "getBookInfo", function(orig, self, fp, get_cover, ...)
        -- Called from inside SimpleUI's cover lookup: already timed there.
        if cur.in_cover then return orig(self, fp, get_cover, ...) end
        local took, bi = timedCall(orig, self, fp, get_cover, ...)
        cur.cover_us = cur.cover_us + took
        cur.cover_max = math.max(cur.cover_max, took)
        if type(bi) == "table" and bi.cover_bb then cur.pending_cover = "bim" end
        return bi
    end)
    local ok_ri, RI = pcall(require, "ui/renderimage")
    if ok_ri then
        wrapField(RI, "scaleBlitBuffer", function(orig, ...)
            local took, bb = timedCall(orig, ...)
            cur.scale_us = (cur.scale_us or 0) + took
            return bb
        end)
    end
    local ok_tb, TextBoxWidget = pcall(require, "ui/widget/textboxwidget")
    if ok_tb then
        wrapField(TextBoxWidget, "init", function(orig, ...)
            local took = timedCall(orig, ...)
            cur.text_us = (cur.text_us or 0) + took
        end)
    end
end

-- --------------------------------------------------------------------------
-- The pager instance: swipes, paints, taps
-- --------------------------------------------------------------------------

local function newRecord()
    return { info_calls = 0, info_uncached = 0, info_us = 0, cover_us = 0, cover_max = 0,
             covers_sh = 0, covers_bim = 0, covers_tile = 0 }
end

local paint_after_swipe = false

local function watchPager(pager)
    if type(pager) ~= "table" or rawget(pager, "__stbrd_watched") then return end
    rawset(pager, "__stbrd_watched", true)

    local orig_swipe = pager.onSwipePager
    if type(orig_swipe) == "function" then
        pager.onSwipePager = function(self, arg, ges)
            if not active() then return orig_swipe(self, arg, ges) end
            if Device.screen_saver_mode then stats.asleep_actions = stats.asleep_actions + 1 end
            local from = self.page
            local building = (ges and (ges.direction == "west" or ges.direction == "east"))
                and not (self.pages and self.pages[2])
            local m0 = mem()
            if building then hookStripPieces(); cur = newRecord() end
            local t = now()
            local ok, res = pcall(orig_swipe, self, arg, ges)
            local took = us(t)
            local rec = cur
            cur = nil
            if not ok then
                log("SWIPE ERROR: %s", q(res))
                error(res, 0)
            end
            stats.swipes = stats.swipes + 1
            local dir = ges and ges.direction or "?"
            if building and self.pages and self.pages[2] then
                stats.strips = stats.strips + 1
                stats.strip_us = stats.strip_us + took
                stats.strip_max = math.max(stats.strip_max, took)
                stats.info_calls = stats.info_calls + rec.info_calls
                stats.info_uncached = stats.info_uncached + rec.info_uncached
                stats.info_us = stats.info_us + rec.info_us
                stats.cover_us = stats.cover_us + rec.cover_us
                stats.cover_max = math.max(stats.cover_max, rec.cover_max)
                stats.covers_sh = stats.covers_sh + rec.covers_sh
                stats.covers_bim = stats.covers_bim + rec.covers_bim
                stats.covers_tile = stats.covers_tile + rec.covers_tile
                log("swipe %s: page %s -> %s, STRIP BUILT in %s ms (memory %+d KB)%s",
                    dir, q(from), q(self.page), f1(took), math.floor(mem() - m0), took > 250000 and "  SLOW" or "")
                log("    book list: %d status lookups (%d read a sidecar) %s ms%s",
                    rec.info_calls, rec.info_uncached, f1(rec.info_us),
                    rec.tbr_us and (", To Be Read list " .. f1(rec.tbr_us) .. " ms") or "")
                log("    covers: SimpleUI %d, CoverBrowser %d, title tile %d | %s ms (slowest %s), scaling %s ms, titles/meta %s ms, text layout %s ms",
                    rec.covers_sh, rec.covers_bim, rec.covers_tile, f1(rec.cover_us), f1(rec.cover_max),
                    f1(rec.scale_us), f1(rec.data_us), f1(rec.text_us))
            else
                log("swipe %s: page %s -> %s in %s ms%s", dir, q(from), q(self.page), f1(took),
                    from == self.page and " (no change)" or "")
            end
            if from ~= self.page then paint_after_swipe = now() end
            return res
        end
    end

    local orig_paint = pager.paintTo
    pager.paintTo = function(self, ...)
        if not (paint_after_swipe and window_open) then return orig_paint(self, ...) end
        local t = now()
        local res = orig_paint(self, ...)
        local took = us(t)
        local since = us(paint_after_swipe)
        paint_after_swipe = false
        stats.paints = stats.paints + 1
        stats.paint_us = stats.paint_us + took
        stats.paint_max = math.max(stats.paint_max, took)
        log("    repaint: toolbar row painted in %s ms, %s ms after the swipe", f1(took), f1(since))
        return res
    end
end

-- Covers: count which source each tile used. The patch builds each tile as
-- coverWidget(...) or titleTile(...): titleTile = no thumbnail. Watch the
-- tile containers being created during a strip build.
local function hookTileCount()
    local ok, CenterContainer = pcall(require, "ui/widget/container/centercontainer")
    if not ok or rawget(CenterContainer, "__stbrd_new") then return end
    rawset(CenterContainer, "__stbrd_new", true)
    local orig_new = CenterContainer.new
    CenterContainer.new = function(cls, o, ...)
        local w = orig_new(cls, o, ...)
        if cur and fromMain(2) and type(o) == "table" and o.dimen and o[1] then
            -- the cover slot of a tile (the empty-list message has no dimen pair like this)
            if cur.pending_cover == "sh" then cur.covers_sh = cur.covers_sh + 1
            elseif cur.pending_cover == "bim" then cur.covers_bim = cur.covers_bim + 1
            elseif o[1].bordersize then cur.covers_tile = cur.covers_tile + 1 end
            cur.pending_cover = nil
        end
        return w
    end
end

-- --------------------------------------------------------------------------
-- Hook the toolbar build (after the Quick Shelf patch has wrapped it)
-- --------------------------------------------------------------------------

local function findUpvalue(fn, name)
    if type(fn) ~= "function" then return nil end
    local i = 1
    while true do
        local n, v = debug.getupvalue(fn, i)
        if not n then return nil end
        if n == name then return i, v end
        i = i + 1
    end
end

local function findBuilder(fn, depth, seen)
    if type(fn) ~= "function" or depth > 4 or seen[fn] then return nil end
    seen[fn] = true
    local idx = findUpvalue(fn, "createBookInfoPanel")
    if idx then return fn, idx end
    local i = 1
    while true do
        local n, v = debug.getupvalue(fn, i)
        if not n then return nil end
        if type(v) == "function" then
            local f, j = findBuilder(v, depth + 1, seen)
            if f then return f, j end
        end
        i = i + 1
    end
end

userpatch.registerPatchPluginFunc("shortcutstoolbar", function()
    local ok, HC = pcall(require, "home_content")
    if not ok or type(HC) ~= "table" or HC.__stbrd_hooked then return end
    HC.__stbrd_hooked = true

    local hooked = HC.__stb_quick_shelf == true
    local builder, idx = findBuilder(HC.createHomeContent, 0, {})
    if not builder then
        shared_log("plugin book panel not found: Quick Shelf patch can't be active either (plugin changed?)")
        return
    end
    local _n, wrapper = debug.getupvalue(builder, idx)
    -- The plugin's own panel, behind the Quick Shelf wrapper.
    local oi, orig_panel = findUpvalue(wrapper, "orig_panel")
    if not (hooked and oi) then
        shared_log("Quick Shelf patch NOT active (hooked=%s, wrapper found=%s): nothing to watch", q(hooked), q(oi ~= nil))
        return
    end

    local panel_us
    debug.setupvalue(wrapper, oi, function(...)
        local t = now()
        local res = { pcall(orig_panel, ...) }
        panel_us = us(t)
        if not res[1] then error(res[2], 0) end
        return unpack(res, 2)
    end)
    debug.setupvalue(builder, idx, function(...)
        openWindow()
        if not active() then return wrapper(...) end
        panel_us = 0
        local t = now()
        local res = { pcall(wrapper, ...) }
        local total = us(t)
        if not res[1] then error(res[2], 0) end
        local pager = res[2]
        local is_pager = type(pager) == "table" and type(pager.onSwipePager) == "function"
        stats.builds = stats.builds + 1
        stats.build_plugin = stats.build_plugin + panel_us
        stats.build_patch = stats.build_patch + math.max(0, total - panel_us)
        log("reader toolbar built: plugin book panel %s ms + patch %s ms%s",
            f1(panel_us), f1(math.max(0, total - panel_us)),
            is_pager and "" or "  (no pager: no book open, or the patch fell back)")
        if is_pager then watchPager(pager) end
        return unpack(res, 2)
    end)
    hookTileCount()
    shared_log("watching Quick Shelf patch (book panel hooked)")
end)

-- --------------------------------------------------------------------------
-- Book taps, sleep, warnings
-- --------------------------------------------------------------------------

local ok_r, ReaderUI = pcall(require, "apps/reader/readerui")
if ok_r and type(ReaderUI.switchDocument) == "function" then
    local orig_switch = ReaderUI.switchDocument
    ReaderUI.switchDocument = function(self, file, ...)
        if active() and fromMain(2) then
            stats.taps = stats.taps + 1
            log("book tapped: switching to %s", q(type(file) == "string" and file:match("[^/]+$")))
        end
        return orig_switch(self, file, ...)
    end
end

-- The refresh each page change asks for (type, area, dithered).
local orig_setDirty = UIManager.setDirty
UIManager.setDirty = function(self, widget, refresh, ...)
    if window_open and fromMain(2) then
        local rtype, region, dither = refresh, ...
        if type(refresh) == "function" then rtype, region, dither = refresh() end
        log("    refresh: %s, %sx%s px%s", q(rtype),
            q(type(region) == "table" and region.w), q(type(region) == "table" and region.h),
            dither and ", dithered" or "")
    end
    return orig_setDirty(self, widget, refresh, ...)
end

local orig_broadcast = UIManager.broadcastEvent
UIManager.broadcastEvent = function(self, event, ...)
    local h = type(event) == "table" and event.handler
    if h == "onSuspend" and active() then
        local n = pendingMainTasks()
        log("SLEEP: Quick Shelf timers pending: %d%s", n, n > 0 and "  CHECK" or "")
        if n > 0 then stats.asleep_actions = stats.asleep_actions + n end
        summary("going to sleep")
    elseif h == "onResume" and active() then
        log("WAKE")
    end
    return orig_broadcast(self, event, ...)
end

local orig_warn = logger.warn
logger.warn = function(...)
    if active() then
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
        local line = table.concat(parts, " ")
        if line:find("quick shelf", 1, true) then
            stats.warnings = stats.warnings + 1
            log("PATCH WARNING: %s", line)
        end
    end
    return orig_warn(...)
end

logger.info("shortcutstoolbar quick shelf diagnostics " .. DIAG_VERSION .. " loaded")
