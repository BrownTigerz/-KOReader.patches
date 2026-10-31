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
  * Option: Action Colours (Tools > BookOrbit Tweaks): separate colours for
    Continue Reading (hero pill + download circle), Book Detail buttons, and
    Dialogs / open-book sheets. Optional Pill Colour Trace for crash.log.
  * Option: keep BookOrbit open through sleep, so it comes back instantly
    instead of reloading after every wake (off by default).
  * Add a separate BookOrbit Tweaks submenu to Tools (or the Add-ons menu
    supplied by 2-tweaks-menu.lua).

This patch hooks the real current module, bookorbit_catalog_widgets.
It does not alter BookOrbit sync, downloads, metadata, or reading progress.

Changes:
  2.15.3  2026-10-31  Add To Collection is also in a book page's ⋯ menu
                      (BookOrbit 2.0's page menu, above Refresh from
                      BookOrbit), not only the book sheet.
  2.15.2  2026-10-31  Add To Collection's sign-in box has a Save Password
                      tick (remembers your last choice, on to start) instead
                      of asking afterwards. Only a sign-in BookOrbit accepted
                      is saved; a wrong password never is.
  2.15.1  2026-10-31  Add To Collection's sign-in box no longer fills in your
                      KOReader sync username: that's a separate BookOrbit
                      account, often with a different name, so the right
                      password failed. It's empty the first time and says to
                      use your BookOrbit website login, then remembers the
                      website username. A refused sign-in says the same.
  2.15.0  2026-10-30  Add To Collection: BookOrbit's book sheet (hold a book
                      in a list, or ⋯ on a book's page) gets a row listing
                      your BookOrbit collections, ✓ on the ones the book is
                      in; tap to add or remove, or make a new collection. It
                      signs in like the web app (BookOrbit's KOReader sign-in
                      can't change collections); the password is saved only
                      if you say so, encrypted like ShelfSync Tweaks' logins,
                      and never in backups. A security notice explains all
                      that before the password is first asked for (and About
                      The Saved Password in the menu); Forget Saved BookOrbit
                      Password removes it. Results follow Network Tweaks'
                      notification style; failures stay popups.
  2.14.12 2026-10-30  Open Book Only From Buttons (off by default): on the
                      dashboard, only the Resume / Download pill and the round
                      play button open the book; a tap anywhere else on the
                      Continue Reading tile does nothing.
  2.14.11 2026-10-30  Fix: in Night Mode, Book Detail and Dialog colours came
                      out inverted (Blue showed as tan): the screen inverts
                      them, and only the dashboard hero is inverted back. Those
                      colours are now given pre-inverted in Night Mode, so they
                      show as picked.
  2.14.10 2026-10-30  Fix: Book Detail and Dialog colours looked pale and grainy
                      next to Continue Reading. A colour screen needs a
                      dithered refresh to show colour, and only BookOrbit's
                      dashboard gets one; each tinted button now asks for
                      one over its own rectangle.
                      Fix: picking White for Book Detail or Dialogs stuck only
                      until the next start (the Continue Reading colour was
                      copied over it again on every start; now only while
                      they were never set). The colour menus show the
                      colour's name instead of its hex code. Patch Backup &
                      Restore 3.0: registers its settings (saved server
                      logins and the library list stay out).
  2.14.9  2026-10-30  Action colours split three ways: Continue Reading (hero
                      pill + download circle), Book Detail (Start reading /
                      Read again / Resume), and Dialogs (bottom sheets /
                      open-book). Optional Pill Colour Trace logs matches to
                      crash.log. Blue (Sky) added as an explicit palette name.
  2.14.8  2026-10-30  Resume Pill Colour: stop tinting detail-page outline
                      chips and other rounded white boxes (they were picking
                      up the colour). Only the hero Resume/Download pill, the
                      px(40) Download circle, and solid black primary buttons.
  2.14.7  2026-10-30  Resume Pill Colour also tints the round Download button
                      (circle before it becomes the Resume pill) and the solid
                      action pills (Start reading, Read again, Resume on the
                      book detail page), not only the white hero Resume pill.
  2.14.6  2026-10-30  Clean-up: debugging trace lines removed from crash.log
                      (hooks, page loops, menu routes, setting changes); a
                      failed BookOrbit open is now logged as a warning; dead
                      code removed.
]]

local VERSION = "2.15.3"
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
    resume_pill_color = "#FFFFFF",  -- Continue reading hero pill / download circle
    detail_pill_color = "#FFFFFF",  -- Book detail Start reading / Read again / Resume
    dialog_pill_color = "#FFFFFF",  -- Bottom sheets / open-book dialog primary pills
    pill_color_trace = false,       -- log matches to crash.log (diagnose colour)
    after_close = "simpleui",
    library_filter_id = false,
    library_filter_name = "",
    server_chooser_in_settings = true,
    keep_open_sleep = false,   -- keep the catalog through sleep instead of closing it
    buttons_only_open = false, -- dashboard: only the Resume / Download buttons open a book
    collections_row = true,    -- book sheet: Add To Collection
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
    -- 2.14.9: split colours. Someone who only ever set resume_pill_color
    -- gets it on detail/dialog too, until they pick those themselves. Only
    -- while those were never saved, so a deliberate White sticks.
    if type(cfg.resume_pill_color) == "string" and cfg.resume_pill_color:upper() ~= "#FFFFFF" then
        local was = type(saved) == "table" and saved or {}
        if was.detail_pill_color == nil then cfg.detail_pill_color = cfg.resume_pill_color end
        if was.dialog_pill_color == nil then cfg.dialog_pill_color = cfg.resume_pill_color end
    end
end

-- Real (wall) time in seconds. os.clock is CPU time, which barely moves while
-- the device idles, so it made the flash debounce windows run long.
local function nowS()
    local ok, time = pcall(require, "ui/time")
    if ok and type(time) == "table" and time.now and time.to_s then
        return time.to_s(time.now())
    end
    return os.time()
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
        local w, h = self.dimen.w, self.dimen.h
        bb:invertRect(x, y, w, h)
        -- The widget-tree search is only a fallback: run it when the paint
        -- itself did not show where the cover went.
        local reverted = cover_rects
        if #reverted == 0 then reverted = collectCoverDimens(self.inner) end
        for _i, r in ipairs(reverted) do
            bb:invertRect(r[1], r[2], r[3], r[4])
        end
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
    return closed
end

-- Close BookOrbit sheets, dialogs and toasts but keep the catalog itself.
local function closeBookOrbitExtras(reason)
    local ok_ui, UIManager = pcall(require, "ui/uimanager")
    if not ok_ui or type(UIManager) ~= "table" or type(UIManager._window_stack) ~= "table" then return 0 end
    local stack, to_close = UIManager._window_stack, {}
    for i = #stack, 1, -1 do
        local w = stack[i] and stack[i].widget
        if isBookOrbitRelated(w) and not isBookOrbitWidget(w) then
            to_close[#to_close + 1] = w
        end
    end
    for _i, w in ipairs(to_close) do pcall(UIManager.close, UIManager, w) end
    return #to_close
end

-- One entry point for every sleep/wake hook (broadcast, event_handlers,
-- plugin onSuspend/onResume all fire on Kobo). Only the first hook of each
-- phase does the work; the rest return at once.
local sleep_phase = nil
local wake_task = nil
local function sleepWipe(phase, reason)
    if phase == "Suspend" and wake_task then
        local ok_ui, UIManager = pcall(require, "ui/uimanager")
        if ok_ui then pcall(UIManager.unschedule, UIManager, wake_task) end
        wake_task = nil
    end
    if sleep_phase == phase then return 0 end
    sleep_phase = phase
    if cfg.keep_open_sleep then
        if phase == "Suspend" then return closeBookOrbitExtras(reason) end
        return 0
    end
    return closeAllBookOrbitCatalogs(reason)
end

-- Nuclear open: close any leftover catalog, then open fresh via the live plugin.
local function forceOpenBookOrbit(reason)
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
        logger.warn(TAG, "forceOpenBookOrbit: no plugin instance")
        return false
    end
    plugin.catalog_browser = nil
    local opened
    if type(plugin.browseCatalog) == "function" then
        local ok, err = pcall(plugin.browseCatalog, plugin, false)
        if not ok then logger.warn(TAG, "browseCatalog failed:", err) end
        opened = ok and true or false
    elseif type(plugin.openBookOrbit) == "function" then
        local ok, err = pcall(plugin.openBookOrbit, plugin)
        if not ok then logger.warn(TAG, "openBookOrbit failed:", err) end
        opened = ok and true or false
    else
        logger.warn(TAG, "forceOpenBookOrbit: no browseCatalog/openBookOrbit")
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
        end
    end
    return opened
end

-- Keep-open mode: bring the catalog that survived sleep back instead of
-- reloading it. Closes BookOrbit sheets above it and SimpleUI home.
-- Returns false when there is no catalog to bring back.
local function raiseKeptCatalog(reason)
    local idx, stack, UIManager = findCatalogOnStack(nil)
    if not idx or not stack or not UIManager then return false end
    local above = {}
    for i = #stack, idx + 1, -1 do
        local w = stack[i] and stack[i].widget
        if isBookOrbitRelated(w) then above[#above + 1] = w end
    end
    for _i, w in ipairs(above) do pcall(UIManager.close, UIManager, w) end
    local _, widget = raiseCatalogWindow(nil)
    if not widget then return false end
    if cfg.reopen_at == "home" and type(widget.dashboardMode) == "function"
            and type(widget.goDashboard) == "function" and not widget:dashboardMode() then
        pcall(widget.goDashboard, widget)
    end
    return true, widget
end

local function openOrRaise(reason)
    if cfg.keep_open_sleep and raiseKeptCatalog(reason) then return true end
    return forceOpenBookOrbit(reason)
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
                -- After sleep the catalog is often buried under SimpleUI home and
                -- the normal early-return path does nothing. Always force a clean open.
                openOrRaise("dispatcher")
                return true
            end
            return original(self, action_id, ...)
        end
    end

    local ok_ui, UIManager = pcall(require, "ui/uimanager")
    if ok_ui and type(UIManager) == "table" and type(UIManager.sendEvent) == "function"
            and not UIManager._bookorbit_tweaks_sendevent then
        UIManager._bookorbit_tweaks_sendevent = true
        local original_send = UIManager.sendEvent
        UIManager.sendEvent = function(self, event, ...)
            local name = type(event) == "table" and event.name
            if name == "BookOrbitOpenDashboard" then
                openOrRaise("sendEvent")
                return true
            end
            -- Second swipe south on any BookOrbit menu/settings chrome -> tools menu.
            if cfg.second_swipe_tools and (name == "Swipe" or name == "Gesture" or name == "SwipePage") then
                local stack = self._window_stack
                local top = type(stack) == "table" and stack[#stack]
                local w = top and top.widget
                local is_sheet = false
                if type(w) == "table" and type(w.name) == "string" then
                    local n = w.name
                    is_sheet = n:find("bookorbit_menu_sheet", 1, true)
                        or n:find("bookorbit_settings", 1, true)
                        or n:find("bookorbit_sign_in", 1, true)
                        or n:find("bookorbit_status", 1, true)
                        or n:find("bookorbit_diagnostics", 1, true)
                        or n:find("bookorbit_menu", 1, true)
                        or n:find("bookorbit_server", 1, true)
                end
                if is_sheet then
                    local a = event.args
                    local ges = type(a) == "table" and (a[2] or a[1]) or nil
                    if type(ges) ~= "table" and name == "Gesture" then
                        ges = a and a[1] or event
                    end
                    if type(ges) ~= "table" and type(event.ges) == "table" then
                        ges = event.ges
                    end
                    if type(ges) == "table" and ges.direction == "south" then
                        pcall(function() self:close(w) end)
                        pcall(function()
                            self:nextTick(function()
                                local function tryMenu(mod_name)
                                    local M = package.loaded[mod_name]
                                    local inst = type(M) == "table" and M.instance
                                    local menu = type(inst) == "table" and inst.menu
                                    if type(menu) == "table" and type(menu.onShowMenu) == "function" then
                                        pcall(menu.onShowMenu, menu)
                                        return true
                                    end
                                    return false
                                end
                                if tryMenu("apps/filemanager/filemanager") then return end
                                if tryMenu("apps/reader/readerui") then return end
                                local ok_d, Dispatcher = pcall(require, "dispatcher")
                                if ok_d and type(Dispatcher) == "table" and type(Dispatcher.execute) == "function" then
                                    pcall(Dispatcher.execute, Dispatcher, "show_menu")
                                    return
                                end
                                local ok_ev, Event = pcall(require, "ui/event")
                                if ok_ev then
                                    pcall(function() self:sendEvent(Event:new("ShowMenu")) end)
                                end
                            end)
                        end)
                        return true
                    end
                end
            end
            return original_send(self, event, ...)
        end
        -- Attach second-swipe handler whenever a BookOrbit menu/settings widget is shown
        if not UIManager._bookorbit_tweaks_show_second_swipe then
            UIManager._bookorbit_tweaks_show_second_swipe = true
            local original_show = UIManager.show
            UIManager.show = function(self, widget, ...)
                local res = original_show(self, widget, ...)
                if cfg.second_swipe_tools and type(widget) == "table" and type(widget.name) == "string" then
                    local n = widget.name
                    if n:find("bookorbit_menu_sheet", 1, true)
                            or n:find("bookorbit_settings", 1, true)
                            or n:find("bookorbit_sign_in", 1, true)
                            or n:find("bookorbit_status", 1, true)
                            or n:find("bookorbit_diagnostics", 1, true)
                            or n:find("bookorbit_menu", 1, true)
                            or n:find("bookorbit_server", 1, true) then
                        local attach = package.loaded.bookorbit_tweaks_attach_second_swipe
                        if type(attach) == "function" then
                            pcall(attach, widget)
                        end
                    end
                end
                return res
            end
        end
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
                pcall(sleepWipe, name, "broadcast-" .. tostring(name))
            end
            local res = original_broadcast(self, event, ...)
            if name == "Resume" and not cfg.keep_open_sleep then
                pcall(function()
                    self:nextTick(function()
                        closeAllBookOrbitCatalogs("resume-nextTick")
                    end)
                    -- One more pass after SimpleUI shows home. Cancelled if
                    -- the device sleeps again first.
                    wake_task = function()
                        wake_task = nil
                        closeAllBookOrbitCatalogs("resume-0.5s")
                    end
                    self:scheduleIn(0.5, wake_task)
                end)
            end
            return res
        end
    end

    if ok_ui and type(UIManager) == "table" and type(UIManager.event_handlers) == "table" then
        local handlers = UIManager.event_handlers
        if type(handlers.Resume) == "function" and not handlers._bookorbit_tweaks_resume then
            handlers._bookorbit_tweaks_resume = true
            local original_resume_handler = handlers.Resume
            handlers.Resume = function(...)
                pcall(sleepWipe, "Resume", "event_handlers.Resume")
                local res = original_resume_handler(...)
                if not cfg.keep_open_sleep then
                    pcall(function()
                        UIManager:nextTick(function()
                            closeAllBookOrbitCatalogs("handler-nextTick")
                        end)
                    end)
                end
                return res
            end
        end
        if type(handlers.Suspend) == "function" and not handlers._bookorbit_tweaks_suspend then
            handlers._bookorbit_tweaks_suspend = true
            local original_suspend_handler = handlers.Suspend
            handlers.Suspend = function(...)
                pcall(sleepWipe, "Suspend", "event_handlers.Suspend")
                return original_suspend_handler(...)
            end
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
                if cfg.keep_open_sleep then
                    local ok_k, widget_k = raiseKeptCatalog("ensure-visible")
                    if ok_k then
                        if self.catalog_browser == nil then self.catalog_browser = widget_k end
                        return true
                    end
                end
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
        sleepWipe("Resume", "plugin-resume")
        if not cfg.keep_open_sleep then self.catalog_browser = nil end
    end
    local function wipeCatalogBeforeSuspend(self)
        sleepWipe("Suspend", "plugin-suspend")
        if not cfg.keep_open_sleep then self.catalog_browser = nil end
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
                pcall(sleepWipe, "Resume", "late-handler-Resume")
                local res = original_resume_handler(...)
                if not cfg.keep_open_sleep then
                    pcall(function()
                        UIManager:nextTick(function()
                            closeAllBookOrbitCatalogs("late-handler-nextTick")
                        end)
                    end)
                end
                return res
            end
        end
        if type(handlers.Suspend) == "function" and not handlers._bookorbit_tweaks_suspend then
            handlers._bookorbit_tweaks_suspend = true
            local original_suspend_handler = handlers.Suspend
            handlers.Suspend = function(...)
                pcall(sleepWipe, "Suspend", "late-handler-Suspend")
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
            -- Prefer the live FileManager or ReaderUI menu instance (original toolbar).
            local function tryMenu(mod_name)
                local M = package.loaded[mod_name]
                local inst = type(M) == "table" and M.instance
                local menu = type(inst) == "table" and inst.menu
                if type(menu) == "table" and type(menu.onShowMenu) == "function" then
                    pcall(menu.onShowMenu, menu)
                    return true
                end
                return false
            end
            if tryMenu("apps/filemanager/filemanager") then return true end
            if tryMenu("apps/reader/readerui") then return true end

            -- Dispatcher path used by many gestures / toolbar shortcuts.
            local ok_d, Dispatcher = pcall(require, "dispatcher")
            if ok_d and type(Dispatcher) == "table" and type(Dispatcher.execute) == "function" then
                local ok = pcall(Dispatcher.execute, Dispatcher, "show_menu")
                if ok then
                    return true
                end
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
            logger.warn(TAG, "openToolsMenu: no menu path available")
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
                local ok_ui, UIManager = pcall(require, "ui/uimanager")
                if ok_ui then
                    pcall(function() UIManager:close(widget) end)
                end
                -- Defer tools menu one tick so the sheet is fully closed first.
                if ok_ui then
                    pcall(function()
                        UIManager:nextTick(function()
                            openToolsMenu()
                        end)
                    end)
                else
                    openToolsMenu()
                end
                return true
            end

            -- BookOrbit MenuPage registers ges_events.SwipePage → onSwipePage
            -- (not onSwipe). That was why the second swipe never fired.
            local original_swipe_page = widget.onSwipePage
            widget.onSwipePage = function(this, arg, ges_ev)
                if maybeToolsFromSouth(ges_ev) then return true end
                if type(original_swipe_page) == "function" then
                    return original_swipe_page(this, arg, ges_ev)
                end
                return true
            end

            -- Keep onSwipe too in case a future build or intermediate wrapper uses it.
            local original_swipe = widget.onSwipe
            widget.onSwipe = function(this, arg, ges_ev)
                if maybeToolsFromSouth(ges_ev) then return true end
                if type(original_swipe) == "function" then
                    return original_swipe(this, arg, ges_ev)
                end
            end

            -- Also catch Event:new("Swipe", ...) / Gesture if they reach handleEvent.
            local original_handle = widget.handleEvent
            if type(original_handle) == "function" then
                widget.handleEvent = function(this, event, ...)
                    if type(event) == "table" then
                        local ename = event.name
                        if ename == "Swipe" or ename == "SwipePage" or ename == "Gesture" then
                            local a = event.args
                            local ges = type(a) == "table" and (a[2] or a[1]) or nil
                            if type(ges) ~= "table" and ename == "Gesture" then
                                ges = (a and a[1]) or event
                            end
                            if type(ges) ~= "table" and type(event.ges) == "table" then
                                ges = event.ges
                            end
                            if maybeToolsFromSouth(ges) then return true end
                        end
                    end
                    return original_handle(this, event, ...)
                end
            end
            -- Expose for MenuPage / UIManager.show hooks
            package.loaded.bookorbit_tweaks_attach_second_swipe = attachSecondSwipe
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
                        if type(w) == "table" and type(w.name) == "string" then
                            local n = w.name
                            if n:find("bookorbit_menu_sheet", 1, true)
                                    or n:find("bookorbit_settings", 1, true)
                                    or n:find("bookorbit_sign_in", 1, true)
                                    or n:find("bookorbit_status", 1, true)
                                    or n:find("bookorbit_diagnostics", 1, true)
                                    or n:find("bookorbit_menu", 1, true)
                                    or n:find("bookorbit_server", 1, true) then
                                attachSecondSwipe(w)
                                return
                            end
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
    return true
end

-- ---- Page looping + optional flash on page turns ------------------------------------
-- When loop_pages is on, a swipe that would have been a no-op at either end
-- of a multi-page book list wraps to the other end. When loop_pages is off,
-- boundary swipes stay no-ops and do not arm the flash.
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
            catalog:onGotoPage(1)
            return true
        elseif direction < 0 and page <= 1 then
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
            ctx.board_page = 1
            if type(catalog.updateItems) == "function" then
                catalog:updateItems(nil, true)
            end
            return true
        elseif direction < 0 and page <= 1 then
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
            local now_c = nowS()
            if (now_c - last_flashed_clock) < 3 then
                return
            end
        end
        -- No Tweaks flash while the catalog is not topmost: init-time content
        -- loads used to flash on the file browser, then KOReader's show flash
        -- fired on the catalog -- the double flash on open. Fail open if the
        -- window stack is unreadable, so flash never silently dies.
        -- Only the topmost real window counts (toasts and modals are skipped);
        -- the old loop scanned the whole stack and its answer was never used.
        if catalog then
            local ok_ui2, UIManager2 = pcall(require, "ui/uimanager")
            if ok_ui2 and type(UIManager2) == "table" and type(UIManager2._window_stack) == "table" then
                local top = true
                local st = UIManager2._window_stack
                for i = #st, 1, -1 do
                    local w = st[i] and st[i].widget
                    local n = type(w) == "table" and type(w.name) == "string" and w.name or ""
                    local transient = type(w) == "table" and (w.modal
                        or n:find("toast", 1, true) or n:find("InfoMessage", 1, true))
                    if not transient then
                        top = (w == catalog) or (w == catalog.show_parent)
                            or n:lower():find("bookorbit", 1, true) ~= nil
                        break
                    end
                end
                if not top then return end
            end
        end
        local now = nowS()
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
                if not (open_t > 0 and (nowS() - open_t) < 8) then
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
            open_t = nowS()
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
    return true
end

-- ---- Action pill colours (hero / detail / dialogs) --------------------------------
-- Three independent colours (each can be White = plugin default):
--   resume_pill_color  Continue reading hero: white text pill + download circle
--   detail_pill_color  Book detail solid primary (Start reading / Read again)
--   dialog_pill_color  Bottom sheets / open-book dialog primary pills (MenuUI)
-- Pill Colour Trace logs every match (and near-miss hero sizes) to crash.log.
local PILL_COLORS = {
    { "White", "#FFFFFF" }, { "Silver", "#AAAAAA" }, { "Light grey", "#CCCCCC" },
    { "Blue", "#6FB7E9" }, { "Sky", "#6FB7E9" }, { "Pink", "#E78FB3" },
    { "Gold", "#D4A017" }, { "Mint", "#A8E6CF" }, { "Lavender", "#D8B4FE" },
}

-- Shown name of a saved colour ("Blue"), or the hex itself if it's not one of ours.
local function pillColorName(hex)
    if type(hex) ~= "string" then return "White" end
    for _i, c in ipairs(PILL_COLORS) do
        if c[2]:upper() == hex:upper() then return c[1] end
    end
    return hex
end

-- invert: for buttons outside the dashboard hero in Night Mode. The screen
-- inverts everything there, so a colour given already inverted shows as
-- picked (the hero tile is inverted back by BookOrbit, so it doesn't need it).
local function pillColorValue(hex, invert)
    if type(hex) ~= "string" then return nil end
    local r, g, b = hex:match("^#?(%x%x)(%x%x)(%x%x)$")
    if not r then return nil end
    r, g, b = tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
    if invert then r, g, b = 255 - r, 255 - g, 255 - b end
    local ok_bb, Blitbuffer = pcall(require, "ffi/blitbuffer")
    if not ok_bb or type(Blitbuffer) ~= "table" then return nil end
    if r == g and g == b then return Blitbuffer.Color8(r) end
    return Blitbuffer.ColorRGB32(r, g, b, 0xFF)
end

local function hexActive(hex)
    return type(hex) == "string" and hex:upper() ~= "#FFFFFF"
end

local function pillTrace(...)
    if cfg.pill_color_trace then
        logger.info(TAG, "pill-color", ...)
    end
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
    local original_circle = BoardUI.circle
    -- While a BookOrbit dialog/sheet is open, solid black pills use dialog colour.
    local in_dialog = 0

    local function rgbOf(c)
        if not c then return nil end
        local ok, rgb = pcall(function() return c:getColorRGB32() end)
        if ok and rgb then return rgb.r, rgb.g, rgb.b end
        return nil
    end
    local function isWhite(c)
        local r, g, b = rgbOf(c)
        return r == 255 and g == 255 and b == 255
    end
    local function isBlack(c)
        local r, g, b = rgbOf(c)
        return r == 0 and g == 0 and b == 0
    end
    -- A colour screen (Kaleido) shows colour properly only through a
    -- dithered refresh. BookOrbit gives its dashboard one, but a book's page
    -- and the dialogs refresh without it, so the same colour came out pale
    -- and grainy there. A tinted button asks for one over its own rectangle
    -- once it's painted (a refresh only, nothing is painted again).
    local function ditherAfterPaint(w)
        if type(w) ~= "table" or type(w.paintTo) ~= "function" then return w end
        local Screen = require("device").screen
        if not (Screen and Screen.isColorEnabled and Screen:isColorEnabled()) then return w end
        local orig_paint = w.paintTo
        w.paintTo = function(self, bb, x, y)
            orig_paint(self, bb, x, y)
            local d = self.dimen
            if bb == Screen.bb and d and d.x and d.w and d.w > 0 then
                local region = require("ui/geometry"):new{ x = d.x, y = d.y, w = d.w, h = d.h }
                require("ui/uimanager"):setDirty(nil, function() return "partial", region, true end)
            end
        end
        return w
    end

    local function withBg(o, col)
        local copy = {}
        for k, v in pairs(o) do copy[k] = v end
        copy.bg = col
        return copy
    end
    local function isRoundedAction(o)
        if type(o) ~= "table" or type(o.h) ~= "number" or type(o.radius) ~= "number" then
            return false
        end
        local h = o.h
        if h < BoardMetrics.px(34) or h > BoardMetrics.px(52) then return false end
        local half = math.floor(h / 2)
        return o.radius >= half - 1 and o.radius <= half + 1
    end

    BoardUI.box = function(o, child)
        if type(o) == "table" then
            local border = o.border or 0
            local h, r = o.h, o.radius
            local br, bg, bb = rgbOf(o.bg)
            -- Hero Continue reading text pill (white, exact 40/20, no border)
            if hexActive(cfg.resume_pill_color) and isWhite(o.bg) and border == 0
                    and h == BoardMetrics.px(40) and r == BoardMetrics.px(20) then
                local col = pillColorValue(cfg.resume_pill_color)
                pillTrace("MATCH hero-pill", "cfg=" .. tostring(cfg.resume_pill_color),
                    "h=" .. tostring(h), "r=" .. tostring(r), "bg=" .. tostring(br))
                if col then return ditherAfterPaint(original_box(withBg(o, col), child)) end
            -- Near-miss hero (trace only): white, no border, near 40 tall
            elseif cfg.pill_color_trace and isWhite(o.bg) and border == 0
                    and type(h) == "number" and h >= BoardMetrics.px(36) and h <= BoardMetrics.px(44) then
                pillTrace("near-miss hero-pill?",
                    "h=" .. tostring(h) .. " want " .. tostring(BoardMetrics.px(40)),
                    "r=" .. tostring(r) .. " want " .. tostring(BoardMetrics.px(20)),
                    "bgRGB=" .. tostring(br) .. "," .. tostring(bg) .. "," .. tostring(bb))
            -- Solid primary: black, no border, rounded action height
            elseif isBlack(o.bg) and border == 0 and isRoundedAction(o) then
                local hex = (in_dialog > 0) and cfg.dialog_pill_color or cfg.detail_pill_color
                if hexActive(hex) then
                    local ok_dev, Device = pcall(require, "device")
                    local night = ok_dev and Device.screen and Device.screen.night_mode == true
                    local col = pillColorValue(hex, night)
                    pillTrace("MATCH solid-primary", night and "night" or "day",
                        (in_dialog > 0) and "dialog" or "detail",
                        "cfg=" .. tostring(hex),
                        "h=" .. tostring(h), "r=" .. tostring(r))
                    if col then return ditherAfterPaint(original_box(withBg(o, col), child)) end
                end
            end
        end
        return original_box(o, child)
    end

    if type(original_circle) == "function" then
        BoardUI.circle = function(d, o, child)
            if hexActive(cfg.resume_pill_color) and type(o) == "table" and type(d) == "number"
                    and d == BoardMetrics.px(40)
                    and isWhite(o.bg)
                    and (o.border or 0) == 0 then
                local col = pillColorValue(cfg.resume_pill_color)
                pillTrace("MATCH hero-circle", "cfg=" .. tostring(cfg.resume_pill_color), "d=" .. tostring(d))
                if col then return ditherAfterPaint(original_circle(d, withBg(o, col), child)) end
            elseif cfg.pill_color_trace and type(o) == "table" and type(d) == "number"
                    and d >= BoardMetrics.px(32) and d <= BoardMetrics.px(48) and isWhite(o.bg) then
                pillTrace("near-miss hero-circle?",
                    "d=" .. tostring(d) .. " want " .. tostring(BoardMetrics.px(40)),
                    "border=" .. tostring(o.border))
            end
            return original_circle(d, o, child)
        end
    end

    -- Track dialog/sheet builds so solid pills there use dialog_pill_color.
    local ok_d, DialogUI = pcall(require, "bookorbit_dialog_ui")
    if ok_d and type(DialogUI) == "table" and type(DialogUI.open) == "function"
            and not DialogUI._bookorbit_tweaks_pill_flag then
        DialogUI._bookorbit_tweaks_pill_flag = true
        local orig_open = DialogUI.open
        DialogUI.open = function(...)
            in_dialog = in_dialog + 1
            local ok, a, b, c = pcall(orig_open, ...)
            in_dialog = math.max(0, in_dialog - 1)
            if not ok then error(a, 0) end
            return a, b, c
        end
    end

    return true
end

-- ---- Flash on BookOrbit settings / menu pages --------------------------------------
-- Open Book Only From Buttons: on the dashboard, a tap on the Continue
-- Reading tile (or the chapters / forecast tiles) outside its buttons opened
-- the book. That tap is the tile's default action; with the option on it
-- does nothing, and the Resume / Download / play buttons still open the book.
local function hookButtonsOnly()
    local ok, Catalog = pcall(require, "bookorbit_catalog")
    if not ok or type(Catalog) ~= "table" or type(Catalog.boardItemAction) ~= "function" then return false end
    if Catalog._bookorbit_tweaks_buttons_only then return true end
    Catalog._bookorbit_tweaks_buttons_only = true
    local original = Catalog.boardItemAction
    Catalog.boardItemAction = function(self, item, d, ...)
        local action = original(self, item, d, ...)
        if cfg.buttons_only_open and type(action) == "table" and action.kind == "book" then
            return nil
        end
        return action
    end
    return true
end

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
        -- Second swipe (original tools menu) on settings / menu pages
        if cfg.second_swipe_tools then
            local attach = package.loaded.bookorbit_tweaks_attach_second_swipe
            if type(attach) == "function" then
                pcall(attach, self)
            end
        end
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

        return page
    end
    return true
end

-- ---- Settings → Account: Server row shows saved-server picker ----------------------
-- The Account page (Server / Signed in as / Test connection) uses action kind
-- "server" → plugin:setServerAddress. Intercept both the settings page action
-- and setServerAddress so a saved list appears when you have profiles.
local function showServerChooser(plugin, on_enter_new, on_switched)
    -- Single-tap fix: if we are already inside an "Enter A Different
    -- Address..." escape (skip flag set by the MenuPage or Settings hook),
    -- do NOT show a second identical chooser. Go straight to the original
    -- action, which reaches setServerAddress unwrapped and opens the entry.
    -- Without this, the MenuPage path stacked two choosers and Enter
    -- Different had to be tapped twice (TK: chooser stayed, 2-3 presses).
    if skip_server_chooser then
        if on_enter_new then on_enter_new() end
        return
    end
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
                        -- Same skip-flag protection as the MenuPage and
                        -- setServerAddress hooks: without it, the original
                        -- action's setServerAddress call is re-intercepted
                        -- and the chooser pops back up instead of the entry.
                        skip_server_chooser = true
                        local ok, err = pcall(function()
                            if type(original_action) == "function" then
                                original_action(p, action)
                            elseif type(plugin.setServerAddress) == "function" then
                                plugin:setServerAddress(function()
                                    if p.refresh then p:refresh() end
                                end)
                            end
                        end)
                        skip_server_chooser = false
                        if not ok then error(err, 0) end
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


-- ---- Add To Collection --------------------------------------------------------------
-- BookOrbit's book sheet (hold a book in a list, or ⋯ on a book's page) gets
-- an "Add To Collection" row: your BookOrbit collections, ✓ on the ones the
-- book is in; tap to add or remove, or make a new one. BookOrbit's KOReader
-- sign-in can't change collections, so this signs in like the web app, with
-- your BookOrbit password. Saved only if you say so, AES-encrypted with a key
-- kept in its own file (like ShelfSync Tweaks), and never in backups.

local T = require("ffi/util").template
local LOGIN_FILE = "bookorbit_tweaks_login.lua"

-- Shared notification contract (same as Network Tweaks' other patches):
-- results follow Network Tweaks' style (Banner / Minimal / Normal), then
-- ReadMastery's, else a short KOReader note; never over the sleep screen.
-- Questions and failures always stay popups.
local function note(banner_text, minimal_text, timeout)
    timeout = timeout or 2
    local okd, Device = pcall(require, "device")
    if okd and Device.screen_saver_mode then return end
    local okn, NetworkMgr = pcall(require, "ui/network/manager")
    if okn and type(NetworkMgr) == "table" and type(NetworkMgr.__network_tweaks_note) == "function" then
        local ok, handled = pcall(NetworkMgr.__network_tweaks_note, banner_text, minimal_text, timeout)
        if ok and handled then return end
    end
    local rm = _G.__readmastery_note
    if type(rm) == "function" then
        local ok, handled = pcall(rm, banner_text or minimal_text, timeout)
        if ok and handled then return end
    end
    local UIManager = require("ui/uimanager")
    UIManager:show(require("ui/widget/infomessage"):new{ text = banner_text, timeout = timeout })
end
local function failure(text)
    local UIManager = require("ui/uimanager")
    UIManager:show(require("ui/widget/infomessage"):new{ text = text })
end

-- Shown before the password is first asked for, and from the menu.
local SECURITY_TEXT = _([[
Add To Collection needs your BookOrbit password.

• Why: BookOrbit's KOReader sign-in can read your library and sync, but it can't change collections. Only the web sign-in can, the same one the BookOrbit website uses.
• Where it goes: only to your own BookOrbit server's sign-in, over the server address you set in BookOrbit. Nothing is sent anywhere else.
• While KOReader runs: the server's session key is kept in memory for 10 minutes, then it signs in again. Nothing about the session is written to disk.
• If you save it: it's encrypted (AES-256) in koreader/settings/bookorbit_tweaks_login.lua, with the key in a separate file, bookorbit_tweaks_keyring.lua. That stops someone casually browsing your files. It does not stop someone with full access to the e-reader, because the key is on the same device.
• Backups: neither file goes into Patch Backup & Restore's backups or device backups.
• Remove it anytime: BookOrbit Tweaks > Forget Saved BookOrbit Password.
If you'd rather not keep it, untick Save Password in the sign-in box: you'll be asked again after 10 minutes or a restart. Only a sign-in BookOrbit accepts is ever saved.]])
local KEYRING_FILE = "bookorbit_tweaks_keyring.lua"

local Crypto = {}
do
    local ok_ffi, ffi = pcall(require, "ffi")
    local lib, cdef_done
    local function libcrypto()
        if lib ~= nil then return lib or nil end
        if not ok_ffi then lib = false return nil end
        local ok, res = pcall(function()
            if not cdef_done then
                cdef_done = true
                pcall(ffi.cdef, [[
                    typedef struct engine_st ENGINE;
                    typedef struct evp_cipher_st EVP_CIPHER;
                    typedef struct evp_cipher_ctx_st EVP_CIPHER_CTX;
                    EVP_CIPHER_CTX *EVP_CIPHER_CTX_new(void);
                    void EVP_CIPHER_CTX_free(EVP_CIPHER_CTX *);
                    int EVP_EncryptInit_ex(EVP_CIPHER_CTX *, const EVP_CIPHER *, ENGINE *, const unsigned char *, const unsigned char *);
                    int EVP_EncryptUpdate(EVP_CIPHER_CTX *, unsigned char *, int *, const unsigned char *, int);
                    int EVP_EncryptFinal_ex(EVP_CIPHER_CTX *, unsigned char *, int *);
                    int EVP_DecryptInit_ex(EVP_CIPHER_CTX *, const EVP_CIPHER *, ENGINE *, const unsigned char *, const unsigned char *);
                    int EVP_DecryptUpdate(EVP_CIPHER_CTX *, unsigned char *, int *, const unsigned char *, int);
                    int EVP_DecryptFinal_ex(EVP_CIPHER_CTX *, unsigned char *, int *);
                    const EVP_CIPHER *EVP_aes_256_cbc(void);
                    int RAND_bytes(unsigned char *, int);
                ]])
            end
            if ffi.loadlib then return ffi.loadlib("crypto", "57") end
            local okl, l = pcall(ffi.load, "libs/libcrypto.so.57")
            if okl and l then return l end
            return ffi.load("crypto")
        end)
        lib = (ok and res) or false
        return lib or nil
    end
    local function hex(s) return (s:gsub(".", function(c) return string.format("%02x", c:byte()) end)) end
    local function unhex(s)
        if type(s) ~= "string" or not s:match("^%x*$") or #s % 2 ~= 0 then return nil end
        return (s:gsub("%x%x", function(cc) return string.char(tonumber(cc, 16)) end))
    end
    local function rand(l, n)
        local buf = ffi.new("unsigned char[?]", n)
        if l.RAND_bytes(buf, n) ~= 1 then return nil end
        return ffi.string(buf, n)
    end
    local function cipher(encrypt, key, iv, input)
        local l = libcrypto()
        if not l then return nil end
        local ctx = l.EVP_CIPHER_CTX_new()
        if ctx == nil then return nil end
        local init = encrypt and l.EVP_EncryptInit_ex or l.EVP_DecryptInit_ex
        local update = encrypt and l.EVP_EncryptUpdate or l.EVP_DecryptUpdate
        local final = encrypt and l.EVP_EncryptFinal_ex or l.EVP_DecryptFinal_ex
        local out, out_len
        local ok = init(ctx, l.EVP_aes_256_cbc(), nil, key, iv) == 1
        if ok then
            out = ffi.new("unsigned char[?]", #input + 16)
            local n1, n2 = ffi.new("int[1]"), ffi.new("int[1]")
            ok = update(ctx, out, n1, input, #input) == 1 and final(ctx, out + n1[0], n2) == 1
            if ok then out_len = n1[0] + n2[0] end
        end
        l.EVP_CIPHER_CTX_free(ctx)
        return ok and ffi.string(out, out_len) or nil
    end
    local function key()
        local l = libcrypto()
        if not l then return nil end
        local s = require("luasettings"):open(require("datastorage"):getSettingsDir() .. "/" .. KEYRING_FILE)
        local k = unhex(s:readSetting("aes_key"))
        if k and #k == 32 then return k end
        k = rand(l, 32)
        if not k then return nil end
        s:saveSetting("aes_key", hex(k))
        s:flush()
        return k
    end
    function Crypto.encrypt(plain)
        local ok, res = pcall(function()
            local k = key()
            local l = libcrypto()
            local iv = k and rand(l, 16)
            local c = iv and cipher(true, k, iv, plain)
            return c and hex(iv .. c) or nil
        end)
        return ok and res or nil
    end
    function Crypto.decrypt(blob)
        local ok, res = pcall(function()
            local raw, k = unhex(blob), key()
            if not (raw and k and #raw > 16) then return nil end
            return cipher(false, k, raw:sub(1, 16), raw:sub(17))
        end)
        return ok and res or nil
    end
end

local function loginStore()
    return require("luasettings"):open(require("datastorage"):getSettingsDir() .. "/" .. LOGIN_FILE)
end

-- server url -> { token, until }: the web session, in memory only
local web_sessions = {}

-- the website username last signed in with (kept with a saved password,
-- else for this session), to fill in next time
local typed_users = {}
local function last_web_user(server)
    local saved = loginStore():readSetting(server)
    if type(saved) == "table" and type(saved.username) == "string" then return saved.username end
    return typed_users[server]
end

local function forgetLogin(server)
    web_sessions[server] = nil
    local s = loginStore()
    local saved = s:readSetting(server)
    if type(saved) == "table" and type(saved.username) == "string" then typed_users[server] = saved.username end
    s:delSetting(server)
    s:flush()
end

-- Signs in the way the web app does and hands the access token to done().
-- Uses a saved password when there is one; otherwise asks, then offers to
-- save it.
local function webSignIn(catalog, done, ask)
    local client = catalog.client
    local server = client and client.server_url
    if not server then return end
    local cached = web_sessions[server]
    if not ask and cached and cached.token and os.time() < cached["until"] then return done(cached.token) end

    local UIManager = require("ui/uimanager")
    -- typed: from the sign-in box (else the saved password); save: its
    -- Save Password tick. Only a sign-in the server accepted gets saved.
    local function login(username, password, typed, save)
        local body, err = catalog:fetch(_("Signing in to BookOrbit…"), function()
            return client:requestBlocking("POST", "/auth/login",
                { username = username, password = password, clientKind = "native", deviceLabel = "KOReader" })
        end)
        if not (type(body) == "table" and type(body.accessToken) == "string") then
            if err == "cancelled" then return end
            if not typed then forgetLogin(server) end -- a saved password that no longer works
            failure(err == 401 and _("BookOrbit didn't accept that username or password.\n\nUse the login you sign in to the BookOrbit website with. Your KOReader sync username can be different.") or T(_("Couldn't sign in to BookOrbit:\n%1"), tostring(err)))
            if not typed then return webSignIn(catalog, done, true) end
            return
        end
        web_sessions[server] = { token = body.accessToken, ["until"] = os.time() + 10 * 60 }
        typed_users[server] = username
        if typed and save then
            local enc = Crypto.encrypt(password)
            if enc then
                local st = loginStore()
                st:saveSetting(server, { username = username, password_enc = enc })
                st:flush()
                note(_("Signed in. Password saved on this device (encrypted)."), _("Password saved"))
            else
                -- never kept in plain text
                failure(_("Signed in, but encryption isn't available on this device, so the password wasn't saved. You'll be asked for it again after a restart."))
            end
        end
        return done(body.accessToken)
    end

    if not ask then
        local saved = loginStore():readSetting(server)
        local password = type(saved) == "table" and Crypto.decrypt(saved.password_enc)
        if password then return login(saved.username, password, false, false) end
    end
    local function askPassword()
    local MultiInputDialog = require("ui/widget/multiinputdialog")
    local CheckButton = require("ui/widget/checkbutton")
    local dlg, save_box
    dlg = MultiInputDialog:new{
        title = _("Sign in to BookOrbit"),
        description = _("Your BookOrbit website login (not your KOReader sync name)."),
        fields = {
            -- not the sync username: that's a separate account and often a
            -- different name, which made the right password fail
            { text = last_web_user(server) or "", hint = _("Website username") },
            { text = "", hint = _("Password"), text_type = "password" },
        },
        buttons = {{
            { text = _("Cancel"), id = "close", callback = function() UIManager:close(dlg) end },
            { text = _("Sign In"), is_enter_default = true, callback = function()
                local f = dlg:getFields()
                local save = save_box and save_box.checked or false
                UIManager:close(dlg)
                if f[1] ~= "" and f[2] ~= "" then login(f[1], f[2], true, save) end
            end },
        }},
    }
    -- ticked or not, nothing is saved until the server accepts the sign-in;
    -- the choice is remembered for next time
    save_box = CheckButton:new{
        text = _("Save password on this device (encrypted)"),
        checked = not (G_reader_settings and G_reader_settings:isFalse("bookorbit_tweaks_save_password")),
        parent = dlg,
        callback = function()
            if G_reader_settings then
                G_reader_settings:saveSetting("bookorbit_tweaks_save_password", save_box.checked and true or false)
            end
        end,
    }
    dlg:addWidget(save_box)
    UIManager:show(dlg)
    dlg:onShowKeyboard()
    end
    -- The first time on this device (and after Forget): what happens to the
    -- password, before it's typed.
    if G_reader_settings and not G_reader_settings:isTrue("bookorbit_tweaks_password_notice_seen") then
        UIManager:show(require("ui/widget/confirmbox"):new{
            text = SECURITY_TEXT,
            ok_text = _("Continue"),
            cancel_text = _("Cancel"),
            ok_callback = function()
                G_reader_settings:saveSetting("bookorbit_tweaks_password_notice_seen", true)
                askPassword()
            end,
        })
        return
    end
    askPassword()
end

-- One authorised call; a session the server turned down signs in again once.
local function webCall(catalog, label, method, path, body, done, retried)
    webSignIn(catalog, function(token)
        local res, err = catalog:fetch(label, function()
            return catalog.client:requestBlocking(method, path, body, { ["Authorization"] = "Bearer " .. token })
        end)
        if err == 401 and not retried then
            web_sessions[catalog.client.server_url] = nil
            return webCall(catalog, label, method, path, body, done, true)
        end
        done(res, err)
    end)
end

local showCollections
showCollections = function(catalog, detail)
    local book_id = detail and tonumber(detail.id)
    if not book_id then return end
    local UIManager = require("ui/uimanager")
    catalog:runConnected(function()
        webCall(catalog, _("Loading your collections…"), "GET", "/collections?bookIds=" .. book_id, nil, function(list, err)
            if type(list) ~= "table" then
                if err ~= "cancelled" then failure(T(_("Couldn't load your BookOrbit collections:\n%1"), tostring(err))) end
                return
            end
            local ButtonDialog = require("ui/widget/buttondialog")
            local dlg
            local buttons = {}
            for _i, c in ipairs(list) do
                if type(c) == "table" and c.id and c.isOwner ~= false then
                    local inside = (tonumber(c.memberCount) or 0) > 0
                    buttons[#buttons + 1] = {{
                        text = (inside and "\u{2713} " or "") .. tostring(c.name or c.id),
                        callback = function()
                            UIManager:close(dlg)
                            webCall(catalog, inside and _("Removing…") or _("Adding…"),
                                inside and "DELETE" or "POST", "/collections/" .. c.id .. "/books",
                                { bookIds = { book_id } }, function(res, e)
                                    if res == nil and e ~= nil then
                                        if e ~= "cancelled" then failure(T(_("Couldn't change the collection:\n%1"), tostring(e))) end
                                        return
                                    end
                                    if catalog.markStackDirty then pcall(catalog.markStackDirty, catalog) end
                                    local msg = T(inside and _("Removed from %1") or _("Added to %1"), tostring(c.name))
                                    note(msg, inside and _("Removed") or _("Added"))
                                end)
                        end,
                    }}
                end
            end
            buttons[#buttons + 1] = {{
                text = _("New Collection…"),
                callback = function()
                    UIManager:close(dlg)
                    local InputDialog = require("ui/widget/inputdialog")
                    local input
                    input = InputDialog:new{
                        title = _("New collection"),
                        buttons = {{
                            { text = _("Cancel"), id = "close", callback = function() UIManager:close(input) end },
                            { text = _("Create"), is_enter_default = true, callback = function()
                                local name = (input:getInputText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
                                UIManager:close(input)
                                if name == "" then return end
                                webCall(catalog, _("Creating…"), "POST", "/collections", { name = name, icon = "library" }, function(made, e)
                                    if type(made) ~= "table" or not made.id then
                                        if e ~= "cancelled" then failure(T(_("Couldn't create the collection:\n%1"), tostring(e))) end
                                        return
                                    end
                                    webCall(catalog, _("Adding…"), "POST", "/collections/" .. made.id .. "/books", { bookIds = { book_id } }, function(res, e2)
                                        if res == nil and e2 ~= nil then
                                            if e2 ~= "cancelled" then failure(T(_("Made %1, but couldn't add the book:\n%2"), name, tostring(e2))) end
                                            return
                                        end
                                        note(T(_("Added to %1"), name), _("Added"))
                                    end)
                                end)
                            end },
                        }},
                    }
                    UIManager:show(input)
                    input:onShowKeyboard()
                end,
            }}
            dlg = ButtonDialog:new{
                title = T(_("Collections · %1"), tostring(detail.title or "")),
                title_align = "center",
                buttons = buttons,
            }
            UIManager:show(dlg)
        end)
    end)
end

-- The book page's ⋯ menu (BookOrbit 2.0's own page menu, not the book
-- sheet): Add To Collection under Open series / Highlights, above Refresh.
local function hookDetailMenuCollections()
    local ok, Catalog = pcall(require, "bookorbit_catalog")
    if not (ok and type(Catalog) == "table" and type(Catalog.detailMenuItems) == "function"
            and type(Catalog.detailRun) == "function") or Catalog._bookorbit_tweaks_detail_coll then
        return
    end
    Catalog._bookorbit_tweaks_detail_coll = true
    local orig_items, orig_run = Catalog.detailMenuItems, Catalog.detailRun
    Catalog.detailMenuItems = function(self, d, detail, ...)
        local items = orig_items(self, d, detail, ...)
        if cfg.collections_row ~= false and type(items) == "table" and type(detail) == "table" and tonumber(detail.id) then
            local at = #items + 1
            for i, it in ipairs(items) do
                local k = type(it) == "table" and type(it.action) == "table" and it.action.kind
                if k == "refresh" or k == "remove" then at = i break end
            end
            table.insert(items, at, { icon = "library", label = _("Add To Collection"), action = { kind = "tk-collections" } })
        end
        return items
    end
    Catalog.detailRun = function(self, action, region, hold, ...)
        if not hold and type(action) == "table" and action.kind == "tk-collections" then
            local detail = self.current_context and self.current_context.detail
            pcall(self.detailSetSheet, self, nil)
            require("ui/uimanager"):tickAfterNext(function() showCollections(self, detail) end)
            return true
        end
        return orig_run(self, action, region, hold, ...)
    end
end

-- The book sheet: our row under BookOrbit's own, and its tap.
local function hookCollectionsRow()
    hookDetailMenuCollections()
    local ok, DialogUI = pcall(require, "bookorbit_dialog_ui")
    local ok_m, MenuUI = pcall(require, "bookorbit_menu_ui")
    if not (ok and ok_m) or type(DialogUI) ~= "table" or type(MenuUI) ~= "table"
            or type(DialogUI.open) ~= "function" or type(DialogUI.sheet) ~= "function" then
        return false
    end
    if DialogUI._bookorbit_tweaks_collections then return true end
    DialogUI._bookorbit_tweaks_collections = true
    local orig_sheet = DialogUI.sheet
    DialogUI.sheet = function(page, sw, sh, build, o, ...)
        if type(page) == "table" and page.name == "bookorbit_book_peek" and type(build) == "function"
                and cfg.collections_row ~= false then
            local inner = build
            build = function(w, ...)
                local items = inner(w, ...)
                if type(items) == "table" then
                    local okr, group = pcall(function()
                        return MenuUI.group(w, { MenuUI.row(MenuUI.rowsIn(w), {
                            icon = "library", label = _("Add To Collection"),
                            sub = _("Your BookOrbit collections"), chevron = true,
                            action = { kind = "tk-collections" },
                        }) })
                    end)
                    if okr and group then items[#items + 1] = group end
                end
                return items
            end
        end
        return orig_sheet(page, sw, sh, build, o, ...)
    end
    local orig_open = DialogUI.open
    DialogUI.open = function(opts, ...)
        if type(opts) == "table" and opts.name == "bookorbit_book_peek" and type(opts.on_action) == "function" then
            local on_action = opts.on_action
            opts.on_action = function(page, action, ...)
                if type(action) == "table" and action.kind == "tk-collections" then
                    local catalog, detail = page.catalog, page.peek and page.peek.detail
                    page:close()
                    require("ui/uimanager"):tickAfterNext(function() showCollections(catalog, detail) end)
                    return true
                end
                return on_action(page, action, ...)
            end
        end
        return orig_open(opts, ...)
    end
    return true
end

-- Saved password and its key: never in Patch Backup & Restore's backups.
do
    local BK = package.loaded.backup_patches or { targets = {} }
    package.loaded.backup_patches = BK
    if type(BK.addSecrets) == "function" then
        pcall(BK.addSecrets, { files = { LOGIN_FILE, KEYRING_FILE } })
    else
        -- Patch Backup & Restore not loaded yet: its secrets are a set by name
        BK.secrets = BK.secrets or { files = {}, folders = {}, keys = {} }
        BK.secrets.files = BK.secrets.files or {}
        BK.secrets.files[LOGIN_FILE] = true
        BK.secrets.files[KEYRING_FILE] = true
    end
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
hookButtonsOnly()
hookCollectionsRow()
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
            hookButtonsOnly()
            hookCollectionsRow()
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
            end,
        },
        {
            text = _("Keep BookOrbit Open Through Sleep"),
            help_text = _("Off: BookOrbit is closed on sleep and reloads the next time you open it. On: it stays open and comes straight back after wake."),
            checked_func = function() return cfg.keep_open_sleep == true end,
            callback = function()
                cfg.keep_open_sleep = not (cfg.keep_open_sleep == true)
                saveConfig()
            end,
        },
        {
            text = _("Open Book Only From Buttons"),
            help_text = _("On the dashboard, only the Resume / Download pill and the round play button open the book. A tap anywhere else on the Continue Reading tile (cover, title, progress) does nothing. Off by default."),
            checked_func = function() return cfg.buttons_only_open == true end,
            callback = function()
                cfg.buttons_only_open = not (cfg.buttons_only_open == true)
                saveConfig()
                -- the dashboard keeps its tap actions until it's rebuilt
                local ok_ui, UIManager = pcall(require, "ui/uimanager")
                if ok_ui then
                    for _i, e in ipairs(UIManager._window_stack or {}) do
                        local w = e.widget
                        if type(w) == "table" and type(w.boardItemAction) == "function"
                                and type(w.updateItems) == "function" then
                            pcall(w.updateItems, w, nil, true)
                        end
                    end
                end
            end,
        },
        {
            text = _("Add To Collection In Book Menu"),
            help_text = _("Hold a book in a list, or tap ⋯ at the top right of a book's page: Add To Collection lists your BookOrbit collections (✓ = the book is in it). Tap one to add or remove the book, or make a new collection. It signs in like the web app, with your BookOrbit password."),
            checked_func = function() return cfg.collections_row ~= false end,
            callback = function()
                cfg.collections_row = not (cfg.collections_row ~= false)
                saveConfig()
            end,
        },
        {
            text = _("Forget Saved BookOrbit Password"),
            help_text = _("The password Add To Collection saved on this device (encrypted). You'll be asked again next time."),
            enabled_func = function()
                local okl, st = pcall(loginStore)
                return okl and type(st.data) == "table" and next(st.data) ~= nil
            end,
            callback = function()
                local okl, st = pcall(loginStore)
                if okl then
                    for k in pairs(st.data) do st:delSetting(k) end
                    st:flush()
                end
                for k in pairs(web_sessions) do web_sessions[k] = nil end
                G_reader_settings:delSetting("bookorbit_tweaks_password_notice_seen")
                note(_("Saved BookOrbit password removed from this device."), _("Password forgotten"))
            end,
        },
        {
            text = _("About The Saved Password"),
            keep_menu_open = true,
            callback = function()
                require("ui/uimanager"):show(require("ui/widget/infomessage"):new{ text = SECURITY_TEXT })
            end,
            separator = true,
        },
        {
            text = _("Second Swipe Opens Tools Menu"),
            checked_func = function() return cfg.second_swipe_tools == true end,
            callback = function()
                cfg.second_swipe_tools = not (cfg.second_swipe_tools == true)
                saveConfig()
            end,
        },
        {
            text = _("Library Filter"),
            sub_item_table_func = buildLibraryMenu,
        },
        {
            text = _("Action Colours"),
            sub_item_table_func = function()
                local function colorMenu(title, key)
                    local items = {
                        {
                            text = title,
                            enabled = false,
                        },
                    }
                    local seen = {}
                    for _i, c in ipairs(PILL_COLORS) do
                        local name, hex = c[1], c[2]
                        if not seen[hex] then
                            seen[hex] = true
                            items[#items + 1] = {
                                text = name,
                                checked_func = function()
                                    return type(cfg[key]) == "string" and cfg[key]:upper() == hex
                                end,
                                callback = function()
                                    cfg[key] = hex
                                    saveConfig()
                                end,
                            }
                        end
                    end
                    return items
                end
                return {
                    {
                        text_func = function()
                            return _("Continue Reading: ") .. pillColorName(cfg.resume_pill_color or "#FFFFFF")
                        end,
                        sub_item_table_func = function()
                            return colorMenu(_("Hero pill + download circle"), "resume_pill_color")
                        end,
                    },
                    {
                        text_func = function()
                            return _("Book Detail: ") .. pillColorName(cfg.detail_pill_color or "#FFFFFF")
                        end,
                        sub_item_table_func = function()
                            return colorMenu(_("Start reading / Read again / Resume"), "detail_pill_color")
                        end,
                    },
                    {
                        text_func = function()
                            return _("Dialogs: ") .. pillColorName(cfg.dialog_pill_color or "#FFFFFF")
                        end,
                        sub_item_table_func = function()
                            return colorMenu(_("Bottom sheets / open-book dialog"), "dialog_pill_color")
                        end,
                    },
                    {
                        text = _("Pill Colour Trace (crash.log)"),
                        help_text = _("When on, every colour match and near-miss is written to crash.log so you can see why Continue Reading did or did not pick up Blue."),
                        checked_func = function() return cfg.pill_color_trace == true end,
                        callback = function()
                            cfg.pill_color_trace = not (cfg.pill_color_trace == true)
                            saveConfig()
                        end,
                    },
                }
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

-- Patch Backup & Restore (2-backup-patches.lua): our settings as a backup
-- target. Works in either patch load order.
do
    local BK = package.loaded.backup_patches or { targets = {} }
    package.loaded.backup_patches = BK
    BK.targets = BK.targets or {}
    local target = {
        id = "bookorbit_tweaks",
        text = _("BookOrbit Tweaks"),
        setting_prefix = SETTINGS_KEY,
        -- saved server logins stay out of backups; the library list is
        -- fetched again
        skip_keys = { SERVERS_KEY, LIBRARIES_CACHE_KEY },
    }
    if type(BK.register) == "function" then pcall(BK.register, target) else table.insert(BK.targets, target) end
end

logger.info(TAG, "========== v" .. VERSION .. " LOADED ==========")
