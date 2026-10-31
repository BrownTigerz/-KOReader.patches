-- SimpleUI Side Panel v1.0.20
-- Tools → SimpleUI Side Panel
-- Full edge-swipe panel for SimpleUI (TBR, collections, new, history, BookOrbit).
--
-- 1.0.20 Clean-up: debugging trace lines removed from crash.log (BookOrbit
--        fetches, detail opening, swipe hook). Only the version line stays.
-- 1.0.19 Header fix: long view titles ("Book Club Anthology", "BookOrbit
--        Newly Added") were still cut after a word or two. The two-line box
--        was sized from a plain text line, which is shorter than a text-box
--        line, so it only held one. It's now sized by the text box itself.
-- 1.0.18 Shares its saved BookOrbit lists with Reading Log Tweaks (1.1.6+),
--        so BookOrbit collections can be picked there (the Book Club card
--        and any card with a collection). Saved lists only: Reading Log
--        never waits on the BookOrbit server.
-- 1.0.17 Header: the whole view title shows ("Book Club Anthology",
--        "BookOrbit Newly Added"): a title that nearly fits steps down to
--        20 to stay on one line; a longer one wraps onto two lines at full
--        size instead of being cut after a few words.
-- 1.0.16 Speed: at most one BookOrbit refresh per panel open. Swiping
--        through BookOrbit views ran one refresh per view (0.75-0.9 s each,
--        the panel frozen meanwhile: four in six seconds in the log). Now
--        only the first view you stop on (0.4 s) is refreshed; the others
--        show their saved list. Saved lists count as fresh for 30 minutes
--        (was 10).
-- 1.0.15 Speed: BookOrbit lists no longer block the swipe. Checking which
--        views have books (every open and every swipe) reads only the
--        saved lists, never BookOrbit's server; the list on show comes from
--        the saved copy straight away and, when it's over 10 minutes old
--        with Wi-Fi on, is refreshed once right after the panel is up, then
--        redrawn in place. Each refresh is one request (up to 100 books)
--        instead of one per page. Was: a swipe asked the server for every
--        picked BookOrbit collection older than 45 s, 0.5-0.6 s each, so
--        swipes took up to 1.8 s.

local VERSION = "1.0.20"
local TAG = "simpleui-sidepanel " .. VERSION .. ":"
local SETTINGS_KEY = "simpleui_sidepanel"
local OLD_KEY = "simpleui_mod"

local logger = require("logger")
local _ = require("gettext")
local Screen = require("device").screen
local G_reader_settings = rawget(_G, "G_reader_settings")

local function loadConfig()
    local c = {
        tbr_panel = "right", tbr_edge = "narrow", tbr_panel_view = "tbr",
        tbr_panel_colls = {}, tbr_panel_show_tbr = true, tbr_panel_show_new = true,
        bo_colls = {}, bo_show_new = false, history_source = "device",
    }
    local saved = G_reader_settings and G_reader_settings:readSetting(SETTINGS_KEY)
    if type(saved) ~= "table" and G_reader_settings then
        local old = G_reader_settings:readSetting(OLD_KEY)
        if type(old) == "table" then
            saved = {}
            for _, k in ipairs({"tbr_panel","tbr_edge","tbr_panel_view","tbr_panel_colls","tbr_panel_show_tbr","tbr_panel_show_new"}) do
                if old[k] ~= nil then saved[k] = old[k] end
            end
            local bo = G_reader_settings:readSetting("simpleui_bo_panel")
            if type(bo) == "table" and type(bo.colls) == "table" then saved.bo_colls = bo.colls end
        end
    end
    if type(saved) == "table" then
        for k, v in pairs(saved) do if c[k] ~= nil then c[k] = v end end
    end
    if type(c.tbr_panel_colls) ~= "table" then c.tbr_panel_colls = {} end
    if type(c.bo_colls) ~= "table" then c.bo_colls = {} end
    return c
end

local cfg = loadConfig()

local function saveConfig()
    if not G_reader_settings then return end
    G_reader_settings:saveSetting(SETTINGS_KEY, {
        tbr_panel = cfg.tbr_panel, tbr_edge = cfg.tbr_edge, tbr_panel_view = cfg.tbr_panel_view,
        tbr_panel_colls = cfg.tbr_panel_colls, tbr_panel_show_tbr = cfg.tbr_panel_show_tbr,
        tbr_panel_show_new = cfg.tbr_panel_show_new, bo_colls = cfg.bo_colls, bo_show_new = cfg.bo_show_new,
        history_source = cfg.history_source,
    })
    if G_reader_settings.flush then pcall(G_reader_settings.flush, G_reader_settings) end
end

local function showSimpleUIHome()
    if not (G_reader_settings and G_reader_settings:readSetting("start_with") == "homescreen_simpleui") then return end
    local UIManager = require("ui/uimanager")
    if UIManager._exit_code ~= nil then return end
    local FM = package.loaded["apps/filemanager/filemanager"]
    local fm = type(FM) == "table" and FM.instance
    local plugin = type(fm) == "table" and (fm._simpleui_plugin or fm.simpleui)
    if type(plugin) == "table" and type(plugin._navigate) == "function" then
        pcall(plugin._navigate, plugin, "homescreen", plugin.ui or fm, nil, false)
    end
end

local empty_noted = {}
local panelNote
-- ---- To Be Read side panel --------------------------------------------------------
-- Swipe in from the right (or left) edge of SimpleUI home: a panel slides in
-- with the To Be Read list, the KOReader collection Bookshelf's "Add to To Be
-- Read" and SimpleUI's TBR module both use. 5 books, one per line (cover,
-- title, author); "Show all (N)" when there are more. Tap a book to open it,
-- hold it to remove it from the list. Tap outside or swipe it back to close.
-- SimpleUI hands horizontal swipes that start at a screen edge on to
-- KOReader's gestures (they never turn its pages); we take only the one from
-- the chosen edge, on the home screen. Built only when opened.
local TBR_COLL = "To Be Read"
local TBR_ROWS = 5
-- How far in from the edge a swipe may start: Wide is KOReader's own edge
-- zone (1/8 of the screen); Narrow and Edge Only leave more room for page
-- swipes and only open the panel from right at the edge.
local EDGE_RATIOS = { wide = 1 / 8, narrow = 1 / 14, edge = 1 / 24 }
local function edgeRatio() return EDGE_RATIOS[cfg.tbr_edge] or EDGE_RATIOS.narrow end

local function tbrList()
    local okm, TBR = pcall(require, "modules/module_tbr")
    if okm and type(TBR) == "table" and type(TBR.getTBRList) == "function" then
        local ok, list = pcall(TBR.getTBRList)
        if ok and type(list) == "table" then return list end
    end
    -- without SimpleUI's module: read the collection directly
    local okr, RC = pcall(require, "readcollection")
    local coll = okr and type(RC) == "table" and RC.coll and RC.coll[TBR_COLL]
    if type(coll) ~= "table" then return {} end
    local lfs = require("libs/libkoreader-lfs")
    local items = {}
    for _k, it in pairs(coll) do
        if type(it) == "table" and it.file and lfs.attributes(it.file, "mode") == "file" then items[#items + 1] = it end
    end
    table.sort(items, function(a, b) return (a.order or 0) < (b.order or 0) end)
    local fps = {}
    for i, it in ipairs(items) do fps[i] = it.file end
    return fps
end

local function tbrRemove(fp)
    local okm, TBR = pcall(require, "modules/module_tbr")
    if okm and type(TBR) == "table" and type(TBR.removeTBR) == "function" then
        return pcall(TBR.removeTBR, fp)
    end
    local okr, RC = pcall(require, "readcollection")
    if okr and type(RC) == "table" and type(RC.removeItem) == "function" then
        return pcall(RC.removeItem, RC, fp, TBR_COLL)
    end
end

local function newBooksList()
    -- Newly added books via SimpleUI's new_books source (by file date)
    local oks, Sources = pcall(require, "engines/sui_book_sources")
    if oks and type(Sources) == "table" and type(Sources.bind) == "function" then
        local okb, src = pcall(Sources.bind, "new_books")
        if okb and type(src) == "table" and type(src.getFileList) == "function" then
            local ok, list = pcall(src.getFileList)
            if ok and type(list) == "table" then return list end
        end
    end
    -- SimpleUI without book sources (2.7.5 release): same ranking as its
    -- New Books module gets from this patch
    local ok, fps = pcall(newestBooks)
    return (ok and type(fps) == "table") and fps or {}
end

local function historyList()
    -- Recently opened books from KOReader's reading history
    local okh, RH = pcall(require, "readhistory")
    local hist = okh and type(RH) == "table" and RH.hist
    if type(hist) ~= "table" then return {} end
    local lfs = require("libs/libkoreader-lfs")
    local fps, seen = {}, {}
    for i = 1, math.min(#hist, 30) do
        local fp = hist[i] and hist[i].file
        if type(fp) == "string" and not seen[fp] and lfs.attributes(fp, "mode") == "file" then
            seen[fp] = true
            fps[#fps + 1] = fp
        end
    end
    return fps
end

-- True when the BookOrbit plugin is present (BO-only settings are hidden otherwise)
local function bookOrbitInstalled()
    local lfs = require("libs/libkoreader-lfs")
    if lfs.attributes("plugins/bookorbit.koplugin/main.lua", "mode") == "file" then return true end
    if lfs.attributes("plugins/BookOrbit.koplugin/main.lua", "mode") == "file" then return true end
    local ok = pcall(require, "bookorbit_api")
    return ok
end

-- Other KOReader collections as panel views ("coll:<name>").
local function collList(name)
    local okr, RC = pcall(require, "readcollection")
    local coll = okr and type(RC) == "table" and RC.coll and RC.coll[name]
    if type(coll) ~= "table" then return {} end
    local lfs = require("libs/libkoreader-lfs")
    local items = {}
    for _k, it in pairs(coll) do
        if type(it) == "table" and it.file and lfs.attributes(it.file, "mode") == "file" then items[#items + 1] = it end
    end
    table.sort(items, function(a, b) return (a.order or 0) < (b.order or 0) end)
    local fps = {}
    for i, it in ipairs(items) do fps[i] = it.file end
    return fps
end

local function collRemove(fp, name)
    local okr, RC = pcall(require, "readcollection")
    if okr and type(RC) == "table" and type(RC.removeItem) == "function" then
        return pcall(RC.removeItem, RC, fp, name)
    end
end

-- All collection names except To Be Read (always in the panel), sorted.
local function allCollectionNames()
    local okr, RC = pcall(require, "readcollection")
    local names = {}
    if okr and type(RC) == "table" and type(RC.coll) == "table" then
        for name in pairs(RC.coll) do
            if type(name) == "string" and name ~= TBR_COLL then names[#names + 1] = name end
        end
    end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    return names
end

local function collLabel(name)
    if name == "favorites" then return _("Favorites") end
    return name
end

local function isCollPicked(name)
    for _i, n in ipairs(cfg.tbr_panel_colls or {}) do if n == name then return true end end
    return false
end

-- The swipe order: To Be Read, the picked collections that have books, Newly Added.
-- BookOrbit path helpers (defined above panel open; stubs filled after lists)
local boCollList, boNewList, boHistoryList, boLabel, isBoPicked, openBoInCatalog, openBoBookDetail, boPlugin
local onDeviceByBookId, liveBookPath, refreshCachedBooks
-- 1.0.15: bo_quick = only the saved lists (no server); bo_stale = the list on
-- show was served old, refresh it after the panel is up
local bo_quick, bo_stale, bo_refresh_task = false, nil, nil
-- 1.0.16: true once this panel open has run its one BookOrbit refresh
local bo_refreshed_open = false
local function boQuick(fn, ...)
    local was = bo_quick
    bo_quick = true
    local ok, res = pcall(fn, ...)
    bo_quick = was
    return ok and res or {}
end

local function panelViews()
    local views = {}
    if cfg.tbr_panel_show_tbr ~= false then views[#views + 1] = "tbr" end
    for _i, name in ipairs(cfg.tbr_panel_colls or {}) do
        if type(name) == "string" and #collList(name) > 0 then views[#views + 1] = "coll:" .. name end
    end
    for _i, e in ipairs(cfg.bo_colls or {}) do
        if type(e) == "table" and e.id and type(boCollList) == "function" and #boQuick(boCollList, e.id) > 0 then
            views[#views + 1] = "bo:" .. tostring(e.id)
        end
    end
    if cfg.bo_show_new and type(boNewList) == "function" then
        views[#views + 1] = "bo:new"
    end
    if cfg.tbr_panel_show_new ~= false then views[#views + 1] = "new" end
    if #views == 0 then views[1] = "tbr" end
    return views
end

-- Says why a picked collection isn't in the panel (no books yet). Once per
-- collection per KOReader start, so it doesn't nag on every open.
local empty_noted = {}
local panelNote   -- shows a short note (defined after the shared note helper)
local function noteEmptyCollections(force_name)
    local empty = {}
    for _i, name in ipairs(cfg.tbr_panel_colls or {}) do
        if (force_name == name or not empty_noted[name]) and #collList(name) == 0 then
            empty_noted[name] = true
            empty[#empty + 1] = collLabel(name)
        end
    end
    if #empty > 0 and panelNote then
        panelNote(string.format(_("%s has no books yet, so it isn't shown in the side panel. Add a book and it'll appear."),
            table.concat(empty, ", ")))
    end
end

local function bookMeta(fp)
    local okb, SH = pcall(require, "modules/module_books_shared")
    local bd = okb and type(SH) == "table" and type(SH.getBookData) == "function"
        and select(2, pcall(SH.getBookData, fp))
    local title = type(bd) == "table" and bd.title or nil
    if not title or title == "" then
        title = (fp:match("([^/]+)$") or fp):gsub("%.[^.]+$", "")
    end
    local percent = type(bd) == "table" and bd.percent or nil
    local status = type(bd) == "table" and bd.status or nil
    return title, type(bd) == "table" and bd.authors or "", okb and SH or nil, percent, status
end

local tbr_panel_open = false
local tbr_panel_view = "tbr"   -- "tbr" | "new" | "history"
local tbr_panel_prev_view = "tbr"   -- view to return to when leaving History
local tbr_panel_root = nil   -- the open panel widget, for suspend-dismiss

-- reuse: the open panel, to rebuild in place (view switch): no close, no
-- repaint of the home behind it, just this panel's area refreshed.
-- True if this view key is currently allowed (Views In Panel + non-empty colls)
local function viewIsAvailable(v)
    if type(v) ~= "string" then return false end
    if v == "history" then return true end  -- history is icon-only, always ok
    if v == "tbr" then return cfg.tbr_panel_show_tbr ~= false end
    if v == "new" then return cfg.tbr_panel_show_new ~= false end
    if v == "bo:new" then return cfg.bo_show_new == true end
    if v:sub(1, 5) == "coll:" then
        local n = v:sub(6)
        return isCollPicked(n) and #collList(n) > 0
    end
    if v:sub(1, 3) == "bo:" then
        return type(isBoPicked) == "function" and isBoPicked(v:sub(4))
            and type(boCollList) == "function" and #boQuick(boCollList, v:sub(4)) > 0
    end
    return false
end

local function firstAvailableView()
    local views = panelViews()
    if #views > 0 then return views[1] end
    return "tbr"
end

-- If Panel Opens To points at a disabled view, reset it and save
local function clampOpensToSetting()
    local dv = cfg.tbr_panel_view
    if dv == "last" or dv == "history" then return end
    if not viewIsAvailable(dv) then
        cfg.tbr_panel_view = firstAvailableView()
        saveConfig()
    end
end

local boAfterShow -- 1.0.15, set after the BookOrbit list code

local function openTBRPanel(hs, view, switching, reuse)
    if tbr_panel_open and not reuse then return end
    -- Apply the configured default view on every open, unless set to "last"
    -- (which keeps wherever you left off — still clamped to an available view).
    local dv = cfg.tbr_panel_view
    if switching then
        -- switching views inside an open panel: keep the view asked for
    elseif dv == "last" then
        -- keep tbr_panel_view as-is (where you left off)
    elseif dv == "history" then
        tbr_panel_view = "history"
    elseif viewIsAvailable(dv) then
        tbr_panel_view = dv
    else
        tbr_panel_view = firstAvailableView()
    end
    -- a view switch has already set where "back" goes (history icon);
    -- overwriting it here made back from History land on History again
    if not switching then tbr_panel_prev_view = tbr_panel_view end
    tbr_panel_view = view or tbr_panel_view or firstAvailableView()
    -- Always land on a view that is still enabled
    if tbr_panel_view ~= "history" and not viewIsAvailable(tbr_panel_view) then
        tbr_panel_view = firstAvailableView()
    end
    if not switching then pcall(noteEmptyCollections) end
    local side = cfg.tbr_panel
    local UIManager       = require("ui/uimanager")
    local InputContainer  = require("ui/widget/container/inputcontainer")
    local FrameContainer  = require("ui/widget/container/framecontainer")
    local VerticalGroup   = require("ui/widget/verticalgroup")
    local HorizontalGroup = require("ui/widget/horizontalgroup")
    local VerticalSpan    = require("ui/widget/verticalspan")
    local HorizontalSpan  = require("ui/widget/horizontalspan")
    local LineWidget      = require("ui/widget/linewidget")
    local TextWidget      = require("ui/widget/textwidget")
    local TextBoxWidget   = require("ui/widget/textboxwidget")
    local Font            = require("ui/font")
    local Geom            = require("ui/geometry")
    local GestureRange    = require("ui/gesturerange")
    local Size            = require("ui/size")
    local Blitbuffer      = require("ffi/blitbuffer")

    local sw, sh = Screen:getWidth(), Screen:getHeight()
    local pw = math.floor(sw * 0.42)
    local px = (side == "left") and 0 or (sw - pw)
    local panel_dimen = Geom:new{ x = px, y = 0, w = pw, h = sh }
    local pad = Screen:scaleBySize(14)
    local cover_h = Screen:scaleBySize(96)
    local cover_w = math.floor(cover_h * 2 / 3)
    local text_w = pw - pad * 3 - cover_w
    -- View: "tbr" (To Be Read), "new" (Newly Added), "history" (Recent History)
    local view = tbr_panel_view
    local coll_name = view:sub(1, 5) == "coll:" and view:sub(6) or nil
    local bo_view = (view:sub(1, 3) == "bo:") and view or nil
    local list, view_title
    if coll_name then
        list = collList(coll_name)
        view_title = collLabel(coll_name)
    elseif bo_view == "bo:new" then
        list = type(boNewList) == "function" and boNewList() or {}
        view_title = _("BookOrbit Newly Added")
    elseif bo_view then
        local id = bo_view:sub(4)
        list = type(boCollList) == "function" and boCollList(id) or {}
        view_title = type(boLabel) == "function" and boLabel(id) or id
    elseif view == "new" then
        list = newBooksList()
        view_title = _("Newly Added")
    elseif view == "history" then
        if cfg.history_source == "bookorbit" and bookOrbitInstalled()
                and type(boHistoryList) == "function" then
            list = boHistoryList() or {}
            view_title = _("History · BookOrbit")
        else
            list = historyList()
            view_title = _("History")
        end
    else
        list = tbrList()
        view_title = _("To Be Read")
    end
    local changed = false

    local root
    if reuse then
        root = reuse
        for k = #root, 1, -1 do root[k] = nil end
    else
        root = InputContainer:new{
            dimen = Geom:new{ x = 0, y = 0, w = sw, h = sh },
            modal = true,
            name = "sui_tbr_panel",
        }
    end
    -- close(true): only to reopen in another view right away. No refresh
    -- here: the new view's own refresh covers the same area.
    local function close(for_switch)
        tbr_panel_open = false
        tbr_panel_root = nil
        -- a pending BookOrbit refresh has nothing to redraw now
        if bo_refresh_task and not for_switch then
            UIManager:unschedule(bo_refresh_task)
            bo_refresh_task = nil
        end
        if not for_switch then bo_refreshed_open = false end
        if for_switch then
            UIManager:close(root)
            return
        end
        UIManager:close(root, "full", panel_dimen)
        if changed and hs and type(hs._refreshImmediate) == "function" then
            pcall(hs._refreshImmediate, hs, false)   -- the home's TBR module catches up
        end
    end
    local function openBook(fp)
        close()
        local open_fn = hs and hs._ctx_cache and hs._ctx_cache.open_fn
        if type(open_fn) == "function" then
            open_fn(fp)
        else
            require("apps/reader/readerui"):showReader(fp)
        end
    end
    local function showAll()
        close()
        if bo_view and type(openBoInCatalog) == "function" then
            if hs then hs._navbar_closing_intentionally = true end
            if bo_view == "bo:new" then
                openBoInCatalog(nil, view_title, { sort = "recently_added" })
            else
                openBoInCatalog(bo_view:sub(4), view_title)
            end
            if hs then hs._navbar_closing_intentionally = nil end
            return
        end
        local FM = package.loaded["apps/filemanager/filemanager"]
        local fm = type(FM) == "table" and FM.instance
        if not (fm and fm.collections and type(fm.collections.onShowColl) == "function") then return end
        if hs then hs._navbar_closing_intentionally = true end
        pcall(fm.collections.onShowColl, fm.collections, coll_name or TBR_COLL)
        if hs then hs._navbar_closing_intentionally = nil end
        local bm = fm.collections.booklist_menu
        if type(bm) == "table" and type(bm.close_callback) == "function" then
            bm.onReturn = function()
                bm.close_callback()
                pcall(showSimpleUIHome)
            end
        end
    end

    local title_face = Font:getFace("smalltfont")
    local author_face = Font:getFace("cfont", 16)
    local head_face = Font:getFace("tfont", 22)
    local group = VerticalGroup:new{ align = "left" }
    -- Header: title on the left, history icon on the right (top-right)
    local title_text = (#list > 0) and string.format("%s (%d)", view_title, #list) or view_title
    -- 1.0.17: the whole title shows. 22, or 20 if that fits one line;
    -- longer, it wraps onto two lines at full size (22), and only a title
    -- longer than two lines is cut.
    local title_avail = pw - pad * 3 - Screen:scaleBySize(32)
    local title_widget
    for _i, size in ipairs({ 22, 20 }) do
        local tw = TextWidget:new{ text = title_text, face = Font:getFace("tfont", size), bold = true }
        if tw:getSize().w <= title_avail then title_widget = tw break end
        tw:free()
    end
    if not title_widget then
        -- 1.0.19: measured by the text box itself. Its lines are taller than a
        -- plain text line, so "two plain lines" only held one and the title was
        -- still cut after a word or two.
        title_widget = TextBoxWidget:new{ text = title_text, face = head_face, bold = true, width = title_avail }
        local lh = tonumber(title_widget.line_height_px)
        if lh and lh > 0 and title_widget:getSize().h > lh * 2 + 1 then
            title_widget:free()
            title_widget = TextBoxWidget:new{
                text = title_text, face = head_face, bold = true, width = title_avail,
                height = lh * 2, height_overflow_show_ellipsis = true,
            }
        end
    end
    -- Header icon (top-right): context-aware.
    -- In TBR/New views: SimpleUI's history.svg → tap goes to History.
    -- In History view: "<" text → tap goes back to previous view.
    -- (back.svg doesn't load reliably on-device; text always renders.)
    local hist_size = Screen:scaleBySize(28)
    local IconWidget = require("ui/widget/iconwidget")
    local is_history_view = (view == "history")
    local hist_icon_path = nil
    if not is_history_view then
        -- Use SimpleUI's own path resolver for the absolute plugin directory.
        local okp, SuiPaths = pcall(require, "infra/sui_paths")
        if okp and type(SuiPaths) == "table" and type(SuiPaths.getPluginDir) == "function" then
            local okd, pdir = pcall(SuiPaths.getPluginDir)
            if okd and type(pdir) == "string" and pdir ~= "" then
                local p = pdir .. "icons/history.svg"
                local lfs = require("libs/libkoreader-lfs")
                if lfs.attributes(p, "mode") == "file" then hist_icon_path = p end
            end
        end
        if not hist_icon_path and type(sui_name) == "string" and sui_name ~= "" then
            local p = "plugins/" .. sui_name .. ".koplugin/icons/history.svg"
            local lfs = require("libs/libkoreader-lfs")
            if lfs.attributes(p, "mode") == "file" then hist_icon_path = p end
        end
    end
    local hist_icon_child
    if not is_history_view and hist_icon_path then
        hist_icon_child = IconWidget:new{ file = hist_icon_path, width = hist_size, height = hist_size }
    elseif is_history_view then
        -- Simple text back arrow; always renders on Kobo
        hist_icon_child = TextWidget:new{
            text = "<", face = Font:getFace("tfont", 24), bold = true,
        }
    else
        hist_icon_child = VerticalSpan:new{ width = hist_size }
    end
    local hist_icon = InputContainer:new{
        dimen = Geom:new{ w = hist_size, h = hist_size },
        hist_icon_child,
    }
    hist_icon.ges_events = {
        TapHist = { GestureRange:new{ ges = "tap", range = hist_icon.dimen } },
    }
    function hist_icon:onTapHist()
        local v = tbr_panel_view
        if v == "history" then
            -- back to the view we came from
            tbr_panel_view = tbr_panel_prev_view
        else
            -- remember where we were, go to history
            tbr_panel_prev_view = v
            tbr_panel_view = "history"
        end
        openTBRPanel(hs, tbr_panel_view, true, root)
        return true
    end
    local header = HorizontalGroup:new{ align = "center" }
    header[#header + 1] = title_widget
    header[#header + 1] = HorizontalSpan:new{ width = pad }
    header[#header + 1] = hist_icon
    group[#group + 1] = header
    group[#group + 1] = VerticalSpan:new{ width = pad }
    if #list == 0 then
        local empty_text
        if view == "new" then
            empty_text = _("No new books. Add books to your library and they'll show up here.")
        elseif view == "history" then
            empty_text = _("No reading history yet. Open a book and it'll show up here.")
        elseif bo_view then
            empty_text = _("No books in this BookOrbit list (or could not load them).")
        else
            empty_text = _("Nothing here yet. Hold a book in Bookshelf and choose To Be Read to add it.")
        end
        group[#group + 1] = TextBoxWidget:new{
            text = empty_text,
            face = author_face, width = pw - pad * 2,
        }
    end
    -- Open the BookOrbit detail page for this book (download / formats live there)
    local function openBoDetail(entry)
        local title = (entry and entry.title) or _("Book")
        local id = entry and entry.id
        close()  -- dismiss side panel before BookOrbit UI
        if hs then hs._navbar_closing_intentionally = true end
        -- nextTick so the panel close/paint finishes before BookOrbit opens
        UIManager:nextTick(function()
            local ok = openBoBookDetail(id, title)
            if hs then hs._navbar_closing_intentionally = nil end
            if not ok then
                panelNote(_("Could not open BookOrbit. Is the plugin installed and signed in?"))
            end
        end)
    end

    -- Tap: open file if still on device; otherwise offer download via BookOrbit
    local function handleBoEntry(entry)
        local fp = liveBookPath(entry and entry.id, entry and entry.path)
        if entry then entry.path = fp end  -- keep list accurate after deletes
        if type(fp) == "string" and fp ~= "" then
            openBook(fp)
            return
        end
        -- Close the panel first so the dialog is not buried under it
        close()
        local ButtonDialog = require("ui/widget/buttondialog")
        local dlg
        local title = (entry and entry.title) or _("Book")
        dlg = ButtonDialog:new{
            title = title,
            title_align = "center",
            buttons = {
                {{
                    text = _("Download / open in BookOrbit"),
                    callback = function()
                        UIManager:close(dlg)
                        -- panel already closed; openBoDetail still nextTick-opens BO
                        openBoDetail(entry)
                    end,
                }},
                {{
                    text = _("Cancel"),
                    callback = function() UIManager:close(dlg) end,
                }},
            },
        }
        UIManager:show(dlg)
    end

    local SH
    for i = 1, math.min(TBR_ROWS, #list) do
        local item = list[i]
        local history_is_bo = (view == "history" and cfg.history_source == "bookorbit"
                and bookOrbitInstalled() and type(item) == "table")
        local is_bo = (bo_view or history_is_bo) and type(item) == "table"
        local fp, title, authors, percent, status, on_device
        if is_bo then
            fp = liveBookPath(item.id, item.path)
            item.path = fp
            title = item.title or _("Untitled")
            authors = item.authors or ""
            on_device = type(fp) == "string" and fp ~= ""
            if on_device then
                local t2, a2, sh2, p2, s2 = bookMeta(fp)
                SH = SH or sh2
                if t2 and t2 ~= "" then title = t2 end
                if a2 and a2 ~= "" then authors = a2 end
                percent, status = p2, s2
            end
        else
            fp = item
            local sh_mod
            title, authors, sh_mod, percent, status = bookMeta(fp)
            SH = SH or sh_mod
            on_device = true
        end
        local cover
        if on_device and fp then
            cover = SH and SH.getBookCover and SH.getBookCover(fp, cover_w, cover_h)
            if not cover and SH and SH.coverPlaceholder then
                cover = SH.coverPlaceholder(title, authors, cover_w, cover_h)
            end
        end
        if not cover and SH and SH.coverPlaceholder then
            cover = SH.coverPlaceholder(title, authors, cover_w, cover_h)
        end
        cover = cover or FrameContainer:new{ bordersize = Size.border.thin, padding = 0,
            dimen = Geom:new{ w = cover_w, h = cover_h }, VerticalSpan:new{ width = cover_h - 2 } }
        -- BookOrbit: same on-device / download corner mark as the catalog cover
        if is_bo then
            local lfs = require("libs/libkoreader-lfs")
            local icon_name = on_device and "bookorbit.on-device.svg" or "bookorbit.download.svg"
            local icon_path = "plugins/bookorbit.koplugin/assets/" .. icon_name
            if lfs.attributes(icon_path, "mode") ~= "file" then
                -- older plugin layout kept assets next to the plugin root
                icon_path = "plugins/bookorbit.koplugin/" .. icon_name
            end
            if lfs.attributes(icon_path, "mode") == "file" then
                local IconWidget = require("ui/widget/iconwidget")
                local OverlapGroup = require("ui/widget/overlapgroup")
                local BottomContainer = require("ui/widget/container/bottomcontainer")
                local RightContainer = require("ui/widget/container/rightcontainer")
                local icon_sz = Screen:scaleBySize(22)
                local pad_i = Screen:scaleBySize(3)
                local badge_icon = IconWidget:new{
                    file = icon_path, width = icon_sz, height = icon_sz,
                }
                cover = OverlapGroup:new{
                    dimen = Geom:new{ w = cover_w, h = cover_h },
                    cover,
                    BottomContainer:new{
                        dimen = Geom:new{ w = cover_w, h = cover_h },
                        RightContainer:new{
                            dimen = Geom:new{ w = cover_w, h = icon_sz + pad_i },
                            HorizontalGroup:new{
                                badge_icon,
                                HorizontalSpan:new{ width = pad_i },
                            },
                        },
                    },
                }
            end
        end
        local meta = VerticalGroup:new{ align = "left",
            TextBoxWidget:new{ text = title, face = title_face, bold = true, width = text_w,
                               height = title_face.size * 3, height_adjust = true, height_overflow_show_ellipsis = true },
        }
        if authors ~= "" then
            meta[#meta + 1] = VerticalSpan:new{ width = Screen:scaleBySize(4) }
            meta[#meta + 1] = TextWidget:new{ text = authors, face = author_face, max_width = text_w }
        end
        if is_bo then
            local badge = on_device and _("On device") or _("Not on device · tap to download")
            meta[#meta + 1] = VerticalSpan:new{ width = Screen:scaleBySize(4) }
            meta[#meta + 1] = TextWidget:new{ text = badge, face = author_face, max_width = text_w }
        end
        if view == "history" then
            local prog_text
            if status == "complete" or (percent and percent >= 1) then
                prog_text = _("Completed")
            elseif percent and percent > 0 then
                prog_text = string.format(_("%d%% read"), math.floor(percent * 100))
            else
                prog_text = _("Not started")
            end
            meta[#meta + 1] = VerticalSpan:new{ width = Screen:scaleBySize(4) }
            meta[#meta + 1] = TextWidget:new{ text = prog_text, face = author_face, max_width = text_w }
        end
        local row = InputContainer:new{
            dimen = Geom:new{ w = pw - pad * 2, h = cover_h },
            HorizontalGroup:new{ align = "center", cover, HorizontalSpan:new{ width = pad }, meta },
        }
        row.ges_events = {
            TapRow  = { GestureRange:new{ ges = "tap",  range = function() return row.dimen end } },
            HoldRow = { GestureRange:new{ ges = "hold", range = function() return row.dimen end } },
        }
        if is_bo then
            local entry = item
            function row:onTapRow() handleBoEntry(entry) return true end
            -- Hold always opens BookOrbit book detail (same as catalog hold)
            function row:onHoldRow() openBoDetail(entry) return true end
        else
            function row:onTapRow() openBook(fp) return true end
            function row:onHoldRow()
                if view ~= "tbr" and not coll_name then return false end
                local ButtonDialog = require("ui/widget/buttondialog")
                local dlg
                dlg = ButtonDialog:new{
                    title = title, title_align = "center",
                    buttons = {
                        {{ text = string.format(_("Remove from %s"), coll_name and collLabel(coll_name) or _("To Be Read")),
                           callback = function()
                            UIManager:close(dlg)
                            if coll_name then collRemove(fp, coll_name) else tbrRemove(fp) end
                            changed = true
                            close()
                            UIManager:nextTick(function() openTBRPanel(hs, tbr_panel_view, true) end)
                        end }},
                        {{ text = _("Cancel"), callback = function() UIManager:close(dlg) end }},
                    },
                }
                UIManager:show(dlg)
                return true
            end
        end
        group[#group + 1] = row
        group[#group + 1] = VerticalSpan:new{ width = pad }
        group[#group + 1] = LineWidget:new{ dimen = Geom:new{ w = pw - pad * 2, h = Size.line.thin } }
        group[#group + 1] = VerticalSpan:new{ width = pad }
    end
    if (view == "tbr" or coll_name) and #list > TBR_ROWS then
        local more = InputContainer:new{
            dimen = Geom:new{ w = pw - pad * 2, h = Screen:scaleBySize(40) },
            TextWidget:new{ text = string.format(_("Show all (%d)"), #list) .. "  \226\128\186",
                            face = title_face, bold = true },
        }
        more.ges_events = { TapMore = { GestureRange:new{ ges = "tap", range = function() return more.dimen end } } }
        function more:onTapMore() showAll() return true end
        group[#group + 1] = more
    end

    -- View indicators at the bottom: 2 dots for the swipeable views
    -- (To Be Read / Newly Added). Filled dot = current view.
    -- History is tap-only via the icon, not swipeable.
    -- Same drawn-dot style as Currently Reading.
    local views = panelViews()
    local cur
    for i, v in ipairs(views) do if v == view then cur = i end end
    if cur then
    do
        local dots = HorizontalGroup:new{ align = "center" }
        local dot_r = Screen:scaleBySize(4)
        local dot_gap = Screen:scaleBySize(10)
        for i = 1, #views do
            local dot = InputContainer:new{
                dimen = Geom:new{ w = dot_r * 2, h = dot_r * 2 },
            }
            local filled = (i == cur)
            dot.paintTo = function(self, bb, x, y)
                local cx, cy = x + dot_r, y + dot_r
                local col = Blitbuffer.COLOR_BLACK
                if filled then
                    -- filled circle
                    for dy = -dot_r, dot_r do
                        local hw = math.floor(math.sqrt(dot_r * dot_r - dy * dy))
                        bb:paintRect(cx - hw, cy + dy, hw * 2, 1, col)
                    end
                else
                    -- outline circle (8 segments)
                    for s = 0, 7 do
                        local a1, a2 = (s * 2 * math.pi) / 8, ((s + 1) * 2 * math.pi) / 8
                        local x1, y1 = cx + dot_r * math.cos(a1), cy + dot_r * math.sin(a1)
                        local x2, y2 = cx + dot_r * math.cos(a2), cy + dot_r * math.sin(a2)
                        bb:paintRect(math.min(x1, x2), math.min(y1, y2),
                                     math.abs(x2 - x1) + 2, math.abs(y2 - y1) + 2, col)
                    end
                end
            end
            dots[#dots + 1] = dot
            if i < #views then dots[#dots + 1] = HorizontalSpan:new{ width = dot_gap } end
        end
        group[#group + 1] = VerticalSpan:new{ width = pad }
        group[#group + 1] = dots
    end
    end

    local frame = FrameContainer:new{
        width = pw, height = sh,
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 0, padding = pad, margin = 0,
        group,
    }
    local edge = LineWidget:new{ dimen = Geom:new{ w = Size.border.thick, h = sh } }
    root[1] = FrameContainer:new{ bordersize = 0, padding = 0, margin = 0, frame }
    -- paint just the panel (and its edge line) at its side; the home stays visible beside it
    root.paintTo = function(self, bb, x, y)
        frame:paintTo(bb, x + px, y)
        edge:paintTo(bb, (side == "left") and (x + pw - Size.border.thick) or (x + px), y)
    end
    root.ges_events = {
        TapOutside = { GestureRange:new{ ges = "tap", range = root.dimen } },
        SwipeClose = { GestureRange:new{ ges = "swipe", range = root.dimen } },
    }
    function root:onTapOutside(_, ges)
        if ges and ges.pos and not panel_dimen:contains(ges.pos) then close() end
        return true
    end
    function root:onSwipeClose(_, ges)
        local dir = ges and ges.direction
        if dir ~= "west" and dir ~= "east" then return true end
        -- Swipe cycles between the 2 swipeable views (TBR / New).
        -- History is tap-only via the icon. Never closes on swipe;
        -- only tapping outside the panel closes it.
        local v = tbr_panel_view
        if v == "history" then return true end  -- no swipe in History view
        -- west = next view, east = previous; loops around
        local order = panelViews()
        local at = 1
        for i, ov in ipairs(order) do if ov == v then at = i end end
        local step = (dir == "west") and 1 or -1
        local okbd, BD = pcall(require, "ui/bidi")
        if okbd and type(BD) == "table" and BD.mirroredUILayout and BD.mirroredUILayout() then step = -step end
        local next_view = order[(at - 1 + step) % #order + 1]
        tbr_panel_view = next_view
        openTBRPanel(hs, next_view, true, root)
        return true
    end
    tbr_panel_open = true
    tbr_panel_root = root
    -- "full" (one flash of just the panel area) on open and close: a plain
    -- "ui" refresh left ghosts of the covers/home behind. "full" also isn't
    -- downgraded by "Avoid mandatory black flashes in UI".
    -- Switching views inside the open panel uses a quick "ui" refresh
    -- (~0.15 s instead of ~0.6 s); any faint ghost from it is cleared by
    -- the full flash when the panel closes.
    if reuse then
        UIManager:setDirty(root, function() return "ui", panel_dimen end)
    else
        UIManager:show(root, switching and "ui" or "full", panel_dimen)
    end
    -- 1.0.15: the list on show was an old saved copy: fetch it fresh now
    -- that the panel is up, then redraw it in place (once; a refresh that
    -- finds nothing new just keeps what's shown)
    local stale = bo_stale
    bo_stale = nil
    if stale and boAfterShow then boAfterShow(hs, stale, tbr_panel_view) end
end

-- hookHomeEdgeSwipe moved to onHomeShow in this patch

-- Dismiss the TBR side panel on suspend: it should not stay open over the
-- sleep screen. Hooks UIManager.broadcastEvent for the onSuspend event,
-- the same pattern Network Tweaks uses.
do
    local ok, UIManager = pcall(require, "ui/uimanager")
    if ok and type(UIManager) == "table" and type(UIManager.broadcastEvent) == "function" then
        local orig_broadcast = UIManager.broadcastEvent
        UIManager.broadcastEvent = function(self, event, ...)
            local handler = type(event) == "table" and event.handler
            if handler == "onSuspend" and bo_refresh_task then
                pcall(UIManager.unschedule, UIManager, bo_refresh_task)
                bo_refresh_task = nil
            end
            if handler == "onSuspend" and tbr_panel_open and tbr_panel_root then
                local root, open = tbr_panel_root, tbr_panel_open
                tbr_panel_open, tbr_panel_root = false, nil
                pcall(UIManager.close, UIManager, root)
            end
            return orig_broadcast(self, event, ...)
        end
    end
end


panelNote = function(text)
    local ok, Notification = pcall(require, "ui/widget/notification")
    if ok and type(Notification) == "table" and type(Notification.notify) == "function" then
        Notification:notify(text)
        return
    end
    local ok2, InfoMessage = pcall(require, "ui/widget/infomessage")
    if ok2 then
        local UIManager = require("ui/uimanager")
        UIManager:show(InfoMessage:new{ text = text, timeout = 4 })
    end
end


-- ---- BookOrbit data ---------------------------------------------------------------
local BO_COLLS_CACHE_KEY = "simpleui_sidepanel_bo_collections"
local BO_BOOKS_CACHE_KEY = "simpleui_sidepanel_bo_books"
local BO_BOOKS_TTL = 6 * 3600       -- offline: keep cache this long (seconds)
local BO_BOOKS_SOFT_TTL = 30 * 60   -- online: refresh (after the panel is up) if older than this

local function boApiClient()
    local s = G_reader_settings and G_reader_settings:readSetting("bookorbit")
    if type(s) ~= "table" or not s.server_url or not s.username or not s.userkey then
        return nil, "not signed in"
    end
    local ok, BookOrbitApi = pcall(require, "bookorbit_api")
    if not ok or type(BookOrbitApi) ~= "table" or type(BookOrbitApi.new) ~= "function" then
        return nil, "BookOrbit not installed"
    end
    return BookOrbitApi.new({
        server_url = s.server_url, username = s.username, userkey = s.userkey, device_id = s.device_id,
    })
end

onDeviceByBookId = function(refresh)
    local ok, SM = pcall(require, "bookorbit_state_manager")
    if not (ok and type(SM) == "table") then return {} end
    -- Drop stale maps so deleted files are not still treated as on-device
    if refresh and type(SM.invalidate) == "function" then
        pcall(SM.invalidate)
    end
    if type(SM.onDeviceMaps) == "function" then
        local okm, maps = pcall(SM.onDeviceMaps)
        if okm and type(maps) == "table" and type(maps.byBookId) == "table" then return maps.byBookId end
    end
    return {}
end

-- Path only if the file still exists on disk (clears deleted-book false positives)
liveBookPath = function(book_id, cached_path)
    local lfs = require("libs/libkoreader-lfs")
    if type(cached_path) == "string" and cached_path ~= ""
            and lfs.attributes(cached_path, "mode") == "file" then
        return cached_path
    end
    if book_id == nil then return nil end
    local on_device = onDeviceByBookId(false)
    local fp = on_device[book_id] or on_device[tostring(book_id)] or on_device[tonumber(book_id)]
    if type(fp) == "string" and fp ~= "" and lfs.attributes(fp, "mode") == "file" then
        return fp
    end
    return nil
end

refreshCachedBooks = function(books)
    if type(books) ~= "table" then return books end
    local out = {}
    for _i, b in ipairs(books) do
        if type(b) == "table" then
            local path = liveBookPath(b.id, b.path)
            out[#out + 1] = {
                id = b.id, title = b.title, authors = b.authors or "", path = path,
            }
        end
    end
    return out
end

local function loadBoCache(key)
    local t = G_reader_settings and G_reader_settings:readSetting(key)
    return type(t) == "table" and t or {}
end

local function saveBoCache(key, t)
    if not G_reader_settings then return end
    G_reader_settings:saveSetting(key, t or {})
    if G_reader_settings.flush then pcall(G_reader_settings.flush, G_reader_settings) end
end

local function fetchBoCollections()
    local client, err = boApiClient()
    if not client then return nil, err end
    local body, ferr = client:catalogSection("collections")
    if not body then return nil, ferr or "fetch failed" end
    local items = body.items or body.collections or body.entries or {}
    local out = {}
    for _i, entry in ipairs(items) do
        if type(entry) == "table" and entry.id then
            out[#out + 1] = { id = tonumber(entry.id) or entry.id, title = entry.title or entry.name or tostring(entry.id) }
        end
    end
    table.sort(out, function(a, b) return tostring(a.title):lower() < tostring(b.title):lower() end)
    saveBoCache(BO_COLLS_CACHE_KEY, out)
    return out
end

local function isWifiOn()
    local ok, NM = pcall(require, "ui/network/manager")
    if not (ok and type(NM) == "table") then return false end
    if type(NM.isOnline) == "function" then
        local ok2, online = pcall(NM.isOnline, NM)
        if ok2 and online then return true end
    end
    if type(NM.isWifiOn) == "function" then
        local ok2, on = pcall(NM.isWifiOn, NM)
        if ok2 and on then return true end
    end
    if type(NM.isConnected) == "function" then
        local ok2, on = pcall(NM.isConnected, NM)
        if ok2 and on then return true end
    end
    return false
end

-- Returns { { id, title, authors, path }, ... } — path is set only when the file is on device.
-- With Wi-Fi on: refresh from BookOrbit if cache is older than SOFT_TTL (like catalog Newly Added).
-- Offline: serve cache up to BO_BOOKS_TTL, with live path checks.
local function fetchBoEntries(cache_key, api_params, force)
    local cache = loadBoCache(BO_BOOKS_CACHE_KEY)
    local entry = cache[cache_key]
    local age = (type(entry) == "table" and type(entry.at) == "number") and (os.time() - entry.at) or nil
    local wifi = isWifiOn()

    -- Only the saved list (view checks): never the server
    if bo_quick and not force then
        if type(entry) == "table" and type(entry.books) == "table" then return refreshCachedBooks(entry.books) end
        -- never fetched yet: count it as having books, so its view is offered
        -- (opening it fetches the list)
        return { true }
    end
    if not force and type(entry) == "table" and type(entry.books) == "table" and age then
        local ttl = wifi and BO_BOOKS_SOFT_TTL or BO_BOOKS_TTL
        if age < ttl then
            return refreshCachedBooks(entry.books)
        end
        -- old but there: show it now, refresh once the panel is up
        if wifi then
            bo_stale = { key = cache_key, params = api_params }
            return refreshCachedBooks(entry.books)
        end
    end
    -- migrate old path-only cache (offline)
    if not force and not wifi and type(entry) == "table" and type(entry.paths) == "table"
            and age and age < BO_BOOKS_TTL then
        local books = {}
        for _i, fp in ipairs(entry.paths) do
            books[#books + 1] = { id = nil, title = nil, authors = "", path = liveBookPath(nil, fp) }
        end
        return books
    end
    local client, err = boApiClient()
    if not client then
        if type(entry) == "table" and type(entry.books) == "table" then
            return refreshCachedBooks(entry.books), err
        end
        return {}, err
    end
    if not force and not wifi and type(entry) == "table" and type(entry.books) == "table" then
        return refreshCachedBooks(entry.books)
    end
    local on_device = onDeviceByBookId()
    local books, seen_id, page, page_size = {}, {}, 1, 100
    local lfs = require("libs/libkoreader-lfs")
    for _ = 1, 1 do -- one request (up to 100 books): the panel shows a handful
        local q = {}
        for k, v in pairs(api_params or {}) do q[k] = v end
        q.page, q.size = page, page_size
        local body = client:catalogBooks(q)
        if not body then break end
        local items = body.items or body.books or body.entries or {}
        if type(items) ~= "table" or #items == 0 then break end
        for _i, book in ipairs(items) do
            if type(book) == "table" and book.id and not seen_id[book.id] then
                seen_id[book.id] = true
                local fp = liveBookPath(book.id,
                    on_device[book.id] or on_device[tostring(book.id)] or on_device[tonumber(book.id)])
                local authors = ""
                if type(book.authors) == "table" then
                    local parts = {}
                    for _j, a in ipairs(book.authors) do
                        if type(a) == "string" then parts[#parts + 1] = a
                        elseif type(a) == "table" and a.name then parts[#parts + 1] = a.name end
                    end
                    authors = table.concat(parts, ", ")
                elseif type(book.author) == "string" then
                    authors = book.author
                end
                books[#books + 1] = {
                    id = book.id,
                    title = book.title or book.name or _("Untitled"),
                    authors = authors,
                    path = type(fp) == "string" and fp or nil,
                }
            end
        end
        local total = tonumber(body.total) or tonumber(body.totalCount)
        if total and page * page_size >= total then break end
        if #items < page_size then break end
        page = page + 1
    end
    cache[cache_key] = { books = books, at = os.time() }
    saveBoCache(BO_BOOKS_CACHE_KEY, cache)
    return books
end

boAfterShow = function(hs, stale, view)
    local UIManager = require("ui/uimanager")
    -- One refresh per panel open: views swiped to after it keep their saved list.
    if bo_refreshed_open then return end
    if bo_refresh_task then UIManager:unschedule(bo_refresh_task) end
    bo_refresh_task = function()
        bo_refresh_task = nil
        if not tbr_panel_open or tbr_panel_view ~= view or not tbr_panel_root then return end
        bo_refreshed_open = true
        local ok, books = pcall(fetchBoEntries, stale.key, stale.params, true)
        if ok and tbr_panel_open and tbr_panel_view == view and tbr_panel_root then
            bo_stale = nil
            openTBRPanel(hs, view, true, tbr_panel_root)
            bo_stale = nil -- just refreshed: don't go round again
        end
    end
    UIManager:scheduleIn(0.4, bo_refresh_task)
end

boCollList = function(id, force)
    return fetchBoEntries("coll:" .. tostring(id), { collectionId = tonumber(id) or id }, force == true) or {}
end
boNewList = function(force)
    return fetchBoEntries("new", { sort = "recently_added" }, force == true) or {}
end
boHistoryList = function(force)
    return fetchBoEntries("history", { sort = "recently_read" }, force == true) or {}
end

-- For panelViews: a BO collection counts as non-empty if it has any books (on or off device)
local function boCollHasBooks(id)
    return #boQuick(boCollList, id) > 0
end
isBoPicked = function(id)
    id = tonumber(id) or id
    for _i, e in ipairs(cfg.bo_colls or {}) do
        if type(e) == "table" and (tonumber(e.id) or e.id) == id then return true end
    end
    return false
end
boLabel = function(id)
    id = tonumber(id) or id
    for _i, e in ipairs(cfg.bo_colls or {}) do
        if type(e) == "table" and (tonumber(e.id) or e.id) == id then return e.title or tostring(id) end
    end
    for _i, e in ipairs(loadBoCache(BO_COLLS_CACHE_KEY)) do
        if type(e) == "table" and (tonumber(e.id) or e.id) == id then return e.title or tostring(id) end
    end
    return tostring(id)
end
-- 1.0.18: the saved BookOrbit lists, for Reading Log Tweaks. Never the
-- server: collections = what was last fetched for this panel's settings,
-- books(id) = that collection's last saved list ({ id, title, authors, path },
-- path only for books on this device; {} when it was never opened here).
package.loaded["simpleui_sidepanel_bo"] = {
    collections = function()
        local out = {}
        for _i, e in ipairs(loadBoCache(BO_COLLS_CACHE_KEY)) do
            if type(e) == "table" and e.id then out[#out + 1] = { id = e.id, title = e.title or tostring(e.id) } end
        end
        for _i, e in ipairs(cfg.bo_colls or {}) do   -- picked ones, even before a fetch
            if type(e) == "table" and e.id then
                local seen = false
                for _j, o in ipairs(out) do if tostring(o.id) == tostring(e.id) then seen = true break end end
                if not seen then out[#out + 1] = { id = e.id, title = e.title or tostring(e.id) } end
            end
        end
        return out
    end,
    books = function(id)
        local out = {}
        for _i, b in ipairs(boQuick(boCollList, id)) do
            if type(b) == "table" then out[#out + 1] = b end
        end
        return out
    end,
}

boPlugin = function()
    local FM = package.loaded["apps/filemanager/filemanager"]
    local fm = type(FM) == "table" and FM.instance
    local plugin = type(fm) == "table" and (fm.bookorbit or fm.BookOrbit)
    if type(plugin) ~= "table" then
        local RUI = package.loaded["apps/reader/readerui"]
        local reader = type(RUI) == "table" and RUI.instance
        plugin = type(reader) == "table" and (reader.bookorbit or reader.BookOrbit)
    end
    return type(plugin) == "table" and plugin or nil
end

openBoInCatalog = function(coll_id, title, params)
    local plugin = boPlugin()
    if not plugin then return false end
    if type(plugin.browseCatalog) == "function" and not plugin.catalog_browser then
        pcall(plugin.browseCatalog, plugin, false)
    elseif type(plugin.openBookOrbit) == "function" and not plugin.catalog_browser then
        pcall(plugin.openBookOrbit, plugin)
    end
    local catalog = plugin.catalog_browser
    if type(catalog) == "table" and type(catalog.loadBooks) == "function" then
        local q = params or (coll_id and { collectionId = tonumber(coll_id) or coll_id } or { sort = "recently_added" })
        return pcall(catalog.loadBooks, catalog, q, title or _("Books"), true)
    end
    return false
end

-- Open BookOrbit on a single book's detail page (download / formats live there)
openBoBookDetail = function(book_id, title)
    local plugin = boPlugin()
    if not plugin then
        logger.warn(TAG, "openBoBookDetail: no BookOrbit plugin instance")
        return false
    end
    -- Prefer opening the catalog UI first so detail has a parent stack
    if not plugin.catalog_browser then
        local opened
        if type(plugin.openBookOrbit) == "function" then
            opened = pcall(plugin.openBookOrbit, plugin)
        end
        if not plugin.catalog_browser and type(plugin.browseCatalog) == "function" then
            opened = pcall(plugin.browseCatalog, plugin, false)
        end
        if not plugin.catalog_browser and type(plugin.openCatalogBrowser) == "function" then
            opened = pcall(plugin.openCatalogBrowser, plugin)
        end
    end
    local catalog = plugin.catalog_browser
    if type(catalog) ~= "table" then
        logger.warn(TAG, "openBoBookDetail: still no catalog_browser after open")
        return false
    end
    if type(catalog.loadBookDetail) == "function" then
        local ok, err = pcall(catalog.loadBookDetail, catalog, book_id)
        return ok
    end
    if type(catalog.loadBooks) == "function" and title then
        local ok, err = pcall(catalog.loadBooks, catalog, { q = title, sort = "recently_added" }, title, true)
        return ok
    end
    logger.warn(TAG, "openBoBookDetail: no usable catalog method")
    return false
end

-- ---- Hook home edge swipe -----------------------------------------------------------
local function tryOpenFromGes(self, ges)
    local side = cfg.tbr_panel
    if side == "off" or type(ges) ~= "table" or not ges.pos then return false end
    local sw = Screen:getWidth()
    local dir = ges.direction
    local edge = math.floor(sw * edgeRatio())
    if (side == "left" and dir == "east" and ges.pos.x <= edge)
            or (side ~= "left" and dir == "west" and ges.pos.x >= sw - edge) then
        local ok, err = pcall(openTBRPanel, self)
        if not ok then
            tbr_panel_open = false
            logger.warn(TAG, "panel:", err)
        end
        return true
    end
    return false
end

local function onHomeShow(hs)
    if type(hs) ~= "table" or rawget(hs, "_sui_sidepanel_hooked") then return end
    -- SimpleUI home uses onScreenSwipe; fall back to onSwipe if needed
    local method = nil
    if type(hs.onScreenSwipe) == "function" then method = "onScreenSwipe"
    elseif type(hs.onSwipe) == "function" then method = "onSwipe"
    end
    if not method then
        logger.warn(TAG, "home has no swipe handler to hook")
        return
    end
    rawset(hs, "_sui_sidepanel_hooked", true)
    local orig = hs[method]
    hs[method] = function(self, args, ges, ...)
        if tryOpenFromGes(self, ges) then return true end
        -- some handlers put ges as the first arg
        if type(args) == "table" and args.pos and tryOpenFromGes(self, args) then return true end
        return orig(self, args, ges, ...)
    end
end

-- Hook UIManager.show for future home opens; also attach if home is already up
do
    local ok, UIManager = pcall(require, "ui/uimanager")
    if ok and type(UIManager) == "table" and type(UIManager.show) == "function" then
        local orig_show = UIManager.show
        UIManager.show = function(self, w, ...)
            if type(w) == "table" and w.name == "homescreen" then
                pcall(onHomeShow, w)
            end
            return orig_show(self, w, ...)
        end
    end
    -- Home may already be on the stack when patches load after a restart-in-place
    local HS = package.loaded["screens/sui_homescreen"]
    if type(HS) == "table" and type(HS._instance) == "table" then
        pcall(onHomeShow, HS._instance)
    end
end

local function buildMenu()
    local function edgeItem(label, value)
        return {
            text = label, radio = true,
            checked_func = function() return cfg.tbr_panel == value end,
            callback = function() cfg.tbr_panel = value; saveConfig() end,
        }
    end

    local function opensToLabel()
        local names = {
            tbr = _("To Be Read"), new = _("Newly Added"), history = _("History"), last = _("Last View"),
        }
        local v = cfg.tbr_panel_view
        return names[v]
            or (type(v) == "string" and v:sub(1, 5) == "coll:" and collLabel(v:sub(6)))
            or (v == "bo:new" and _("BookOrbit Newly Added"))
            or (type(v) == "string" and v:sub(1, 3) == "bo:" and boLabel(v:sub(4)))
            or tostring(v)
    end

    local items = {
            -- 1. Enable Panel: checkmark when on; open submenu to pick side or turn off
            { text_func = function()
                  local side = cfg.tbr_panel
                  if side == "off" then return _("Panel: Off") end
                  if side == "left" then return _("Panel: Left edge") end
                  return _("Panel: Right edge")
              end,
              help_text = _("Swipe in from the home screen edge to open the panel. Tick means it is on; open this item to choose left, right, or off."),
              checked_func = function() return cfg.tbr_panel ~= "off" end,
              -- Tap the row (not only the check) opens the side picker
              sub_item_table = {
                  edgeItem(_("Right Edge"), "right"),
                  edgeItem(_("Left Edge"), "left"),
                  edgeItem(_("Off"), "off"),
              },
              separator = true },

            -- 2. Swipe Zone
            { text_func = function()
                  local names = { wide = _("Wide"), narrow = _("Narrow"), edge = _("Edge Only") }
                  return string.format(_("Swipe Zone: %s"), names[cfg.tbr_edge] or names.narrow)
              end,
              help_text = _("How close to the screen edge a swipe must start to open the panel."),
              sub_item_table_func = function()
                  local items = {}
                  for _, opt in ipairs({ {"wide", _("Wide")}, {"narrow", _("Narrow")}, {"edge", _("Edge Only")} }) do
                      items[#items + 1] = {
                          text = opt[2], radio = true,
                          checked_func = function() return cfg.tbr_edge == opt[1] end,
                          callback = function() cfg.tbr_edge = opt[1]; saveConfig() end,
                      }
                  end
                  return items
              end },

            -- 3. Panel Opens To
            { text_func = function()
                  return string.format(_("Panel Opens To: %s"), opensToLabel())
              end,
              help_text = _("Which list the panel shows when you open it. Last View reopens wherever you left off."),
              sub_item_table_func = function()
                  local function opt(label, value)
                      return {
                          text = label, radio = true,
                          checked_func = function() return cfg.tbr_panel_view == value end,
                          callback = function() cfg.tbr_panel_view = value; saveConfig() end,
                      }
                  end
                  local items = {}
                  if cfg.tbr_panel_show_tbr ~= false then
                      items[#items + 1] = opt(_("To Be Read"), "tbr")
                  end
                  for _i, name in ipairs(cfg.tbr_panel_colls or {}) do
                      items[#items + 1] = opt(collLabel(name), "coll:" .. name)
                  end
                  if bookOrbitInstalled() then
                      for _i, e in ipairs(cfg.bo_colls or {}) do
                          if type(e) == "table" and e.id then
                              items[#items + 1] = opt(e.title or tostring(e.id), "bo:" .. tostring(e.id))
                          end
                      end
                      if cfg.bo_show_new then
                          items[#items + 1] = opt(_("BookOrbit Newly Added"), "bo:new")
                      end
                  end
                  if cfg.tbr_panel_show_new ~= false then
                      items[#items + 1] = opt(_("Newly Added (device)"), "new")
                  end
                  items[#items + 1] = opt(_("History"), "history")
                  items[#items + 1] = opt(_("Last View"), "last")
                  if #items == 0 then
                      items[1] = { text = _("No views enabled"), enabled = false }
                  end
                  return items
              end,
              separator = true },

            -- History source (item omitted when BookOrbit is not installed)
            { text_func = function()
                  local src = cfg.history_source == "bookorbit" and _("BookOrbit") or _("Device")
                  return string.format(_("History: %s"), src)
              end,
              help_text = _("History icon in the panel: Device = KOReader reading history on this device; BookOrbit = recently read from your BookOrbit library."),
              enabled_func = function() return bookOrbitInstalled() end,
              sub_item_table_func = function()
                  return {
                      {
                          text = _("Device"),
                          radio = true,
                          checked_func = function() return cfg.history_source ~= "bookorbit" end,
                          callback = function()
                              cfg.history_source = "device"
                              saveConfig()
                          end,
                      },
                      {
                          text = _("BookOrbit"),
                          radio = true,
                          checked_func = function() return cfg.history_source == "bookorbit" end,
                          callback = function()
                              cfg.history_source = "bookorbit"
                              if type(boHistoryList) == "function" then pcall(boHistoryList) end
                              saveConfig()
                          end,
                      },
                  }
              end },

            -- 4. Local Collections (+ which local views appear in the panel)
            { text_func = function()
                  local n = #(cfg.tbr_panel_colls or {})
                  local parts = {}
                  if cfg.tbr_panel_show_tbr ~= false then parts[#parts + 1] = _("TBR") end
                  if cfg.tbr_panel_show_new ~= false then parts[#parts + 1] = _("New") end
                  if n > 0 then parts[#parts + 1] = string.format(_("%d coll"), n) end
                  local suffix = #parts > 0 and (" · " .. table.concat(parts, ", ")) or ""
                  return _("Local Collections") .. suffix
              end,
              help_text = _("Choose which on-device lists appear when you swipe in the panel: To Be Read, Newly Added, and any KOReader collections you pick."),
              sub_item_table_func = function()
                  local items = {
                      { text = _("To Be Read"),
                        checked_func = function() return cfg.tbr_panel_show_tbr ~= false end,
                        keep_menu_open = true,
                        callback = function()
                            cfg.tbr_panel_show_tbr = not (cfg.tbr_panel_show_tbr ~= false)
                            clampOpensToSetting()
                            saveConfig()
                        end },
                      { text = _("Newly Added (device)"),
                        checked_func = function() return cfg.tbr_panel_show_new ~= false end,
                        keep_menu_open = true,
                        callback = function()
                            cfg.tbr_panel_show_new = not (cfg.tbr_panel_show_new ~= false)
                            clampOpensToSetting()
                            saveConfig()
                        end,
                        separator = true },
                  }
                  local names = allCollectionNames()
                  if #names == 0 then
                      items[#items + 1] = { text = _("No other collections yet"), enabled = false }
                  else
                      for _i, name in ipairs(names) do
                          items[#items + 1] = {
                              text = collLabel(name),
                              checked_func = function() return isCollPicked(name) end,
                              keep_menu_open = true,
                              callback = function()
                                  local list, out, found = cfg.tbr_panel_colls or {}, {}, false
                                  for _j, n in ipairs(list) do
                                      if n == name then found = true else out[#out + 1] = n end
                                  end
                                  if not found then out[#out + 1] = name end
                                  cfg.tbr_panel_colls = out
                                  clampOpensToSetting()
                                  saveConfig()
                              end,
                          }
                      end
                  end
                  return items
              end },

            -- 5. BookOrbit Collections (disabled / hidden when plugin missing)
            { text_func = function()
                  local n = #(cfg.bo_colls or {})
                  local parts = {}
                  if cfg.bo_show_new then parts[#parts + 1] = _("New") end
                  if n > 0 then parts[#parts + 1] = string.format(_("%d coll"), n) end
                  local suffix = #parts > 0 and (" · " .. table.concat(parts, ", ")) or ""
                  return _("BookOrbit Collections") .. suffix
              end,
              enabled_func = function() return bookOrbitInstalled() end,
              help_text = _("BookOrbit lists in the panel. Only books already on this device are shown. Use Refresh List after signing in or adding collections on the server."),
              sub_item_table_func = function()
                  local items = {
                      { text = _("BookOrbit Newly Added"),
                        checked_func = function() return cfg.bo_show_new == true end,
                        keep_menu_open = true,
                        callback = function()
                            cfg.bo_show_new = not cfg.bo_show_new
                            if cfg.bo_show_new then pcall(boNewList) end
                            clampOpensToSetting()
                            saveConfig()
                        end,
                        separator = true },
                  }
                  local list = loadBoCache(BO_COLLS_CACHE_KEY)
                  if #list == 0 then
                      items[#items + 1] = { text = _("No Collections Cached — Tap Refresh"), enabled = false }
                  else
                      for _i, entry in ipairs(list) do
                          local id, title = entry.id, entry.title or tostring(entry.id)
                          items[#items + 1] = {
                              text = title,
                              checked_func = function() return isBoPicked(id) end,
                              keep_menu_open = true,
                              callback = function()
                                  local cur, out, found = cfg.bo_colls or {}, {}, false
                                  for _j, e in ipairs(cur) do
                                      if type(e) == "table" and (tonumber(e.id) or e.id) == (tonumber(id) or id) then
                                          found = true
                                      else
                                          out[#out + 1] = e
                                      end
                                  end
                                  if not found then
                                      out[#out + 1] = { id = id, title = title }
                                      pcall(fetchBoEntries, "coll:" .. tostring(id), { collectionId = id }, true)
                                  end
                                  cfg.bo_colls = out
                                  clampOpensToSetting()
                                  saveConfig()
                              end,
                          }
                      end
                  end
                  items[#items + 1] = {
                      text = _("Refresh List"),
                      callback = function(touchmenu_instance)
                          local InfoMessage = require("ui/widget/infomessage")
                          local UIManager = require("ui/uimanager")
                          local list2, err = fetchBoCollections()
                          if not list2 then
                              UIManager:show(InfoMessage:new{
                                  text = _("Could not load BookOrbit collections.")
                                      .. (err and ("\n" .. tostring(err)) or ""),
                                  timeout = 3,
                              })
                              return
                          end
                          local ids = {}
                          for _i, e in ipairs(list2) do ids[tostring(e.id)] = e end
                          local kept = {}
                          for _i, e in ipairs(cfg.bo_colls or {}) do
                              local hit = ids[tostring(e and e.id)]
                              if hit then kept[#kept + 1] = { id = hit.id, title = hit.title } end
                          end
                          cfg.bo_colls = kept
                          clampOpensToSetting()
                          saveConfig()
                          UIManager:show(InfoMessage:new{
                              text = string.format(_("Loaded %d BookOrbit collections."), #list2),
                              timeout = 2,
                          })
                          if touchmenu_instance and touchmenu_instance.updateItems then
                              touchmenu_instance:updateItems()
                          end
                      end,
                  }
                  return items
              end },
    }

    -- Drop BookOrbit-only entries when the plugin is not installed
    local out = {}
    for _i, item in ipairs(items) do
        local needs_bo = item.enabled_func == bookOrbitInstalled
        if needs_bo and not bookOrbitInstalled() then
            -- skip
        else
            out[#out + 1] = item
        end
    end
    return {
        text = _("SimpleUI Side Panel"),
        sub_item_table = out,
    }
end


-- ---- Tools menu (same pattern as SimpleUI Tweaks / tweaks-menu) --------------------
local function addToOrder(order_mod)
    local ok, order = pcall(require, order_mod)
    if not ok or type(order) ~= "table" or type(order.tools) ~= "table" then return end
    for _i, v in ipairs(order.tools) do
        if v == "simpleui_sidepanel" then return end
    end
    local pos = #order.tools + 1
    for i, v in ipairs(order.tools) do
        if type(v) == "string" and v:find("^%-%-%-") then pos = i break end
    end
    table.insert(order.tools, pos, "simpleui_sidepanel")
end

local function lazyMenu()
    local menu = buildMenu()
    menu.sorting_hint = "tools"
    return menu
end

-- Appears under Tools > Add-ons when 2-tweaks-menu.lua is installed
local TM = package.loaded.tweaks_mods or {}
package.loaded.tweaks_mods = TM
TM.entries = TM.entries or {}
TM.entries.simpleui_sidepanel = {
    text  = "SimpleUI Side Panel",
    where = "filemanager",
    build = lazyMenu,
}

local function hookMenu(menu_mod, order_mod)
    local ok, Menu = pcall(require, menu_mod)
    if not ok or type(Menu) ~= "table" or type(Menu.setUpdateItemTable) ~= "function" then return end
    if Menu._simpleui_sidepanel_hooked then return end
    Menu._simpleui_sidepanel_hooked = true
    local orig = Menu.setUpdateItemTable
    Menu.setUpdateItemTable = function(self, ...)
        -- Always register into Tools so the entry is findable whether or not
        -- 2-tweaks-menu.lua is grouping items under Add-ons.
        if type(self.menu_items) == "table" then
            pcall(addToOrder, order_mod)
            self.menu_items.simpleui_sidepanel = lazyMenu()
        end
        return orig(self, ...)
    end
end

pcall(hookMenu, "apps/filemanager/filemanagermenu", "ui/elements/filemanager_menu_order")
pcall(hookMenu, "apps/reader/readermenu", "ui/elements/reader_menu_order")

package.loaded.simpleui_sidepanel = {
    name = "simpleui_sidepanel",
    version = VERSION,
    onHomeShow = onHomeShow,
}

logger.info(TAG, "========== v" .. VERSION .. " LOADED ==========")
