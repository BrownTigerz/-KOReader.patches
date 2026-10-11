--[[
    Direct X-Ray Lookup patch for ultimatejimmy/xray.koplugin
    https://github.com/ultimatejimmy/xray.koplugin

    Version: 1.1.5 (2026-10-11) - See CHANGELOG below.

    Versioning (for future updates to this file):
      1.0.x - fixes (e.g. adapting to an xray.koplugin internal rename)
      1.x.0 - new features
      2.0.0 - anything that changes how existing on-disk caches/backups work

    What it does:
    When the toggle is ON and you select a single word, the patch checks
    X-Ray's already-fetched entity data for that word (no AI call, no scan).
    If X-Ray knows the word, the dictionary popup is skipped and X-Ray opens
    straight away - the detail view on a single match, or the multiple-matches
    picker. If X-Ray has no data for the word, the standard dictionary popup
    opens exactly as usual (with its X-Ray button still there for a manual
    fetch). While X-Ray is open from a lookup, a small "Dictionary" button sits
    bottom-right; tapping it closes X-Ray and re-opens the standard word
    popup for the same word.

    Toggle: bind "Toggle direct X-Ray lookup" in Gesture Manager (Settings >
    Taps and Gestures > Gesture Manager), and/or the "Direct X-Ray lookup"
    checkbox at the top of the X-Ray menu. The toggle persists across
    restarts (default off). It only reroutes when X-Ray mode itself is
    enabled for the book.

    This REPLACES 2-xray-entity-footnotes.lua and
    2-zz-entity-footnotes-diagnostics.lua - delete those two files. On first
    run this patch removes the old patch's settings keys and deletes its
    per-book on-disk entity cache (xray_entity_cache.cache) as books are
    opened. If you had the old "Toggle entity footnote underlines" gesture
    bound, rebind it to the new action name (the old one no longer exists).

    This patch does not modify xray.koplugin at all. It hooks the plugin's
    class table via userpatch.registerPatchPluginFunc and wraps
    ReaderHighlight:lookupDictWord (word popup) and onShowHighlightMenu
    (standard highlight menu, only when opened by a single-word long-press)
    from the outside. The actual lookup is X-Ray's own LookupManager:handleLookup -
    the same code path as the "X-Ray" button in the word popup - so matching,
    disambiguation and detail views behave exactly like the manual flow.

    ===================================================================
    CHANGELOG
    ===================================================================
    1.1.5 (2026-10-11)
      - NEW: status notifications (toggle on/off, button position) now go
        through the shared notification contract v1: Network Tweaks' style
        if installed, else ReadMastery notify's style if installed, else
        the existing Notification widget. Never over the sleep screen.
    1.1.4 (2026-10-11)
      - FIX: tapping the Dictionary button crashed KOReader ("attempt to
        index a nil value" in UIManager:sendEvent). The button is a toast,
        so the tap keeps dispatching to the windows below it while the
        callback ran: closing the button and X-Ray's windows synchronously
        shrank UIManager._window_stack in the middle of sendEvent's walk
        and it indexed a nil slot. The teardown now runs on the next tick,
        after dispatch finishes. (The 0.2s deferred popup from 1.1.2 is
        unchanged.)
      - FIX: after picking an entry from the multiple-matches picker, the
        Dictionary button kept the picker's lifted/offset position in the
        detail view. When a detail view opens, the button now moves back to
        the plain bottom-right corner, lined up - the position offset only
        ever applies to the picker. (The word selection captured for the
        Dictionary popup is preserved across the move, not re-captured.)
    1.1.3 (2026-10-10) - The on/off state is now also saved to KOReader's global
            settings (key xray_direct_lookup) so the QuickMenu toggle-state
            patch can show "(On)/(Off)" next to the gesture entry.
    1.1.2 (2026-10-10) - FIX: the "Dictionary" button closed X-Ray but the dictionary
            popup never appeared (the same tap dismissed it again). The popup
            is now opened a moment after the tap, the selection is restored
            if it was cleared, and any failure is written to the log.
    1.1.1 (2026-10-10) - FIX: sometimes the long-press was never finished (KOReader's
            long-hold icon showed top-left, the word stayed selected and
            nothing happened until you tapped again): the finger-lift event was
            not delivered. Now, with the toggle on, a single selected word
            that X-Ray knows is looked up if no release arrives within 1
            second of the hold. The late release (if it ever comes) is
            swallowed so it can't trigger a second lookup. Unknown words and
            multi-word selections are untouched.
    1.1.0 (2026-10-10) - NEW: "Direct X-Ray lookup" is now a submenu at the top of
            the X-Ray menu: Enabled checkbox, "Dictionary button position
            (picker)..." and Reset. The position tool closes the menu and
            shows a live preview of the button over the real page with
            Up / Down / Left / Right nudges (step 5/10/25/50 px). The offset
            applies ONLY to the multiple-matches picker; the single-match
            detail view keeps the fixed corner position. Offsets persist.
    1.0.8 (2026-10-10) - The Dictionary button now has the same solid framed
            look as X-Ray's picker dialog (opaque background, window border,
            rounded corners, standard font size) so it is easy to see over
            page text. Previously: small bare button.
    1.0.7 (2026-10-10) - The button now says "Dictionary" and returns to the
            dictionary word popup (not the highlight menu), from both paths.
    1.0.6 (2026-10-10) - Overlay is now ONE small "Highlight menu" button (the
            Menu/Back pair is gone: tapping outside already closes X-Ray).
            It closes X-Ray and opens the standard highlight menu (Highlight /
            Dictionary / X-Ray ...) for the same word, from both the long-press
            and word-popup paths. When X-Ray shows the multiple-matches
            picker the button sits higher so it clears the status bar; for a
            single match (detail view) it stays in the bottom corner.
    1.0.5 (2026-10-10) - FIX: with several matches the picker could not be
            tapped - the Back overlay was a normal top window and swallowed
            every tap. It is now a "toast" (receives taps, never blocks the
            window underneath, stays on top of windows opened later). NEW:
            a small "Menu" button next to Back opens the X-Ray main (quick)
            menu. Widget tracking now ignores the overlay itself.
    1.0.4 (2026-10-10) - FIX: the Back button stayed on screen after dismissing
            X-Ray by tapping outside it. It now goes away as soon as the last
            tracked X-Ray window closes (picker -> detail transitions keep
            it), and the leftover word selection is cleared.
    1.0.3 (2026-10-10) - FIX: reroute silently did nothing for the book KOReader
            reopens at startup (its X-Ray instance was created before this
            patch hooked init, so it was never tracked). The instance is now
            also found via ui.xray and adopted lazily, which also runs the
            first-run cleanup and widget tracking for it.
    1.0.2 (2026-10-10) - Diagnostics: every word select now logs why it was
            or wasn't rerouted (toggle state, instance found, settings
            source). Menu checkbox now logs + shows the on/off notification
            like the gesture does.
    1.0.1 (2026-10-10) - FIX: the reroute never fired when the standard
            highlight menu (Highlight / Dictionary / X-Ray ...) was the
            long-press result, which is the default ("ask") setup. The patch
            only hooked lookupDictWord (the word-popup path). It now also
            hooks onHoldRelease/onShowHighlightMenu: a single-word long-press
            skips the highlight menu and goes straight to X-Ray. Back button
            restores whichever menu you skipped. Multi-word / drag
            selections and taps on existing highlights are untouched.
    1.0.0 (2026-10-10) - First release. Replaces the Entity Footnotes patch
            with a direct-lookup design: no full-book scan, no underlines,
            no paint overlay, no entity cache. Reroutes single-word selections
            to X-Ray when data exists, standard popup otherwise.
--]]

local PATCH_VERSION = "1.1.5"

local ok_userpatch, userpatch = pcall(require, "userpatch")
if not ok_userpatch or not userpatch or not userpatch.registerPatchPluginFunc then
    local ok_lb, lb = pcall(require, "logger")
    if ok_lb then lb.warn("xray-direct-lookup: userpatch API not available, skipping") end
    return
end

local logger = require("logger")
local function log(msg)
    logger.info("DirectXRay: " .. tostring(msg))
end

local UIManager = require("ui/uimanager")
local Screen = require("device").screen
local Geom = require("ui/geometry")
local Button = require("ui/widget/button")
local FrameContainer = require("ui/widget/container/framecontainer")
local Blitbuffer = require("ffi/blitbuffer")
local Size = require("ui/size")
local DocSettings = require("docsettings")

log("v" .. PATCH_VERSION .. " loading")

-- The single-word selection path. Drag selections (multi-word) go through
-- onShowHighlightMenu instead and are never touched by this patch.
local ok_rh, ReaderHighlight = pcall(require, "apps/reader/modules/readerhighlight")
if not ok_rh or type(ReaderHighlight) ~= "table"
        or type(ReaderHighlight.lookupDictWord) ~= "function" then
    log("ReaderHighlight.lookupDictWord not found - patch disabled")
    return
end
local orig_lookupDictWord = ReaderHighlight.lookupDictWord
local orig_onHold = ReaderHighlight.onHold
local orig_onHoldRelease = ReaderHighlight.onHoldRelease
local orig_onShowHighlightMenu = ReaderHighlight.onShowHighlightMenu

local M = {}

local SETTING_KEY = "xray_direct_lookup"
local OFFSET_X_KEY = "xray_direct_picker_dx"
local OFFSET_Y_KEY = "xray_direct_picker_dy"
local CLEANUP_FLAG = "xray_direct_lookup_cleanup_v1"

-- Settings keys owned by the old Entity Footnotes patch. X-Ray's own keys
-- (unit_underline_*, xray_mode_enabled, spoiler_setting, ...) are untouched.
local OLD_SETTING_KEYS = {
    "entity_footnotes_enabled",
    "entity_cat_characters",
    "entity_cat_historical_figures",
    "entity_cat_locations",
    "entity_cat_terms",
    "entity_tooltip_timeout",
    "entity_exclude_terms",
}
local OLD_CACHE_NAMES = {
    "/xray_entity_cache.cache",
    "/xray_entity_cache.cache.tmp",
}

local function _settings(self)
    return (self.ai_helper and self.ai_helper.settings) or {}
end

-- Copy of the toggle in KOReader's global settings, so other patches (e.g.
-- the QuickMenu On/Off labels) can read the state without touching X-Ray.
local function _mirrorToggle(val)
    pcall(function() G_reader_settings:saveSetting(SETTING_KEY, val and true or false) end)
end

local function _toggleOn(self)
    return _settings(self)[SETTING_KEY] == true
end

-- Shared notification contract v1: user-facing status notes resolve style
-- in priority order - Network Tweaks' style if installed, ReadMastery's if
-- installed, otherwise the caller's own default. Checks run at call time,
-- so patch load order does not matter. Never over the sleep screen.
local function shared_note(banner_text, minimal_text, timeout)
    local Device = require("device")
    if Device.screen_saver_mode then return true end -- never over the sleep screen
    local NetworkMgr = require("ui/network/manager")
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

-- ---- X-Ray instance tracking -------------------------------------------
-- lookup_manager lives on the per-book plugin instance (created in init),
-- not on the class table, so the highlight wrapper needs the live instance.
local _xray_instances = {}
local _adopt -- forward declaration, defined below

local function _findXRayInstance(hl)
    local hl_ui = hl and hl.ui
    -- Instances created before this patch hooked init are never in the list;
    -- the plugin is always reachable as ui.xray.
    local direct = hl_ui and hl_ui.xray
    if type(direct) == "table" and direct.lookup_manager and not direct.destroyed then
        _adopt(direct)
        return direct
    end
    for i = #_xray_instances, 1, -1 do
        local inst = _xray_instances[i]
        if inst.destroyed then
            table.remove(_xray_instances, i)
        elseif hl_ui and inst.ui == hl_ui then
            return inst
        end
    end
    for i = #_xray_instances, 1, -1 do
        if not _xray_instances[i].destroyed then
            return _xray_instances[i]
        end
    end
    return nil
end

-- ---- Back-button + tracked X-Ray widgets -------------------------------
local _xray_widgets = {}
local _back_button = nil
local _back_button_picker = false
-- The selection as it was when the button was first shown for this lookup.
-- Kept across the picker->detail reposition: re-capturing there could grab
-- a selection that X-Ray's own taps already cleared.
local _back_saved_sel = nil

-- Topmost real window: skips invisible widgets and toasts (our own overlay).
local function _topWidget()
    local ok, w = pcall(function()
        local stack = UIManager._window_stack
        for i = #stack, 1, -1 do
            local cand = stack[i].widget
            if cand and not cand.invisible and not cand.toast then return cand end
        end
    end)
    return ok and w or nil
end

local _isShown
local _back_xray = nil
local _back_hl = nil
local _back_button_close_and_clear

_isShown = function(w)
    local ok, found = pcall(function()
        for _, win in ipairs(UIManager._window_stack) do
            if win.widget == w then return true end
        end
        return false
    end)
    return ok and found
end

local function _trackXRayWidget(w)
    if not w or w == _back_button then return end
    for _, e in ipairs(_xray_widgets) do
        if e == w then return end
    end
    if #_xray_widgets < 10 then
        table.insert(_xray_widgets, w)
        -- When any tracked window closes (tap outside, close button, picker
        -- -> detail), re-check on the next tick whether any is still open;
        -- if none is, X-Ray is gone and the Back button must go with it.
        local prev = w.onCloseWidget
        w.onCloseWidget = function(self_w, ...)
            local r
            if prev then r = prev(self_w, ...) end
            UIManager:nextTick(function()
                if not _back_button then return end
                for _, e in ipairs(_xray_widgets) do
                    if _isShown(e) then return end
                end
                log("x-ray dismissed - removing back button")
                local hl = _back_hl
                _back_button_close_and_clear(hl)
            end)
            return r
        end
    end
end

local function _closeBackButton()
    if _back_button then
        pcall(function() UIManager:close(_back_button) end)
        _back_button = nil
    end
    _back_button_picker = false
end

_back_button_close_and_clear = function(hl)
    if _back_button then
        pcall(function() UIManager:close(_back_button) end)
        _back_button = nil
    end
    _back_button_picker = false
    _xray_widgets = {}
    _back_hl = nil
    _back_xray = nil
    _back_saved_sel = nil
    if hl then pcall(function() hl:clear() end) end
end

local function _closeTrackedWidgets()
    for i = #_xray_widgets, 1, -1 do
        pcall(function() UIManager:close(_xray_widgets[i]) end)
    end
    _xray_widgets = {}
end

-- Reroute decision. Only logs when the toggle is on - with it off, every
-- word tap is a silent passthrough and shouldn't spam the log.
local function _shouldReroute(xray, word)
    if not _toggleOn(xray) then return false end
    if not xray.xray_mode_enabled then
        log("passthrough '" .. word:sub(1, 40) .. "' (xray mode off)")
        return false
    end
    local lm = xray.lookup_manager
    if not lm then
        log("passthrough '" .. word:sub(1, 40) .. "' (no lookup_manager)")
        return false
    end
    local t0 = os.clock()
    local ok, results = pcall(function() return lm:lookupAll(word) end)
    local dt_ms = math.floor((os.clock() - t0) * 1000)
    if not ok or not results then
        log("passthrough '" .. word:sub(1, 40) .. "' (lookupAll error)")
        return false
    end
    if #results == 0 then
        log("passthrough '" .. word:sub(1, 40) .. "' (no xray data, " .. dt_ms .. "ms)")
        return false
    end
    return true, #results, dt_ms
end

-- Return to the standard dictionary word popup for the same word,
-- whichever path the lookup came from.
local function _restoreMenu(hl, saved_sel)
    -- Closing X-Ray / the tap itself can clear the selection; put it back.
    if not hl.selected_text and saved_sel then
        log("selection was cleared, restoring it")
        hl.selected_text = saved_sel
    end
    log("restoring dictionary popup for '" .. tostring(hl.selected_text and hl.selected_text.text or "?"):sub(1, 40) .. "'")
    orig_lookupDictWord(hl)
end

-- The framed "Dictionary" button: opaque, bordered, rounded like X-Ray's
-- picker dialog.
local function _buildDictButton(callback)
    local btn = Button:new{
        text = "Dictionary",
        bordersize = 0,
        margin = 0,
        callback = callback,
    }
    return FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = Size.border.window,
        radius = Size.radius.window,
        padding = 0,
        margin = 0,
        btn,
    }
end

-- Bottom-right corner. For the multiple-matches picker the default is lifted
-- clear of the status bar and the user's saved X/Y offset is added (right and
-- down are positive). The single-match detail view never uses the offset.
local function _buttonPos(og, picker, xray)
    local sw, sh = Screen:getWidth(), Screen:getHeight()
    local margin = Screen:scaleBySize(12)
    local bs = og:getSize()
    local x = sw - bs.w - margin
    local y = sh - bs.h - margin
    if picker then
        local st = _settings(xray)
        y = y - Screen:scaleBySize(44)
        x = x + (tonumber(st[OFFSET_X_KEY]) or 0)
        y = y + (tonumber(st[OFFSET_Y_KEY]) or 0)
    end
    x = math.max(0, math.min(sw - bs.w, x))
    y = math.max(0, math.min(sh - bs.h, y))
    return x, y, bs
end

local function _showBackButton(hl, picker, xray)
    _closeBackButton()
    if hl.selected_text then _back_saved_sel = hl.selected_text end
    local saved_sel = _back_saved_sel
    local og = _buildDictButton(function()
        log("dictionary button tapped")
        -- The button is a toast, so this same tap keeps dispatching to the
        -- windows below it: sendEvent is walking UIManager._window_stack
        -- right now. Closing windows here shrinks the stack mid-walk and
        -- crashes ("attempt to index a nil value"). Defer the teardown a
        -- tick so it runs after dispatch finishes.
        UIManager:nextTick(function()
            _closeBackButton()
            _closeTrackedWidgets()
        end)
        -- Open the popup only after the tap has finished, or the tap
        -- closes it again straight away.
        UIManager:scheduleIn(0.2, function()
            local ok, err = pcall(_restoreMenu, hl, saved_sel)
            if not ok then log("dictionary restore failed: " .. tostring(err)) end
        end)
    end)
    local x, y, bs = _buttonPos(og, picker, xray)
    -- A toast receives taps but never stops them reaching the window below,
    -- so X-Ray's picker / detail views stay tappable.
    og.toast = true
    og.dimen = Geom:new{ x = x, y = y, w = bs.w, h = bs.h }
    _back_button = og
    _back_hl = hl
    _back_button_picker = picker == true
    UIManager:show(og, "ui", nil, x, y)
end

-- Inert copy of the picker-position button, used while adjusting offsets.
local _preview = nil
local function _closePreview()
    if _preview then
        pcall(function() UIManager:close(_preview) end)
        _preview = nil
    end
end

local function _showPreview(xray)
    _closePreview()
    local og = _buildDictButton(function() end)
    local x, y, bs = _buttonPos(og, true, xray)
    og.toast = true
    og.dimen = Geom:new{ x = x, y = y, w = bs.w, h = bs.h }
    _preview = og
    UIManager:show(og, "ui", nil, x, y)
end

local function _rerouteToXRay(xray, hl, word, nres)
    local sel = hl.selected_text or {}
    local lm = xray.lookup_manager
    _xray_widgets = {}
    _closeBackButton()
    local before = _topWidget()
    local t0 = os.clock()
    local ok, err = pcall(function()
        lm:handleLookup(word, sel.pos0, sel.pos1)
    end)
    local dt_ms = math.floor((os.clock() - t0) * 1000)
    if not ok then
        log("handleLookup failed (" .. tostring(err) .. "), falling back to standard menu")
        pcall(function() _restoreMenu(hl) end)
        return
    end
    local after = _topWidget()
    if after and after ~= before then
        _trackXRayWidget(after)
        log("reroute '" .. word:sub(1, 40) .. "' -> xray (" .. dt_ms .. "ms)")
        _showBackButton(hl, (nres or 1) > 1, xray)
    else
        -- handleLookup showed nothing (e.g. unit conversion handled it).
        log("handleLookup showed no widget for '" .. word:sub(1, 40) .. "' (" .. dt_ms .. "ms)")
        pcall(function() hl:clear() end)
    end
end

-- Shared entry: returns true if the selection was rerouted to X-Ray.
local function _tryReroute(hl, via)
    local sel = hl.selected_text
    local word = sel and sel.text
    if not word or word == "" then return false end
    local xray = _findXRayInstance(hl)
    if not xray then
        log("passthrough via " .. via .. " (no xray instance; tracked=" .. #_xray_instances .. ")")
        return false
    end
    if not _toggleOn(xray) then
        log("passthrough via " .. via .. " (toggle OFF; value=" .. tostring(_settings(xray)[SETTING_KEY]) .. ")")
        return false
    end
    local go, nres, dt_ms = _shouldReroute(xray, word)
    if not go then return false end
    log("lookup via " .. via .. " '" .. word:sub(1, 40) .. "' matched "
        .. tostring(nres) .. " (" .. tostring(dt_ms) .. "ms)")
    _rerouteToXRay(xray, hl, word, nres)
    return true
end

function ReaderHighlight:lookupDictWord(...)
    if _tryReroute(self, "lookupDictWord") then return end
    return orig_lookupDictWord(self, ...)
end

-- Standard highlight menu. Only a single word opened straight from a
-- long-press release is rerouted; menus for existing highlights (index),
-- extended selections and drag selections pass through untouched.
-- Lost finger-lift watchdog. A hold normally releases within ~0.15s of the
-- word being selected. If none arrives within WATCHDOG_S the lift event was
-- lost; for a known single word we finish the gesture ourselves.
local WATCHDOG_S = 1.0

local function _cancelWatchdog(hl)
    if hl.__dxr_watchdog then
        UIManager:unschedule(hl.__dxr_watchdog)
        hl.__dxr_watchdog = nil
    end
end

if orig_onHold and orig_onHoldRelease and orig_onShowHighlightMenu then
    function ReaderHighlight:onHold(...)
        self.__dxr_early_done = nil
        _cancelWatchdog(self)
        local r = orig_onHold(self, ...)
        local sel = self.selected_text
        local text = sel and sel.text
        if text and text ~= "" and not text:find("%s") and not self.select_mode then
            local xray = _findXRayInstance(self)
            if xray and _toggleOn(xray) then
                local hl = self
                hl.__dxr_watchdog = function()
                    hl.__dxr_watchdog = nil
                    local cur = hl.selected_text
                    if not (cur and cur.text == text) or hl.select_mode then return end
                    local go = _shouldReroute(xray, text)
                    if not go then return end
                    log("no release " .. WATCHDOG_S .. "s after hold - finishing '"
                        .. text:sub(1, 40) .. "' ourselves")
                    hl.__dxr_early_done = true
                    hl.__dxr_simulating = true
                    local ok, err = pcall(function() hl:onHoldRelease() end)
                    hl.__dxr_simulating = nil
                    if not ok then log("watchdog release failed: " .. tostring(err)) end
                end
                UIManager:scheduleIn(WATCHDOG_S, hl.__dxr_watchdog)
            end
        end
        return r
    end
end

if orig_onHoldRelease and orig_onShowHighlightMenu then
    function ReaderHighlight:onHoldRelease(...)
        _cancelWatchdog(self)
        if self.__dxr_early_done and not self.__dxr_simulating then
            -- The real release finally arrived after we already handled it.
            self.__dxr_early_done = nil
            log("late release swallowed")
            return true
        end
        self.__dxr_from_release = not self.select_mode
        local r = orig_onHoldRelease(self, ...)
        self.__dxr_from_release = nil
        return r
    end

    function ReaderHighlight:onShowHighlightMenu(index, ...)
        if self.__dxr_from_release and not index then
            local text = self.selected_text and self.selected_text.text
            if text and text ~= "" and not text:find("%s") then
                self.__dxr_from_release = nil
                if _tryReroute(self, "highlightMenu") then
                    return
                end
            end
        end
        return orig_onShowHighlightMenu(self, index, ...)
    end
else
    log("onHoldRelease/onShowHighlightMenu not found - highlight-menu reroute disabled")
end

-- ---- Toggle -------------------------------------------------------------
function M:onToggleDirectXRayLookup()
    if not self.ai_helper then return true end
    local new_val = not _toggleOn(self)
    self.ai_helper:saveSettings({ [SETTING_KEY] = new_val })
    _mirrorToggle(new_val)
    if not shared_note(new_val and "Direct X-Ray lookup: on" or "Direct X-Ray lookup: off") then
        local ok_n, Notification = pcall(require, "ui/widget/notification")
        if ok_n then
            Notification:notify(new_val and "Direct X-Ray lookup: on" or "Direct X-Ray lookup: off")
        end
    end
    log("toggled " .. (new_val and "ON" or "OFF"))
    return true
end

-- ---- Picker button position adjuster ------------------------------------
local STEPS = { 5, 10, 25, 50 }

local function _offsets(self)
    local st = _settings(self)
    return tonumber(st[OFFSET_X_KEY]) or 0, tonumber(st[OFFSET_Y_KEY]) or 0
end

local function _notifyOffsets(self, step)
    local dx, dy = _offsets(self)
    local msg = string.format("X %+d  Y %+d  (step %d)", dx, dy, step)
    if not shared_note(msg) then
        local ok_n, Notification = pcall(require, "ui/widget/notification")
        if ok_n then
            Notification:notify(msg)
        end
    end
end

function M:resetDirectXRayButtonOffset()
    if self.ai_helper then
        self.ai_helper:saveSettings(nil, { OFFSET_X_KEY, OFFSET_Y_KEY })
    end
end

function M:showDirectXRayPositionAdjuster()
    if not self.ai_helper then return end
    local plugin = self
    local ButtonDialog = require("ui/widget/buttondialog")
    local step_i = 2
    local dlg
    local function step() return STEPS[step_i] end
    local function nudge(ddx, ddy)
        local dx, dy = _offsets(plugin)
        plugin.ai_helper:saveSettings({
            [OFFSET_X_KEY] = dx + ddx * step(),
            [OFFSET_Y_KEY] = dy + ddy * step(),
        })
        _showPreview(plugin)
        _notifyOffsets(plugin, step())
    end
    -- Close the X-Ray / reader menu so the preview sits over the real page
    -- and status bar, exactly as it will with the picker.
    pcall(function()
        local Event = require("ui/event")
        plugin.ui:handleEvent(Event:new("CloseReaderMenu"))
    end)
    dlg = ButtonDialog:new{
        title = "Dictionary button position (multiple-match picker)\n"
            .. "Right and Down are +, Left and Up are -.",
        title_align = "center",
        buttons = {
            {{ text = "Up", callback = function() nudge(0, -1) end }},
            {
                { text = "Left", callback = function() nudge(-1, 0) end },
                { text = "Right", callback = function() nudge(1, 0) end },
            },
            {{ text = "Down", callback = function() nudge(0, 1) end }},
            {
                { text = "Change step", callback = function()
                    step_i = step_i % #STEPS + 1
                    _notifyOffsets(plugin, step())
                end },
                { text = "Reset", callback = function()
                    plugin:resetDirectXRayButtonOffset()
                    _showPreview(plugin)
                    _notifyOffsets(plugin, step())
                end },
            },
            {{ text = "Done", callback = function() UIManager:close(dlg) end }},
        },
        -- Top of the screen, so the preview at the bottom stays visible.
        anchor = function() return { y = Screen:scaleBySize(8) }, true end,
    }
    local prev_close = dlg.onCloseWidget
    dlg.onCloseWidget = function(...)
        _closePreview()
        if prev_close then return prev_close(...) end
    end
    UIManager:show(dlg)
    _showPreview(plugin)
    _notifyOffsets(plugin, step())
end

-- ---- First-run cleanup of the old Entity Footnotes patch ----------------
local function _firstRunCleanup(self)
    if G_reader_settings:isTrue(CLEANUP_FLAG) then return end
    if self.ai_helper then
        local ok, err = pcall(function()
            self.ai_helper:saveSettings(nil, OLD_SETTING_KEYS)
        end)
        log("first-run: removed entity-footnotes settings keys"
            .. (ok and "" or (" (error: " .. tostring(err) .. ")")))
    end
    G_reader_settings:saveSetting(CLEANUP_FLAG, true)
end

local function _deleteOldEntityCache(self)
    local file = self.ui and self.ui.document and self.ui.document.file
    if not file then return end
    local ok, sidecar = pcall(function() return DocSettings:getSidecarDir(file) end)
    if not ok or not sidecar then return end
    for _, name in ipairs(OLD_CACHE_NAMES) do
        local path = sidecar .. name
        local f = io.open(path, "r")
        if f then
            f:close()
            if os.remove(path) then
                log("deleted old entity cache: " .. path)
            end
        end
    end
end

_adopt = function(self)
    if self.__dxr_adopted then return end
    self.__dxr_adopted = true
    _mirrorToggle(_toggleOn(self))
    table.insert(_xray_instances, self)
    -- Catch detail views opened later from the multiple-matches picker:
    -- after showResult runs, the topmost widget is the view it just showed.
    local lm = self.lookup_manager
    if lm and not lm.__dxr_showresult_wrapped then
        lm.__dxr_showresult_wrapped = true
        local orig_sr = lm.showResult
        if type(orig_sr) == "function" then
            lm.showResult = function(lm_self, ...)
                local r = orig_sr(lm_self, ...)
                _trackXRayWidget(_topWidget())
                -- A detail view just opened. The Dictionary button belongs
                -- at the plain corner here, lined up - the picker's lifted /
                -- offset position is only for the multiple-matches menu.
                -- Deferred: when coming from the picker this runs inside tap
                -- dispatch, and moving the button closes its old window,
                -- which would shrink the window stack mid-dispatch (the same
                -- crash as the dictionary-tap bug).
                if _back_button and _back_button_picker and _back_hl then
                    UIManager:nextTick(function()
                        if _back_button and _back_button_picker and _back_hl then
                            log("detail view opened - dictionary button back to corner")
                            _showBackButton(_back_hl, false, self)
                        end
                    end)
                end
                return r
            end
        end
    end
    _firstRunCleanup(self)
    _deleteOldEntityCache(self)
end

-- ---- Plugin class table wiring ------------------------------------------
local _dispatcher_registered = false

userpatch.registerPatchPluginFunc("xray", function(XRayPlugin)
if XRayPlugin.__direct_xray_patched then return end
XRayPlugin.__direct_xray_patched = true

for k, v in pairs(M) do
    if XRayPlugin[k] == nil then
        XRayPlugin[k] = v
    else
        log("skipping mixin key '" .. tostring(k) .. "' - already defined on XRayPlugin")
    end
end

if not _dispatcher_registered then
    _dispatcher_registered = true
    local ok_d, Dispatcher = pcall(require, "dispatcher")
    if ok_d then
        Dispatcher:registerAction("xray_direct_lookup_toggle", {
            category = "none",
            event = "ToggleDirectXRayLookup",
            title = "Toggle direct X-Ray lookup",
            reader = true,
        })
    else
        log("dispatcher not available, gesture action not registered")
    end
end

local orig_init = XRayPlugin.init
function XRayPlugin:init(...)
    local ret = orig_init(self, ...)
    _adopt(self)
    return ret
end

local orig_getSubMenuItems = XRayPlugin.getSubMenuItems
function XRayPlugin:getSubMenuItems(...)
    local items = orig_getSubMenuItems(self, ...)
    if not items then return items end
    for _, item in ipairs(items) do
        if item._dxr_toggle_item then return items end
    end
    table.insert(items, 1, {
        _dxr_toggle_item = true,
        text = "Direct X-Ray lookup",
        checked_func = function() return _toggleOn(self) end,
        sub_item_table_func = function()
            return {
                {
                    text = "Enabled",
                    checked_func = function() return _toggleOn(self) end,
                    keep_menu_open = true,
                    callback = function(tm)
                        self:onToggleDirectXRayLookup()
                        if tm and tm.updateItems then tm:updateItems() end
                    end,
                },
                {
                    text = "Dictionary button position (picker)...",
                    callback = function()
                        self:showDirectXRayPositionAdjuster()
                    end,
                },
                {
                    text_func = function()
                        local dx, dy = _offsets(self)
                        return string.format("Reset position (X %+d, Y %+d)", dx, dy)
                    end,
                    keep_menu_open = true,
                    callback = function(tm)
                        self:resetDirectXRayButtonOffset()
                        if tm and tm.updateItems then tm:updateItems() end
                    end,
                },
            }
        end,
        separator = true,
    })
    return items
end

local orig_onCloseDocument = XRayPlugin.onCloseDocument
function XRayPlugin:onCloseDocument(...)
    _closeBackButton()
    _closeTrackedWidgets()
    if orig_onCloseDocument then
        return orig_onCloseDocument(self, ...)
    end
end

log("v" .. PATCH_VERSION .. " applied to xray.koplugin class table")
end)

log("Direct X-Ray Lookup patch v" .. PATCH_VERSION .. " registered")
