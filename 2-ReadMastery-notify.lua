--[[--
ReadMastery - Notification Style Patch
=======================================

Version: 1.0.6

Drop this file, unmodified plugin included, into your KOReader
`patches/` folder:

    Kindle:   /koreader/patches/
    Kobo:     /.adds/koreader/patches/
    Android:  /sdcard/koreader/patches/
    Desktop:  ~/.config/koreader/patches/

Then restart KOReader. It does NOT edit any ReadMastery plugin
file - it patches it in memory at runtime. Delete this file (or
move it out of patches/) at any time to fully revert to stock
ReadMastery behaviour.

IMPORTANT: the filename prefix matters. KOReader only scans patch
files whose name starts with a supported priority number (0, 1, 2,
8, or 9) - "2-" is the one that runs after the UI is ready, which
is what these patches need. Keep the "2-" prefix.

Three top-level toggles above the settings menu:
  * Notifications             - master ON/OFF for everything below
  * Nudges                    - 80%/90% "almost there" notices from
                                 the quest patch (informational only,
                                 no XP). Greyed out whenever
                                 Notifications is off, since nudges
                                 are delivered through the same
                                 render pipeline.
  * Critter Reacts (SimpleUI) - SimpleUI 3.0's Critter (home screen
                                 module) comments on level ups,
                                 achievements, streak milestones and
                                 completed quests the next time it's
                                 on screen, gets a little happier for
                                 each, and can offer one of today's
                                 daily quests in its chat (quest
                                 patch 1.0.6+, Quests (Enhanced) on).
                                 Near the end of the week / month it
                                 nudges toward a quest still in reach
                                 (finish your closest-to-done book,
                                 pages or minutes to go).
                                 Default ON; does nothing without the
                                 Critter. Independent of Notifications.

Everything else lives under ReadMastery -> Settings -> Notification
Settings (greyed out while "Notifications" above it is off):
  * Full / Compact / Banner   - notification style
        Full    = ReadMastery's original popup (tap to dismiss)
        Compact = a small centered box (auto-dismiss or tap) - a
                  custom widget, so it can mix your chosen font for
                  text with a monospace font for achievement art
        Banner  = a corner or full-width toast that auto-dismisses
                  and never blocks reading/page-turns
  * Banner Position           - Top Left / Top Right / Bottom Left /
                                 Bottom Right / Full Width (Top) /
                                 Full Width (Bottom) (Banner style
                                 only; the two Full Width options are
                                 a slim edge-to-edge strip, not a big
                                 centered box)
  * Duration                  - how long Compact/Banner stay up
  * Font                      - grouped list of fonts already on
                                 your device, or KOReader's default
  * Preview Notification      - fires a real Level 1 level-up
                                 notification using everything above,
                                 so you can check changes without
                                 waiting for a real one

Level Up notifications also show a cosmetic title badge at certain
milestone levels (e.g. "Established Reader" at 10) - flavor text
only, no XP or gameplay effect.

Achievement notifications (Compact/Banner only) show that
achievement's own small pixel-art icon (from ReadMastery's own
ascii_art.lua), rendered in a monospace font so it doesn't distort,
alongside your chosen font for the name/description. All
notifications also use a few of ReadMastery's own plain-ASCII icon
tags (from icons.lua) for a bit of flair - these are always on.
"Full" style is untouched and still shows ReadMastery's original
large ASCII art popup.

If more than one notification fires close together (e.g. several
quests completing at once, via the quest patch), Compact/Banner
notifications queue and show one at a time instead of overlapping.

All settings are stored in their own file
(settings/ReadMastery_notify.lua), completely separate from
ReadMastery's own data file.

Changelog:
  1.0.6 (2026-10-24) - SimpleUI Critter: new "Critter Reacts (SimpleUI)"
    toggle (default ON). Level ups, achievements (tier ups too), streak
    milestones and completed quests wait for SimpleUI 3.0's Critter,
    which comments on the most important one the next time the home
    screen shows it (a finished book still comes first) and gets a
    little happier. In its chat the Critter
    can offer one of today's daily quests ("I'll do it" / "Not today" /
    "What's in it for me?") and later ask how it's going; finishing a
    quest you said you'd do gets its own line. Near the end of the week
    (last 2 days), month (last 5) or a seasonal quest's month (last 7),
    it nudges once a day toward a quest still in reach: a "finish N
    books" quest one book short with your closest-to-done book named
    ("4 days left for Bibliophile. The Hobbit is 91% done."), the
    seasonal book quest, or pages / minutes still to go - in its bubble
    and as a chat ("Let's finish it" / "Which book?" / "Not this
    time"). Uses SimpleUI's own
    critter files, nothing on a timer. ReadMastery's popups unchanged.
  1.0.5 (2026-10-22) - A tap on a Banner toast itself now only dismisses
    it. It also reached whatever was underneath: with the toast in the
    top-right corner, dismissing a quest toast fired the reader's
    top-right corner gesture (here, "set current page as reading
    location", which moved the saved location). Taps and swipes
    elsewhere still close the toast and go through as before.
  1.0.4 (2026-10-11) - Title case for all user-facing menu texts, per
    the shared convention: style options, banner position label,
    duration options ("2 Seconds"), and the font picker's default
    entry. Notification/toast strings untouched.
  1.0.3 (2026-10-11) - Shared notification contract v1: publishes
    _G.__readmastery_note(text, timeout) on successful install, so
    other patches can show a status note in the user's chosen style
    (Banner with configured position, timeout overriding duration;
    Compact/Full fall through to the CompactBox modal, same as
    dispatch()). Not gated on the Notifications toggle - fires
    whenever the patch is installed. Returns true when shown.
  1.0.2 (2026-10-09) - Restored the one-shot guard on the achievement
    detail popup's close hook, so a double onCloseWidget fire (tap plus
    a second close path) can't reopen the achievements list twice.
  1.0.1 (2026-10-02) - Full style now always delegates streak-milestone
    notifications to the real plugin, even for milestone days this file
    doesn't have hardcoded itself (previously these were silently
    dropped under Full style). Preview's Full-style path no longer
    passes a bare nil for self. The whole one-time setup is now
    wrapped so a failure anywhere in it shows a visible error and can
    retry, instead of failing silently and uncaught.
  1.0.0 (2026-10-02) - First release.
--]]--

local userpatch  = require("userpatch")
local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local UIManager   = require("ui/uimanager")
local Blitbuffer  = require("ffi/blitbuffer")
local BottomContainer = require("ui/widget/container/bottomcontainer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device      = require("device")
local Font        = require("ui/font")
local FontList    = require("fontlist")
local FrameContainer  = require("ui/widget/container/framecontainer")
local Geom        = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local InfoMessage = require("ui/widget/infomessage")
local InputContainer  = require("ui/widget/container/inputcontainer")
local RectSpan    = require("ui/widget/rectspan")
local Size        = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget    = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan  = require("ui/widget/verticalspan")
local logger      = require("logger")
local Input  = Device.input
local Screen = Device.screen

-- The only version number that actually matters at runtime - the
-- header comment above is for humans reading the file; this is what
-- the menu's version line and the startup log entry below both
-- display, so they can never drift out of sync with each other.
local PATCH_VERSION = "1.0.6"

-- =================================================================
-- Settings (own file - ReadMastery's own data.json is never touched)
-- =================================================================

local settings = LuaSettings:open(DataStorage:getSettingsDir() .. "/ReadMastery_notify.lua")

local Notify = {
    enabled   = settings:nilOrTrue("enabled"),                   -- default: true
    style     = settings:readSetting("style") or "banner",       -- "full" | "compact" | "banner"
    duration  = settings:readSetting("duration") or 4,           -- seconds
    position  = settings:readSetting("position") or "right",     -- "left" | "right" | "full_top" | "full_bottom"
    font_path = settings:readSetting("font_path"),                -- nil = KOReader default UI font
    nudges_enabled = settings:nilOrTrue("nudges_enabled"),        -- default: true; 80%/90% "almost there" notices from the quest patch
}

local function saveSetting(key, value)
    settings:saveSetting(key, value)
    settings:flush()
end

-- Font:getFace() returns nil (not an error) if the file is missing,
-- e.g. a previously-selected custom font got deleted from the
-- device. Fall back to the built-in default instead of handing a
-- nil face to TextWidget (which would error), and forget the bad
-- selection so this doesn't keep happening every notification.
local function safeFace(font_path, fallback_key, size)
    if font_path then
        local face = Font:getFace(font_path, size)
        if face then return face end
        Notify.font_path = nil
        saveSetting("font_path", nil)
    end
    return Font:getFace(fallback_key, size)
end

-- =================================================================
-- Font picker helper - lists fonts actually present on this device,
-- grouped alphabetically so the menu doesn't become one giant list
-- =================================================================

local function getFontChoices()
    local choices = {}
    local seen = {}
    local ok, files = pcall(function() return FontList:getFontList() end)
    if ok and files then
        for _, path in ipairs(files) do
            local base = path:match("([^/]+)$") or path
            local label = base:gsub("%.[%a%d]+$", "")
            if not seen[label] then
                seen[label] = true
                table.insert(choices, { label = label, path = path })
            end
        end
    end
    table.sort(choices, function(a, b) return a.label < b.label end)
    return choices
end

local FONT_GROUPS = {
    { label = "A - E",         from = "A", to = "E" },
    { label = "F - J",         from = "F", to = "J" },
    { label = "K - O",         from = "K", to = "O" },
    { label = "P - T",         from = "P", to = "T" },
    { label = "U - Z / Other", from = "U", to = "Z" },
}

local function buildFontMenu()
    local font_menu = {
        {
            text = "Default (KOReader UI Font)",
            radio = true,
            checked_func = function() return Notify.font_path == nil end,
            callback = function()
                Notify.font_path = nil
                saveSetting("font_path", nil)
            end,
            keep_menu_open = true,
        },
    }

    local buckets = {}
    for _, g in ipairs(FONT_GROUPS) do buckets[g.label] = {} end
    local other_label = FONT_GROUPS[#FONT_GROUPS].label

    for _, choice in ipairs(getFontChoices()) do
        local first = choice.label:sub(1, 1):upper()
        local placed = false
        for _, g in ipairs(FONT_GROUPS) do
            if first >= g.from and first <= g.to then
                table.insert(buckets[g.label], choice)
                placed = true
                break
            end
        end
        if not placed then
            table.insert(buckets[other_label], choice)
        end
    end

    for _, g in ipairs(FONT_GROUPS) do
        local list = buckets[g.label]
        if #list > 0 then
            local sub = {}
            for _, choice in ipairs(list) do
                table.insert(sub, {
                    text = choice.label,
                    radio = true,
                    checked_func = function() return Notify.font_path == choice.path end,
                    callback = function()
                        Notify.font_path = choice.path
                        saveSetting("font_path", choice.path)
                    end,
                    keep_menu_open = true,
                })
            end
            table.insert(font_menu, {
                text = g.label .. " (" .. #list .. ")",
                sub_item_table = sub,
            })
        end
    end

    return font_menu
end

-- =================================================================
-- Shared: builds the "content" stack (title / ascii art / body text)
-- used by both Banner and CompactBox. Ascii art always renders in a
-- monospace font (DroidSansMono, via "infont") regardless of the
-- chosen font, since a proportional font would distort the pixel
-- art; only the title/body use the chosen font.
-- =================================================================

local function buildContentGroup(title, text, ascii_art, font_path, content_width, is_full)
    local title_span = is_full and (Size.padding.small and math.floor(Size.padding.small / 2) or 2)
                                 or (Size.padding.small or 4)
    local content = VerticalGroup:new{ align = "left" }
    if title then
        table.insert(content, TextWidget:new{
            text = title,
            face = safeFace(font_path, "smallinfofontbold", 22),
            bold = true,
            max_width = content_width,
        })
        table.insert(content, VerticalSpan:new{ width = title_span })
    end
    if ascii_art then
        table.insert(content, TextBoxWidget:new{
            text = ascii_art,
            face = Font:getFace("infont", 14),
            width = content_width,
        })
        table.insert(content, VerticalSpan:new{ width = title_span })
    end
    table.insert(content, TextBoxWidget:new{
        text = text,
        face = safeFace(font_path, "smallinfofont", 22),
        width = content_width,
    })
    return content
end

-- =================================================================
-- Small "toast" banner: auto-dismisses, never blocks input.
-- position: "left" / "right" (top corners) or "full_top" / "full_bottom"
-- (the full-width ones use tighter padding/spacing for a slim,
-- edge-to-edge strip rather than a big stretched box)
-- =================================================================

local Banner = InputContainer:extend{
    title = nil,
    text = "",
    ascii_art = nil,
    timeout = 4,
    position = "right",
    font_path = nil,      -- nil = KOReader default UI font
    width_ratio = 0.55,   -- only used for the corner (left/right) styles
    on_close = nil,       -- optional callback, used by the notification queue
    _timeout_func = nil,
    _closed = false,
}

function Banner:init()
    local is_full = (self.position == "full_top" or self.position == "full_bottom")
    local margin = Size.margin.default * 2
    local frame_padding = is_full and (Size.padding.default or 8) or (Size.padding.large or 15)
    local bordersize = Size.border.window or 1

    local content_width
    if is_full then
        -- FrameContainer's total width = content + 2*padding + 2*bordersize,
        -- so bordersize has to come off content_width too, or the frame
        -- ends up a few px wider than the screen instead of flush.
        content_width = Screen:getWidth() - (frame_padding * 2) - (bordersize * 2)
    else
        local max_width = math.floor(Screen:getWidth() * self.width_ratio)
        content_width = max_width - (frame_padding * 2)
    end

    local content = buildContentGroup(self.title, self.text, self.ascii_art, self.font_path, content_width, is_full)

    self.frame = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        radius = is_full and 0 or (Size.radius.window or 6),
        bordersize = bordersize,
        padding = frame_padding,
        margin = 0,
        content,
    }

    if self.position == "left" then
        self[1] = VerticalGroup:new{
            align = "left",
            RectSpan:new{ width = Screen:getWidth(), height = margin },
            HorizontalGroup:new{
                HorizontalSpan:new{ width = margin },
                self.frame,
            },
        }
    elseif self.position == "right" then
        self[1] = VerticalGroup:new{
            align = "right",
            RectSpan:new{ width = Screen:getWidth() - margin, height = margin },
            self.frame,
        }
    elseif self.position == "bottom_left" or self.position == "bottom_right" then
        -- Same corner-alignment trick as top-left/top-right, just with
        -- a computed tall filler span instead of a small top margin,
        -- to push the frame down near the bottom while keeping it
        -- corner-aligned. BottomContainer isn't used here since it
        -- always centers horizontally - fine for the full-width
        -- banners below, but not for a corner placement.
        local frame_size = self.frame:getSize()
        local filler_height = math.max(0, Screen:getHeight() - frame_size.h - margin)
        if self.position == "bottom_left" then
            self[1] = VerticalGroup:new{
                align = "left",
                RectSpan:new{ width = Screen:getWidth(), height = filler_height },
                HorizontalGroup:new{
                    HorizontalSpan:new{ width = margin },
                    self.frame,
                },
            }
        else
            self[1] = VerticalGroup:new{
                align = "right",
                RectSpan:new{ width = Screen:getWidth() - margin, height = filler_height },
                self.frame,
            }
        end
    elseif self.position == "full_top" then
        self[1] = self.frame -- already full width; paints flush top-left
    else -- "full_bottom"
        self[1] = BottomContainer:new{
            dimen = Geom:new{ w = Screen:getWidth(), h = Screen:getHeight() },
            self.frame,
        }
    end

    if Device:hasKeys() then
        self.key_events.AnyKeyPressed = { { Input.group.Any } }
    end
end

function Banner:onShow()
    UIManager:setDirty(self, function() return "ui", self.frame.dimen end)
    if self.timeout then
        self._timeout_func = function()
            self._timeout_func = nil
            UIManager:close(self)
        end
        UIManager:scheduleIn(self.timeout, self._timeout_func)
    end
    return true
end

function Banner:onCloseWidget()
    UIManager:setDirty(nil, function() return "ui", self.frame.dimen end)
    if self._timeout_func then
        UIManager:unschedule(self._timeout_func)
        self._timeout_func = nil
    end
    if self.on_close and not self._closed then
        self._closed = true
        self.on_close()
    end
end

function Banner:onTapClose()
    UIManager:close(self)
    return false -- let the tap still reach whatever is underneath
end
Banner.onAnyKeyPressed = Banner.onTapClose

function Banner:onKeyPress(key)
    UIManager:close(self)
    return false
end
Banner.onKeyRepeat = Banner.onKeyPress

-- Any gesture closes the toast. Elsewhere on the screen it still goes
-- through (a page-turn tap turns the page). A tap or hold ON the toast
-- only dismisses it: it used to reach what's underneath too, e.g. the
-- reader's corner gesture behind a top-right toast.
local ON_TOAST = { tap = true, hold = true, double_tap = true, hold_release = true }
function Banner:onGesture(ev)
    UIManager:close(self)
    local pos = type(ev) == "table" and ev.pos
    local d = self.frame and self.frame.dimen
    if pos and d and d.x and ON_TOAST[ev.ges]
            and pos.x >= d.x and pos.x < d.x + d.w
            and pos.y >= d.y and pos.y < d.y + d.h then
        return true
    end
    return false
end

function Banner:onIgnoreTouchInput() return true end
Banner.onResume = Banner.onIgnoreTouchInput
Banner.onPhysicalKeyboardDisconnected = Banner.onIgnoreTouchInput
Banner.onInput = Banner.onIgnoreTouchInput

-- =================================================================
-- CompactBox: a small centered dialog, like the stock InfoMessage,
-- but built ourselves so it can mix a monospace face (for
-- achievement art) with your chosen font (for title/body) in the
-- same box - the stock InfoMessage only supports one face for all
-- of its text.
-- =================================================================

local CompactBox = InputContainer:extend{
    title = nil,
    text = "",
    ascii_art = nil,
    timeout = 4,
    font_path = nil,
    width_ratio = 0.55,
    on_close = nil,        -- optional callback, used by the notification queue
    _timeout_func = nil,
    _closed = false,
}

function CompactBox:init()
    local frame_padding = Size.padding.large or 15
    local max_width = math.floor(Screen:getWidth() * self.width_ratio)
    local content_width = max_width - (frame_padding * 2)

    local content = buildContentGroup(self.title, self.text, self.ascii_art, self.font_path, content_width, false)

    self.frame = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        radius = Size.radius.window or 6,
        bordersize = Size.border.window or 1,
        padding = frame_padding,
        margin = 0,
        content,
    }

    self[1] = CenterContainer:new{
        dimen = Screen:getSize(),
        self.frame,
    }

    if Device:isTouchDevice() then
        self.ges_events.TapClose = {
            GestureRange:new{
                ges = "tap",
                range = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() },
            }
        }
    end
    if Device:hasKeys() then
        self.key_events.AnyKeyPressed = { { Input.group.Any } }
    end
end

function CompactBox:onShow()
    UIManager:setDirty(self, function() return "ui", self.frame.dimen end)
    if self.timeout then
        self._timeout_func = function()
            self._timeout_func = nil
            UIManager:close(self)
        end
        UIManager:scheduleIn(self.timeout, self._timeout_func)
    end
    return true
end

function CompactBox:onCloseWidget()
    UIManager:setDirty(nil, function() return "ui", self.frame.dimen end)
    if self._timeout_func then
        UIManager:unschedule(self._timeout_func)
        self._timeout_func = nil
    end
    if self.on_close and not self._closed then
        self._closed = true
        self.on_close()
    end
end

-- Unlike Banner, CompactBox is a deliberate modal dialog (matches
-- the original "tap or wait" Compact behaviour), so taps/keys are
-- swallowed rather than passed through.
function CompactBox:onTapClose()
    UIManager:close(self)
    return true
end
CompactBox.onAnyKeyPressed = CompactBox.onTapClose

-- =================================================================
-- Notification queue - shows one Banner/CompactBox at a time so
-- several notifications firing close together (e.g. multiple quests
-- completing from the same page turn) don't visually overlap.
-- =================================================================

local notify_queue = {}
local notify_active = false

local function showNextQueued()
    if notify_active then return end
    local item = table.remove(notify_queue, 1)
    if not item then return end
    notify_active = true

    -- No separate gap constant: Duration (how long each notification
    -- stays up, whether it closes by timeout or a tap) is what paces
    -- the queue. nextTick is just a safety deferral, not a real wait -
    -- showing the next one synchronously inside the same tap that
    -- just closed the current one risks the same flash-and-instantly-
    -- close bug the detail popups had.
    local function onDone()
        notify_active = false
        UIManager:nextTick(showNextQueued)
    end

    -- Wrapped in pcall so a widget that fails to build/show (e.g. a
    -- font error) can't permanently stick the queue - without this,
    -- notify_active would stay true forever since onDone would never
    -- get called, and every notification after it would silently
    -- pile up and never show.
    local ok = pcall(function()
        if item.kind == "compact" then
            UIManager:show(CompactBox:new{
                title = item.title,
                text = item.text,
                ascii_art = item.ascii_art,
                timeout = item.duration,
                font_path = item.font_path,
                on_close = onDone,
            })
        else
            UIManager:show(Banner:new{
                title = item.title,
                text = item.text,
                ascii_art = item.ascii_art,
                timeout = item.duration,
                position = item.position,
                font_path = item.font_path,
                on_close = onDone,
            })
        end
    end)
    if not ok then
        notify_active = false
        UIManager:nextTick(showNextQueued)
    end
end

-- Snapshot ALL display settings (style already fixed at enqueue via
-- "kind" - position/font/duration used to be re-read fresh from
-- Notify at display time instead, so changing a setting while
-- something was still queued gave that queued item a mismatched mix
-- of old and new settings. Now the whole look is locked in at the
-- moment it's queued, consistently.
--
-- MAX_QUEUE is a defensive cap, not an expected ceiling - normal use
-- never gets close. If it's ever hit, drop the OLDEST pending item
-- rather than let an unbounded backlog pile up.
local MAX_QUEUE = 15

local function enqueue(kind, title, text, ascii_art, duration_override)
    if #notify_queue >= MAX_QUEUE then
        table.remove(notify_queue, 1)
    end
    table.insert(notify_queue, {
        kind = kind, title = title, text = text, ascii_art = ascii_art,
        duration = duration_override or Notify.duration,
        position = Notify.position, font_path = Notify.font_path,
    })
    showNextQueued()
end

local function clearQueue()
    for i = #notify_queue, 1, -1 do
        table.remove(notify_queue, i)
    end
end

local function showBanner(title, text, ascii_art)
    enqueue("banner", title, text, ascii_art)
end

local function showCompact(title, text, ascii_art)
    enqueue("compact", title, text, ascii_art)
end

-- dispatch() always shows (used by Preview, so it still works even
-- with Notifications toggled off - an explicit test action shouldn't
-- silently do nothing). render() is the gated public path: it's what
-- Notifications.show* and the quest-patch bridge use, so turning
-- Notifications off actually silences everything routed through it,
-- quest-complete popups included.
--
-- Full style is handled differently here than for achievements/
-- level-ups: those have ReadMastery's own genuine large-ASCII-art
-- popup to fall back to (a separate code path entirely, bypassing
-- dispatch). Quest completions have no such native "Full" popup of
-- their own - if style is "full" but the caller only has a plain
-- title+text (nothing to hand off to a real Full popup), Compact is
-- the closest match to "Full"'s tap-to-dismiss modal feel, so that's
-- what "full" falls through to here rather than silently becoming
-- Banner against the user's actual choice.
local function dispatch(title, text, ascii_art)
    if Notify.style == "banner" then
        showBanner(title, text, ascii_art)
    else
        showCompact(title, text, ascii_art)
    end
end

local function render(title, text, ascii_art)
    if not Notify.enabled then return end
    dispatch(title, text, ascii_art)
end

-- Shared notification contract v1: a generic entry point other
-- patches call to show a plain status note in the user's chosen
-- style. Deliberately NOT gated on Notify.enabled (unlike render()
-- above) - this is a shared provider, not achievement spam: it fires
-- whenever this patch is installed. Consumers call it defensively
-- (type check + pcall) and only when a higher-priority provider
-- didn't handle the note, so patch load order doesn't matter.
-- Style mapping matches dispatch()'s fall-through: "banner" shows
-- the Banner toast (configured position; timeout overrides the
-- configured duration when given), anything else ("compact", "full")
-- shows the CompactBox modal. Returns true when the note was
-- accepted for display (shown immediately when the queue is idle,
-- otherwise in order behind what's already showing).
local function sharedNote(text, timeout)
    if type(text) ~= "string" or text == "" then return false end
    local kind = (Notify.style == "banner") and "banner" or "compact"
    enqueue(kind, nil, text, nil, timeout)
    return true
end

-- Small bridge so other patches (e.g. the quest-engine patch) can
-- reuse this same styled + queued render pipeline instead of
-- building their own separate notification look. Safe no-op for
-- anything that doesn't check for it.
_G.ReadMasteryNotify = _G.ReadMasteryNotify or {}
_G.ReadMasteryNotify.render = render
_G.ReadMasteryNotify.nudgesEnabled = function() return Notify.enabled and Notify.nudges_enabled end
_G.ReadMasteryNotify.clearQueue = clearQueue

-- =================================================================
-- SimpleUI Critter bridge (SimpleUI 3.0's "Tiny Critter Companion")
--
-- With "Critter Reacts" on (top of ReadMastery's menu, default ON):
--   * Level ups, achievements (and tier ups), streak milestones and
--     completed quests (quest patch 1.0.6+) wait for the Critter, which
--     comments on the most important one the next time the home screen
--     shows it - the same way it comments on a finished book. Each also
--     lifts the Critter's mood a little.
--   * In the Critter's chat it can offer one of today's daily quests
--     (quest patch on, Quests (Enhanced) on), and ask how a quest you
--     said you'd do is going. Doing a promised quest gets a special line.
-- Uses SimpleUI's own critter files (reactions, lines, chat, mood) and
-- adds to them in memory; their saved data keeps SimpleUI's format.
-- Nothing here runs on a timer. Without SimpleUI 3.0's Critter it does
-- nothing; the ReadMastery popups are not affected either way.
-- =================================================================

Notify.critter = settings:nilOrTrue("critter_enabled")

local CRITTER_MODS = {
    ["modules/critter/reactions"] = true,
    ["modules/critter/reaction_lines"] = true,
    ["modules/critter/dialog"] = true,
}

-- Priority of the waiting reaction (SimpleUI: book finished 8, its own
-- challenge 7, a reading session 6): the Critter keeps one, the higher.
local RM_PRIORITY = { rm_level = 7.5, rm_achievement = 6.8, rm_streak = 6.6, rm_quest = 6.4, rm_deadline = 4.5 }

-- Mood lift for each (SimpleUI's own challenge gives about this much).
local RM_REWARD = { rm_level = 5, rm_achievement = 3, rm_streak = 4, quest_daily = 2, quest_big = 4, quest_promised = 4 }

local critter_done = {}

-- ---- end of the week / month: nudge toward a quest still in reach ----
-- Weekly quests in their last 2 days, monthly in their last 5, this
-- month's seasonal in its last 7. Kept to what one push can still do:
--   book     a "finish N books" quest one book short, and a book of yours
--            at least half read (the closest to done of your 10 latest)
--   seasonal this month's seasonal "finish a tagged book" quest
--   pages    a page total started and within ~60 pages a day
--   minutes  a minutes total started and within ~90 minutes a day
-- Looked up at most every 10 minutes, and again after a quest completes
-- (up to 10 sidecar reads, only when a book quest is in its window).
local NUDGE_WINDOW = { weekly = 2, monthly = 5, seasonal = 7 }
local NUDGE_RANK   = { book = 1, seasonal = 2, pages = 3, minutes = 4 }
local nudge_cache  = { at = 0, value = nil }

local function closestBook()
    local okh, RH = pcall(require, "readhistory")
    local okd, DS = pcall(require, "docsettings")
    if not (okh and okd and type(RH) == "table" and type(RH.hist) == "table" and type(DS) == "table") then return nil end
    local best
    for i, e in ipairs(RH.hist) do
        if i > 10 then break end
        if type(e) == "table" and type(e.file) == "string" and not e.dim then
            local ok, ds = pcall(DS.open, DS, e.file)
            if ok and ds then
                local pct = ds:readSetting("percent_finished")
                local summary = ds:readSetting("summary")
                local props = ds:readSetting("doc_props")
                local done = type(summary) == "table" and summary.status == "complete"
                if type(pct) == "number" and pct >= 0.5 and pct < 1 and not done and (not best or pct > best.pct) then
                    local title = type(props) == "table" and type(props.title) == "string" and props.title ~= "" and props.title
                        or e.file:match("([^/]+)%.[^./]+$") or e.file
                    best = { pct = pct, title = title, file = e.file }
                end
            end
        end
    end
    return best
end

local function findNudge()
    local Q = _G.ReadMasteryQuests
    if type(Q) ~= "table" or type(Q.open) ~= "function" or not Q.enabled() then return nil end
    local ok, list = pcall(Q.open)
    if not ok or type(list) ~= "table" then return nil end
    local book, book_looked
    local best
    for _, q in ipairs(list) do
        local window = NUDGE_WINDOW[q.period]
        if window and q.days_left >= 1 and q.days_left <= window then
            local rem = q.need - q.have
            local cand
            if q.type == "books_finished" and rem == 1 then
                if not book_looked then book_looked, book = true, closestBook() end
                if book then cand = { kind = "book", q = q, book = book } end
            elseif q.type == "tag_book_finish" and q.period == "seasonal" then
                cand = { kind = "seasonal", q = q }
            elseif q.type == "pages" and q.have > 0 and rem > 0 and rem <= 60 * q.days_left then
                cand = { kind = "pages", q = q, rem = rem }
            elseif q.type == "minutes" and q.have > 0 and rem > 0 and rem <= 90 * q.days_left then
                cand = { kind = "minutes", q = q, rem = rem }
            end
            if cand and (not best or NUDGE_RANK[cand.kind] < NUDGE_RANK[best.kind]
                    or (NUDGE_RANK[cand.kind] == NUDGE_RANK[best.kind] and q.days_left < best.q.days_left)) then
                best = cand
            end
        end
    end
    return best
end

local function currentNudge()
    if not Notify.critter then return nil end
    local now = os.time()
    if now - nudge_cache.at < 10 * 60 and nudge_cache.day == os.date("%Y-%m-%d") then return nudge_cache.value end
    local ok, v = pcall(findNudge)
    nudge_cache.at, nudge_cache.day, nudge_cache.value = now, os.date("%Y-%m-%d"), ok and v or nil
    return nudge_cache.value
end

local function nudgeData(n)
    return {
        title = n.q.title, days = n.q.days_left, kind = n.kind,
        which = n.book and n.book.title or nil,                   -- the book to finish
        capacity = n.book and math.floor(n.book.pct * 100) or nil, -- how far into it, %
        minutes = n.rem,                                          -- pages or minutes still to go
    }
end

local function rmLines(L)
    local function add(kind, group, when, line)
        line.kind, line.group, line.when = kind, group, when
        L.LINES[#L.LINES + 1] = line
    end
    local function t(fmt) return function(d) return string.format(fmt, d.title) end end
    local function n(fmt) return function(d) return string.format(fmt, d.days) end end
    local function s(text) return function() return text end end
    local has_title = function(d) return d.title ~= nil end
    local has_days  = function(d) return d.days ~= nil end

    -- Level up
    add("rm_level", "level", has_title, { id = "rm_lv1", mood = "party",
        text = t("Level %s!"), sub = s("Shiny new number. I approve."),
        by_tier = {
            grumpy  = { mood = "grumpy", text = t("Level %s. Fine. That's impressive.") },
            radiant = { mood = "party",  text = t("LEVEL %s! Bow before the reader!") },
        } })
    add("rm_level", "level", has_title, { id = "rm_lv2", mood = "cheer",
        text = t("You hit level %s."), sub = s("Pages really do add up.") })
    add("rm_level", "level", has_title, { id = "rm_lv3", mood = "love",
        text = t("Level %s. Look at you."), sub = s("I knew you had it in you."),
        by_tier = { meh = { mood = "sleepy", text = t("Level %s. Wake me for the next one.") } } })
    add("rm_level", "level", has_title, { id = "rm_lv4", mood = "surprised",
        text = t("Level %s already?"), sub = s("Slow down, I can't keep up.") })

    -- Achievement (or a tier up of one)
    add("rm_achievement", "unlocked", has_title, { id = "rm_ac1", mood = "party",
        text = t("%s, unlocked!"), sub = s("Framing it. In my head.") })
    add("rm_achievement", "unlocked", has_title, { id = "rm_ac2", mood = "cheer",
        text = t("You got %s."), sub = s("Another badge for the shelf."),
        by_tier = { grumpy = { mood = "grumpy", text = t("%s. Show-off.") } } })
    add("rm_achievement", "unlocked", has_title, { id = "rm_ac3", mood = "curious",
        text = t("%s? How'd you do that?"), sub = s("It looked hard. Was it hard?") })
    add("rm_achievement", "unlocked", has_title, { id = "rm_ac4", mood = "love",
        text = t("%s! I'm so proud."),
        by_tier = { radiant = { mood = "party", text = t("%s! Is there anything you can't do?") } } })

    -- Streak milestone
    add("rm_streak", "days", has_days, { id = "rm_st1", mood = "party",
        text = n("%d days in a row!"), sub = s("That's a real habit now.") })
    add("rm_streak", "days", has_days, { id = "rm_st2", mood = "cheer",
        text = n("A %d-day streak!"), sub = s("Don't you dare stop now."),
        by_tier = { grumpy = { mood = "grumpy", text = n("%d days. Fine, that's impressive.") } } })
    add("rm_streak", "days", has_days, { id = "rm_st3", mood = "love",
        text = n("%d days of reading."), sub = s("Same time tomorrow?") })

    -- Quest done: one you told the Critter you'd do, a daily, a bigger one
    local promised = function(d) return d.kind == "promised" and d.title ~= nil end
    local daily    = function(d) return d.kind == "daily" and d.title ~= nil end
    local big      = function(d) return d.title ~= nil and d.kind ~= nil and d.kind ~= "promised" and d.kind ~= "daily" end
    add("rm_quest", "promised", promised, { id = "rm_qp1", mood = "party",
        text = t("You said you'd do %s. You did!"), sub = s("A critter remembers these things.") })
    add("rm_quest", "promised", promised, { id = "rm_qp2", mood = "love",
        text = t("%s, done, like you promised."), sub = s("I'm writing this down."),
        by_tier = { grumpy = { mood = "grumpy", text = t("%s. You kept your word. Hmph.") } } })
    add("rm_quest", "daily", daily, { id = "rm_qd1", mood = "cheer",
        text = t("Quest done: %s."), sub = s("Easy for you."),
        by_tier = {
            grumpy  = { mood = "grumpy", text = t("%s. Done. Big deal.") },
            radiant = { mood = "party",  text = t("Quest done: %s! Legendary!") },
        } })
    add("rm_quest", "daily", daily, { id = "rm_qd2", mood = "happy",
        text = t("%s, complete!"), sub = s("XP looks good on you.") })
    add("rm_quest", "daily", daily, { id = "rm_qd3", mood = "playful",
        text = t("Another quest down: %s."), sub = s("What's next, dragons?") })
    add("rm_quest", "big", big, { id = "rm_qb1", mood = "party",
        text = t("%s! That's a big one."), sub = s("That took real work.") })
    add("rm_quest", "big", big, { id = "rm_qb2", mood = "surprised",
        text = t("You finished %s?!"), sub = s("I need to sit down.") })

    -- End of the week / month (see findNudge)
    local function left(d) return d.days == 1 and "Last day" or string.format("%d days left", d.days) end
    local nb = function(d) return d.kind == "book" and d.title and d.which and d.days end
    local ns = function(d) return d.kind == "seasonal" and d.title and d.days end
    local np = function(d) return d.kind == "pages" and d.title and d.minutes and d.days end
    local nm = function(d) return d.kind == "minutes" and d.title and d.minutes and d.days end
    add("rm_deadline", "book", nb, { id = "rm_nb1", mood = "curious",
        text = function(d) return string.format("%s for %s.", left(d), d.title) end,
        sub  = function(d) return string.format("\u{201C}%s\u{201D} is %d%% done. Finish it?", d.which, d.capacity or 0) end })
    add("rm_deadline", "book", nb, { id = "rm_nb2", mood = "playful",
        text = function(d) return string.format("\u{201C}%s\u{201D} is so close.", d.which) end,
        sub  = function(d) return string.format("%d%% done. %s for %s.", d.capacity or 0, left(d), d.title) end,
        by_tier = { grumpy = { mood = "grumpy", text = function(d) return string.format("Just finish \u{201C}%s\u{201D} already.", d.which) end } } })
    add("rm_deadline", "seasonal", ns, { id = "rm_ns1", mood = "curious",
        text = function(d) return string.format("%s for %s.", left(d), d.title) end,
        sub  = s("Got a book for it going?") })
    add("rm_deadline", "seasonal", ns, { id = "rm_ns2", mood = "playful",
        text = function(d) return string.format("%s is almost over.", d.title) end,
        sub  = function(d) return string.format("%s. One book does it.", left(d)) end })
    add("rm_deadline", "pages", np, { id = "rm_np1", mood = "cheer",
        text = function(d) return string.format("%d pages to go for %s.", d.minutes, d.title) end,
        sub  = function(d) return string.format("%s. Very doable.", left(d)) end })
    add("rm_deadline", "minutes", nm, { id = "rm_nm1", mood = "cheer",
        text = function(d) return string.format("%d minutes to go for %s.", d.minutes, d.title) end,
        sub  = function(d) return string.format("%s. A couple of sessions.", left(d)) end })
end

-- ---- chat: offer one of today's daily quests ---------------------

local FOCUS_KEY = "critter_focus"   -- { day, id }: the daily quest you said you'd do

local function readFocus(day)
    local f = settings:readSetting(FOCUS_KEY)
    if type(f) == "table" and f.day == day and type(f.id) == "string" then return f.id end
    return nil
end

local function questOffer()
    if not Notify.critter then return nil end
    local Q = _G.ReadMasteryQuests
    if type(Q) ~= "table" or type(Q.daily) ~= "function" or not Q.enabled() then return nil end
    local ok, list = pcall(Q.daily)
    if not ok or type(list) ~= "table" or #list == 0 then return nil end
    local focus = readFocus(list[1].day)
    if focus then
        for _, q in ipairs(list) do
            -- done: offer another of today's (below)
            if q.id == focus and not q.done then return { mode = "active", q = q } end
        end
    end
    -- today's rotating one first, else the first still open; a time-window
    -- quest whose window is over for today (First Light after 9:00) isn't
    -- offered. The quest day ends at 3 AM, so a window past midnight
    -- (Night Owl) is never over before then.
    local function over(q)
        if not (q.from and q.to) then return false end
        local fh, fm = q.from:match("(%d+):(%d+)")
        local th, tm = q.to:match("(%d+):(%d+)")
        if not (fh and th) then return false end
        local from_m, to_m = tonumber(fh) * 60 + tonumber(fm), tonumber(th) * 60 + tonumber(tm)
        if from_m > to_m then return false end
        local t = os.date("*t")
        local now_m = t.hour * 60 + t.min
        -- before 3 AM it's still yesterday's quest day, its window long gone
        return now_m >= to_m or now_m < 3 * 60
    end
    local pick
    for i = #list, 1, -1 do
        if not list[i].done and not over(list[i]) then pick = list[i] break end
    end
    if not pick then return nil end
    return { mode = "offer", q = pick }
end

local function unitText(q, n)
    if q.unit == "minutes" then return n == 1 and "minute" or "minutes" end
    return n == 1 and "page" or "pages"
end

local function offerText(q)
    if q.have > 0 then
        return string.format("%s: %d of %d %s so far. Finish it today?", q.title, q.have, q.need, unitText(q, q.need))
    end
    if q.type == "single_session_minutes" then
        return string.format("Today's quest: %s. %d minutes in one sitting?", q.title, q.need)
    elseif q.type == "time_window_minutes" and q.from and q.to then
        return string.format("Today's quest: %s. %d minutes between %s and %s?", q.title, q.need, q.from, q.to)
    end
    return string.format("Today's quest: %s. Read %d %s?", q.title, q.need, unitText(q, q.need))
end

local function rmExchanges(D)
    local function s(text) return function() return text end end
    -- `f` (the Critter's facts) carries the quest from when() to the replies
    local function offer(f) return f.rm_quest_offer end
    local function accepting(text)
        return function(f)
            local o = offer(f)
            if o then
                settings:saveSetting(FOCUS_KEY, { day = o.q.day, id = o.q.id })
                settings:flush()
            end
            return text
        end
    end
    D.EXCHANGES[#D.EXCHANGES + 1] = {
        id = "rm_quest_offer",
        when = function(f)
            local ok, o = pcall(questOffer)
            f.rm_quest_offer = ok and o or nil
            return f.rm_quest_offer ~= nil and f.rm_quest_offer.mode == "offer"
        end,
        opener = function(f) return offerText(offer(f).q) end,
        options = {
            { id = "rm_accept", delta = 1,
              text = s("I'll do it"),
              reply = { mood = "cheer", text = accepting("Deal. I'll keep an eye on it."),
                        sub = function(f) return string.format("+%d XP is waiting.", offer(f).q.reward_xp or 0) end } },
            { id = "rm_later", delta = 0,
              text = s("Not today"),
              reply = { mood = "playful", text = s("Fair. It's there until 3 AM."),
                        by_tier = { grumpy = { mood = "grumpy", text = s("Of course not.") } } } },
            { id = "rm_xp", delta = 0,
              text = s("What's in it for me?"),
              reply = { mood = "curious",
                        text = function(f) return string.format("%d XP. And my respect.", offer(f).q.reward_xp or 0) end } },
        },
    }
    D.EXCHANGES[#D.EXCHANGES + 1] = {
        id = "rm_quest_active",
        when = function(f)
            local ok, o = pcall(questOffer)
            f.rm_quest_offer = ok and o or nil
            return f.rm_quest_offer ~= nil and f.rm_quest_offer.mode == "active"
        end,
        opener = function(f)
            local q = offer(f).q
            return string.format("%s: %d of %d %s. How's it going?", q.title, q.have, q.need, unitText(q, q.need))
        end,
        options = {
            { id = "rm_on_it", delta = 1,
              text = s("On it!"),
              reply = { mood = "cheer", text = s("Go get it. I'll be cheering."),
                        by_tier = { radiant = { mood = "party", text = s("Unstoppable! I can feel it!") } } } },
            { id = "rm_tough", delta = 0,
              text = s("Tough one…"),
              reply = { mood = "curious", text = s("A little now, a little later. It adds up.") } },
        },
    }
    -- End of the week / month (see findNudge)
    local function nudge(f) return f.rm_nudge end
    local function leftText(q) return q.days_left == 1 and "Last day" or string.format("%d days left", q.days_left) end
    local function hasBook(f) return nudge(f) ~= nil and nudge(f).book ~= nil end
    D.EXCHANGES[#D.EXCHANGES + 1] = {
        id = "rm_deadline",
        when = function(f)
            local ok, n = pcall(currentNudge)
            f.rm_nudge = ok and n or nil
            return f.rm_nudge ~= nil
        end,
        opener = function(f)
            local n = nudge(f)
            local q = n.q
            if n.kind == "book" then
                return string.format("%s for %s. \u{201C}%s\u{201D} is %d%% done.", leftText(q), q.title, n.book.title, math.floor(n.book.pct * 100))
            elseif n.kind == "pages" then
                return string.format("%s: %d pages to go. %s.", q.title, n.rem, leftText(q))
            elseif n.kind == "minutes" then
                return string.format("%s: %d minutes to go. %s.", q.title, n.rem, leftText(q))
            end
            return string.format("%s for %s. Got a book for it?", leftText(q), q.title)
        end,
        options = {
            { id = "rm_go", delta = 1,
              text = function(f) return nudge(f).kind == "book" and "Let's finish it" or "Let's do it" end,
              reply = { mood = "cheer",
                        text = function(f) return nudge(f).kind == "book" and "That's the spirit. Open it and go." or "I'll be cheering from here." end,
                        by_tier = { radiant = { mood = "party", text = s("Yes! Finish line, here we come!") } } } },
            { id = "rm_which", delta = 0, when = function(f) return hasBook(f) end,
              text = s("Which book?"),
              reply = { mood = "curious",
                        text = function(f) return string.format("\u{201C}%s\u{201D}. It's the closest to the end.", nudge(f).book.title) end } },
            { id = "rm_not_now", delta = 0,
              text = s("Not this time"),
              reply = { mood = "playful",
                        text = function(f)
                            local period = nudge(f).q.period
                            if period == "weekly" then return "Next week, then. I'll remember." end
                            if period == "seasonal" then return "Next year, then. It comes back." end
                            return "Next month, then. I'll remember."
                        end,
                        by_tier = { grumpy = { mood = "grumpy", text = s("Sure. I'll pretend I didn't ask.") } } } },
        },
    }
end

local function installCritter()
    local R = package.loaded["modules/critter/reactions"]
    if not critter_done.R and type(R) == "table" and type(R.PRIORITY) == "table" then
        critter_done.R = true
        for k, v in pairs(RM_PRIORITY) do R.PRIORITY[k] = v end
        -- Each home screen visit: once a day, an end-of-week/month nudge
        -- waits for the Critter (kept only if nothing more important
        -- waits; tried again on a later visit).
        if type(R.observe) == "function" then
            local orig_observe = R.observe
            R.observe = function(...)
                local res = { orig_observe(...) }
                pcall(function()
                    local today = os.date("%Y-%m-%d")
                    if settings:readSetting("critter_nudge_day") == today then return end
                    local n = currentNudge()
                    if not n then return end
                    R.record("rm_deadline", nudgeData(n))
                    local pending = R.read().pending
                    if pending and pending.kind == "rm_deadline" then
                        settings:saveSetting("critter_nudge_day", today)
                        settings:flush()
                    end
                end)
                return unpack(res)
            end
        end
    end
    local L = package.loaded["modules/critter/reaction_lines"]
    if not critter_done.L and type(L) == "table" and type(L.LINES) == "table" then
        critter_done.L = true
        local ok, err = pcall(rmLines, L)
        if not ok then logger.warn("ReadMastery notify: critter lines failed:", err) end
    end
    local D = package.loaded["modules/critter/dialog"]
    if not critter_done.D and type(D) == "table" and type(D.EXCHANGES) == "table" then
        critter_done.D = true
        local ok, err = pcall(rmExchanges, D)
        if not ok then logger.warn("ReadMastery notify: critter chat failed:", err) end
    end
end

-- SimpleUI loads the critter files with its home screen: catch them as
-- they load (no-op for every other require).
installCritter()
do
    local orig_require = require
    _G.require = function(name, ...)
        local mod = orig_require(name, ...)
        if CRITTER_MODS[name] and not (critter_done.R and critter_done.L and critter_done.D) then
            pcall(installCritter)
        end
        return mod
    end
end

-- Leaves `kind` waiting for the Critter and lifts its mood by `reward`.
local function critterRecord(kind, data, reward)
    if not Notify.critter then return end
    installCritter()
    if not critter_done.R then return end   -- no SimpleUI 3.0 Critter
    local R = package.loaded["modules/critter/reactions"]
    R.record(kind, data)
    local M = package.loaded["modules/critter/mood"]
    if reward and type(M) == "table" and type(M.reward) == "function" then
        M.write(M.reward(M.read(), reward))
    end
end

local function questKind(id)
    local p = type(id) == "string" and id:sub(1, 2) or ""
    return ({ d_ = "daily", w_ = "weekly", m_ = "monthly", s_ = "seasonal", y_ = "yearly" })[p] or "quest"
end

-- Called by the quest patch (1.0.6+) for each completed quest.
_G.ReadMasteryNotify.onQuestComplete = function(quest)
    nudge_cache.at = 0   -- what's left to nudge about changed
    if not Notify.critter or type(quest) ~= "table" or type(quest.title) ~= "string" then return end
    local kind = questKind(quest.id)
    local Q = _G.ReadMasteryQuests
    local day
    if type(Q) == "table" and type(Q.daily) == "function" then
        local ok, list = pcall(Q.daily)
        day = ok and type(list) == "table" and list[1] and list[1].day or nil
    end
    if kind == "daily" and day and readFocus(day) == quest.id then
        critterRecord("rm_quest", { title = quest.title, kind = "promised" }, RM_REWARD.quest_promised)
    else
        critterRecord("rm_quest", { title = quest.title, kind = kind },
            kind == "daily" and RM_REWARD.quest_daily or RM_REWARD.quest_big)
    end
end

-- =================================================================
-- Patch the plugin (runs once per plugin-instantiation; guarded so
-- the actual class-level monkey-patch only happens once per session)
-- =================================================================

local classes_patched = false

userpatch.registerPatchPluginFunc("ReadMastery", function(plugin)
    if classes_patched then return end

    local ok, err = pcall(function()

    local Notifications = require("ui/notifications")
    local MainMenu = require("ui/mainmenu")
    local Icons = require("icons")
    local AsciiArt = require("ascii_art")
    local AchievementsView = require("ui/achievements_view")

    -- Stock ReadMastery's achievement list closes itself on every tap
    -- (its rows never set keep_menu_open), so viewing a detail then
    -- dismissing it drops you all the way out to the top menu. Fix:
    -- after the detail popup shows, grab that exact instance off the
    -- window stack and hook ITS close (not the class, not any other
    -- AsciiPopup use - achievement unlocks, tier-ups, and our own
    -- Preview all stay untouched) to reopen the list. Different
    -- mechanism from an earlier, reverted attempt here that deferred
    -- the popup's SHOW and raced against the list's synchronous
    -- close - this instead hooks the popup's CLOSE, after the show
    -- has already safely happened, so there's nothing to race.
    local orig_showAchievementDetail = AchievementsView.showAchievementDetail
    AchievementsView.showAchievementDetail = function(self, achievement)
        local ret = orig_showAchievementDetail(self, achievement)
        local popup = UIManager:getTopmostVisibleWidget()
        if popup then
            local orig_popup_close = popup.onCloseWidget
            local chained = false
            popup.onCloseWidget = function(popup_self, ...)
                if orig_popup_close then orig_popup_close(popup_self, ...) end
                if chained then return end
                chained = true
                self:show()
            end
        end
        return ret
    end

    local orig_showLevelUp          = Notifications.showLevelUp
    local orig_showAchievement      = Notifications.showAchievement
    local orig_showTierUp           = Notifications.showTierUp
    local orig_showStreakMilestone  = Notifications.showStreakMilestone

    -- Kept in sync with the original plugin's ui/notifications.lua
    local STREAK_MILESTONES = {
        [7] = "One Week Wonder!",
        [14] = "Two Week Triumph!",
        [30] = "Monthly Master!",
        [60] = "Bimonthly Beast!",
        [100] = "Century Streak!",
        [365] = "Year of Reading!",
    }

    -- -----------------------------------------------------------
    -- Content builders. Icons/pixel-art are always on. Each
    -- returns (title, text, ascii_art) - ascii_art is nil except
    -- for real, unlocked achievements.
    -- -----------------------------------------------------------

    -- Cosmetic only - no XP, no gameplay effect, just a title badge
    -- shown in the Level Up popup at these milestone levels.
    local LEVEL_TITLES = {
        [2] = "Curious Reader", [3] = "Bookworm", [4] = "Page Turner",
        [5] = "Avid Reader", [6] = "Dedicated Reader", [7] = "Literary Explorer",
        [8] = "Seasoned Reader", [9] = "Reading Regular", [10] = "Established Reader",
        [11] = "Mastered Reader", [12] = "Literary Adventurer", [13] = "Dedicated Bibliophile",
        [14] = "Veteran Reader", [15] = "Reading Veteran", [16] = "Literary Scholar",
        [17] = "Book Connoisseur", [18] = "Reading Expert", [19] = "Master Reader",
        [20] = "Reading Master",
    }

    local function levelUpContent(level, unlocked_feature)
        local text = "You reached Level " .. level .. " " .. Icons.LIGHTNING
        local title_badge = LEVEL_TITLES[level]
        if title_badge then
            text = text .. "\n" .. Icons.CROWN .. " " .. title_badge
        end
        if unlocked_feature then
            text = text .. "\n" .. Icons.UNLOCK .. " Unlocked: " .. unlocked_feature.name
        end
        return Icons.STAR .. " LEVEL UP " .. Icons.STAR, text
    end

    local function achievementContent(achievement)
        local art = achievement.id and AsciiArt.getSmall(achievement.id, true) or nil
        local body
        if art then
            body = achievement.name .. "\n" .. achievement.description
        else
            body = (achievement.icon or Icons.MEDAL) .. "  " .. achievement.name .. "\n" .. achievement.description
        end
        return Icons.TROPHY .. " ACHIEVEMENT UNLOCKED " .. Icons.TROPHY, body, art
    end

    local function tierUpContent(achievement, tier_info)
        local tier_icon = Icons.getTierIcon(tier_info.id)
        return tier_icon .. " TIER UP " .. tier_icon,
               achievement.name .. "\n" .. tier_icon .. " " .. string.upper(tier_info.name) .. " TIER " .. tier_icon
    end

    local function streakContent(days, milestone_text)
        return Icons.FIRE .. " STREAK MILESTONE " .. Icons.FIRE,
               days .. " DAYS " .. Icons.FIRE .. "  " .. milestone_text
    end

    Notifications.showLevelUp = function(self, level, unlocked_feature)
        if not Notify.enabled then return end
        if Notify.style == "full" then
            return orig_showLevelUp(self, level, unlocked_feature)
        end
        local title, text = levelUpContent(level, unlocked_feature)
        render(title, text)
    end

    Notifications.showAchievement = function(self, achievement)
        if not Notify.enabled then return end
        if Notify.style == "full" then
            return orig_showAchievement(self, achievement)
        end
        local title, text, ascii_art = achievementContent(achievement)
        render(title, text, ascii_art)
    end

    Notifications.showTierUp = function(self, achievement_id, achievement, tier_info)
        if not Notify.enabled then return end
        if Notify.style == "full" then
            return orig_showTierUp(self, achievement_id, achievement, tier_info)
        end
        local title, text = tierUpContent(achievement, tier_info)
        render(title, text)
    end

    Notifications.showStreakMilestone = function(self, days)
        if not Notify.enabled then return end
        if Notify.style == "full" then
            -- Delegates to the real, complete milestone handling
            -- regardless of whether `days` is in OUR hardcoded
            -- STREAK_MILESTONES table below - that table only exists
            -- to build Compact/Banner content ourselves, and checking
            -- it first (as this used to) meant any milestone day the
            -- real plugin supports but this file doesn't know about
            -- got silently dropped even under Full style, breaking
            -- the "Full is untouched" guarantee for those days.
            return orig_showStreakMilestone(self, days)
        end
        local milestone_text = STREAK_MILESTONES[days]
        if not milestone_text then return end
        local title, text = streakContent(days, milestone_text)
        render(title, text)
    end

    -- SimpleUI Critter: comments on these next time it's on the home
    -- screen (whatever the notification settings; Preview doesn't come
    -- through here).
    do
        local function hook(name, fn)
            local inner = Notifications[name]
            Notifications[name] = function(self, ...)
                pcall(fn, ...)
                return inner(self, ...)
            end
        end
        hook("showLevelUp", function(level)
            if level then critterRecord("rm_level", { title = tostring(level) }, RM_REWARD.rm_level) end
        end)
        hook("showAchievement", function(achievement)
            if type(achievement) == "table" and type(achievement.name) == "string" then
                critterRecord("rm_achievement", { title = achievement.name }, RM_REWARD.rm_achievement)
            end
        end)
        hook("showTierUp", function(_id, achievement, tier_info)
            if type(achievement) == "table" and type(achievement.name) == "string" then
                local tier = type(tier_info) == "table" and tier_info.name
                local title = tier and (achievement.name .. " (" .. tostring(tier) .. ")") or achievement.name
                critterRecord("rm_achievement", { title = title }, RM_REWARD.rm_achievement)
            end
        end)
        hook("showStreakMilestone", function(days)
            if tonumber(days) then critterRecord("rm_streak", { days = tonumber(days) }, RM_REWARD.rm_streak) end
        end)
    end

    -- ---------------------------------------------------------------
    -- Preview = a real achievement notification (Early Bird), built
    -- from current settings, so style / font / position / duration
    -- changes - including the achievement pixel-art - can be checked
    -- without waiting for a real one to fire.
    --
    -- A real achievement id is used (not a fabricated one) because
    -- the "Full" style needs a real id to look up its ASCII art.
    -- ---------------------------------------------------------------
    local function showPreview()
        local sample = {
            id = "early_bird",
            name = "Early Bird",
            description = "Read between 4:00 AM and 7:00 AM",
        }
        if Notify.style == "full" then
            -- Deferred to next tick: AsciiPopup registers a full-
            -- screen tap-to-close gesture in its own init(), and
            -- showing it synchronously inside the SAME tap that
            -- triggered this menu item risks that same originating
            -- tap being redelivered to the newly-shown popup, closing
            -- it instantly (looks like "doesn't show" - it shows and
            -- immediately self-closes, same tick). Safe to defer here
            -- specifically because "Preview Notification" already has
            -- keep_menu_open = true, so nothing else is closing
            -- synchronously after this tap to race against.
            UIManager:nextTick(function()
                -- Notifications (the real self this method would
                -- normally be called on), not nil - costs nothing and
                -- means this doesn't break if a future ReadMastery
                -- update ever has this method touch self for anything.
                orig_showAchievement(Notifications, sample)
            end)
        else
            local title, text, ascii_art = achievementContent(sample)
            dispatch(title, text, ascii_art)
        end
    end

    -- ---------------------------------------------------------------
    -- Add our settings to ReadMastery's own Settings submenu
    --
    -- checked_func (+ radio for mutually-exclusive groups) is what
    -- makes KOReader's menu redraw the checkmark/radio-dot the
    -- instant you tap an item, instead of only on next open.
    -- ---------------------------------------------------------------
    local orig_getSettingsMenu = MainMenu.getSettingsMenu
    MainMenu.getSettingsMenu = function(self)
        local items = orig_getSettingsMenu(self)

        local duration_options = { 2, 3, 4, 5, 8 }
        local duration_menu = {}
        for _, secs in ipairs(duration_options) do
            table.insert(duration_menu, {
                text = secs .. " Seconds",
                radio = true,
                checked_func = function() return Notify.duration == secs end,
                callback = function()
                    Notify.duration = secs
                    saveSetting("duration", secs)
                end,
                keep_menu_open = true,
            })
        end

        local position_options = {
            { id = "left",         name = "Top Left" },
            { id = "right",        name = "Top Right" },
            { id = "bottom_left",  name = "Bottom Left" },
            { id = "bottom_right", name = "Bottom Right" },
            { id = "full_top",     name = "Full Width (Top)" },
            { id = "full_bottom",  name = "Full Width (Bottom)" },
        }
        local position_menu = {}
        for _, opt in ipairs(position_options) do
            table.insert(position_menu, {
                text = opt.name,
                radio = true,
                checked_func = function() return Notify.position == opt.id end,
                callback = function()
                    Notify.position = opt.id
                    saveSetting("position", opt.id)
                end,
                keep_menu_open = true,
            })
        end

        -- Full - Compact - Banner - Banner Position - Duration -
        -- Font - Preview, all in one contained menu.
        local style_menu = {}
        local style_options = {
            { id = "full",    name = "Full (Original Popup, Tap To Close)" },
            { id = "compact", name = "Compact (Small Centered Box)" },
            { id = "banner",  name = "Banner (Auto-Dismiss)" },
        }
        for _, opt in ipairs(style_options) do
            table.insert(style_menu, {
                text = opt.name,
                radio = true,
                checked_func = function() return Notify.style == opt.id end,
                callback = function()
                    Notify.style = opt.id
                    saveSetting("style", opt.id)
                end,
                keep_menu_open = true,
            })
        end
        table.insert(style_menu, {
            text = "Banner Position (Banner Style Only)",
            sub_item_table = position_menu,
        })
        table.insert(style_menu, {
            text = "Duration",
            sub_item_table = duration_menu,
        })
        table.insert(style_menu, {
            text = "Font",
            sub_item_table = buildFontMenu(),
        })
        table.insert(style_menu, {
            text = "Preview Notification",
            keep_menu_open = true,
            callback = function()
                showPreview()
            end,
        })

        local extra = {
            {
                text = "Notifications",
                checked_func = function() return Notify.enabled end,
                callback = function()
                    Notify.enabled = not Notify.enabled
                    saveSetting("enabled", Notify.enabled)
                    if not Notify.enabled then
                        -- OFF means stop everything, not just block
                        -- new ones - clear whatever's still pending.
                        -- Whatever's CURRENTLY on screen finishes out
                        -- naturally rather than being force-closed.
                        clearQueue()
                    end
                end,
                keep_menu_open = true,
            },
            {
                text = "Nudges",
                checked_func = function() return Notify.nudges_enabled end,
                enabled_func = function() return Notify.enabled end,
                callback = function()
                    Notify.nudges_enabled = not Notify.nudges_enabled
                    saveSetting("nudges_enabled", Notify.nudges_enabled)
                end,
                keep_menu_open = true,
            },
            {
                text = "Critter Reacts (SimpleUI)",
                help_text = "SimpleUI's Critter comments on level ups, achievements, streak milestones "
                    .. "and completed quests next time it's on the home screen, and can offer "
                    .. "today's daily quests in its chat. Needs SimpleUI 3.0 with the Critter module.",
                checked_func = function() return Notify.critter end,
                callback = function()
                    Notify.critter = not Notify.critter
                    saveSetting("critter_enabled", Notify.critter)
                end,
                keep_menu_open = true,
            },
            {
                text = "Notification Settings",
                sub_item_table = style_menu,
                enabled_func = function() return Notify.enabled end,
            },
        }

        local combined = {}
        for _, it in ipairs(extra) do table.insert(combined, it) end
        for _, it in ipairs(items) do table.insert(combined, it) end
        return combined
    end

    -- Only mark done once setup has actually completed - if anything
    -- above throws, this stays false so the next plugin instantiation
    -- can retry instead of permanently skipping setup.
    classes_patched = true
    -- Shared notification contract v1: published only on successful
    -- install, so consumers never see a half-installed provider.
    _G.__readmastery_note = sharedNote
    logger.info("ReadMastery Notify patch v" .. PATCH_VERSION .. " loaded")

    end) -- pcall
    if not ok then
        -- Whole one-time setup wrapped so a throw anywhere in it
        -- (including the AchievementsView hook above) is visible and
        -- retryable on the next plugin instantiation, instead of
        -- propagating uncaught with no message - same pattern the
        -- sibling quest-engine patch already uses.
        UIManager:show(InfoMessage:new{
            text = "ReadMastery Notify patch failed to load:\n" .. tostring(err),
            timeout = 8,
        })
    end
end)
