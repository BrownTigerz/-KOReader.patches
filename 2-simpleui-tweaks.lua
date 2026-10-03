--[[
2-simpleui-tweaks.lua - SimpleUI Tweaks, a KOReader user patch for SimpleUI
(simpleui.koplugin)
Version 1.8.0

Colours, bold, section title styling and Night Mode "day look" for the
SimpleUI home screen, nav bar and status bar.
Settings: Tools > SimpleUI Tweaks (or Tools > Add-ons > SimpleUI Tweaks when
2-tweaks-menu.lua is installed). Install: koreader/patches/, then restart.
Also: KOReader's own menu tab icons and arrows can keep their original
colours in Night Mode (for colour icons swapped in via koreader/icons/).

Colours are picked as they look ON SCREEN; Night Mode inversion is handled.

Changelog
  1.8.0  Renamed to SimpleUI Tweaks (settings kept). Settings are saved to
         disk straight away, so they survive a crash, power-off or patch
         update. Works with SimpleUI's own "Don't Invert Colored Icons in
         Night Mode" (no double flip) and with its custom tab icons (icon
         list lookup no longer blocked). File renamed to
         2-simpleui-tweaks.lua (delete 2-simpleui-mod.lua).
  1.7.2  Menu tabs matched by menu id, so tabs with a custom icon from
         SimpleUI's System Icons work (Navigation, Back to file browser…).
         File browser settings and Back to file browser are separate.
         Fix: Shortcuts Toolbar stopped showing when those tabs had a custom
         icon (it recognised menus by icon name only).
  1.7.1  Menu tab icons chosen one by one (e.g. only Tools).
  1.7.0  Original colours in Night Mode for KOReader's menu tab icons, menu
         arrows and Quick Actions icons (each a toggle, off by default).
  1.6.0  Backup patch support. Fixed a duplicate status bar timer. Section
         title size only applied while titles are built. Hardened loading.
  1.5.0  Add-ons menu support (incl. on/off). Settings menu built only when
         opened.
  1.4.0  Lighter: no status popup, leaner hot paths. Menu grouped by area.
  1.3.0  Per-section titles: colour, bold and size (presets or custom).
  1.2.0  Bold for modules, nav bar and status bar. Section title size.
  1.1.0  Night Mode day look for section titles, status bar and the whole nav
         bar (Framed style fixed). Original-colour nav icons.
  1.0.0  Settings menu (Tools > SimpleUI Mod): module text and Night Mode
         colours, progress & border colours.
]]

local VERSION = "1.8.0"

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
        nav     = false,
        titles  = false,
        modules = {},               -- [module id] = true
    },
    title_size       = 100,         -- section title size, % (x SimpleUI's own label scale)
    titles           = {},          -- per-section overrides: [module id] = { color, bold, size }
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
    -- keep saved keys that have no default (e.g. per-module bold flags)
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
    -- the old 3-way nav icon setting became an on/off switch
    if saved.nav_icons_original == nil and saved.nav_icon_night == "off" then
        m.nav_icons_original = false
    end
    m.topbar_bold, m.show_popup, m.nav_icon_night = nil, nil, nil   -- retired settings
    -- 1.7.0 had one switch for all tab icons; 1.7.1 keyed tabs by icon name
    local by_icon = {
        ["appbar.filebrowser"] = { "filemanager_settings", "filemanager" },
        ["appbar.settings"] = { "setting" }, ["appbar.tools"] = { "tools" },
        ["appbar.search"] = { "search" }, ["appbar.menu"] = { "main" },
        ["appbar.navigation"] = { "navi" }, ["appbar.typeset"] = { "typeset" },
    }
    if m.menu_icons.tabs == true then
        for _icon, ids in pairs(by_icon) do
            for _i, id in ipairs(ids) do m.menu_icons.tab[id] = true end
        end
    end
    for icon, ids in pairs(by_icon) do
        if m.menu_icons.tab[icon] then
            m.menu_icons.tab[icon] = nil
            for _i, id in ipairs(ids) do m.menu_icons.tab[id] = true end
        end
    end
    m.menu_icons.tabs = nil
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

local function colorForModule()
    if Screen.night_mode and NIGHT_C then return NIGHT_C end
    return TEXT_C
end

-- ---- scopes -----------------------------------------------------------------------
local cur_color = nil  -- colour applied to text built right now
local cur_bold  = false -- bold applied to text built right now (modules)
local suspended = 0    -- > 0: don't recolour (mask internals)
local flip_kind = nil  -- "nav" | "title" | "topbar" while building those
local icon_kind = nil  -- icons only: "quick_actions" | "menu_tab" | "menu_arrow"
local in_mask   = 0    -- > 0: painting through an alpha mask

local function pack(...) return { n = select("#", ...), ... } end

local function withColor(c, fn, ...)
    if not c then return fn(...) end
    local prev = cur_color
    cur_color = c
    local res = pack(pcall(fn, ...))
    cur_color = prev
    if not res[1] then error(res[2], 0) end
    return unpack(res, 2, res.n)
end

local function withBold(on, fn, ...)
    if not on then return fn(...) end
    local prev = cur_bold
    cur_bold = true
    local res = pack(pcall(fn, ...))
    cur_bold = prev
    if not res[1] then error(res[2], 0) end
    return unpack(res, 2, res.n)
end

local function tabOn(name)
    return type(name) == "string" and cfg.menu_icons.tab[name] == true
end
local function anyTabOn() return next(cfg.menu_icons.tab) ~= nil end

local function boldForModule(id)
    local mods = cfg.bold.modules
    if type(id) ~= "string" then return false end
    if mods[id] then return true end
    for key, on in pairs(mods) do
        if on and id:sub(1, #key) == key then return true end
    end
    return false
end

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
    if kind == "nav"    then return cfg.bold.nav end
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
local function swapAccents(C, saved)
    local ovr = Screen.night_mode and acc_ovr_night or acc_ovr_day
    for i = 1, #ACC_KEYS do
        local k = ACC_KEYS[i]
        local v = ovr[k]
        if v then saved[k] = C[k]; C[k] = v end
    end
end
local function restoreAccents(C, saved)
    for i = 1, #ACC_KEYS do
        local k = ACC_KEYS[i]
        -- truthiness only: comparing a colour with nil crashes (its __eq)
        if saved[k] then C[k] = saved[k]; saved[k] = nil end
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
        if cur_color or cur_bold or flip_kind then
            if cur_color and suspended == 0 and shouldRecolor(self.fgcolor) then
                self.fgcolor = cur_color
            end
            -- bold also applies inside masks (the mask shape IS the glyphs)
            if cur_bold or (flip_kind and boldForKind(flip_kind)) then self.bold = true end
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
        local bold = boldForModule(id)
        -- Quick Actions icons get the Night Mode switch (checked when drawn)
        local prev_icon_kind = icon_kind
        if type(id) == "string" and id:sub(1, 13) == "quick_actions" then icon_kind = "quick_actions" end
        if accent then
            ok, w = pcall(withBold, bold, withAccents, withColor, colorForModule(id), orig, ...)
        else
            ok, w = pcall(withBold, bold, withColor, colorForModule(id), orig, ...)
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
                local bold = boldForModule(id)
                if isAccentModule(id) then
                    res = pack(pcall(withBold, bold, withAccents, withColor, colorForModule(id), orig_upd, ...))
                else
                    res = pack(pcall(withBold, bold, withColor, colorForModule(id), orig_upd, ...))
                end
                if res[1] then return unpack(res, 2, res.n) end
                logger.warn(TAG, fname, "failed for", id, res[2])
                return orig_upd(...)
            end
        end
    end
    return orig
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
    -- the clock's minute tick calls its local build() directly
    if file_id == "clock" and orig then
        local lb, idx = findUpvalue(orig, "build", function(v) return type(v) == "function" end)
        if lb then
            debug.setupvalue(orig, idx, function(...)
                return withBold(boldForModule("clock"), withColor, colorForModule("clock"), lb, ...)
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
                fg = colorForModule(nil) or fg
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

local function patcherFor(name)
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

local function refreshTopbarNow()
    local T = package.loaded["screens/sui_topbar"]
    local p = suiInstance()
    if p and type(T) == "table" and type(T.refresh) == "function" then
        pcall(T.refresh, p)
    end
    -- no instance found: the change shows on SimpleUI's next minute tick
end

local function askRestart()
    local UIManager = orig_require("ui/uimanager")
    if UIManager.askForRestart then
        UIManager:askForRestart(_("Restart KOReader to apply this change to the home screen."))
    else
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
                      UIManager:show(orig_require("ui/widget/infomessage"):new{
                          text = _("Not a valid colour. Use #RRGGBB."), timeout = 3 })
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
                return _("Custom") .. " (" .. tostring(v) .. ")"
            end
            return _("Custom…")
        end,
        radio = true,
        checked_func = function()
            local v = get()
            return v ~= nil and v ~= "none" and not isPreset(v)
        end,
        keep_menu_open = true,
        callback = function(touchmenu_instance)
            customColorDialog(get(), function(v)
                put(v)
                if touchmenu_instance then touchmenu_instance:updateItems() end
            end)
        end,
    }
    items[#items + 1] = {
        text = off_label or _("SimpleUI default"), radio = true,
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
            text = pct == 100 and (pct .. "% " .. _("(default)")) or (pct .. "%"),
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
                              UIManager:show(orig_require("ui/widget/infomessage"):new{
                                  text = _("Enter a number from 50 to 300."), timeout = 3 })
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
    local function boldMods() return cfg.bold.modules end
    local function accentMods() return cfg.accent_modules end

    -- Bold > Modules
    local bold_module_items = {
        {
            text = _("All modules"),
            checked_func = function()
                for _i, m in ipairs(ALL_MODULES) do
                    if not cfg.bold.modules[m[1]] then return false end
                end
                return true
            end,
            callback = function(touchmenu_instance)
                local all = true
                for _i, m in ipairs(ALL_MODULES) do
                    if not cfg.bold.modules[m[1]] then all = false break end
                end
                for _i, m in ipairs(ALL_MODULES) do cfg.bold.modules[m[1]] = not all end
                saveConfig()
                if touchmenu_instance then touchmenu_instance:updateItems() end
                askRestart()
            end,
            separator = true,
        },
    }
    for _i, m in ipairs(ALL_MODULES) do
        bold_module_items[#bold_module_items + 1] = item(m[2], toggle(boldMods, m[1], askRestart))
    end

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

    local titles_items = {
        {
            text = _("All sections"),
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
            text = _("Day look in Night Mode"),
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
                                                 nil, _("Same as all sections")) },
                { text = _("Bold"),
                  sub_item_table = {
                    { text = _("Same as all sections"), radio = true,
                      checked_func = function() return sectionGet(id, "bold")() == nil end,
                      callback = function() sectionPut(id, "bold")(nil) end,
                      separator = true },
                    { text = _("Bold"), radio = true,
                      checked_func = function() return sectionGet(id, "bold")() == true end,
                      callback = function() sectionPut(id, "bold")(true) end },
                    { text = _("Not bold"), radio = true,
                      checked_func = function() return sectionGet(id, "bold")() == false end,
                      callback = function() sectionPut(id, "bold")(false) end },
                  } },
                { text_func = function()
                      local v = sectionGet(id, "size")()
                      return _("Size") .. ": " .. (v and (v .. "%") or _("same as all"))
                  end,
                  sub_item_table = sizeMenuWith(sectionGet(id, "size"), sectionPut(id, "size"),
                                                _("Same as all sections")) },
                { text = _("Reset this section"),
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
                    { text = _("Text colour"),
                      sub_item_table = colorMenu("module_text", true) },
                    { text = _("Text colour in Night Mode"),
                      sub_item_table = colorMenu("night_text", true, _("Off (inverts with the screen)")) },
                    { text = _("Also recolour grey text"),
                      checked_func = function() return cfg.recolor_all end,
                      callback = function() set("recolor_all", not cfg.recolor_all, true) end,
                      separator = true },
                    { text = _("Progress & borders colour"),
                      sub_item_table = colorMenu("accent", true) },
                    { text = _("Progress track colour"),
                      sub_item_table = colorMenu("track", true) },
                    { text = _("Use progress colours in"),
                      sub_item_table = accent_items,
                      separator = true },
                    { text = _("Bold"), sub_item_table = bold_module_items },
                    { text = _("Quick Actions icons keep original colours in Night Mode"),
                      checked_func = function() return cfg.qa_icons_original end,
                      callback = function() set("qa_icons_original", not cfg.qa_icons_original) end },
                },
            },
            {
                text = _("Section titles"),
                sub_item_table = titles_items,
            },
            {
                text = _("Nav bar"),
                sub_item_table = {
                    item(_("Bold labels"), toggle(boldTbl, "nav", askRestart)),
                    { text = _("Day look in Night Mode"),
                      checked_func = function() return cfg.nav_labels_black end,
                      callback = function() set("nav_labels_black", not cfg.nav_labels_black) end },
                    { text = _("Icons keep original colours in Night Mode"),
                      checked_func = function() return cfg.nav_icons_original end,
                      callback = function() set("nav_icons_original", not cfg.nav_icons_original) end },
                },
            },
            {
                text = _("KOReader menu"),
                sub_item_table = {
                    { text_func = function()
                          local n = 0
                          for _k in pairs(cfg.menu_icons.tab) do n = n + 1 end
                          return _("Tab icons keep original colours in Night Mode") .. (n > 0 and (": " .. n) or "")
                      end,
                      help_text = _("For colour icons you've swapped in (same file name in koreader/icons/). Plain black icons would disappear on the dark Night Mode menu. Applies the next time the menu opens."),
                      sub_item_table_func = tabItems },
                    { text = _("Arrows keep original colours in Night Mode"),
                      help_text = _("Back arrow and page arrows. Only useful with colour arrow icons swapped in. Applies the next time the menu opens."),
                      checked_func = function() return cfg.menu_icons.arrows end,
                      callback = function() cfg.menu_icons.arrows = not cfg.menu_icons.arrows; saveConfig() end },
                },
            },
            {
                text = _("Status bar"),
                sub_item_table = {
                    item(_("Bold"), toggle(boldTbl, "topbar", refreshTopbarNow)),
                    { text = _("Day look in Night Mode"),
                      checked_func = function() return cfg.topbar_day_night end,
                      callback = function() set("topbar_day_night", not cfg.topbar_day_night) end },
                },
                separator = true,
            },
            {
                text = _("Reset to defaults"),
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
            return { { text = _("Couldn't load settings (see crash.log)"), enabled = false } }
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

-- ---- Shortcuts Toolbar compatibility ---------------------------------------------------
-- Shortcuts Toolbar tells the file browser and reader menus apart by tab icon
-- name (appbar.filebrowser / appbar.navigation / appbar.typeset). A custom tab
-- icon from SimpleUI's System Icons renames it, so the toolbar stopped
-- showing. Teach its two checks to also recognise those tabs by menu id.
userpatch.registerPatchPluginFunc("shortcutstoolbar", function(plugin)
    if type(plugin) ~= "table" or plugin._sui_mod_menu_compat then return end
    local menuConfig = findUpvalue(plugin.onSwitchTab, "menuConfig")
        or findUpvalue(plugin.onMenuInit, "menuConfig")
    if type(menuConfig) ~= "function" then return end
    local orig_reader, ri = findUpvalue(menuConfig, "isReaderMenu")
    local orig_fb, fi = findUpvalue(menuConfig, "isFileBrowserMenu")
    if type(orig_reader) ~= "function" or type(orig_fb) ~= "function" then return end
    plugin._sui_mod_menu_compat = true

    local function hasTab(menu, ids)
        if type(menu) ~= "table" or type(menu.tab_item_table) ~= "table" then return false end
        for _i, tab in ipairs(menu.tab_item_table) do
            if type(tab) == "table" and ids[tab.id] then return true end
        end
        return false
    end
    local READER_TABS = { navi = true, typeset = true }
    local FB_TABS = { filemanager_settings = true }

    -- shared by every function in the plugin that uses these checks
    debug.setupvalue(menuConfig, ri, function(menu)
        if orig_reader(menu) then return true end
        local R = package.loaded["apps/reader/readerui"]
        local inst = type(R) == "table" and R.instance
        return inst ~= nil and inst ~= false and not inst.tearing_down and hasTab(menu, READER_TABS)
    end)
    debug.setupvalue(menuConfig, fi, function(menu)
        if orig_fb(menu) then return true end
        local F = package.loaded["apps/filemanager/filemanager"]
        local inst = type(F) == "table" and F.instance
        return inst ~= nil and inst ~= false and not inst.tearing_down
            and not hasTab(menu, READER_TABS) and hasTab(menu, FB_TABS)
    end)
end)

-- Remember SimpleUI's plugin name (its folder name), for suiInstance().
userpatch.registerPatchPluginFunc("simpleui", function(plugin)
    if type(plugin) == "table" and type(plugin.name) == "string" then sui_name = plugin.name end
end)
