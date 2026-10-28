--[[
2-bookorbit-tweaks.lua
BookOrbit Tweaks for current BookOrbit KOReader plugin (plugin 2.0 / server 3.5+).

Install this file in KOReader/patches/ and restart KOReader.

Purpose:
  * Keep BookOrbit cover artwork from being inverted by KOReader Night Mode,
    in both the catalog grid (ImageWidget) and the dashboard / list / detail
    covers (BoardCover, which paints straight into the framebuffer).
  * Bring the BookOrbit catalog back to the front when it is already open
    but buried (for example under the SimpleUI home screen after waking
    from sleep), instead of "Open BookOrbit" doing nothing.
  * The SimpleUI nav tap for BookOrbit does the same (it used to do nothing
    while a buried catalog existed).
  * Option: reopen an already-open catalog at BookOrbit home, or where you
    left off.
  * Option: when BookOrbit closes and SimpleUI home is gone, show SimpleUI
    home instead of the stock library.
  * Optional e-ink flash on catalog page turns to reduce ghosting.
  * Option: loop catalog pages (swipe past last page → first, past first → last).
    When looping is off, a swipe at either end is a no-op and does not flash.
  * Saved servers: snapshot the current BookOrbit login and switch between
    them later (from Tweaks menu, Sign-in, or Settings → Account → Server).
  * Loop also wraps the dashboard board pages (Home / Insights / Library / Decor).
  * Persistent library filter: choose which BookOrbit library is shown (e.g. Books, not Comics).
  * Option: change the Continue reading Resume pill colour (Tools > BookOrbit Tweaks > Resume Pill Colour).
  * Add a separate BookOrbit Tweaks submenu to Tools (or the Add-ons menu
    supplied by 2-tweaks-menu.lua).

This patch hooks the real current module, bookorbit_catalog_widgets.
It does not alter BookOrbit sync, downloads, metadata, or reading progress.
]]

local VERSION = "2.14.1"
local TAG = "bookorbit-tweaks " .. VERSION .. ":"
local SETTINGS_KEY = "bookorbit_tweaks"
local MENU_ID = "bookorbit_tweaks"

local logger = require("logger")
local _ = require("gettext")

-- Prevent duplicate wrapping if the patch was copied to two patch files.
if package.loaded["bookorbit_tweaks_patch_v2"] then
    logger.warn(TAG, "duplicate patch skipped")
    return
end
package.loaded["bookorbit_tweaks_patch_v2"] = true

local DEFAULTS = {
    keep_covers_original_in_nightmode = true,
    flash_ghosting = false,
    flash_every = 1,
    -- What to flash when Enable Flash is on (each is independent):
    flash_page_turns = true,   -- catalog / dashboard page swipes
    flash_content = true,      -- library / recent / section rebuilds
    flash_dashboard = true,    -- return to dashboard from library/recent
    flash_menu_sheet = true,   -- pull-down settings open + close
    flash_open = true,         -- single flash when BookOrbit opens
    loop_pages = false,
    second_swipe_tools = true, -- second south swipe on settings sheet -> tools menu
    reopen_at = "last",
    resume_pill_color = "#FFFFFF",
    after_close = "simpleui",
    library_filter_id = false,
    library_filter_name = "",
    server_chooser_in_settings = true,
}

local cfg = {}
for key, value in pairs(DEFAULTS) do
    cfg[key] = value
end

do
    local saved = G_reader_settings and G_reader_settings:readSetting(SETTINGS_KEY)
    if type(saved) == "table" then
        for key, value in pairs(saved) do
            if DEFAULTS[key] ~= nil then
                cfg[key] = value
            end
        end
    end
    -- Menu option removed: always restore SimpleUI home when BookOrbit closes.
    cfg.after_close = "simpleui"
end

local function saveConfig()
    if not G_reader_settings then return end
    G_reader_settings:saveSetting(SETTINGS_KEY, cfg)
    if G_reader_settings.flush then
        pcall(G_reader_settings.flush, G_reader_settings)
    end
end

-- ---- Saved BookOrbit servers (multi-profile) ---------------------------------------
-- Stores named snapshots of bookorbit credentials so you can switch between
-- servers without re-typing. Switching writes into the real "bookorbit"
-- settings key; reopen BookOrbit (or restart KOReader) to apply.
local SERVERS_KEY = "bookorbit_tweaks_servers"

local function loadServers()
    local list = G_reader_settings and G_reader_settings:readSetting(SERVERS_KEY)
    if type(list) ~= "table" then return {} end
    return list
end

local function saveServers(list)
    if not G_reader_settings then return end
    G_reader_settings:saveSetting(SERVERS_KEY, list)
    if G_reader_settings.flush then
        pcall(G_reader_settings.flush, G_reader_settings)
    end
end

local function currentBookOrbitCreds()
    local s = G_reader_settings and G_reader_settings:readSetting("bookorbit")
    if type(s) ~= "table" then return nil end
    if not s.server_url or not s.username or not s.userkey then return nil end
    return {
        server_url = s.server_url,
        username = s.username,
        userkey = s.userkey,
    }
end

local function applyBookOrbitCreds(creds)
    if type(creds) ~= "table" or not creds.server_url then return false end
    local s = G_reader_settings:readSetting("bookorbit") or {}
    s.server_url = creds.server_url
    s.username = creds.username
    s.userkey = creds.userkey
    G_reader_settings:saveSetting("bookorbit", s)
    if G_reader_settings.flush then
        pcall(G_reader_settings.flush, G_reader_settings)
    end
    return true
end

local function serverLabel(entry)
    if type(entry) ~= "table" then return "?" end
    if type(entry.label) == "string" and entry.label:match("%S") then
        return entry.label
    end
    local host = tostring(entry.server_url or ""):gsub("^https?://", ""):gsub("/api/v1/?$", ""):gsub("/$", "")
    local user = entry.username or ""
    if host == "" then host = "?" end
    if user ~= "" then return host .. "  (" .. user .. ")" end
    return host
end

local function isEnabled()
    return cfg.keep_covers_original_in_nightmode == true
end

local function toggle()
    cfg.keep_covers_original_in_nightmode = not isEnabled()
    saveConfig()
    logger.info(TAG, "keep covers original in Night Mode =", isEnabled())
end

-- Recursively visit numeric widget children. KOReader widget containers keep
-- their child widgets in the array portion of the widget table.
local function markCoverImages(widget, depth, visited)
    if type(widget) ~= "table" or depth < 0 then return 0 end
    visited = visited or {}
    if visited[widget] then return 0 end
    visited[widget] = true

    local changed = 0
    -- ImageWidget uses `file` for file-backed artwork. Only mark actual image
    -- widgets, not arbitrary containers or the title/icon widgets around them.
    if type(widget.file) == "string" and widget.scale_factor ~= nil then
        widget.original_in_nightmode = isEnabled()
        changed = changed + 1
    end

    if depth > 0 then
        for i = 1, #widget do
            changed = changed + markCoverImages(widget[i], depth - 1, visited)
        end
    end
    return changed
end

local hooked_functions = setmetatable({}, { __mode = "k" })
local function hookCatalogWidgets()
    local widgets = package.loaded["bookorbit_catalog_widgets"]
    if type(widgets) ~= "table" then
        local ok, loaded = pcall(require, "bookorbit_catalog_widgets")
        if ok and type(loaded) == "table" then
            widgets = loaded
        end
    end

    if type(widgets) ~= "table" or type(widgets.buildCoverWidget) ~= "function" then
        return false
    end

    local original = widgets.buildCoverWidget
    if hooked_functions[original] then return true end
    hooked_functions[original] = true

    widgets.buildCoverWidget = function(...)
        local widget = original(...)
        if type(widget) == "table" then
            markCoverImages(widget, 8)
        end
        return widget
    end

    logger.info(TAG, "hooked BookOrbit catalog cover builder")
    return true
end

-- Dashboard, list, detail and dialog covers are BoardCover widgets. They blit
-- the image straight into the framebuffer, so KOReader's screen-wide Night Mode
-- inverts them. Plugin builds before the upstream fix (9d1319ef, Oct 21 2026)
-- never counter-invert them. BoardCover is a local in bookorbit_board_ui, so
-- the class is reached through an instance (an instance's metatable is its class).
--
-- paintTo is run against a proxy buffer that remembers where the cover image was
-- blitted. After the image (and any dim/lighten film) is down, and before the
-- border, that rect is inverted once so the screen-wide invert restores the
-- original colors. If the plugin already inverts the rect itself (a fixed
-- build), the proxy sees that and does nothing, so no double inversion.
local function hookBoardCover()
    local ok_ui, BoardUI = pcall(require, "bookorbit_board_ui")
    if not ok_ui or type(BoardUI) ~= "table" or type(BoardUI.cover) ~= "function" then
        return false
    end
    local ok_probe, probe = pcall(BoardUI.cover, {}, 1, 1, { path = "__bookorbit_tweaks_probe__" })
    if not ok_probe or type(probe) ~= "table" then return false end
    local class = getmetatable(probe)
    if type(class) ~= "table" or type(class.paintTo) ~= "function" then return false end
    if class._bookorbit_tweaks_board_hooked then return true end
    class._bookorbit_tweaks_board_hooked = true

    local ok_dev, Device = pcall(require, "device")
    local Screen = ok_dev and Device and Device.screen
    if not Screen then return false end

    local original = class.paintTo
    class.paintTo = function(self, bb, x, y)
        if not isEnabled() or not Screen.night_mode then
            return original(self, bb, x, y)
        end

        local rect, flushed, native = nil, false, false
        local function flush()
            if rect and not flushed and not native then
                flushed = true
                bb:invertRect(rect[1], rect[2], rect[3], rect[4])
            end
        end

        local proxy = setmetatable({}, {
            __index = function(_, key)
                local value = bb[key]
                if type(value) ~= "function" then return value end
                if key == "blitFrom" then
                    return function(_, src, dx, dy, ox, oy, w, h)
                        rect = { dx, dy, w, h }
                        return value(bb, src, dx, dy, ox, oy, w, h)
                    end
                elseif key == "invertRect" then
                    return function(_, ...)
                        native = true
                        return value(bb, ...)
                    end
                elseif key == "paintBorder" then
                    return function(_, ...)
                        flush()
                        return value(bb, ...)
                    end
                end
                return function(_, ...) return value(bb, ...) end
            end,
        })

        local ok, err = pcall(original, self, proxy, x, y)
        flush()
        if not ok then error(err, 0) end
    end

    logger.info(TAG, "hooked BookOrbit board cover painter")
    return true
end

-- ---- Continue reading hero card in night mode --------------------------------
-- Night mode only; day mode is untouched (the wrapper paints the tile
-- normally and returns). The hero tile is the only black-fill tile on
-- the board (chrome "ink"). KOReader night mode inverts the whole
-- screen, so every white tile becomes black with white text (which
-- looks right) while the black hero becomes white with black text
-- (which does not). Covers escape this because they are
-- counter-inverted at paint time; tile backgrounds have no such step.
-- This wraps the hero tile's paint: in night mode only, after the tile
-- is painted normally, its whole rectangle is inverted once, so the
-- screen-wide flip restores black background + white text. The cover
-- is then inverted once more (see below), the four corner squares
-- are repainted with the board background, and a black-in-buffer
-- border is painted (white on screen) so the black card does not
-- blend into the black board.
-- Cover handling, two sources, in order: (1) rects the inner paint
-- itself counter-inverted (BoardCover's invertRect, recorded through
-- a proxy buffer); (2) if none were recorded, the cover widget's
-- own dimen, which BoardCover.paintTo sets to its absolute position.
-- Round 2 relied on (1) alone and the cover still came out inverted
-- on-device, so (2) is the fallback and both counts are logged.
local function hookHeroNight()
    local ok_bw, BoardWidgets = pcall(require, "bookorbit_board_widgets")
    if not ok_bw or type(BoardWidgets) ~= "table" or type(BoardWidgets.tile) ~= "function" then
        return false
    end
    if BoardWidgets._bookorbit_tweaks_hero_night then return true end
    BoardWidgets._bookorbit_tweaks_hero_night = true

    local ok_dev, Device = pcall(require, "device")
    local Screen = ok_dev and Device and Device.screen
    if not Screen then return false end
    local ok_w, Widget = pcall(require, "ui/widget/widget")
    if not ok_w or type(Widget) ~= "table" then return false end
    local ok_geom, Geom = pcall(require, "ui/geometry")
    if not ok_geom or type(Geom) ~= "table" then return false end
    local ok_bb, Blitbuffer = pcall(require, "ffi/blitbuffer")
    if not ok_bb or type(Blitbuffer) ~= "table" then return false end
    local ok_met, BoardMetrics = pcall(require, "bookorbit_board_metrics")
    local radius = 12
    if ok_met and type(BoardMetrics) == "table" and type(BoardMetrics.px) == "function" then
        radius = BoardMetrics.px(12)
    end

    local function collectCoverDimens(root)
        local out, seen = {}, {}
        local function walk(node, depth)
            if type(node) ~= "table" or seen[node] or depth > 12 then return end
            seen[node] = true
            local d = node.dimen
            if type(node.path) == "string" and type(d) == "table"
                    and type(d.x) == "number" and type(d.y) == "number"
                    and type(d.w) == "number" and type(d.h) == "number"
                    and d.w >= 20 and d.h >= 20 then
                table.insert(out, { d.x, d.y, d.w, d.h })
            end
            for _k, v in pairs(node) do
                if type(v) == "table" then walk(v, depth + 1) end
            end
        end
        walk(root, 0)
        return out
    end

    local HeroNightWidget = Widget:extend{}
    function HeroNightWidget:getSize()
        return self.dimen
    end
    function HeroNightWidget:paintTo(bb, x, y)
        if not Screen.night_mode then
            self.inner:paintTo(bb, x, y)
            return
        end
        local cover_rects = {}
        local proxy = setmetatable({}, {
            __index = function(_, key)
                local value = bb[key]
                if type(value) ~= "function" then return value end
                if key == "invertRect" then
                    return function(_, rx, ry, rw, rh)
                        table.insert(cover_rects, { rx, ry, rw, rh })
                        return value(bb, rx, ry, rw, rh)
                    end
                end
                return function(_, ...) return value(bb, ...) end
            end,
        })
        self.inner:paintTo(proxy, x, y)
        local dimen_rects = collectCoverDimens(self.inner)
        local w, h = self.dimen.w, self.dimen.h
        bb:invertRect(x, y, w, h)
        local reverted = cover_rects
        if #reverted == 0 then reverted = dimen_rects end
        for _i, r in ipairs(reverted) do
            bb:invertRect(r[1], r[2], r[3], r[4])
        end
        logger.info(TAG, "hero night: proxy cover rects=", #cover_rects, "dimen cover rects=", #dimen_rects)
        bb:paintRect(x, y, radius, radius, Blitbuffer.COLOR_WHITE)
        bb:paintRect(x + w - radius, y, radius, radius, Blitbuffer.COLOR_WHITE)
        bb:paintRect(x, y + h - radius, radius, radius, Blitbuffer.COLOR_WHITE)
        bb:paintRect(x + w - radius, y + h - radius, radius, radius, Blitbuffer.COLOR_WHITE)
        local bw = 2
        if ok_met and type(BoardMetrics) == "table" and type(BoardMetrics.px) == "function" then
            bw = math.max(1, BoardMetrics.px(1.5))
        end
        bb:paintBorder(x, y, w, h, bw, Blitbuffer.COLOR_BLACK, radius)
    end

    local original_tile = BoardWidgets.tile
    BoardWidgets.tile = function(ctx, item, w, h)
        local result = original_tile(ctx, item, w, h)
        if type(item) ~= "table" or item.type ~= "hero" or type(result) ~= "table" then
            return result
        end
        return HeroNightWidget:new{
            dimen = Geom:new{ w = w, h = h },
            inner = result,
        }
    end
    logger.info(TAG, "hooked BookOrbit hero tile for night mode")
    return true
end

-- ---- Wake fix: raise an already-open catalog ---------------------------------------
-- BookOrbit's openCatalogBrowser returns at once when a catalog already exists,
-- and its "BookOrbitOpenDashboard" event (the SimpleUI nav tab, gestures) only
-- acts when the catalog is already the topmost window. After sleep, another
-- window (the SimpleUI home screen) can sit on top of the catalog, so both did
-- nothing. Move the catalog back to the top of the window stack instead.
-- Returns true when it moved the catalog, false when it was already on top.
local function isBookOrbitWidget(w)
    if type(w) ~= "table" then return false end
    local n = w.name
    local t = w.title
    -- Menu sheets sit above the catalog; treat them as related for wipe, not raise.
    if type(n) == "string" and n:find("menu_sheet", 1, true) then return false end
    if type(n) == "string" and (n:find("dialog", 1, true) or n:find("toast", 1, true)) then
        return false
    end
    -- Diagnostics show title as "BookOrbit catalog" (not plain "BookOrbit").
    if type(t) == "string" and t:find("BookOrbit", 1, true) then return true end
    if n == "BookOrbit" then return true end
    if type(n) == "string" and n:lower():find("bookorbit", 1, true) then return true end
    return false
end

local function isBookOrbitRelated(w)
    if type(w) ~= "table" then return false end
    local n = w.name
    local t = w.title
    if type(t) == "string" and t:find("BookOrbit", 1, true) then return true end
    if type(n) == "string" and n:lower():find("bookorbit", 1, true) then return true end
    return false
end

-- Find the BookOrbit catalog entry on the window stack (by identity or name).
local function findCatalogOnStack(catalog)
    local ok, UIManager = pcall(require, "ui/uimanager")
    if not ok or type(UIManager) ~= "table" or type(UIManager._window_stack) ~= "table" then
        return nil, nil, nil
    end
    local stack = UIManager._window_stack
    local top
    if type(UIManager.getTopmostVisibleWidget) == "function" then
        local ok_top, w = pcall(UIManager.getTopmostVisibleWidget, UIManager)
        if ok_top then top = w end
    end
    if top == nil and stack[#stack] then top = stack[#stack].widget end
    local idx
    for i = 1, #stack do
        local w = stack[i] and stack[i].widget
        if (catalog and w == catalog) or isBookOrbitWidget(w) then
            idx = i
            break
        end
    end
    return idx, stack, UIManager
end

-- Returns: "top", "buried", "missing"
local function catalogStackState(catalog)
    local idx, stack, UIManager = findCatalogOnStack(catalog)
    if not idx then return "missing", UIManager end
    if idx == #stack then return "top", UIManager end
    -- Ignore toasts/modals above when deciding "top enough"
    local only_transient_above = true
    for i = idx + 1, #stack do
        local w = stack[i] and stack[i].widget
        local transient = type(w) == "table" and (
            w.modal or (type(w.name) == "string" and (
                w.name:find("toast", 1, true) or w.name:find("InfoMessage", 1, true)
            ))
        )
        if not transient then only_transient_above = false break end
    end
    if only_transient_above then return "top", UIManager end
    return "buried", UIManager
end

local function raiseCatalogWindow(catalog)
    local idx, stack, UIManager = findCatalogOnStack(catalog)
    if not idx or not stack or not UIManager then return false, nil end
    local widget = stack[idx] and stack[idx].widget
    if idx == #stack then
        -- Already top: still force a repaint in case SimpleUI drew over it.
        pcall(function() UIManager:setDirty(widget or "all", "full") end)
        return false, widget
    end
    local entry = table.remove(stack, idx)
    table.insert(stack, entry)
    widget = entry and entry.widget
    -- Close SimpleUI home so it cannot sit above BookOrbit again after sleep.
    local to_close = {}
    for i = 1, #stack do
        local w = stack[i] and stack[i].widget
        if type(w) == "table" and w ~= widget and (
            w.name == "homescreen"
            or (type(w.name) == "string" and w.name:find("homescreen", 1, true))
        ) then
            table.insert(to_close, w)
        end
    end
    for _i, w in ipairs(to_close) do
        pcall(function() UIManager:close(w) end)
    end
    pcall(function()
        if widget then UIManager:show(widget) end
        UIManager:setDirty("all", "full")
    end)
    logger.info(TAG, "raised buried BookOrbit catalog to the top")
    return true, widget
end

-- Raise any BookOrbit window on the stack; used when plugin.catalog_browser is nil
-- on the instance that received the nav event.
local function raiseAnyBookOrbitWindow()
    local ok, widget = raiseCatalogWindow(nil)
    return ok, widget
end

-- Close every BookOrbit catalog widget on the stack and clear plugin refs.
-- Used after sleep so the next nav/shortcut open is always a clean open.
local function closeAllBookOrbitCatalogs(reason)
    local ok_ui, UIManager = pcall(require, "ui/uimanager")
    if not ok_ui or type(UIManager) ~= "table" then return 0 end
    local stack = UIManager._window_stack
    if type(stack) ~= "table" then return 0 end
    local closed = 0
    local to_close = {}
    -- Close top-down so menu sheets go before the catalog under them.
    for i = #stack, 1, -1 do
        local w = stack[i] and stack[i].widget
        if isBookOrbitRelated(w) then
            table.insert(to_close, w)
        end
    end
    for _i, w in ipairs(to_close) do
        pcall(function() UIManager:close(w) end)
        closed = closed + 1
    end
    -- Clear catalog_browser on both FileManager and Reader instances.
    local function clearPlugin(ui_mod, key)
        local M = package.loaded[ui_mod]
        local inst = type(M) == "table" and M.instance
        if type(inst) ~= "table" then return end
        local p = inst[key] or inst.bookorbit or inst.BookOrbit
        if type(p) == "table" then
            p.catalog_browser = nil
        end
    end
    clearPlugin("apps/filemanager/filemanager", "bookorbit")
    clearPlugin("apps/reader/readerui", "bookorbit")
    if closed > 0 then
        logger.info(TAG, "TRACE closeAllBookOrbitCatalogs:", reason or "?", "closed=", closed)
    end
    return closed
end

-- Nuclear open: close any leftover catalog, then open fresh via the live plugin.
local function forceOpenBookOrbit(reason)
    logger.info(TAG, "TRACE forceOpenBookOrbit:", reason or "?")
    closeAllBookOrbitCatalogs(reason or "force-open")
    local FM = package.loaded["apps/filemanager/filemanager"]
    local fm = type(FM) == "table" and FM.instance
    local plugin = type(fm) == "table" and (fm.bookorbit or fm.BookOrbit)
    if type(plugin) ~= "table" then
        local RUI = package.loaded["apps/reader/readerui"]
        local reader = type(RUI) == "table" and RUI.instance
        plugin = type(reader) == "table" and (reader.bookorbit or reader.BookOrbit)
    end
    if type(plugin) ~= "table" then
        logger.warn(TAG, "TRACE forceOpenBookOrbit: no plugin instance")
        return false
    end
    plugin.catalog_browser = nil
    local opened = false
    if type(plugin.browseCatalog) == "function" then
        local ok, err = pcall(plugin.browseCatalog, plugin, false)
        logger.info(TAG, "TRACE forceOpenBookOrbit browseCatalog ok=", ok, "err=", err)
        opened = ok and true or false
    elseif type(plugin.openBookOrbit) == "function" then
        local ok, err = pcall(plugin.openBookOrbit, plugin)
        logger.info(TAG, "TRACE forceOpenBookOrbit openBookOrbit ok=", ok, "err=", err)
        opened = ok and true or false
    else
        logger.warn(TAG, "TRACE forceOpenBookOrbit: no browseCatalog/openBookOrbit")
        return false
    end
    -- After open, SimpleUI home often remains on the stack and can paint over
    -- the new catalog. Close it and force the catalog to the top with a full refresh.
    if opened then
        local ok_ui, UIManager = pcall(require, "ui/uimanager")
        if ok_ui and type(UIManager) == "table" then
            local stack = UIManager._window_stack
            if type(stack) == "table" then
                local homes = {}
                for i = 1, #stack do
                    local w = stack[i] and stack[i].widget
                    if type(w) == "table" and (
                        w.name == "homescreen"
                        or (type(w.name) == "string" and w.name:find("homescreen", 1, true))
                    ) then
                        table.insert(homes, w)
                    end
                end
                for _i, w in ipairs(homes) do
                    pcall(function() UIManager:close(w) end)
                end
            end
            raiseAnyBookOrbitWindow()
            if cfg.flash_ghosting and cfg.flash_open then
                pcall(function() UIManager:setDirty("all", "flashui") end)
            else
                pcall(function() UIManager:setDirty("all", "ui") end)
            end
            logger.info(TAG, "TRACE forceOpenBookOrbit: closed home + raised catalog")
        end
    end
    return opened
end

-- Global open intercept: Dispatcher + UIManager events.

-- Flash when the BookOrbit settings/menu sheet closes (swipe back up).
local function hookMenuSheetCloseFlash()
    if package.loaded.bookorbit_tweaks_menu_close_flash then return true end
    local ok, UIManager = pcall(require, "ui/uimanager")
    if not ok or type(UIManager) ~= "table" or type(UIManager.close) ~= "function" then
        return false
    end
    package.loaded.bookorbit_tweaks_menu_close_flash = true
    local original_close = UIManager.close
    UIManager.close = function(self, widget, ...)
        local is_sheet = type(widget) == "table" and type(widget.name) == "string"
                and widget.name:find("bookorbit_menu_sheet", 1, true)
        local res = original_close(self, widget, ...)
        if is_sheet and cfg.flash_ghosting and cfg.flash_menu_sheet then
            pcall(function()
                UIManager:setDirty("all", "flashui")
            end)
        end
        return res
    end
    return true
end
hookMenuSheetCloseFlash()

local function hookDispatcherOpen()
    if package.loaded.bookorbit_tweaks_dispatcher_hooked then return true end
    package.loaded.bookorbit_tweaks_dispatcher_hooked = true

    local ok, Dispatcher = pcall(require, "dispatcher")
    if ok and type(Dispatcher) == "table" and type(Dispatcher.execute) == "function" then
        local original = Dispatcher.execute
        Dispatcher.execute = function(self, action_id, ...)
            if action_id == "bookorbit_open_dashboard" then
                logger.info(TAG, "TRACE Dispatcher.execute bookorbit_open_dashboard")
                -- After sleep the catalog is often buried under SimpleUI home and
                -- the normal early-return path does nothing. Always force a clean open.
                forceOpenBookOrbit("dispatcher")
                return true
            end
            return original(self, action_id, ...)
        end
        logger.info(TAG, "hooked Dispatcher.execute for BookOrbit open")
    end

    local ok_ui, UIManager = pcall(require, "ui/uimanager")
    if ok_ui and type(UIManager) == "table" and type(UIManager.sendEvent) == "function"
            and not UIManager._bookorbit_tweaks_sendevent then
        UIManager._bookorbit_tweaks_sendevent = true
        local original_send = UIManager.sendEvent
        UIManager.sendEvent = function(self, event, ...)
            local name = type(event) == "table" and event.name
            if name == "BookOrbitOpenDashboard" then
                logger.info(TAG, "TRACE UIManager.sendEvent BookOrbitOpenDashboard")
                forceOpenBookOrbit("sendEvent")
                return true
            end
            -- Second swipe south while BookOrbit settings sheet is top -> tools menu.
            -- Intercept here because the sheet's children often consume Swipe before
            -- our instance onSwipe runs.
            if cfg.second_swipe_tools and (name == "Swipe" or name == "Gesture") then
                local stack = self._window_stack
                local top = type(stack) == "table" and stack[#stack]
                local w = top and top.widget
                local is_sheet = type(w) == "table" and type(w.name) == "string"
                        and w.name:find("bookorbit_menu_sheet", 1, true)
                if is_sheet then
                    local a = event.args
                    local ges = type(a) == "table" and (a[2] or a[1]) or nil
                    if type(ges) ~= "table" and name == "Gesture" then
                        ges = a and a[1] or event
                    end
                    if type(ges) == "table" and ges.direction == "south" then
                        logger.info(TAG, "sendEvent south on menu sheet -> tools menu")
                        pcall(function() self:close(w) end)
                        local FM = package.loaded["apps/filemanager/filemanager"]
                        local fm = type(FM) == "table" and FM.instance
                        local menu = type(fm) == "table" and fm.menu
                        if type(menu) == "table" and type(menu.onShowMenu) == "function" then
                            pcall(menu.onShowMenu, menu)
                        end
                        return true
                    end
                end
            end
            return original_send(self, event, ...)
        end
        logger.info(TAG, "hooked UIManager.sendEvent for BookOrbitOpenDashboard + second swipe")
    end

    -- Resume/Suspend: wipe BookOrbit so SimpleUI home cannot bury a live catalog.
    -- Hook both broadcastEvent and event_handlers.Resume (Kobo uses both paths).
    if ok_ui and type(UIManager) == "table" and type(UIManager.broadcastEvent) == "function"
            and not UIManager._bookorbit_tweaks_resume_broadcast then
        UIManager._bookorbit_tweaks_resume_broadcast = true
        local original_broadcast = UIManager.broadcastEvent
        UIManager.broadcastEvent = function(self, event, ...)
            local name = type(event) == "table" and event.name or event
            if name == "Suspend" or name == "Resume" then
                logger.info(TAG, "TRACE broadcastEvent", tostring(name), "- wiping BookOrbit")
                pcall(closeAllBookOrbitCatalogs, tostring(name))
            end
            local res = original_broadcast(self, event, ...)
            if name == "Resume" then
                pcall(function()
                    self:nextTick(function()
                        closeAllBookOrbitCatalogs("resume-nextTick")
                    end)
                    -- One more pass after SimpleUI shows home.
                    self:scheduleIn(0.5, function()
                        closeAllBookOrbitCatalogs("resume-0.5s")
                    end)
                end)
            end
            return res
        end
        logger.info(TAG, "hooked UIManager.broadcastEvent for Suspend/Resume wipe")
    end

    if ok_ui and type(UIManager) == "table" and type(UIManager.event_handlers) == "table" then
        local handlers = UIManager.event_handlers
        if type(handlers.Resume) == "function" and not handlers._bookorbit_tweaks_resume then
            handlers._bookorbit_tweaks_resume = true
            local original_resume_handler = handlers.Resume
            handlers.Resume = function(...)
                logger.info(TAG, "TRACE event_handlers.Resume - wiping BookOrbit")
                pcall(closeAllBookOrbitCatalogs, "event_handlers.Resume")
                local res = original_resume_handler(...)
                pcall(function()
                    UIManager:nextTick(function()
                        closeAllBookOrbitCatalogs("handler-nextTick")
                    end)
                end)
                return res
            end
            logger.info(TAG, "hooked UIManager.event_handlers.Resume")
        end
        if type(handlers.Suspend) == "function" and not handlers._bookorbit_tweaks_suspend then
            handlers._bookorbit_tweaks_suspend = true
            local original_suspend_handler = handlers.Suspend
            handlers.Suspend = function(...)
                logger.info(TAG, "TRACE event_handlers.Suspend - wiping BookOrbit")
                pcall(closeAllBookOrbitCatalogs, "event_handlers.Suspend")
                return original_suspend_handler(...)
            end
            logger.info(TAG, "hooked UIManager.event_handlers.Suspend")
        end
    end
    return true
end

-- "Reopen BookOrbit at": only applies when a catalog that is still open is
-- brought back (after sleep, from SimpleUI home, from Tools). A catalog opened
-- fresh always starts at BookOrbit's dashboard; BookOrbit keeps nothing to
-- restore once it is closed.
local function applyReopenMode(catalog)
    if cfg.reopen_at ~= "home" then return end
    if type(catalog.dashboardMode) == "function" and type(catalog.goDashboard) == "function"
            and not catalog:dashboardMode() then
        pcall(catalog.goDashboard, catalog)
    end
end

local function hookPluginOpen(plugin)
    if type(plugin) ~= "table" then return false end
    if plugin._bookorbit_tweaks_open_hooked then return true end
    plugin._bookorbit_tweaks_open_hooked = true

    local function ensureCatalogVisible(self)
        -- Post-sleep pollution: SimpleUI home and/or menu sheet above the
        -- catalog. Raising alone is not enough — force a clean open.
        local idx, stack = findCatalogOnStack(nil)
        if idx and stack then
            local polluted = false
            for i = idx + 1, #stack do
                local w = stack[i] and stack[i].widget
                if type(w) == "table" then
                    if w.name == "homescreen"
                            or (type(w.name) == "string" and w.name:find("homescreen", 1, true))
                            or isBookOrbitRelated(w) then
                        polluted = true
                        break
                    end
                end
            end
            if polluted then
                logger.info(TAG, "TRACE ensureCatalogVisible: stack polluted, forceOpen")
                forceOpenBookOrbit("ensure-visible")
                return true
            end
        end

        local raised, widget = raiseAnyBookOrbitWindow()
        if widget and self.catalog_browser == nil then
            self.catalog_browser = widget
        end
        if raised or widget then
            local catalog = self.catalog_browser or widget
            if catalog then pcall(applyReopenMode, catalog) end
            if raised then return true end
            if widget then return true end
        end
        local catalog = self.catalog_browser
        if catalog == nil then return false end
        local state = catalogStackState(catalog)
        if state == "top" then
            return true
        end
        if state == "missing" then
            logger.info(TAG, "stale BookOrbit catalog_browser after sleep; clearing for reopen")
            self.catalog_browser = nil
            return false
        end
        return false
    end

    local original_open = plugin.openCatalogBrowser
    if type(original_open) == "function" then
        plugin.openCatalogBrowser = function(self, ...)
            if ensureCatalogVisible(self) then
                return self.catalog_browser
            end
            return original_open(self, ...)
        end
    end

    local original_browse = plugin.browseCatalog
    if type(original_browse) == "function" then
        plugin.browseCatalog = function(self, ...)
            if ensureCatalogVisible(self) then
                return true
            end
            return original_browse(self, ...)
        end
    end

    -- Some toolbar / diagnostics paths call openBookOrbit if present.
    if type(plugin.openBookOrbit) == "function" and not plugin._bookorbit_tweaks_open_bo then
        plugin._bookorbit_tweaks_open_bo = true
        local original_bo = plugin.openBookOrbit
        plugin.openBookOrbit = function(self, ...)
            if ensureCatalogVisible(self) then
                return true
            end
            return original_bo(self, ...)
        end
    end

    -- SimpleUI nav tab / gesture: BookOrbitOpenDashboard
    local original_dashboard = plugin.onBookOrbitOpenDashboard
    if type(original_dashboard) == "function" then
        plugin.onBookOrbitOpenDashboard = function(self, ...)
            logger.info(TAG, "TRACE onBookOrbitOpenDashboard")
            -- If anything is above the catalog (home / menu sheet), force clean open.
            if ensureCatalogVisible(self) then
                return true
            end
            return original_dashboard(self, ...)
        end
    end

    -- After sleep SimpleUI draws home on top of a still-open catalog; nav then
    -- no-ops. Closing under the ScreenSaver during Suspend is unreliable, so
    -- wipe the catalog on Resume instead — next open is always clean.
    local function wipeCatalogAfterResume(self)
        logger.info(TAG, "TRACE plugin Resume: wiping BookOrbit catalog")
        closeAllBookOrbitCatalogs("plugin-resume")
        self.catalog_browser = nil
    end
    local function wipeCatalogBeforeSuspend(self)
        logger.info(TAG, "TRACE plugin Suspend: wiping BookOrbit catalog")
        closeAllBookOrbitCatalogs("plugin-suspend")
        self.catalog_browser = nil
    end
    if type(plugin.onResume) == "function" and not plugin._bookorbit_tweaks_resume_wipe then
        plugin._bookorbit_tweaks_resume_wipe = true
        local original_resume = plugin.onResume
        plugin.onResume = function(self, ...)
            local res = original_resume(self, ...)
            wipeCatalogAfterResume(self)
            return res
        end
    end
    if type(plugin._onResume) == "function" and not plugin._bookorbit_tweaks_resume_wipe2 then
        plugin._bookorbit_tweaks_resume_wipe2 = true
        local original_resume2 = plugin._onResume
        plugin._onResume = function(self, ...)
            local res = original_resume2(self, ...)
            wipeCatalogAfterResume(self)
            return res
        end
    end
    if type(plugin.onSuspend) == "function" and not plugin._bookorbit_tweaks_suspend_wipe then
        plugin._bookorbit_tweaks_suspend_wipe = true
        local original_suspend = plugin.onSuspend
        plugin.onSuspend = function(self, ...)
            wipeCatalogBeforeSuspend(self)
            return original_suspend(self, ...)
        end
    end
    if type(plugin._onSuspend) == "function" and not plugin._bookorbit_tweaks_suspend_wipe2 then
        plugin._bookorbit_tweaks_suspend_wipe2 = true
        local original_suspend2 = plugin._onSuspend
        plugin._onSuspend = function(self, ...)
            wipeCatalogBeforeSuspend(self)
            return original_suspend2(self, ...)
        end
    end
    -- Re-bind event_handlers in case Device set them after patch load.
    pcall(function()
        local UIManager = require("ui/uimanager")
        local handlers = UIManager.event_handlers
        if type(handlers) ~= "table" then return end
        if type(handlers.Resume) == "function" and not handlers._bookorbit_tweaks_resume then
            handlers._bookorbit_tweaks_resume = true
            local original_resume_handler = handlers.Resume
            handlers.Resume = function(...)
                logger.info(TAG, "TRACE event_handlers.Resume (late) - wiping")
                pcall(closeAllBookOrbitCatalogs, "late-handler-Resume")
                local res = original_resume_handler(...)
                pcall(function()
                    UIManager:nextTick(function()
                        closeAllBookOrbitCatalogs("late-handler-nextTick")
                    end)
                end)
                return res
            end
        end
        if type(handlers.Suspend) == "function" and not handlers._bookorbit_tweaks_suspend then
            handlers._bookorbit_tweaks_suspend = true
            local original_suspend_handler = handlers.Suspend
            handlers.Suspend = function(...)
                logger.info(TAG, "TRACE event_handlers.Suspend (late) - wiping")
                pcall(closeAllBookOrbitCatalogs, "late-handler-Suspend")
                return original_suspend_handler(...)
            end
        end
    end)

    -- Settings / menu sheet: flash when it opens (pull-down) and when it closes
    -- (swipe back up) so the sheet does not leave a ghost on the catalog.
    if type(plugin.openMenuSheet) == "function" and not plugin._bookorbit_tweaks_menu_flash then
        plugin._bookorbit_tweaks_menu_flash = true
        local original_sheet = plugin.openMenuSheet

        local function openToolsMenu()
            local FM = package.loaded["apps/filemanager/filemanager"]
            local fm = type(FM) == "table" and FM.instance
            local menu = type(fm) == "table" and fm.menu
            if type(menu) == "table" and type(menu.onShowMenu) == "function" then
                logger.info(TAG, "opening tools menu")
                pcall(menu.onShowMenu, menu)
                return true
            end
            -- Fallback: broadcast ShowMenu
            local ok_ev, Event = pcall(require, "ui/event")
            local ok_ui, UIManager = pcall(require, "ui/uimanager")
            if ok_ev and ok_ui then
                pcall(function()
                    UIManager:sendEvent(Event:new("ShowMenu"))
                end)
                return true
            end
            return false
        end

        local function gesDirection(ges_ev)
            if type(ges_ev) ~= "table" then return nil end
            return ges_ev.direction
        end

        local function attachSecondSwipe(widget)
            if type(widget) ~= "table" or widget._bookorbit_tweaks_second_swipe then
                return
            end
            widget._bookorbit_tweaks_second_swipe = true

            local function maybeToolsFromSouth(ges_ev)
                if not cfg.second_swipe_tools then return false end
                if gesDirection(ges_ev) ~= "south" then return false end
                logger.info(TAG, "menu sheet south swipe -> tools menu")
                local ok_ui, UIManager = pcall(require, "ui/uimanager")
                if ok_ui then
                    pcall(function() UIManager:close(widget) end)
                end
                openToolsMenu()
                return true
            end

            local original_swipe = widget.onSwipe
            widget.onSwipe = function(this, arg, ges_ev)
                if maybeToolsFromSouth(ges_ev) then return true end
                if type(original_swipe) == "function" then
                    return original_swipe(this, arg, ges_ev)
                end
            end

            -- Menu builds Event:new("Swipe", args, ges) so ges is args[2].
            local original_handle = widget.handleEvent
            if type(original_handle) == "function" then
                widget.handleEvent = function(this, event, ...)
                    if type(event) == "table" and event.name == "Swipe" then
                        local a = event.args
                        local ges = type(a) == "table" and (a[2] or a[1]) or nil
                        if maybeToolsFromSouth(ges) then return true end
                    end
                    return original_handle(this, event, ...)
                end
            end
            logger.info(TAG, "attached second-swipe tools on menu sheet")
        end

        plugin.openMenuSheet = function(self, ...)
            local res = original_sheet(self, ...)
            if cfg.flash_ghosting and cfg.flash_menu_sheet then
                local ok_ui, UIManager = pcall(require, "ui/uimanager")
                if ok_ui then
                    pcall(function() UIManager:setDirty("all", "flashui") end)
                end
            end
            -- Attach after the sheet is on the stack (openMenuSheet may show async).
            pcall(function()
                local UIManager = require("ui/uimanager")
                local function tryAttach()
                    local stack = UIManager._window_stack
                    if type(stack) ~= "table" then return end
                    for i = #stack, 1, -1 do
                        local w = stack[i] and stack[i].widget
                        if type(w) == "table" and type(w.name) == "string"
                                and w.name:find("bookorbit_menu_sheet", 1, true) then
                            attachSecondSwipe(w)
                            return
                        end
                    end
                end
                tryAttach()
                UIManager:nextTick(tryAttach)
            end)
            return res
        end
    end

    return true
end

-- ---- After closing BookOrbit: SimpleUI home instead of the stock library -----------
-- SimpleUI closes its home while a full-screen window is up and brings it back
-- when that window closes. After sleep the home is re-shown over the catalog and
-- later closed again, so closing the catalog can leave only the stock file
-- browser. When the option is on and no SimpleUI home is left, show it.
local function showSimpleUIHome()
    if not (G_reader_settings and G_reader_settings:readSetting("start_with") == "homescreen_simpleui") then
        return
    end
    local ok, UIManager = pcall(require, "ui/uimanager")
    if not ok or type(UIManager) ~= "table" then return end
    if UIManager._exit_code ~= nil or UIManager._simpleui_exiting then return end
    local RUI = package.loaded["apps/reader/readerui"]
    if type(RUI) == "table" and RUI.instance then return end
    for _i, entry in ipairs(UIManager._window_stack or {}) do
        local w = entry.widget
        if type(w) == "table" and w.name == "homescreen" and not w._parked then return end
    end
    local HS = package.loaded["screens/sui_homescreen"]
    if type(HS) ~= "table" or HS._instance then return end
    local FM = package.loaded["apps/filemanager/filemanager"]
    local fm = type(FM) == "table" and FM.instance
    local plugin = type(fm) == "table" and (fm._simpleui_plugin or fm["simpleui"])
    if type(plugin) ~= "table" or type(plugin._navigate) ~= "function" then return end
    plugin:_navigate("homescreen", plugin.ui or fm, nil, false)
end

local function hookCatalogClose()
    local ok, Catalog = pcall(require, "bookorbit_catalog")
    if not ok or type(Catalog) ~= "table" then return false end
    if Catalog._bookorbit_tweaks_close_hooked then return true end
    local original = Catalog.onCloseWidget
    if type(original) ~= "function" then return false end
    Catalog._bookorbit_tweaks_close_hooked = true
    Catalog.onCloseWidget = function(self, ...)
        local result = original(self, ...)
        if cfg.after_close == "simpleui" then
            -- Show home in the SAME step the catalog closes, not on the
            -- next tick: UIManager:close removes the catalog from the
            -- stack and repaints right after this returns, so a
            -- nextTick show leaves one repaint where the file browser
            -- is topmost (the stock-library flash). Showing it here
            -- makes home topmost before that repaint. This mirrors the
            -- Bookshelf close path, which shows home synchronously
            -- after its close instead of deferring it.
            local ok_show, err = pcall(showSimpleUIHome)
            if not ok_show then logger.warn(TAG, "show SimpleUI home failed:", err) end
        end
        return result
    end
    logger.info(TAG, "hooked BookOrbit catalog close")
    return true
end

-- ---- Page looping + optional flash on page turns ------------------------------------
-- When loop_pages is on, a swipe that would have been a no-op at either end
-- of a multi-page book list wraps to the other end. When loop_pages is off,
-- boundary swipes stay no-ops and do not arm the flash.
local FLASH_PENDING_S = 15

local function pageFingerprint(catalog)
    local ctx = catalog and catalog.current_context
    if type(ctx) == "table" then
        if ctx.kind == "books" then
            return "books:" .. tostring(ctx.page) .. "/" .. tostring(ctx.page_count)
        end
        if ctx.kind == "dashboard" then
            return "dashboard:" .. tostring(ctx.board_page or 1)
        end
        return tostring(ctx.kind) .. ":" .. tostring(ctx.page or ctx.section or ctx.list_page or "") .. "|menu:" .. tostring(catalog.page or "?")
    end
    if type(catalog.page) == "number" then
        return "menu:" .. tostring(catalog.page) .. "/" .. tostring(catalog.page_num or "?")
    end
    return nil
end

local function dashboardPageCount()
    local ok, BoardStore = pcall(require, "bookorbit_board_store")
    if ok and type(BoardStore) == "table" and type(BoardStore.PAGE_COUNT) == "number" then
        return BoardStore.PAGE_COUNT
    end
    return 4 -- Home, Insights, Library, Decor
end

local function tryLoopPages(catalog, direction)
    -- direction +1 = next, -1 = prev.
    if not cfg.loop_pages then return false end
    local ctx = catalog and catalog.current_context
    if type(ctx) ~= "table" then return false end

    -- Book grid / list
    if ctx.kind == "books" then
        local page = tonumber(ctx.page)
        local page_count = tonumber(ctx.page_count)
        if not page or not page_count or page_count < 2 then return false end
        if direction > 0 and page >= page_count then
            logger.info(TAG, "loop books next:", page, "-> 1")
            catalog:onGotoPage(1)
            return true
        elseif direction < 0 and page <= 1 then
            logger.info(TAG, "loop books prev: 1 ->", page_count)
            catalog:onGotoPage(page_count)
            return true
        end
        return false
    end

    -- Dashboard board pages (Home / Insights / Library / Decor)
    if ctx.kind == "dashboard" or (type(catalog.dashboardMode) == "function" and catalog:dashboardMode()) then
        local page_count = dashboardPageCount()
        local page = tonumber(ctx.board_page) or 1
        if page_count < 2 then return false end
        if direction > 0 and page >= page_count then
            logger.info(TAG, "loop dashboard next:", page, "-> 1")
            ctx.board_page = 1
            if type(catalog.updateItems) == "function" then
                catalog:updateItems(nil, true)
            end
            return true
        elseif direction < 0 and page <= 1 then
            logger.info(TAG, "loop dashboard prev: 1 ->", page_count)
            ctx.board_page = page_count
            if type(catalog.updateItems) == "function" then
                catalog:updateItems(nil, true)
            end
            return true
        end
        return false
    end

    return false
end

local function hookCatalogFlash()
    hookCatalogClose()
    local ok, Catalog = pcall(require, "bookorbit_catalog")
    if not ok or type(Catalog) ~= "table" then return false end
    if Catalog._bookorbit_tweaks_flash_hooked then return true end
    Catalog._bookorbit_tweaks_flash_hooked = true

    -- Debounce: multiple flash requests within 400ms become one (stops the
    -- 2–3 flashes on open from init + updateItems + refreshDashboard).
    local last_flash_t = 0
    local FLASH_DEBOUNCE = 0.4
    local open_t = 0
    local last_flashed_fp = nil
    local last_flashed_clock = 0
    local last_turn_fp = nil

    local function flashNow(catalog, why)
        if not cfg.flash_ghosting then return end
        local fp = nil
        if catalog then
            local ok_fp, res_fp = pcall(pageFingerprint, catalog)
            if ok_fp then fp = res_fp end
        end
        if why == "content" and fp and fp == last_flashed_fp then
            local now_c = (os.clock and os.clock()) or os.time()
            if (now_c - last_flashed_clock) < 3 then
                return
            end
        end
        -- No Tweaks flash while the catalog is not topmost: init-time content
        -- loads used to flash on the file browser, then KOReader's show flash
        -- fired on the catalog -- the double flash on open. Fail open if the
        -- window stack is unreadable, so flash never silently dies.
        if catalog then
            local ok_ui2, UIManager2 = pcall(require, "ui/uimanager")
            if ok_ui2 and type(UIManager2) == "table" and type(UIManager2._window_stack) == "table" then
                local top = false
                for i = #UIManager2._window_stack, 1, -1 do
                    local w = UIManager2._window_stack[i] and UIManager2._window_stack[i].widget
                    if w == catalog or w == (catalog.show_parent or nil) then top = true break end
                    if type(w) == "table" and type(w.name) == "string" and w.name:lower():find("bookorbit", 1, true) then top = true break end
                end
            end
        end
        local now = (os.clock and os.clock()) or os.time()
        if why ~= "page-turn" and (now - last_flash_t) < FLASH_DEBOUNCE then
            return
        end
        last_flash_t = now
        if fp then last_flashed_fp = fp last_flashed_clock = now end
        local ok_ui, UIManager = pcall(require, "ui/uimanager")
        if ok_ui then
            UIManager:setDirty(catalog and (catalog.show_parent or catalog) or "all",
                "flashui", catalog and catalog.dimen)
        end
        if why then logger.info(TAG, "flash:", why) end
    end

    local turns = 0
    local in_turn = false

    local function maybeArmFlash(self)
        if not cfg.flash_ghosting or not cfg.flash_page_turns then return end
        turns = turns + 1
        local every = tonumber(cfg.flash_every) or 1
        if every < 1 then every = 1 end
        if turns >= every then
            turns = 0
            local ok_fp2, fp2 = pcall(pageFingerprint, self)
            if ok_fp2 and fp2 and fp2 == last_turn_fp then
                return
            end
            if ok_fp2 then last_turn_fp = fp2 end
            flashNow(self, "page-turn")
        end
    end

    local original_next = Catalog.onNextPage
    if type(original_next) == "function" then
        Catalog.onNextPage = function(self, ...)
            if in_turn then return original_next(self, ...) end
            in_turn = true
            local before = pageFingerprint(self)

            local ok_call, result = pcall(original_next, self, ...)
            if not ok_call then
                in_turn = false
                error(result, 0)
            end

            local after = pageFingerprint(self)
            local changed = before ~= nil and after ~= nil and before ~= after

            -- Original did nothing at the end → try wrapping (books + dashboard).
            if not changed and tryLoopPages(self, 1) then
                maybeArmFlash(self)
                in_turn = false
                return true
            end

            if changed then
                maybeArmFlash(self)
            end
            in_turn = false
            return result
        end
    end

    local original_prev = Catalog.onPrevPage
    if type(original_prev) == "function" then
        Catalog.onPrevPage = function(self, ...)
            if in_turn then return original_prev(self, ...) end
            in_turn = true
            local before = pageFingerprint(self)

            local ok_call, result = pcall(original_prev, self, ...)
            if not ok_call then
                in_turn = false
                error(result, 0)
            end

            local after = pageFingerprint(self)
            local changed = before ~= nil and after ~= nil and before ~= after

            if not changed and tryLoopPages(self, -1) then
                maybeArmFlash(self)
                in_turn = false
                return true
            end

            if changed then
                maybeArmFlash(self)
            end
            in_turn = false
            return result
        end
    end

    -- onGotoPage: flash only on real page changes (loop uses this path).
    local original_goto = Catalog.onGotoPage
    if type(original_goto) == "function" then
        Catalog.onGotoPage = function(self, page, ...)
            if in_turn then return original_goto(self, page, ...) end
            in_turn = true
            local before = pageFingerprint(self)
            local ok_call, result = pcall(original_goto, self, page, ...)
            in_turn = false
            if not ok_call then error(result, 0) end
            local after = pageFingerprint(self)
            if before ~= nil and after ~= nil and before ~= after then
                maybeArmFlash(self)
            end
            return result
        end
    end

    -- Content rebuilds (library / recent / section loads).
    local original_update = Catalog.updateItems
    if type(original_update) == "function" then
        Catalog.updateItems = function(self, ...)
            local ok_call, result = pcall(original_update, self, ...)
            if not ok_call then error(result, 0) end
            local pending = self._bookorbit_flash_pending
            if pending then
                self._bookorbit_flash_pending = nil
                if cfg.flash_page_turns then
                    flashNow(self, "page-turn-landed")
                end
            elseif cfg.flash_content then
                if open_t > 0 and (os.time() - open_t) < 8 then
                else
                    flashNow(self, "content")
                end
            end
            return result
        end
    end

    -- Open: restore the toggle-gated open flash (nextTick, so the catalog
    -- is topmost by then and the gate passes). The delayed second flash is
    -- handled by the content-suppression window below, not by removing this.
    local original_open = Catalog.init
    if type(original_open) == "function" then
        Catalog.init = function(self, ...)
            local result = original_open(self, ...)
            open_t = os.time()
            if cfg.flash_ghosting and cfg.flash_open then
                local ok_ui, UIManager = pcall(require, "ui/uimanager")
                if ok_ui then
                    pcall(function()
                        UIManager:nextTick(function()
                            flashNow(self, "open")
                        end)
                    end)
                end
            end
            return result
        end
    end
    -- Content flashes in the first 8 s after open are the dashboard load
    -- (sections arrive ~500 ms apart). Suppress them so they do not become
    -- a second open flash; page-turn flashes are immediate and unaffected.

    -- goDashboard / boardFlip: leaving library/recent for the dashboard left a
    -- ghost of the previous view when flash-to-reduce-ghosting is on.
    local original_go = Catalog.goDashboard
    if type(original_go) == "function" then
        Catalog.goDashboard = function(self, ...)
            local res = original_go(self, ...)
            if cfg.flash_dashboard then
                flashNow(self, "dashboard")
            end
            return res
        end
    end
    local original_flip = Catalog.boardFlip
    if type(original_flip) == "function" then
        Catalog.boardFlip = function(self, ...)
            local res = original_flip(self, ...)
            if cfg.flash_page_turns then
                maybeArmFlash(self)
            end
            return res
        end
    end

    logger.info(TAG, "hooked BookOrbit catalog page-turn loop + flash")
    return true
end


-- ---- Block swipe-south from closing BookOrbit --------------------------------------
-- KOReader Menu closes on swipe south. BookOrbit's catalog extends Menu, so a
-- downward swipe (not only the top-edge menu gesture) closes the whole catalog.
-- Keep top-edge south -> menu; ignore other south swipes for close.
local function hookCatalogSwipeClose()
    local ok, Catalog = pcall(require, "bookorbit_catalog")
    if not ok or type(Catalog) ~= "table" then return false end
    if Catalog._bookorbit_tweaks_swipe_hooked then return true end
    Catalog._bookorbit_tweaks_swipe_hooked = true

    local original_swipe = Catalog.onSwipe
    Catalog.onSwipe = function(self, arg, ges_ev)
        local direction = ges_ev and ges_ev.direction
        if direction == "south" then
            -- Top-edge swipe still opens the BookOrbit menu.
            if type(self.onTopEdgeSwipe) == "function" then
                local handled = self:onTopEdgeSwipe(ges_ev)
                if handled then
                    if cfg.flash_ghosting and cfg.flash_menu_sheet then
                        local ok_ui, UIManager = pcall(require, "ui/uimanager")
                        if ok_ui then
                            pcall(function() UIManager:setDirty("all", "flashui") end)
                        end
                    end
                    return true
                end
            end
            -- Do not close the catalog on swipe south.
            return true
        end
        if type(original_swipe) == "function" then
            return original_swipe(self, arg, ges_ev)
        end
        return true
    end
    logger.info(TAG, "hooked BookOrbit catalog swipe (no close on swipe south)")
    return true
end

-- ---- Resume pill colour -----------------------------------------------------------
-- The hero Resume/Download pill is BoardUI.box({h = px(40), radius = px(20),
-- bg = INK.white}). No other board box uses exactly 40/20 with a white fill
-- (Shuffle is 38/19), so that shape is the discriminator. The play icon is
-- baked into an SVG at build time, so it stays black: the palette below is
-- light colours only, so black text/icon stay readable. Night mode needs no
-- special case: the hero night wrapper inverts the tile and the screen
-- inversion flips it back, so the chosen colour shows as chosen in both modes.
local PILL_COLORS = {
    { "White", "#FFFFFF" }, { "Silver", "#AAAAAA" }, { "Light grey", "#CCCCCC" },
    { "Sky", "#6FB7E9" }, { "Pink", "#E78FB3" }, { "Gold", "#D4A017" },
    { "Mint", "#A8E6CF" }, { "Lavender", "#D8B4FE" },
}

local function pillColorName(hex)
    if type(hex) ~= "string" then return "White" end
    for _i, c in ipairs(PILL_COLORS) do
        if c[2]:upper() == hex:upper() then return c[1] end
    end
    return hex
end

local function pillColorValue(hex)
    if type(hex) ~= "string" then return nil end
    local r, g, b = hex:match("^#?(%x%x)(%x%x)(%x%x)$")
    if not r then return nil end
    r, g, b = tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
    local ok_bb, Blitbuffer = pcall(require, "ffi/blitbuffer")
    if not ok_bb or type(Blitbuffer) ~= "table" then return nil end
    if r == g and g == b then return Blitbuffer.Color8(r) end
    return Blitbuffer.ColorRGB32(r, g, b, 0xFF)
end

local function hookResumePillColor()
    if package.loaded["bookorbit_tweaks_pill_color"] then return true end
    local ok_ui, BoardUI = pcall(require, "bookorbit_board_ui")
    if not ok_ui or type(BoardUI) ~= "table" or type(BoardUI.box) ~= "function" then
        return false
    end
    local ok_met, BoardMetrics = pcall(require, "bookorbit_board_metrics")
    if not ok_met or type(BoardMetrics) ~= "table" or type(BoardMetrics.px) ~= "function" then
        return false
    end
    package.loaded["bookorbit_tweaks_pill_color"] = true
    local original_box = BoardUI.box
    -- Never compare a Blitbuffer colour with == nil: its __eq calls
    -- getColorRGB32 on the other side and crashes when that side is nil.
    -- Most BoardUI.box calls have no bg at all, so that crash fired on the
    -- first dashboard build after a non-white colour was picked.
    local function isWhite(c)
        if not c then return false end
        local ok, rgb = pcall(function() return c:getColorRGB32() end)
        return ok and rgb and rgb.r == 255 and rgb.g == 255 and rgb.b == 255
    end
    BoardUI.box = function(o, child)
        if type(o) == "table" and type(cfg.resume_pill_color) == "string"
                and cfg.resume_pill_color:upper() ~= "#FFFFFF"
                and isWhite(o.bg) and o.h == BoardMetrics.px(40)
                and o.radius == BoardMetrics.px(20) then
            local col = pillColorValue(cfg.resume_pill_color)
            if col then
                local copy = {}
                for k, v in pairs(o) do copy[k] = v end
                copy.bg = col
                return original_box(copy, child)
            end
        end
        return original_box(o, child)
    end
    logger.info(TAG, "hooked BoardUI.box for Resume pill colour")
    return true
end

-- ---- Flash on BookOrbit settings / menu pages --------------------------------------
local function hookSettingsFlash()
    local ok, MenuPage = pcall(require, "bookorbit_menu_page")
    if not ok or type(MenuPage) ~= "table" or type(MenuPage.refresh) ~= "function" then
        return false
    end
    if MenuPage._bookorbit_tweaks_flash_hooked then return true end
    MenuPage._bookorbit_tweaks_flash_hooked = true

    local original_refresh = MenuPage.refresh
    MenuPage.refresh = function(self, mode, ...)
        local result = original_refresh(self, mode, ...)
        if not cfg.flash_ghosting or not cfg.flash_menu_sheet then return result end
        local name = self and self.name
        if type(name) == "string" and (
            name:find("bookorbit_settings", 1, true)
            or name:find("bookorbit_sign_in", 1, true)
            or name:find("bookorbit_menu", 1, true)
            or name:find("bookorbit_status", 1, true)
            or name:find("bookorbit_diagnostics", 1, true)
        ) then
            local ok_ui, UIManager = pcall(require, "ui/uimanager")
            if ok_ui and type(UIManager) == "table" then
                pcall(function()
                    UIManager:setDirty(self, "flashui")
                end)
            end
        end
        return result
    end
    logger.info(TAG, "hooked BookOrbit menu/settings pages for ghosting flash")
    return true
end

-- ---- Sign-in page: saved-server picker ------------------------------------------
-- Adds a "Saved servers" action on the BookOrbit sign-in page so you can pick
-- a stored profile without retyping. Selecting one signs in immediately with
-- the saved credentials.
-- Apply credentials only. Avoid completeSignIn / refreshActiveCatalogApi(true)
-- while Settings or the catalog are open — that path was crashing on switch.
local skip_server_chooser = false

local function switchToSavedServer(plugin, entry)
    if type(entry) ~= "table" or not entry.server_url then return false end
    if not applyBookOrbitCreds(entry) then return false end

    if type(plugin) == "table" and type(plugin.settings) == "table" then
        local s = plugin.settings
        if s.server_url ~= entry.server_url or s.username ~= entry.username then
            if type(plugin.clearAccountCaches) == "function" then
                pcall(plugin.clearAccountCaches, plugin)
            else
                s.catalog_dashboard_cache = nil
                s.catalog_detail_cache = nil
            end
        end
        s.server_url = entry.server_url
        s.username = entry.username
        s.userkey = entry.userkey
    end

    -- Update the open catalog's API opts only; never force a network refresh here.
    if type(plugin) == "table" and type(plugin.refreshActiveCatalogApi) == "function" then
        pcall(plugin.refreshActiveCatalogApi, plugin, false)
    end

    logger.info(TAG, "switched saved server to", serverLabel(entry))
    return true
end


local function showSavedServerPicker(plugin, page)
    local list = loadServers()
    if #list == 0 then
        local InfoMessage = require("ui/widget/infomessage")
        local UIManager = require("ui/uimanager")
        UIManager:show(InfoMessage:new{
            text = _("No saved servers yet.\nSign in once, then use BookOrbit Tweaks → Saved servers → Save current server."),
            timeout = 4,
        })
        return
    end
    local ButtonDialog = require("ui/widget/buttondialog")
    local UIManager = require("ui/uimanager")
    local dialog
    local buttons = {}
    for _i, entry in ipairs(list) do
        local label = serverLabel(entry)
        table.insert(buttons, {
            {
                text = label,
                callback = function()
                    if dialog then UIManager:close(dialog) end
                    local ok_switch, err = pcall(switchToSavedServer, plugin, entry)
                    if not ok_switch then logger.warn(TAG, "server switch failed:", err) end
                    if page and type(page.close) == "function" then
                        pcall(page.close, page)
                    elseif page then
                        pcall(UIManager.close, UIManager, page)
                    end
                    if page and page.on_signed_in then
                        pcall(page.on_signed_in)
                    end
                    local InfoMessage = require("ui/widget/infomessage")
                    UIManager:show(InfoMessage:new{
                        text = _("Switching To") .. "\n" .. label,
                        timeout = 3,
                    })
                end,
            },
        })
    end
    table.insert(buttons, {
        {
            text = _("Cancel"),
            callback = function()
                if dialog then UIManager:close(dialog) end
            end,
        },
    })
    dialog = ButtonDialog:new{
        title = _("Saved Servers"),
        buttons = buttons,
    }
    UIManager:show(dialog)
end

local function hookSignInPage()
    local ok, SignIn = pcall(require, "bookorbit_signin_page")
    if not ok or type(SignIn) ~= "table" or type(SignIn.open) ~= "function" then
        return false
    end
    if SignIn._bookorbit_tweaks_signin_hooked then return true end
    SignIn._bookorbit_tweaks_signin_hooked = true

    local original_open = SignIn.open
    SignIn.open = function(plugin, on_signed_in)
        local page = original_open(plugin, on_signed_in)
        if type(page) ~= "table" then return page end

        -- Wrap on_action so a "saved" action opens the picker.
        local original_action = page.on_action
        page.on_action = function(p, action)
            if type(action) == "table" and action.kind == "saved-servers" then
                showSavedServerPicker(plugin, p)
                return true
            end
            if type(original_action) == "function" then
                return original_action(p, action)
            end
            return true
        end

        -- Wrap build to insert a "Saved servers" pill when any are stored.
        local original_build = page.build
        if type(original_build) == "function" then
            page.build = function(p, sw, sh)
                local root = original_build(p, sw, sh)
                local list = loadServers()
                if #list == 0 then return root end
                -- Best-effort: we cannot easily rewrite the custom BoardUI tree,
                -- so we rely on the action hook + a long-press / menu alternative.
                -- The picker is also reachable from the server field via a
                -- secondary entry point below.
                return root
            end
        end

        -- Offer the picker immediately when the page opens if servers exist,
        -- via a small toast with a hint (non-blocking). User can also open it
        -- from Tweaks. Additionally, intercept edit of "server" when servers
        -- are saved: first show picker, with "Enter address" as an option.
        local orig_action2 = page.on_action
        page.on_action = function(p, action)
            if type(action) == "table" and action.kind == "edit" and action.field == "server" then
                local list = loadServers()
                if #list > 0 then
                    local ButtonDialog = require("ui/widget/buttondialog")
                    local UIManager = require("ui/uimanager")
                    local dlg
                    local buttons = {}
                    for _i, entry in ipairs(list) do
                        local label = serverLabel(entry)
                        table.insert(buttons, {{
                            text = label,
                            callback = function()
                                if dlg then pcall(UIManager.close, UIManager, dlg) end
                                local ok_switch, err = pcall(switchToSavedServer, plugin, entry)
                                if not ok_switch then logger.warn(TAG, "server switch failed:", err) end
                                if p then
                                    pcall(UIManager.close, UIManager, p)
                                    if p.on_signed_in then pcall(p.on_signed_in) end
                                end
                                local InfoMessage = require("ui/widget/infomessage")
                                UIManager:show(InfoMessage:new{
                                    text = _("Switching To") .. "\n" .. label,
                                    timeout = 3,
                                })
                            end,
                        }})
                    end
                    table.insert(buttons, {{
                        text = _("Enter A Different Address…"),
                        callback = function()
                            if dlg then UIManager:close(dlg) end
                            if type(orig_action2) == "function" then
                                orig_action2(p, action)
                            end
                        end,
                    }})
                    table.insert(buttons, {{
                        text = _("Cancel"),
                        callback = function() if dlg then UIManager:close(dlg) end end,
                    }})
                    dlg = ButtonDialog:new{
                        title = _("Choose A Server"),
                        buttons = buttons,
                    }
                    UIManager:show(dlg)
                    return true
                end
            end
            if type(action) == "table" and action.kind == "saved-servers" then
                showSavedServerPicker(plugin, p)
                return true
            end
            if type(orig_action2) == "function" then
                return orig_action2(p, action)
            end
            return true
        end

        logger.info(TAG, "hooked BookOrbit sign-in page for saved servers")
        return page
    end
    return true
end

-- ---- Settings → Account: Server row shows saved-server picker ----------------------
-- The Account page (Server / Signed in as / Test connection) uses action kind
-- "server" → plugin:setServerAddress. Intercept both the settings page action
-- and setServerAddress so a saved list appears when you have profiles.
local function showServerChooser(plugin, on_enter_new, on_switched)
    if cfg.server_chooser_in_settings == false then
        if on_enter_new then on_enter_new() end
        return
    end
    local list = loadServers()
    if #list == 0 then
        if on_enter_new then on_enter_new() end
        return
    end
    local ButtonDialog = require("ui/widget/buttondialog")
    local UIManager = require("ui/uimanager")
    local dlg
    local buttons = {}
    for _i, entry in ipairs(list) do
        local label = serverLabel(entry)
        local current = currentBookOrbitCreds()
        local mark = (current and current.server_url == entry.server_url
            and current.username == entry.username) and "✓ " or ""
        table.insert(buttons, {{
            text = mark .. label,
            callback = function()
                if dlg then pcall(UIManager.close, UIManager, dlg) end
                local ok_switch, err = pcall(switchToSavedServer, plugin, entry)
                if not ok_switch then
                    logger.warn(TAG, "server switch failed:", err)
                end
                if on_switched then pcall(on_switched, entry) end
                local InfoMessage = require("ui/widget/infomessage")
                UIManager:show(InfoMessage:new{
                    text = _("Switching To") .. "\n" .. label,
                    timeout = 3,
                })
            end,
        }})
    end
    table.insert(buttons, {{
        text = _("Enter A Different Address…"),
        callback = function()
            if dlg then pcall(UIManager.close, UIManager, dlg) end
            if on_enter_new then pcall(on_enter_new) end
        end,
    }})
    table.insert(buttons, {{
        text = _("Cancel"),
        callback = function()
            if dlg then pcall(UIManager.close, UIManager, dlg) end
        end,
    }})
    dlg = ButtonDialog:new{
        title = _("Choose A Server"),
        buttons = buttons,
    }
    UIManager:show(dlg)
end

local function hookSettingsPage()
    local ok, Settings = pcall(require, "bookorbit_settings_page")
    if not ok or type(Settings) ~= "table" then return false end
    if Settings._bookorbit_tweaks_settings_hooked then return true end
    Settings._bookorbit_tweaks_settings_hooked = true

    if type(Settings.open) == "function" then
        local original_open = Settings.open
        Settings.open = function(plugin, catalog, view)
            local page = original_open(plugin, catalog, view)
            if type(page) ~= "table" then return page end
            local original_action = page.on_action
            page.on_action = function(p, action)
                if type(action) == "table" and action.kind == "server" then
                    showServerChooser(plugin, function()
                        if type(original_action) == "function" then
                            original_action(p, action)
                        elseif type(plugin.setServerAddress) == "function" then
                            plugin:setServerAddress(function()
                                if p.refresh then p:refresh() end
                            end)
                        end
                    end, function()
                        if p.refresh then p:refresh() end
                    end)
                    return true
                end
                if type(original_action) == "function" then
                    return original_action(p, action)
                end
                return true
            end
            return page
        end
        logger.info(TAG, "hooked BookOrbit settings page for server chooser")
    end
    return true
end

-- Catch Account → Server even if Settings.open was already captured.
local function hookMenuPageRunAction()
    local ok, MenuPage = pcall(require, "bookorbit_menu_page")
    if not ok or type(MenuPage) ~= "table" or type(MenuPage.runAction) ~= "function" then
        return false
    end
    if MenuPage._bookorbit_tweaks_runaction_hooked then return true end
    MenuPage._bookorbit_tweaks_runaction_hooked = true
    local original = MenuPage.runAction
    MenuPage.runAction = function(self, action)
        if type(action) == "table" and action.kind == "server" and type(self.plugin) == "table" then
            local list = loadServers()
            if #list > 0 then
                showServerChooser(self.plugin, function()
                    skip_server_chooser = true
                    local ok, err = pcall(original, self, action)
                    skip_server_chooser = false
                    if not ok then error(err, 0) end
                end, function()
                    if type(self.refresh) == "function" then pcall(self.refresh, self) end
                end)
                return
            end
        end
        return original(self, action)
    end
    logger.info(TAG, "hooked MenuPage.runAction for server chooser")
    return true
end

local function hookPluginServerAddress(plugin)
    if type(plugin) ~= "table" or type(plugin.setServerAddress) ~= "function" then return end
    if plugin._bookorbit_tweaks_server_addr_hooked then return end
    plugin._bookorbit_tweaks_server_addr_hooked = true
    local original = plugin.setServerAddress
    plugin.setServerAddress = function(self, on_done)
        if skip_server_chooser then
            return original(self, on_done)
        end
        local list = loadServers()
        if #list == 0 then
            return original(self, on_done)
        end
        showServerChooser(self, function()
            skip_server_chooser = true
            local ok, err = pcall(original, self, on_done)
            skip_server_chooser = false
            if not ok then error(err, 0) end
        end, function()
            if on_done then pcall(on_done) end
        end)
    end
    logger.info(TAG, "hooked plugin setServerAddress for server chooser")
end

-- ---- Persistent library filter -------------------------------------------------------
-- Injects libraryId into catalog book requests so BookOrbit only shows the chosen
-- library (e.g. Books, not Comics) without opening Sort & filter every time.
local LIBRARIES_CACHE_KEY = "bookorbit_tweaks_libraries"

local function loadLibrariesCache()
    local list = G_reader_settings and G_reader_settings:readSetting(LIBRARIES_CACHE_KEY)
    if type(list) ~= "table" then return {} end
    return list
end

local function saveLibrariesCache(list)
    if not G_reader_settings then return end
    G_reader_settings:saveSetting(LIBRARIES_CACHE_KEY, list or {})
    if G_reader_settings.flush then pcall(G_reader_settings.flush, G_reader_settings) end
end

local function applyLibraryFilterToParams(params)
    if type(params) ~= "table" then return params end
    local id = cfg.library_filter_id
    if id == false or id == nil or id == "" then
        return params
    end
    -- Do not override an explicit library (user drilled into one library).
    if params.libraryId ~= nil then return params end
    params.libraryId = tonumber(id) or id
    return params
end

local function hookCatalogLibraryFilter()
    local ok, CatalogLists = pcall(require, "bookorbit_catalog_lists")
    if ok and type(CatalogLists) == "table" and type(CatalogLists.listDecorateBookQuery) == "function"
            and not CatalogLists._bookorbit_tweaks_libfilter then
        CatalogLists._bookorbit_tweaks_libfilter = true
        local original = CatalogLists.listDecorateBookQuery
        CatalogLists.listDecorateBookQuery = function(self, query)
            query = original(self, query) or query
            return applyLibraryFilterToParams(query)
        end
        logger.info(TAG, "hooked listDecorateBookQuery for library filter")
    end

    local ok_cat, Catalog = pcall(require, "bookorbit_catalog")
    if ok_cat and type(Catalog) == "table" and type(Catalog.loadBooks) == "function"
            and not Catalog._bookorbit_tweaks_libfilter_load then
        Catalog._bookorbit_tweaks_libfilter_load = true
        local original_load = Catalog.loadBooks
        Catalog.loadBooks = function(self, params, title, push)
            if type(params) == "table" then
                params = applyLibraryFilterToParams(params)
            end
            return original_load(self, params, title, push)
        end
        logger.info(TAG, "hooked loadBooks for library filter")
    end

    local ok_api, Api = pcall(require, "bookorbit_api")
    if ok_api and type(Api) == "table" and type(Api.catalogBooks) == "function"
            and not Api._bookorbit_tweaks_libfilter_api then
        Api._bookorbit_tweaks_libfilter_api = true
        local original_books = Api.catalogBooks
        Api.catalogBooks = function(self, params)
            if type(params) == "table" then
                params = applyLibraryFilterToParams(params)
            end
            return original_books(self, params)
        end
        logger.info(TAG, "hooked api.catalogBooks for library filter")
    end
    return true
end

local function fetchLibrariesFromServer()
    local s = G_reader_settings and G_reader_settings:readSetting("bookorbit")
    if type(s) ~= "table" or not s.server_url or not s.username or not s.userkey then
        return nil, "not signed in"
    end
    local ok_api, BookOrbitApi = pcall(require, "bookorbit_api")
    if not ok_api or type(BookOrbitApi) ~= "table" then
        return nil, "api missing"
    end
    local client
    if type(BookOrbitApi.new) == "function" then
        client = BookOrbitApi.new({
            server_url = s.server_url,
            username = s.username,
            userkey = s.userkey,
        })
    else
        return nil, "api.new missing"
    end
    if type(client.catalogSection) ~= "function" then
        return nil, "catalogSection missing"
    end
    local body, err = client:catalogSection("libraries")
    if not body then return nil, err or "fetch failed" end
    local items = body.items or body.libraries or {}
    local out = {}
    for _i, entry in ipairs(items) do
        if type(entry) == "table" and entry.id then
            table.insert(out, {
                id = tonumber(entry.id) or entry.id,
                title = entry.title or entry.name or tostring(entry.id),
            })
        end
    end
    saveLibrariesCache(out)
    return out
end

-- After a library change, ask about a restart: the dashboard and its
-- cached lists do not reliably re-fetch on a menu change alone, so a
-- restart is the sure way to apply the new library everywhere. The
-- dialog is shown on the next tick so the menu callback has finished
-- first; showing it synchronously inside the callback left it behind
-- the menu on some routes. Cancel only dismisses the popup -- the
-- new library stays saved and applies on the next restart.
local function askRestartAfterLibraryChange(old_id, new_id)
    if tostring(old_id or "") == tostring(new_id or "") then return end

    local ok_ui, UIManager = pcall(require, "ui/uimanager")
    if not ok_ui or type(UIManager) ~= "table" then return end
    UIManager:nextTick(function()
        local ok_bd, ButtonDialog = pcall(require, "ui/widget/buttondialog")
        if not ok_bd or type(ButtonDialog) ~= "table" then return end
        local dialog
        dialog = ButtonDialog:new{
            title = _("Library Changed"),
            text = _("Restart KOReader to apply the new library?"),
            buttons = {
                {
                    {
                        text = _("Restart Now"),
                        callback = function()
                            if dialog then UIManager:close(dialog) end
                            if type(UIManager.restartKOReader) == "function" then
                                UIManager:restartKOReader()
                            elseif type(UIManager.quit) == "function" then
                                UIManager:quit(85)
                            end
                        end,
                    },
                },
                {
                    {
                        text = _("Cancel"),
                        callback = function()
                            if dialog then UIManager:close(dialog) end
                        end,
                    },
                },
            },
        }
        UIManager:show(dialog)
    end)
end

local function buildLibraryMenu()
    local items = {}
    local current_id = cfg.library_filter_id
    local all_active = (current_id == false or current_id == nil or current_id == "")

    table.insert(items, {
        text = all_active and (_("All Libraries") .. " · " .. _("Active")) or _("All Libraries"),
        radio = true,
        checked_func = function()
            local id = cfg.library_filter_id
            return id == false or id == nil or id == ""
        end,
        callback = function(touchmenu_instance)
            local old_id = cfg.library_filter_id
            cfg.library_filter_id = false
            cfg.library_filter_name = ""
            saveConfig()
            logger.info(TAG, "library filter: all")
            askRestartAfterLibraryChange(old_id, false)
            if touchmenu_instance then
                touchmenu_instance.item_table = buildLibraryMenu()
                touchmenu_instance:updateItems()
            end
        end,
    })

    local list = loadLibrariesCache()
    if #list == 0 then
        table.insert(items, {
            text = _("No Libraries Cached — Tap Refresh"),
            enabled = false,
        })
    else
        for _i, lib in ipairs(list) do
            local lid = lib.id
            local label = lib.title or tostring(lid)
            local selected = tostring(cfg.library_filter_id) == tostring(lid)
            table.insert(items, {
                text = selected and (label .. " · " .. _("Active")) or label,
                radio = true,
                checked_func = function()
                    return tostring(cfg.library_filter_id) == tostring(lid)
                end,
                callback = function(touchmenu_instance)
                    local old_id = cfg.library_filter_id
                    cfg.library_filter_id = lid
                    cfg.library_filter_name = label
                    saveConfig()
                    logger.info(TAG, "library filter:", label, lid)
                    askRestartAfterLibraryChange(old_id, lid)
                    if touchmenu_instance then
                        touchmenu_instance.item_table = buildLibraryMenu()
                        touchmenu_instance:updateItems()
                    end
                end,
            })
        end
    end

    table.insert(items, {
        text = _("Refresh Library List"),
        callback = function(touchmenu_instance)
            local InfoMessage = require("ui/widget/infomessage")
            local UIManager = require("ui/uimanager")
            local list2, err = fetchLibrariesFromServer()
            if not list2 then
                UIManager:show(InfoMessage:new{
                    text = _("Could not load libraries.")
                        .. (err and ("\n" .. tostring(err)) or ""),
                    timeout = 3,
                })
                return
            end
            UIManager:show(InfoMessage:new{
                text = string.format(_("Loaded %d libraries."), #list2),
                timeout = 2,
            })
            if touchmenu_instance then
                touchmenu_instance.item_table = buildLibraryMenu()
                touchmenu_instance:updateItems()
            end
        end,
    })
    return items
end


-- Try immediately in case BookOrbit's modules have already been loaded.
hookCatalogWidgets()
hookBoardCover()
hookHeroNight()
hookCatalogFlash()
hookSignInPage()
hookSettingsPage()
hookMenuPageRunAction()
hookCatalogSwipeClose()
hookSettingsFlash()
hookResumePillColor()
hookCatalogLibraryFilter()
hookDispatcherOpen()

-- KOReader's userpatch hook runs when the BookOrbit plugin is instantiated.
-- This is the important retry for current BookOrbit, whose catalog modules
-- are loaded as part of the plugin's startup.
do
    local ok, userpatch = pcall(require, "userpatch")
    if ok and type(userpatch) == "table"
            and type(userpatch.registerPatchPluginFunc) == "function" then
        local function onPlugin(plugin)
            hookPluginOpen(plugin)
            if not hookCatalogFlash() then
                logger.warn(TAG, "BookOrbit loaded but catalog class was not found for flash")
            end
            hookCatalogClose()
            if not hookCatalogWidgets() then
                logger.warn(TAG, "BookOrbit loaded but catalog cover builder was not found")
            end
            if not hookBoardCover() then
                logger.warn(TAG, "BookOrbit loaded but board cover painter was not found")
            end
            if not hookHeroNight() then
                logger.warn(TAG, "BookOrbit loaded but hero tile was not found for night mode")
            end
            hookSignInPage()
            hookSettingsPage()
            hookMenuPageRunAction()
            hookCatalogSwipeClose()
            hookSettingsFlash()
            hookResumePillColor()
            hookCatalogLibraryFilter()
            hookDispatcherOpen()
            hookPluginServerAddress(plugin)
        end
        userpatch.registerPatchPluginFunc("bookorbit", onPlugin)
        userpatch.registerPatchPluginFunc("BookOrbit", onPlugin)
    else
        logger.warn(TAG, "KOReader userpatch plugin hook unavailable")
    end
end

-- ---- Menu ---------------------------------------------------------------------

local function choiceItem(text, key, value)
    return {
        text = text,
        radio = true,
        keep_menu_open = true,
        checked_func = function() return cfg[key] == value end,
        callback = function(touchmenu_instance)
            cfg[key] = value
            saveConfig()
            if touchmenu_instance then touchmenu_instance:updateItems() end
        end,
    }
end

local function flashEveryItem(n)
    return {
        text = n == 1 and _("Every Page Turn") or string.format(_("Every %d Page Turns"), n),
        radio = true,
        keep_menu_open = true,
        enabled_func = function() return cfg.flash_ghosting == true end,
        checked_func = function() return (tonumber(cfg.flash_every) or 1) == n end,
        callback = function(touchmenu_instance)
            if not cfg.flash_ghosting then return end
            cfg.flash_every = n
            saveConfig()
            if touchmenu_instance then touchmenu_instance:updateItems() end
        end,
    }
end

local function buildServerMenu()
    local items = {}
    local list = loadServers()
    local current = currentBookOrbitCreds()

    table.insert(items, {
        text = _("Enable Server Selection In Settings"),
        checked_func = function() return cfg.server_chooser_in_settings ~= false end,
        callback = function()
            cfg.server_chooser_in_settings = not (cfg.server_chooser_in_settings ~= false)
            saveConfig()
            logger.info(TAG, "server_chooser_in_settings =", cfg.server_chooser_in_settings)
        end,
    })

    table.insert(items, {
        text = _("Save Current Server"),
        enabled_func = function() return current ~= nil end,
        callback = function(touchmenu_instance)
            local creds = currentBookOrbitCreds()
            if not creds then return end
            local list2 = loadServers()
            local replaced = false
            for i, e in ipairs(list2) do
                if e.server_url == creds.server_url and e.username == creds.username then
                    list2[i] = creds
                    replaced = true
                    break
                end
            end
            if not replaced then
                table.insert(list2, creds)
            end
            saveServers(list2)
            logger.info(TAG, "saved server", serverLabel(creds))
            local InfoMessage = require("ui/widget/infomessage")
            local UIManager = require("ui/uimanager")
            UIManager:show(InfoMessage:new{
                text = _("Saved:\n") .. serverLabel(creds),
                timeout = 2,
            })
            if touchmenu_instance then
                touchmenu_instance.item_table = buildServerMenu()
                touchmenu_instance:updateItems()
            end
        end,
    })

    if #list == 0 then
        table.insert(items, {
            text = _("No Saved Servers Yet"),
            enabled = false,
        })
    else
        for idx, entry in ipairs(list) do
            local label = serverLabel(entry)
            local is_active = current
                and current.server_url == entry.server_url
                and current.username == entry.username
            table.insert(items, {
                text = (is_active and "✓ " or "") .. label,
                callback = function()
                    if applyBookOrbitCreds(entry) then
                        logger.info(TAG, "switched to", label)
                        local InfoMessage = require("ui/widget/infomessage")
                        local UIManager = require("ui/uimanager")
                        UIManager:show(InfoMessage:new{
                            text = _("Switching To") .. "\n" .. label,
                            timeout = 2,
                        })
                    end
                end,
                hold_callback = function(touchmenu_instance)
                    local ButtonDialog = require("ui/widget/buttondialog")
                    local MultiInputDialog = require("ui/widget/multiinputdialog")
                    local UIManager = require("ui/uimanager")
                    local dlg
                    dlg = ButtonDialog:new{
                        title = label,
                        buttons = {
                            {{
                                text = _("Edit Server"),
                                callback = function()
                                    if dlg then pcall(UIManager.close, UIManager, dlg) end
                                    local fields
                                    fields = MultiInputDialog:new{
                                        title = _("Edit Server"),
                                        fields = {
                                            {
                                                description = _("Server Address"),
                                                text = entry.server_url or "",
                                                hint = "https://…",
                                            },
                                            {
                                                description = _("Username"),
                                                text = entry.username or "",
                                            },
                                            {
                                                description = _("User Key / Password"),
                                                text = entry.userkey or "",
                                                text_type = "password",
                                            },
                                            {
                                                description = _("Display Name (Optional)"),
                                                text = entry.label or "",
                                                hint = _("e.g. Home, Comics"),
                                            },
                                        },
                                        buttons = {{
                                            {
                                                text = _("Cancel"),
                                                id = "close",
                                                callback = function()
                                                    UIManager:close(fields)
                                                end,
                                            },
                                            {
                                                text = _("Save"),
                                                is_enter_default = true,
                                                callback = function()
                                                    local values = fields:getFields()
                                                    UIManager:close(fields)
                                                    local url = values[1] and tostring(values[1]):match("^%s*(.-)%s*$") or ""
                                                    local user = values[2] and tostring(values[2]):match("^%s*(.-)%s*$") or ""
                                                    local key = values[3] and tostring(values[3]) or ""
                                                    local name = values[4] and tostring(values[4]):match("^%s*(.-)%s*$") or ""
                                                    if url == "" or user == "" or key == "" then
                                                        local InfoMessage = require("ui/widget/infomessage")
                                                        UIManager:show(InfoMessage:new{
                                                            text = _("Server address, username, and user key are required."),
                                                            timeout = 3,
                                                        })
                                                        return
                                                    end
                                                    local list2 = loadServers()
                                                    for i, e in ipairs(list2) do
                                                        if e.server_url == entry.server_url
                                                                and e.username == entry.username then
                                                            list2[i].server_url = url
                                                            list2[i].username = user
                                                            list2[i].userkey = key
                                                            if name ~= "" then
                                                                list2[i].label = name
                                                            else
                                                                list2[i].label = nil
                                                            end
                                                            break
                                                        end
                                                    end
                                                    saveServers(list2)
                                                    logger.info(TAG, "edited saved server", url, user)
                                                    if touchmenu_instance then
                                                        touchmenu_instance.item_table = buildServerMenu()
                                                        touchmenu_instance:updateItems()
                                                    end
                                                end,
                                            },
                                        }},
                                    }
                                    UIManager:show(fields)
                                    fields:onShowKeyboard()
                                end,
                            }},
                            {{
                                text = _("Remove From List"),
                                callback = function()
                                    if dlg then pcall(UIManager.close, UIManager, dlg) end
                                    local list2 = loadServers()
                                    for i, e in ipairs(list2) do
                                        if e.server_url == entry.server_url
                                                and e.username == entry.username then
                                            table.remove(list2, i)
                                            break
                                        end
                                    end
                                    saveServers(list2)
                                    if touchmenu_instance then
                                        touchmenu_instance.item_table = buildServerMenu()
                                        touchmenu_instance:updateItems()
                                    end
                                end,
                            }},
                            {{
                                text = _("Cancel"),
                                callback = function()
                                    if dlg then pcall(UIManager.close, UIManager, dlg) end
                                end,
                            }},
                        },
                    }
                    UIManager:show(dlg)
                end,
            })
        end
    end
    return items
end

local function buildMenu()
    return {
        {
            text = _("Keep Covers Original In Night Mode"),
            checked_func = isEnabled,
            callback = toggle,
        },
        {
            text = _("Loop Pages (Swipe Past Last → First)"),
            checked_func = function() return cfg.loop_pages == true end,
            callback = function()
                cfg.loop_pages = not (cfg.loop_pages == true)
                saveConfig()
                logger.info(TAG, "loop_pages =", cfg.loop_pages)
            end,
        },
        {
            text = _("Second Swipe Opens Tools Menu"),
            checked_func = function() return cfg.second_swipe_tools == true end,
            callback = function()
                cfg.second_swipe_tools = not (cfg.second_swipe_tools == true)
                saveConfig()
                logger.info(TAG, "second_swipe_tools =", cfg.second_swipe_tools)
            end,
        },
        {
            text = _("Library Filter"),
            sub_item_table_func = buildLibraryMenu,
        },
        {
            text = _("Resume Pill Colour"),
            sub_item_table_func = function()
                local items = {}
                for _i, c in ipairs(PILL_COLORS) do
                    local name, hex = c[1], c[2]
                    items[#items + 1] = {
                        text = name,
                        checked_func = function()
                            return type(cfg.resume_pill_color) == "string"
                                and cfg.resume_pill_color:upper() == hex
                        end,
                        callback = function()
                            cfg.resume_pill_color = hex
                            saveConfig()
                            logger.info(TAG, "resume_pill_color =", hex)
                        end,
                    }
                end
                return items
            end,
        },
        {
            text = _("Reopen BookOrbit At"),
            sub_item_table = {
                choiceItem(_("Where I Left Off"), "reopen_at", "last"),
                choiceItem(_("BookOrbit Home"), "reopen_at", "home"),
            },
        },
        {
            text = _("Flash To Reduce Ghosting"),
            sub_item_table = {
                {
                    text = _("Enable Flash"),
                    checked_func = function() return cfg.flash_ghosting == true end,
                    callback = function(touchmenu_instance)
                        cfg.flash_ghosting = not (cfg.flash_ghosting == true)
                        saveConfig()
                        if touchmenu_instance then touchmenu_instance:updateItems() end
                    end,
                },
                {
                    text = _("Flash Per Page"),
                    enabled_func = function() return cfg.flash_ghosting == true end,
                    sub_item_table = {
                        {
                            text = _("Flash On Page Turns"),
                            enabled_func = function() return cfg.flash_ghosting == true end,
                            checked_func = function() return cfg.flash_page_turns == true end,
                            callback = function(touchmenu_instance)
                                if not cfg.flash_ghosting then return end
                                cfg.flash_page_turns = not (cfg.flash_page_turns == true)
                                saveConfig()
                                if touchmenu_instance then touchmenu_instance:updateItems() end
                            end,
                        },
                        {
                            text = _("Flash On Content Load"),
                            enabled_func = function() return cfg.flash_ghosting == true end,
                            checked_func = function() return cfg.flash_content == true end,
                            callback = function(touchmenu_instance)
                                if not cfg.flash_ghosting then return end
                                cfg.flash_content = not (cfg.flash_content == true)
                                saveConfig()
                                if touchmenu_instance then touchmenu_instance:updateItems() end
                            end,
                        },
                        {
                            text = _("Flash On Return To Dashboard"),
                            enabled_func = function() return cfg.flash_ghosting == true end,
                            checked_func = function() return cfg.flash_dashboard == true end,
                            callback = function(touchmenu_instance)
                                if not cfg.flash_ghosting then return end
                                cfg.flash_dashboard = not (cfg.flash_dashboard == true)
                                saveConfig()
                                if touchmenu_instance then touchmenu_instance:updateItems() end
                            end,
                        },
                        {
                            text = _("Flash On Settings Menu"),
                            enabled_func = function() return cfg.flash_ghosting == true end,
                            checked_func = function() return cfg.flash_menu_sheet == true end,
                            callback = function(touchmenu_instance)
                                if not cfg.flash_ghosting then return end
                                cfg.flash_menu_sheet = not (cfg.flash_menu_sheet == true)
                                saveConfig()
                                if touchmenu_instance then touchmenu_instance:updateItems() end
                            end,
                        },
                        {
                            text = _("Flash On Open"),
                            enabled_func = function() return cfg.flash_ghosting == true end,
                            checked_func = function() return cfg.flash_open == true end,
                            callback = function(touchmenu_instance)
                                if not cfg.flash_ghosting then return end
                                cfg.flash_open = not (cfg.flash_open == true)
                                saveConfig()
                                if touchmenu_instance then touchmenu_instance:updateItems() end
                            end,
                        },
                    },
                },
                {
                    text = _("Frequency"),
                    enabled_func = function() return cfg.flash_ghosting == true end,
                    sub_item_table = {
                        flashEveryItem(1),
                        flashEveryItem(2),
                        flashEveryItem(3),
                        flashEveryItem(5),
                    },
                },
            },
        },
        {
            text = _("Server Management"),
            sub_item_table_func = buildServerMenu,
        },
    }
end

local function lazyMenu()
    return {
        text = _("BookOrbit Tweaks"),
        sub_item_table_func = function()
            local ok, items = pcall(buildMenu)
            if ok and type(items) == "table" then
                return items
            end
            logger.warn(TAG, "could not build settings menu:", items)
            return {
                { text = _("Settings unavailable; see crash.log"), enabled = false },
            }
        end,
    }
end

-- Support the shared Add-ons menu if 2-tweaks-menu.lua is installed.
local tweaks = package.loaded.tweaks_mods
if type(tweaks) ~= "table" then
    tweaks = {}
    package.loaded.tweaks_mods = tweaks
end
tweaks.entries = tweaks.entries or {}
tweaks.entries[MENU_ID] = {
    text = "BookOrbit Tweaks",
    build = function()
        return lazyMenu()
    end,
}

-- Otherwise add a Tools > BookOrbit Tweaks entry. Install the wrapper only once
-- per menu module; add the item before the original update call rebuilds menus.
local function hookMenu(module_name)
    local ok, menu_module = pcall(require, module_name)
    if not ok or type(menu_module) ~= "table"
            or type(menu_module.setUpdateItemTable) ~= "function" then
        return
    end
    if menu_module._bookorbit_tweaks_v2_hooked then return end
    menu_module._bookorbit_tweaks_v2_hooked = true

    local original = menu_module.setUpdateItemTable
    menu_module.setUpdateItemTable = function(self, ...)
        if type(self.menu_items) == "table" then
            local addons_active = tweaks.active
                and (type(tweaks.shows) ~= "function" or tweaks.shows(MENU_ID))
            if not addons_active then
                local entry = lazyMenu()
                entry.sorting_hint = "tools"
                self.menu_items[MENU_ID] = entry
            end
        end
        return original(self, ...)
    end
end

pcall(hookMenu, "apps/filemanager/filemanagermenu")
pcall(hookMenu, "apps/reader/modules/readermenu")

logger.info(TAG, "========== v" .. VERSION .. " LOADED ==========")
