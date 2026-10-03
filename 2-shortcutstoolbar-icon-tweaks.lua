--[[
Shortcuts Toolbar – Icon Tweaks (userpatch)
===========================================
Version: 1.10.0
For xusoo/shortcutstoolbar.koplugin

Adds  Shortcuts toolbar → Icon tweaks  to the plugin menu:
  • Swap any toolbar icon (built-in or custom) for your own SVG/PNG,
    or put it back to the plugin's original.
  • Colour mode, globally or per icon:
      Default          – plugin behaviour (icons follow night mode)
      Keep original    – icons keep their true colours, even in night mode
      Inverted         – icon colours flipped relative to the UI
    (no background tile – only the icon pixels are flipped)
  • Optional on/off indicator per icon. Follows Wi-Fi, frontlight, night
    mode, SSH server, Calibre connection, or a remembered tap toggle.
    Off/on styles: dim when off, inverted tile when off or when on, or an
    alternate "off" icon.
  • The toolbar Wi-Fi icon, and any Wi-Fi/SSH/Calibre indicator, follow
    the real network state: connecting in the background, failing,
    cancelling, auto-disconnect and sleep all update them.
  • Custom shortcuts for SSH, Wi-Fi, Calibre connect/disconnect and night
    mode toggles keep the toolbar open when tapped (like the built-in Wi-Fi
    button), so you see the icon change. Other actions still close it.
  • Hold the built-in Wi-Fi button: network list (Network Tweaks' picker
    when installed). Hold the built-in Restart button: Restart / Exit
    KOReader, Reboot, Power off. Tap does what it always did.

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
(stops as soon as the state changes). Nothing runs in the background or
while asleep.

Changelog
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

local userpatch = require("userpatch")

local PATCH_VERSION = "1.10.0"
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

-- The window a repaint should go to: the topmost real screen, skipping
-- toasts (notifications, banners) and invisible helpers. A toast on top
-- would otherwise get the repaint instead of the toolbar underneath it.
local function screenWindow()
    local UIManager = require("ui/uimanager")
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
    local UIManager = require("ui/uimanager")
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
    local UIManager = require("ui/uimanager")
    local first = btn._stb_win
    if first and UIManager.isWidgetShown and not UIManager:isWidgetShown(first) then
        return nil, true
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
    local UIManager = require("ui/uimanager")
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
local function wifiOn()
    local NetworkMgr = require("ui/network/manager")
    return NetworkMgr:isWifiOn() or NetworkMgr.pending_connection == true
end

local STATES = {
    { id = "wifi", text = "Wi-Fi", get = wifiOn },
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
local toggleId = groupId

-- Settings for a toolbar key: shared group first, old per-view entry second.
local function keySettings(s, key)
    return s.keys[groupId(key)] or s.keys[key]
end

-- One-time move of pre-1.6 per-view entries onto shared groups. If the
-- reader and library copies differed, the library copy wins.
local migrated = false
local function migrate()
    if migrated then return end
    local ok_m, Manager = pcall(require, "custom_shortcut_manager")
    if not ok_m then return end
    migrated = true
    local s = loadSettings()
    local changed = false
    if s.stay_open ~= nil then s.stay_open = nil; changed = true end -- 1.8.0 option, removed
    for _i, view in ipairs({ "fb", "reader" }) do
        for _j, it in ipairs(Manager.getShortcutDataItems(view)) do
            local gid = groupId(it.key)
            if gid ~= it.key and s.keys[it.key] then
                if not s.keys[gid] then s.keys[gid] = s.keys[it.key] end
                s.keys[it.key] = nil
                changed = true
            end
            local old = s.toggles and s.toggles["label:" .. tostring(it.label)]
            if old then
                s.toggles[gid] = true
                changed = true
            end
        end
    end
    if s.toggles then
        for id in pairs(s.toggles) do
            if id:sub(1, 6) == "label:" or id:sub(1, 4) == "key:" then
                s.toggles[id] = nil
                changed = true
            end
        end
    end
    if changed then saveSettings(s) end
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
local ASYNC_STATES = { calibre = true, ssh = true }
local REFRESH_STEPS = { 1, 3, 6, 10 } -- seconds after the tap

local function addStateRefresh(btn, key)
    local UIManager = require("ui/uimanager")
    local cb = btn.callback
    if not cb then return end
    btn.callback = function(...)
        local top = visibleWindow(btn) or screenWindow()
        local s = loadSettings()
        local k = keySettings(s, key)
        if k and k.state == "tap" then
            local id = toggleId(key)
            s.toggles = s.toggles or {}
            s.toggles[id] = (not s.toggles[id]) or nil
            saveSettings(s)
            if top and btn.dimen then UIManager:setDirty(top, "ui", btn.dimen) end
        end
        local state = k and STATE_BY_ID[k.state]
        local async = state and ASYNC_STATES[state.id]
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
    local UIManager = require("ui/uimanager")
    local s = loadSettings()
    local want_wifi = wifiOn() and "wifi" or "wifi.open.0"
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
                UIManager:setDirty(win, "ui", btn.dimen)
            elseif btn._stb_win then
                waitForScreen(btn, function()
                    local w = visibleWindow(btn)
                    if w then UIManager:setDirty(w, "ui", btn.dimen) end
                end)
            end
        end
    end
end

-- Coalesced: a burst of events (connecting → connected) is one repaint,
-- plus one follow-up for things that start after the connect.
local function scheduleSync()
    if next(live) == nil then return end
    local UIManager = require("ui/uimanager")
    UIManager:unschedule(syncLive)
    UIManager:nextTick(syncLive)
    UIManager:scheduleIn(FOLLOW_UP_S, syncLive)
end

local net_hooked = false
local function hookNetworkEvents()
    if net_hooked then return end
    net_hooked = true

    local UIManager = require("ui/uimanager")
    local orig_bc = UIManager.broadcastEvent
    UIManager.broadcastEvent = function(self, event, ...)
        local res = orig_bc(self, event, ...)
        if type(event) == "table" and NET_EVENTS[event.handler] then scheduleSync() end
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
    local Device = require("device")
    local Event = require("ui/event")
    local UIManager = require("ui/uimanager")
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
    if Device:canPowerOff() then table.insert(device_row, action(_("Power off"), "RequestPowerOff")) end
    if #device_row > 0 then table.insert(buttons, device_row) end
    table.insert(buttons, { { text = _("Cancel"), callback = function() UIManager:close(dialog) end } })

    dialog = ButtonDialog:new{ title = _("Power"), title_align = "center", buttons = buttons }
    UIManager:show(dialog)
end

local HOLD = { wifi = holdWifi, restart = holdPower }

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
    group_cache = {} -- pick up edited shortcuts
    migrate()
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
        if HOLD[key] then btn.hold_callback = HOLD[key] end
        -- Wi-Fi toggles rebuild the image via setIcon(); re-apply after.
        local orig_set = btn.setIcon
        btn.setIcon = function(self, icon)
            orig_set(self, icon)
            tweakButton(self, key)
        end
        if k and k.state then trackScreen(btn) end
        if key == "wifi" or (k and k.state and NET_STATES[k.state]) then
            trackScreen(btn)
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

local function hookExecute()
    local ok, Manager = pcall(require, "custom_shortcut_manager")
    if not ok or type(Manager) ~= "table" or Manager.__stb_stay_open then return end
    if type(Manager.execute) ~= "function" or type(Manager.getActionSource) ~= "function" then return end
    Manager.__stb_stay_open = true

    local orig_execute = Manager.execute
    Manager.execute = function(shortcut, menu, ...)
        local ev = type(shortcut) == "table" and STAY_OPEN[shortcut.dispatcher_action]
        if ev and Manager.getActionSource(shortcut) == "system" then
            local UIManager = require("ui/uimanager")
            local Event = require("ui/event")
            UIManager:broadcastEvent(Event:new(ev))
            return true
        end
        return orig_execute(shortcut, menu, ...)
    end
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
            group_cache = {}
            migrate()
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

require("logger").info("shortcutstoolbar icon tweaks v" .. PATCH_VERSION)

userpatch.registerPatchPluginFunc("shortcutstoolbar", function(plugin)
    hookHomeContent()
    hookExecute()
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
