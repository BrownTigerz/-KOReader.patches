--[[
    2-readinginsights-tweaks.lua
    Version: 2.1.0
    KOReader user patch: visual toggles for Reading Insights
    (peterboda236/readinginsights.koplugin) and KOReader's Statistics calendar.
    Each one is on its own toggle.

      1. Book calendar header     cover, title and author under the month title
                                  of the Book progress calendar.
      2. Heatmap goal shading     calendar heatmap shaded against your daily goal
                                  (darkest = goal met) instead of your busiest day.
      3. Record covers            the books behind your records (most time in a
                                  day, most pages in a day, best streak); tap one
                                  for details or to open the book.
      4. Statistics calendar      KOReader's built-in Statistics calendar view:
                                  covers instead of title bars, time badge shaded
                                  by your daily goal. Tap a day still opens its
                                  day view.
      5. Close on sleep           Reading Insights (and anything it opened) closes
                                  when the device sleeps, so waking shows your
                                  home screen or book, not the stats. On by default.

    Streak calendar covers, tap-a-day and the sleep card were removed in 2.0.0:
    Reading Insights 8.1+ does all three itself (streak calendar covers with
    stacking and tap-a-day; sleep screen with a cover background or Book progress).

    How: Reading Insights loads its files through the global loadfile. This
    patch wraps loadfile for three of its view files. The book calendar gets a
    small addition to its source (routing one function through here); the
    heatmap and records views are patched on the module table they return. The
    Statistics calendar is patched when KOReader's Statistics plugin loads.
    Toggles are checked every time something is drawn, so turning one off gives
    you the stock view right away.

    Update-safe: every addition looks for exact lines first. If a Reading Insights
    update changes them, that feature is skipped (logged as "RI tweaks:") and the
    stock view is used. Any error while drawing also falls back to stock.

    Covers come from CoverBrowser's cache (keep CoverBrowser enabled). A cover not
    cached yet shows its title; it's fetched once in CoverBrowser's background
    subprocess and appears the next time the view is drawn.

    Menu: Tools > Tweaks & Mods > Reading Insights Tweaks (with 2-tweaks-menu.lua),
    otherwise Tools > Reading Insights Tweaks.

    Install: koreader/patches/ (Kobo: .adds/koreader/patches/), then restart once.
    Replaces 2-readinginsights-covers.lua / 2-cover-calendar.lua (delete those).

    Cost: nothing runs in the background and nothing runs at sleep. Work happens
    only when you open one of these views (a few small read-only queries + covers
    already cached by CoverBrowser). Scaled covers are kept for the session (max
    150). The only timer is a one-shot 30s retry window after a missing cover was
    sent for extraction. One quick check each time a window opens (to know
    Reading Insights' own: Simple UI's home mark in 2.0.1, closing on sleep in
    2.1.0); at sleep, Reading Insights' windows are closed, nothing else runs.

    Versioning
      1.0.x  fixes, e.g. adapting to a Reading Insights or KOReader change
      1.x.0  new features or toggles
      2.0.0  something that changes how existing toggles or saved settings work

    Changelog
      1.0.0  2026-10-02  First release.
      1.1.0  2026-10-03  Record covers are tappable (book details, open book). Menu
                         renamed to Reading Insights Tweaks.
      1.1.1  2026-10-04  Dialogs opened from Reading Insights' popups (day details,
                         record book) and the sleep card now show on top instead
                         of behind: Reading Insights' popups are modal, and
                         KOReader stacks non-modal windows below modal ones.
      1.1.2  2026-10-08  Reading Insights 6.15+ support: its streak grid now also
                         returns day positions (for its new tap-a-day book list);
                         the cover grid returns them too, so the calendar no
                         longer errors with covers on. Reading Insights' own day
                         tap is used when present (works across the full height
                         of tall cover cells); this patch's day dialog and its
                         toggle remain only for older Reading Insights.
      1.1.3  2026-10-09  Taller cover cells: the streak popup's fit-to-screen now
                         accounts for the taller rows (covers were shrunk ~45% more
                         than needed). Records covers and Statistics calendar covers
                         check the exact widget layout before adding anything (a
                         layout change now skips them instead of misplacing them).
      1.1.4  2026-10-11  Fixed the sleep-card install guard: KOReader wraps plugin
                         on* handlers in callable HandlerSandbox tables before
                         userpatch callbacks run, so the bare type()=="function"
                         check was a false negative — it warned on every load and
                         left the whole sleep-card block (flush, wraps, card)
                         uninstalled. Now accepts callables, and only warns when
                         the sleep-card setting is actually on.
      1.1.5  2026-10-11  Title case for all menu item texts (TK convention):
                         first letter of every word capitalized.
      2.0.0  2026-10-16  For Reading Insights 8.1+, which now has its own streak
                         calendar covers, tap-a-day and a cover/Book progress sleep
                         screen. Removed this patch's streak calendar covers,
                         taller cells, tap-a-day and sleep card, with their four
                         toggles; their saved settings are cleared once on first
                         start. Nothing hooks suspend/resume any more. Kept: book
                         calendar header, heatmap goal shading, record covers,
                         Statistics calendar covers, daily goal.
      2.0.1  2026-10-23  Simple UI: closing Reading Insights after one of its
                         full-screen pages (a day's book list, Achievements, a
                         year's books) went to the stock library instead of the
                         home screen. Simple UI closes its home under a
                         full-screen page and only brings it back if nothing
                         else is open when the page closes, and Reading
                         Insights' popup still was. Reading Insights' own
                         full-screen pages now keep Simple UI's home open under
                         them (Simple UI's own _sui_keep_homescreen flag), so
                         closing them and then Reading Insights lands on home.
      2.1.0  2026-10-23  New toggle, Close Reading Insights On Sleep (on by
                         default): Reading Insights and everything it opened
                         (its popup, day lists, Achievements...) close when the
                         device sleeps, so waking shows the home screen or the
                         book you were reading. Reading Insights' own sleep
                         screen isn't affected (it's drawn after they close).
]]

local Blitbuffer = require("ffi/blitbuffer")
local ButtonDialog = require("ui/widget/buttondialog")
local CenterContainer = require("ui/widget/container/centercontainer")
local DataStorage = require("datastorage")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local ImageWidget = require("ui/widget/imagewidget")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local OverlapGroup = require("ui/widget/overlapgroup")
local RenderImage = require("ui/renderimage")
local Size = require("ui/size")
local SpinWidget = require("ui/widget/spinwidget")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local util = require("util")
local T = require("ffi/util").template
local _ = require("gettext")
local Screen = Device.screen

local PATCH_VERSION = "2.1.0" -- the only number to change when updating
local TAG = "RI tweaks:"
logger.info(TAG, "version", PATCH_VERSION, "loaded")
local HOOK_NAME = "ri_tweaks_hook"

-- ---- Settings ------------------------------------------------------------------------------
local SETTINGS_KEY = "ri_cover_calendar"
local DEFAULTS = {
    book_header = true,    -- 1. book calendar header
    heatmap_goal = true,   -- 2. heatmap goal shading
    records = true,        -- 3. record covers
    stats_calendar = true, -- 4. built-in Statistics calendar covers
    close_on_sleep = true, -- 5. close Reading Insights' windows on sleep
    goal_min = 30,
}

-- 2.0.0: clear the settings of the toggles that were removed (streak calendar
-- covers, taller cells, tap-a-day, sleep card). One write, only if any are there.
do
    local saved = G_reader_settings:readSetting(SETTINGS_KEY)
    if type(saved) == "table" then
        local changed = false
        for _i, k in ipairs({ "enabled", "tall", "day_tap", "sleep_card" }) do
            if saved[k] ~= nil then
                saved[k] = nil
                changed = true
            end
        end
        if changed then G_reader_settings:saveSetting(SETTINGS_KEY, saved) end
    end
end

local function getSetting(key)
    local s = G_reader_settings:readSetting(SETTINGS_KEY) or {}
    if s[key] == nil then return DEFAULTS[key] end
    return s[key]
end

local function setSetting(key, value)
    local s = G_reader_settings:readSetting(SETTINGS_KEY) or {}
    s[key] = value
    G_reader_settings:saveSetting(SETTINGS_KEY, s)
end

-- ---- Look / formatting ---------------------------------------------------------------------
local C_WHITE = Blitbuffer.COLOR_WHITE
local C_BLACK = Blitbuffer.COLOR_BLACK
local C_CARD  = Blitbuffer.Color8(0xEE)
local C_MUTED = Blitbuffer.Color8(0x66)
local C_FAINT = Blitbuffer.Color8(0xAA)
-- goal levels: 1 none, 2 <1/3, 3 <2/3, 4 <goal, 5 goal met
local LEVEL_BG = {
    Blitbuffer.Color8(0xFF), Blitbuffer.Color8(0xDD), Blitbuffer.Color8(0xAA),
    Blitbuffer.Color8(0x66), Blitbuffer.Color8(0x11),
}

local function S(n) return Screen:scaleBySize(n) end

local function fmtDuration(sec)
    sec = math.floor(sec or 0)
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    if h > 0 then return m > 0 and (h .. "h " .. m .. "m") or (h .. "h") end
    return m .. "m"
end

local function fmtBadge(sec)
    if sec < 3570 then return math.max(1, math.floor(sec / 60 + 0.5)) .. "m" end
    return math.floor(sec / 3600 + 0.5) .. "h"
end

local function goalSecs() return getSetting("goal_min") * 60 end

local function goalLevel(sec)
    if not sec or sec <= 0 then return 1 end
    local r = sec / goalSecs()
    if r >= 1 then return 5 elseif r >= 2/3 then return 4 elseif r >= 1/3 then return 3 end
    return 2
end

local function dateToTime(ds, hour)
    local y, m, d = tostring(ds or ""):match("(%d+)-(%d+)-(%d+)")
    if not y then return nil end
    return os.time{ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = hour or 0 }
end

-- ---- Stats database ------------------------------------------------------------------------
local DB_PATH = DataStorage:getSettingsDir() .. "/statistics.sqlite3"

-- Runs one SELECT; returns the column-major result (res[col][row]) or nil.
-- One connection is shared by every query in the same UI pass (a calendar build
-- runs several) and closed on the next tick. No transaction is held open.
local shared_conns = {}

local function getConn(path)
    path = path or DB_PATH
    if shared_conns[path] then return shared_conns[path] end
    if lfs.attributes(path, "mode") ~= "file" then return nil end
    local ok_req, SQ3 = pcall(require, "lua-ljsqlite3/init")
    if not ok_req then return nil end
    local ok_open, conn = pcall(SQ3.open, path)
    if not ok_open or not conn then return nil end
    shared_conns[path] = conn
    UIManager:nextTick(function()
        local c = shared_conns[path]
        shared_conns[path] = nil
        if c then pcall(c.close, c) end
    end)
    return conn
end

local function dbQuery(sql)
    local conn = getConn()
    if not conn then return nil end
    local ok, res = pcall(conn.exec, conn, sql)
    if not ok then
        logger.warn(TAG, "query failed", res)
        return nil
    end
    return res
end

local function nrows(res) return (res and res[1]) and #res[1] or 0 end

local function loadMonth(y, m)
    local t0 = os.time{ year = y, month = m, day = 1, hour = 0 }
    local t1 = os.time{ year = y, month = m + 1, day = 1, hour = 0 } - 1
    local res = dbQuery(
        "SELECT CAST(strftime('%d', p.start_time, 'unixepoch', 'localtime') AS INTEGER) AS d, " ..
        "p.id_book, SUM(p.duration), COUNT(DISTINCT p.page), b.title, b.authors, b.md5 " ..
        "FROM page_stat_data p JOIN book b ON b.id = p.id_book " ..
        "WHERE p.start_time BETWEEN " .. t0 .. " AND " .. t1 .. " " ..
        "GROUP BY d, p.id_book ORDER BY d, 3 DESC")
    local days, books = {}, {}
    for i = 1, nrows(res) do
        local d, id = tonumber(res[1][i]), tonumber(res[2][i])
        if d and id then
            books[id] = books[id] or { id = id, title = res[5][i], authors = res[6][i], md5 = res[7][i] }
            local day = days[d]
            if not day then
                day = { dur = 0, pages = 0, list = {} }
                days[d] = day
            end
            local dur, pages = tonumber(res[3][i]) or 0, tonumber(res[4][i]) or 0
            day.dur = day.dur + dur
            day.pages = day.pages + pages
            table.insert(day.list, { id = id, dur = dur, pages = pages })
        end
    end
    return days, books
end

-- Top book between t0 and t1, by time ("time") or distinct pages ("pages").
local function topBook(t0, t1, by)
    if not t0 or not t1 then return nil end
    local order = by == "pages" and "COUNT(DISTINCT p.page)" or "SUM(p.duration)"
    local res = dbQuery(
        "SELECT b.id, b.title, b.authors, b.md5 FROM page_stat_data p JOIN book b ON b.id = p.id_book " ..
        "WHERE p.start_time BETWEEN " .. t0 .. " AND " .. t1 .. " " ..
        "GROUP BY p.id_book ORDER BY " .. order .. " DESC LIMIT 1")
    if nrows(res) == 0 then return nil end
    return { id = tonumber(res[1][1]), title = res[2][1], authors = res[3][1], md5 = res[4][1] }
end

local function bookById(id)
    id = tonumber(id)
    if not id then return nil end
    local res = dbQuery("SELECT title, authors, md5 FROM book WHERE id = " .. id)
    if nrows(res) == 0 then return nil end
    return { id = id, title = res[1][1], authors = res[2][1], md5 = res[3][1] }
end

-- ---- Stats md5 -> file path (exact, via ReadHistory, cached for the session) ---------------
local md5_to_path, hashed = {}, {}
local BIM_DB = DataStorage:getSettingsDir() .. "/bookinfo_cache.sqlite3"
local title_missed = {}

local function findByTitle(title)
    if not title or title == "" or title_missed[title] then return nil end
    title_missed[title] = true -- one lookup per title per session
    local conn = getConn(BIM_DB)
    if not conn then return nil end
    local ok, res = pcall(conn.exec, conn,
        "SELECT directory, filename FROM bookinfo WHERE title = '" .. (title:gsub("'", "''")) .. "'")
    if not ok then return nil end
    for i = 1, nrows(res) do
        local dir, name = res[1][i], res[2][i]
        if dir and name then
            if not dir:match("/$") then dir = dir .. "/" end
            local p = dir .. name
            if lfs.attributes(p, "mode") == "file" then
                title_missed[title] = nil
                return p
            end
        end
    end
    return nil
end

local function resolvePaths(books)
    local need, missing = {}, 0
    for _k, b in pairs(books) do
        if b.md5 then
            local p = md5_to_path[b.md5]
            if p and lfs.attributes(p, "mode") == "file" then
                b.path = p
            elseif not need[b.md5] then
                need[b.md5] = true
                missing = missing + 1
            end
        end
    end
    if missing == 0 then return end
    local ok, ReadHistory = pcall(require, "readhistory")
    if not ok or type(ReadHistory) ~= "table" or type(ReadHistory.hist) ~= "table" then return end
    for _i, item in ipairs(ReadHistory.hist) do
        local f = item.file
        if f and not hashed[f] then
            hashed[f] = true
            if lfs.attributes(f, "mode") == "file" then
                local ok_m, md5 = pcall(util.partialMD5, f)
                if ok_m and md5 then
                    md5_to_path[md5] = f
                    if need[md5] then
                        need[md5] = nil
                        missing = missing - 1
                    end
                end
            end
            if missing == 0 then break end
        end
    end
    for _k, b in pairs(books) do
        if b.md5 and not b.path then b.path = md5_to_path[b.md5] end
    end
    -- Books no longer in your history: look them up by title in CoverBrowser's
    -- index (finds any file it has seen while you browsed your library).
    for _k, b in pairs(books) do
        if not b.path and b.title then
            local p = findByTitle(b.title)
            if p then
                b.path = p
                if b.md5 then md5_to_path[b.md5] = p end
            end
        end
    end
end

local function resolveOne(book)
    if book then resolvePaths({ book }) end
    return book
end

-- ---- Covers (CoverBrowser's cache) ---------------------------------------------------------
-- Scaled covers are kept for the session (sizes are fixed per view, so roughly
-- one per book per view). Past MAX_CACHED, a cover is owned by its widget.
local MAX_CACHED = 150
local bb_cache, bb_count = {}, 0
local queued, queued_now, pending = {}, {}, {}

local function getBIM()
    local ok, BIM = pcall(require, "bookinfomanager")
    if ok and type(BIM) == "table" then return BIM end
end

local function flushExtraction()
    if #pending == 0 then return end
    local BIM = getBIM()
    local spec = { max_cover_w = math.floor(Screen:getWidth() / 3), max_cover_h = math.floor(Screen:getHeight() / 3) }
    local files = {}
    for _i, p in ipairs(pending) do files[#files + 1] = { filepath = p, cover_specs = spec } end
    local batch = pending
    pending = {}
    local ok, err = false, "CoverBrowser unavailable"
    if BIM and type(BIM.extractInBackground) == "function" then
        ok, err = pcall(BIM.extractInBackground, BIM, files)
    end
    if not ok then
        logger.warn(TAG, "background extraction failed", err)
        for _i, p in ipairs(batch) do queued[p] = 0 end -- didn't start: full retry budget
    end
    -- let the next draw requeue anything still missing (within its attempt budget),
    -- but not before this batch has had time to finish
    UIManager:scheduleIn(30, function()
        for _i, p in ipairs(batch) do queued_now[p] = nil end
    end)
end

-- returns bb, owned_by_widget
local function getScaledCover(path, bw, bh)
    local key = path .. "|" .. bw .. "x" .. bh
    local cached = bb_cache[key]
    if cached ~= nil then return cached or nil, false end
    local BIM = getBIM()
    if not BIM then return nil end
    local ok, bi = pcall(BIM.getBookInfo, BIM, path, true)
    if not ok then bi = nil end
    if not bi or bi.cover_fetched ~= "Y" then
        -- queued[path] counts attempts: a failed extraction is retried once
        -- on a later draw, then left alone for the session
        if (queued[path] or 0) < 2 and not queued_now[path]
           and lfs.attributes(path, "mode") == "file" then
            queued[path] = (queued[path] or 0) + 1
            queued_now[path] = true
            table.insert(pending, path)
        end
        return nil
    end
    local src = bi.cover_bb
    if not src then
        bb_cache[key] = false
        return nil
    end
    local sw, sh = src:getWidth(), src:getHeight()
    local s = math.min(bw / sw, bh / sh)
    local ok2, scaled = pcall(RenderImage.scaleBlitBuffer, RenderImage, src,
        math.max(1, math.floor(sw * s)), math.max(1, math.floor(sh * s)), true)
    if not ok2 or not scaled then
        pcall(src.free, src)
        return nil -- transient: retried next draw (only "no cover" is cached as false)
    end
    if bb_count < MAX_CACHED then
        bb_cache[key] = scaled
        bb_count = bb_count + 1
        return scaled, false
    end
    return scaled, true
end

-- A cover fitting in bw x bh, or a title placeholder of exactly that size.
local function coverWidget(book, bw, bh, border)
    border = border or Size.border.thin
    if book and book.path then
        local bb, owned = getScaledCover(book.path, bw - 2 * border, bh - 2 * border)
        if bb then
            return FrameContainer:new{
                bordersize = border, color = C_BLACK, padding = 0, margin = 0,
                ImageWidget:new{ image = bb, image_disposable = owned and true or false },
            }
        end
    end
    local pad = S(2)
    local iw, ih = bw - 2 * (border + pad), bh - 2 * (border + pad)
    return FrameContainer:new{
        width = bw, height = bh, bordersize = border, color = C_FAINT,
        radius = S(3), padding = pad, margin = 0, background = C_CARD,
        CenterContainer:new{
            dimen = Geom:new{ w = iw, h = ih },
            TextBoxWidget:new{
                text = (book and book.title) or "?",
                face = Font:getFace("cfont", 8),
                width = iw, height = ih,
                height_adjust = true, height_overflow_show_ellipsis = true,
                alignment = "center",
            },
        },
    }
end

local function whiteBar(w, h)
    return LineWidget:new{ dimen = Geom:new{ w = w, h = h }, background = C_WHITE }
end

local function badge(text, level)
    local tw = TextWidget:new{
        text = text,
        face = Font:getFace("cfont", 11),
        fgcolor = level >= 4 and C_WHITE or C_BLACK,
        bold = level == 5,
    }
    return FrameContainer:new{
        radius = math.floor(tw:getSize().h / 2),
        bordersize = Size.border.thin, color = C_FAINT,
        background = LEVEL_BG[level],
        margin = 0, padding = 0, padding_left = S(4), padding_right = S(4),
        tw,
    }
end

-- ---- Opening a book from inside Reading Insights' popups ------------------------------------
local function openBook(path)
    if not path or lfs.attributes(path, "mode") ~= "file" then return end
    local ok_r, ReaderUI = pcall(require, "apps/reader/readerui")
    if not ok_r then return end
    local ok_f, FileManager = pcall(require, "apps/filemanager/filemanager")
    -- close every popup stacked above the reader / file browser
    local function isBase(w)
        return w == ReaderUI.instance or (ok_f and w == FileManager.instance)
    end
    local closed = pcall(function()
        if type(UIManager.getTopmostVisibleWidget) ~= "function" then error("no public API") end
        for _i = 1, 12 do
            local w = UIManager:getTopmostVisibleWidget()
            if not w or isBase(w) then return end
            UIManager:close(w)
        end
    end)
    if not closed then -- older KOReader: fall back to the internal stack
        pcall(function()
            local stack = UIManager._window_stack or {}
            for i = #stack, 1, -1 do
                local w = stack[i] and stack[i].widget
                if not w or isBase(w) then break end
                UIManager:close(w)
            end
        end)
    end
    UIManager:nextTick(function()
        if ReaderUI.instance then
            local doc = ReaderUI.instance.document
            if doc and doc.file == path then return end
            ReaderUI.instance:switchDocument(path)
        else
            ReaderUI:showReader(path)
        end
    end)
end

-- =============================================================================================
-- Shared: hook table (read by the source edit and the diagnostics patch) and the cover cell
-- =============================================================================================
local Hook = { caps = {}, version = PATCH_VERSION }
package.loaded[HOOK_NAME] = Hook

local function coverCell(info, books, cw, ch, is_today, no_bg)
    local pad = S(3)
    local list = info.list
    local n = math.min(#list, 3) -- up to 3 covers fanned out, +N for more
    local b = (info.dur or 0) > 0 and badge(fmtBadge(info.dur), goalLevel(info.dur)) or nil
    local bsz = b and b:getSize() or { w = 0, h = 0 }
    local top = math.floor(bsz.h / 2)
    local box_h = ch - 2 * pad - top

    -- Step between stacked covers: use the cell's spare width (covers are
    -- height-limited, so there's usually plenty), within sensible limits.
    local step, drop = 0, 0
    if n > 1 then
        local spare = cw - 2 * pad - math.floor(box_h * 2 / 3)
        step = math.max(S(5), math.min(S(22), math.floor(spare / (n - 1))))
        drop = math.floor(step / 3) -- slight vertical shift for depth
    end
    local box_w = cw - 2 * pad - (n - 1) * step
    local main = coverWidget(books[list[1].id], box_w, box_h - (n - 1) * drop,
        is_today and Size.border.thick or nil)
    local ms = main:getSize()
    local stack_w = ms.w + (n - 1) * step
    local cx = math.floor((cw - stack_w) / 2)
    local cy = pad + top + math.floor((box_h - ms.h - (n - 1) * drop) / 2)

    local group = OverlapGroup:new{ dimen = Geom:new{ w = cw, h = ch } }
    if not no_bg then table.insert(group, whiteBar(cw, ch)) end
    for i = n, 2, -1 do -- back-most first
        local back = coverWidget(books[list[i].id], ms.w, ms.h)
        local bs = back:getSize()
        back.overlap_offset = {
            cx + (i - 1) * step + (ms.w - bs.w),
            cy + (i - 1) * drop + math.floor((ms.h - bs.h) / 2),
        }
        table.insert(group, back)
    end
    main.overlap_offset = { cx, cy }
    table.insert(group, main)
    if #list > 3 then
        local more = badge("+" .. (#list - 3), 1)
        more.overlap_offset = { cx, math.max(0, cy + ms.h - more:getSize().h) }
        table.insert(group, more)
    end
    if b then
        local bx = math.min(cw - bsz.w, cx + stack_w - math.floor(bsz.w * 0.7))
        b.overlap_offset = { math.max(0, bx), math.max(0, cy - top) }
        table.insert(group, b)
    end
    return group
end

-- =============================================================================================
-- 1. Book progress calendar header
-- =============================================================================================
local function buildBookRow(book, width)
    local cover_h = S(78)
    local cover_w = math.floor(cover_h * 2 / 3)
    local cover = coverWidget(book, cover_w, cover_h)
    local gap = S(10)
    local text_w = math.max(S(60), width - cover:getSize().w - gap)
    local texts = VerticalGroup:new{ align = "left" }
    table.insert(texts, TextBoxWidget:new{
        text = book.title or "?", face = Font:getFace("tfont", 15), width = text_w,
        height = S(42), height_adjust = true, height_overflow_show_ellipsis = true,
    })
    if book.authors and book.authors ~= "" then
        table.insert(texts, TextWidget:new{
            text = book.authors, face = Font:getFace("cfont", 12), fgcolor = C_MUTED, max_width = text_w,
        })
    end
    local row = HorizontalGroup:new{ align = "center", cover, HorizontalSpan:new{ width = gap }, texts }
    return LeftContainer:new{ dimen = Geom:new{ w = width, h = row:getSize().h }, row }
end

function Hook.bookCal(orig_rebuild, orig_header)
    local ctx
    local rebuild = function(self, ...)
        ctx = { book_id = self.book_id }
        local ok, err = pcall(orig_rebuild, self, ...)
        ctx = nil
        if not ok then error(err, 0) end
    end
    local header = function(title_str, content_width, ...)
        local row, lf, rf, lw, rw, hh = orig_header(title_str, content_width, ...)
        if ctx and getSetting("book_header") and type(content_width) == "number" then
            local ok, grp = pcall(function()
                if not ctx.book then ctx.book = resolveOne(bookById(ctx.book_id)) or false end
                if not ctx.book then return nil end
                local g = VerticalGroup:new{
                    align = "center",
                    row,
                    VerticalSpan:new{ width = Size.padding.large },
                    buildBookRow(ctx.book, content_width),
                }
                flushExtraction()
                return g
            end)
            if ok and grp then
                row = grp -- arrows stay on the top line; hh (their tap height) is unchanged
            elseif not ok then
                logger.warn(TAG, "book header failed:", grp)
            end
        end
        return row, lf, rf, lw, rw, hh
    end
    return rebuild, header
end

-- =============================================================================================
-- 2. Heatmap goal shading (module table patch)
-- =============================================================================================
local function patchHeatmap(M, deps)
    if type(M) ~= "table" or type(M.heatmapLevelColor) ~= "function"
       or type(M.buildRangeHeatmapWidget) ~= "function" then
        logger.warn(TAG, "heatmap changed; goal shading skipped")
        return
    end
    local orig_level, orig_range = M.heatmapLevelColor, M.buildRangeHeatmapWidget
    local in_range = false
    M.heatmapLevelColor = function(seconds, max_seconds, ...)
        if in_range and getSetting("heatmap_goal") and seconds and seconds > 0 then
            -- Reuse Reading Insights' own shades, but skip its faintest one: it sits
            -- too close to "no reading" (especially in night mode). Any reading gets
            -- at least the middle shade; under half the goal, 3/4 of it, goal met.
            local r = seconds / goalSecs()
            local frac = r >= 1 and 1 or (r >= 0.5 and 0.7 or 0.45)
            return orig_level(frac, 1)
        end
        return orig_level(seconds, max_seconds, ...)
    end
    M.buildRangeHeatmapWidget = function(daily_map, start_t, end_t, fonts, max_width, ...)
        in_range = true
        local ok, w, cs, off = pcall(orig_range, daily_map, start_t, end_t, fonts, max_width, ...)
        in_range = false
        if not ok then error(w, 0) end
        if w and getSetting("heatmap_goal") then
            local ok2, grp = pcall(function()
                local face = (type(fonts) == "table" and fonts.small) or Font:getFace("cfont", 11)
                return VerticalGroup:new{
                    align = "left",
                    w,
                    VerticalSpan:new{ width = S(4) },
                    TextWidget:new{
                        text = T(_("Shaded by daily goal · %1 = %2 or more"),
                            G_reader_settings:isTrue("night_mode") and _("brightest") or _("darkest"),
                            fmtDuration(goalSecs())),
                        face = face, fgcolor = C_MUTED,
                        max_width = type(max_width) == "number" and max_width or nil,
                    },
                }
            end)
            if ok2 and grp then w = grp end
        end
        return w, cs, off
    end
end

-- =============================================================================================
-- 3. Record covers (module table patch)
-- =============================================================================================
local function recordTiles(d, width)
    local tiles = {}
    local function add(book, label, when)
        if book then tiles[#tiles + 1] = { book = resolveOne(book), label = label, when = when } end
    end
    local function day(t) return t and (os.date("%B ", t) .. tonumber(os.date("%d", t)) .. os.date(", %Y", t)) end
    if d.longest and d.longest.date then
        local t0 = dateToTime(d.longest.date, 0)
        add(topBook(t0, t0 and t0 + 86399, "time"), _("Most time"), day(t0))
    end
    if d.best_day and d.best_day.date then
        local t0 = dateToTime(d.best_day.date, 0)
        add(topBook(t0, t0 and t0 + 86399, "pages"), _("Most pages"), day(t0))
    end
    if d.streak and d.streak.start_date and d.streak.end_date then
        local t0, t1 = dateToTime(d.streak.start_date, 0), dateToTime(d.streak.end_date, 0)
        local span = (t0 and t1) and (day(t0) .. " – " .. day(t1)) or nil
        add(topBook(t0, t1 and t1 + 86399, "time"), _("Best streak"), span)
    end
    if #tiles == 0 then return nil end

    local tile_w = math.floor(width / 3)
    local cover_h = S(96)
    local cover_w = math.min(tile_w - S(12), math.floor(cover_h * 2 / 3))
    local label_face = Font:getFace("cfont", 11)
    local row = HorizontalGroup:new{ align = "top" }
    for _i, tile in ipairs(tiles) do
        -- a frame per tile so its on-screen position is known for taps
        tile.frame = FrameContainer:new{
            bordersize = 0, padding = 0, margin = 0,
            CenterContainer:new{
                dimen = Geom:new{ w = tile_w, h = cover_h + S(24) },
                VerticalGroup:new{
                    align = "center",
                    coverWidget(tile.book, cover_w, cover_h),
                    VerticalSpan:new{ width = S(4) },
                    TextWidget:new{ text = tile.label, face = label_face, fgcolor = C_MUTED, max_width = tile_w - S(4) },
                },
            },
        }
        table.insert(row, tile.frame)
    end
    flushExtraction()
    return CenterContainer:new{ dimen = Geom:new{ w = width, h = row:getSize().h }, row }, tiles
end

local function showRecordBook(tile)
    local b = tile.book or {}
    local lines = { b.title or "?" }
    if b.authors and b.authors ~= "" then lines[#lines + 1] = b.authors end
    lines[#lines + 1] = tile.label .. (tile.when and (" · " .. tile.when) or "")
    local dlg
    dlg = ButtonDialog:new{
        modal = true, -- Reading Insights' popups are modal; non-modal would open behind them
        title = table.concat(lines, "\n"),
        title_align = "center",
        buttons = {
            { {
                text = _("Open book"),
                enabled = b.path ~= nil,
                callback = function()
                    UIManager:close(dlg)
                    openBook(b.path)
                end,
            } },
            { { text = _("Close"), callback = function() UIManager:close(dlg) end } },
        },
    }
    UIManager:show(dlg)
end

local function patchRecords(mod, deps)
    local Popup = type(mod) == "table" and mod.Popup
    local RecordsData = type(deps) == "table" and deps.RecordsData
    if type(Popup) ~= "table" or type(Popup._buildUI) ~= "function"
       or type(RecordsData) ~= "table" or type(RecordsData.load) ~= "function" then
        logger.warn(TAG, "records changed; record covers skipped")
        return
    end
    local orig = Popup._buildUI
    Popup._buildUI = function(self, ...)
        orig(self, ...)
        if not getSetting("records") then return end
        local ok, err = pcall(function()
            local center = self[1]
            local box = center and center[1]
            local content = box and box[1]
            -- exact layout check: the card's first row holds Reading Insights' own title row
            local first = type(content) == "table" and content[1]
            if type(first) ~= "table" or first[2] ~= self._title_row or not content.getSize then
                logger.warn(TAG, "records layout changed; record covers skipped")
                return
            end
            local width = content:getSize().w
            local tiles, list = recordTiles(RecordsData.load() or {}, width)
            if not tiles then return end
            self._ri_tiles = list
            table.insert(content, VerticalSpan:new{ width = Size.padding.large })
            table.insert(content, LineWidget:new{
                dimen = Geom:new{ w = width, h = Size.line.thin }, background = C_FAINT })
            table.insert(content, VerticalSpan:new{ width = Size.padding.large })
            table.insert(content, tiles)
            if content.resetLayout then content:resetLayout() end
        end)
        if not ok then logger.warn(TAG, "record covers failed:", err) end
    end

    -- Records closes on any tap; a tap on one of our covers shows that book instead.
    -- The dialog goes on top of Records, which stays open behind it.
    if type(Popup.onTap) == "function" then
        local orig_tap = Popup.onTap
        Popup.onTap = function(self, arg, ges_ev, ...)
            if getSetting("records") and ges_ev and ges_ev.pos and self._ri_tiles then
                local x, y = ges_ev.pos.x, ges_ev.pos.y
                for _i, tile in ipairs(self._ri_tiles) do
                    local d = tile.frame and tile.frame.dimen
                    if d and d.x and x >= d.x and x <= d.x + d.w and y >= d.y and y <= d.y + d.h then
                        local ok, err = pcall(showRecordBook, tile)
                        if not ok then logger.warn(TAG, "record book dialog failed:", err) end
                        return true
                    end
                end
            end
            return orig_tap(self, arg, ges_ev, ...)
        end
    end
end


-- =============================================================================================
-- 4. KOReader's built-in Statistics calendar view (module table patch)
-- =============================================================================================
local function booksByIds(ids)
    local list = {}
    for id in pairs(ids) do list[#list + 1] = tostring(math.floor(id)) end
    local books = {}
    if #list == 0 then return books end
    local res = dbQuery("SELECT id, title, authors, md5 FROM book WHERE id IN (" .. table.concat(list, ",") .. ")")
    for i = 1, nrows(res) do
        local id = tonumber(res[1][i])
        if id then books[id] = { id = id, title = res[2][i], authors = res[3][i], md5 = res[4][i] } end
    end
    resolvePaths(books)
    return books
end

local function coverizeStatsCalendar(view)
    local y, m = tostring(view.cur_month or ""):match("^(%d+)-(%d+)")
    y, m = tonumber(y), tonumber(m)
    if not y or type(view.weeks) ~= "table" then return end
    local days = loadMonth(y, m) -- durations for the badges
    local ids = {}
    for _w, week in ipairs(view.weeks) do
        for _d, calday in ipairs(week.calday_widgets or {}) do
            for _b, rb in ipairs(calday.read_books or {}) do
                if rb.id then ids[rb.id] = true end
            end
        end
    end
    local books = booksByIds(ids)
    local today = tonumber(os.date("%d"))
    local this_month = os.date("%Y-%m") == view.cur_month
    for _w, week in ipairs(view.weeks) do
        local dc = week.day_container
        -- exact layout check: KOReader's week is LeftContainer > OverlapGroup > day_container
        local wrap = week[1]
        local overlaps = type(wrap) == "table" and wrap[1]
        if not (type(overlaps) == "table" and overlaps[1] == dc) then
            logger.warn(TAG, "Statistics calendar layout changed; covers skipped")
            return
        end
        if dc and week.dimen then
            local group = OverlapGroup:new{ dimen = week.dimen:copy(), dc }
            local border = week.day_border or 0
            local span_h = week.span_height or S(30)
            -- Covers run from just under the day number to the bottom of the cell,
            -- over the hourly histogram (it still peeks out either side).
            local top_y = math.floor(span_h * 0.8)
            local inner = S(2)
            for col, calday in ipairs(week.calday_widgets or {}) do
                local rb = calday.read_books
                if not calday.filler and rb and #rb > 0 then
                    local cw = week.day_width - 2 * (border + inner)
                    local ch = week.height - top_y - 2 * border - inner
                    if cw > S(20) and ch > S(20) then
                        local list = {}
                        for _b, b in ipairs(rb) do
                            if b.id then list[#list + 1] = { id = b.id } end
                        end
                        local info = { dur = days[calday.daynum] and days[calday.daynum].dur or 0, list = list }
                        local cell = coverCell(info, books, cw, ch,
                            this_month and calday.daynum == today, true)
                        cell.overlap_offset = {
                            (col - 1) * (week.day_width + (week.day_padding or 0)) + border + inner,
                            border + top_y,
                        }
                        table.insert(group, cell)
                    end
                    if calday.nb_not_shown_w and calday.nb_not_shown_w.setText then
                        calday.nb_not_shown_w:setText("") -- the covers show their own +N
                    end
                end
            end
            week[1] = LeftContainer:new{ dimen = week.dimen:copy(), group }
        end
    end
    flushExtraction()
end

local function patchStatsCalendar(CalendarView)
    if type(CalendarView) ~= "table" or type(CalendarView._populateItems) ~= "function" then
        logger.warn(TAG, "Statistics calendar changed; covers skipped")
        return
    end
    if CalendarView._ri_tweaks_patched then return end
    CalendarView._ri_tweaks_patched = true
    Hook.caps.stats_calendar = true
    local orig = CalendarView._populateItems
    CalendarView._populateItems = function(self, ...)
        -- KOReader always sizes for 6 weeks; most months need 5, so with covers on,
        -- give the unused row's height to the real weeks.
        pcall(function()
            if type(self.week_height) ~= "number" then return end
            self._ri_week_h0 = self._ri_week_h0 or self.week_height
            local h0 = self._ri_week_h0
            local y, m = tostring(self.cur_month or ""):match("^(%d+)-(%d+)")
            y, m = tonumber(y), tonumber(m)
            if not getSetting("stats_calendar") or not y then
                self.week_height = h0
                return
            end
            local first = os.date("*t", os.time{ year = y, month = m, day = 1, hour = 12 }).wday
            local dim = os.date("*t", os.time{ year = y, month = m + 1, day = 0, hour = 12 }).day
            local lead = (first - (self.start_day_of_week or 1) + 7) % 7
            local weeks = math.ceil((lead + dim) / 7)
            local inner = self.inner_padding or 0
            self.week_height = weeks < 6 and math.floor((6 * h0 + (6 - weeks) * inner) / weeks) or h0
        end)
        local r = orig(self, ...)
        if getSetting("stats_calendar") then
            local ok, err = pcall(coverizeStatsCalendar, self)
            if not ok then logger.warn(TAG, "Statistics calendar covers failed:", err) end
        end
        return r
    end
end

-- =============================================================================================
-- Loader hook
-- =============================================================================================
local HK = 'package.loaded["' .. HOOK_NAME .. '"]'

-- Source edits. Each is optional and independent; `cap` records which applied.
-- Insertions go on the anchor's own line so Reading Insights' line numbers don't shift.
local EDITS = {
    ["book_calendar_view.lua"] = {
        {
            cap = "book_header",
            requires = "local function buildBookCalendarHeader(",
            requires2 = "local BookCalendarPopup = InputContainer:extend{",
            before = "\nfunction M.show(opts)",
            insert = "do local H = " .. HK .. "; if H and H.bookCal then " ..
                "BookCalendarPopup._rebuild, buildBookCalendarHeader = " ..
                "H.bookCal(BookCalendarPopup._rebuild, buildBookCalendarHeader) end end ",
        },
    },
}

local POST = {
    ["heatmap_view.lua"] = patchHeatmap,
    ["records_view.lua"] = patchRecords,
}

local function countOf(s, needle)
    local n, i = 0, 1
    while true do
        local a, b = s:find(needle, i, true)
        if not a then return n end
        n, i = n + 1, b + 1
    end
end

local function loadEdited(path, edits)
    local f = io.open(path, "rb")
    if not f then return nil end
    local src = f:read("*a")
    f:close()
    local applied = 0
    for _i, e in ipairs(edits) do
        if e.detect then Hook.caps[e.cap] = src:find(e.detect, 1, true) and true or nil end
        local ok_req = (not e.requires or src:find(e.requires, 1, true))
            and (not e.requires2 or src:find(e.requires2, 1, true))
        if e.detect then -- luacheck: ignore 542
            -- detection only, no edit
        elseif e.before then
            local at = ok_req and countOf(src, e.before) == 1 and src:find(e.before, 1, true)
            local req_at = e.requires and src:find(e.requires, 1, true)
            if at and (not req_at or req_at < at) then
                src = src:sub(1, at) .. e.insert .. src:sub(at + 1)
                Hook.caps[e.cap] = true
                applied = applied + 1
            else
                logger.warn(TAG, "Reading Insights changed;", e.cap, "skipped")
            end
        elseif e.replace then
            if countOf(src, e.replace) == 1 then
                local a, b = src:find(e.replace, 1, true)
                src = src:sub(1, a - 1) .. e.with .. src:sub(b + 1)
                Hook.caps[e.cap] = true
                applied = applied + 1
            else
                logger.warn(TAG, "Reading Insights changed;", e.cap, "skipped")
            end
        end
    end
    if applied == 0 then return nil end
    local chunk, err = loadstring(src, "@" .. path)
    if not chunk then
        for _i, e in ipairs(edits) do if not e.detect then Hook.caps[e.cap] = nil end end
        logger.warn(TAG, "edit failed, stock file used:", err)
        return nil
    end
    return chunk
end

local orig_loadfile = loadfile
_G.loadfile = function(path, ...)
    if type(path) == "string" and path:find("readinginsights%.koplugin/views/") then
        local name = path:match("([^/]+)$")
        if EDITS[name] then
            local ok, chunk = pcall(loadEdited, path, EDITS[name])
            if ok and chunk then return chunk end
            if not ok then logger.warn(TAG, "edit error, stock file used:", chunk) end
        elseif POST[name] then
            local chunk, err = orig_loadfile(path, ...)
            if not chunk then return chunk, err end
            return function(deps, ...)
                local mod = chunk(deps, ...)
                local ok, perr = pcall(POST[name], mod, deps)
                if not ok then logger.warn(TAG, "patch error for", name, perr) end
                return mod
            end
        end
    end
    return orig_loadfile(path, ...)
end

local ok_up, userpatch = pcall(require, "userpatch")
if not ok_up or type(userpatch) ~= "table" or type(userpatch.registerPatchPluginFunc) ~= "function" then
    logger.warn(TAG, "userpatch unavailable; Statistics calendar covers skipped")
else
-- Statistics calendar: patched when KOReader's Statistics plugin loads.
userpatch.registerPatchPluginFunc("statistics", function()
    -- plugin folders are on package.path by now
    local ok, CalendarView = pcall(require, "calendarview")
    if ok then patchStatsCalendar(CalendarView) else logger.warn(TAG, "calendarview not found") end
end)
end

-- =============================================================================================
-- Menu
-- =============================================================================================
local function toggle(text, key, depends)
    return {
        text = text,
        checked_func = function() return getSetting(key) end,
        enabled_func = depends and function() return getSetting(depends) end or nil,
        keep_menu_open = true,
        callback = function() setSetting(key, not getSetting(key)) end,
    }
end

local function menuItem()
    return {
        text = _("Reading Insights Tweaks"),
        sub_item_table = {
            toggle(_("Book Calendar: Cover Header"), "book_header"),
            toggle(_("Heatmap: Shade By Daily Goal"), "heatmap_goal"),
            toggle(_("Records: Book Covers"), "records"),
            toggle(_("Statistics Calendar: Book Covers"), "stats_calendar"),
            toggle(_("Close Reading Insights On Sleep"), "close_on_sleep"),
            {
                text_func = function() return T(_("Daily Goal: %1"), fmtDuration(goalSecs())) end,
                keep_menu_open = true,
                callback = function(touchmenu_instance)
                    UIManager:show(SpinWidget:new{
                        title_text = _("Daily reading goal (minutes)"),
                        value = getSetting("goal_min"),
                        value_min = 5, value_max = 600, value_step = 5, value_hold_step = 30,
                        default_value = DEFAULTS.goal_min,
                        callback = function(spin)
                            setSetting("goal_min", spin.value)
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                        end,
                    })
                end,
            },
        },
    }
end

-- Tweaks & Mods (2-tweaks-menu.lua) registry
local TM = package.loaded.tweaks_mods or {}
package.loaded.tweaks_mods = TM
TM.entries = TM.entries or {}
TM.entries.ri_tweaks = { text = "Reading Insights Tweaks", build = function() return menuItem() end }

-- Fallback: Tools > Reading Insights Tweaks when Tweaks & Mods isn't installed
local function hookMenu(mod)
    local ok, Menu = pcall(require, mod)
    if not ok or type(Menu) ~= "table" or type(Menu.setUpdateItemTable) ~= "function" then return end
    local orig = Menu.setUpdateItemTable
    Menu.setUpdateItemTable = function(self, ...)
        if self.menu_items and not TM.active then
            local item = menuItem()
            item.sorting_hint = "tools"
            self.menu_items.ri_tweaks = item
        end
        return orig(self, ...)
    end
end
hookMenu("apps/filemanager/filemanagermenu")
hookMenu("apps/reader/modules/readermenu")

-- ---- Reading Insights' windows: Simple UI's home, and closing on sleep -------------------
-- Windows Reading Insights (or this patch) opens are noted as they open:
--  * Simple UI closes its home screen when a full-screen window opens over it,
--    and brings it back when that window closes, but only if nothing else is
--    open then. Reading Insights opens its full-screen pages (a day's books,
--    Achievements, a year's books) from its own popup, which is still open
--    when the page closes: home wasn't brought back, and closing the popup
--    left the stock library. Simple UI skips that for windows marked
--    _sui_keep_homescreen, so Reading Insights' full-screen windows get the
--    mark (2.0.1).
--  * Close On Sleep: when the device sleeps, every one of them still open is
--    closed, so waking shows home or the book (2.1.0).
-- Installed on the first UI tick, after Simple UI has wrapped UIManager.show.
local ri_windows = setmetatable({}, { __mode = "k" }) -- open windows Reading Insights opened
local in_suspend = false

local function fromReadingInsights()
    for level = 3, 8 do -- the caller, past a few other wrappers of UIManager.show
        local info = debug.getinfo(level, "S")
        if not info then return false end
        local src = info.source or ""
        if src:find("readinginsights.koplugin", 1, true) or src:find("readinginsights-tweaks.lua", 1, true) then
            return true
        end
    end
    return false
end

UIManager:nextTick(function()
    -- Simple UI 2.7 (infra/sui_patches) and 3.0 (also infra/sui_window_hooks)
    -- both honour the mark.
    local sui = package.loaded["infra/sui_patches"] or package.loaded["infra/sui_window_hooks"]
    local orig_show = UIManager.show
    UIManager.show = function(self, widget, ...)
        -- not Reading Insights' own sleep screen, shown while it handles sleep
        if type(widget) == "table" and not in_suspend and not Device.screen_saver_mode
                and widget.name ~= "homescreen" and fromReadingInsights() then
            ri_windows[widget] = true
            if sui and widget.covers_fullscreen and not widget._sui_keep_homescreen then
                widget._sui_keep_homescreen = true
            end
        end
        return orig_show(self, widget, ...)
    end
end)

-- Closes every window Reading Insights opened that is still open, top first.
local function closeRIWindows()
    local open = {}
    local stack = UIManager._window_stack or {}
    for i = #stack, 1, -1 do
        local w = stack[i].widget
        if w and ri_windows[w] then open[#open + 1] = w end
    end
    for _i, w in ipairs(open) do
        ri_windows[w] = nil
        pcall(UIManager.close, UIManager, w)
    end
    if #open > 0 then logger.info(TAG, "closed", #open, "Reading Insights window(s) on sleep") end
end

if ok_up and type(userpatch) == "table" and type(userpatch.registerPatchPluginFunc) == "function" then
    userpatch.registerPatchPluginFunc("readinginsights", function(plugin)
        if plugin._ri_tweaks_sleep then return end
        plugin._ri_tweaks_sleep = true
        local orig = plugin.onSuspend -- a function or KOReader's callable handler table
        plugin.onSuspend = function(self, ...)
            if getSetting("close_on_sleep") then pcall(closeRIWindows) end
            if not orig then return end
            in_suspend = true
            local r = { pcall(orig, self, ...) }
            in_suspend = false
            if not r[1] then error(r[2], 0) end
            return unpack(r, 2)
        end
    end)
end
