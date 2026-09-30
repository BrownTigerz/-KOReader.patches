--[[
Shortcuts Toolbar – Icon Tweaks (userpatch)
===========================================
For xusoo/shortcutstoolbar.koplugin

Adds  Shortcuts toolbar → Icon tweaks  to the plugin menu:
  • Swap any toolbar icon (built-in or custom) for your own SVG/PNG,
    or put it back to the plugin's original.
  • Colour mode, globally or per icon:
      Default          – plugin behaviour (icons follow night mode)
      Keep original    – icons keep their true colours, even in night mode
      Inverted         – icon colours flipped relative to the UI
    (no background tile – only the icon pixels are flipped)
  • Optional on/off indicator per icon (follow Wi-Fi, frontlight or night
    mode): dim when off, inverted tile when off or when on, or swap to an
    alternate "off" icon.

Works in the reader menu, file-browser bar/persistent bar and the SimpleUI
home-screen module. Does not modify any plugin files.

Install: drop in koreader/patches/ and restart KOReader.
Custom icons: put them in koreader/icons/ (or anywhere) and pick them from
the menu.
--]]

local userpatch = require("userpatch")

local SETTINGS_KEY = "shortcutstoolbar_icon_tweaks"
local MODES = {
    { id = "default",  text = "Default (follow UI)" },
    { id = "original", text = "Keep original colours" },
    { id = "inverted", text = "Inverted" },
}

local function loadSettings()
    local s = G_reader_settings:readSetting(SETTINGS_KEY) or {}
    s.mode = s.mode or "default"
    s.keys = s.keys or {}
    return s
end

local function saveSettings(s)
    G_reader_settings:saveSetting(SETTINGS_KEY, s)
end

local function modeText(id)
    for _, m in ipairs(MODES) do
        if m.id == id then return m.text end
    end
    return id
end

-- --------------------------------------------------------------------------
-- State sources (for on/off indicators)
-- --------------------------------------------------------------------------

local STATES = {
    { id = "wifi", text = "Wi-Fi", get = function()
        return require("ui/network/manager"):isWifiOn()
    end },
    { id = "frontlight", text = "Frontlight", get = function()
        local Device = require("device")
        if not Device:hasFrontlight() then return true end
        return Device:getPowerDevice():isFrontlightOn()
    end },
    { id = "night_mode", text = "Night mode", get = function()
        return require("device").screen.night_mode or G_reader_settings:isTrue("night_mode")
    end },
    -- Same check KOReader's own SSH menu uses for its checkmark.
    { id = "ssh", text = "SSH server", get = function()
        return require("libs/libkoreader-lfs").attributes("/tmp/dropbear_koreader.pid", "mode") == "file"
    end },
    -- Calibre plugin's wireless client: its socket exists only while
    -- connected (it's cleared on disconnect or a failed connect).
    { id = "calibre", text = "Calibre connection", get = function()
        local W = package.loaded["wireless"]
        return type(W) == "table" and W.calibre_socket ~= nil
    end },
}

-- Tap-toggle state is shared by shortcut NAME, so the same shortcut set up
-- in the reader and the library (which get different internal keys) stays
-- in sync.
local function toggleId(key)
    local ok_m, Manager = pcall(require, "custom_shortcut_manager")
    if ok_m then
        for _i, view in ipairs({ "reader", "fb", "simpleui" }) do
            for _j, it in ipairs(Manager.getShortcutDataItems(view)) do
                if it.key == key then return "label:" .. tostring(it.label or key) end
            end
        end
    end
    return "key:" .. key
end

local function getToggled(key)
    local t = (G_reader_settings:readSetting(SETTINGS_KEY) or {}).toggles
    return t and t[toggleId(key)] == true
end
-- Not a real device state: flips each time the icon is tapped and is
-- remembered across restarts. For custom shortcuts that toggle something
-- KOReader can't report on.
table.insert(STATES, 1, { id = "tap", text = "Tap toggle", get = getToggled })

local STATE_BY_ID = {}
for _, st in ipairs(STATES) do STATE_BY_ID[st.id] = st end

-- --------------------------------------------------------------------------
-- Rendering
-- --------------------------------------------------------------------------

local function fileExists(f)
    if not f then return false end
    return require("libs/libkoreader-lfs").attributes(f, "mode") == "file"
end

local function newIcon(btn, file, alpha)
    local IconWidget = require("ui/widget/iconwidget")
    return IconWidget:new{ file = file, width = btn.width, height = btn.height, alpha = alpha }
end

-- The icon keeps its transparency (alpha), so flipping is done as:
-- invert area -> blend icon -> invert area. The background gets inverted
-- twice (unchanged); only the icon pixels end up inverted. No tile.
local function installPaint(img, mode, state, off_img, style, key)
    local base = img.paintTo
    img.paintTo = function(self, bb, x, y)
        local night = require("device").screen.night_mode and true or false
        local flip = (mode == "original" and night) or (mode == "inverted" and not night)

        local on = true
        if state then
            local ok, v = pcall(state.get, key)
            on = (not ok) or (v and true or false)
        end

        local src, paint = self, base
        if not on and off_img then src, paint = off_img, off_img.paintTo end
        local sz = src:getSize()
        -- Deliberate: this patch owns inversion for tweaked icons (via the
        -- invertRect pairs below), so ImageWidget's own flag must stay off
        -- or the two would stack.
        src.invert = nil

        if flip then bb:invertRect(x, y, sz.w, sz.h) end
        paint(src, bb, x, y)
        if flip then bb:invertRect(x, y, sz.w, sz.h) end
        if state then
            if style == "dim" and not on then
                bb:lightenRect(x, y, sz.w, sz.h)
            elseif (style == "invert_off" and not on) or (style == "invert_on" and on) then
                -- Full-area flip on purpose: gives a solid "active" tile
                -- that's visible even for plain black line icons.
                bb:invertRect(x, y, sz.w, sz.h)
            end
        end
    end
end

local function tweakButton(btn, key)
    local s = loadSettings()
    local k = s.keys[key] or {}
    local mode = k.mode or s.mode
    local state = k.state and STATE_BY_ID[k.state]
    local custom = fileExists(k.file) and k.file or nil
    if not custom and mode == "default" and not state then return end

    local file = custom or (btn.image and btn.image.file)
    if not file then return end
    local alpha = mode ~= "default"
    local img = newIcon(btn, file, alpha)
    local style = k.off_style or (k.off_file and "icon") or "dim"
    -- Release the previous off-state widget before making a new one.
    -- (Its bitmap lives in KOReader's shared icon cache, so this is tidiness
    -- rather than a real leak, but it keeps ownership explicit.)
    if btn._stb_off_img then pcall(btn._stb_off_img.free, btn._stb_off_img) end
    local off_img = (state and style == "icon" and fileExists(k.off_file))
        and newIcon(btn, k.off_file, alpha) or nil
    btn._stb_off_img = off_img
    installPaint(img, mode, state, off_img, style, key)

    local old = btn.image
    local hg = btn.horizontal_group
    local slot
    if hg then
        for i = 1, #hg do
            if hg[i] == old then slot = i; break end
        end
    end
    if not slot then return end -- unexpected layout: leave button untouched
    btn.image = img
    hg[slot] = img
    btn:update()
    if old and old ~= img and old.free then pcall(old.free, old) end
end

-- After a tap, re-draw a few times so async state (Wi-Fi) catches up.
local function addStateRefresh(btn, key)
    local UIManager = require("ui/uimanager")
    local cb = btn.callback
    if not cb then return end
    btn.callback = function(...)
        local top = UIManager.getTopmostVisibleWidget and UIManager:getTopmostVisibleWidget()
        local s = loadSettings()
        local k = s.keys[key]
        if k and k.state == "tap" then
            local id = toggleId(key)
            s.toggles = s.toggles or {}
            s.toggles[id] = (not s.toggles[id]) or nil
            saveSettings(s)
            if top and btn.dimen then UIManager:setDirty(top, "ui", btn.dimen) end
        end
        cb(...)
        for _, d in ipairs({ 1, 3, 6, 10 }) do
            UIManager:scheduleIn(d, function()
                if top and btn.dimen and UIManager:getTopmostVisibleWidget() == top then
                    UIManager:setDirty(top, "ui", btn.dimen)
                end
            end)
        end
    end
end

-- Work out which shortcut keys will become IconButtons, in order, so each
-- captured button can be matched back to its key.
local function expectedKeys(config)
    local ok_d, SHORTCUT_DATA = pcall(require, "shortcuts_data")
    local ok_m, Manager = pcall(require, "custom_shortcut_manager")
    local known = {}
    if ok_d then for _, it in ipairs(SHORTCUT_DATA) do known[it.key] = it end end
    if ok_m then
        for _, it in ipairs(Manager.getShortcutDataItems(config.view or "reader")) do
            known[it.key] = it
        end
    end
    local list = {}
    for token in string.gmatch(config.items or "", "([^,]+)") do
        local key = token:match("^%s*(.-)%s*$")
        if known[key] and key ~= "spacer" and key ~= "spacer2"
                and key ~= "time" and key ~= "battery" then
            -- The icon the plugin passes to IconButton:new for this key.
            -- Wi-Fi is dynamic, so accept either state.
            local icons = key == "wifi" and { ["wifi"] = true, ["wifi.open.0"] = true }
                or { [known[key].icon or "__nil__"] = true }
            table.insert(list, { key = key, icons = icons })
        end
    end
    return list
end

-- Run fn while capturing every toolbar IconButton it creates.
local building = false
local function withCapture(config, fn, ...)
    if building or type(config) ~= "table" then return fn(...) end
    local IconButton = require("ui/widget/iconbutton")
    local Screen = require("device").screen
    local icon_size = Screen:scaleBySize(config.icon_size or 32)
    local padding_h = Screen:scaleBySize(config.spacing or 8)
    local queue = expectedKeys(config)
    local desynced = false
    local captured = {}
    local orig_new = IconButton.new

    building = true
    IconButton.new = function(cls, o)
        local icon_arg = o and rawget(o, "icon")
        local btn = orig_new(cls, o)
        -- Only consider buttons shaped like toolbar shortcuts.
        if desynced or not o or #queue == 0 or o.width ~= icon_size
                or o.padding_left ~= padding_h then
            return btn
        end
        local want = queue[1]
        if want.icons[icon_arg or "__nil__"] then
            table.remove(queue, 1)
            table.insert(captured, { btn = btn, key = want.key })
        else
            -- Order no longer matches what we expected: stop matching so
            -- nothing gets the wrong key's tweaks. Earlier (verified)
            -- matches still apply.
            desynced = true
            require("logger").warn("shortcutstoolbar icon tweaks: button order mismatch at", want.key)
        end
        return btn
    end
    local ok, res = pcall(fn, ...)
    IconButton.new = orig_new
    building = false
    if not ok then error(res) end

    local settings = loadSettings()
    for _, c in ipairs(captured) do
        local btn, key = c.btn, c.key
        tweakButton(btn, key)
        local k = settings.keys[key]
        if k and k.state then addStateRefresh(btn, key) end
        -- Wi-Fi toggles rebuild the image via setIcon(); re-apply after.
        local orig_set = btn.setIcon
        btn.setIcon = function(self, icon)
            orig_set(self, icon)
            tweakButton(self, key)
        end
    end
    return res
end

local function hookHomeContent()
    local HomeContent = package.loaded["home_content"]
    if not HomeContent then
        local ok, mod = pcall(require, "home_content")
        if not ok then return false end
        HomeContent = mod
    end
    if HomeContent.__stb_icon_tweaks then return true end
    HomeContent.__stb_icon_tweaks = true

    local orig_home = HomeContent.createHomeContent
    HomeContent.createHomeContent = function(menu, config, ...)
        return withCapture(config, orig_home, menu, config, ...)
    end
    local orig_bar = HomeContent.createShortcutsBar
    HomeContent.createShortcutsBar = function(menu, config, ...)
        return withCapture(config, orig_bar, menu, config, ...)
    end
    return true
end

-- --------------------------------------------------------------------------
-- Menu
-- --------------------------------------------------------------------------

local function refreshViews()
    local HS = package.loaded["homescreen"]
    if HS and HS.refreshImmediate then pcall(HS.refreshImmediate, false) end
end

local function allShortcuts()
    local _ = require("gettext")
    local items, seen = {}, {}
    local ok_d, SHORTCUT_DATA = pcall(require, "shortcuts_data")
    if ok_d then
        for _i, it in ipairs(SHORTCUT_DATA) do
            if it.icon or it.icon_file then
                seen[it.key] = true
                table.insert(items, { key = it.key, label = it.label })
            end
        end
    end
    local ok_m, Manager = pcall(require, "custom_shortcut_manager")
    if ok_m then
        local where = { reader = _("reader"), fb = _("library"), simpleui = _("home") }
        for _i, view in ipairs({ "reader", "fb", "simpleui" }) do
            for _j, it in ipairs(Manager.getShortcutDataItems(view)) do
                if not seen[it.key] then
                    seen[it.key] = true
                    table.insert(items, { key = it.key,
                        label = (it.label or it.key) .. " (" .. where[view] .. ")" })
                end
            end
        end
    end
    return items
end

local function pickIcon(on_pick)
    local DataStorage = require("datastorage")
    local lfs = require("libs/libkoreader-lfs")
    local UIManager = require("ui/uimanager")
    local ok, IconBrowser = pcall(require, "icon_browser")
    local user_dir = DataStorage:getDataDir() .. "/icons"
    local start = lfs.attributes(user_dir, "mode") == "directory" and user_dir or nil
    if ok then
        UIManager:show(IconBrowser:new{ path = start, onConfirm = on_pick })
    else
        local PathChooser = require("ui/widget/pathchooser")
        UIManager:show(PathChooser:new{
            select_directory = false,
            path = start or DataStorage:getDataDir(),
            onConfirm = on_pick,
        })
    end
end

local function modeRadio(get, set)
    local t = {}
    for _, m in ipairs(MODES) do
        table.insert(t, {
            text = m.text,
            radio = true,
            checked_func = function() return get() == m.id end,
            callback = function() set(m.id) end,
        })
    end
    return t
end

local function perIconMenu(key)
    local _ = require("gettext")
    local T = require("ffi/util").template
    local function getK() local s = loadSettings(); return s, s.keys[key] or {} end
    local function putK(s, k)
        if next(k) == nil then s.keys[key] = nil else s.keys[key] = k end
        saveSettings(s); refreshViews()
    end

    local colour = {
        {
            text = _("Use global setting"),
            radio = true,
            checked_func = function() local _s, k = getK(); return k.mode == nil end,
            callback = function() local s, k = getK(); k.mode = nil; putK(s, k) end,
            separator = true,
        },
    }
    for _i, entry in ipairs(modeRadio(
        function() local _s, k = getK(); return k.mode end,
        function(id) local s, k = getK(); k.mode = id; putK(s, k) end)) do
        table.insert(colour, entry)
    end

    return {
        {
            text_func = function()
                local _s, k = getK()
                return k.file and T(_("Icon: %1"), k.file:match("[^/]+$")) or _("Icon: original")
            end,
            keep_menu_open = true,
            callback = function(touchmenu)
                pickIcon(function(path)
                    local s, k = getK(); k.file = path; putK(s, k)
                    if touchmenu then touchmenu:updateItems() end
                end)
            end,
        },
        {
            text = _("Restore original icon"),
            enabled_func = function() local _s, k = getK(); return k.file ~= nil end,
            keep_menu_open = true,
            callback = function(touchmenu)
                local s, k = getK(); k.file = nil; putK(s, k)
                if touchmenu then touchmenu:updateItems() end
            end,
            separator = true,
        },
        {
            text_func = function()
                local _s, k = getK()
                return T(_("Colour: %1"), k.mode and modeText(k.mode) or _("global"))
            end,
            sub_item_table = colour,
            separator = true,
        },
        {
            text_func = function()
                local _s, k = getK()
                local st = k.state and STATE_BY_ID[k.state]
                return T(_("On/off indicator: %1"), st and st.text or _("off"))
            end,
            sub_item_table_func = function()
                local t = {
                    {
                        text = _("None"),
                        radio = true,
                        checked_func = function() local _s, k = getK(); return k.state == nil end,
                        callback = function() local s, k = getK(); k.state = nil; putK(s, k) end,
                        separator = true,
                    },
                }
                for _i, st in ipairs(STATES) do
                    table.insert(t, {
                        text = st.id == "tap" and _("Tap toggle (flips on each tap)")
                            or T(_("Follow %1"), st.text),
                        radio = true,
                        checked_func = function() local _s, k = getK(); return k.state == st.id end,
                        callback = function() local s, k = getK(); k.state = st.id; putK(s, k) end,
                    })
                end
                table.insert(t, {
                    text = _("Reset tap toggle to off"),
                    enabled_func = function() local _s, k = getK(); return k.state == "tap" and getToggled(key) end,
                    keep_menu_open = true,
                    callback = function(touchmenu)
                        local s = loadSettings()
                        if s.toggles then s.toggles[toggleId(key)] = nil end
                        saveSettings(s); refreshViews()
                        if touchmenu then touchmenu:updateItems() end
                    end,
                })
                t[#t].separator = true
                local function curStyle(k) return k.off_style or (k.off_file and "icon") or "dim" end
                local styles = {
                    { id = "dim",        text = _("Dim when off") },
                    { id = "invert_off", text = _("Inverted when off") },
                    { id = "invert_on",  text = _("Inverted when on") },
                }
                for _i, sty in ipairs(styles) do
                    table.insert(t, {
                        text = sty.text,
                        radio = true,
                        enabled_func = function() local _s, k = getK(); return k.state ~= nil end,
                        checked_func = function() local _s, k = getK(); return curStyle(k) == sty.id end,
                        callback = function() local s, k = getK(); k.off_style = sty.id; putK(s, k) end,
                    })
                end
                table.insert(t, {
                    text_func = function()
                        local _s, k = getK()
                        return k.off_file and T(_("Custom icon when off: %1"), k.off_file:match("[^/]+$"))
                            or _("Custom icon when off…")
                    end,
                    radio = true,
                    enabled_func = function() local _s, k = getK(); return k.state ~= nil end,
                    checked_func = function() local _s, k = getK(); return curStyle(k) == "icon" end,
                    keep_menu_open = true,
                    callback = function(touchmenu)
                        pickIcon(function(path)
                            local s, k = getK(); k.off_file = path; k.off_style = "icon"; putK(s, k)
                            if touchmenu then touchmenu:updateItems() end
                        end)
                    end,
                })
                return t
            end,
        },
    }
end

local function buildMenu()
    local _ = require("gettext")
    local UIManager = require("ui/uimanager")
    local ConfirmBox = require("ui/widget/confirmbox")
    return {
        text = _("Icon tweaks"),
        sub_item_table_func = function()
            local t = {
                {
                    text_func = function()
                        return _("Global colour: ") .. modeText(loadSettings().mode)
                    end,
                    sub_item_table = modeRadio(
                        function() return loadSettings().mode end,
                        function(id) local s = loadSettings(); s.mode = id; saveSettings(s); refreshViews() end),
                    separator = true,
                },
            }
            for _i, it in ipairs(allShortcuts()) do
                local key = it.key
                table.insert(t, {
                    text_func = function()
                        local k = loadSettings().keys[key]
                        return it.label .. ((k and next(k)) and "  ●" or "")
                    end,
                    sub_item_table_func = function() return perIconMenu(key) end,
                })
            end
            t[#t].separator = true
            table.insert(t, {
                text = _("Reset all icon tweaks"),
                callback = function()
                    UIManager:show(ConfirmBox:new{
                        text = _("Reset all icon and colour tweaks?"),
                        ok_callback = function()
                            G_reader_settings:delSetting(SETTINGS_KEY)
                            refreshViews()
                        end,
                    })
                end,
            })
            return t
        end,
    }
end

-- --------------------------------------------------------------------------
-- Entry point
-- --------------------------------------------------------------------------

userpatch.registerPatchPluginFunc("shortcutstoolbar", function(plugin)
    hookHomeContent()
    if plugin.__stb_icon_tweaks_menu then return end
    plugin.__stb_icon_tweaks_menu = true

    local orig_add = plugin.addToMainMenu
    plugin.addToMainMenu = function(self, menu_items)
        orig_add(self, menu_items)
        local root = menu_items.shortcutstoolbar
        if root and root.sub_item_table then
            table.insert(root.sub_item_table, buildMenu())
        end
    end
end)
