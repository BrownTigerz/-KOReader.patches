--[[
2-simpleui-mod.lua
KOReader user patch for SimpleUI (simpleui.koplugin).

Settings: Tools > SimpleUI Mod

- Module text colour (normal and Night Mode)
- Progress bar / ring / border colours for chosen modules
- Nav bar labels black in Night Mode
- Nav bar icons in Night Mode: keep original colours, black, or normal

Colours are how things look ON SCREEN. Night Mode inverts the screen,
so the patch pre-inverts where needed to get the colour you picked.

Install: koreader/patches/2-simpleui-mod.lua, then restart.
(Remove the older 2-simpleui-module-text-color.lua if you have it.)
]]

-- ---- Defaults (change in Tools > SimpleUI Mod) -----------------------------
local DEFAULTS = {
    module_text      = "#000000",   -- module text, normal mode
    night_text       = "#000000",   -- module text in Night Mode (as shown)
    recolor_all      = true,        -- also recolour grey/dim text
    section_titles   = "none",      -- section title colour ("none" = default)
    accent           = "#000000",   -- borders, progress fill, stat icons
    track            = "#CCCCCC",   -- unfilled part of bars/rings
    accent_modules   = { reading_goals = true, reading_stats = true, currently = false },
    nav_labels_black = true,        -- nav labels show black in Night Mode
    nav_icon_night   = "original",  -- "original" | "black" | "off"
    titles_day_night = true,        -- section titles look the same in Night Mode
    topbar_day_night = true,        -- status bar looks the same in Night Mode
    topbar_bold      = true,        -- bold status bar text and symbols
    show_popup       = false,       -- status popup on startup
}

-- Per-module text overrides (file only), e.g. quote = "#333333"
local PER_MODULE = {
}
-- ---------------------------------------------------------------------------

local userpatch  = require("userpatch")
local Blitbuffer = require("ffi/blitbuffer")
local Screen     = require("device").screen
local logger     = require("logger")

local TAG = "simpleui-mod:"
local SETTINGS_KEY = "simpleui_mod"
local status = {}

-- ---- settings ----------------------------------------------------------------
local cfg = {}
local function loadConfig()
    local saved = G_reader_settings and G_reader_settings:readSetting(SETTINGS_KEY) or {}
    for k, v in pairs(DEFAULTS) do
        if type(v) == "table" then
            cfg[k] = {}
            for k2, v2 in pairs(v) do cfg[k][k2] = v2 end
            if type(saved[k]) == "table" then
                for k2, v2 in pairs(saved[k]) do cfg[k][k2] = v2 end
            end
        elseif saved[k] ~= nil then
            cfg[k] = saved[k]
        else
            cfg[k] = v
        end
    end
end
local function saveConfig()
    if G_reader_settings then G_reader_settings:saveSetting(SETTINGS_KEY, cfg) end
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
local TEXT_C, NIGHT_C, LABEL_C
local ACC_DAY, ACC_NIGHT, TRK_DAY, TRK_NIGHT
local PER_C = {}
local onConfigApplied  -- set further down (rebuilds cached accent tables)

local function applyConfig()
    TEXT_C    = colorOf(cfg.module_text)
    NIGHT_C   = colorOf(cfg.night_text, true)   -- pre-inverted for Night Mode
    LABEL_C   = colorOf(cfg.section_titles)
    ACC_DAY   = colorOf(cfg.accent)
    ACC_NIGHT = colorOf(cfg.accent, true)
    TRK_DAY   = colorOf(cfg.track)
    TRK_NIGHT = colorOf(cfg.track, true)
    PER_C = {}
    for id, hex in pairs(PER_MODULE) do PER_C[id] = colorOf(hex) end
    if onConfigApplied then onConfigApplied() end
end
applyConfig()

local function shouldRecolor(c)
    local v = grayLevel(c)
    if v == nil then return false end
    if cfg.recolor_all then return v < 0xE0 end  -- skip white/near-white text
    return v == 0
end

local function colorForModule(id)
    if Screen.night_mode and NIGHT_C then return NIGHT_C end
    if type(id) == "string" then
        for key, c in pairs(PER_C) do
            if id == key or id:sub(1, #key) == key then return c end
        end
    end
    return TEXT_C
end

-- ---- scopes -----------------------------------------------------------------------
local cur_color = nil  -- colour applied to text built right now
local suspended = 0    -- > 0: don't recolour (mask internals)
local flip_kind = nil  -- "nav" | "title" | "topbar" while building those
local in_mask   = 0    -- > 0: painting through an alpha mask
local UIcore           -- infra/sui_core once loaded

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
    if kind == "nav_icon" then return cfg.nav_icon_night ~= "off" end
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

local WHITE = Blitbuffer.Color8(255)

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
    self._bb = self._sui_inv_bb
    local ok, err = pcall(orig, self, bb, x, y)
    self._bb = src
    if not ok then error(err, 0) end
    return true
end

local function paintIconBlack(self, orig, bb, x, y)
    if not (UIcore and UIcore.paintWithAlphaMask) then return false end
    local sz = self:getSize()
    local w, h = sz.w, sz.h
    if w <= 0 or h <= 0 then return false end
    if not self._sui_tmp_bb or self._sui_tmp_bb:getWidth() ~= w
       or self._sui_tmp_bb:getHeight() ~= h then
        if self._sui_tmp_bb then self._sui_tmp_bb:free() end
        self._sui_tmp_bb = Blitbuffer.new(w, h, Blitbuffer.TYPE_BB8)
    end
    UIcore.paintWithAlphaMask(self, bb, x, y, w, h, WHITE, orig, self._sui_tmp_bb)
    return true
end

local function makeNightAwareIcon(iw, kind)
    if iw._sui_nav_night then return end
    iw._sui_nav_night = true
    local orig = iw.paintTo
    iw.paintTo = function(self, bb, x, y)
        if Screen.night_mode and in_mask == 0 then
            local mode
            if kind == "nav" then mode = cfg.nav_icon_night
            else mode = flipOn(kind) and "original" or "off" end
            local painter = (mode == "original" and paintIconOriginal)
                         or (mode == "black" and paintIconBlack)
            if painter then
                local ok, done = pcall(painter, self, orig, bb, x, y)
                if ok and done then return end
                if not ok then logger.warn(TAG, "icon paint failed", done) end
            end
        end
        return orig(self, bb, x, y)
    end
    local orig_free = iw.free
    iw.free = function(self, ...)
        if self._sui_tmp_bb then self._sui_tmp_bb:free(); self._sui_tmp_bb = nil end
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
        if cur_color and suspended == 0 and shouldRecolor(self.fgcolor) then
            self.fgcolor = cur_color
        end
        if flip_kind and suspended == 0 then
            if flip_kind == "topbar" and cfg.topbar_bold then self.bold = true end
            makeNightAwareText(self, flip_kind)
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
                status.icons = "ok"
            end
            if orig_init then return orig_init(self, ...) end
        end
        status.icons = "waiting (no nav icon built yet)"
    else
        status.icons = "FAILED (imagewidget not found)"
    end
    local ok2, IcW = pcall(require, "ui/widget/iconwidget")
    if ok2 and type(IcW) == "table" and rawget(IcW, "init") then
        local orig_icon_init = IcW.init
        IcW.init = function(self, ...)
            if flip_kind then
                makeNightAwareIcon(self, flip_kind)   -- guarded against double-wrapping
                status.icons = "ok"
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

local function wrapDescriptor(m, fallback_id)
    if type(m) ~= "table" or wrapped[m] or type(m.build) ~= "function" then return end
    wrapped[m] = true
    local orig = m.build
    m.build = function(...)
        local id = (type(m.id) == "string" and m.id) or fallback_id
        local accent = isAccentModule(id)
        local ok, w
        if accent then
            ok, w = pcall(withAccents, withColor, colorForModule(id), orig, ...)
        else
            ok, w = pcall(withColor, colorForModule(id), orig, ...)
        end
        if ok then
            -- nil is a legitimate result (e.g. no book / no data yet)
            if w ~= nil and accent then pcall(makeAccentPaint, w, id); status.accents = "ok" end
            return w
        end
        -- Error: build once more without recolouring so the module doesn't
        -- disappear. (Runs build() a second time, but only on this error path.)
        status["error " .. tostring(id)] = tostring(w)
        logger.warn(TAG, "build failed for", id, w)
        return orig(...)
    end
    status.modules = "ok"

    -- In-place refreshes (e.g. stats after returning from the reader) rebuild
    -- parts of the module outside build(): give them the same colours.
    for _, fname in ipairs({ "updateStats", "updateCovers" }) do
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
                status["error " .. tostring(id) .. " " .. fname] = tostring(res[2])
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
        for _, sm in ipairs(M.sub_modules) do wrapDescriptor(sm, file_id) end
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
                return withColor(colorForModule("clock"), lb, ...)
            end)
        end
    end
end

local function patchCore(UI)
    if type(UI) ~= "table" then return end
    UIcore = UI

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
    status.coloredtext = wrapMaskMaker("makeColoredText") and "ok" or "FAILED"
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
    return status.coloredtext == "ok"
end

local function patchEngine(E)
    local done = false
    local function tryFn(fn)
        local orig_label, idx = findUpvalue(fn, "sectionLabel")
        if type(orig_label) == "function" then
            if ours[orig_label] then return true end
            debug.setupvalue(fn, idx, mine(function(...)
                return withColor(LABEL_C, flipScope, "title", orig_label, ...)
            end))
            return true
        end
    end
    for _, v in pairs(E or {}) do
        if done then break end
        if type(v) == "function" then
            if tryFn(v) then done = true break end
            local i = 1
            while not done do
                local n, uv = debug.getupvalue(v, i)
                if n == nil then break end
                if type(uv) == "table" then
                    for _, m in pairs(uv) do
                        if type(m) == "function" and tryFn(m) then done = true break end
                    end
                end
                i = i + 1
            end
        end
    end
    status.titles = done and "ok" or "unavailable"
    return done
end

local function patchTopbar(T)
    if type(T) ~= "table" or type(T.buildTopbarWidget) ~= "function" then
        status.topbar = "FAILED"
        return
    end
    local orig = T.buildTopbarWidget
    if not ours[orig] then
        T.buildTopbarWidget = mine(function(...) return flipScope("topbar", orig, ...) end)
    end
    status.topbar = "ok"
    return true
end

local function patchBottombar(B)
    if type(B) ~= "table" then return end
    local n = 0
    for _, fname in ipairs({ "buildBarWidget", "buildBarWidgetWithArrows",
                             "buildBarWidgetWithKeyFocus", "buildTabCell",
                             "buildNavpagerArrowCell" }) do
        local orig = B[fname]
        if ours[orig] then
            n = n + 1
        elseif type(orig) == "function" then
            B[fname] = mine(function(...) return flipScope("nav", orig, ...) end)
            n = n + 1
        end
    end
    status.navbar = n > 0 and "ok" or "FAILED"
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

-- ---- Tools > SimpleUI Mod menu ------------------------------------------------------------
local _ = orig_require("gettext")

local PRESETS = {
    { "Black",      "#000000" },
    { "Dark grey",  "#555555" },
    { "Grey",       "#888888" },
    { "Light grey", "#CCCCCC" },
    { "White",      "#FFFFFF" },
}

local function isPreset(v)
    for _, p in ipairs(PRESETS) do if p[2] == v then return true end end
    return false
end

local sui_plugin  -- SimpleUI plugin instance (set once it starts)

local function refreshTopbarNow()
    local T = package.loaded["screens/sui_topbar"]
    if sui_plugin and type(T) == "table" and type(T.refresh) == "function" then
        pcall(T.refresh, sui_plugin)
    end
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

local function colorMenu(key, needs_restart, off_label)
    local items = {}
    for _, p in ipairs(PRESETS) do
        items[#items + 1] = {
            text = p[1],
            radio = true,
            checked_func = function() return cfg[key] == p[2] end,
            callback = function() set(key, p[2], needs_restart) end,
        }
    end
    items[#items + 1] = {
        text_func = function()
            local v = cfg[key]
            if v ~= "none" and not isPreset(v) then return _("Custom") .. " (" .. tostring(v) .. ")" end
            return _("Custom…")
        end,
        radio = true,
        checked_func = function() return cfg[key] ~= "none" and not isPreset(cfg[key]) end,
        keep_menu_open = true,
        callback = function(touchmenu_instance)
            local UIManager = orig_require("ui/uimanager")
            local InputDialog = orig_require("ui/widget/inputdialog")
            local dlg
            dlg = InputDialog:new{
                title = _("Colour (hex, e.g. #336699)"),
                input = (cfg[key] ~= "none" and cfg[key]) or "#",
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
                          set(key, v:upper(), needs_restart)
                          if touchmenu_instance then touchmenu_instance:updateItems() end
                      end },
                }},
            }
            UIManager:show(dlg)
            dlg:onShowKeyboard()
        end,
    }
    items[#items + 1] = {
        text = off_label or _("SimpleUI default"),
        radio = true,
        checked_func = function() return cfg[key] == "none" end,
        callback = function() set(key, "none", needs_restart) end,
    }
    return items
end

local function buildMenu()
    local modules_list = {
        { "reading_goals", _("Reading Goals") },
        { "reading_stats", _("Reading Stats") },
        { "currently",     _("Currently Reading") },
    }
    local accent_items = {}
    for _, m in ipairs(modules_list) do
        accent_items[#accent_items + 1] = {
            text = m[2],
            checked_func = function() return cfg.accent_modules[m[1]] and true or false end,
            callback = function()
                cfg.accent_modules[m[1]] = not cfg.accent_modules[m[1]]
                saveConfig()
                applyConfig()
                askRestart()
            end,
        }
    end

    return {
        text = _("SimpleUI Mod"),
        sub_item_table = {
            {
                text = _("Module text colour"),
                sub_item_table = colorMenu("module_text", true),
            },
            {
                text = _("Module text colour in Night Mode"),
                sub_item_table = colorMenu("night_text", true, _("Off (inverts with the screen)")),
            },
            {
                text = _("Also recolour grey text"),
                checked_func = function() return cfg.recolor_all end,
                callback = function() set("recolor_all", not cfg.recolor_all, true) end,
            },
            {
                text = _("Section title colour"),
                sub_item_table = colorMenu("section_titles", true),
            },
            {
                text = _("Section titles: day look in Night Mode"),
                checked_func = function() return cfg.titles_day_night end,
                callback = function() set("titles_day_night", not cfg.titles_day_night) end,
                separator = true,
            },
            {
                text = _("Progress & border colour"),
                sub_item_table = colorMenu("accent", true),
            },
            {
                text = _("Progress track colour"),
                sub_item_table = colorMenu("track", true),
            },
            {
                text = _("Modules using progress colours"),
                sub_item_table = accent_items,
                separator = true,
            },
            {
                text = _("Nav labels black in Night Mode"),
                checked_func = function() return cfg.nav_labels_black end,
                callback = function() set("nav_labels_black", not cfg.nav_labels_black) end,
            },
            {
                text = _("Nav icons in Night Mode"),
                sub_item_table = {
                    { text = _("Keep original colours"), radio = true,
                      checked_func = function() return cfg.nav_icon_night == "original" end,
                      callback = function() set("nav_icon_night", "original") end },
                    { text = _("Solid black"), radio = true,
                      checked_func = function() return cfg.nav_icon_night == "black" end,
                      callback = function() set("nav_icon_night", "black") end },
                    { text = _("Off (invert normally)"), radio = true,
                      checked_func = function() return cfg.nav_icon_night == "off" end,
                      callback = function() set("nav_icon_night", "off") end },
                },
                separator = true,
            },
            {
                text = _("Status bar: day look in Night Mode"),
                checked_func = function() return cfg.topbar_day_night end,
                callback = function() set("topbar_day_night", not cfg.topbar_day_night) end,
            },
            {
                text = _("Status bar: bold text"),
                checked_func = function() return cfg.topbar_bold end,
                callback = function()
                    set("topbar_bold", not cfg.topbar_bold)
                    refreshTopbarNow()
                end,
                separator = true,
            },
            {
                text = _("Show status popup on startup"),
                checked_func = function() return cfg.show_popup end,
                callback = function() set("show_popup", not cfg.show_popup) end,
            },
            {
                text = _("Reset to defaults"),
                keep_menu_open = true,
                callback = function(touchmenu_instance)
                    local UIManager = orig_require("ui/uimanager")
                    local ConfirmBox = orig_require("ui/widget/confirmbox")
                    UIManager:show(ConfirmBox:new{
                        text = _("Reset all SimpleUI Mod settings to defaults?"),
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

local function addToOrder(order_mod)
    local ok, order = pcall(orig_require, order_mod)
    if not ok or type(order) ~= "table" or type(order.tools) ~= "table" then return end
    for _, v in ipairs(order.tools) do if v == "simpleui_mod" then return end end
    local pos = #order.tools + 1
    for i, v in ipairs(order.tools) do
        if type(v) == "string" and v:find("^%-%-%-") then pos = i break end
    end
    table.insert(order.tools, pos, "simpleui_mod")
end

local function hookMenu(menu_mod, order_mod)
    local ok, Menu = pcall(orig_require, menu_mod)
    if not ok or type(Menu) ~= "table" or type(Menu.setUpdateItemTable) ~= "function" then return end
    addToOrder(order_mod)
    local orig = Menu.setUpdateItemTable
    if ours[orig] then return end
    Menu.setUpdateItemTable = mine(function(self, ...)
        if self.menu_items then self.menu_items.simpleui_mod = buildMenu() end
        return orig(self, ...)
    end)
end

pcall(hookMenu, "apps/filemanager/filemanagermenu", "ui/elements/filemanager_menu_order")
pcall(hookMenu, "apps/reader/modules/readermenu", "ui/elements/reader_menu_order")

-- ---- status popup (optional) -----------------------------------------------------------------
local shown = false
userpatch.registerPatchPluginFunc("simpleui", function(plugin)
    sui_plugin = plugin
    if shown then return end
    shown = true
    local UIManager = orig_require("ui/uimanager")
    UIManager:scheduleIn(1.5, function()
        for name, mod in pairs(package.loaded) do handle(name, mod) end
        status.modules = status.modules or "waiting (no module loaded yet)"
        local ver = "?"
        pcall(function()
            local meta = dofile(plugin.path .. "/_meta.lua")
            ver = meta and meta.version or "?"
        end)
        local lines = {}
        for k, v in pairs(status) do lines[#lines + 1] = k .. ": " .. v end
        table.sort(lines)
        table.insert(lines, 1, "SimpleUI " .. tostring(ver))
        local msg = "SimpleUI Mod\n" .. table.concat(lines, "\n")
        logger.info(TAG, msg)
        if cfg.show_popup then
            UIManager:show(orig_require("ui/widget/infomessage"):new{ text = msg })
        end
    end)
end)
