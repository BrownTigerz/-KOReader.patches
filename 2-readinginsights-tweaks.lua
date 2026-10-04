--[[
    2-readinginsights-tweaks.lua
    Version: 1.1.0
    KOReader user patch: visual toggles for Reading Insights
    (peterboda236/readinginsights.koplugin). Each one is on its own toggle.

      1. Streak calendar covers   each read day shows that day's top book cover,
                                  a time badge shaded by your daily goal (black =
                                  goal met), a second cover stacked behind for
                                  2+ books (+N for 3+).
      2. Taller cover cells       2:3 cells so covers fill them; the popup shrinks
                                  to fit the screen (Reading Insights' own
                                  landscape fit, also run in portrait).
      3. Tap a day                in the streak calendar: that day's books, time
                                  and pages; tap a book to open it.
      4. Book calendar header     cover, title and author under the month title
                                  of the Book progress calendar.
      5. Heatmap goal shading     calendar heatmap shaded against your daily goal
                                  (darkest = goal met) instead of your busiest day.
      6. Record covers            the books behind your records (most time in a
                                  day, most pages in a day, best streak).
      7. Sleep screen card        "Now reading" card (cover, progress, today vs
                                  goal) over Reading Insights' sleep screen.
      8. Statistics calendar      KOReader's built-in Statistics calendar view:
                                  covers instead of title bars, same time badge.
                                  Tap a day still opens its day view.

    How: Reading Insights loads its files through the global loadfile. This
    patch wraps loadfile for four of its view files. Two get small additions to
    their source (routing one function through here); the other two are patched
    on the module table they return. The sleep card hooks the plugin's
    suspend/resume. Toggles are checked every time something is drawn, so turning
    one off gives you the stock view right away.

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

    Cost: nothing runs in the background. Work happens only when you open one of
    these views (a few small read-only queries + covers already cached by
    CoverBrowser), and once at suspend for the sleep card. Scaled covers are kept
    for the session (max 150). The only timer is a one-shot 30s retry window
    after a missing cover was sent for extraction.

    Versioning
      1.0.x  fixes, e.g. adapting to a Reading Insights or KOReader change
      1.x.0  new features or toggles
      2.0.0  something that changes how existing toggles or saved settings work

    Changelog
      1.0.0  2026-10-02  First release.
      1.1.0  2026-10-03  Record covers are tappable (book details, open book). Menu
                         renamed to Reading Insights Tweaks.
]]

local Blitbuffer = require("ffi/blitbuffer")
local BottomContainer = require("ui/widget/container/bottomcontainer")
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
local InfoMessage = require("ui/widget/infomessage")
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
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local util = require("util")
local T = require("ffi/util").template
local _ = require("gettext")
local Screen = Device.screen

local PATCH_VERSION = "1.1.0" -- the only number to change when updating
local TAG = "RI tweaks:"
logger.info(TAG, "version", PATCH_VERSION, "loaded")
local HOOK_NAME = "ri_tweaks_hook"

-- ---- Settings ------------------------------------------------------------------------------
local SETTINGS_KEY = "ri_cover_calendar"
local DEFAULTS = {
    enabled = true,       -- 1. streak calendar covers
    tall = true,          -- 2. taller cover cells
    day_tap = true,       -- 3. tap a day
    book_header = true,   -- 4. book calendar header
    heatmap_goal = true,  -- 5. heatmap goal shading
    records = true,       -- 6. record covers
    sleep_card = true,    -- 7. sleep screen card
    stats_calendar = true, -- 8. built-in Statistics calendar covers
    goal_min = 30,
}

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
local C_READ  = Blitbuffer.Color8(0xCC)
local C_MUTED = Blitbuffer.Color8(0x66)
local C_FAINT = Blitbuffer.Color8(0xAA)
-- goal levels: 1 none, 2 <1/3, 3 <2/3, 4 <goal, 5 goal met
local LEVEL_BG = {
    Blitbuffer.Color8(0xFF), Blitbuffer.Color8(0xDD), Blitbuffer.Color8(0xAA),
    Blitbuffer.Color8(0x66), Blitbuffer.Color8(0x11),
}
local WEEKDAY_SHORT = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
local TALL_RATIO = 1.45

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

local function todaySecs()
    local t = os.date("*t")
    local t0 = os.time{ year = t.year, month = t.month, day = t.day, hour = 0 }
    local res = dbQuery("SELECT SUM(duration) FROM page_stat_data WHERE start_time >= " .. t0)
    return nrows(res) > 0 and (tonumber(res[1][1]) or 0) or 0
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
local function getScaledCover(path, bw, bh, no_queue)
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
        if not no_queue and (queued[path] or 0) < 2 and not queued_now[path]
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

local function bookInfo(path)
    local BIM = getBIM()
    if not BIM or not path then return nil end
    local ok, bi = pcall(BIM.getBookInfo, BIM, path, false)
    return ok and bi or nil
end

-- A cover fitting in bw x bh, or a title placeholder of exactly that size.
local function coverWidget(book, bw, bh, border, no_queue)
    border = border or Size.border.thin
    if book and book.path then
        local bb, owned = getScaledCover(book.path, bw - 2 * border, bh - 2 * border, no_queue)
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
-- 1-3. Streak calendar
-- =============================================================================================
local Hook = { caps = {}, day_cells = {} }
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

local function numberCell(text, cw, ch, fill, fg, bold)
    return OverlapGroup:new{
        dimen = Geom:new{ w = cw, h = ch },
        LineWidget:new{ dimen = Geom:new{ w = cw, h = ch }, background = fill },
        CenterContainer:new{
            dimen = Geom:new{ w = cw, h = ch },
            TextWidget:new{ text = text, face = Font:getFace("cfont", 14), fgcolor = fg, bold = bold },
        },
    }
end

-- Same shape as Reading Insights' grid: weekday header, then a fixed six-week grid.
local function buildCoverGrid(year, month, read_set, fonts, cell, week_start_wd)
    local days, books = loadMonth(year, month)
    resolvePaths(books)
    read_set = read_set or {}
    local ch = (Hook.caps.tall and getSetting("tall")) and math.floor(cell * TALL_RATIO) or cell
    local today_str = os.date("%Y-%m-%d")
    local grid_w = 7 * cell
    local small = (type(fonts) == "table" and fonts.small) or Font:getFace("cfont", 12)
    local grid = VerticalGroup:new{ align = "center" }
    local cells = {}

    local header = HorizontalGroup:new{}
    for i = 0, 6 do
        local wd = ((week_start_wd + i) % 7) + 1
        local tw = TextWidget:new{ text = _(WEEKDAY_SHORT[wd]), face = small, fgcolor = C_MUTED }
        table.insert(header, CenterContainer:new{ dimen = Geom:new{ w = cell, h = tw:getSize().h }, tw })
    end
    table.insert(grid, header)
    table.insert(grid, whiteBar(grid_w, Size.padding.small))

    local first_wd = tonumber(os.date("%w", os.time{ year = year, month = month, day = 1, hour = 12 }))
    local lead = (first_wd - week_start_wd + 7) % 7
    local dim = tonumber(os.date("%d", os.time{ year = year, month = month + 1, day = 0, hour = 12 }))
    for r = 0, 5 do
        if r > 0 then table.insert(grid, whiteBar(grid_w, S(6))) end
        local row = HorizontalGroup:new{}
        for col = 0, 6 do
            local cd = 1 - lead + r * 7 + col
            local t = os.time{ year = year, month = month, day = cd, hour = 12 }
            local day_str = os.date("%Y-%m-%d", t)
            local num = tostring(tonumber(day_str:sub(9, 10)))
            local is_today = day_str == today_str
            local w
            if cd >= 1 and cd <= dim then
                if days[cd] then
                    w = coverCell(days[cd], books, cell, ch, is_today)
                elseif read_set[day_str] then
                    w = numberCell(num, cell, ch, C_READ, C_BLACK, is_today)
                else
                    w = numberCell(num, cell, ch, C_WHITE, day_str > today_str and C_FAINT or C_BLACK, is_today)
                end
                local frame = FrameContainer:new{ bordersize = 0, padding = 0, margin = 0, w }
                table.insert(cells, { frame = frame, t = t, info = days[cd], books = books })
                w = frame
            else
                w = numberCell(num, cell, ch, read_set[day_str] and C_CARD or C_WHITE, C_FAINT, false)
            end
            table.insert(row, w)
        end
        table.insert(grid, row)
    end
    Hook.day_cells = cells
    flushExtraction()
    return grid
end

function Hook.wrap(orig)
    return function(year, month, read_set, fonts, cell, week_start_wd, show_week, ...)
        Hook.day_cells = {}
        if getSetting("enabled") and not show_week and type(cell) == "number" then
            local ok, grid = pcall(buildCoverGrid, year, month, read_set, fonts, cell, week_start_wd or 1)
            if ok and grid then return grid end
            logger.warn(TAG, "cover grid failed, using stock grid:", grid)
        end
        return orig(year, month, read_set, fonts, cell, week_start_wd, show_week, ...)
    end
end

-- Used by the portrait-fit edit: only shrink when our tall cells are on screen.
function Hook.tall()
    return getSetting("enabled") and getSetting("tall") and true or false
end

local function showDayDialog(cell)
    local date_str = os.date("%A, %B ", cell.t) .. tonumber(os.date("%d", cell.t))
    local info = cell.info
    if not info then
        UIManager:show(InfoMessage:new{ text = date_str .. "\n" .. _("No reading this day."), timeout = 2 })
        return
    end
    local dlg
    local buttons = {}
    for _i, e in ipairs(info.list) do
        local b = cell.books[e.id] or {}
        local path = b.path
        table.insert(buttons, { {
            text = (b.title or "?") .. " · " .. fmtDuration(e.dur) .. " · " .. e.pages .. "p",
            enabled = path ~= nil,
            callback = function()
                UIManager:close(dlg)
                openBook(path)
            end,
        } })
    end
    table.insert(buttons, { { text = _("Close"), callback = function() UIManager:close(dlg) end } })
    local goal_note = goalLevel(info.dur) == 5 and (" · " .. _("goal met")) or ""
    dlg = ButtonDialog:new{
        title = date_str .. "\n" .. fmtDuration(info.dur) .. " · " .. info.pages .. " " .. _("pages") .. goal_note,
        title_align = "center",
        buttons = buttons,
    }
    UIManager:show(dlg)
end

function Hook.wrapTap(orig)
    return function(self, arg, ges_ev, ...)
        if ges_ev and ges_ev.pos and getSetting("enabled") and getSetting("day_tap") then
            local x, y = ges_ev.pos.x, ges_ev.pos.y
            for _i, c in ipairs(Hook.day_cells or {}) do
                local d = c.frame.dimen
                if d and d.x and x >= d.x and x <= d.x + d.w and y >= d.y and y <= d.y + d.h then
                    local ok, err = pcall(showDayDialog, c)
                    if not ok then logger.warn(TAG, "day dialog failed", err) end
                    return true
                end
            end
        end
        return orig(self, arg, ges_ev, ...)
    end
end

-- =============================================================================================
-- 4. Book progress calendar header
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
-- 5. Heatmap goal shading (module table patch)
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
-- 6. Record covers (module table patch)
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
            if type(content) ~= "table" or not content.getSize then return end
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
-- 8. KOReader's built-in Statistics calendar view (module table patch)
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
    ["streak_calendar_view.lua"] = {
        {
            cap = "grid",
            requires = "local function buildStreakMonthGrid(",
            before = "\nlocal function streakMonthList(",
            insert = "do local H = " .. HK .. "; if H and H.wrap then " ..
                "buildStreakMonthGrid = H.wrap(buildStreakMonthGrid) end end ",
        },
        {
            cap = "tap",
            requires = "local StreakDatePopup = InputContainer:extend{",
            before = "\nlocal function showStreaksPopup(",
            insert = "do local H = " .. HK .. "; if H and H.wrapTap and StreakDatePopup.onTap then " ..
                "StreakDatePopup.onTap = H.wrapTap(StreakDatePopup.onTap) end end ",
        },
        {
            cap = "tall",
            replace = "    if UI.isLandscapeScreen() then\n        local target_h = math.floor(screen_h * 0.94)",
            with = "    if UI.isLandscapeScreen() or (" .. HK .. " and " .. HK .. ".tall()) then\n" ..
                "        local target_h = math.floor(screen_h * 0.94)",
        },
    },
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
        local ok_req = (not e.requires or src:find(e.requires, 1, true))
            and (not e.requires2 or src:find(e.requires2, 1, true))
        if e.before then
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
        for _i, e in ipairs(edits) do Hook.caps[e.cap] = nil end
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

-- =============================================================================================
-- 7. Sleep screen card (plugin suspend/resume)
-- =============================================================================================
local function currentBook(plugin)
    local ui = plugin and plugin.ui
    local path
    if ui and ui.document and ui.document.file then path = ui.document.file end
    if not path then path = G_reader_settings:readSetting("lastfile") end
    if not path or lfs.attributes(path, "mode") ~= "file" then return nil end
    local bi = bookInfo(path) or {}
    local title = bi.title
    if not title or title == "" then title = path:match("([^/]+)%.[^.]+$") or path end
    local percent
    if ui and ui.doc_settings and ui.document and ui.document.file == path then
        percent = ui.doc_settings:readSetting("percent_finished")
    else
        local ok, DocSettings = pcall(require, "docsettings")
        if ok and DocSettings.hasSidecarFile and DocSettings:hasSidecarFile(path) then
            local ok2, ds = pcall(DocSettings.open, DocSettings, path)
            if ok2 and ds then percent = ds:readSetting("percent_finished") end
        end
    end
    return { path = path, title = title, authors = bi.authors, percent = percent }
end

local function buildSleepCard(plugin)
    local book = currentBook(plugin)
    if not book then return nil end
    local sw = Screen:getWidth()
    local card_w = math.floor(sw * 0.9)
    local pad = S(14)
    local cover_h = S(120)
    local cover_w = math.floor(cover_h * 2 / 3)
    local cover = coverWidget(book, cover_w, cover_h, nil, true)
    local text_w = card_w - 2 * pad - 2 * Size.border.window - cover:getSize().w - S(14)

    local secs = todaySecs()
    local goal = goalSecs()
    local lines = VerticalGroup:new{ align = "left" }
    table.insert(lines, TextWidget:new{ text = _("Now reading"), face = Font:getFace("cfont", 12), fgcolor = C_MUTED })
    table.insert(lines, TextBoxWidget:new{
        text = book.title, face = Font:getFace("tfont", 18), width = text_w,
        height = S(52), height_adjust = true, height_overflow_show_ellipsis = true,
    })
    if book.authors and book.authors ~= "" then
        table.insert(lines, TextWidget:new{ text = book.authors, face = Font:getFace("cfont", 13),
            fgcolor = C_MUTED, max_width = text_w })
    end
    table.insert(lines, VerticalSpan:new{ width = S(8) })

    -- progress bar + today vs goal
    local bar_h = S(6)
    local pct = tonumber(book.percent)
    if pct then
        local fill = math.max(0, math.min(text_w, math.floor(text_w * pct)))
        table.insert(lines, OverlapGroup:new{
            dimen = Geom:new{ w = text_w, h = bar_h },
            LineWidget:new{ dimen = Geom:new{ w = text_w, h = bar_h }, background = C_CARD },
            LineWidget:new{ dimen = Geom:new{ w = math.max(1, fill), h = bar_h }, background = C_BLACK },
        })
        table.insert(lines, VerticalSpan:new{ width = S(4) })
    end
    local status = (pct and (math.floor(pct * 100 + 0.5) .. "% · ") or "")
        .. T(_("Today %1 of %2"), fmtDuration(secs), fmtDuration(goal))
        .. (secs >= goal and (" · " .. _("goal met")) or "")
    table.insert(lines, TextWidget:new{ text = status, face = Font:getFace("cfont", 13),
        bold = secs >= goal, max_width = text_w })

    return FrameContainer:new{
        width = card_w, background = C_WHITE, bordersize = Size.border.window,
        radius = Size.radius.window, padding = pad, margin = 0,
        HorizontalGroup:new{ align = "center", cover, HorizontalSpan:new{ width = S(14) }, lines },
    }
end

local SleepCard = WidgetContainer:extend{ name = "ri_sleep_card" }

function SleepCard:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    self[1] = BottomContainer:new{
        dimen = Geom:new{ w = self.dimen.w, h = self.dimen.h - S(28) },
        CenterContainer:new{
            dimen = Geom:new{ w = self.dimen.w, h = self.card:getSize().h },
            self.card,
        },
    }
end

local ok_up, userpatch = pcall(require, "userpatch")
if not ok_up or type(userpatch) ~= "table" or type(userpatch.registerPatchPluginFunc) ~= "function" then
    logger.warn(TAG, "userpatch unavailable; sleep card skipped")
else
userpatch.registerPatchPluginFunc("statistics", function(plugin)
    -- plugin folders are on package.path by now
    local ok, CalendarView = pcall(require, "calendarview")
    if ok then patchStatsCalendar(CalendarView) else logger.warn(TAG, "calendarview not found") end
end)
userpatch.registerPatchPluginFunc("readinginsights", function(plugin)
    if plugin._ri_tweaks_patched then return end -- runs on every plugin instance creation
    if type(plugin.onSuspend) ~= "function" or type(plugin.onResume) ~= "function" then
        logger.warn(TAG, "plugin changed; sleep card skipped")
        return
    end
    plugin._ri_tweaks_patched = true
    local orig_suspend, orig_resume = plugin.onSuspend, plugin.onResume
    plugin.onSuspend = function(self, ...)
        -- flush the open book's pending stats so today's time is current
        if getSetting("sleep_card") and self.ui and self.ui.statistics
           and type(self.ui.statistics.insertDB) == "function" then
            pcall(self.ui.statistics.insertDB, self.ui.statistics)
        end
        local r = orig_suspend(self, ...)
        if getSetting("sleep_card") and self._screensaver_widget and not self._ri_sleep_card then
            local ok, card = pcall(buildSleepCard, self)
            if ok and card then
                self._ri_sleep_card = SleepCard:new{ card = card }
                UIManager:show(self._ri_sleep_card)
            elseif not ok then
                logger.warn(TAG, "sleep card failed:", card)
            end
        end
        return r
    end
    plugin.onResume = function(self, ...)
        if self._ri_sleep_card then
            UIManager:close(self._ri_sleep_card)
            self._ri_sleep_card = nil
        end
        return orig_resume(self, ...)
    end
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
            toggle(_("Streak calendar: book covers"), "enabled"),
            toggle(_("Streak calendar: taller cover cells"), "tall", "enabled"),
            toggle(_("Streak calendar: tap a day for details"), "day_tap", "enabled"),
            toggle(_("Book calendar: cover header"), "book_header"),
            toggle(_("Heatmap: shade by daily goal"), "heatmap_goal"),
            toggle(_("Records: book covers"), "records"),
            toggle(_("Sleep screen: now reading card"), "sleep_card"),
            toggle(_("Statistics calendar: book covers"), "stats_calendar"),
            {
                text_func = function() return T(_("Daily goal: %1"), fmtDuration(goalSecs())) end,
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
