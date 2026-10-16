--[[
2-simpleui-tweaks.lua - SimpleUI Tweaks, a KOReader user patch for SimpleUI
(simpleui.koplugin)
Version 2.9.10

Colours, bold, section title styling and Night Mode "day look" for the
SimpleUI home screen, nav bar and status bar.
Settings: Tools > SimpleUI Tweaks (or Tools > Add-ons > SimpleUI Tweaks when
2-tweaks-menu.lua is installed). Install: koreader/patches/, then restart.
Also: KOReader's own menu tab icons and arrows can keep their original
colours in Night Mode (for colour icons swapped in via koreader/icons/).

Colours are picked as they look ON SCREEN; Night Mode inversion is handled.

Changelog
  2.9.10 Currently Reading: days read and time left now show for the books
         you swipe to too, not just the current one (their stats id is read
         once from the book's sidecar; SimpleUI only had it for the
         current book).
  2.9.9  Currently Reading dots are drawn shapes now: a filled black dot for
         the book showing, black outlined circles for the others (the text
         glyph outlines were too faint to see).
  2.9.8  Swipe logging follows the SimpleUI diagnostic: on while it's
         installed and logging, off otherwise (no setting to remember).
  2.9.7  Currently Reading: dots are back, in a small row below the cover
         (not on it), filled dot = the book showing. The row only appears
         when there are 2+ books to swipe through. Swipe logging is off now
         that swipes work.
  2.9.6  Swipe fixed for real: SimpleUI's home screen takes every left/right
         swipe itself and only passes it to a book module that has an
         onSwipe handler (how Cover Deck gets its swipes). Ours was named
         differently, so the home screen never passed it on. Also: the book
         you swiped to survives a full home rebuild (it only resets when a
         book is opened or the list changes), and the swipe log is capped
         at 128 KB.
  2.9.5  Fixed swipe diagnostics log path (was writing to wrong location;
         now uses DataStorage path like other diagnostics).
  2.9.4  Removed the tap gesture entirely (v2.9.2/v2.9.3 broke swipe; the
         invisible tap zone was confusing). Back to swipe-only as in the
         working v2.9.1. Swipe left/right on the Currently Reading cover
         to change books.
  2.9.3  Removed the cover dots and the 2/2 page indicator visuals per TK
         (2/2 overlapped the title; header can't be hooked safely). Fixed
         the tap-zone crash (range must be a Geom, not a plain table).
         Invisible tap zone at top-right of the module remains: tap for
         next book.
  2.9.2  Tappable page indicator ("1/4") at top-right of Currently Reading
         (tap = next book) — swipe was sometimes captured by the quote
         module instead. Swipe diagnostics now log to diagnostics.log
         ([simpleui] tag): handler fires, idx changes, refresh results.
  2.9.1  Fixed swipe getting stuck on last book: the fallback refresh now
         does a full rebuild (was repaint-only, leaving the old book visible).
  2.9.0  Currently Reading: swipe left/right to step through your most recent
         books still in progress (4 by default, 2-6; finished ones skipped),
         with dots on the cover showing where you are. Tap opens the book
         shown. Only the module is repainted, no flash. Modules > Currently
         Reading: swipe between books.
  2.8.5  Title case for all menu item texts (per TK's house convention).
  2.8.4  Reverted the 2.8.0 title/nav hook changes (they caused module
         build failures with makeAlphaTextBox on some setups); kept the
         shared notification contract v1 from 2.8.1. Title/nav styling
         fixes are parked pending a root-cause fix.
  2.8.1  Shared notification contract v1: status notes (restart prompt,
         colour/size validation) go through Network Tweaks' or ReadMastery
         notify's style when installed, else the InfoMessage default.
  2.7.0  Windows opened from the menu while it stays open (e.g. Shortcuts
         Toolbar: ReadMastery quests) keep SimpleUI home underneath, so
         closing them goes back to the menu over the home instead of the
         stock library.
  2.6.0  Close Bookshelf goes straight to SimpleUI home (when it's your
         start screen) instead of showing the stock library for a moment
         first. Nothing to set.
  2.5.0  Removed Series folders (2.4.x): they only fix SimpleUI's own library
         file browser, and the library here is Bookshelf, which groups series
         itself. Its hooks on the file browser and Cover Browser are gone.
  2.4.2  The file browser check behind the series fixes' backup never
         matched (it looked for the name "filemanager", which is the file
         list's name, not the file browser's), so the backup never ran.
  2.4.1  Series folder fixes are hooked in once per SimpleUI install. Before,
         if another patch or plugin also hooked the file browser, each time
         the file browser opened could add another copy of them.
  2.4.0  Series folders (fixes for SimpleUI's series grouping, each a toggle
         under SimpleUI Tweaks > Series folders, all on by default):
         new series group as soon as Cover Browser has scanned the books
         (no more opening and closing a book first); closing a book from a
         series returns to that book's page instead of page 1; books with
         the same or no series number keep a fixed order.
  2.3.2  Trimmed: removed settings conversions from 1.x versions and the
         one-time Bold move from 2.0.0 (both long done), shorter changelog.
  2.3.1  Colour picker no longer looks cut off at the bottom: it now asks
         for its own screen refresh over the whole dialog instead of relying
         on the menu's, which only updated the area the menu covered.
  2.3.0  Faster Quote of the Day module. Each time it picked a quote,
         SimpleUI rewrote its whole settings file to disk three times and
         wrote debug lines to crash.log. Now the quote position is kept in
         memory and saved when the Kobo sleeps or KOReader closes (as
         SimpleUI already does for everything), and those debug lines are
         skipped. Nothing changes on screen.
  2.2.0  Removed the Colour boost for e-ink setting (it only changes
         coloured text, so it made no visible difference here). Colours
         are drawn exactly as picked again. The deep "Ink" swatches in the
         colour picker stay.
  2.1.1  A module set to "SimpleUI default" text colour keeps it when it
         refreshes in place (e.g. stats after closing a book); it could pick
         up the All modules colour there. Hardening for future SimpleUI
         versions: a missing palette colour can't leave an override behind,
         and the clock hook only wraps a real function.
  2.1.0  Colour boost for e-ink (Off / Medium / Strong): text colours you
         pick are drawn deeper and more saturated so they hold up on colour
         e-ink, which washes colours out. Hue is kept; black, white and greys
         are untouched; in Night Mode colours stay bright enough to read on
         the dark background. Applies to module text (normal and Night Mode,
         all modules and per module) and section titles, not to progress
         bars or borders. The colour picker previews text colours with the
         boost, and has a new row of deep "Ink" shades made for colour
         e-ink.
  2.0.0  For SimpleUI 2.7.5. Removed what SimpleUI now does itself: module
         Bold (SimpleUI: each module's Text > Style) and nav bar Bold labels
         (SimpleUI: nav bar label Style). Your Bold choices are moved into
         SimpleUI's own settings once, so nothing changes on screen, and the
         two can no longer stack (double bold). Also removed: the reader tab
         id workaround (fixed in SimpleUI 2.7.5) and the old Shortcuts
         Toolbar fix that looked for its internals (1.10.2's covers every
         version).
  1.x    Earlier versions: see the GitHub history.
]]

local VERSION = "2.9.10"

-- Only one copy may run (e.g. an old 2-simpleui-mod.lua left next to
-- 2-simpleui-tweaks.lua): a second copy would hook everything twice.
if package.loaded["simpleui_tweaks_patch"] then
    require("logger").warn("simpleui-tweaks: another copy is already loaded, this one is skipped")
    return
end
package.loaded["simpleui_tweaks_patch"] = true

-- ---- Defaults (change in Tools > SimpleUI Tweaks) --------------------------
local DEFAULTS = {
    module_text      = "#000000",   -- module text, normal mode
    night_text       = "#000000",   -- module text in Night Mode (as shown)
    recolor_all      = true,        -- also recolour grey/dim text
    section_titles   = "none",      -- section title colour ("none" = default)
    accent           = "#000000",   -- borders, progress fill, stat icons
    track            = "#CCCCCC",   -- unfilled part of bars/rings
    accent_modules   = { reading_goals = true, reading_stats = true, currently = false },
    nav_labels_black = true,        -- nav labels show black in Night Mode
    nav_icons_original = true,      -- nav icons keep their real colours in Night Mode
    qa_icons_original = false,      -- Quick Actions icons: same, in Night Mode
    menu_icons       = {            -- KOReader menu icons: same, in Night Mode
        tab    = {},                --   tab icons, by menu id: ["tools"] = true
        arrows = false,             --   back arrow and page arrows
    },
    titles_day_night = true,        -- section titles look the same in Night Mode
    topbar_day_night = true,        -- status bar looks the same in Night Mode
    bold = {                        -- bold text (applies after restart,
        topbar  = true,             -- except the status bar: instant)
        titles  = false,            -- (module and nav bar text: SimpleUI's own
    },                              --  Text > Style since SimpleUI 2.7.5)
    title_size       = 100,         -- section title size, % (x SimpleUI's own label scale)
    titles           = {},          -- per-section overrides: [module id] = { color, bold, size }
    module_colors    = {},          -- per-module text: [module id] = { text, night }
    currently_swipe  = true,        -- Currently Reading: swipe between in-progress books
    currently_books  = 4,           --   how many (current book included), 2-6
}

local userpatch  = require("userpatch")
local Blitbuffer = require("ffi/blitbuffer")
local Screen     = require("device").screen
local logger     = require("logger")

local TAG = "simpleui-tweaks " .. VERSION .. ":"
local SETTINGS_KEY = "simpleui_mod"

-- ---- settings ----------------------------------------------------------------
local cfg = {}

-- defaults, overlaid (recursively) with saved values
local function merged(def, saved)
    local out = {}
    for k, v in pairs(def) do
        if type(v) == "table" then
            out[k] = merged(v, type(saved) == "table" and saved[k] or nil)
        elseif type(saved) == "table" and saved[k] ~= nil then
            out[k] = saved[k]
        else
            out[k] = v
        end
    end
    -- keep saved keys that have no default (e.g. per-module colours, per-section titles)
    if type(saved) == "table" then
        for k, v in pairs(saved) do
            if out[k] == nil and def[k] == nil then out[k] = v end
        end
    end
    return out
end

local function loadConfig()
    local saved = G_reader_settings and G_reader_settings:readSetting(SETTINGS_KEY) or {}
    local m = merged(DEFAULTS, saved)
    -- retired settings
    m.topbar_bold, m.show_popup, m.nav_icon_night, m.colour_boost, m.series = nil, nil, nil, nil, nil
    m.bold.modules, m.bold.nav, m.menu_icons.tabs = nil, nil, nil
    for k in pairs(cfg) do cfg[k] = nil end
    for k, v in pairs(m) do cfg[k] = v end
end
-- Written to disk straight away (only ever on a settings change): KOReader
-- otherwise only saves on a clean exit, so a crash, power-off or swapping
-- patch files over USB could lose the change.
local function saveConfig()
    if G_reader_settings then
        G_reader_settings:saveSetting(SETTINGS_KEY, cfg)
        if G_reader_settings.flush then pcall(G_reader_settings.flush, G_reader_settings) end
    end
end
loadConfig()

-- ---- colour helpers -----------------------------------------------------------
local function parseRGB(hex)
    if type(hex) ~= "string" then return nil end
    local r, g, b = hex:match("^#?(%x%x)(%x%x)(%x%x)$")
    if not r then return nil end
    return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
end

local function mkColor(r, g, b)
    if r == g and g == b then return Blitbuffer.Color8(r) end
    return Blitbuffer.ColorRGB32(r, g, b, 0xFF)
end

local function colorOf(hex, inverted)
    local r, g, b = parseRGB(hex)
    if not r then return nil end
    if inverted then r, g, b = 255 - r, 255 - g, 255 - b end
    return mkColor(r, g, b)
end

-- NB: never compare a colour with == nil (its __eq can crash); use truthiness
local function grayLevel(c)
    if not c then return 0 end  -- default text colour is black
    if type(c) ~= "cdata" and type(c) ~= "table" then return nil end
    local getter = c.getColor8
    if type(getter) ~= "function" then return nil end
    local ok, c8 = pcall(getter, c)
    local v = ok and c8 and c8.a
    if type(v) == "number" then return v end
    return nil
end

-- Inverts a colour, keeping hue (greys stay native greyscale).
local function invColor(c)
    if not c then return Blitbuffer.Color8(255) end   -- default black -> white
    local getter = (type(c) == "cdata" or type(c) == "table") and c.getColorRGB32
    if type(getter) == "function" then
        local ok, rgb = pcall(getter, c)
        if ok and rgb and rgb.r then
            return mkColor(255 - rgb.r, 255 - rgb.g, 255 - rgb.b)
        end
    end
    local v = grayLevel(c)
    if v == nil then return c end
    return Blitbuffer.Color8(255 - v)
end

-- ---- derived colours (recomputed when settings change) -------------------------
local TEXT_C, NIGHT_C
local ACC_DAY, ACC_NIGHT, TRK_DAY, TRK_NIGHT
local onConfigApplied  -- set further down (rebuilds cached accent tables)

local function applyConfig()
    TEXT_C    = colorOf(cfg.module_text)
    NIGHT_C   = colorOf(cfg.night_text, true)   -- pre-inverted for Night Mode
    ACC_DAY   = colorOf(cfg.accent)
    ACC_NIGHT = colorOf(cfg.accent, true)
    TRK_DAY   = colorOf(cfg.track)
    TRK_NIGHT = colorOf(cfg.track, true)
    if onConfigApplied then onConfigApplied() end
end
applyConfig()

local function shouldRecolor(c)
    local v = grayLevel(c)
    if v == nil then return false end
    if cfg.recolor_all then return v < 0xE0 end  -- skip white/near-white text
    return v == 0
end

-- A module's own text colour settings, if any (instances like Quick Actions
-- rows match their module id as a prefix).
local function moduleColors(id)
    if type(id) ~= "string" then return nil end
    local mc = cfg.module_colors
    if mc[id] then return mc[id] end
    for key, t in pairs(mc) do
        if id:sub(1, #key) == key then return t end
    end
    return nil
end

-- Text colour for a module, as drawn (Night Mode values pre-inverted).
-- nil = leave SimpleUI's colour.
local function colorForModule(id)
    local t = moduleColors(id)
    if Screen.night_mode then
        local n = t and t.night
        if n ~= nil and n ~= "none" then return colorOf(n, true) end
        if n == nil and NIGHT_C then return NIGHT_C end
        -- "none" (inverts with the screen) falls through to the day colour
    end
    local d = t and t.text
    if d ~= nil then return colorOf(d) end   -- "none" -> nil
    return TEXT_C
end

-- ---- scopes -----------------------------------------------------------------------
local cur_color = nil  -- colour applied to text built right now
local suspended = 0    -- > 0: don't recolour (mask internals)
local flip_kind = nil  -- "nav" | "title" | "topbar" while building those
local icon_kind = nil  -- icons only: "quick_actions" | "menu_tab" | "menu_arrow"
local in_mask   = 0    -- > 0: painting through an alpha mask

local function pack(...) return { n = select("#", ...), ... } end

local keep_own  = 0    -- > 0: inside a module/title set to SimpleUI's own colour

local function withColor(c, fn, ...)
    if not c then
        keep_own = keep_own + 1
        local res = pack(pcall(fn, ...))
        keep_own = keep_own - 1
        if not res[1] then error(res[2], 0) end
        return unpack(res, 2, res.n)
    end
    local prev = cur_color
    cur_color = c
    local res = pack(pcall(fn, ...))
    cur_color = prev
    if not res[1] then error(res[2], 0) end
    return unpack(res, 2, res.n)
end

local function tabOn(name)
    return type(name) == "string" and cfg.menu_icons.tab[name] == true
end
local function anyTabOn() return next(cfg.menu_icons.tab) ~= nil end

-- ---- section titles: which module a title belongs to, and its settings --------
local cur_title_id  = nil  -- module id of the title being built right now
local in_title      = 0    -- > 0 while a section title is being built
local last_mod_id   = nil  -- module built most recently (titles follow their module)
local label_to_id   = {}   -- title text -> module id (learned while building)
local label_count   = 0

local function titleCfg(id)
    return id and cfg.titles[id] or nil
end
local function titleBold(id)
    local t = titleCfg(id)
    if t and t.bold ~= nil then return t.bold end
    return cfg.bold.titles
end
local function titleSize(id)
    local t = titleCfg(id)
    return (t and tonumber(t.size)) or tonumber(cfg.title_size) or 100
end
local function titleColor(id)   -- nil = leave SimpleUI's colour
    local t = titleCfg(id)
    local v = t and t.color
    if v == nil then v = cfg.section_titles end
    return colorOf(v)           -- "none" -> nil
end

local function boldForKind(kind)
    if kind == "topbar" then return cfg.bold.topbar end
    if kind == "title"  then return titleBold(cur_title_id) end
    return false
end

local function activeColor()
    if suspended > 0 then return nil end
    return cur_color
end

local function flipScope(kind, fn, ...)
    local prev = flip_kind
    flip_kind = kind
    local res = pack(pcall(fn, ...))
    flip_kind = prev
    if not res[1] then error(res[2], 0) end
    return unpack(res, 2, res.n)
end

-- Is the Night Mode "look like day" flip on for this kind of element?
local function flipOn(kind)
    if kind == "nav"      then return cfg.nav_labels_black end
    if kind == "nav_icon" then return cfg.nav_icons_original end
    if kind == "quick_actions" then return cfg.qa_icons_original end
    if kind == "menu_tab"   then return anyTabOn() end
    if kind == "menu_arrow" then return cfg.menu_icons.arrows end
    if kind == "title"    then return cfg.titles_day_night end
    if kind == "topbar"   then return cfg.topbar_day_night end
    return false
end

-- ---- nav bar: night-mode painting ----------------------------------------------------
local function makeNightAwareText(w, kind)
    if w._sui_nav_night then return end
    w._sui_nav_night = true
    local orig = w.paintTo
    w.paintTo = function(self, bb, x, y)
        if flipOn(kind) and Screen.night_mode and in_mask == 0 then
            local fg = self.fgcolor
            if not self._sui_inv_fg or not rawequal(self._sui_inv_of, fg) then
                self._sui_inv_fg, self._sui_inv_of = invColor(fg), fg
            end
            self.fgcolor = self._sui_inv_fg
            local ok, err = pcall(orig, self, bb, x, y)
            self.fgcolor = fg
            if not ok then error(err, 0) end
            return
        end
        return orig(self, bb, x, y)
    end
end

local function makeNightAwareMask(w, kind)
    if type(w) ~= "table" or w._sui_nav_night or not w._fg then return end
    w._sui_nav_night = true
    local orig = w.paintTo
    w.paintTo = function(self, bb, x, y)
        if flipOn(kind) and Screen.night_mode and in_mask == 0 then
            local fg = self._fg
            self._fg = invColor(fg)
            local ok, err = pcall(orig, self, bb, x, y)
            self._fg = fg
            if not ok then error(err, 0) end
            return
        end
        return orig(self, bb, x, y)
    end
end

-- KOReader's own ImageWidget painter, captured before SimpleUI loads.
-- SimpleUI's "Don't Invert Colored Icons in Night Mode" wraps ImageWidget's
-- painter and pre-inverts coloured icons itself; drawing our inverted copy
-- through that wrapper would flip the icon twice (no visible change). When
-- that wrapper is the one we'd call, draw with KOReader's painter instead.
local ImageWidgetCls, RAW_IMAGE_PAINT
do
    local ok, IW = pcall(require, "ui/widget/imagewidget")
    if ok and type(IW) == "table" then ImageWidgetCls, RAW_IMAGE_PAINT = IW, IW.paintTo end
end

local function paintIconOriginal(self, orig, bb, x, y)
    -- Draw a private inverted COPY of the icon (alpha untouched); the
    -- screen-wide inversion flips it back to the real colours. The source
    -- buffer (possibly shared via KOReader's image cache) is never modified.
    -- Only for icons with transparency: inverting an opaque icon would turn
    -- its white background into a visible box.
    if not self.alpha then return false end
    self:getSize()
    local src = self._bb
    if not src then return false end
    if not self._sui_inv_bb or not rawequal(self._sui_inv_src, src) then
        if self._sui_inv_bb then self._sui_inv_bb:free() end
        local copy = src:copy()
        copy:invertRect(0, 0, copy:getWidth(), copy:getHeight())
        self._sui_inv_bb, self._sui_inv_src = copy, src
    end
    local painter = orig
    if ImageWidgetCls and RAW_IMAGE_PAINT and rawget(ImageWidgetCls, "_simpleui_icon_nightcolor_patched")
            and rawequal(orig, ImageWidgetCls.paintTo) then
        painter = RAW_IMAGE_PAINT
    end
    self._bb = self._sui_inv_bb
    local ok, err = pcall(painter, self, bb, x, y)
    self._bb = src
    if not ok then error(err, 0) end
    return true
end

local function makeNightAwareIcon(iw, kind)
    if iw._sui_nav_night or iw._mi_night then return end
    iw._sui_nav_night = true
    local orig = iw.paintTo
    iw.paintTo = function(self, bb, x, y)
        if Screen.night_mode and in_mask == 0 then
            local on
            if kind == "nav" then on = cfg.nav_icons_original
            elseif kind == "menu_tab" then on = tabOn(self._sui_tab_id)
            else on = flipOn(kind) end
            if on then
                local ok, done = pcall(paintIconOriginal, self, orig, bb, x, y)
                if ok and done then return end
                if not ok then logger.warn(TAG, "icon paint failed", done) end
            end
        end
        return orig(self, bb, x, y)
    end
    local orig_free = iw.free
    iw.free = function(self, ...)
        if self._sui_inv_bb then self._sui_inv_bb:free(); self._sui_inv_bb = nil end
        self._sui_inv_src = nil
        if orig_free then return orig_free(self, ...) end
    end
end

-- ---- accents (progress / borders) ------------------------------------------------------
-- Built once per settings change instead of on every paint.
local ACC_KEYS = { "gray", "gray_strong", "gray_soft", "track" }
local acc_ovr_day, acc_ovr_night = {}, {}
local accent_id_cache = {}

local function rebuildAccentTables()
    acc_ovr_day, acc_ovr_night = {}, {}
    if ACC_DAY then
        acc_ovr_day.gray, acc_ovr_day.gray_strong, acc_ovr_day.gray_soft = ACC_DAY, ACC_DAY, ACC_DAY
        acc_ovr_night.gray, acc_ovr_night.gray_strong, acc_ovr_night.gray_soft = ACC_NIGHT, ACC_NIGHT, ACC_NIGHT
    end
    if TRK_DAY then acc_ovr_day.track, acc_ovr_night.track = TRK_DAY, TRK_NIGHT end
    accent_id_cache = {}
end

-- Swap the palette, returning the previous values in `saved` (caller-owned).
-- A key the palette didn't have is saved as `false`, so restoring clears it.
local function swapAccents(C, saved)
    local ovr = Screen.night_mode and acc_ovr_night or acc_ovr_day
    for i = 1, #ACC_KEYS do
        local k = ACC_KEYS[i]
        local v = ovr[k]
        if v then
            local was = C[k]
            if was then saved[k] = was else saved[k] = false end
            C[k] = v
        end
    end
end
local function restoreAccents(C, saved)
    for i = 1, #ACC_KEYS do
        local k = ACC_KEYS[i]
        -- rawequal/truthiness only: comparing a colour with nil crashes (its __eq)
        local was = saved[k]
        if rawequal(was, false) then C[k] = nil; saved[k] = nil
        elseif was then C[k] = was; saved[k] = nil end
    end
end

onConfigApplied = rebuildAccentTables
rebuildAccentTables()

local function accentPalette()
    local Style = package.loaded["features/sui_style"]
    local C = type(Style) == "table" and Style.COLOR
    return type(C) == "table" and C or nil
end

local function withAccents(fn, ...)
    local C = accentPalette()
    if not C then return fn(...) end
    local saved = {}
    swapAccents(C, saved)
    local res = pack(pcall(fn, ...))
    restoreAccents(C, saved)
    if not res[1] then error(res[2], 0) end
    return unpack(res, 2, res.n)
end

local function isAccentModule(id)
    if type(id) ~= "string" then return false end
    local hit = accent_id_cache[id]
    if hit ~= nil then return hit end
    hit = false
    for key, on in pairs(cfg.accent_modules) do
        if on and (id == key or id:sub(1, #key) == key) then hit = true break end
    end
    accent_id_cache[id] = hit
    return hit
end

local function makeAccentPaint(w, id)
    if type(w) ~= "table" or w._sui_accent then return end
    w._sui_accent = true
    local orig = w.paintTo
    local saved, busy = {}, false   -- reused; a nested paint gets its own table
    w.paintTo = function(self, bb, x, y)
        local C = isAccentModule(id) and accentPalette()
        if not C then return orig(self, bb, x, y) end
        local tbl = busy and {} or saved
        local was_busy = busy
        busy = true
        swapAccents(C, tbl)
        local ok, err = pcall(orig, self, bb, x, y)
        restoreAccents(C, tbl)
        busy = was_busy
        if not ok then error(err, 0) end
    end
end

-- ---- KOReader widget hooks ---------------------------------------------------------------
local function hookTextInit(modname)
    local ok, W = pcall(require, modname)
    if not ok or type(W) ~= "table" then return end
    local orig_init = W.init
    -- Runs for every text widget in KOReader (reader included): keep it cheap.
    -- All work happens before init (it only touches fgcolor/paintTo), then a
    -- tail call - no table allocations per widget.
    W.init = function(self, ...)
        -- Fast path: outside SimpleUI builds this is a single check.
        if cur_color or flip_kind then
            if cur_color and suspended == 0 and shouldRecolor(self.fgcolor) then
                self.fgcolor = cur_color
            end
            -- bold also applies inside masks (the mask shape IS the glyphs)
            if flip_kind and boldForKind(flip_kind) then self.bold = true end
            if flip_kind and suspended == 0 then makeNightAwareText(self, flip_kind) end
        end
        if orig_init then return orig_init(self, ...) end
    end
end
hookTextInit("ui/widget/textwidget")
hookTextInit("ui/widget/textboxwidget")

do
    local ok, IW = pcall(require, "ui/widget/imagewidget")
    if ok and type(IW) == "table" then
        -- ImageWidget has no init of its own; Widget:new() calls one if present
        local orig_init = IW.init
        IW.init = function(self, ...)
            if flip_kind and self.is_icon then
                makeNightAwareIcon(self, flip_kind)
            elseif icon_kind and self.is_icon then
                makeNightAwareIcon(self, icon_kind)
            end
            if orig_init then return orig_init(self, ...) end
        end
    end
    local ok2, IcW = pcall(require, "ui/widget/iconwidget")
    if ok2 and type(IcW) == "table" and rawget(IcW, "init") then
        local orig_icon_init = IcW.init
        -- SimpleUI finds KOReader's icon lookup tables (ICONS_PATH,
        -- ICONS_DIRS) by inspecting IconWidget.init's upvalues, to register
        -- custom tab icons without a restart. We load first, so it inspects
        -- this wrapper: carry the same tables under the same names so its
        -- lookup still works.
        local ICONS_PATH, ICONS_DIRS
        local i = 1
        while true do
            local n, v = debug.getupvalue(orig_icon_init, i)
            if n == nil then break end
            if n == "ICONS_PATH" then ICONS_PATH = v elseif n == "ICONS_DIRS" then ICONS_DIRS = v end
            i = i + 1
        end
        IcW.init = function(self, ...)
            if ICONS_PATH == self then return ICONS_DIRS end   -- never true: keeps both as upvalues
            if flip_kind then
                makeNightAwareIcon(self, flip_kind)   -- guarded against double-wrapping
            elseif icon_kind and (icon_kind ~= "menu_arrow"
                    or (type(self.icon) == "string" and self.icon:find("^chevron"))) then
                -- menu icons are normally flattened onto white when rendered,
                -- which would leave a box once flipped: keep transparency
                if icon_kind == "menu_tab" or icon_kind == "menu_arrow" then self.alpha = true end
                makeNightAwareIcon(self, icon_kind)
            end
            return orig_icon_init(self, ...)
        end
    end
end

-- ---- SimpleUI hooks -------------------------------------------------------------------------
-- Every wrapper we install is recorded here, so a retried patch never
-- wraps the same function twice.
local ours = setmetatable({}, { __mode = "k" })
local function mine(fn) ours[fn] = true; return fn end

-- Find an upvalue by exact name. Only if no upvalue has that name (e.g. debug
-- names stripped) fall back to the first one matching `pred`.
local function findUpvalue(fn, name, pred)
    if type(fn) ~= "function" then return nil end
    local i = 1
    while true do
        local n, v = debug.getupvalue(fn, i)
        if n == nil then break end
        if n == name then return v, i end
        i = i + 1
    end
    if pred then
        i = 1
        while true do
            local n, v = debug.getupvalue(fn, i)
            if n == nil then break end
            if (n == "" or n == "?") and pred(v) then return v, i end
            i = i + 1
        end
    end
    return nil
end

local wrapped = setmetatable({}, { __mode = "k" })

-- Tabs other plugins recognise menus by, with KOReader's stock icon name.
-- Shortcuts Toolbar looks for these names to tell the library and reader
-- menus apart; SimpleUI's custom tab icons replace them.
local STOCK_TAB_ICON = {
    filemanager_settings = "appbar.filebrowser",
    navi                 = "appbar.navigation",
    typeset              = "appbar.typeset",
}

-- ---- KOReader's own menu: tab icons and arrows ------------------------------------
local seen_tabs = {}   -- tab icon names seen this session, in order
-- The menu is created each time it opens, so a toggle applies on the next
-- open. Icons are only touched while their toggle is on.
do
    local ok, TouchMenu = pcall(require, "ui/widget/touchmenu")
    if ok and type(TouchMenu) == "table" and type(TouchMenu.init) == "function"
            and not TouchMenu._sui_mod_hooked then
        TouchMenu._sui_mod_hooked = true
        -- the tab bar class is private to touchmenu.lua
        local TouchMenuBar = findUpvalue(TouchMenu.init, "TouchMenuBar")
        local function scoped(kind, on, orig, ...)
            local prev = icon_kind
            icon_kind = on and kind or nil
            local res = pack(pcall(orig, ...))
            icon_kind = prev
            if not res[1] then error(res[2], 0) end
            return unpack(res, 2, res.n)
        end
        local orig_menu_init = TouchMenu.init
        TouchMenu.init = function(self, ...)
            return scoped("menu_arrow", cfg.menu_icons.arrows, orig_menu_init, self, ...)
        end
        if type(TouchMenuBar) == "table" and type(TouchMenuBar.init) == "function" then
            local orig_bar_init = TouchMenuBar.init
            TouchMenuBar.init = function(self, ...)
                local res = pack(scoped("menu_tab", anyTabOn(), orig_bar_init, self, ...))
                -- Tabs are matched by menu id (it never changes), not icon
                -- name: SimpleUI's System Icons give custom tab icons their
                -- own names, and two tabs can share one stock icon.
                local tabs = type(self.menu) == "table" and self.menu.tab_item_table
                for k, ib in ipairs(self.icon_widgets or {}) do
                    local tab = type(tabs) == "table" and tabs[k]
                    local id = type(tab) == "table" and tab.id
                    if type(id) == "string" then
                        if type(ib) == "table" and type(ib.image) == "table" then ib.image._sui_tab_id = id end
                        -- tabs that aren't KOReader's own (a plugin's tab)
                        -- show up in the settings list once seen
                        if not seen_tabs[id] then
                            seen_tabs[id] = true
                            seen_tabs[#seen_tabs + 1] = id
                        end
                        -- The icons are drawn now: give these tabs their stock
                        -- name back so other plugins still recognise the menu.
                        -- SimpleUI sets the custom name again before the menu
                        -- is next drawn.
                        local stock = STOCK_TAB_ICON[id]
                        if stock and tab.icon ~= stock then tab.icon = stock end
                    end
                end
                return unpack(res, 1, res.n)
            end
        end
    end
end

local function wrapDescriptor(m, fallback_id)
    if type(m) ~= "table" or wrapped[m] or type(m.build) ~= "function" then return end
    wrapped[m] = true
    local orig = m.build
    m.build = function(...)
        local id = (type(m.id) == "string" and m.id) or fallback_id
        last_mod_id = id
        if label_count > 200 then label_to_id, label_count = {}, 0 end   -- stays small
        if type(m.label) == "string" and not label_to_id[m.label] then
            label_to_id[m.label] = id; label_count = label_count + 1
        end
        if type(m.label_func) == "function" then
            local okl, lbl = pcall(m.label_func, select(2, ...))
            if okl and type(lbl) == "string" and not label_to_id[lbl] then
                label_to_id[lbl] = id; label_count = label_count + 1
            end
        end
        local accent = isAccentModule(id)
        local ok, w
        -- Quick Actions icons get the Night Mode switch (checked when drawn)
        local prev_icon_kind = icon_kind
        if type(id) == "string" and id:sub(1, 13) == "quick_actions" then icon_kind = "quick_actions" end
        if accent then
            ok, w = pcall(withAccents, withColor, colorForModule(id), orig, ...)
        else
            ok, w = pcall(withColor, colorForModule(id), orig, ...)
        end
        icon_kind = prev_icon_kind
        if ok then
            -- nil is a legitimate result (e.g. no book / no data yet)
            if w ~= nil and accent then pcall(makeAccentPaint, w, id) end
            return w
        end
        -- Error: build once more without recolouring so the module doesn't
        -- disappear. (Runs build() a second time, but only on this error path.)
        logger.warn(TAG, "build failed for", id, w)
        return orig(...)
    end

    -- In-place refreshes (e.g. stats after returning from the reader) rebuild
    -- parts of the module outside build(): give them the same colours.
    for _i, fname in ipairs({ "updateStats", "updateCovers" }) do
        local orig_upd = m[fname]
        if type(orig_upd) == "function" then
            m[fname] = function(...)
                local id = (type(m.id) == "string" and m.id) or fallback_id
                local res
                if isAccentModule(id) then
                    res = pack(pcall(withAccents, withColor, colorForModule(id), orig_upd, ...))
                else
                    res = pack(pcall(withColor, colorForModule(id), orig_upd, ...))
                end
                if res[1] then return unpack(res, 2, res.n) end
                logger.warn(TAG, fname, "failed for", id, res[2])
                return orig_upd(...)
            end
        end
    end
    return orig
end

-- Quote module: picking a quote saves its place in the shuffled deck as three
-- settings, and each save rewrites SimpleUI's whole settings file to disk;
-- it also writes debug lines to crash.log on every build. While it builds,
-- deck saves stay in memory (SimpleUI writes everything to disk on sleep and
-- exit) and those debug lines are skipped. Real warnings still get through.
local QUOTE_DEBUG = { "^simpleui quote: ", "^simpleui: quote: build source=", "^simpleui: quote: showing highlight" }
local function isQuoteDebug(msg)
    if type(msg) ~= "string" then return false end
    for i = 1, #QUOTE_DEBUG do
        if msg:find(QUOTE_DEBUG[i]) then return true end
    end
    return false
end
local function quietQuoteBuild(M)
    if type(M.build) ~= "function" or M._sui_tweaks_quiet then return end
    local Store = package.loaded["infra/sui_store"]
    if type(Store) ~= "table" or type(Store.saveSetting) ~= "function"
            or type(Store.setNoFlush) ~= "function" then return end
    M._sui_tweaks_quiet = true
    local orig_build = M.build
    M.build = function(...)
        local orig_save, orig_warn = Store.saveSetting, logger.warn
        Store.saveSetting = function(self, key, value, ...)
            if type(key) == "string" and key:find("^simpleui_quote_.*deck_") then
                return Store.setNoFlush(self, key, value)
            end
            return orig_save(self, key, value, ...)
        end
        logger.warn = function(msg, ...)
            if isQuoteDebug(msg) then return end
            return orig_warn(msg, ...)
        end
        local res = pack(pcall(orig_build, ...))
        Store.saveSetting, logger.warn = orig_save, orig_warn
        if not res[1] then error(res[2], 0) end
        return unpack(res, 2, res.n)
    end
end

-- ---- Currently Reading: swipe between books --------------------------------
-- Swipe left/right on the module to step through the most recent books still
-- in progress (from KOReader's reading history, finished ones skipped). Dots on
-- the cover show where you are. Only this module is repainted (SimpleUI's own
-- single-slot refresh, the one Cover Deck swipes use). A new home build (e.g.
-- after closing a book) starts again from the current book.
local swipe_state = {}   -- [screen pfx] = { ctx, top, idx, fps, n, dots = {} }
local SCAN_MAX = 30      -- history entries looked at, at most

local function inProgressList(ctx, n)
    local fps, seen = { ctx.current_fp }, { [ctx.current_fp] = true }
    local okh, RH = pcall(require, "readhistory")
    local hist = okh and type(RH) == "table" and RH.hist
    if type(hist) ~= "table" then return fps end
    local okl, lfs = pcall(require, "libs/libkoreader-lfs")
    local okb, SH = pcall(require, "modules/module_books_shared")
    for i = 1, math.min(#hist, SCAN_MAX) do
        if #fps >= n then break end
        local fp = hist[i] and hist[i].file
        if type(fp) == "string" and not seen[fp] then
            seen[fp] = true
            if okl and lfs.attributes(fp, "mode") == "file" then
                local pct, status
                local pd = type(ctx.prefetched) == "table" and ctx.prefetched[fp]
                if type(pd) == "table" and pd.percent ~= nil then
                    pct = pd.percent
                    status = type(pd.summary) == "table" and pd.summary.status or nil
                elseif okb and type(SH) == "table" and type(SH.getBookData) == "function" then
                    local okd, bd = pcall(SH.getBookData, fp)
                    if okd and type(bd) == "table" then pct, status = bd.percent, bd.status end
                end
                if not ((pct or 0) >= 1 or status == "complete") then fps[#fps + 1] = fp end
            end
        end
    end
    return fps
end

local function findTappable(w, depth)
    if type(w) ~= "table" or depth > 8 then return nil end
    if rawget(w, "_cover_slots") and rawget(w, "ges_events") then return w end
    for i = 1, #w do
        local t = findTappable(w[i], depth + 1)
        if t then return t end
    end
end

-- Dots in a small white pill at the bottom of the cover (no extra height).
-- Swipe lines go to the SimpleUI diagnostic's log while it's on (and within
-- its logging window); without it, nothing is written.
local function diagLog(fmt, ...)
    local D = package.loaded["simpleui_diagnostics"]
    if type(D) ~= "table" or type(D.log) ~= "function" then return end
    pcall(D.log, "swipe: " .. fmt, ...)
end

-- Dots in a row just below the module, centred under the cover. The module
-- reports itself that much taller (getSize), so SimpleUI lays out and
-- refreshes the extra row with it; the module's own widgets are untouched.
local DOT     = Screen:scaleBySize(9)   -- dot size
local DOT_GAP = Screen:scaleBySize(6)   -- space between dots
local RING    = math.max(2, Screen:scaleBySize(1.5))  -- outline width of the other dots
local DOTS_GAP = Screen:scaleBySize(5)  -- space between the cover and the dots

-- Drawn shapes, not text glyphs: a filled black dot for the book showing,
-- black outlined circles for the others (thin glyph outlines were too faint).
local function paintDots(bb, st, tap, x, y, base_h)
    local n = #st.fps
    local total = n * DOT + (n - 1) * DOT_GAP
    local cx, cw
    local slot = type(tap._cover_slots) == "table" and tap._cover_slots[1]
    if type(slot) == "table" and type(slot.container) == "table" then
        local c = slot.container[slot.idx or 1]
        local r = (type(c) == "table" and c.dimen and c.dimen.x and c.dimen) or slot.container.dimen
        if r and r.x and r.w then cx, cw = r.x, r.w end
    end
    if not cx then cx, cw = x, total end   -- no cover position: left edge
    local px = cx + math.floor((cw - total) / 2)
    local py = y + base_h + DOTS_GAP
    local radius = math.floor(DOT / 2)
    for i = 1, n do
        local dx = px + (i - 1) * (DOT + DOT_GAP)
        if i == st.idx then
            bb:paintRoundedRect(dx, py, DOT, DOT, Blitbuffer.COLOR_BLACK, radius)
        else
            bb:paintRoundedRect(dx, py, DOT, DOT, Blitbuffer.COLOR_WHITE, radius)
            bb:paintBorder(dx, py, DOT, DOT, RING, Blitbuffer.COLOR_BLACK, radius)
        end
    end
end

local function addSwipe(root, st, ctx)
    local tap = findTappable(root, 0)
    if not tap then
        diagLog("addSwipe: no tappable widget found, swipe not registered")
        return
    end
    diagLog("addSwipe: registered, %d books, idx=%d", #st.fps, st.idx)
    local BD = require("ui/bidi")
    -- SimpleUI's home screen catches every left/right swipe itself
    -- (ScreenWidget:onScreenSwipe) and hands it to the first widget with an
    -- onSwipe method inside a book module it lands on, else turns the page.
    -- So the handler has to be called onSwipe; a ges_events entry never fires.
    -- v2.9.4: tap gesture REMOVED (v2.9.2/v2.9.3 broke swipe; tap zone was
    -- invisible and confusing). Swipe only, as in working v2.9.1.
    local function advance(step, via)
        local n = #st.fps
        if n < 2 then return false end
        local old = st.idx
        st.idx = (st.idx - 1 + step) % n + 1
        if st.idx < 1 then st.idx = 1 elseif st.idx > n then st.idx = n end
        diagLog("%s: idx %d -> %d (n=%d)", via, old, st.idx, n)
        local scr = ctx._screen_widget
        if type(scr) == "table" then
            local ok, done = pcall(function()
                return scr._refreshBookModSlot and scr:_refreshBookModSlot("currently")
            end)
            diagLog("%s: _refreshBookModSlot ok=%s done=%s", via, tostring(ok), tostring(done))
            if not (ok and done) and scr._refreshImmediate then
                scr:_refreshImmediate(false)
                diagLog("%s: fallback _refreshImmediate(false) called", via)
            end
        else
            diagLog("%s: no _screen_widget, no refresh", via)
        end
        return true
    end
    tap.onSwipe = function(_self, _, ges)
        local dir = ges and ges.direction
        diagLog("swipe detected, dir=%s", tostring(dir))
        if BD.mirroredUILayout() then
            if dir == "west" then dir = "east" elseif dir == "east" then dir = "west" end
        end
        local step = (dir == "west" and 1) or (dir == "east" and -1) or nil
        if not step then
            diagLog("swipe: no step for dir=%s, ignoring", tostring(dir))
            return false
        end
        return advance(step, "swipe")
    end
    -- v2.9.7: dots back, in their own row below the cover (not on it).
    if rawget(root, "_sui_dots_hooked") then return end
    rawset(root, "_sui_dots_hooked", true)
    local Geom = require("ui/geometry")
    local orig_size, orig_paint = root.getSize, root.paintTo
    local extra = DOT + DOTS_GAP * 2
    root.getSize = function(self)
        local sz = orig_size(self)
        return Geom:new{ x = sz.x, y = sz.y, w = sz.w, h = sz.h + extra }
    end
    root.paintTo = function(self, bb, x, y, ...)
        orig_paint(self, bb, x, y, ...)
        local ok, base = pcall(orig_size, self)
        if ok and base then pcall(paintDots, bb, st, tap, x, y, base.h) end
    end
end

-- Days read / time left for a swiped-to book. The module only finds a book's
-- stats id (partial md5) in SimpleUI's prefetch, which holds the current
-- book; for the others it's read once from the book's sidecar and kept.
local function bookStats(M, st, fp, ctx)
    if type(M.fetchBookStatsForCtx) ~= "function" then return false end
    st.md5 = st.md5 or {}
    local md5 = st.md5[fp]
    if md5 == nil then
        local pd = type(ctx.prefetched) == "table" and ctx.prefetched[fp]
        md5 = type(pd) == "table" and pd.partial_md5_checksum or nil
        if not md5 then
            local okd, DS = pcall(require, "docsettings")
            local ok, ds = false, nil
            if okd and type(DS) == "table" then ok, ds = pcall(DS.open, DS, fp) end
            if ok and ds then
                md5 = ds:readSetting("partial_md5_checksum")
                pcall(function() ds:close() end)
            end
        end
        st.md5[fp] = md5 or false
    end
    if not md5 then return false end
    local ok, stats = pcall(M.fetchBookStatsForCtx, md5, ctx.db_conn)
    return (ok and stats) and { fp = fp, stats = stats } or false
end

local function patchCurrentlySwipe(M)
    if type(M.build) ~= "function" or wrapped[M.build] then return end
    local orig = M.build
    M.build = function(w, ctx, ...)
        if not cfg.currently_swipe or type(ctx) ~= "table" or not ctx.current_fp then
            return orig(w, ctx, ...)
        end
        local key = ctx.pfx or ""
        local n = math.max(2, math.min(6, tonumber(cfg.currently_books) or 4))
        -- Opening any book (even the same one) updates the top history entry's
        -- time, so that's what starts the list again from the current book.
        -- Not the ctx table: a full home rebuild makes a new one, and the
        -- swipe's fallback refresh is a full rebuild.
        local okh, RH = pcall(require, "readhistory")
        local h1 = okh and type(RH) == "table" and type(RH.hist) == "table" and RH.hist[1]
        local stamp = type(h1) == "table" and tostring(h1.file) .. "@" .. tostring(h1.time) or ""
        local st = swipe_state[key]
        if not st or st.stamp ~= stamp or st.top ~= ctx.current_fp or st.n ~= n then
            local okl, fps = pcall(inProgressList, ctx, n)
            st = { stamp = stamp, top = ctx.current_fp, idx = 1, n = n, dots = {},
                   fps = okl and fps or { ctx.current_fp } }
            swipe_state[key] = st
        end
        if #st.fps < 2 then return orig(w, ctx, ...) end
        if st.idx > #st.fps then st.idx = 1 end
        local use = ctx
        if st.idx > 1 then
            -- this build only: another book; reads and writes go to the real ctx
            local fp = st.fps[st.idx]
            use = setmetatable({ current_fp = fp, currently_book_stats = bookStats(M, st, fp, ctx) },
                               { __index = ctx, __newindex = ctx })
        end
        local widget = orig(w, use, ...)
        if widget ~= nil then
            local ok, err = pcall(addSwipe, widget, st, ctx)
            if not ok then logger.warn(TAG, "currently swipe:", err) end
        end
        return widget
    end
    wrapped[M.build] = true
end

local function patchModule(name, M)
    if type(M) ~= "table" then return false end
    local file_id = name:match("module_(.+)$")
    local orig = wrapDescriptor(M, file_id)
    if type(M.sub_modules) == "table" then
        for _i, sm in ipairs(M.sub_modules) do wrapDescriptor(sm, file_id) end
    end
    if type(M.makeInstance) == "function" and not wrapped[M.makeInstance] then
        local orig_mk = M.makeInstance
        M.makeInstance = function(...)
            local inst = orig_mk(...)
            wrapDescriptor(inst, file_id)
            return inst
        end
        wrapped[M.makeInstance] = true
    end
    if file_id == "quote" then quietQuoteBuild(M) end
    if file_id == "currently" then patchCurrentlySwipe(M) end
    -- the clock's minute tick calls its local build() directly
    if file_id == "clock" and orig then
        local lb, idx = findUpvalue(orig, "build", function(v) return type(v) == "function" end)
        if type(lb) == "function" then
            debug.setupvalue(orig, idx, function(...)
                return withColor(colorForModule("clock"), lb, ...)
            end)
        end
    end
end

local function patchCore(UI)
    if type(UI) ~= "table" then return end

    local function wrapMaskMaker(fname)
        local orig = UI[fname]
        if ours[orig] then return true end
        if type(orig) ~= "function" then return false end
        UI[fname] = mine(function(opts)
            local c = activeColor()
            if c and type(opts) == "table" and opts.fgcolor and shouldRecolor(opts.fgcolor) then
                local o = {}
                for k, v in pairs(opts) do o[k] = v end
                o.fgcolor = c
                opts = o
            end
            suspended = suspended + 1   -- inner text must stay black (it's the mask)
            local ok, res = pcall(orig, opts)
            suspended = suspended - 1
            if not ok then error(res, 0) end
            if flip_kind and type(res) == "table" then
                if res._fg then makeNightAwareMask(res, flip_kind)
                elseif res.fgcolor then makeNightAwareText(res, flip_kind) end
            end
            return res
        end)
        return true
    end
    local core_ok = wrapMaskMaker("makeColoredText")
    wrapMaskMaker("makeAlphaTextBox")

    -- Framed nav bar style draws SVG icons through an alpha mask (one colour).
    local orig_amw = UI.makeAlphaMaskWidget
    if type(orig_amw) == "function" and not ours[orig_amw] then
        UI.makeAlphaMaskWidget = mine(function(inner, fgcolor, ...)
            local res = orig_amw(inner, fgcolor, ...)
            if flip_kind and suspended == 0 and type(inner) == "table" and inner.is_icon then
                makeNightAwareMask(res, flip_kind == "nav" and "nav_icon" or flip_kind)
            end
            return res
        end)
    end

    local orig_upd = UI.updateColoredText
    if type(orig_upd) == "function" and not ours[orig_upd] then
        UI.updateColoredText = mine(function(wgt, txt, fg)
            if cfg.recolor_all and fg and shouldRecolor(fg) then
                if cur_color then fg = cur_color
                elseif keep_own == 0 then fg = colorForModule(nil) or fg end
                -- else: this module/title uses SimpleUI's own colour, leave it
            end
            return orig_upd(wgt, txt, fg)
        end)
    end

    local orig_pwam = UI.paintWithAlphaMask
    if type(orig_pwam) == "function" and not ours[orig_pwam] then
        UI.paintWithAlphaMask = mine(function(...)
            in_mask = in_mask + 1
            local res = pack(pcall(orig_pwam, ...))
            in_mask = in_mask - 1
            if not res[1] then error(res[2], 0) end
            return unpack(res, 2, res.n)   -- keep the original return values
        end)
    end
    return core_ok
end

local function patchEngine(E)
    local done = false
    local function tryFn(fn)
        local orig_label, idx = findUpvalue(fn, "sectionLabel")
        if type(orig_label) == "function" then
            if ours[orig_label] then return true end
            debug.setupvalue(fn, idx, mine(function(text, w, right_text, page_nav, lf, ...)
                local id = (type(page_nav) == "table" and page_nav.mod_id)
                        or (type(text) == "string" and label_to_id[text])
                        or last_mod_id
                local prev = cur_title_id
                cur_title_id = id
                in_title = in_title + 1
                local res = pack(pcall(withColor, titleColor(id), flipScope, "title",
                                       orig_label, text, w, right_text, page_nav, lf, ...))
                in_title = in_title - 1
                cur_title_id = prev
                if not res[1] then error(res[2], 0) end
                return unpack(res, 2, res.n)
            end))
            return true
        end
    end
    for _i, v in pairs(E or {}) do
        if done then break end
        if type(v) == "function" then
            if tryFn(v) then done = true break end
            local i = 1
            while not done do
                local n, uv = debug.getupvalue(v, i)
                if n == nil then break end
                if type(uv) == "table" then
                    for _i, m in pairs(uv) do
                        if type(m) == "function" and tryFn(m) then done = true break end
                    end
                end
                i = i + 1
            end
        end
    end
    return done
end

local function patchTopbar(T)
    if type(T) ~= "table" or type(T.buildTopbarWidget) ~= "function" then
        return
    end
    local orig = T.buildTopbarWidget
    if not ours[orig] then
        T.buildTopbarWidget = mine(function(...) return flipScope("topbar", orig, ...) end)
    end
    return true
end

-- ---- nav bar "day look" for backgrounds/borders (fixes the Framed style) ------
-- In Night Mode the bar's own fills, borders and indicator would stay
-- inverted while its labels/icons get the day look, so e.g. black icons end
-- up on a black frame. Flip those too, at paint time.
local function cachedInv(self, slot, c)
    local src_slot = slot .. "_of"
    if not self[slot] or not rawequal(self[src_slot], c) then
        self[slot], self[src_slot] = invColor(c), c
    end
    return self[slot]
end

local function makeNightAwareFill(node)
    if node._sui_fill_night then return end
    node._sui_fill_night = true
    local orig = node.paintTo
    node.paintTo = function(self, bb, x, y)
        if cfg.nav_labels_black and Screen.night_mode and in_mask == 0 then
            local bg, col, bc = rawget(self, "background"), self.color, rawget(self, "border_color")
            if bg  then self.background   = cachedInv(self, "_sui_inv_bg", bg) end
            if col then self.color        = cachedInv(self, "_sui_inv_col", col) end
            if bc  then self.border_color = cachedInv(self, "_sui_inv_bc", bc) end
            local ok, err = pcall(orig, self, bb, x, y)
            if bg then self.background = bg end
            if col then self.color = col end
            if bc then self.border_color = bc end
            if not ok then error(err, 0) end
            return
        end
        return orig(self, bb, x, y)
    end
end

local function walkNav(node, depth, seen)
    if type(node) ~= "table" or depth > 14 or seen[node] then return end
    seen[node] = true
    if not rawget(node, "_sui_nav_night") and not rawget(node, "_fg")
       and type(node.paintTo) == "function"
       and (rawget(node, "background") or rawget(node, "border_color")
            or (tonumber(rawget(node, "bordersize")) or 0) > 0) then
        makeNightAwareFill(node)
    end
    for i = 1, #node do walkNav(node[i], depth + 1, seen) end
end

-- Backdrops/scrims read the palette at paint time: swap it for the bar.
local NAV_PALETTE_KEYS = { "surface", "surface_flat", "gray" }
local function makeNavPalettePaint(w)
    if type(w) ~= "table" or w._sui_nav_palette then return end
    w._sui_nav_palette = true
    local orig = w.paintTo
    local saved, inv_cache = {}, {}
    w.paintTo = function(self, bb, x, y)
        local C = accentPalette()
        if not (C and cfg.nav_labels_black and Screen.night_mode and in_mask == 0) then
            return orig(self, bb, x, y)
        end
        for i = 1, #NAV_PALETTE_KEYS do
            local k = NAV_PALETTE_KEYS[i]
            local v = C[k]
            if v then
                if not inv_cache[k] or not rawequal(inv_cache[k .. "_of"], v) then
                    inv_cache[k], inv_cache[k .. "_of"] = invColor(v), v
                end
                saved[k] = v
                C[k] = inv_cache[k]
            end
        end
        local ok, err = pcall(orig, self, bb, x, y)
        for i = 1, #NAV_PALETTE_KEYS do
            local k = NAV_PALETTE_KEYS[i]
            if saved[k] then C[k] = saved[k]; saved[k] = nil end   -- truthiness only
        end
        if not ok then error(err, 0) end
    end
end

local function dayLookNav(w, whole_bar)
    walkNav(w, 0, {})
    if whole_bar then makeNavPalettePaint(w) end
end

-- Section title size: SimpleUI sizes titles from Config.getLabelScale().
-- Only scale while a section title is being built, so any other caller
-- (none today) is never affected.
local function patchConfig(Cf)
    if type(Cf) ~= "table" or type(Cf.getLabelScale) ~= "function" then
        return false
    end
    local orig = Cf.getLabelScale
    if not ours[orig] then
        Cf.getLabelScale = mine(function(...)
            local v = orig(...)
            if in_title == 0 then return v end
            local pct = titleSize(cur_title_id)
            if type(v) == "number" and pct ~= 100 then return v * pct / 100 end
            return v
        end)
    end
    return true
end

local function patchBottombar(B)
    if type(B) ~= "table" then return end
    local n = 0
    for _i, fname in ipairs({ "buildBarWidget", "buildBarWidgetWithArrows",
                             "buildBarWidgetWithKeyFocus", "buildTabCell",
                             "buildNavpagerArrowCell" }) do
        local orig = B[fname]
        if ours[orig] then
            n = n + 1
        elseif type(orig) == "function" then
            local whole_bar = fname:find("^buildBarWidget") ~= nil
            B[fname] = mine(function(...)
                local outermost = flip_kind == nil
                local res = pack(flipScope("nav", orig, ...))
                -- post-process once, on the outermost call (whole bar, or a
                -- single cell rebuilt on its own e.g. after a page change)
                if outermost and type(res[1]) == "table" then
                    pcall(dayLookNav, res[1], whole_bar)
                end
                return unpack(res, 1, res.n)
            end)
            n = n + 1
        end
    end
    return n > 0
end

-- ---- install on load ------------------------------------------------------------------
local handled = {}
local attempts = {}
local MAX_ATTEMPTS = 3

local patchBookshelfPark   -- Bookshelf: Close Bookshelf -> SimpleUI home (defined below)

local function patcherFor(name)
    if name == "lib/bookshelf_reader_park" then return patchBookshelfPark end
    if name == "infra/sui_core" then return patchCore end
    if name == "engines/sui_screen_engine" then return patchEngine end
    if name == "screens/sui_bottombar" then return patchBottombar end
    if name == "screens/sui_topbar" then return patchTopbar end
    if name == "infra/sui_config" then return patchConfig end
    if name:find("^modules/module_") then
        return function(mod) patchModule(name, mod); return true end
    end
end

-- Marks a module handled only once its patch succeeds; failures are retried
-- on later loads, up to MAX_ATTEMPTS (patches are idempotent, see `ours`).
local function handle(name, mod)
    if type(name) ~= "string" or handled[name] or mod == nil then return end
    local patcher = patcherFor(name)
    if not patcher then handled[name] = true return end
    attempts[name] = (attempts[name] or 0) + 1
    local ok, success = pcall(patcher, mod)
    if not ok then logger.warn(TAG, "patch failed for", name, success) end
    if (ok and success) or attempts[name] >= MAX_ATTEMPTS then
        handled[name] = true
    end
end

for name, mod in pairs(package.loaded) do handle(name, mod) end

local orig_require = require
_G.require = function(name, ...)
    local mod = orig_require(name, ...)
    if not handled[name] then handle(name, mod) end
    return mod
end

-- ---- Tools > SimpleUI Tweaks menu ---------------------------------------------------------
local _ = orig_require("gettext")

local PRESETS = {
    { "Black",      "#000000" },
    { "Dark grey",  "#555555" },
    { "Grey",       "#888888" },
    { "Light grey", "#CCCCCC" },
    { "White",      "#FFFFFF" },
}

local function isPreset(v)
    for _i, p in ipairs(PRESETS) do if p[2] == v then return true end end
    return false
end

local sui_name = "simpleui"   -- SimpleUI's plugin name (= its folder name)

-- The running SimpleUI instance of the file browser, looked up when needed
-- (never stored, so nothing keeps it alive). Must be the instance, not the
-- class: SimpleUI keeps its status bar timer on whatever it's given, and a
-- class would start a second, never-paused minute timer.
local function suiInstance()
    local FM = package.loaded["apps/filemanager/filemanager"]
    local inst = type(FM) == "table" and FM.instance
    local p = type(inst) == "table" and inst[sui_name]
    if type(p) == "table" and p.ui ~= nil then return p end
end

-- ---- Bookshelf: Close Bookshelf goes straight to SimpleUI home ----------------------
-- With SimpleUI home as the start screen, "Close Bookshelf" showed the stock
-- library for a moment: SimpleUI only brings its home back on the next tick,
-- and KOReader's menu redraws the screen in between (it repaints right after
-- a menu item's action). Here the home is shown in the same step the shelf
-- closes, so that redraw already shows it. Only for a user's Close Bookshelf
-- with no book held behind the shelf (Bookshelf asks its reader-park module
-- first, every time); everything else Bookshelf closes for is left alone.
local bs_close_home = false

patchBookshelfPark = function(Park)
    if type(Park) ~= "table" or type(Park.closeShelfToFileManager) ~= "function" then return false end
    local orig = Park.closeShelfToFileManager
    if ours[orig] then return true end
    Park.closeShelfToFileManager = mine(function(...)
        local res = pack(orig(...))
        if not res[1] then
            -- no book held: the caller now closes the shelf itself
            bs_close_home = true
            local UIManager = orig_require("ui/uimanager")
            UIManager:nextTick(function() bs_close_home = false end)
        end
        return unpack(res, 1, res.n)
    end)
    return true
end

local function showSimpleUIHome()
    if not (G_reader_settings and G_reader_settings:readSetting("start_with") == "homescreen_simpleui") then return end
    local UIManager = orig_require("ui/uimanager")
    if UIManager._exit_code ~= nil or UIManager._simpleui_exiting then return end
    local RUI = package.loaded["apps/reader/readerui"]
    if type(RUI) == "table" and RUI.instance then return end
    local HS = package.loaded["screens/sui_homescreen"]
    if type(HS) ~= "table" or HS._instance then return end
    local FM = package.loaded["apps/filemanager/filemanager"]
    local fm = type(FM) == "table" and FM.instance
    local plugin = type(fm) == "table" and (fm._simpleui_plugin or fm[sui_name])
    if type(plugin) ~= "table" or type(plugin._navigate) ~= "function" then return end
    plugin:_navigate("homescreen", plugin.ui or fm, nil, false)
end

do
    local UIManager = orig_require("ui/uimanager")
    local orig_close = UIManager.close
    if type(orig_close) == "function" and not ours[orig_close] then
        UIManager.close = mine(function(self, w, ...)
            if not (bs_close_home and type(w) == "table" and w.name == "bookshelf") then
                return orig_close(self, w, ...)
            end
            bs_close_home = false
            local res = pack(orig_close(self, w, ...))
            local ok, err = pcall(showSimpleUIHome)
            if not ok then logger.warn(TAG, "Bookshelf close -> home failed:", err) end
            return unpack(res, 1, res.n)
        end)
    end
end

-- ---- Keep SimpleUI home under windows opened from the menu ---------------------------
-- SimpleUI closes its home whenever a full-screen window opens, and brings it
-- back when that window closes, unless a dialog is still open. KOReader's
-- menu counts as one, so with the menu left open (e.g. Shortcuts Toolbar
-- items), closing the window showed the stock library behind the menu until
-- the menu closed too. When a full-screen window opens on top of the menu
-- while the home is under that menu, the home is kept (SimpleUI's own
-- _sui_keep_homescreen flag), so closing the window goes back to menu + home.
local function isTouchMenuContainer(w)
    local tm = type(w) == "table" and w[1]
    return type(tm) == "table" and type(tm.tab_item_table) == "table"
end

local function homeUnderOpenMenu()
    local UIManager = orig_require("ui/uimanager")
    local stack = UIManager._window_stack
    if type(stack) ~= "table" then return false end
    local hs_at
    for i = 1, #stack do
        local w = stack[i] and stack[i].widget
        if type(w) == "table" then
            if w.name == "homescreen" and not w._parked then hs_at = i
            elseif hs_at and isTouchMenuContainer(w) then return true end
        end
    end
    return false
end

do
    local UIManager = orig_require("ui/uimanager")
    local orig_show = UIManager.show
    if type(orig_show) == "function" and not ours[orig_show] then
        UIManager.show = mine(function(self, w, ...)
            if type(w) == "table" and w.covers_fullscreen and w.name ~= "homescreen"
                    and w.name ~= "ReaderUI" and not w._sui_keep_homescreen then
                local ok, yes = pcall(homeUnderOpenMenu)
                if ok and yes then w._sui_keep_homescreen = true end
            end
            return orig_show(self, w, ...)
        end)
    end
end

local function refreshTopbarNow()
    local T = package.loaded["screens/sui_topbar"]
    local p = suiInstance()
    if p and type(T) == "table" and type(T.refresh) == "function" then
        pcall(T.refresh, p)
    end
    -- no instance found: the change shows on SimpleUI's next minute tick
end

-- Shared notification contract v1: user-facing status notes go through the
-- installed notifier with the best style, in priority order: Network Tweaks,
-- ReadMastery notify, then our own InfoMessage default. Checks run at call
-- time, so patch load order doesn't matter. Never over the sleep screen.
local function shared_note(banner_text, minimal_text, timeout)
    local Device = orig_require("device")
    if Device.screen_saver_mode then return true end
    local NetworkMgr = orig_require("ui/network/manager")
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

local function askRestart()
    local UIManager = orig_require("ui/uimanager")
    if UIManager.askForRestart then
        UIManager:askForRestart(_("Restart KOReader to apply this change to the home screen."))
    elseif not shared_note(_("Restart KOReader to apply this change.")) then
        UIManager:show(orig_require("ui/widget/infomessage"):new{
            text = _("Restart KOReader to apply this change."),
        })
    end
end

local function repaintNow()
    local UIManager = orig_require("ui/uimanager")
    UIManager:setDirty("all", "ui")
end

local function set(key, value, needs_restart)
    cfg[key] = value
    saveConfig()
    applyConfig()
    if needs_restart then askRestart() else repaintNow() end
end

-- Settings that change what the home screen builds: rebuild it now.
local function setHome(key, value)
    cfg[key] = value
    saveConfig()
    for k in pairs(swipe_state) do swipe_state[k] = nil end
    local UIManager = orig_require("ui/uimanager")
    for i = #(UIManager._window_stack or {}), 1, -1 do
        local w = UIManager._window_stack[i].widget
        if type(w) == "table" and w.name == "homescreen" and type(w._refreshImmediate) == "function" then
            pcall(w._refreshImmediate, w, false)
            return
        end
    end
end

local function customColorDialog(current, on_save)
    local UIManager = orig_require("ui/uimanager")
    local InputDialog = orig_require("ui/widget/inputdialog")
    local dlg
    dlg = InputDialog:new{
        title = _("Colour (hex, e.g. #336699)"),
        input = (type(current) == "string" and parseRGB(current) and current) or "#",
        buttons = {{
            { text = _("Cancel"), id = "close",
              callback = function() UIManager:close(dlg) end },
            { text = _("Save"), is_enter_default = true,
              callback = function()
                  local v = dlg:getInputText():gsub("%s", "")
                  if v:sub(1, 1) ~= "#" then v = "#" .. v end
                  if not parseRGB(v) then
                      if not shared_note(_("Not a valid colour. Use #RRGGBB."), nil, 3) then
                          UIManager:show(orig_require("ui/widget/infomessage"):new{
                              text = _("Not a valid colour. Use #RRGGBB."), timeout = 3 })
                      end
                      return
                  end
                  UIManager:close(dlg)
                  on_save(v:upper())
              end },
        }},
    }
    UIManager:show(dlg)
    dlg:onShowKeyboard()
end

-- ---- Colour picker: named swatches, shown as they'll look on screen -------------------
local PALETTE = {
    { "Black",      "#000000" }, { "Charcoal",   "#333333" }, { "Dark grey", "#555555" }, { "Grey",   "#888888" },
    { "Silver",     "#AAAAAA" }, { "Light grey", "#CCCCCC" }, { "White",     "#FFFFFF" }, { "Navy",   "#1F3A68" },
    { "Blue",       "#2E6FD8" }, { "Sky",        "#6FB7E9" }, { "Teal",      "#1B8A8A" }, { "Green",  "#2E8B57" },
    { "Olive",      "#6B8E23" }, { "Gold",       "#D4A017" }, { "Orange",    "#E07B24" }, { "Red",    "#C62828" },
    { "Maroon",     "#7B1E2B" }, { "Pink",       "#E78FB3" }, { "Purple",    "#6A3D9A" }, { "Brown",  "#7A4E2D" },
    -- deep, fully saturated shades that hold up on colour e-ink
    { "Ink blue",   "#0040B0" }, { "Ink green",  "#00753A" }, { "Ink red",   "#B00018" }, { "Ink purple", "#5A14A0" },
    { "Ink orange", "#C25400" },
}

local function paletteName(hex)
    if type(hex) ~= "string" then return nil end
    for _i, p in ipairs(PALETTE) do
        if p[2] == hex:upper() then return p[1] end
    end
    return nil
end

-- Black or white label, whichever reads better on this swatch.
local function labelOn(hex)
    local r, g, b = parseRGB(hex)
    local lum = (0.299 * r + 0.587 * g + 0.114 * b)
    return lum < 140 and "#FFFFFF" or "#000000"
end

local function showColourPicker(current, on_pick)
    local UIManager       = orig_require("ui/uimanager")
    local InputContainer  = orig_require("ui/widget/container/inputcontainer")
    local FrameContainer  = orig_require("ui/widget/container/framecontainer")
    local CenterContainer = orig_require("ui/widget/container/centercontainer")
    local VerticalGroup   = orig_require("ui/widget/verticalgroup")
    local HorizontalGroup = orig_require("ui/widget/horizontalgroup")
    local VerticalSpan    = orig_require("ui/widget/verticalspan")
    local HorizontalSpan  = orig_require("ui/widget/horizontalspan")
    local TextWidget      = orig_require("ui/widget/textwidget")
    local ButtonTable     = orig_require("ui/widget/buttontable")
    local Font            = orig_require("ui/font")
    local Geom            = orig_require("ui/geometry")
    local GestureRange    = orig_require("ui/gesturerange")
    local Size            = orig_require("ui/size")

    -- What you pick is what you see: in Night Mode the swatch is drawn
    -- pre-inverted, so after the screen's inversion it shows the real colour.
    local function drawn(hex) return colorOf(hex, Screen.night_mode) end

    local sw, sh = Screen:getWidth(), Screen:getHeight()
    local gap = Screen:scaleBySize(6)
    local width = math.floor(math.min(sw, sh) * 0.9)
    -- 5 columns when swatches stay wide enough to read, else 4
    local cols = 5
    if (width - gap * 6) / 5 < Screen:scaleBySize(90) then cols = 4 end
    local nrows = math.ceil(#PALETTE / cols)
    local cell_w = math.floor((width - gap * (cols + 1)) / cols)
    -- Height: whatever fits. Title, buttons, padding and gaps are set aside
    -- first; the swatches share the rest (never taller than comfortable).
    local reserved = Screen:scaleBySize(40) + Screen:scaleBySize(70) + gap * (nrows + 6)
    local fit = math.floor((sh * 0.9 - reserved) / nrows)
    local cell_h = math.max(Screen:scaleBySize(28), math.min(Screen:scaleBySize(52), fit))
    local face = Font:getFace("cfont", cell_h < Screen:scaleBySize(40) and 14 or 16)
    local cur = type(current) == "string" and current:upper() or nil

    local picker
    local cells, box

    -- Builds the dialog with swatches of the given height.
    local function build(ch)
        cells = {}
        local rows = VerticalGroup:new{ align = "center" }
        local row
        for i, p in ipairs(PALETTE) do
            if (i - 1) % cols == 0 then
                row = HorizontalGroup:new{ align = "center" }
                rows[#rows + 1] = VerticalSpan:new{ width = gap }
                rows[#rows + 1] = row
            else
                row[#row + 1] = HorizontalSpan:new{ width = gap }
            end
            local selected = (cur == p[2])
            local frame = FrameContainer:new{
                background = drawn(p[2]),
                color = drawn("#000000"),
                bordersize = selected and Size.border.thick * 2 or Size.border.thin,
                padding = 0, margin = 0,
                CenterContainer:new{
                    dimen = Geom:new{ w = cell_w, h = ch },
                    TextWidget:new{
                        text = (selected and "\u{2713} " or "") .. p[1],
                        face = face,
                        fgcolor = drawn(labelOn(p[2])),
                        max_width = cell_w - gap,
                    },
                },
            }
            cells[#cells + 1] = { frame = frame, hex = p[2] }
            row[#row + 1] = frame
        end

        local buttons = ButtonTable:new{
            width = width - gap * 2,
            buttons = {{
                { text = _("Hex code…"), callback = function()
                    UIManager:close(picker)
                    customColorDialog(current, on_pick)
                end },
                { text = _("Cancel"), callback = function() UIManager:close(picker) end },
            }},
        }

        box = FrameContainer:new{
            background = Blitbuffer.COLOR_WHITE,
            bordersize = Size.border.window,
            radius = Size.radius.window,
            padding = gap,
            VerticalGroup:new{
                align = "center",
                TextWidget:new{ text = _("Pick a colour"), face = Font:getFace("tfont", 20) },
                rows,
                VerticalSpan:new{ width = gap * 2 },
                buttons,
            },
        }
    end

    -- Measure the real dialog and shrink the swatches until it fits.
    local limit = math.floor(sh * 0.94)
    for _try = 1, 6 do
        build(cell_h)
        local h = box:getSize().h
        if h <= limit or cell_h <= Screen:scaleBySize(24) then break end
        cell_h = math.max(Screen:scaleBySize(24), cell_h - math.ceil((h - limit) / nrows) - 1)
    end

    picker = InputContainer:new{
        dimen = Geom:new{ x = 0, y = 0, w = sw, h = sh },
        CenterContainer:new{ dimen = Geom:new{ w = sw, h = sh }, box },
    }
    picker.ges_events = {
        TapSelect = { GestureRange:new{ ges = "tap", range = Geom:new{ x = 0, y = 0, w = sw, h = sh } } },
    }
    function picker:onTapSelect(_arg, ges)
        for _i, c in ipairs(cells) do
            if c.frame.dimen and c.frame.dimen:contains(ges.pos) then
                UIManager:close(self)
                on_pick(c.hex)
                return true
            end
        end
        if box.dimen and not box.dimen:contains(ges.pos) then
            UIManager:close(self)   -- tap outside: cancel
        end
        return true
    end
    function picker:onCloseWidget()
        UIManager:setDirty(nil, "ui", self.dimen)
    end
    -- Ask for our own screen refresh over the whole dialog. Without it the
    -- picker relied on whatever refresh was already queued (e.g. just the
    -- menu's area), so the part below the menu could stay un-updated and
    -- look cut off. "flashui": a clean redraw so the swatch colours show true.
    UIManager:show(picker, function()
        return "flashui", box.dimen or picker.dimen
    end)
end

-- get() returns the stored value; put(v) stores it (nil = inherit).
-- inherit_label: adds a "same as ..." choice stored as nil.
local function colorMenuWith(get, put, off_label, inherit_label)
    local items = {}
    if inherit_label then
        items[#items + 1] = {
            text = inherit_label, radio = true,
            checked_func = function() return get() == nil end,
            callback = function() put(nil) end,
            separator = true,
        }
    end
    for _i, p in ipairs(PRESETS) do
        items[#items + 1] = {
            text = p[1], radio = true,
            checked_func = function() return get() == p[2] end,
            callback = function() put(p[2]) end,
        }
    end
    items[#items + 1] = {
        text_func = function()
            local v = get()
            if v ~= nil and v ~= "none" and not isPreset(v) then
                return _("More colours") .. " (" .. (paletteName(v) or tostring(v)) .. ")"
            end
            return _("More colours…")
        end,
        radio = true,
        checked_func = function()
            local v = get()
            return v ~= nil and v ~= "none" and not isPreset(v)
        end,
        keep_menu_open = true,
        callback = function(touchmenu_instance)
            showColourPicker(get(), function(v)
                put(v)
                if touchmenu_instance then touchmenu_instance:updateItems() end
            end)
        end,
    }
    items[#items + 1] = {
        text = off_label or _("SimpleUI Default"), radio = true,
        checked_func = function() return get() == "none" end,
        callback = function() put("none") end,
    }
    return items
end

local function colorMenu(key, needs_restart, off_label)
    return colorMenuWith(
        function() return cfg[key] end,
        function(v) set(key, v, needs_restart) end,
        off_label)
end

-- Size menu: presets + custom %. get()/put() as above; inherit_label optional.
local SIZE_PRESETS = { 80, 90, 100, 110, 125, 150, 175, 200 }
local function sizeMenuWith(get, put, inherit_label)
    local items = {}
    if inherit_label then
        items[#items + 1] = {
            text = inherit_label, radio = true,
            checked_func = function() return get() == nil end,
            callback = function() put(nil) end,
            separator = true,
        }
    end
    local function isSizePreset(v)
        for _i, p in ipairs(SIZE_PRESETS) do if p == v then return true end end
        return false
    end
    for _i, pct in ipairs(SIZE_PRESETS) do
        items[#items + 1] = {
            text = pct == 100 and (pct .. "% " .. _("(Default)")) or (pct .. "%"),
            radio = true,
            checked_func = function() return get() == pct end,
            callback = function() put(pct) end,
        }
    end
    items[#items + 1] = {
        text_func = function()
            local v = get()
            if v ~= nil and not isSizePreset(v) then return _("Custom") .. " (" .. v .. "%)" end
            return _("Custom…")
        end,
        radio = true,
        checked_func = function()
            local v = get()
            return v ~= nil and not isSizePreset(v)
        end,
        keep_menu_open = true,
        callback = function(touchmenu_instance)
            local UIManager = orig_require("ui/uimanager")
            local InputDialog = orig_require("ui/widget/inputdialog")
            local dlg
            dlg = InputDialog:new{
                title = _("Size in % (50 to 300)"),
                input = tostring(get() or 100),
                input_type = "number",
                buttons = {{
                    { text = _("Cancel"), id = "close",
                      callback = function() UIManager:close(dlg) end },
                    { text = _("Save"), is_enter_default = true,
                      callback = function()
                          local n = tonumber(dlg:getInputText())
                          if not n or n < 50 or n > 300 then
                              if not shared_note(_("Enter a number from 50 to 300."), nil, 3) then
                                  UIManager:show(orig_require("ui/widget/infomessage"):new{
                                      text = _("Enter a number from 50 to 300."), timeout = 3 })
                              end
                              return
                          end
                          UIManager:close(dlg)
                          put(math.floor(n + 0.5))
                          if touchmenu_instance then touchmenu_instance:updateItems() end
                      end },
                }},
            }
            UIManager:show(dlg)
            dlg:onShowKeyboard()
        end,
    }
    return items
end

-- All home screen modules, as SimpleUI names them (id = SimpleUI module id).
local ALL_MODULES = {
    { "currently",         _("Currently Reading") },
    { "quote",             _("Quote of the Day") },
    { "reading_goals",     _("Reading Goals") },
    { "reading_stats",     _("Reading Stats") },
    { "recent",            _("Recent Books") },
    { "clock",             _("Clock") },
    { "heatmap",           _("Reading Heatmap") },
    { "tbr",               _("To Be Read") },
    { "new_books",         _("New Books") },
    { "collections",       _("Collections") },
    { "coll_row",          _("Featured Collection") },
    { "coverdeck",         _("Coverdeck") },
    { "flat_library",      _("Library") },
    { "quick_actions_row", _("Quick Actions") },
    { "action_list",       _("Action List") },
}

local function toggle(tbl, key, after)
    return {
        checked_func = function() return tbl()[key] and true or false end,
        callback = function()
            local t = tbl()
            t[key] = not t[key]
            saveConfig()
            applyConfig()
            if after then after() end
        end,
    }
end

local function item(text, spec)
    spec.text = text
    return spec
end

local tabItems
-- KOReader's own tab icons, file browser and reader menus combined
local STOCK_TABS = {
    { "filemanager_settings", _("File browser settings") },
    { "navi",                 _("Navigation (reader)") },
    { "typeset",              _("Typeset (reader)") },
    { "filemanager",          _("Back to file browser (reader)") },
    { "setting",              _("Settings") },
    { "tools",                _("Tools") },
    { "search",               _("Search") },
    { "main",                 _("Main menu") },
    { "_sui_qs_panel",        _("SimpleUI Quick Settings") },
}

tabItems = function()
    local list, known = {}, {}
    for _i, t in ipairs(STOCK_TABS) do list[#list + 1] = t; known[t[1]] = true end
    for _i, name in ipairs(seen_tabs) do
        if not known[name] then list[#list + 1] = { name, name } end
    end
    local items = {}
    for _i, t in ipairs(list) do
        local name = t[1]
        items[#items + 1] = {
            text = t[2],
            checked_func = function() return tabOn(name) end,
            callback = function()
                cfg.menu_icons.tab[name] = (not tabOn(name)) or nil
                saveConfig()
            end,
        }
    end
    return items
end

local function buildMenu()
    local function boldTbl() return cfg.bold end
    local function accentMods() return cfg.accent_modules end

    -- Colours > Progress colours for
    local accent_items = {}
    for _i, id in ipairs({ "reading_goals", "reading_stats", "currently" }) do
        for _i, m in ipairs(ALL_MODULES) do
            if m[1] == id then
                accent_items[#accent_items + 1] = item(m[2], toggle(accentMods, id, askRestart))
            end
        end
    end

    -- Section titles: "All sections" defaults + one submenu per module
    local function sectionPut(id, field)
        return function(v)
            local t = cfg.titles[id] or {}
            t[field] = v
            if next(t) == nil then cfg.titles[id] = nil else cfg.titles[id] = t end
            saveConfig()
            applyConfig()
            askRestart()
        end
    end
    local function sectionGet(id, field)
        return function() local t = cfg.titles[id]; return t and t[field] end
    end

    -- Modules > Text colour: "All modules" defaults + one submenu per module
    local function modPut(id, field)
        return function(v)
            local t = cfg.module_colors[id] or {}
            t[field] = v
            if next(t) == nil then cfg.module_colors[id] = nil else cfg.module_colors[id] = t end
            saveConfig()
            applyConfig()
            askRestart()
        end
    end
    local function modGet(id, field)
        return function() local t = cfg.module_colors[id]; return t and t[field] end
    end
    local text_colour_items = {
        {
            text = _("All Modules"),
            sub_item_table = {
                { text = _("Colour"), sub_item_table = colorMenu("module_text", true) },
                { text = _("Colour In Night Mode"),
                  sub_item_table = colorMenu("night_text", true, _("Off (Inverts With The Screen)")) },
            },
            separator = true,
        },
    }
    for _i, m in ipairs(ALL_MODULES) do
        local id, name = m[1], m[2]
        text_colour_items[#text_colour_items + 1] = {
            text_func = function()
                return cfg.module_colors[id] and (name .. " •") or name   -- dot = customised
            end,
            sub_item_table = {
                { text = _("Colour"),
                  sub_item_table = colorMenuWith(modGet(id, "text"), modPut(id, "text"),
                                                 nil, _("Same As All Modules")) },
                { text = _("Colour In Night Mode"),
                  sub_item_table = colorMenuWith(modGet(id, "night"), modPut(id, "night"),
                                                 _("Off (Inverts With The Screen)"), _("Same As All Modules")) },
                { text = _("Reset This Module"),
                  callback = function()
                      cfg.module_colors[id] = nil
                      saveConfig(); applyConfig(); askRestart()
                  end },
            },
        }
    end

    local titles_items = {
        {
            text = _("All Sections"),
            sub_item_table = {
                { text = _("Colour"), sub_item_table = colorMenu("section_titles", true) },
                item(_("Bold"), toggle(boldTbl, "titles", askRestart)),
                { text_func = function() return _("Size") .. ": " .. tostring(cfg.title_size) .. "%" end,
                  sub_item_table = sizeMenuWith(
                      function() return cfg.title_size end,
                      function(v) set("title_size", v or 100, true) end) },
            },
        },
        {
            text = _("Day Look In Night Mode"),
            checked_func = function() return cfg.titles_day_night end,
            callback = function() set("titles_day_night", not cfg.titles_day_night) end,
            separator = true,
        },
    }
    for _i, m in ipairs(ALL_MODULES) do
        local id, name = m[1], m[2]
        titles_items[#titles_items + 1] = {
            text_func = function()
                return cfg.titles[id] and (name .. " •") or name   -- dot = customised
            end,
            sub_item_table = {
                { text = _("Colour"),
                  sub_item_table = colorMenuWith(sectionGet(id, "color"), sectionPut(id, "color"),
                                                 nil, _("Same As All Sections")) },
                { text = _("Bold"),
                  sub_item_table = {
                    { text = _("Same As All Sections"), radio = true,
                      checked_func = function() return sectionGet(id, "bold")() == nil end,
                      callback = function() sectionPut(id, "bold")(nil) end,
                      separator = true },
                    { text = _("Bold"), radio = true,
                      checked_func = function() return sectionGet(id, "bold")() == true end,
                      callback = function() sectionPut(id, "bold")(true) end },
                    { text = _("Not Bold"), radio = true,
                      checked_func = function() return sectionGet(id, "bold")() == false end,
                      callback = function() sectionPut(id, "bold")(false) end },
                  } },
                { text_func = function()
                      local v = sectionGet(id, "size")()
                      return _("Size") .. ": " .. (v and (v .. "%") or _("Same As All"))
                  end,
                  sub_item_table = sizeMenuWith(sectionGet(id, "size"), sectionPut(id, "size"),
                                                _("Same As All Sections")) },
                { text = _("Reset This Section"),
                  callback = function()
                      cfg.titles[id] = nil
                      saveConfig(); applyConfig(); askRestart()
                  end },
            },
        }
    end

    return {
        text = _("SimpleUI Tweaks"),
        sub_item_table = {
            {
                text = _("Modules"),
                sub_item_table = {
                    { text = _("Text Colour"),
                      sub_item_table = text_colour_items },
                    { text = _("Also Recolour Grey Text"),
                      checked_func = function() return cfg.recolor_all end,
                      callback = function() set("recolor_all", not cfg.recolor_all, true) end,
                      separator = true },
                    { text = _("Progress & Borders Colour"),
                      sub_item_table = colorMenu("accent", true) },
                    { text = _("Progress Track Colour"),
                      sub_item_table = colorMenu("track", true) },
                    { text = _("Use Progress Colours In"),
                      sub_item_table = accent_items,
                      separator = true },
                    { text = _("Quick Actions Icons Keep Original Colours In Night Mode"),
                      checked_func = function() return cfg.qa_icons_original end,
                      callback = function() set("qa_icons_original", not cfg.qa_icons_original) end,
                      separator = true },
                    { text = _("Currently Reading: Swipe Between Books"),
                      help_text = _("Swipe left or right on Currently Reading to step through your most recent books still in progress. Dots on the cover show where you are."),
                      checked_func = function() return cfg.currently_swipe end,
                      callback = function() setHome("currently_swipe", not cfg.currently_swipe) end },
                    { text_func = function()
                          return string.format(_("Books To Swipe Through: %d"), cfg.currently_books)
                      end,
                      enabled_func = function() return cfg.currently_swipe end,
                      sub_item_table_func = function()
                          local items = {}
                          for k = 2, 6 do
                              items[#items + 1] = { text = tostring(k), radio = true,
                                  checked_func = function() return cfg.currently_books == k end,
                                  callback = function() setHome("currently_books", k) end }
                          end
                          return items
                      end },
                },
            },
            {
                text = _("Section Titles"),
                sub_item_table = titles_items,
            },
            {
                text = _("Nav Bar"),
                sub_item_table = {
                    { text = _("Day Look In Night Mode"),
                      checked_func = function() return cfg.nav_labels_black end,
                      callback = function() set("nav_labels_black", not cfg.nav_labels_black) end },
                    { text = _("Icons Keep Original Colours In Night Mode"),
                      checked_func = function() return cfg.nav_icons_original end,
                      callback = function() set("nav_icons_original", not cfg.nav_icons_original) end },
                },
            },
            {
                text = _("KOReader Menu"),
                sub_item_table = {
                    { text_func = function()
                          local n = 0
                          for _k in pairs(cfg.menu_icons.tab) do n = n + 1 end
                          return _("Tab icons keep original colours in Night Mode") .. (n > 0 and (": " .. n) or "")
                      end,
                      help_text = _("For colour icons you've swapped in (same file name in koreader/icons/). Plain black icons would disappear on the dark Night Mode menu. Applies the next time the menu opens."),
                      sub_item_table_func = tabItems },
                    { text = _("Arrows Keep Original Colours In Night Mode"),
                      help_text = _("Back arrow and page arrows. Only useful with colour arrow icons swapped in. Applies the next time the menu opens."),
                      checked_func = function() return cfg.menu_icons.arrows end,
                      callback = function() cfg.menu_icons.arrows = not cfg.menu_icons.arrows; saveConfig() end },
                },
            },
            {
                text = _("Status Bar"),
                sub_item_table = {
                    item(_("Bold"), toggle(boldTbl, "topbar", refreshTopbarNow)),
                    { text = _("Day Look In Night Mode"),
                      checked_func = function() return cfg.topbar_day_night end,
                      callback = function() set("topbar_day_night", not cfg.topbar_day_night) end },
                },
                separator = true,
            },
            {
                text = _("Reset To Defaults"),
                keep_menu_open = true,
                callback = function(touchmenu_instance)
                    local UIManager = orig_require("ui/uimanager")
                    local ConfirmBox = orig_require("ui/widget/confirmbox")
                    UIManager:show(ConfirmBox:new{
                        text = _("Reset all SimpleUI Tweaks settings to defaults?"),
                        ok_text = _("Reset"),
                        ok_callback = function()
                            if G_reader_settings then G_reader_settings:delSetting(SETTINGS_KEY) end
                            loadConfig()
                            applyConfig()
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                            askRestart()
                        end,
                    })
                end,
            },
        },
    }
end

-- The top-level entry is cheap; the ~475-item submenu is only built when it's
-- opened (sub_item_table_func), not every time KOReader's main menu is built.
local function lazyMenu()
    return {
        text = _("SimpleUI Tweaks"),
        sub_item_table_func = function()
            -- a menu bug must never take KOReader down: show a stub instead
            local ok, menu = pcall(buildMenu)
            if ok and type(menu) == "table" and type(menu.sub_item_table) == "table" then
                return menu.sub_item_table
            end
            logger.warn(TAG, "menu build failed:", menu)
            return { { text = _("Couldn't Load Settings (See Crash.log)"), enabled = false } }
        end,
    }
end

local function addToOrder(order_mod)
    local ok, order = pcall(orig_require, order_mod)
    if not ok or type(order) ~= "table" or type(order.tools) ~= "table" then return end
    for _i, v in ipairs(order.tools) do if v == "simpleui_mod" then return end end
    local pos = #order.tools + 1
    for i, v in ipairs(order.tools) do
        if type(v) == "string" and v:find("^%-%-%-") then pos = i break end
    end
    table.insert(order.tools, pos, "simpleui_mod")
end

-- ---- Add-ons menu (2-tweaks-menu.lua) -------------------------------------------------------
-- With that patch installed, our settings live under Tools > Add-ons
-- (file browser only). Without it, we add our own Tools > SimpleUI Tweaks entry.
local TM = package.loaded.tweaks_mods or {}
package.loaded.tweaks_mods = TM
TM.entries = TM.entries or {}
TM.entries.simpleui_mod = {
    text  = "SimpleUI Tweaks",
    where = "filemanager",
    build = lazyMenu,
}

local function hookMenu(menu_mod, order_mod)
    local ok, Menu = pcall(orig_require, menu_mod)
    if not ok or type(Menu) ~= "table" or type(Menu.setUpdateItemTable) ~= "function" then return end
    local orig = Menu.setUpdateItemTable
    if ours[orig] then return end
    Menu.setUpdateItemTable = mine(function(self, ...)
        -- checked at menu build time, so patch load order doesn't matter;
        -- also shows our own entry when turned off in "Choose what's in Add-ons"
        local in_addons = TM.active and (type(TM.shows) ~= "function" or TM.shows("simpleui_mod"))
        if self.menu_items and not in_addons then
            addToOrder(order_mod)
            local menu = lazyMenu()
            menu.sorting_hint = "tools"   -- still lands in Tools if a custom menu order replaces the list
            self.menu_items.simpleui_mod = menu
        end
        return orig(self, ...)
    end)
end

pcall(hookMenu, "apps/filemanager/filemanagermenu", "ui/elements/filemanager_menu_order")

-- ---- Backup patch (Tools > Backup) --------------------------------------------------------
-- Adds "SimpleUI Tweaks" as a backup target when the Backup patch is installed.
-- All our settings live under one key (SETTINGS_KEY), which the prefix matches.
-- Works in either patch load order: if Backup hasn't loaded yet, we queue the
-- target in its shared table and it picks it up as one of its targets.
do
    local BK = package.loaded.backup_patches or { targets = {} }
    package.loaded.backup_patches = BK
    local target = {
        id = "simpleui_mod",
        text = _("SimpleUI Tweaks"),
        setting_prefix = SETTINGS_KEY,
    }
    if type(BK.register) == "function" then
        pcall(BK.register, target)
    else
        BK.targets = BK.targets or {}
        -- register() would normally fill this in; set it for the early case
        -- (never let a backup convenience stop this patch from loading)
        local ok, DS = pcall(require, "datastorage")
        if ok and type(DS) == "table" and DS.getDataDir then
            target.icon_dir = DS:getDataDir() .. "/icons/simpleui_mod"
        end
        table.insert(BK.targets, target)
    end
end

userpatch.registerPatchPluginFunc("simpleui", function(plugin)
    -- Remember SimpleUI's plugin name (its folder name), for suiInstance().
    if type(plugin) == "table" and type(plugin.name) == "string" then sui_name = plugin.name end
end)