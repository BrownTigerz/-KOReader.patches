--[[
    Track Reading Location
    Version: 1.8.2

    Versioning: 1.0.x = fixes, 1.x.0 = new features, 2.0.0 = a change to how
    existing saved reading locations are stored (the per-book sidecar data).

    This patch remembers the last "confirmed" reading position (the furthest page
    you've actually read) for the book you're currently reading.

    If you page backward more than one page - one page at a time or in a single
    jump (progress bar, etc.) - a small floating pill-shaped button appears at
    the bottom-right of the screen. If you jump forward more than two pages at
    once (e.g. tapping a table of contents entry that lands you in the
    appendix) - or several smaller forward taps land close enough together in
    time to add up to the same thing - the same button appears mirrored at the
    bottom-left. A slow, single 2-page forward move stays silent on purpose
    (skipping a blank/illustration page, a "skip ahead" gesture); only
    backward drift is held to that tighter 1-page tolerance. What it shows is
    configurable independently (Reader menu -> Navigation -> Reading location ->
    Settings):

    - "Show full text": include the "Go back to page" wording.
    - "Show location/page number": include the page number (or percentage, in
      percentage mode) next to the arrow.
    - "Show dismiss button": include a tappable "X" to cancel/dismiss.
    - "Mode: Page number/Percentage": show the reference point as a page
      number (default) or as a percentage of the book, both on the button
      and in the "Go back to..." wording.
    - "Forward popup auto-dismiss" (Off/15s/20s/30s/50s, default 20s): the
      forward popup only - never backward - hides itself if you never act on
      it within this window, treating an unreturned skim-ahead (table of
      contents, a picture page, checking something) as intentional. The next
      real page turn after it hides becomes the new anchor.

    With everything off, the button shrinks to just a small circular arrow.

    - Tapping the go-back side (or the whole button, if there's no dismiss
      section) jumps back to that page.
    - Tapping the "X" - or, if it isn't shown, holding the button instead -
      cancels the prompt and accepts your current page as the new reference
      point (it won't nag you about this jump again).
    - Reading normally (forward, or drifting back by at most one page) silently
      advances the remembered position - no popup.

    The button is drawn as an overlay on top of the page (like KOReader's own
    footer/progress bar), so it never blocks taps anywhere else on the screen -
    you can keep turning pages or open menus while it's showing. It docks
    above KOReader's own footer bar when the footer is visible and actually
    reserving its own space (not when "Overlap status bar" is on).

    A "Reading location" menu entry (Reader menu -> Navigation, right below
    "Go forward to next location", by default - a menu-organizing patch may
    relocate it elsewhere) groups three rows: "Go to furthest reading
    location" (jump to your reference page with a tap), "Set current page as
    reading location" (accept the current page as the new reference point on
    demand - the same thing tapping/holding the button's "X" does - without
    needing an active prompt to dismiss first), and "Settings", which opens a
    submenu with a "Show button on screen" checkbox (to turn the floating
    button off entirely if you'd rather only use the menu/gesture), the
    display checkboxes described above, a "Show shadow" checkbox (toggles the
    button's drop shadow), "Bottom offset"/"Side offset" settings to adjust
    how far the button is docked from the bottom and side edges of the screen
    (applied the same way to both corners), and a "Button radius" setting to
    adjust how rounded its corners are, from 0 (square) up to fully rounded
    (pill/circle, the default). Both actions can also be bound to a gesture
    via the gesture manager, independently of this menu.

    The reference page is saved per book, so a pending prompt will still be there
    if you close the book and reopen it later. On reflowable documents (EPUB,
    FB2...) it's tracked by an internal xpointer alongside its page number, so
    a font size/margin/line-spacing change doesn't leave "go back" pointing at
    the wrong page - paginated documents (PDF, CBZ, DjVu...) can't reflow, so
    this doesn't apply to them.

    Changelog (from here forward - this patch's earlier history predates this
    numbering scheme and isn't repeated here):
    1.8.2 - 2026-10-03 - After a forward popup times out, a big jump (search,
    TOC, progress bar) no longer becomes the anchor; the page you were on
    does, and the jump gets the usual go-back popup.
    1.8.1 - 2026-10-03 - Fast-forward burst threshold raised from 3 to 4 pages.
    1.8.0 - 2026-10-02 - Added formal version tracking: this header's Version
    line, the PATCH_VERSION constant everything else reads from, and a
    version-stamped line in the log on load.
--]]

local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Dispatcher = require("dispatcher")
local Event = require("ui/event")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local LineWidget = require("ui/widget/linewidget")
local Notification = require("ui/widget/notification")
local ReaderLink = require("apps/reader/modules/readerlink")
local ReaderUI = require("apps/reader/readerui")
local ReaderView = require("apps/reader/modules/readerview")
local Size = require("ui/size")
local SpinWidget = require("ui/widget/spinwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local time = require("ui/time")

local logger = require("logger")
local _ = require("gettext")
local T = require("ffi/util").template

local Screen = Device.screen

-- Single source of truth for the version shown in the menu and logged below -
-- the header comment's own "Version:" line is a separate piece of text (a
-- comment can't read a code constant) and needs updating by hand alongside
-- this one; everything else - the menu's version row and both load logs -
-- reads from here.
local PATCH_VERSION = "1.8.2"

logger.info("ReadingLocationTracker Patch: v" .. PATCH_VERSION .. " loading...")

local SETTING_SHOW_BUTTON = "readingloc_show_floating_button"
-- Independent display toggles for the floating button's content (all
-- default on, matching the button's original look). With all three off,
-- the button shrinks to a small circular arrow, and holding it (instead of
-- tapping a visible "X") is how you cancel/dismiss - see
-- ReadingLocationOverlay:handleHold.
local SETTING_SHOW_FULL_TEXT = "readingloc_show_full_text"
local SETTING_SHOW_PAGE_NUMBER = "readingloc_show_page_number"
local SETTING_SHOW_DISMISS_BUTTON = "readingloc_show_dismiss_button"
-- Whether the reference point is displayed (button + "Go back to..." wording)
-- as a page number (default) or as a percentage of the book.
local SETTING_MODE_PERCENTAGE = "readingloc_mode_percentage"

-- Reading forward one page at a time never trips the "jumped ahead" check
-- below on its own, no matter the pace - each step is small. But several
-- such steps arriving in a tight burst (riffling/skimming ahead to check
-- something) add up to the same thing a single big jump does, even though
-- no single step looked like one. FAST_TURN_MAX_INTERVAL is how close
-- together (in ms) consecutive page turns have to land to count as the same
-- burst; FAST_FORWARD_BURST_PAGES is how many pages forward a burst has to
-- cover before it's treated as a jump instead of quick reading. Both are
-- heuristic, chosen without on-device testing - adjust if they feel off.
local FAST_TURN_MAX_INTERVAL_MS = 1500
local FAST_FORWARD_BURST_PAGES = 4

-- The button is always docked to its fixed bottom-left/bottom-right corner.
-- Its distance from the bottom edge, and from whichever side edge (left or
-- right) it's currently anchored to, is configurable from the settings
-- submenu - the same two values apply to both corners.
local BUTTON_BASE_MARGIN = 14
local SETTING_OFFSET_BOTTOM = "readingloc_offset_bottom"
local SETTING_OFFSET_SIDE = "readingloc_offset_side"

-- Whether the button casts a small drop shadow (see paintButtonShadow below).
local SETTING_SHOW_SHADOW = "readingloc_show_shadow"

-- How long the forward ("jumped ahead") popup stays up before dismissing
-- itself automatically, if you never act on it - a genuine skim-ahead (TOC,
-- a picture page, checking something) shouldn't leave a stale popup pointing
-- at an anchor you've long since moved past. The backward popup never times
-- out - see refreshOverlayVisibility/scheduleForwardDismiss. Stored value is
-- a number of seconds, or `false` for "Off" (restores the old
-- never-times-out behavior for the forward popup too); unset (first run)
-- means the default below.
local SETTING_FORWARD_DISMISS_SECONDS = "readingloc_forward_dismiss_seconds"
local FORWARD_DISMISS_DEFAULT_SECONDS = 20

-- Corner radius of the button, in unscaled px like the offset settings above.
-- Defaults intentionally oversized - bb:paintRoundedRect/paintBorder already
-- clamp radius down to at most half the button's own height/width, so a big
-- default always resolves to a full pill, matching the button's original
-- hardcoded look, while still leaving smaller values (down to 0, i.e. square
-- corners) available to the settings submenu's spinner.
local BUTTON_RADIUS_DEFAULT = 25
local SETTING_BUTTON_RADIUS = "readingloc_button_radius"

-- Forward-declared so ReadingLocationOverlay's methods (defined next) can already
-- reference it by the time they're actually called at runtime.
local ReadingLocationTracker = {}

-- Label a page number the same way KOReader's own footer does, respecting
-- the user's real-page-numbers-vs-computed-pagination setting (page maps,
-- hidden reading flows), instead of always showing the raw internal page
-- number. This only affects the displayed text - the anchor tracking/delta
-- math below always uses the raw internal page number, since real-page
-- labels aren't guaranteed to be sequential integers.
local function getPageLabel(ui, pageno)
    local ok, label = pcall(function()
        if ui.pagemap and ui.pagemap:wantsPageLabels() then
            local xp = ui.document:getPageXPointer(pageno)
            if xp then
                return ui.pagemap:getXPointerPageLabel(xp, true)
            end
        elseif ui.document.hasHiddenFlows and ui.document:hasHiddenFlows() then
            local flow = ui.document:getPageFlow(pageno)
            local page_in_flow = ui.document:getPageNumberInFlow(pageno)
            if flow == 0 then
                return tostring(page_in_flow)
            else
                return ("[%d]%d"):format(page_in_flow, flow)
            end
        end
        return tostring(pageno)
    end)
    if ok and label then
        return tostring(label)
    end
    return tostring(pageno)
end

-- Labels a location the way the floating button/menu wording should show it:
-- a page label (see getPageLabel above), or, when percentage mode is on, the
-- position as a percentage of the total page count - falling back to the
-- page label if the page count isn't available yet.
local function getLocationLabel(ui, pageno)
    if ReadingLocationTracker.isPercentageModeEnabled() then
        local page_count = ReadingLocationTracker.getPageCount(ui)
        if page_count and page_count > 0 then
            return math.floor((pageno / page_count) * 100 + 0.5) .. "%"
        end
    end
    return getPageLabel(ui, pageno)
end

--[[ ---------------------------------------------------------------------
     Floating split-button overlay (painted as part of the page, like
     KOReader's own footer/progress bar - never a separate modal window)
----------------------------------------------------------------------- ]]

local ReadingLocationOverlay = WidgetContainer:extend{
    ui = nil,
    view = nil,
    visible = false,
    side = "bottom_right", -- or "bottom_left"
    anchor = 0,
    -- Forces the button to render on BOTH corners at once, purely so the
    -- settings submenu can preview both dockings side by side - see the
    -- "hold for settings" hold_callback. `side` still names the "real"
    -- one used for hit-testing; the mirrored one is decorative only.
    preview_both_sides = false,
}

function ReadingLocationOverlay:_getBox(side)
    side = side or self.side
    local show_full_text = ReadingLocationTracker.isFullTextEnabled()
    local show_page_number = ReadingLocationTracker.isPageNumberEnabled()
    local show_dismiss = ReadingLocationTracker.isDismissButtonEnabled()
    local percentage_mode = ReadingLocationTracker.isPercentageModeEnabled()
    local button_radius = ReadingLocationTracker.getButtonRadius()
    local key = table.concat({
        side, tostring(self.anchor),
        tostring(show_full_text), tostring(show_page_number), tostring(show_dismiss),
        tostring(percentage_mode), tostring(button_radius),
    }, ":")
    if side == self._cached_side and self._box and self._box_key == key then
        return self._box
    end

    local box = self:_getButtonBox(side, show_full_text, show_page_number, show_dismiss)

    if side == self.side then
        -- Only cache (and only let it feed hit-testing) for the "real"
        -- side - a mirrored preview box is built fresh every repaint and
        -- must never overwrite the real side's _goback_w/_cancel_w/_sep_w.
        self._box = box
        self._box_key = key
        self._cached_side = side
    end
    return box
end

-- The "Go back to page X" section (built from whichever of show_full_text/
-- show_page_number are on - if neither is, it's just the arrow), plus an
-- optional "X" section to cancel/dismiss.
function ReadingLocationOverlay:_getButtonBox(side, show_full_text, show_page_number, show_dismiss)
    local face = Font:getFace("cfont", 16)
    local pad_h = Screen:scaleBySize(14)
    local pad_v = Screen:scaleBySize(8)
    local arrow = side == "bottom_left" and "\u{2190}" or "\u{2192}"

    -- The outer frame's ends are fully rounded (see the pill radius
    -- below), but each section's own padding is symmetric - only the side
    -- of a section that actually faces an outward (curved) end needs the
    -- extra room; the side facing the flat middle separator doesn't.
    local pad_h_extra = Screen:scaleBySize(2)
    local goback_pad_left, goback_pad_right = pad_h, pad_h
    local cancel_pad_left, cancel_pad_right = pad_h, pad_h
    if show_dismiss then
        -- "Go back" sits on the screen-corner-facing edge, "X" on the
        -- content-facing edge - whichever of the two ends up outermost
        -- (left or right) gets the extra padding on that side only.
        if side == "bottom_left" then
            goback_pad_left = goback_pad_left + pad_h_extra
            cancel_pad_right = cancel_pad_right + pad_h_extra
        else
            cancel_pad_left = cancel_pad_left + pad_h_extra
            goback_pad_right = goback_pad_right + pad_h_extra
        end
    end

    -- Point the arrow toward the screen edge this button is docked to.
    local words = {}
    if show_full_text then
        -- "page" doesn't read well in front of a percentage ("page 42%"),
        -- so it's dropped from the wording in that mode.
        if ReadingLocationTracker.isPercentageModeEnabled() then
            table.insert(words, _("Go back to"))
        else
            table.insert(words, _("Go back to page"))
        end
    end
    if show_page_number then
        table.insert(words, getLocationLabel(self.ui, self.anchor))
    end
    local label = table.concat(words, " ")
    local goback_text
    if label == "" then
        -- Neither text toggle is on - just the arrow, alone or next to a
        -- separate "X" section.
        goback_text = arrow
    else
        goback_text = side == "bottom_left" and (arrow .. " " .. label) or (label .. " " .. arrow)
    end
    local goback_section = FrameContainer:new{
        bordersize = 0,
        radius = 0,
        margin = 0,
        padding_top = pad_v,
        padding_bottom = pad_v,
        padding_left = goback_pad_left,
        padding_right = goback_pad_right,
        TextWidget:new{
            text = goback_text,
            face = face,
        },
    }

    local content
    if show_dismiss then
        local cancel_section = FrameContainer:new{
            bordersize = 0,
            radius = 0,
            margin = 0,
            padding_top = pad_v,
            padding_bottom = pad_v,
            padding_left = cancel_pad_left,
            padding_right = cancel_pad_right,
            TextWidget:new{
                text = "\u{2715}", -- "X" close mark
                face = face,
            },
        }

        local row_h = math.max(goback_section:getSize().h, cancel_section:getSize().h)
        local sep_w = Screen:scaleBySize(1)
        local separator = LineWidget:new{
            background = Blitbuffer.COLOR_BLACK,
            dimen = Geom:new{ w = sep_w, h = row_h },
        }

        -- "Go back" (with its arrow) sits on the screen-corner-facing edge,
        -- "X" on the content-facing edge next to it.
        local children
        if side == "bottom_left" then
            children = { goback_section, separator, cancel_section }
        else
            children = { cancel_section, separator, goback_section }
        end
        content = HorizontalGroup:new(children)

        if side == self.side then
            self._goback_w = goback_section:getSize().w
            self._cancel_w = cancel_section:getSize().w
            self._sep_w = sep_w
        end
    else
        content = goback_section
        if side == self.side then
            self._goback_w, self._cancel_w, self._sep_w = nil, nil, nil
        end
    end

    return FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = Size.border.thin,
        -- The configured radius gets clamped down by paintRoundedRect/
        -- paintBorder (see base/ffi/blitbuffer.lua) to at most half the
        -- button's own height - so the default (BUTTON_RADIUS_DEFAULT,
        -- intentionally oversized) always resolves to a pill shape, or a
        -- circle when the content ends up about as wide as it is tall (e.g.
        -- arrow-only, no text, no dismiss section), while a smaller value
        -- from the settings submenu's spinner yields a less rounded button,
        -- down to square corners at 0.
        radius = Screen:scaleBySize(ReadingLocationTracker.getButtonRadius()),
        padding = 0,
        margin = 0,
        content,
    }
end

-- Shared by paintButtonShadow and growRegionForShadow below, so the
-- refresh-region padding always matches how far the shadow is actually
-- offset - drifting the two apart would leave a stale sliver of shadow on
-- screen once the button's gone (see growRegionForShadow).
local SHADOW_OFFSET = 2

local function paintButtonShadow(bb, box_x, box_y, w, h, radius)
    local offset = Screen:scaleBySize(SHADOW_OFFSET)
    bb:paintRoundedRect(box_x, box_y + offset, w, h, Blitbuffer.COLOR_GRAY_9, radius)
end

-- The shadow pokes out a few pixels past the button's own bottom edge (see
-- paintButtonShadow above) - a refresh region sized to just box_dimen would
-- leave a stale sliver of it on screen once the button's gone, since e-ink
-- only actually re-flashes whatever rect it's told to. Only grows downward,
-- matching the shadow's own offset direction, and only when the shadow is
-- actually enabled.
local function growRegionForShadow(region)
    if not region or not ReadingLocationTracker.isShadowEnabled() then
        return region
    end
    local pad = Screen:scaleBySize(SHADOW_OFFSET)
    return Geom:new{ x = region.x, y = region.y, w = region.w, h = region.h + pad }
end

-- Called by our ReaderView:paintTo hook on every page repaint.
function ReadingLocationOverlay:paintTo(bb, x, y)
    if not self.visible then
        self.box_dimen = nil
        return
    end

    local ok, err = pcall(function()
        local show_dismiss = ReadingLocationTracker.isDismissButtonEnabled()
        local box = self:_getBox()
        local w, h = box:getSize().w, box:getSize().h

        local view_w = (self.view and self.view.dimen and self.view.dimen.w) or Screen:getWidth()
        local view_h = (self.view and self.view.dimen and self.view.dimen.h) or Screen:getHeight()

        local margin_x = ReadingLocationTracker.getSideMargin()
        local margin_y = ReadingLocationTracker.getBottomMargin(self.ui)
        local box_x
        if self.side == "bottom_left" then
            box_x = x + margin_x
        else
            box_x = x + view_w - w - margin_x
        end
        local box_y = y + view_h - h - margin_y

        self.box_dimen = Geom:new{ x = box_x, y = box_y, w = w, h = h }

        if not show_dismiss then
            -- No visible "X": the whole button is a single hit target, tap
            -- goes back, and holding it is how you cancel/dismiss instead
            -- (see handleHold).
            self.goback_dimen = self.box_dimen
            self.cancel_dimen = nil
        else
            -- The box's own border sits between box_x/box_y and where the
            -- goback/cancel sections actually start - without this offset the
            -- computed hit-boxes drift from what's actually drawn, most
            -- noticeably on the narrow "X" section.
            local border = Size.border.thin
            local content_x = box_x + border
            local content_y = box_y + border
            local content_h = h - (2 * border)
            -- Must mirror _getButtonBox()'s children order exactly, or the
            -- hit-boxes end up swapped relative to what's actually drawn.
            if self.side == "bottom_left" then
                self.goback_dimen = Geom:new{ x = content_x, y = content_y, w = self._goback_w, h = content_h }
                self.cancel_dimen = Geom:new{ x = content_x + self._goback_w + self._sep_w, y = content_y, w = self._cancel_w, h = content_h }
            else
                self.cancel_dimen = Geom:new{ x = content_x, y = content_y, w = self._cancel_w, h = content_h }
                self.goback_dimen = Geom:new{ x = content_x + self._cancel_w + self._sep_w, y = content_y, w = self._goback_w, h = content_h }
            end
        end

        local button_radius = Screen:scaleBySize(ReadingLocationTracker.getButtonRadius())
        if ReadingLocationTracker.isShadowEnabled() then
            paintButtonShadow(bb, box_x, box_y, w, h, button_radius)
        end
        box:paintTo(bb, box_x, box_y)

        if self.preview_both_sides then
            -- Purely decorative: painted at the opposite corner so both
            -- dockings can be compared side by side, but not wired up to
            -- goback_dimen/cancel_dimen - self.side stays the only side
            -- that's actually tappable.
            local other_side = self.side == "bottom_left" and "bottom_right" or "bottom_left"
            local other_box = self:_getBox(other_side)
            local ow, oh = other_box:getSize().w, other_box:getSize().h
            -- Same margin values as the real side - they aren't per-corner.
            local other_x
            if other_side == "bottom_left" then
                other_x = x + margin_x
            else
                other_x = x + view_w - ow - margin_x
            end
            local other_y = y + view_h - oh - margin_y
            if ReadingLocationTracker.isShadowEnabled() then
                paintButtonShadow(bb, other_x, other_y, ow, oh, button_radius)
            end
            other_box:paintTo(bb, other_x, other_y)
        end
    end)
    if not ok then
        logger.warn("ReadingLocationTracker: overlay paintTo error:", err)
    end
end

-- Runs the button's action (go back / cancel) if `pos` lands on it.
function ReadingLocationOverlay:_activate(pos)
    if not self.visible or not self.box_dimen or not self.box_dimen:contains(pos) then
        return false
    end
    if self.cancel_dimen and self.cancel_dimen:contains(pos) then
        ReadingLocationTracker.onCancel(self.ui)
    elseif self.goback_dimen and self.goback_dimen:contains(pos) then
        ReadingLocationTracker.onGoBack(self.ui)
    end
    return true
end

-- Precise hit test, called from a touch zone registered on ReaderUI. Returns
-- true only when the tap actually lands on the button (consuming it and
-- preventing the underlying page-turn zone from also firing); returns a
-- falsy value otherwise so the normal page-turn/menu zone still runs.
function ReadingLocationOverlay:handleTap(ges)
    if self:_activate(ges.pos) then
        return true
    end
end

-- When there's no visible "X" section to tap, holding the button is how
-- you cancel/dismiss instead. When the dismiss button IS shown, a hold
-- here is a no-op and falls through to whatever hold zone is normally
-- underneath (e.g. the dictionary lookup on selected text).
function ReadingLocationOverlay:_activateHold(pos)
    if not self.visible or ReadingLocationTracker.isDismissButtonEnabled() then
        return false
    end
    if not self.box_dimen or not self.box_dimen:contains(pos) then
        return false
    end
    ReadingLocationTracker.onCancel(self.ui)
    return true
end

function ReadingLocationOverlay:handleHold(ges)
    if self:_activateHold(ges.pos) then
        return true
    end
end

function ReadingLocationOverlay:setupTouchZones()
    if self._zones_registered then
        return
    end
    self._zones_registered = true

    -- Take priority over every tap/hold zone already registered on the
    -- reader at this point - page-turn corners, the bottom footer bar,
    -- menu-toggle zones, etc. - so our button always gets first look at a
    -- tap/hold landing on it, regardless of which zone layout or KOReader
    -- version is in use (this is what was previously letting bottom-bar/
    -- corner taps win over the button - overriding only a few hardcoded
    -- zone ids wasn't enough).
    local zone_overrides = {
        -- Known ids, kept explicit in case they get (re-)registered later.
        "readerconfigmenu_ext_tap",
        "readerconfigmenu_tap",
        "tap_forward",
        "tap_backward",
        "readerfooter_tap",
        "readerhighlight_hold",
    }
    if self.ui._zones then
        for id in pairs(self.ui._zones) do
            table.insert(zone_overrides, id)
        end
    end
    -- The button always sits in its fixed bottom-left/bottom-right corner,
    -- so a generous bottom strip on each half is enough to reach it.
    self.ui:registerTouchZones{
        {
            id = "readingloc_tap_left",
            ges = "tap",
            screen_zone = { ratio_x = 0, ratio_y = 0.75, ratio_w = 0.5, ratio_h = 0.25 },
            handler = function(ges) return self:handleTap(ges) end,
            overrides = zone_overrides,
        },
        {
            id = "readingloc_tap_right",
            ges = "tap",
            screen_zone = { ratio_x = 0.5, ratio_y = 0.75, ratio_w = 0.5, ratio_h = 0.25 },
            handler = function(ges) return self:handleTap(ges) end,
            overrides = zone_overrides,
        },
        {
            id = "readingloc_hold_left",
            ges = "hold",
            screen_zone = { ratio_x = 0, ratio_y = 0.75, ratio_w = 0.5, ratio_h = 0.25 },
            handler = function(ges) return self:handleHold(ges) end,
            overrides = zone_overrides,
        },
        {
            id = "readingloc_hold_right",
            ges = "hold",
            screen_zone = { ratio_x = 0.5, ratio_y = 0.75, ratio_w = 0.5, ratio_h = 0.25 },
            handler = function(ges) return self:handleHold(ges) end,
            overrides = zone_overrides,
        },
    }
end

--[[ ---------------------------------------------------------------------
     Anchor tracking state machine
----------------------------------------------------------------------- ]]

function ReadingLocationTracker.isFloatingButtonEnabled()
    local v = G_reader_settings:readSetting(SETTING_SHOW_BUTTON)
    if v == nil then
        return true
    end
    return v == true
end

function ReadingLocationTracker.setFloatingButtonEnabled(enabled)
    G_reader_settings:saveSetting(SETTING_SHOW_BUTTON, enabled and true or false)
end

function ReadingLocationTracker.isFullTextEnabled()
    local v = G_reader_settings:readSetting(SETTING_SHOW_FULL_TEXT)
    if v == nil then
        return true
    end
    return v == true
end

function ReadingLocationTracker.setFullTextEnabled(enabled)
    G_reader_settings:saveSetting(SETTING_SHOW_FULL_TEXT, enabled and true or false)
end

function ReadingLocationTracker.isPageNumberEnabled()
    if ReadingLocationTracker.isFullTextEnabled() then
        -- "Go back to page" doesn't make sense without the page number.
        return true
    end
    local v = G_reader_settings:readSetting(SETTING_SHOW_PAGE_NUMBER)
    if v == nil then
        return true
    end
    return v == true
end

function ReadingLocationTracker.setPageNumberEnabled(enabled)
    G_reader_settings:saveSetting(SETTING_SHOW_PAGE_NUMBER, enabled and true or false)
end

function ReadingLocationTracker.isDismissButtonEnabled()
    local v = G_reader_settings:readSetting(SETTING_SHOW_DISMISS_BUTTON)
    if v == nil then
        return true
    end
    return v == true
end

function ReadingLocationTracker.setDismissButtonEnabled(enabled)
    G_reader_settings:saveSetting(SETTING_SHOW_DISMISS_BUTTON, enabled and true or false)
end

function ReadingLocationTracker.isShadowEnabled()
    local v = G_reader_settings:readSetting(SETTING_SHOW_SHADOW)
    if v == nil then
        return true
    end
    return v == true
end

function ReadingLocationTracker.setShadowEnabled(enabled)
    G_reader_settings:saveSetting(SETTING_SHOW_SHADOW, enabled and true or false)
end

-- Returns the configured forward-dismiss duration in seconds, or nil if the
-- setting is "Off" (never auto-dismiss). Falls back to the default on first
-- run (nothing saved yet) - see SETTING_FORWARD_DISMISS_SECONDS above for
-- why `false` specifically means "Off" rather than nil.
function ReadingLocationTracker.getForwardDismissSeconds()
    local v = G_reader_settings:readSetting(SETTING_FORWARD_DISMISS_SECONDS)
    if v == nil then
        return FORWARD_DISMISS_DEFAULT_SECONDS
    end
    if v == false then
        return nil
    end
    return v
end

-- seconds: a positive number, or nil/false for "Off".
function ReadingLocationTracker.setForwardDismissSeconds(seconds)
    G_reader_settings:saveSetting(SETTING_FORWARD_DISMISS_SECONDS, seconds or false)
end

function ReadingLocationTracker.isPercentageModeEnabled()
    local v = G_reader_settings:readSetting(SETTING_MODE_PERCENTAGE)
    if v == nil then
        return false
    end
    return v == true
end

function ReadingLocationTracker.setPercentageModeEnabled(enabled)
    G_reader_settings:saveSetting(SETTING_MODE_PERCENTAGE, enabled and true or false)
end

function ReadingLocationTracker.getBottomOffset()
    local v = G_reader_settings:readSetting(SETTING_OFFSET_BOTTOM)
    if type(v) ~= "number" then
        return 0
    end
    return v
end

function ReadingLocationTracker.setBottomOffset(value)
    G_reader_settings:saveSetting(SETTING_OFFSET_BOTTOM, value)
end

function ReadingLocationTracker.getSideOffset()
    local v = G_reader_settings:readSetting(SETTING_OFFSET_SIDE)
    if type(v) ~= "number" then
        return 0
    end
    return v
end

function ReadingLocationTracker.setSideOffset(value)
    G_reader_settings:saveSetting(SETTING_OFFSET_SIDE, value)
end

function ReadingLocationTracker.getButtonRadius()
    local v = G_reader_settings:readSetting(SETTING_BUTTON_RADIUS)
    if type(v) ~= "number" then
        return BUTTON_RADIUS_DEFAULT
    end
    return v
end

function ReadingLocationTracker.setButtonRadius(value)
    G_reader_settings:saveSetting(SETTING_BUTTON_RADIUS, value)
end

-- Total distance the button is docked away from the bottom edge - the
-- configured base margin/offset, plus the height of KOReader's own footer
-- bar when it's currently occupying its own space. `ui.view.footer:getHeight()`
-- is the same call ReaderView itself uses to lay out content around the
-- footer, so it already reflects whatever footer mode is active (full bar,
-- mini progress bar, etc.) and returns 0 when there's nothing rendered.
-- footer.reclaim_height ("Overlap status bar") means the footer is drawn
-- over the last line of text instead of reserving its own space - readertypeset.lua
-- skips adding footer height to its own bottom margin in that case, so this
-- does too, or the button would dock a full footer-height above the edge
-- for no reason.
function ReadingLocationTracker.getBottomMargin(ui)
    local margin = Screen:scaleBySize(BUTTON_BASE_MARGIN + ReadingLocationTracker.getBottomOffset())
    local view = ui and ui.view
    if view and view.footer_visible and view.footer and not view.footer.reclaim_height
        and view.footer.getHeight then
        local ok, footer_h = pcall(function() return view.footer:getHeight() end)
        if ok and type(footer_h) == "number" and footer_h > 0 then
            margin = margin + footer_h
        end
    end
    return margin
end

function ReadingLocationTracker.getSideMargin()
    return Screen:scaleBySize(BUTTON_BASE_MARGIN + ReadingLocationTracker.getSideOffset())
end

function ReadingLocationTracker.getPageCount(ui)
    local ok, count = pcall(function() return ui.document:getPageCount() end)
    if ok and type(count) == "number" and count > 0 then
        return count
    end
    return nil
end

-- Re-derives the anchor's page number from its xpointer twin, for rolling
-- (reflowable) documents only - crengine can re-paginate at any time (font
-- size, margins, line spacing...), which shifts what page number any given
-- piece of content lands on. The xpointer identifies the content itself, so
-- resolving through it (rather than trusting a possibly-stale page number)
-- keeps the anchor pointing at the same text even after a reflow. Paginated
-- documents (PDF, CBZ, DjVu...) can't reflow, so their tracked page number
-- is always used as-is.
function ReadingLocationTracker.resolveAnchorPage(ui)
    if ui._rlt_is_rolling and ui._rlt_anchor_xpointer then
        local ok, page = pcall(function()
            return ui.document:getPageFromXPointer(ui._rlt_anchor_xpointer)
        end)
        if ok and type(page) == "number" and page > 0 then
            return page
        end
    end
    return ui._rlt_anchor
end

-- Updates the tracked anchor page, and - for rolling documents - refreshes
-- its xpointer twin to match, under whatever pagination is active right
-- now. Every place that changes ui._rlt_anchor should go through this
-- instead of assigning it directly, so the xpointer never drifts out of
-- sync with the page number it's supposed to mirror (see
-- resolveAnchorPage above).
function ReadingLocationTracker.setAnchor(ui, page)
    if ui._rlt_anchor ~= page then
        -- Only the page number drives this - not the xpointer twin computed
        -- below, which is purely derived from it and never changes
        -- independently. persistAnchor uses this to skip writing (and
        -- flushing) to disk when nothing has actually moved since the last
        -- save - relevant mainly for onSuspend, which would otherwise touch
        -- disk on every single sleep/wake cycle even if no page was turned
        -- in between.
        ui._rlt_anchor_dirty = true
    end
    ui._rlt_anchor = page
    if ui._rlt_is_rolling then
        local ok, xp = pcall(function() return ui.document:getPageXPointer(page) end)
        -- Explicitly reject nil/empty results (e.g. image-only pages, title
        -- pages with non-standard DOM nodes) rather than trusting whatever
        -- crengine handed back - an empty string is truthy in Lua, and
        -- resolveAnchorPage falling back to the raw page number is only
        -- reliable if we're the ones ruling this xpointer unusable, not
        -- something that only surfaces later as a failed lookup.
        ui._rlt_anchor_xpointer = (ok and type(xp) == "string" and xp ~= "" and xp) or nil
    end
end

-- Immediately persists the current anchor to disk, instead of waiting for
-- KOReader's own periodic/on-close save (see the ReaderUI:saveSettings hook
-- further down). Used only for the two explicit "accept this page" actions
-- - cancelling a prompt, and "Set current page as reading location" - so a
-- crash or forced kill right after one of those doesn't leave a stale
-- prompt to deal with on next launch. Deliberately NOT called from the
-- routine per-page-turn anchor advance, which runs on every single page
-- turn and would otherwise mean a disk write (and flush) on every one.
function ReadingLocationTracker.persistAnchor(ui)
    if not ui or not ui.doc_settings or ui._rlt_anchor == nil then
        return
    end
    if not ui._rlt_anchor_dirty then
        -- Nothing has moved since the last save (from either this function
        -- or KOReader's own periodic saveSettings) - skip touching disk
        -- entirely, rather than re-flushing an unchanged value. Matters
        -- most for onSuspend, which would otherwise write on every single
        -- sleep/wake cycle.
        return
    end
    local ok, err = pcall(function()
        ui.doc_settings:saveSetting("readingloc_anchor", ui._rlt_anchor)
        if ui._rlt_is_rolling then
            -- Save this unconditionally, even when nil - saveSetting(key,
            -- nil) clears it (same as delSetting; this is how KOReader's
            -- own code clears stale settings too, e.g. readerdictionary.lua).
            -- Only writing when truthy left a stale on-disk xpointer from an
            -- earlier anchor in place if a later anchor's xpointer came back
            -- empty (title/image-only page) - it would then wrongly take
            -- priority over the correct raw page number on next load, since
            -- a saved xpointer is trusted over the saved page (see
            -- onPageUpdate's initial-load resolution).
            ui.doc_settings:saveSetting("readingloc_anchor_xpointer", ui._rlt_anchor_xpointer)
        end
        if ui.doc_settings.flush then
            ui.doc_settings:flush()
        end
    end)
    if ok then
        ui._rlt_anchor_dirty = false
    else
        logger.warn("ReadingLocationTracker: persistAnchor error:", err)
    end
end

-- Forces a clean repaint of a screen region (used whenever we hide the
-- overlay outside of a normal page-turn, e.g. on cancel). setDirty(nil, ...)
-- only re-flashes whatever's already in the screen buffer without calling
-- any widget's paintTo again - since our button is baked directly into
-- ReaderView's own paintTo (not a separate window), that would just re-flash
-- the stale buffer with the button still in it. Passing the reader's own
-- top-level widget (ui.dialog, which ReaderUI sets to itself) marks it dirty
-- so paintTo actually reruns - skipping the button now that it's hidden -
-- before the flash. Uses a flashing refresh so no e-ink ghost is left.
local function refreshRegion(ui, region, refresh_type)
    if not region then
        return
    end
    UIManager:setDirty(ui.dialog or ui, function() return refresh_type or "flashui", region end)
end

-- Lets the settings submenu's checkboxes preview their effect on the
-- floating button immediately, without having to close the menu first.
-- Called with whether the button was visible *before* the toggle being
-- applied, since a callback may itself have just hidden it (or may be
-- about to make it visible again).
-- Refreshes a fixed, generous corner strip - matching the touch zones'
-- hit area - rather than the button's own (possibly now-stale) box_dimen,
-- since toggling a display setting can grow or shrink the button.
-- `refresh_type` defaults to a flashing refresh (to clear any e-ink ghost);
-- pass "ui" for a cheap non-flashing repaint, e.g. while a value is still
-- being dragged in a SpinWidget.
local function refreshFloatingButtonPreview(ui, was_visible, refresh_type)
    local overlay = ui._rlt_overlay
    if not was_visible and not (overlay and overlay.visible) then
        return
    end
    local region = Geom:new{
        x = 0, y = math.floor(Screen:getHeight() * 0.75),
        w = Screen:getWidth(), h = math.ceil(Screen:getHeight() * 0.25),
    }
    refreshRegion(ui, region, refresh_type)
end

-- Opens a SpinWidget to edit one of the button's offset settings, previewing
-- the change against the actual floating button as the value is dragged
-- (not just once "Apply" is tapped), and reverting it if the widget is
-- dismissed any other way (Cancel, tapping outside, the Back key).
-- `opts` (optional) overrides the spinner's bounds/default - used for the
-- button radius setting below, which needs a non-zero "reset" value (its
-- default is intentionally oversized so it resolves to a full pill - see
-- BUTTON_RADIUS_DEFAULT). Omitted entirely, this keeps its original 0-200,
-- default-0 behavior for the two offset settings.
local function showOffsetSpinWidget(ui, touchmenu_instance, title, info, get_offset, set_offset, opts)
    opts = opts or {}
    local original_value = get_offset()
    local applied = false
    local spin_widget
    spin_widget = SpinWidget:new{
        title_text = title,
        info_text = info,
        value = original_value,
        value_min = opts.value_min or 0,
        value_max = opts.value_max or 200,
        value_step = opts.value_step or 1,
        value_hold_step = opts.value_hold_step or 10,
        unit = "px",
        default_value = opts.default_value or 0,
        callback = function(spin)
            applied = true
            set_offset(spin.value)
        end,
        close_callback = function()
            if not applied then
                set_offset(original_value)
            end
            refreshFloatingButtonPreview(ui, ui._rlt_overlay and ui._rlt_overlay.visible)
            if touchmenu_instance then
                touchmenu_instance:updateItems()
            end
        end,
    }
    -- SpinWidget only runs `callback` once "Apply" is tapped; wrapping its
    -- own `update` (called on every tick, including hold-repeat) is the only
    -- way to preview it live. This live-updates the setting itself, but
    -- close_callback reverts it above if the widget wasn't actually applied.
    local orig_spin_update = spin_widget.update
    spin_widget.update = function(self, numberpicker_value, ...)
        orig_spin_update(self, numberpicker_value, ...)
        set_offset(numberpicker_value or self.value)
        refreshFloatingButtonPreview(ui, ui._rlt_overlay and ui._rlt_overlay.visible, "ui")
    end
    UIManager:show(spin_widget)
end

function ReadingLocationTracker.initOverlay(ui)
    if ui._rlt_overlay then
        return
    end
    local overlay = ReadingLocationOverlay:new{
        ui = ui,
        view = ui.view,
        visible = false,
    }
    overlay:setupTouchZones()
    ui._rlt_overlay = overlay
end

function ReadingLocationTracker.onCancel(ui)
    local overlay = ui._rlt_overlay
    local region = growRegionForShadow(overlay and overlay.box_dimen)
    -- Stop tracking the old position: accept wherever we currently are.
    ReadingLocationTracker.setAnchor(ui, ui._rlt_current_page or ui._rlt_anchor)
    ReadingLocationTracker.cancelForwardDismiss(ui)
    ui._rlt_forward_dismiss_pending = false
    if overlay then
        overlay.visible = false
    end
    refreshRegion(ui, region)
    ReadingLocationTracker.persistAnchor(ui)
end

function ReadingLocationTracker.onGoBack(ui)
    local overlay = ui._rlt_overlay
    local region = growRegionForShadow(overlay and overlay.box_dimen)
    -- Re-derive from the xpointer twin (rolling documents only) rather than
    -- trusting the last-known page number outright, in case a reflow
    -- happened since it was last refreshed - see resolveAnchorPage.
    local target_page = ReadingLocationTracker.resolveAnchorPage(ui)
    ReadingLocationTracker.cancelForwardDismiss(ui)
    ui._rlt_forward_dismiss_pending = false
    if overlay then
        overlay.visible = false
    end
    refreshRegion(ui, region)
    if target_page then
        ui:handleEvent(Event:new("GotoPage", target_page))
    end
end

-- Standalone system action: accepts the current page as the new reference
-- point on demand, regardless of whether the floating button is currently
-- showing (unlike onCancel, which only ever runs from an active overlay tap/
-- hold, where the button vanishing is already visible feedback). Shows a
-- notification here instead, since there's otherwise no visible confirmation.
function ReadingLocationTracker.setCurrentPageAsReadingLocation(ui)
    if not ui or type(ui._rlt_current_page) ~= "number" then
        return
    end
    local overlay = ui._rlt_overlay
    local region = overlay and overlay.visible and growRegionForShadow(overlay.box_dimen)
    ReadingLocationTracker.setAnchor(ui, ui._rlt_current_page)
    ReadingLocationTracker.cancelForwardDismiss(ui)
    ui._rlt_forward_dismiss_pending = false
    if overlay then
        overlay.visible = false
    end
    refreshRegion(ui, region)
    ReadingLocationTracker.persistAnchor(ui)
    UIManager:show(Notification:new{
        text = _("Current page set as reading location."),
    })
end

-- Whether the current page already IS the tracked reading location - true
-- when there's nothing to jump back to (goToFurthestReadingLocation) and
-- nothing new to set (setCurrentPageAsReadingLocation). Shared by both menu
-- entries' enabled_func, so they gray out instead of just no-op'ing/notifying
-- when tapped.
function ReadingLocationTracker.isAtReadingLocation(ui)
    local anchor = ui and ReadingLocationTracker.resolveAnchorPage(ui)
    local current = ui and ui._rlt_current_page
    return not anchor or anchor == current
end

function ReadingLocationTracker.goToFurthestReadingLocation(ui)
    if ReadingLocationTracker.isAtReadingLocation(ui) then
        UIManager:show(Notification:new{
            text = _("You're already at your furthest reading location."),
        })
        return
    end
    ReadingLocationTracker.onGoBack(ui)
end

-- Schedules the forward popup's auto-dismiss timer. Only called once per
-- forward-popup occurrence (see the was_showing_forward guard in
-- refreshOverlayVisibility below) - the countdown runs from when the popup
-- first appears, and is NOT restarted by every subsequent page turn while
-- it's still showing (which would mean it never fires as long as you kept
-- reading forward). A no-op if the setting is "Off".
--
-- UIManager:scheduleIn doesn't return a handle - the only way to cancel a
-- scheduled task later is to keep the exact function reference and pass
-- that same reference to UIManager:unschedule, which is why the task is
-- stored on ui._rlt_forward_dismiss_task before scheduling it.
function ReadingLocationTracker.scheduleForwardDismiss(ui)
    ReadingLocationTracker.cancelForwardDismiss(ui)
    local seconds = ReadingLocationTracker.getForwardDismissSeconds()
    if not seconds then
        return
    end
    local task
    task = function()
        -- Guards against a stale timer firing after the popup's already
        -- been resolved some other way (this won't be the current pending
        -- task anymore) or the book's been closed in the meantime.
        if ui._rlt_forward_dismiss_task ~= task then
            return
        end
        ui._rlt_forward_dismiss_task = nil
        local overlay = ui._rlt_overlay
        local region = overlay and overlay.visible and growRegionForShadow(overlay.box_dimen)
        if overlay then
            overlay.visible = false
        end
        -- Never touch the anchor here directly - only flag that the next
        -- real page turn should adopt wherever it lands as the new anchor,
        -- which onPageUpdate is what actually acts on. A bare timer firing
        -- is not itself evidence of where you are or that you're even still
        -- looking at the device.
        ui._rlt_forward_dismiss_pending = true
        refreshRegion(ui, region)
    end
    ui._rlt_forward_dismiss_task = task
    -- KOReader's scheduler uses a monotonic clock that doesn't tick during
    -- suspend, so this is `seconds` of the device actually being awake, not
    -- wall-clock time - a nap between now and then doesn't count against it.
    UIManager:scheduleIn(seconds, task)
end

function ReadingLocationTracker.cancelForwardDismiss(ui)
    if ui._rlt_forward_dismiss_task then
        UIManager:unschedule(ui._rlt_forward_dismiss_task)
        ui._rlt_forward_dismiss_task = nil
    end
end

-- Computes whether the floating button should currently be visible (and on
-- which side), purely from the tracked anchor/current-page state - without
-- touching the anchor itself. Shared by onPageUpdate (after a real page
-- turn) and by the settings submenu (to restore normal state once you're
-- done previewing - see the "hold for settings" hold_callback below, which
-- forces the button visible so its appearance can be previewed even when
-- you're already at the furthest reading location).
-- known_anchor: pass the anchor page if the caller already resolved it
-- moments ago (onPageUpdate does, right after setAnchor) - avoids a second,
-- redundant xpointer resolve for the same value. Left nil, this resolves it
-- itself (needed for the other caller, restoring the real display after a
-- settings preview, which doesn't already have a fresh one on hand).
function ReadingLocationTracker.refreshOverlayVisibility(ui, known_anchor)
    local overlay = ui._rlt_overlay
    if not overlay then
        return
    end
    local anchor = known_anchor or ReadingLocationTracker.resolveAnchorPage(ui)
    local current = ui._rlt_current_page
    local new_side = nil
    if anchor and current then
        if anchor - current > 1 then
            new_side = "bottom_right" -- drifted backward: offer to go forward again
        elseif current - anchor > 2 and not ui._rlt_forward_dismiss_pending then
            -- Suppressed once the forward popup has already auto-dismissed
            -- and is waiting for the next real page turn to promote the
            -- anchor (see scheduleForwardDismiss/onPageUpdate) - otherwise
            -- this same still-true gap would just show it again immediately,
            -- e.g. if the settings menu gets opened/closed during that gap.
            new_side = "bottom_left" -- jumped forward: offer to go back
        end
    end
    -- The forward-dismiss timer runs for a fixed window from when the popup
    -- first appears (see scheduleForwardDismiss's own comment on why it must
    -- not restart on every subsequent page turn) - only (re)schedule it on
    -- the transition into showing forward, not on every call that finds it
    -- already showing.
    local was_showing_forward = overlay.visible and overlay.side == "bottom_left"
    if new_side and ReadingLocationTracker.isFloatingButtonEnabled() then
        overlay.visible = true
        overlay.side = new_side
        overlay.anchor = anchor
        if new_side == "bottom_left" then
            if not was_showing_forward then
                ReadingLocationTracker.scheduleForwardDismiss(ui)
            end
        else
            ReadingLocationTracker.cancelForwardDismiss(ui)
        end
    else
        overlay.visible = false
        ReadingLocationTracker.cancelForwardDismiss(ui)
    end
end

-- Shared handler called from both ReaderPaging:onPageUpdate and
-- ReaderRolling:onPageUpdate. `is_rolling` tells us which one, so the
-- xpointer-based reflow safety net above only ever applies to reflowable
-- documents.
function ReadingLocationTracker.onPageUpdate(reader_module, new_page_no, is_rolling)
    local ui = reader_module.ui
    if not ui or type(new_page_no) ~= "number" then
        return
    end

    ReadingLocationTracker.initOverlay(ui)
    local previous_page = ui._rlt_current_page
    ui._rlt_current_page = new_page_no
    ui._rlt_is_rolling = is_rolling

    if ui._rlt_anchor == nil then
        -- First page update seen for this book: load the saved anchor (if
        -- any), falling back to the current page. This comparison is NOT
        -- skipped below - if a pending jump was saved from a previous
        -- session, the overlay can legitimately reappear right away.
        --
        -- For rolling documents, a saved xpointer takes priority over the
        -- saved raw page number - it's re-derived under whatever
        -- pagination is currently active, so a font/margin/line-spacing
        -- change made in a previous session doesn't leave the anchor
        -- pointing at stale content (see resolveAnchorPage above).
        local saved_page = ui.doc_settings and ui.doc_settings:readSetting("readingloc_anchor")
        if type(saved_page) ~= "number" then
            saved_page = nil
        end

        local resolved
        local saved_xp = is_rolling and ui.doc_settings and ui.doc_settings:readSetting("readingloc_anchor_xpointer")
        if type(saved_xp) == "string" then
            local ok, page = pcall(function() return ui.document:getPageFromXPointer(saved_xp) end)
            if ok and type(page) == "number" and page > 0 then
                resolved = page
                ui._rlt_anchor_xpointer = saved_xp
            end
        end

        if not resolved and saved_page then
            local page_count = ReadingLocationTracker.getPageCount(ui)
            if not page_count or (saved_page >= 1 and saved_page <= page_count) then
                resolved = saved_page
            end
        end

        ui._rlt_anchor = resolved or new_page_no
    end

    -- Re-derive the anchor's page number from its xpointer twin (rolling
    -- documents only) before doing the delta math below, so a reflow that
    -- happened earlier in this same session doesn't leave a stale number
    -- driving the button's visibility/label.
    local anchor = ReadingLocationTracker.resolveAnchorPage(ui)

    -- Fast-forward burst tracking (see FAST_TURN_MAX_INTERVAL_MS above):
    -- a burst "continues" from the previous page update if the two arrived
    -- within the interval, otherwise it restarts from wherever we already
    -- were (previous_page). previous_page is read before ui._rlt_current_page
    -- gets overwritten further up, so it's genuinely the page before this
    -- update, not this one.
    local now = time.now()
    local is_fast_turn = ui._rlt_last_turn_time ~= nil
        and time.to_ms(now - ui._rlt_last_turn_time) <= FAST_TURN_MAX_INTERVAL_MS
    if not is_fast_turn then
        ui._rlt_burst_start_page = previous_page or new_page_no
    end
    ui._rlt_last_turn_time = now
    local burst_forward_span = new_page_no - ui._rlt_burst_start_page

    if ui._rlt_forward_dismiss_pending then
        -- The forward popup already auto-dismissed and we've been waiting
        -- for the next page change to settle the anchor, bypassing the
        -- normal tolerance/burst check just this once. The timer itself
        -- deliberately never touches the anchor (see
        -- scheduleForwardDismiss) - this is the only place that acts on it.
        ui._rlt_forward_dismiss_pending = false
        local from_page = previous_page or new_page_no
        if math.abs(new_page_no - from_page) <= 2 then
            -- A normal page flip: wherever it lands is the new anchor.
            anchor = new_page_no
        else
            -- A jump (search, TOC, progress bar, link) isn't a page turn.
            -- The page you were sitting on when the popup timed out is what
            -- got accepted, so that's the anchor; the jump is then judged
            -- against it below like any other, so it gets its own popup.
            anchor = from_page
        end
    elseif anchor - new_page_no <= 1 and new_page_no - anchor <= 2 then
        -- A real fast skim is many small steps; one big jump (the go-back
        -- tap, progress bar, TOC) that happens to land near the anchor is
        -- a return, not a skim, so it must not roll the anchor back.
        local step = new_page_no - (previous_page or new_page_no)
        if burst_forward_span >= FAST_FORWARD_BURST_PAGES and step <= 2 then
            -- Each individual step here was small enough to silently
            -- advance on its own, but this many of them this close
            -- together add up to more page-flipping than anyone reads at.
            -- Roll the anchor back to where the burst started, rather than
            -- letting it silently trail just behind the current page - the
            -- pages skipped through during the burst weren't really read.
            anchor = ui._rlt_burst_start_page
        else
            -- Only ever advance forward. This is what makes "back one page
            -- at a time" accumulate correctly: a single page back stays
            -- inside the tolerated range, so the anchor must stay put
            -- rather than trailing one page behind on every tap.
            anchor = math.max(anchor, new_page_no)
        end
    end
    ReadingLocationTracker.setAnchor(ui, anchor)

    ReadingLocationTracker.refreshOverlayVisibility(ui, anchor)
end

--[[ ---------------------------------------------------------------------
     Hooks
----------------------------------------------------------------------- ]]

-- Paint the overlay as part of the normal page compositing (same spot
-- ReaderView paints its dogear/footer/page-flip overlays), so it never
-- becomes a separate top-level window that could swallow input.
local orig_view_paintTo = ReaderView.paintTo
ReaderView.paintTo = function(self, bb, x, y)
    orig_view_paintTo(self, bb, x, y)
    local ui = self.ui
    if ui and ui._rlt_overlay then
        ui._rlt_overlay:paintTo(bb, x, y)
    end
end

-- Most of KOReader's own modules (e.g. ReaderHighlight) register their
-- touch zones from onReaderReady, which fires once, right after every
-- reader module has finished initializing. setupTouchZones's override list
-- is a one-time snapshot of whatever's in ui._zones at the moment it runs
-- (see setupTouchZones), so doing our own setup here too - rather than only
-- lazily on the first page turn - means that snapshot is taken at the same
-- point KOReader's own zones are, and is less likely to miss one. This is a
-- coverage improvement, not a guarantee: a zone registered even later than
-- onReaderReady (rare, but possible for lazily-initialized modules) can
-- still end up ahead of ours. initOverlay is idempotent, so the original
-- call from onPageUpdate below still runs as a fallback either way.
local orig_ui_onReaderReady = ReaderUI.onReaderReady
ReaderUI.onReaderReady = function(self, ...)
    local ok, err = pcall(ReadingLocationTracker.initOverlay, self)
    if not ok then
        logger.warn("ReadingLocationTracker: onReaderReady error:", err)
    end
    if orig_ui_onReaderReady then
        return orig_ui_onReaderReady(self, ...)
    end
end

-- Explicit safety net for device suspend: `onFlushSettings` (KOReader's own
-- periodic/on-close save path) already calls `saveSettings`, which our hook
-- further below already extends to persist the xpointer twin too - so most
-- quit/close paths are already covered without anything extra here. Suspend
-- is a separate lifecycle event, though, and isn't guaranteed to run a full
-- settings flush before the screen sleeps, so this reuses the same
-- persistAnchor used for explicit "accept this page" actions.
local orig_ui_onSuspend = ReaderUI.onSuspend
ReaderUI.onSuspend = function(self, ...)
    local ok, err = pcall(ReadingLocationTracker.persistAnchor, self)
    if not ok then
        logger.warn("ReadingLocationTracker: onSuspend error:", err)
    end
    if orig_ui_onSuspend then
        return orig_ui_onSuspend(self, ...)
    end
end

-- A scheduled forward-dismiss timer (see scheduleForwardDismiss) holds a
-- closure over this specific `ui` instance, which would otherwise keep it
-- alive for as long as the timer is still pending even after the book's
-- closed. The timer callback already guards against acting on a stale/
-- superseded task, so this isn't a correctness issue, just a lifecycle one -
-- cancel it explicitly here rather than waiting out however long was left.
local orig_ui_onCloseDocument = ReaderUI.onCloseDocument
ReaderUI.onCloseDocument = function(self, ...)
    local ok, err = pcall(ReadingLocationTracker.cancelForwardDismiss, self)
    if not ok then
        logger.warn("ReadingLocationTracker: onCloseDocument error:", err)
    end
    if orig_ui_onCloseDocument then
        return orig_ui_onCloseDocument(self, ...)
    end
end

local function hookPageUpdate(module_name, is_rolling)
    local ok, Module = pcall(require, module_name)
    if not ok or not Module then
        logger.warn("ReadingLocationTracker: could not load", module_name)
        return
    end

    local orig_onPageUpdate = Module.onPageUpdate
    Module.onPageUpdate = function(self, new_page_no, ...)
        orig_onPageUpdate(self, new_page_no, ...)
        local ok_update, err = pcall(ReadingLocationTracker.onPageUpdate, self, new_page_no, is_rolling)
        if not ok_update then
            logger.warn("ReadingLocationTracker: onPageUpdate error:", err)
        end
    end
end

hookPageUpdate("apps/reader/modules/readerpaging", false)
hookPageUpdate("apps/reader/modules/readerrolling", true)

local orig_saveSettings = ReaderUI.saveSettings
ReaderUI.saveSettings = function(self, ...)
    if self._rlt_anchor then
        local ok, err = pcall(function()
            self.doc_settings:saveSetting("readingloc_anchor", self._rlt_anchor)
            if self._rlt_is_rolling then
                -- See the matching comment in persistAnchor above - this
                -- must run unconditionally (even for a nil xpointer) so a
                -- stale on-disk value from an earlier anchor can't outlive
                -- the current one.
                self.doc_settings:saveSetting("readingloc_anchor_xpointer", self._rlt_anchor_xpointer)
            end
        end)
        if ok then
            self._rlt_anchor_dirty = false
        else
            logger.warn("ReadingLocationTracker: saveSettings error:", err)
        end
    end
    return orig_saveSettings(self, ...)
end

-- Menu: "Go to furthest reading location" (tap = jump, hold = settings submenu with
-- the button-visibility toggle and its display checkboxes), right below
-- ReaderLink's own "Go forward to next location".
local orig_link_addToMainMenu = ReaderLink.addToMainMenu
ReaderLink.addToMainMenu = function(self, menu_items)
    orig_link_addToMainMenu(self, menu_items)

    local ui = self.ui
    menu_items.go_to_furthest_reading_location = {
        text = _("Reading location"),
        sub_item_table = {
            {
                text = _("Go to furthest reading location"),
                callback = function()
                    ReadingLocationTracker.goToFurthestReadingLocation(ui)
                end,
            },
            {
                text = _("Set current page as reading location"),
                enabled_func = function()
                    return not ReadingLocationTracker.isAtReadingLocation(ui)
                end,
                callback = function()
                    ReadingLocationTracker.setCurrentPageAsReadingLocation(ui)
                end,
            },
            {
                text = _("Settings"),
                -- Fixed id used below instead of deriving one from `item` -
                -- unlike hold_callback, a plain callback isn't guaranteed to
                -- receive the menu item table as its second argument (this
                -- crashed in the field: "attempt to index local 'item' (a
                -- nil value)" once this became a tap callback in v1.7.0).
                menu_item_id = "reading_location_settings",
                -- Without this, TouchMenu closes the whole menu right after
                -- a plain tap callback returns (unlike hold_callback, which
                -- doesn't auto-close) - undoing the manual submenu push
                -- below before it's ever visible. This is why "Settings"
                -- silently did nothing on tap once this became a plain
                -- callback in v1.7.0/v1.7.1.
                keep_menu_open = true,
                -- A normal `sub_item_table` on this row can't also run the
                -- preview setup below on tap (TouchMenu always opens
                -- sub_item_table instead of running callback), so this
                -- manually replicates what TouchMenu:onMenuSelect does for
                -- one, to open exactly like a native submenu (back
                -- navigation included) while still running that setup first.
                callback = function(touchmenu_instance)
                    local overlay = ui._rlt_overlay
                    -- Force the button to show while previewing these settings -
                    -- even if you're already at the furthest reading location, where it
                    -- wouldn't normally appear - so changes are visible right away
                    -- without needing an actual pending "go back" prompt to look at.
                    if overlay then
                        overlay.anchor = ui._rlt_current_page or overlay.anchor
                        overlay.side = overlay.side or "bottom_right"
                        overlay.visible = ReadingLocationTracker.isFloatingButtonEnabled()
                        -- Also show the mirrored docking, so both corners can be
                        -- compared while adjusting these settings.
                        overlay.preview_both_sides = true
                        refreshFloatingButtonPreview(ui, true)
                    end

                    -- However you leave this settings screen - going back up, or
                    -- closing the whole menu outright - stop forcing the preview
                    -- and let the button go back to reflecting the real page state,
                    -- as if these settings had never been touched.
                    local orig_backToUpperMenu = touchmenu_instance.backToUpperMenu
                    local orig_closeMenu = touchmenu_instance.closeMenu
                    local function exitPreview()
                        touchmenu_instance.backToUpperMenu = orig_backToUpperMenu
                        touchmenu_instance.closeMenu = orig_closeMenu
                        if overlay then
                            overlay.preview_both_sides = false
                        end
                        ReadingLocationTracker.refreshOverlayVisibility(ui)
                        refreshFloatingButtonPreview(ui, true)
                    end
                    touchmenu_instance.backToUpperMenu = function(self, ...)
                        exitPreview()
                        return orig_backToUpperMenu(self, ...)
                    end
                    touchmenu_instance.closeMenu = function(self, ...)
                        exitPreview()
                        return orig_closeMenu(self, ...)
                    end

                    local sub_item_table = {
                        {
                            text = _("Show button on screen"),
                            checked_func = function()
                                return ReadingLocationTracker.isFloatingButtonEnabled()
                            end,
                            callback = function()
                                local enabled = not ReadingLocationTracker.isFloatingButtonEnabled()
                                ReadingLocationTracker.setFloatingButtonEnabled(enabled)
                                if not enabled then
                                    -- Nothing left to dismiss/promote on the button's
                                    -- behalf once it's off - stop a still-running
                                    -- timer from doing either later regardless.
                                    ReadingLocationTracker.cancelForwardDismiss(ui)
                                    ui._rlt_forward_dismiss_pending = false
                                end
                                -- Directly tied to this setting while previewing, so
                                -- it appears/disappears the moment you toggle it.
                                if ui._rlt_overlay then
                                    ui._rlt_overlay.visible = enabled
                                end
                                refreshFloatingButtonPreview(ui, true)
                            end,
                        },
                        {
                            text_func = function()
                                return T(_("Mode: %1"), ReadingLocationTracker.isPercentageModeEnabled()
                                    and _("Percentage") or _("Page number"))
                            end,
                            -- No checked_func on this item (it's a cycling text
                            -- toggle, not a checkbox), so TouchMenu:onMenuSelect
                            -- would otherwise close the menu on tap - and, since it
                            -- also skips the auto-updateItems() it does for checked/
                            -- checked_func items, the text_func label needs a manual
                            -- refresh here too, or it'd keep showing the old mode.
                            keep_menu_open = true,
                            callback = function(touchmenu_instance)
                                ReadingLocationTracker.setPercentageModeEnabled(not ReadingLocationTracker.isPercentageModeEnabled())
                                refreshFloatingButtonPreview(ui, ui._rlt_overlay and ui._rlt_overlay.visible)
                                if touchmenu_instance then
                                    touchmenu_instance:updateItems()
                                end
                            end,
                        },
                        {
                            text = _("Show full text"),
                            checked_func = function()
                                return ReadingLocationTracker.isFullTextEnabled()
                            end,
                            callback = function()
                                ReadingLocationTracker.setFullTextEnabled(not ReadingLocationTracker.isFullTextEnabled())
                                refreshFloatingButtonPreview(ui, ui._rlt_overlay and ui._rlt_overlay.visible)
                            end,
                        },
                        {
                            text = _("Show location/page number"),
                            -- "Go back to page"/"Go back to" doesn't make sense
                            -- without a value next to it, so this is forced on (and
                            -- locked) while "Show full text" is on - see
                            -- isPageNumberEnabled().
                            enabled_func = function()
                                return not ReadingLocationTracker.isFullTextEnabled()
                            end,
                            checked_func = function()
                                return ReadingLocationTracker.isPageNumberEnabled()
                            end,
                            callback = function()
                                ReadingLocationTracker.setPageNumberEnabled(not ReadingLocationTracker.isPageNumberEnabled())
                                refreshFloatingButtonPreview(ui, ui._rlt_overlay and ui._rlt_overlay.visible)
                            end,
                        },
                        {
                            text_func = function()
                                return _("Show dismiss button") .. (ReadingLocationTracker.isDismissButtonEnabled() and "" or " (hold to dismiss)")
                            end,
                            checked_func = function()
                                return ReadingLocationTracker.isDismissButtonEnabled()
                            end,
                            callback = function()
                                ReadingLocationTracker.setDismissButtonEnabled(not ReadingLocationTracker.isDismissButtonEnabled())
                                refreshFloatingButtonPreview(ui, ui._rlt_overlay and ui._rlt_overlay.visible)
                            end,
                        },
                        {
                            text = _("Show shadow"),
                            checked_func = function()
                                return ReadingLocationTracker.isShadowEnabled()
                            end,
                            callback = function()
                                ReadingLocationTracker.setShadowEnabled(not ReadingLocationTracker.isShadowEnabled())
                                refreshFloatingButtonPreview(ui, ui._rlt_overlay and ui._rlt_overlay.visible)
                            end,
                        },
                        {
                            text_func = function()
                                local seconds = ReadingLocationTracker.getForwardDismissSeconds()
                                return T(_("Forward popup auto-dismiss: %1"),
                                    seconds and T(_("%1s"), seconds) or _("Off"))
                            end,
                            sub_item_table = {
                                {
                                    text = _("Off"),
                                    radio = true,
                                    checked_func = function()
                                        return ReadingLocationTracker.getForwardDismissSeconds() == nil
                                    end,
                                    callback = function()
                                        ReadingLocationTracker.setForwardDismissSeconds(nil)
                                    end,
                                },
                                {
                                    text = _("15 seconds"),
                                    radio = true,
                                    checked_func = function()
                                        return ReadingLocationTracker.getForwardDismissSeconds() == 15
                                    end,
                                    callback = function()
                                        ReadingLocationTracker.setForwardDismissSeconds(15)
                                    end,
                                },
                                {
                                    text = _("20 seconds"),
                                    radio = true,
                                    checked_func = function()
                                        return ReadingLocationTracker.getForwardDismissSeconds() == 20
                                    end,
                                    callback = function()
                                        ReadingLocationTracker.setForwardDismissSeconds(20)
                                    end,
                                },
                                {
                                    text = _("30 seconds"),
                                    radio = true,
                                    checked_func = function()
                                        return ReadingLocationTracker.getForwardDismissSeconds() == 30
                                    end,
                                    callback = function()
                                        ReadingLocationTracker.setForwardDismissSeconds(30)
                                    end,
                                },
                                {
                                    text = _("50 seconds"),
                                    radio = true,
                                    checked_func = function()
                                        return ReadingLocationTracker.getForwardDismissSeconds() == 50
                                    end,
                                    callback = function()
                                        ReadingLocationTracker.setForwardDismissSeconds(50)
                                    end,
                                },
                            },
                        },
                        {
                            text_func = function()
                                return T(_("Bottom offset: %1"), ReadingLocationTracker.getBottomOffset())
                            end,
                            keep_menu_open = true,
                            callback = function(touchmenu_instance)
                                showOffsetSpinWidget(ui, touchmenu_instance,
                                    _("Bottom offset"),
                                    _("Extra distance the button is docked away from the bottom edge of the screen, on top of the footer's own height when it's visible. Applies to both corners."),
                                    ReadingLocationTracker.getBottomOffset,
                                    ReadingLocationTracker.setBottomOffset)
                            end,
                        },
                        {
                            text_func = function()
                                return T(_("Side offset: %1"), ReadingLocationTracker.getSideOffset())
                            end,
                            keep_menu_open = true,
                            callback = function(touchmenu_instance)
                                showOffsetSpinWidget(ui, touchmenu_instance,
                                    _("Side offset"),
                                    _("Extra distance the button is docked away from the left/right edge of the screen, whichever corner it's currently in. Applies to both corners."),
                                    ReadingLocationTracker.getSideOffset,
                                    ReadingLocationTracker.setSideOffset)
                            end,
                        },
                        {
                            text_func = function()
                                return T(_("Button radius: %1"), ReadingLocationTracker.getButtonRadius())
                            end,
                            keep_menu_open = true,
                            callback = function(touchmenu_instance)
                                showOffsetSpinWidget(ui, touchmenu_instance,
                                    _("Button radius"),
                                    _("Corner roundness of the button, from 0 (square) up to fully rounded (pill/circle)."),
                                    ReadingLocationTracker.getButtonRadius,
                                    ReadingLocationTracker.setButtonRadius,
                                    { value_max = BUTTON_RADIUS_DEFAULT, default_value = BUTTON_RADIUS_DEFAULT })
                            end,
                        },
                    }
                    table.insert(touchmenu_instance.item_table_stack, touchmenu_instance.item_table)
                    touchmenu_instance.parent_id = "reading_location_settings"
                    touchmenu_instance.item_table = sub_item_table
                    touchmenu_instance:updateItems(1)
                end,
            },
        },
    }
end

-- Place the group entry right after "go_to_next_location" in the reader's
-- Navigation submenu - it contains "Go to furthest reading location",
-- "Set current page as reading location", and "Settings" as its three rows.
local ok_order, reader_menu_order = pcall(require, "ui/elements/reader_menu_order")
if ok_order and reader_menu_order and reader_menu_order.navi then
    local navi = reader_menu_order.navi
    local already_inserted = false
    for _, key in ipairs(navi) do
        if key == "go_to_furthest_reading_location" then
            already_inserted = true
            break
        end
    end

    -- Guards against a duplicate menu entry if this file gets require()'d
    -- more than once in the same session (e.g. reloading patches during
    -- development without a full restart) - normal single-boot loading is
    -- unaffected, since already_inserted is always false the first time.
    if not already_inserted then
        local insert_at = #navi + 1
        for i, key in ipairs(navi) do
            if key == "go_to_previous_location" then
                insert_at = i
                break
            end
        end

        table.insert(navi, insert_at, "go_to_furthest_reading_location")
    end
end

-- Register as a dispatchable action so it can be bound to a gesture, a
-- profile, or a physical button via KOReader's gesture manager.
Dispatcher:registerAction("go_to_furthest_reading_location", {
    category = "none",
    event = "GoToFurthestReadingLocation",
    title = _("Go to furthest reading location"),
    reader = true,
})

ReaderUI.onGoToFurthestReadingLocation = function(self)
    ReadingLocationTracker.goToFurthestReadingLocation(self)
    return true
end

-- Register as a second, standalone dispatchable action - not tied to any
-- menu entry - so the current page can be accepted as the new reference
-- point directly from a gesture, profile, or physical button, without first
-- needing an active "go back" prompt to dismiss.
Dispatcher:registerAction("set_current_page_as_reading_location", {
    category = "none",
    event = "SetCurrentPageAsReadingLocation",
    title = _("Set current page as reading location"),
    reader = true,
})

ReaderUI.onSetCurrentPageAsReadingLocation = function(self)
    ReadingLocationTracker.setCurrentPageAsReadingLocation(self)
    return true
end

logger.info("ReadingLocationTracker Patch: v" .. PATCH_VERSION .. " loaded")
