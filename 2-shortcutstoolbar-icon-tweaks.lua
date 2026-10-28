--[[
Shortcuts Toolbar – Icon Tweaks (userpatch)
===========================================
Version: 1.17.0
For xusoo/shortcutstoolbar.koplugin

Adds  Shortcuts toolbar → Icon tweaks  to the plugin menu:
  • Swap any toolbar icon (built-in or custom) for your own SVG/PNG,
    or restore the plugin's original.
  • Colour mode, globally or per icon:
      Default          – plugin behaviour (icons follow night mode)
      Keep original    – icons keep their true colours, even in night mode
      Inverted         – icon colours flipped
    (no background tile – only the icon pixels are flipped)
  • Optional on/off indicator per icon. Follows Wi-Fi, frontlight, night
    mode, SSH server, Calibre connection, Bluetooth (Kobo plugin), a
    remembered tap toggle, or (for custom shortcuts set to a menu action)
    that menu item's own ✓.
    Off/on styles: dim when off, inverted tile when off or when on, or an
    alternate "off" icon.
  • The toolbar Wi-Fi icon, and any Wi-Fi/SSH/Calibre indicator, follow
    the real network state: background connects, failures, cancels,
    auto-disconnect, and sleep all update them.
  • Custom shortcuts for SSH, Wi-Fi, Calibre connect/disconnect and night
    mode toggles keep the toolbar open when tapped (like the built-in Wi-Fi
    button), so you see the icon change. Other actions still close it.
  • Hold the built-in Wi-Fi button: network list (Network Tweaks' picker
    when installed). Hold the built-in Restart or Search button: Restart /
    Exit KOReader, Reboot, Power off. Hold an SSH shortcut: Bluetooth
    (Kobo plugin): turn it on or off, scan, paired devices. Hold a
    Calibre shortcut: BookOrbit, directly, no menu. Hold a Bookshelf
    shortcut: BookOrbit, directly, no menu. Each hold action can be
    flipped on its own: tap runs the hold action, hold runs the normal
    tap. Tap does what it always did, unless flipped.
  • The Kobo plugin's Bluetooth messages show in Network Tweaks' note style
    (Banner / Minimal), like its Wi-Fi notes. Each hold action can be
    turned off in Icon Tweaks → Hold Actions. Off gives the plugin's own
    hold back.
  • If the top menu is open when the device goes to sleep (reader or
    library, where the toolbar lives), it closes first, so you wake up to
    the page, not the menu, and a sleep screen that keeps the page doesn't
    show the menu either.

Works in the reader menu, file-browser bar/persistent bar and the SimpleUI
home-screen module. Does not modify any plugin files. Compatible with
2-network-tweaks.lua (background connect, banners, SSH on connect); with
Network Tweaks 1.4.0+, SSH and Calibre icons update the moment they change.

Install: drop in koreader/patches/ and restart KOReader.
Custom icons: put them in koreader/icons/ (or anywhere) and pick them from
the menu.

Cost: icons left untouched get no hooks at all. Tweaked icons add one small
check per redraw. Indicator icons are only redrawn while their toolbar is
on screen; a closed toolbar triggers no redraws, a covered one redraws its
changed icons once when uncovered. Network-driven
icons repaint once per Wi-Fi connect / disconnect event (plus one follow-up
1.5s later for SSH/Calibre). Calibre
and SSH indicators also run at most one short catch-up timer after a tap
(stops as soon as the state changes). Menu Toggle and Bluetooth
indicators are checked once per toolbar open (~15-40 ms for Bluetooth,
a D-Bus query), then reuse the answer for redraws. Nothing runs
in the background or while asleep.

Changelog
  1.17.0 Hold a Bookshelf shortcut for BookOrbit directly, no menu: hold a
         custom shortcut that goes to the Bookshelf home screen to open
         BookOrbit. New per-hold Flip Tap And Hold: tap runs the hold
         action, hold runs the button's normal tap. Hold Actions menu
         restructured: each hold action is its own group with Enabled and
         Flip Tap And Hold. Without the BookOrbit plugin, or with a hold
         off, holding opens the shortcut's edit dialog as before.
  1.16.0 Hold a Calibre shortcut for BookOrbit directly, no menu: hold a
         custom shortcut that connects to (or disconnects from) Calibre to
         open BookOrbit. New Hold Actions toggle, on by default. Without
         the BookOrbit plugin, holding opens the shortcut's edit dialog
         as before.
  1.15.0 Hold Actions menu (Icon Tweaks → Hold Actions): each hold action
         can be turned off, giving the plugin's own hold back (built-ins
         flash their name, custom shortcuts open their edit dialog). New:
         hold a custom shortcut that toggles SSH to open Bluetooth from
         the Kobo plugin (OGKevin/kobo.koplugin): Turn Bluetooth On / Off,
         Scan For Devices, Paired Devices. Without the Kobo plugin the
         shortcut's edit dialog opens as before. A Wi-Fi / SSH change
         redraws the toolbar once, with every changed icon, instead of once
         per icon. Bluetooth notes: the Kobo
         plugin's Bluetooth messages ("Scanning for Bluetooth devices...",
         "Bluetooth enabled", "Failed to connect to ...") show in Network
         Tweaks' style (Banner / Minimal) like its Wi-Fi notes; with Normal,
         or without Network Tweaks, they stay as they are. No setting.
  1.14.3 Follow Bluetooth: falls back to the Kobo plugin's D-Bus helper
         when the plugin itself isn't found (still greyed out on device
         with 1.14.2). Tells diagnostics where Bluetooth was found.
  1.14.2 Fix: Follow Bluetooth was always greyed out. KOReader names the
         Kobo plugin after its folder, not its internal name, so it
         wasn't found; it's now found whatever the folder is called.
  1.14.1 Fix: tapping a Menu Action shortcut in the library's top menu left
         that menu stuck on screen until a restart (the toolbar plugin
         opened a second copy to run it). It now runs in the open menu and
         closes it, like the reader toolbar. New indicator: Follow
         Bluetooth (Kobo plugin), works with its Toggle / Enable / Disable
         Bluetooth system actions. Menu toggle option renamed "Follow Menu
         Toggle (Menu Action Shortcuts)" so it's clear why it's greyed out
         on other shortcuts.
  1.14.0 New indicator: Follow Menu Toggle. For a custom shortcut set to a
         menu action, the icon follows that menu item's ✓ (e.g. Bluetooth
         Enable/Disable from the Kobo plugin). Read once per toolbar open;
         after a tap from a bar that stays open (library bar, home screen)
         it re-checks until the ✓ changes. Greyed out for system-action
         and open-a-menu shortcuts.
  1.13.0 The reader and library top menus close when the device goes to
         sleep, so they're not still open on wake (or in a sleep screen
         that shows the current page).
  1.12.2 Title case for all user-facing menu/item labels ("Reset All Icon
         Tweaks", "Night Mode", "Power Off", ...). First letter of each
         word only; SimpleUI/X-Ray/Wi-Fi/SSH-style names untouched.
  1.12.1 Trimmed: the one-time 1.6 settings migration is gone (it has run;
         old per-view entries are still read as a fallback). Modules used
         on every redraw/event are looked up once at load instead of each
         time. Small duplicates removed. No behaviour change.
  1.12.0 Reader toolbar opens ~110 ms faster after the first time: the
         book cover thumbnail is kept for the open book instead of being
         extracted and shrunk on every menu open (measured: 120-130 ms
         builds, 90% of it the cover). Re-done when the book or its custom
         cover changes.
  1.11.3 No timer left pending over sleep: the Wi-Fi-off event sent while
         going to sleep is synced once on wake instead (diagnostics
         flagged one 0.3s check scheduled while asleep).
  1.11.2 Fewer redraws (from on-device diagnostics): network events that
         arrive together are repainted once. With Network Tweaks
         installed, SSH / Calibre icons rely on its announcements alone:
         no catch-up checks after a tap and no 1.5s follow-up repaint. An
         SSH toggle went from 3 redraws to 1.
  1.11.1 Audit fixes: nothing is built for a button whose layout isn't
         recognised; a network repaint no longer replaces a pending SSH /
         Calibre catch-up check while a popup covers the toolbar; two
         KOReader/plugin lookups guarded so an error can't break a tap.
  1.11.0 Holding the built-in Search button (reader) opens the same power
         options as Restart. Tap still searches.
  1.10.0 Hold actions: built-in Wi-Fi opens the network list (Network
         Tweaks 1.6.0's "Choose network" when installed, else KOReader's
         own), built-in Restart opens Restart / Exit KOReader / Reboot /
         Power off. Custom shortcuts still open their edit dialog on hold.
  1.9.2  Merged with the 1.8.x fixes. Icons only redraw while their toolbar
         is on screen (a closed reader menu costs nothing; the 1.9.1
         fallback redrew the current page instead). A toolbar covered by a
         popup or dialog (e.g. "SSH server started") redraws its changed
         icons once when it closes. Button screen: asked from KOReader,
         falling back to the screen it was first drawn on. Toggle night
         mode also keeps the toolbar open. "Keep toolbar open" option
         removed: always on.
  1.9.1  Fix: an indicator could miss its update when a note or banner
         (e.g. Network Tweaks' "SSH on") was on screen: the repaint went to
         the note instead of the toolbar, and catch-up timers stopped
         early. Repaints now target the window that holds the button.
  1.9.0  SSH and Calibre indicators update the moment they change when
         Network Tweaks 1.4.0+ is installed (it announces the change).
         Calibre wireless connect / disconnect shortcuts keep the toolbar
         open too.
  1.8.0  Custom shortcuts set to Toggle SSH server / Toggle Wi-Fi / Turn
         Wi-Fi on / Turn Wi-Fi off no longer close the toolbar.
  1.7.0  Toolbar Wi-Fi icon and Wi-Fi/SSH/Calibre indicators follow network
         events instead of guessing on tap: correct after a background
         connect, a failed or cancelled connect, auto-disconnect and sleep.
         Wi-Fi shows as on while a connection is in progress. Wi-Fi no
         longer uses the tap catch-up timers.
  1.6.0  Custom shortcuts merged: one menu entry each, tweaks apply in
         reader, library and home. Grouped by action, not name. Existing
         per-view settings move over automatically (library copy wins if
         they differed).
  1.5.4  Fix crash on tapping a tweaked icon: the swapped/main image could
         have no size info (when the off icon was drawn, or tapped before
         first paint), and IconButton's tap highlight needs it.
  1.5.3  Tap-toggle name lookup cached per toolbar build (was per redraw);
         failed state reads no longer count as "on"; header updated.
  1.5.2  Catch-up timers: one per button, cancelled on re-tap, stop as soon
         as state changes; only for Wi-Fi/SSH/Calibre.
  1.5.1  Old off-state icon freed on rebuild; comment on invert handling.
  1.5.0  Calibre connection indicator.
  1.4.0  SSH server indicator; tap toggle synced across reader/library;
         custom shortcuts labelled by view in the menu.
  1.3.0  Tap toggle indicator for custom shortcuts. Fix: built-in icons
         weren't matched, so only custom icons got tweaks.
  1.2.1  Safer button matching (icon + size + spacing, stops on mismatch);
         image slot found instead of assumed.
  1.2.0  On/off styles: inverted when off / inverted when on.
  1.1.0  On/off indicator (Wi-Fi, frontlight, night mode): dim or alternate
         off icon. Fix: Keep original / Inverted no longer draw a white tile.
  1.0.0  Custom icons per shortcut, global and per-icon colour modes.
--]]

local Device = require("device")
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")
local userpatch = require("userpatch")

local PATCH_VERSION = "1.17.0"
local SETTINGS_KEY = "shortcutstoolbar_icon_tweaks"
local MODES = {
    { id = "default",  text = "Default (Follow UI)" },
    { id = "original", text = "Keep Original Colours" },
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

-- The window a repaint should go to: the topmost real screen, skipping
-- toasts (notifications, banners) and invisible helpers. A toast on top
-- would otherwise get the repaint instead of the toolbar underneath it.
local function screenWindow()
    local stack = UIManager._window_stack
    if type(stack) == "table" then
        for i = #stack, 1, -1 do
            local w = stack[i].widget
            if w and not w.invisible and not w.toast then return w end
        end
        return nil
    end
    return UIManager.getTopmostVisibleWidget and UIManager:getTopmostVisibleWidget()
end

-- Each tracked button remembers the screen it belongs to (the one showing
-- when it was first drawn: a toolbar is always built, then shown on top).
-- It only gets redrawn while that screen is the one showing: a closed
-- reader menu, or a toolbar under a dialog, costs nothing.
local function trackScreen(btn)
    if btn._stb_tracks_screen then return end
    btn._stb_tracks_screen = true
    local base = btn.paintTo
    btn.paintTo = function(self, ...)
        if not self._stb_win then self._stb_win = screenWindow() end
        return base(self, ...)
    end
end

-- The screen holding this button: asked from KOReader first (exact), else
-- the screen it was first drawn on.
local function homeWindow(btn)
    if UIManager.isSubwidgetShown then
        local ok, matched, _depth, w = pcall(UIManager.isSubwidgetShown, UIManager, btn)
        if ok and matched and w then return w end
    end
    return btn._stb_win
end

-- Returns the button's screen if it's the one showing. Second value is
-- true when that screen has closed for good (a reader menu that was
-- dismissed): the button is gone and can be forgotten. A reopened toolbar
-- is built fresh, so nothing is lost.
local function visibleWindow(btn)
    if not btn.dimen then return nil end
    local first = btn._stb_win
    if first and UIManager.isWidgetShown then
        local ok, shown = pcall(UIManager.isWidgetShown, UIManager, first)
        if ok and not shown then return nil, true end
    end
    local win = homeWindow(btn)
    if win and win == screenWindow() then return win end
    return nil
end

-- Buttons whose state changed while something covered them (e.g. the SSH
-- "server started" popup). Closing that popup only refreshes the popup's
-- own area, so the icon would stay stale: they redraw once their screen is
-- showing again. Weak keys: a toolbar that's gone just drops out.
local waiting = setmetatable({}, { __mode = "k" })

local function resumeWaiting()
    for btn, fn in pairs(waiting) do
        local win, gone = visibleWindow(btn)
        if gone then
            waiting[btn] = nil
        elseif win then
            waiting[btn] = nil
            fn()
        end
    end
end

local close_hooked = false
local function hookClose()
    if close_hooked then return end
    close_hooked = true
    local orig_close = UIManager.close
    UIManager.close = function(self, ...)
        local res = orig_close(self, ...)
        if next(waiting) then UIManager:nextTick(resumeWaiting) end
        return res
    end
end

local function waitForScreen(btn, fn)
    hookClose()
    waiting[btn] = fn
end

-- --------------------------------------------------------------------------
-- State sources (for on/off indicators)
-- --------------------------------------------------------------------------

-- Wi-Fi counts as on while a connection is in progress (background
-- connects take a few seconds), matching what the tap asked for.
-- Network Tweaks announces SSH and Calibre changes the moment they happen
-- (NetworkTweaksStateChanged), so with it installed no guessing is needed.
local function networkTweaksActive()
    return require("ui/network/manager").__network_tweaks == true
end

local function wifiOn()
    local NetworkMgr = require("ui/network/manager")
    return NetworkMgr:isWifiOn() or NetworkMgr.pending_connection == true
end

local STATES = {
    { id = "wifi", text = "Wi-Fi", get = wifiOn },
    { id = "frontlight", text = "Frontlight", get = function()
        if not Device:hasFrontlight() then return true end
        return Device:getPowerDevice():isFrontlightOn()
    end },
    { id = "night_mode", text = "Night Mode", get = function()
        return Device.screen.night_mode or G_reader_settings:isTrue("night_mode")
    end },
    -- Same check KOReader's own SSH menu uses for its checkmark.
    { id = "ssh", text = "SSH Server", get = function()
        return lfs.attributes("/tmp/dropbear_koreader.pid", "mode") == "file"
    end },
    -- Calibre plugin's wireless client: its socket exists only while
    -- connected (it's cleared on disconnect or a failed connect).
    { id = "calibre", text = "Calibre Connection", get = function()
        local W = package.loaded["wireless"]
        return type(W) == "table" and W.calibre_socket ~= nil
    end },
}

-- One identity per shortcut across views.
-- Built-ins already use the same key everywhere. Custom shortcuts get a
-- different internal key in the reader and the library, so they're grouped
-- by what they DO: patch id, system action, menu action, then name.
local group_cache = {}  -- cleared on every toolbar build / menu open

local function groupId(key)
    if type(key) ~= "string" or key:sub(1, 3) ~= "cs_" then return key end
    if group_cache[key] then return group_cache[key] end
    local id = key
    local ok_m, Manager = pcall(require, "custom_shortcut_manager")
    if ok_m then
        for _i, view in ipairs({ "fb", "reader" }) do
            local ok_f, sc = pcall(Manager.find, key, view)
            if ok_f and sc then
                if sc.id and sc.id ~= "" then
                    id = "id:" .. sc.id
                elseif sc.dispatcher_action and sc.dispatcher_action ~= "" then
                    id = "act:" .. sc.dispatcher_action
                elseif type(sc.path_record) == "table" and sc.path_record.display_label then
                    id = "menu:" .. sc.path_record.display_label
                else
                    id = "name:" .. tostring(sc.name or key)
                end
                break
            end
        end
    end
    group_cache[key] = id
    return id
end

-- Settings for a toolbar key: shared group first; an old per-view entry
-- (e.g. from a backup made before 1.6) still works as a fallback.
local function keySettings(s, key)
    return s.keys[groupId(key)] or s.keys[key]
end

local function getToggled(key)
    local t = (G_reader_settings:readSetting(SETTINGS_KEY) or {}).toggles
    return t and t[groupId(key)] == true
end
-- Not a real device state: flips each time the icon is tapped and is
-- remembered across restarts. For custom shortcuts that toggle something
-- KOReader can't report on.
table.insert(STATES, 1, { id = "tap", text = "Tap Toggle", get = getToggled })

-- Menu toggle: a custom shortcut set to a menu action points at a menu
-- item; this reads that item's own ✓ (checked_func), the same way the
-- plugin's replay finds it: tab, then sub-menus, then the item, matched by
-- id, then text, then position.
local function shortcutFor(key)
    local ok_m, Manager = pcall(require, "custom_shortcut_manager")
    if not ok_m then return nil end
    for _i, view in ipairs({ "fb", "reader" }) do
        local ok_f, sc = pcall(Manager.find, key, view)
        if ok_f and sc then return sc end
    end
    return nil
end

-- A shortcut that runs a menu item (not one that just opens a sub-menu).
local function menuLeaf(sc)
    local pr = type(sc) == "table" and sc.path_record
    if type(pr) ~= "table" or pr.is_menu or type(pr.item) ~= "table" then return nil end
    if sc.dispatcher_action and sc.dispatcher_action ~= "" then return nil end
    return pr
end

local function itemText(item)
    local t = item.text
    if type(t) == "function" then t = t() end
    if not t and item.text_func then t = item.text_func() end
    return type(t) == "string" and t or ""
end

local function findMenuItem(tbl, id, index, text)
    if type(tbl) ~= "table" then return nil end
    if id then
        for _i, item in ipairs(tbl) do
            if item.menu_item_id == id then return item end
        end
    end
    if text then
        local want = text:lower()
        for _i, item in ipairs(tbl) do
            local ok, t = pcall(itemText, item)
            if ok and t:lower() == want then return item end
        end
    end
    return index and tbl[index] or nil
end

-- The live menu tabs for a view. Only the menu that exists right now: a
-- reader shortcut can't be read from the library and the other way round.
local function menuTabs(view)
    local RUI = package.loaded["apps/reader/readerui"]
    local FM = package.loaded["apps/filemanager/filemanager"]
    local reader = RUI and RUI.instance and not RUI.instance.tearing_down and RUI.instance
    local fm = FM and FM.instance and not FM.instance.tearing_down and FM.instance
    local app
    if view == "reader" then app = reader
    elseif view == "fb" then app = fm
    else app = reader or fm end -- old shortcuts without a view
    local m = app and app.menu
    if not m then return nil end
    -- The library menu builds its tabs the first time it's opened; a bar
    -- shown before that builds them here, once (same as opening the menu).
    if m.tab_item_table == nil and type(m.setUpdateItemTable) == "function" then
        pcall(m.setUpdateItemTable, m)
    end
    return m.tab_item_table
end

local function readMenuToggle(key)
    local pr = menuLeaf(shortcutFor(key))
    if not pr then return nil end
    local tabs = menuTabs(pr.view)
    local tbl = tabs and tabs[pr.tab_index or 1]
    for _i, step in ipairs(pr.nav_path or {}) do
        local item = findMenuItem(tbl, step.id, step.index, step.text)
        if not item then return nil end
        tbl = (item.sub_item_table_func and item.sub_item_table_func()) or item.sub_item_table
    end
    local leaf = findMenuItem(tbl, pr.item.id, pr.item.index, pr.item.text)
    if not leaf then return nil end
    if type(leaf.checked_func) == "function" then return leaf.checked_func() and true or false end
    if leaf.checked ~= nil then return leaf.checked and true or false end
    return nil
end

-- Some ✓s ask the system (Bluetooth runs a D-Bus query), so each one is
-- read once per toolbar build and reused for its redraws. Unknown (menu
-- not built, item gone, no ✓) shows as on.
-- Bluetooth, from the Kobo plugin (OGKevin/kobo.koplugin): the same check
-- its own menu ✓ uses. Works whatever the shortcut runs (its Toggle /
-- Enable / Disable Bluetooth system actions, or the menu item).
-- KOReader names a plugin after its folder (kobo.koplugin -> ui.kobo), so
-- it's found by what it carries rather than by name; whatever the folder is
-- called. The name it was found under is remembered for next time.
local bt_name
local function btOf(p)
    local bt = type(p) == "table" and rawget(p, "kobo_bluetooth")
    if type(bt) == "table" and type(bt.isBluetoothEnabled) == "function" then return bt end
    return nil
end
-- Fallback: the plugin's own D-Bus helper (the same check, without going
-- through the plugin instance).
local dbus_bt = { isBluetoothEnabled = function()
    return package.loaded["src/lib/bluetooth/dbus_adapter"].isEnabled()
end }

-- Returns the Bluetooth checker and where it was found (for diagnostics).
local function koboBluetooth()
    for _i, path in ipairs({ "apps/reader/readerui", "apps/filemanager/filemanager" }) do
        local mod = package.loaded[path]
        local ui = mod and mod.instance
        if type(ui) == "table" and not ui.tearing_down then
            local bt = bt_name and btOf(rawget(ui, bt_name))
            if bt then return bt, "plugin ui." .. bt_name end
            for k, v in pairs(ui) do
                bt = type(k) == "string" and btOf(v)
                if bt then bt_name = k; return bt, "plugin ui." .. k end
            end
        end
    end
    local da = package.loaded["src/lib/bluetooth/dbus_adapter"]
    if type(da) == "table" and type(da.isEnabled) == "function" then
        return dbus_bt, "dbus_adapter module"
    end
    return nil, "not found"
end

local function readBluetooth()
    local bt = koboBluetooth()
    if not bt then return nil end
    return bt:isBluetoothEnabled() and true or false
end

-- Both ask the system (Bluetooth runs a D-Bus query each time), so each is
-- read once per toolbar build and reused for its redraws. Unknown (plugin
-- missing, menu not built, item gone, no ✓) shows as on.
-- Reads go through this table so the diagnostics patch can time them
-- (shared as home_content.__stb_state_reads).
local state_reads = { menu = readMenuToggle, bluetooth = readBluetooth,
    bluetooth_source = function() return select(2, koboBluetooth()) end }
local read_cache = {}  -- "id|key" -> { v = true|false|nil }; cleared on every toolbar build
local function cachedRead(id)
    return function(key)
        local ck = id .. "|" .. tostring(key)
        local c = read_cache[ck]
        if not c then
            local ok, v = pcall(state_reads[id], key)
            c = {}
            if ok then c.v = v end
            read_cache[ck] = c
        end
        return c.v ~= false
    end
end
local function forgetRead(id, key) read_cache[id .. "|" .. tostring(key)] = nil end

table.insert(STATES, 2, { id = "menu", text = "Menu Toggle", get = cachedRead("menu") })
table.insert(STATES, { id = "bluetooth", text = "Bluetooth", get = cachedRead("bluetooth") })

local STATE_BY_ID = {}
for _, st in ipairs(STATES) do STATE_BY_ID[st.id] = st end

-- --------------------------------------------------------------------------
-- Rendering
-- --------------------------------------------------------------------------

local function fileExists(f)
    if not f then return false end
    return lfs.attributes(f, "mode") == "file"
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
        local night = Device.screen.night_mode and true or false
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
        if src ~= self then
            -- The off icon was drawn instead; keep our own geometry current
            -- so IconButton's tap highlight has something to invert.
            local Geom = require("ui/geometry")
            self.dimen = self.dimen or Geom:new{}
            self.dimen.x, self.dimen.y, self.dimen.w, self.dimen.h = x, y, sz.w, sz.h
        end
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
    local k = keySettings(s, key) or {}
    local mode = k.mode or s.mode
    local state = k.state and STATE_BY_ID[k.state]
    local custom = fileExists(k.file) and k.file or nil
    if not custom and mode == "default" and not state then return end

    local file = custom or (btn.image and btn.image.file)
    if not file then return end

    -- Find where the image sits first, so nothing is built (or the current
    -- off icon freed) if the button's layout isn't what we expect.
    local old = btn.image
    local hg = btn.horizontal_group
    local slot
    if hg then
        for i = 1, #hg do
            if hg[i] == old then slot = i; break end
        end
    end
    if not slot then return end -- unexpected layout: leave button untouched

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

    btn.image = img
    hg[slot] = img
    btn:update()
    if not img.dimen then
        local Geom = require("ui/geometry")
        local sz = img:getSize()
        img.dimen = Geom:new{ x = 0, y = 0, w = sz.w, h = sz.h }
    end
    if old and old ~= img and old.free then pcall(old.free, old) end
end

-- After a tap, re-draw a few times so async state catches up. Only for
-- states with no event to follow (starting a server, Calibre connecting).
-- Wi-Fi follows network events instead (see below). Tap toggle repaints
-- instantly; night mode repaints the whole screen; frontlight changes
-- through its own dialog.
-- Menu toggles are included: a bar that stays open (library bar, home
-- screen) re-reads the ✓ after the tap. The reader toolbar closes when a
-- menu action runs, so its chain stops at the first check.
local ASYNC_STATES = { calibre = true, ssh = true, menu = true, bluetooth = true }
local CACHED = { menu = true, bluetooth = true } -- re-read fresh on each catch-up
local ANNOUNCED = { calibre = true, ssh = true } -- by Network Tweaks, when installed
local REFRESH_STEPS = { 1, 3, 6, 10 } -- seconds after the tap

local function addStateRefresh(btn, key)
    local cb = btn.callback
    if not cb then return end
    btn.callback = function(...)
        local s = loadSettings()
        local k = keySettings(s, key)
        if k and k.state == "tap" then
            local id = groupId(key)
            s.toggles = s.toggles or {}
            s.toggles[id] = (not s.toggles[id]) or nil
            saveSettings(s)
            local top = visibleWindow(btn) or screenWindow()
            if top and btn.dimen then UIManager:setDirty(top, "ui", btn.dimen) end
        end
        local state = k and STATE_BY_ID[k.state]
        local async = state and ASYNC_STATES[state.id]
            and not (ANNOUNCED[state.id] and networkTweaksActive())
        local before
        if async then
            local ok, v = pcall(state.get, key)
            before = ok and (v and true or false) or nil
        end
        cb(...)
        if not async then return end

        -- One catch-up timer per button, never stacked: a new tap cancels
        -- the previous chain. The chain stops as soon as the state actually
        -- changes or the screen changes, so usually it's 1-2 wake-ups.
        if btn._stb_refresh then UIManager:unschedule(btn._stb_refresh) end
        waiting[btn] = nil
        local step = 0
        local function tick()
            -- Covered (popup, dialog) or closed: no timers, no redraws.
            -- Picks up again when its screen is showing.
            local win, gone = visibleWindow(btn)
            if not win then
                btn._stb_refresh = nil
                if not gone then waitForScreen(btn, tick) end
                return
            end
            step = step + 1
            if CACHED[state.id] then forgetRead(state.id, key) end
            local ok, now = pcall(state.get, key)
            local changed = ok and before ~= nil and (now and true or false) ~= before
            if changed or step >= #REFRESH_STEPS then
                UIManager:setDirty(win, "ui", btn.dimen)
                btn._stb_refresh = nil
                return
            end
            UIManager:scheduleIn(REFRESH_STEPS[step + 1] - REFRESH_STEPS[step], tick)
        end
        btn._stb_refresh = tick
        UIManager:scheduleIn(REFRESH_STEPS[1], tick)
    end
end

-- --------------------------------------------------------------------------
-- Network sync
-- --------------------------------------------------------------------------
-- The plugin flips its Wi-Fi icon on tap and never looks again, so it goes
-- wrong whenever Wi-Fi changes on its own (background connect, failure,
-- cancel, auto-disconnect, sleep). Buttons that show network-driven state
-- are tracked here and re-synced on KOReader's network events.

local NET_STATES = { wifi = true, ssh = true, calibre = true }
local NET_EVENTS = {
    onNetworkConnecting = true,
    onNetworkConnected = true,
    onNetworkDisconnected = true,
    onNetworkTweaksStateChanged = true, -- SSH / Calibre, from Network Tweaks 1.4.0+
}
local FOLLOW_UP_S = 1.5 -- SSH/Calibre react to a connect a moment later

-- btn -> key. Weak keys: buttons from discarded toolbars just drop out.
local live = setmetatable({}, { __mode = "k" })

local function syncLive()
    if next(live) == nil then return end
    local s = loadSettings()
    local want_wifi = wifiOn() and "wifi" or "wifi.open.0"
    -- One screen update per toolbar: the changed icons' areas combined, so a
    -- Wi-Fi change with SSH and Calibre indicators asks once, not three times.
    local per_win, order = {}, {}
    for btn, key in pairs(live) do
        local dirty = false
        if key == "wifi" and btn.icon ~= want_wifi and btn.setIcon then
            -- Wrapped in withCapture, so tweaks are re-applied.
            pcall(btn.setIcon, btn, want_wifi)
            dirty = true
        end
        local k = keySettings(s, key)
        if k and k.state and NET_STATES[k.state] then dirty = true end
        -- State above is always updated (cheap); the screen is only
        -- touched when this toolbar is actually showing.
        if dirty then
            local win, gone = visibleWindow(btn)
            if gone then
                live[btn] = nil
            elseif win then
                local area = per_win[win]
                if not area then
                    order[#order + 1] = win
                    per_win[win] = btn.dimen and btn.dimen:copy() or false
                elseif area and btn.dimen then
                    per_win[win] = area:combine(btn.dimen)
                else
                    per_win[win] = false -- an icon with no size yet: the whole toolbar
                end
            elseif btn._stb_win and not waiting[btn] then
                waitForScreen(btn, function()
                    local w = visibleWindow(btn)
                    if w then UIManager:setDirty(w, "ui", btn.dimen) end
                end)
            end
        end
    end
    for _i, win in ipairs(order) do
        UIManager:setDirty(win, "ui", per_win[win] or nil)
    end
end

-- Coalesced: events arriving close together (Wi-Fi off, then SSH off a
-- moment later) wait for the last one and repaint once. Without Network
-- Tweaks there's also one follow-up for things that start after a connect;
-- with it, those changes are announced and need no follow-up.
local SETTLE_S = 0.3

-- Going to sleep turns Wi-Fi off, which sends a disconnect event. Nothing
-- can be seen while asleep, so no timer is left pending across sleep: the
-- sync is noted and done once on wake instead.
local sync_on_wake = false

local function scheduleSync(on_wake)
    if next(live) == nil then return end
    if not on_wake and Device.screen_saver_mode then
        sync_on_wake = true
        return
    end
    UIManager:unschedule(syncLive)
    UIManager:scheduleIn(SETTLE_S, syncLive)
    if not networkTweaksActive() then
        UIManager:scheduleIn(FOLLOW_UP_S, syncLive)
    end
end

local net_hooked = false
local function hookNetworkEvents()
    if net_hooked then return end
    net_hooked = true

    local orig_bc = UIManager.broadcastEvent
    UIManager.broadcastEvent = function(self, event, ...)
        local res = orig_bc(self, event, ...)
        local handler = type(event) == "table" and event.handler
        if handler and NET_EVENTS[handler] then
            scheduleSync()
        elseif handler == "onResume" and sync_on_wake then
            sync_on_wake = false
            scheduleSync(true)
        end
        return res
    end

    -- A failed connect sends no event (it was never connected).
    local NetworkMgr = require("ui/network/manager")
    local orig_abort = NetworkMgr._abortWifiConnection
    if type(orig_abort) == "function" then
        NetworkMgr._abortWifiConnection = function(self, ...)
            orig_abort(self, ...)
            scheduleSync()
        end
    end
end

-- --------------------------------------------------------------------------
-- Hold actions for built-in buttons
-- --------------------------------------------------------------------------
-- The plugin's built-in buttons only flash their name on hold. Wi-Fi and
-- Restart get something useful instead. Custom shortcuts keep their hold
-- (it opens their edit dialog).

-- Hold Wi-Fi: the network list. Uses Network Tweaks' picker (1.6.0+) when
-- installed, else KOReader's own long-press flow.
local function holdWifi()
    local NetworkMgr = require("ui/network/manager")
    local choose = NetworkMgr.__network_tweaks_choose_network
    if type(choose) == "function" then
        choose()
    elseif not NetworkMgr:isWifiOn() then
        NetworkMgr:toggleWifiOn(nil, true, true)
    elseif NetworkMgr.reconnectOrShowNetworkMenu then
        NetworkMgr:reconnectOrShowNetworkMenu(nil, true)
    end
end

-- Hold Restart: power options. Same events KOReader's gestures use, so the
-- book and settings are saved; reboot / power off ask to confirm.
local function holdPower()
    local _ = require("gettext")
    local Event = require("ui/event")
    local ButtonDialog = require("ui/widget/buttondialog")

    local dialog
    local function action(text, event)
        return { text = text, callback = function()
            UIManager:close(dialog)
            UIManager:broadcastEvent(Event:new(event))
        end }
    end

    local buttons = {}
    if Device:canRestart() then
        table.insert(buttons, { action(_("Restart KOReader"), "Restart") })
    end
    table.insert(buttons, { action(_("Exit KOReader"), "Exit") })
    local device_row = {}
    if Device:canReboot() then table.insert(device_row, action(_("Reboot"), "RequestReboot")) end
    if Device:canPowerOff() then table.insert(device_row, action(_("Power Off"), "RequestPowerOff")) end
    if #device_row > 0 then table.insert(buttons, device_row) end
    table.insert(buttons, { { text = _("Cancel"), callback = function() UIManager:close(dialog) end } })

    dialog = ButtonDialog:new{ title = _("Power"), title_align = "center", buttons = buttons }
    UIManager:show(dialog)
end

-- Hold an SSH shortcut: Bluetooth, from the Kobo plugin (OGKevin/kobo.koplugin),
-- the same actions as its own menu. Returns false when the plugin isn't
-- there, so the shortcut's own hold (its edit dialog) runs instead.
local function holdBluetooth()
    local bt = koboBluetooth()
    if type(bt) ~= "table" or type(bt.toggleBluetooth) ~= "function"
            or type(bt.scanAndShowDevices) ~= "function" then
        return false
    end
    if type(bt.isDeviceSupported) == "function" then
        local ok_s, sup = pcall(bt.isDeviceSupported, bt)
        if ok_s and not sup then return false end
    end
    local _ = require("gettext")
    local ButtonDialog = require("ui/widget/buttondialog")
    local ok_e, on = pcall(bt.isBluetoothEnabled, bt)
    on = ok_e and on and true or false
    local dialog
    local function action(text, fn, enabled)
        return { text = text, enabled = enabled ~= false, callback = function()
            UIManager:close(dialog)
            pcall(fn)
        end }
    end
    local buttons = {
        { action(on and _("Turn Bluetooth Off") or _("Turn Bluetooth On"), function() bt:toggleBluetooth(true) end) },
        { action(_("Scan For Devices"), function() bt:scanAndShowDevices() end, on),
          action(_("Paired Devices"), function() bt:showPairedDevices() end,
              on and type(bt.showPairedDevices) == "function") },
        { { text = _("Cancel"), callback = function() UIManager:close(dialog) end } },
    }
    dialog = ButtonDialog:new{ title = _("Bluetooth"), title_align = "center", buttons = buttons }
    UIManager:show(dialog)
end

-- Hold a Calibre shortcut: open BookOrbit directly, no menu. The plugin
-- instance comes from PluginLoader (canonical, by name); the UI scan is the
-- fallback, same pattern as the Kobo Bluetooth lookup. Returns false when
-- the BookOrbit plugin isn't there, so the shortcut's own hold (its edit
-- dialog) runs instead.
local function findBookOrbit()
    local ok_pl, PluginLoader = pcall(require, "pluginloader")
    if ok_pl and type(PluginLoader) == "table"
            and type(PluginLoader.getPluginInstance) == "function" then
        local ok, bo = pcall(PluginLoader.getPluginInstance, PluginLoader, "bookorbit")
        if ok and type(bo) == "table" and type(bo.openBookOrbit) == "function" then
            return bo
        end
    end
    for _i, path in ipairs({ "apps/reader/readerui", "apps/filemanager/filemanager" }) do
        local mod = package.loaded[path]
        local ui = mod and mod.instance
        if type(ui) == "table" and not ui.tearing_down then
            for k, v in pairs(ui) do
                if type(v) == "table" and type(v.openBookOrbit) == "function" then
                    return v
                end
            end
        end
    end
    return nil
end

local function holdBookOrbit()
    local bo = findBookOrbit()
    if type(bo) ~= "table" then return false end
    local ok = pcall(bo.openBookOrbit, bo)
    if not ok then return false end
    return true
end

-- --------------------------------------------------------------------------
-- Bluetooth notes in Network Tweaks' style
-- --------------------------------------------------------------------------
-- The Kobo plugin shows its Bluetooth messages as plain popups that close by
-- themselves (scanning, enabled / disabled, failed to connect...). Those are
-- handed to Network Tweaks' shared note instead, so they look like its Wi-Fi
-- notes. Its style decides: Normal (or no Network Tweaks) leaves the popup as
-- it is. Only the plugin's Bluetooth files, and only messages with a timeout
-- (anything it closes itself, or that asks something, stays a popup).
local function fromKoboBluetooth()
    -- the caller, past other patches' wrappers of UIManager.show (this one
    -- is installed first, so it sits under all of them)
    for level = 3, 16 do
        local info = debug.getinfo(level, "S")
        if not info then return false end
        local src = info.source or ""
        if src:find(".koplugin/src/lib/bluetooth/", 1, true) or src:find(".koplugin/src/kobo_bluetooth.lua", 1, true) then
            return true
        end
    end
    return false
end
do
    local orig_show = UIManager.show
    UIManager.show = function(self, w, ...)
        if type(w) == "table" and type(w.text) == "string" and type(w.timeout) == "number"
                and not w.toast and w.ok_callback == nil and w.buttons == nil
                and fromKoboBluetooth() then
            local NM = package.loaded["ui/network/manager"]
            local fn = type(NM) == "table" and NM.__network_tweaks_note
            if type(fn) == "function" then
                local ok, handled = pcall(fn, w.text, nil, w.timeout)
                if ok and handled then return end
            end
        end
        return orig_show(self, w, ...)
    end
end

-- Hold actions by id; each has its own on/off (Hold Actions menu, on by default).
local HOLD = {
    wifi    = holdWifi,
    restart = holdPower,
    search  = holdPower, -- reader search button: tap searches, hold = power
    ssh     = holdBluetooth,
    bookorbit = holdBookOrbit,
    bookshelf_bookorbit = holdBookOrbit,
}
local HOLD_BUILTIN = { wifi = "wifi", restart = "restart", search = "search" }

local function holdOn(id)
    local h = loadSettings().hold
    return not (type(h) == "table" and h[id] == false)
end

-- Per-hold tap/hold swap: each hold action can be flipped on its own.
local function flipOn(id)
    local f = loadSettings().flip
    return type(f) == "table" and f[id] == true
end

-- The hold action for a toolbar key, if it has one and it's on.
local function holdFor(key)
    local id = HOLD_BUILTIN[key]
    if not id and type(key) == "string" and key:sub(1, 3) == "cs_" then
        local sc = shortcutFor(key)
        if type(sc) == "table" then
            if sc.dispatcher_action == "toggle_ssh_server" then id = "ssh"
            elseif sc.dispatcher_action == "calibre_start_connection"
                    or sc.dispatcher_action == "calibre_close_connection" then
                id = "bookorbit"
            elseif sc.dispatcher_action == "bookshelf_go_home" then
                id = "bookshelf_bookorbit"
            end
        end
    end
    if id and holdOn(id) then return id end
    return nil
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
    local Screen = Device.screen
    local icon_size = Screen:scaleBySize(config.icon_size or 32)
    local padding_h = Screen:scaleBySize(config.spacing or 8)
    local queue = expectedKeys(config)
    local desynced = false
    group_cache = {} -- pick up edited shortcuts
    read_cache = {}  -- and menu toggles / Bluetooth changed since the last build
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
        local k = keySettings(settings, key)
        if k and k.state then addStateRefresh(btn, key) end
        local hid = holdFor(key)
        if hid then
            -- the plugin's own hold stays as the fallback (e.g. no Kobo plugin)
            local own_hold, fn = btn.hold_callback, HOLD[hid]
            if flipOn(hid) then
                -- flipped: tap runs the hold action, hold runs the button's
                -- normal tap (with its state refresh, as wrapped above).
                -- A hold action that declines (no plugin) falls back to the
                -- normal tap, same as the unflipped hold fallback.
                local own_tap = btn.callback
                btn.hold_callback = function(...)
                    if own_tap then return own_tap(...) end
                    if own_hold then return own_hold(...) end
                end
                btn.callback = function(...)
                    if fn() == false and own_tap then return own_tap(...) end
                end
            else
                btn.hold_callback = function(...)
                    if fn() == false and own_hold then return own_hold(...) end
                end
            end
        end
        -- Wi-Fi toggles rebuild the image via setIcon(); re-apply after.
        local orig_set = btn.setIcon
        btn.setIcon = function(self, icon)
            orig_set(self, icon)
            tweakButton(self, key)
        end
        if key == "wifi" or (k and k.state) then trackScreen(btn) end
        if key == "wifi" or (k and k.state and NET_STATES[k.state]) then
            live[btn] = key
            hookNetworkEvents()
        end
    end
    return res
end

-- --------------------------------------------------------------------------
-- Keep the toolbar open for toggle shortcuts
-- --------------------------------------------------------------------------
-- The plugin closes the menu before running a custom shortcut's system
-- action, because sendEvent stops at the top widget (the menu). For these
-- toggles a broadcast reaches the handler (SSH plugin, network listener,
-- Calibre plugin, device listener) even with the menu open, so the toolbar
-- stays put, like the built-in Wi-Fi icon, and you see the icon change.
-- Anything else still closes the toolbar as before.
local STAY_OPEN = {
    toggle_ssh_server        = "ToggleSSHServer",
    toggle_wifi              = "ToggleWifi",
    wifi_on                  = "InfoWifiOn",
    wifi_off                 = "InfoWifiOff",
    calibre_start_connection = "StartWirelessConnection",
    calibre_close_connection = "CloseWirelessConnection",
    night_mode               = "ToggleNightMode",
}

-- The library's menu manager, when `menu` is its top menu showing right now
-- (not the persistent bar or the SimpleUI home module).
local function liveLibraryMenu(menu)
    local FM = package.loaded["apps/filemanager/filemanager"]
    local fmm = FM and FM.instance and not FM.instance.tearing_down and FM.instance.menu
    local mc = type(fmm) == "table" and fmm.menu_container
    if type(mc) == "table" and menu ~= nil and mc[1] == menu then return fmm end
    return nil
end

local function hookExecute()
    local ok, Manager = pcall(require, "custom_shortcut_manager")
    if not ok or type(Manager) ~= "table" or Manager.__stb_stay_open then return end
    if type(Manager.execute) ~= "function" or type(Manager.getActionSource) ~= "function" then return end
    Manager.__stb_stay_open = true

    local orig_execute = Manager.execute
    Manager.execute = function(shortcut, menu, ...)
        local ev = type(shortcut) == "table" and STAY_OPEN[shortcut.dispatcher_action]
        local ok_src, src = false, nil
        if ev then ok_src, src = pcall(Manager.getActionSource, shortcut) end
        if ok_src and src == "system" then
            local Event = require("ui/event")
            UIManager:broadcastEvent(Event:new(ev))
            return true
        end
        -- Menu actions tapped in the library's own top menu: the plugin
        -- opens a second copy of that menu to run them, and the first copy
        -- can't be closed any more (its close button points at the second;
        -- only a restart clears it). Run them in the menu that's already
        -- open instead, the way the reader toolbar does.
        local fmm = type(shortcut) == "table" and type(shortcut.path_record) == "table"
            and shortcut.path_record.view == "fb" and liveLibraryMenu(menu)
        if fmm then
            local ok_m, s = pcall(Manager.getActionSource, shortcut)
            if ok_m and s == "menu" then
                local own = rawget(fmm, "onShowMenu")
                fmm.onShowMenu = function() end -- the menu is already showing
                local res = { pcall(orig_execute, shortcut, menu, ...) }
                fmm.onShowMenu = own -- nil puts the class method back
                if not res[1] then error(res[2], 0) end
                return unpack(res, 2)
            end
        end
        return orig_execute(shortcut, menu, ...)
    end
end

-- --------------------------------------------------------------------------
-- Book cover cache for the reader toolbar
-- --------------------------------------------------------------------------
-- The plugin's book info panel pulls the cover out of the book and shrinks
-- it to thumbnail size on every reader-menu open: ~60 ms + ~50 ms on a
-- Clara Colour, 90% of the build. The thumbnail is kept for the open book
-- instead, so only the first open pays. Re-done when the book or its custom
-- cover changes. One thumbnail in memory (a few tens of KB).
-- Fails safe: if the plugin's panel changes shape, it's left alone.

local cover_cache = { key = nil, bb = nil }

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

local function coverKey(ui)
    local file = ui.document and ui.document.file
    if not file then return nil end
    local custom
    local ok_ds, DocSettings = pcall(require, "docsettings")
    if ok_ds and DocSettings.findCustomCoverFile then
        local ok, path = pcall(DocSettings.findCustomCoverFile, DocSettings, file)
        if ok and path then
            custom = path .. "@" .. tostring(lfs.attributes(path, "modification"))
        end
    end
    return file .. "|" .. (custom or "")
end

local function hookCoverCache(plugin_home)
    local _bi, book_fn = findUpvalue(plugin_home, "createBookInfoPanel")
    local ci, orig_cover = findUpvalue(book_fn, "buildCoverWidget")
    if not ci then return end
    local _w, cover_w = findUpvalue(orig_cover, "COVER_W")
    local _h, cover_h = findUpvalue(orig_cover, "COVER_H")
    if type(cover_w) ~= "number" or type(cover_h) ~= "number" then return end

    debug.setupvalue(book_fn, ci, function(ui)
        local ok_k, key = pcall(coverKey, ui)
        if not (ok_k and key) then return orig_cover(ui) end

        if cover_cache.key ~= key then
            if cover_cache.bb then pcall(cover_cache.bb.free, cover_cache.bb) end
            cover_cache.key, cover_cache.bb = key, nil
            local ok, thumb = pcall(function() return ui.bookinfo:getCoverImage(ui.document) end)
            if ok and thumb then
                -- Same sizing as the plugin.
                local w, h = thumb:getWidth(), thumb:getHeight()
                local scale = math.min(cover_w / w, cover_h / h)
                w = math.min(math.floor(w * scale) + 1, cover_w)
                h = math.min(math.floor(h * scale) + 1, cover_h)
                local ok_s, bb = pcall(function()
                    return require("ui/renderimage"):scaleBlitBuffer(thumb, w, h, true)
                end)
                if ok_s and bb then cover_cache.bb = bb end
            end
        end

        local bb = cover_cache.bb
        if not bb then return nil end -- book has no cover (also remembered)
        local Blitbuffer = require("ffi/blitbuffer")
        local FrameContainer = require("ui/widget/container/framecontainer")
        local ImageWidget = require("ui/widget/imagewidget")
        local Size = require("ui/size")
        return FrameContainer:new{
            bordersize = Size.border.thin,
            color      = Blitbuffer.COLOR_LIGHT_GRAY,
            padding    = 0,
            -- The cache owns the bitmap: the menu must not free it on close.
            ImageWidget:new{ image = bb, image_disposable = false,
                             width = bb:getWidth(), height = bb:getHeight() },
        }
    end)
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
    HomeContent.__stb_state_reads = state_reads

    local orig_home = HomeContent.createHomeContent
    pcall(hookCoverCache, orig_home)
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
        for _i, view in ipairs({ "fb", "reader" }) do
            for _j, it in ipairs(Manager.getShortcutDataItems(view)) do
                local gid = groupId(it.key)
                if not seen[gid] then
                    seen[gid] = true
                    table.insert(items, { key = gid, label = it.label or it.key })
                end
            end
        end
    end
    return items
end

local function pickIcon(on_pick)
    local DataStorage = require("datastorage")
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

-- True when the menu entry's group (a "menu:..." group key) is a custom
-- shortcut that runs a menu item, so Follow Menu Toggle makes sense.
local function groupIsMenuLeaf(gkey)
    if type(gkey) ~= "string" or gkey:sub(1, 5) ~= "menu:" then return false end
    local ok_m, Manager = pcall(require, "custom_shortcut_manager")
    if not ok_m then return false end
    for _i, view in ipairs({ "fb", "reader" }) do
        local ok_l, items = pcall(Manager.getShortcutDataItems, view)
        for _j, it in ipairs(ok_l and items or {}) do
            if groupId(it.key) == gkey and menuLeaf(shortcutFor(it.key)) then return true end
        end
    end
    return false
end

local function perIconMenu(key)
    local _ = require("gettext")
    local T = require("ffi/util").template
    local menu_leaf = groupIsMenuLeaf(key)
    local function getK() local s = loadSettings(); return s, s.keys[key] or {} end
    local function putK(s, k)
        if next(k) == nil then s.keys[key] = nil else s.keys[key] = k end
        saveSettings(s); refreshViews()
    end

    local colour = {
        {
            text = _("Use Global Setting"),
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
                return k.file and T(_("Icon: %1"), k.file:match("[^/]+$")) or _("Icon: Original")
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
            text = _("Restore Original Icon"),
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
                return T(_("Colour: %1"), k.mode and modeText(k.mode) or _("Global"))
            end,
            sub_item_table = colour,
            separator = true,
        },
        {
            text_func = function()
                local _s, k = getK()
                local st = k.state and STATE_BY_ID[k.state]
                return T(_("On/Off Indicator: %1"), st and st.text or _("Off"))
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
                        text = (st.id == "tap" and _("Tap Toggle (Flips On Each Tap)"))
                            or (st.id == "menu" and _("Follow Menu Toggle (Menu Action Shortcuts)"))
                            or T(_("Follow %1"), st.text),
                        radio = true,
                        -- Menu toggle: only shortcuts that run a menu item.
                        -- Bluetooth: only with the Kobo plugin installed.
                        enabled_func = (st.id == "menu" and function() return menu_leaf end)
                            or (st.id == "bluetooth" and function() return koboBluetooth() ~= nil end)
                            or nil,
                        checked_func = function() local _s, k = getK(); return k.state == st.id end,
                        callback = function() local s, k = getK(); k.state = st.id; putK(s, k) end,
                    })
                end
                table.insert(t, {
                    text = _("Reset Tap Toggle To Off"),
                    enabled_func = function() local _s, k = getK(); return k.state == "tap" and getToggled(key) end,
                    keep_menu_open = true,
                    callback = function(touchmenu)
                        local s = loadSettings()
                        if s.toggles then s.toggles[groupId(key)] = nil end
                        saveSettings(s); refreshViews()
                        if touchmenu then touchmenu:updateItems() end
                    end,
                })
                t[#t].separator = true
                local function curStyle(k) return k.off_style or (k.off_file and "icon") or "dim" end
                local styles = {
                    { id = "dim",        text = _("Dim When Off") },
                    { id = "invert_off", text = _("Inverted When Off") },
                    { id = "invert_on",  text = _("Inverted When On") },
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
                        return k.off_file and T(_("Custom Icon When Off: %1"), k.off_file:match("[^/]+$"))
                            or _("Custom Icon When Off…")
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
    local ConfirmBox = require("ui/widget/confirmbox")
    return {
        text = _("Icon Tweaks"),
        sub_item_table_func = function()
            local t = {
                {
                    text_func = function()
                        return _("Global Colour: ") .. modeText(loadSettings().mode)
                    end,
                    sub_item_table = modeRadio(
                        function() return loadSettings().mode end,
                        function(id) local s = loadSettings(); s.mode = id; saveSettings(s); refreshViews() end),
                    separator = true,
                },
            }
            group_cache = {}
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
            local function holdItem(text, id, help)
                return {
                    text = text, help_text = help, keep_menu_open = true,
                    checked_func = function() return holdOn(id) end,
                    callback = function()
                        local s2 = loadSettings()
                        s2.hold = type(s2.hold) == "table" and s2.hold or {}
                        if holdOn(id) then s2.hold[id] = false else s2.hold[id] = nil end
                        if next(s2.hold) == nil then s2.hold = nil end
                        saveSettings(s2)
                        refreshViews()
                    end,
                }
            end
            -- Each hold action is its own group: on/off, plus its own
            -- tap/hold flip. A flip only matters while its hold is on.
            -- The group row ticks when its hold is on.
            local function holdGroup(text, id, help)
                return {
                    text = text,
                    checked_func = function() return holdOn(id) end,
                    sub_item_table = {
                        holdItem(_("Enabled"), id, help),
                        {
                            text = _("Flip Tap And Hold"),
                            help_text = _("Swap tap and hold for this action: tap runs the hold action, hold runs the button's normal tap. Off restores tap and hold as usual. No effect while the hold action is off."),
                            keep_menu_open = true,
                            checked_func = function() return flipOn(id) end,
                            callback = function()
                                local s2 = loadSettings()
                                s2.flip = type(s2.flip) == "table" and s2.flip or {}
                                if flipOn(id) then s2.flip[id] = nil else s2.flip[id] = true end
                                if next(s2.flip) == nil then s2.flip = nil end
                                saveSettings(s2)
                                refreshViews()
                            end,
                        },
                    },
                }
            end
            table.insert(t, {
                text = _("Hold Actions"),
                separator = true,
                sub_item_table = {
                    holdGroup(_("Hold Wi-Fi: Network List"), "wifi",
                        _("Hold the built-in Wi-Fi button for the network list. Off gives the plugin's own hold back.")),
                    holdGroup(_("Hold Restart: Power Options"), "restart",
                        _("Hold the built-in Restart button for Restart / Exit / Reboot / Power Off. Off gives the plugin's own hold back.")),
                    holdGroup(_("Hold Search: Power Options"), "search",
                        _("Hold the built-in Search button (reader) for the power options. Tap still searches. Off gives the plugin's own hold back.")),
                    holdGroup(_("Hold SSH Shortcut: Bluetooth"), "ssh",
                        _("Hold a custom shortcut that toggles SSH for Bluetooth from the Kobo plugin: turn it on or off, scan, paired devices. Without the Kobo plugin, or with this off, holding opens the shortcut's edit dialog.")),
                    holdGroup(_("Hold Calibre Shortcut: BookOrbit"), "bookorbit",
                        _("Hold a custom shortcut that connects to Calibre for BookOrbit: opens BookOrbit directly, no menu. Without the BookOrbit plugin, or with this off, holding opens the shortcut's edit dialog.")),
                    holdGroup(_("Hold Bookshelf Shortcut: BookOrbit"), "bookshelf_bookorbit",
                        _("Hold a custom shortcut that goes to the Bookshelf home screen for BookOrbit: opens BookOrbit directly, no menu. Without the BookOrbit plugin, or with this off, holding opens the shortcut's edit dialog.")),
                },
            })
            table.insert(t, {
                text = _("Reset All Icon Tweaks"),
                callback = function()
                    UIManager:show(ConfirmBox:new{
                        text = _("Reset All Icon And Colour Tweaks?"),
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
-- Close the top menus on sleep
-- --------------------------------------------------------------------------
-- KOReader draws the sleep screen first and only then sends "Suspend", so
-- the menus are closed when the sleep screen is set up: the redraw that
-- follows shows the page (or library) without them, and that's what's there
-- on wake. Any open TouchMenu (reader / library top menu) is closed through
-- its own close callback, the same as tapping outside it.

-- A TouchMenu or anything built on it: same closeMenu method, or the class
-- somewhere up its metatable chain.
local function isTouchMenu(w, TouchMenu)
    if type(w) ~= "table" then return false end
    if w.closeMenu ~= nil and w.closeMenu == TouchMenu.closeMenu then return true end
    local mt = getmetatable(w)
    while type(mt) == "table" do
        if mt == TouchMenu then return true end
        local nxt = getmetatable(mt)
        if not nxt and type(mt.__index) == "table" and mt.__index ~= mt then nxt = mt.__index end
        mt = nxt
    end
    return false
end

local function closeMenusForSleep()
    local ok, TouchMenu = pcall(require, "ui/widget/touchmenu")
    local stack = UIManager._window_stack
    if not ok or type(stack) ~= "table" then return end
    local menus = {}
    for i = #stack, 1, -1 do
        local inner = stack[i].widget and stack[i].widget[1]
        if isTouchMenu(inner, TouchMenu) and type(inner.closeMenu) == "function" then
            menus[#menus + 1] = inner
        end
    end
    for _i, m in ipairs(menus) do pcall(m.closeMenu, m) end
end

local function hookSleep()
    local ok, Screensaver = pcall(require, "ui/screensaver")
    if not ok or type(Screensaver) ~= "table" or type(Screensaver.setup) ~= "function"
            or Screensaver.__stb_close_menus then return end
    Screensaver.__stb_close_menus = true
    local orig_setup = Screensaver.setup
    Screensaver.setup = function(...)
        pcall(closeMenusForSleep)
        return orig_setup(...)
    end
end

-- --------------------------------------------------------------------------
-- Entry point
-- --------------------------------------------------------------------------

require("logger").info("shortcutstoolbar icon tweaks v" .. PATCH_VERSION)

userpatch.registerPatchPluginFunc("shortcutstoolbar", function(plugin)
    hookHomeContent()
    hookExecute()
    hookSleep()
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
