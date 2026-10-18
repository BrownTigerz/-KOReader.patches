--[[
    Gesture QuickMenu toggle-state patch
    Version: 1.0.4 (2026-10-18) - See CHANGELOG below.

    Versioning (for future updates to this file):
      1.0.x - fixes (e.g. adapting to a Dispatcher internal rename)
      1.x.0 - new features

    What it does:
    When a multi-action gesture is set to "Show as QuickMenu", the popup
    lists plain action names with no indication of state. This patch adds a
    checkbox in front of toggle actions it knows how to read: "✓" when on,
    "▢" when off - the same glyphs KOReader's own menus use
    (ui/widget/checkmark.lua renders them as text in the stock UI font, so
    they always render). The marker goes FIRST on purpose: the popup
    truncates long labels from the end, so a trailing marker would be the
    first thing cut off.

    Supported toggles:
    - style_tweak_* toggle actions (stock style tweaks AND custom CSS files
      in koreader/styletweaks/, e.g. the seven "Fix - ..." tweaks): state is
      read live from the ReaderStyleTweak instance for the current book, so
      per-book tweaks report correctly. Any tweak you register for gestures
      is picked up automatically - no list to maintain here.
      The style_tweak_set_* setter actions are left alone.
    - xray_direct_lookup_toggle (from 2-xray-direct-lookup.lua v1.0.1+):
      that patch mirrors its toggle to G_reader_settings, which is read
      here. Older v1.0.0 of that patch has no mirror, so its entry would
      always read Off - update it.

    To add more toggles, add an entry to CUSTOM_TOGGLES below: action key
    -> function returning true/false. Return nil to leave the text alone
    (e.g. when the state can't be determined); the patch never breaks the
    menu over an unreadable state.

    Notes:
    - Renamed actions (custom names via "Rename QuickMenu actions") are
      annotated too: the marker is applied to the stored custom name for the
      duration of the menu build, then the stored name is restored untouched.
    - If "keep menu open" is turned on for the gesture, the checkboxes
      show the state from when the menu opened - reopen it to refresh.
    - In the file browser no book is open, so style tweak entries show
      without a checkbox there. That's expected, not a bug.

    This patch does not modify KOReader. It wraps Dispatcher._showAsMenu
    and Dispatcher.getDisplayList from the outside; the flags between them
    mean only the fired quick menu is annotated, never the "Arrange
    actions" screen or other display lists.

    ===================================================================
    CHANGELOG
    ===================================================================
    1.0.4 (2026-10-18)
      - Fixed _stripStateMark: the old "^[✓▢] " pattern was a Lua
        byte-class and never stripped the checkbox marks (✓/▢ are 3-byte
        UTF-8, so the class matched one byte and then required a space
        that wasn't there), letting marks stack on rebuild. Now strips
        "✓ " and "▢ " literally. Legacy "(On) "/"(Off) " strips unchanged.
    1.0.3 (2026-10-10)
      - State marker is now a real checkbox: "✓" when on, "▢" when off,
        prepended to the label. These are the exact glyphs KOReader's own
        menus use (ui/widget/checkmark.lua renders them as text in the
        stock UI font), so rendering is guaranteed.
    1.0.2 (2026-10-10)
      - State marker is now PREPENDED ("(On) Name") instead of appended:
        the popup (ButtonDialog) truncates long labels from the end, so a
        trailing marker was always the first thing cut off.
      - Renamed actions are annotated too: the _showAsMenu wrapper now
        temporarily applies the marker to custom names in
        settings.settings.quickmenu_action_names for toggles it can read,
        and restores the stored names right after the menu is built.
        Previously _showAsMenu preferred the custom name over the annotated
        text, so renamed toggles never showed state.
      - The "Rename QuickMenu actions" screen itself is no longer annotated.
    1.0.1 (2026-10-10)
      - getDisplayList wrapper now passes all args through (varargs), so it
        works whether Dispatcher defines it with . or : and survives new args.
      - Strips any existing (On)/(Off) suffix before appending, so labels
        can't stack if a display list is ever cached/reused.
      - _showAsMenu wrapper now passes return values through.
      - Header note about file-browser behaviour.
    1.0.0 (2026-10-10) - First release.
--]]

local PATCH_VERSION = "1.0.4"

local Dispatcher = require("dispatcher")
local logger = require("logger")
local function log(msg)
    logger.info("QuickMenuToggleState: " .. tostring(msg))
end

log("v" .. PATCH_VERSION .. " loading")

local unpack = unpack or table.unpack
local function pack(...)
    return { n = select("#", ...), ... }
end

-- Exact action keys with custom state readers. Function receives the key,
-- returns true/false, or nil to leave the button text untouched.
local CUSTOM_TOGGLES = {
    -- ["some_action_key"] = function() return G_reader_settings:isTrue("something") end,
}

-- State for a style-tweak toggle action (key "style_tweak_<tweak_id>").
-- Read from the live instance so per-book tweaks report their actual state.
local function _styleTweakState(key)
    local tweak_id = key:match("^style_tweak_(.+)$")
    if not tweak_id then return nil end
    local ok_ru, ReaderUI = pcall(require, "apps/reader/readerui")
    local reader = ok_ru and ReaderUI and ReaderUI.instance
    local rst = reader and reader.styletweak
    if not rst or type(rst.isTweakEnabled) ~= "function" then return nil end
    local ok, enabled = pcall(function() return rst:isTweakEnabled(tweak_id) end)
    if not ok then return nil end
    return enabled == true
end

local function _toggleState(key)
    if type(key) ~= "string" then return nil end
    local custom = CUSTOM_TOGGLES[key]
    if custom then
        local ok, state = pcall(custom, key)
        if ok then return state end
        return nil
    end
    if key == "xray_direct_lookup_toggle" then
        return G_reader_settings:isTrue("xray_direct_lookup")
    end
    if key:match("^style_tweak_") and not key:match("^style_tweak_set_") then
        return _styleTweakState(key)
    end
    return nil
end

-- Remove a previously applied state marker so labels never stack.
-- Strips the current checkbox marks and the legacy 1.0.x "(On) "/"(Off) "
-- text marks (never persisted, but cheap to be safe).
-- NOTE: do NOT use a character class like [✓▢] here — Lua classes match
-- single bytes and these glyphs are 3-byte UTF-8, so the class never
-- matches. Each glyph is stripped literally instead.
local function _stripStateMark(text)
    text = text:gsub("^✓ ", "")
    text = text:gsub("^▢ ", "")
    text = text:gsub("^%(On%) ", "")
    text = text:gsub("^%(Off%) ", "")
    return text
end

local function _stateMark(state)
    return state and "✓ " or "▢ "
end

-- Set while the fired quick menu is being built, so only that display list
-- gets annotated (not "Arrange actions" or anything else using
-- getDisplayList). _showAsMenu builds synchronously, so flags are enough.
local _in_quickmenu = false
local _in_rename_mode = false

-- _showAsMenu is defined dot-style as (settings, exec_props, rename_callback,
-- rename_hold_callback). Tolerate a colon-style call just in case.
local function _showAsMenuArgs(...)
    local a1 = select(1, ...)
    if type(a1) == "table" and type(a1.getDisplayList) == "function" then
        -- colon-style: (self, settings, exec_props, rename_callback, ...)
        return select(2, ...), select(4, ...)
    end
    -- dot-style: (settings, exec_props, rename_callback, rename_hold_callback)
    return a1, select(3, ...)
end

local orig_showAsMenu = Dispatcher._showAsMenu
function Dispatcher._showAsMenu(...)
    local settings, rename_callback = _showAsMenuArgs(...)
    _in_quickmenu = true
    _in_rename_mode = rename_callback ~= nil
    -- _showAsMenu prefers a custom name over the annotated v.text, which would
    -- discard the marker for renamed actions. So temporarily apply the marker
    -- to the stored custom names of toggles we can read, and restore them
    -- right after the menu is built. Skipped in rename mode.
    local restored = {}
    if not _in_rename_mode and type(settings) == "table" then
        local s = settings.settings
        local names = type(s) == "table" and s.quickmenu_action_names
        if type(names) == "table" then
            for key, custom in pairs(names) do
                if type(custom) == "string" then
                    local state = _toggleState(key)
                    if state ~= nil then
                        restored[key] = custom
                        names[key] = _stateMark(state) .. _stripStateMark(custom)
                    end
                end
            end
        end
    end
    local res = pack(pcall(orig_showAsMenu, ...))
    for key, custom in pairs(restored) do
        local s = type(settings) == "table" and settings.settings
        local names = type(s) == "table" and s.quickmenu_action_names
        if type(names) == "table" then
            names[key] = custom
        end
    end
    _in_quickmenu = false
    _in_rename_mode = false
    if not res[1] then error(res[2], 0) end
    return unpack(res, 2, res.n)
end

local orig_getDisplayList = Dispatcher.getDisplayList
function Dispatcher.getDisplayList(...)
    local list = orig_getDisplayList(...)
    if _in_quickmenu and not _in_rename_mode and type(list) == "table" then
        for _, item in ipairs(list) do
            local state = _toggleState(item.key)
            if state ~= nil and type(item.text) == "string" then
                item.text = _stateMark(state) .. _stripStateMark(item.text)
            end
        end
    end
    return list
end

log("v" .. PATCH_VERSION .. " applied")
