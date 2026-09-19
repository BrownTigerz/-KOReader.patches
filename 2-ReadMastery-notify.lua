--[[--
ReadMastery - Notification Style Patch
=======================================

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

Everything lives under ReadMastery -> Settings -> Notification Settings
(greyed out while "Notifications" below it is off):
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
local InputContainer  = require("ui/widget/container/inputcontainer")
local RectSpan    = require("ui/widget/rectspan")
local Size        = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget    = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan  = require("ui/widget/verticalspan")
local Input  = Device.input
local Screen = Device.screen

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
            text = "Default (KOReader UI font)",
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

function Banner:onGesture(ev)
    UIManager:close(self)
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
                timeout = Notify.duration,
                font_path = Notify.font_path,
                on_close = onDone,
            })
        else
            UIManager:show(Banner:new{
                title = item.title,
                text = item.text,
                ascii_art = item.ascii_art,
                timeout = Notify.duration,
                position = Notify.position,
                font_path = Notify.font_path,
                on_close = onDone,
            })
        end
    end)
    if not ok then
        notify_active = false
        UIManager:nextTick(showNextQueued)
    end
end

local function enqueue(kind, title, text, ascii_art)
    table.insert(notify_queue, { kind = kind, title = title, text = text, ascii_art = ascii_art })
    showNextQueued()
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
local function dispatch(title, text, ascii_art)
    if Notify.style == "compact" then
        showCompact(title, text, ascii_art)
    else
        showBanner(title, text, ascii_art)
    end
end

local function render(title, text, ascii_art)
    if not Notify.enabled then return end
    dispatch(title, text, ascii_art)
end

-- Small bridge so other patches (e.g. the quest-engine patch) can
-- reuse this same styled + queued render pipeline instead of
-- building their own separate notification look. Safe no-op for
-- anything that doesn't check for it.
_G.ReadMasteryNotify = _G.ReadMasteryNotify or {}
_G.ReadMasteryNotify.render = render

-- =================================================================
-- Patch the plugin (runs once per plugin-instantiation; guarded so
-- the actual class-level monkey-patch only happens once per session)
-- =================================================================

local classes_patched = false

userpatch.registerPatchPluginFunc("ReadMastery", function(plugin)
    if classes_patched then return end
    classes_patched = true

    local Notifications = require("ui/notifications")
    local MainMenu = require("ui/mainmenu")
    local Icons = require("icons")
    local AsciiArt = require("ascii_art")

    -- (Previously wrapped AchievementsView.showAchievementDetail with
    -- a nextTick deferral here to fix a flash-and-disappear bug.
    -- Reverted: that wrap likely raced against the achievements list's
    -- own auto-close-on-tap behavior instead of fixing it. Left as
    -- stock/untouched - lightest, safest option until there's a
    -- confirmed, targeted fix.)

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
    local function levelUpContent(level, unlocked_feature)
        local text = "You reached Level " .. level .. " " .. Icons.LIGHTNING
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
        local milestone_text = STREAK_MILESTONES[days]
        if not milestone_text then return end
        if Notify.style == "full" then
            return orig_showStreakMilestone(self, days)
        end
        local title, text = streakContent(days, milestone_text)
        render(title, text)
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
            orig_showAchievement(nil, sample)
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
                text = secs .. " seconds",
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
            { id = "full",    name = "Full (original popup, tap to close)" },
            { id = "compact", name = "Compact (small centered box)" },
            { id = "banner",  name = "Banner (auto-dismiss)" },
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
            text = "Banner Position (Banner style only)",
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
end)
