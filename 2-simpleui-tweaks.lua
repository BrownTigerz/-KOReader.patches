--[[
2-simpleui-tweaks.lua - SimpleUI Tweaks, a KOReader user patch for SimpleUI
(simpleui.koplugin)
Version 2.14.10

Colours, bold, section title styling and Night Mode "day look" for the
SimpleUI home screen, nav bar and status bar.
Settings: Tools > SimpleUI Tweaks (or Tools > Add-ons > SimpleUI Tweaks when
2-tweaks-menu.lua is installed). Install: koreader/patches/, then restart.
Also: KOReader's own menu tab icons and arrows can keep their original
colours in Night Mode (for colour icons swapped in via koreader/icons/).

Colours are picked as they look ON SCREEN; Night Mode inversion is handled.

Changelog
  2.14.10 Critter Insights in Donny, Blu and Donny & Blu's own voice:
         critter-phrases.lua's insight_voices section. With SimpleUI
         3.0.2 a critter with its own wording of an insight uses it about
         half the time, the shared lines the rest.
  2.14.9 Donny, Blu and Donny & Blu talk in their own voice, like
         SimpleUI 3.0.2's critters (Suey, Hazel...): their lines are in
         critter-phrases.lua (voices) and join SimpleUI's voice lines, so
         the home screen and Reading Log Tweaks both use them. Same
         situations as SimpleUI's: greetings, streak, today, books this
         year, the current book, goal, Monday, weekend, any time.
  2.14.8 Early Page Turn (Page Turns, off by default): a sideways swipe
         turns the page once your finger has moved 35 dp (or 50 / 80),
         without waiting for the lift. Books in page mode and full-screen
         lists (file browser, history, collections, TOC, bookmarks,
         search). One turn per swipe. Steps aside if 2-earlyturn.lua is
         installed.
  2.14.7 Menu reorganised: Modules, Critter, Appearance, Bars & Menus;
         toggles listed above submenus in each group.
  2.14.6 Side panel moved to 2-simpleui-sidepanel.lua (settings + BookOrbit +
         view toggles). This patch only bridges the home swipe when that
         patch is installed.
  2.14.4 Section label hook forwards SimpleUI 3.0.1's new `inside` param,
         so labels inside a module's box keep their inside styling.
  2.14.3 Wording pass: menu help texts and critter lines rewritten to
         sound natural (no AI phrasing). No functionality changed.
  2.14.2 Critter Mix (Modules): tick two or more critters (say Donny, Blu
         and Donny & Blu) and they take turns: the next one shows each
         time the critter has something new to say. Reading Log's
         critter takes turns too (a new remark or a tap there moves it along).
         Off (fewer than two ticked): SimpleUI's own pick.
  2.14.1 More critter moods: reading, proud, hungry, cozy, sipping,
         dreamy, festive and spooky (Donny and Blu have them in
         critters.zip). The phrase bank uses them; a critter without one
         shows the pose it's drawn from (reading = neutral, proud =
         cheer...), not plain neutral. Party is festive in December and
         spooky in the last week of October, when the critter has those.
         A pep-talk line can carry its own mood ({ "Snack break?",
         mood = "hungry" }).
  2.14.0 Critter phrase bank: Critter Insights and Critter Pep Talk read
         their lines from koreader/patches/critter-phrases.lua when it's
         there (several times the lines, a bit sassier; edit it freely).
         Missing or broken, the built-in lines are used as before. Same
         triggers, limits and steps (pep talk adds 90-119 min and 50-99
         pages). Reading Log reads the same file.
  2.13.9 Critter Pep Talk (Modules, on by default): SimpleUI's "minutes
         read today" and "pages turned today" lines grow with your
         reading. 1 minute gets a nudge, 15 a groove, an hour a party,
         and within 10 minutes of your daily goal it counts you in.
         Moves up a step on the next home screen draw as you read.
  2.13.8 Critter Bubble Max removed. To Be Read side panel: Side Panel
         Swipe Zone (Modules) - Narrow (default, 1/14 of the screen) or
         Edge Only (1/24): the swipe has to start nearer the edge, so page
         swipes don't open it by accident. Wide is the old 1/8.
  2.13.7 Page Turn Flash (SimpleUI Tweaks menu): SimpleUI turns home
         pages with a quiet update, so the old page ghosts through. Normal
         adds a quick flash to each turn, Strong a full refresh (dark pages
         and night mode). Off (default) as before.
  2.13.6 Critter text in night mode: the module text colours (Text Colour
         / Night Text Colour, made for text on the page or wallpaper) no
         longer reach inside the critter's bubble, which has its own
         background; in night mode they made the text the same colour as
         the bubble. Auto now keeps SimpleUI's ink (white on the dark
         bubble at night); White / Black are as they look, night included.
  2.13.5 Critter Text Colour (Modules): Auto writes the critter's speech
         in white when its bubble is dark (a dark SimpleUI look), White /
         Black always; its outline follows. Reading Log's critter too.
  2.13.4 Critter Position (Modules): Left, Right, or Left or right (never
         the middle) for the critter and its bubble in their row, so the
         middle of the row stays clear; works with or without Critter
         Wanders. With Critter Side, the cat's side of its text.
  2.13.3 Critters Everywhere removed. Critter Side (Modules) now works
         whatever the bubble width or Critter Wanders: Left of Text / Right
         of Text keeps the critter on that side of its bubble; the third
         choice uses SimpleUI's own Side (random while wandering).
  2.13.2 Fix: 2.13.0/2.13.1 stopped the patch from loading (Critters
         Everywhere used two helpers before the file defines them).
  2.13.1 Critter Side (Modules, with Critter Wanders on): keep the critter
         always left or always right of its text while the row still
         moves left, centre or right; Random keeps the old switching.
  2.13.0 Critters Everywhere (Modules → Critters Everywhere, on by
         default): SimpleUI's Tiny Critters on every KOReader window -
         top menus (Tools, Search, Add-ons, settings), button popups, the
         search box, confirmations, X-ray and other patches' popups, and
         full-screen pages (file browser, history, collections, lists,
         toolbar panels, the home screen). Never on the book page or the
         sleep screen. A critter only goes where that bit of the window is
         blank (one plain colour, plus a margin), so it never covers text,
         icons or lines; it sits on a bottom edge or hangs upside down from
         a top edge, and takes no taps. Options: menus/dialogs, pages,
         hanging, 1 or 2 per window, size, a different critter per window
         or one all day, and which critters (all, or tick the ones you
         want, your own packs included). Its mood fits the place. Drawn
         after the window paints; a spot is looked for once per window.
  2.12.6 Critter Insights, tightened:
         - Milestones fire when the count goes up to one (finishing that
           book), not when the home screen first sees it, and stay said for
           the year. Before, the record of what was said was trimmed to
           today's after 60 entries, so a milestone could come again.
         - What's remembered has its own life now: today's insights reset
           each day, milestones last the year, comebacks / quiet stretches
           / weekly ones are dropped after 90 days.
         - Back on a roll: once per comeback (was once a day for up to 4
           days).
         - Goal pace: books left over days left ("20 books to go, 69 days
           left. About one every 3 days catches you up."), worded for on
           pace or catching up; weekly from mid-January.
         - Weekend reader: needs 4+ weekend and 8+ weekday reading days in
           8 weeks; the verdict sticks until the difference is mostly gone.
  2.12.5 Tiny Critter:
         - Critter Bubble Width > Dynamic. The bubble keeps SimpleUI's
           width for short lines and grows, up to all the room the critter
           and decorations leave, when a line would otherwise be cut short.
           Measured with SimpleUI's own text box, per phrase (its chat
           replies too).
         - Critter Bubble Max: Full Row and Dynamic can stop short of the
           row's end (90% or 80% of the room), so a long bubble doesn't run
           to the edge.
         - Critter Wanders (Dynamic): each time the home screen draws the
           row, the critter and its bubble move to the left, centre or
           right of the row, with the critter on either side of the bubble
           (never the same spot twice in a row). Overrides SimpleUI's
           Side / Alignment while it's on.
         - Critter Insights: remarks from your reading history (best day
           this month, book milestones, back on a roll, nearly done with
           your book, goal pace this month, a gentle nudge after quiet
           days, weekend reading). Waits for the critter like SimpleUI's
           own reactions, once each, at most 3 a day, only when the stats
           back it. One statistics query a day. Its chat no longer offers
           the same book twice in a day.
         - Critter Row Height: Taller (+30%) or Tallest (+60%) gives the
           bubble room for its full 2 + 2 lines. The row keeps that height
           for every phrase, so nothing below it moves. The critter keeps
           its size (Critter Size > Fill Height grows it to the new row).
  2.12.4 Tiny Critter: Modules > Critter Size. SimpleUI draws the critter
         at the largest whole pixel step that fits the row, which often
         leaves it well short of its speech bubble. Fill Height scales it
         to the bubble's height (still sharp pixels, each a little
         uneven); Smaller takes it one pixel step down. Its moods, and
         decorations next to it, follow. Default is SimpleUI's own.
  2.12.3 Tiny Critter (SimpleUI 3.0): Modules > Critter Bubble Width
         makes its speech bubble wider (SimpleUI's is fixed), so longer
         lines fit on fewer rows. Its chat answers follow the bubble.
         The bubble still gives way to decorations and never leaves the
         row.
  2.12.2 SimpleUI 3.0:
         - Reading Stats takes the module colours again (it showed
           SimpleUI's own white in Night Mode). SimpleUI 3.0 moved it to
           modules/reading_stats/module_reading_stats, and only files
           directly in modules/ were hooked. Modules in a folder are now
           hooked too (also the new Critter module).
         - Palette colours SimpleUI 3.0 works out live (track,
           surface_flat: they follow the secondary colour and Night Mode)
           no longer get stuck at one value after this patch swaps them
           for a moment (progress accents, nav bar in Night Mode).
  2.12.1 Section titles on SimpleUI v3.0.0: the label builder moved to
         engines/sui_section_label, so the hook retargets there (v2.x
         inline fallback kept).
  2.12.0 TBR panel: more collections. Modules > Collections In Panel picks
         any of your KOReader collections (e.g. Book Club); each becomes a
         panel view after To Be Read: swipe left/right through To Be Read,
         your collections, Newly Added (one dot per view). Each works like
         To Be Read: 5 books, Show all, hold to remove from that collection.
         Panel Opens To can open straight to one. A picked collection with
         no books isn't shown, and a note says so (when you pick it, and
         once per start when the panel opens).
  2.11.15 TBR panel: dismisses on device suspend (was staying open over
         the sleep screen).
  2.11.14 TBR panel: switching views rebuilds the panel in place instead of
         closing and reopening it, so the home screen behind isn't redrawn
         each time (about 60 ms less per switch).
  2.11.13 TBR panel: back from History works again (2.11.12's faster view
         switch overwrote where back should go, so it stayed on History).
  2.11.12 TBR panel: switching views (swipe, history icon) is about 4x
         faster: a quick refresh of the panel instead of a full flash, and
         the home behind isn't flashed in between. Opening and closing the
         panel still do one full flash, which also clears any faint ghost
         left by switching.
  2.11.11 New Books on SimpleUI 2.7.5 (no book sources there, which 2.11.10
         relied on): the side panel's Newly Added view was always empty,
         and the home New Books module used SimpleUI's own folder walk
         (every 5 minutes, stops after 5000 entries, so a new book on a
         bigger library could be missed). Both now rank the newest files
         from SimpleUI's shared library scan, the one that notices a new
         book straight away, recomputed only when it re-walks.
  2.11.10 New Books (home module and the side panel's Newly Added): a book
         you add (e.g. from Calibre) shows up right away instead of after
         up to 5 minutes. SimpleUI's library scan already spots new books
         by checking folder dates (like Bookshelf's Latest); its newest-
         books ranking just waited on its own 5-minute timer. Now it's
         redone whenever the scan sees a change, reused otherwise.
  2.11.9 TBR panel: "Panel Opens To" now applies on every open (was only
         the first); added 4th option "Last View" to reopen wherever
         you left off.
  2.11.8 TBR panel: fixed tap-to-go-back in History view (custom paintTo
         was breaking gestures); back icon is now simple "<" text.
         New setting: Panel Opens To (To Be Read / Newly Added / History).
  2.11.7 TBR panel: back.svg wouldn't load on-device, so the History
         view's back icon is now a drawn chevron (reliable on Kobo).
  2.11.6 TBR panel: header icon uses SimpleUI's own path resolver
         (infra/sui_paths) for the absolute plugin dir — the relative
         plugins/... path failed on Kobo where CWD isn't the app dir.
  2.11.5 TBR panel: header icon is context-aware — history icon in
         TBR/New views, back icon in History view (tap returns to
         previous view).
  2.11.4 TBR panel: history icon fixed (was passing path as icon name,
         now uses file=); 2 dots for swipe views (TBR/New), History is
         tap-only via the icon again.
  2.11.3 TBR panel: history icon uses SimpleUI's own history.svg; swipe
         loops through all 3 views (TBR/New/History) and never closes —
         only tapping outside closes the panel. History view shows
         completion status ("Completed", "X% read", "Not started").
  2.11.2 TBR panel fixes: 2 view dots (not 3, History is tap-only); history
         icon is a drawn circular arrow (tap fixed); swiping back from
         History returns to the previous view instead of closing.
  2.11.1 TBR panel: view indicator dots at the bottom (TBR/New/History),
         and the history icon is a drawn clock now (the Unicode arrow
         didn't render on Kobo).
  2.11.0 To Be Read panel: swipe sideways to switch between To Be Read and
         Newly Added. History icon (top-right) shows your reading history.
  2.10.2 To Be Read side panel is narrower now (42% of screen width, was
         66%) — reads as a panel instead of a full page.
  2.10.1 To Be Read panel: one flash of just the panel area when it opens
         and closes, so it no longer leaves a ghost.
  2.10.0 To Be Read side panel: swipe in from the right edge of SimpleUI
         home (or the left, or off: Modules > To Be Read Side Panel). It
         lists the To Be Read collection (Bookshelf's "To Be Read" and
         SimpleUI's TBR), 5 books one per line with cover, title and
         author, "Show all (N)" when there are more. Tap opens a book,
         hold removes it from the list. Tap outside or swipe back to close.
  2.9.10 Currently Reading: days read and time left now show for the books
         you swipe to too, not just the current one (their stats id is read
         once from the book's sidecar; SimpleUI only had it for the
         current book).
  2.9.9  Currently Reading dots are drawn shapes now: a filled black dot for
         the book showing, black outlined circles for the others (the text
         glyph outlines were too faint to see).
  2.9.8  Swipe logging follows the SimpleUI diagnostic: on while it's
         installed and logging, off otherwise (no setting to remember).
  2.9.7  Currently Reading: dots are back, in a small row below the cover
         (not on it), filled dot = the book showing. The row only appears
         when there are 2+ books to swipe through. Swipe logging is off now
         that swipes work.
  2.9.6  Swipe fixed for real: SimpleUI's home screen takes every left/right
         swipe itself and only passes it to a book module that has an
         onSwipe handler (how Cover Deck gets its swipes). Ours was named
         differently, so the home screen never passed it on. Also: the book
         you swiped to survives a full home rebuild (it only resets when a
         book is opened or the list changes), and the swipe log is capped
         at 128 KB.
  2.9.5  Fixed swipe diagnostics log path (was writing to wrong location;
         now uses DataStorage path like other diagnostics).
  2.9.4  Removed the tap gesture entirely (v2.9.2/v2.9.3 broke swipe; the
         invisible tap zone was confusing). Back to swipe-only as in the
         working v2.9.1. Swipe left/right on the Currently Reading cover
         to change books.
  2.9.3  Removed the cover dots and the 2/2 page indicator visuals per TK
         (2/2 overlapped the title; header can't be hooked safely). Fixed
         the tap-zone crash (range must be a Geom, not a plain table).
         Invisible tap zone at top-right of the module remains: tap for
         next book.
  2.9.2  Tappable page indicator ("1/4") at top-right of Currently Reading
         (tap = next book) — swipe was sometimes captured by the quote
         module instead. Swipe diagnostics now log to diagnostics.log
         ([simpleui] tag): handler fires, idx changes, refresh results.
  2.9.1  Fixed swipe getting stuck on last book: the fallback refresh now
         does a full rebuild (was repaint-only, leaving the old book visible).
  2.9.0  Currently Reading: swipe left/right to step through your most recent
         books still in progress (4 by default, 2-6; finished ones skipped),
         with dots on the cover showing where you are. Tap opens the book
         shown. Only the module is repainted, no flash. Modules > Currently
         Reading: swipe between books.
  2.8.5  Title case for all menu item texts (per TK's house convention).
  2.8.4  Reverted the 2.8.0 title/nav hook changes (they caused module
         build failures with makeAlphaTextBox on some setups); kept the
         shared notification contract v1 from 2.8.1. Title/nav styling
         fixes are parked pending a root-cause fix.
  2.8.1  Shared notification contract v1: status notes (restart prompt,
         colour/size validation) go through Network Tweaks' or ReadMastery
         notify's style when installed, else the InfoMessage default.
  2.7.0  Windows opened from the menu while it stays open (e.g. Shortcuts
         Toolbar: ReadMastery quests) keep SimpleUI home underneath, so
         closing them goes back to the menu over the home instead of the
         stock library.
  2.6.0  Close Bookshelf goes straight to SimpleUI home (when it's your
         start screen) instead of showing the stock library for a moment
         first. Nothing to set.
  2.5.0  Removed Series folders (2.4.x): they only fix SimpleUI's own library
         file browser, and the library here is Bookshelf, which groups series
         itself. Its hooks on the file browser and Cover Browser are gone.
  2.4.2  The file browser check behind the series fixes' backup never
         matched (it looked for the name "filemanager", which is the file
         list's name, not the file browser's), so the backup never ran.
  2.4.1  Series folder fixes are hooked in once per SimpleUI install. Before,
         if another patch or plugin also hooked the file browser, each time
         the file browser opened could add another copy of them.
  2.4.0  Series folders (fixes for SimpleUI's series grouping, each a toggle
         under SimpleUI Tweaks > Series folders, all on by default):
         new series group as soon as Cover Browser has scanned the books
         (no more opening and closing a book first); closing a book from a
         series returns to that book's page instead of page 1; books with
         the same or no series number keep a fixed order.
  2.3.2  Trimmed: removed settings conversions from 1.x versions and the
         one-time Bold move from 2.0.0 (both long done), shorter changelog.
  2.3.1  Colour picker no longer looks cut off at the bottom: it now asks
         for its own screen refresh over the whole dialog instead of relying
         on the menu's, which only updated the area the menu covered.
  2.3.0  Faster Quote of the Day module. Each time it picked a quote,
         SimpleUI rewrote its whole settings file to disk three times and
         wrote debug lines to crash.log. Now the quote position is kept in
         memory and saved when the Kobo sleeps or KOReader closes (as
         SimpleUI already does for everything), and those debug lines are
         skipped. Nothing changes on screen.
  2.2.0  Removed the Colour boost for e-ink setting (it only changes
         coloured text, so it made no visible difference here). Colours
         are drawn exactly as picked again. The deep "Ink" swatches in the
         colour picker stay.
  2.1.1  A module set to "SimpleUI default" text colour keeps it when it
         refreshes in place (e.g. stats after closing a book); it could pick
         up the All modules colour there. Hardening for future SimpleUI
         versions: a missing palette colour can't leave an override behind,
         and the clock hook only wraps a real function.
  2.1.0  Colour boost for e-ink (Off / Medium / Strong): text colours you
         pick are drawn deeper and more saturated so they hold up on colour
         e-ink, which washes colours out. Hue is kept; black, white and greys
         are untouched; in Night Mode colours stay bright enough to read on
         the dark background. Applies to module text (normal and Night Mode,
         all modules and per module) and section titles, not to progress
         bars or borders. The colour picker previews text colours with the
         boost, and has a new row of deep "Ink" shades made for colour
         e-ink.
  2.0.0  For SimpleUI 2.7.5. Removed what SimpleUI now does itself: module
         Bold (SimpleUI: each module's Text > Style) and nav bar Bold labels
         (SimpleUI: nav bar label Style). Your Bold choices are moved into
         SimpleUI's own settings once, so nothing changes on screen, and the
         two can no longer stack (double bold). Also removed: the reader tab
         id workaround (fixed in SimpleUI 2.7.5) and the old Shortcuts
         Toolbar fix that looked for its internals (1.10.2's covers every
         version).
  1.x    Earlier versions: see the GitHub history.
]]

local VERSION = "2.14.10"

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
        titles  = false,            -- (module and nav bar text: SimpleUI's own
    },                              --  Text > Style since SimpleUI 2.7.5)
    title_size       = 100,         -- section title size, % (x SimpleUI's own label scale)
    titles           = {},          -- per-section overrides: [module id] = { color, bold, size }
    module_colors    = {},          -- per-module text: [module id] = { text, night }
    currently_swipe  = true,        -- Currently Reading: swipe between in-progress books
    currently_books  = 4,           --   how many (current book included), 2-6
    critter_bubble   = 0,           -- Tiny Critter speech bubble width, dp at 100% scale (0 = SimpleUI's own, -1 = dynamic)
    critter_size     = "default",   -- Tiny Critter size: "default" (SimpleUI) / "fill" (bubble height) / "smaller"
    critter_row      = 100,         -- Tiny Critter row height, % of SimpleUI's
    critter_insights = true,        -- remarks from your reading history (Critter Insights)
    critter_pep      = true,        -- "minutes / pages today" lines that grow with your reading (Critter Pep Talk)
    critter_mix      = {},          -- critters taking turns (ids of SimpleUI's critter folders); fewer than 2 = off
    critter_wander   = true,        -- Dynamic bubble: random spot and side each draw
    critter_wander_side = "random", -- critter "left" / "right" of its bubble, or SimpleUI's ("random" while wandering)
    early_turn       = false,       -- turn on swipe distance, not on lift
    early_turn_dp    = 35,          -- 35 / 50 / 80 dp
    early_turn_lists = true,        -- also full-screen KOReader lists
    page_flash       = "off",       -- home screen page turns: "off" / "normal" (UI flash) / "strong" (full refresh)
    critter_text     = "auto",      -- critter's speech text: "auto" (white on a dark bubble) / "white" / "black"
    critter_pos      = "wander",    -- row spot: "wander" / "left" / "right" / "edges" (left or right, never the middle)
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
    -- keep saved keys that have no default (e.g. per-module colours, per-section titles)
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
    -- retired settings
    m.topbar_bold, m.show_popup, m.nav_icon_night, m.colour_boost, m.series = nil, nil, nil, nil, nil
    m.bold.modules, m.bold.nav, m.menu_icons.tabs = nil, nil, nil
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

-- A module's own text colour settings, if any (instances like Quick Actions
-- rows match their module id as a prefix).
local function moduleColors(id)
    if type(id) ~= "string" then return nil end
    local mc = cfg.module_colors
    if mc[id] then return mc[id] end
    for key, t in pairs(mc) do
        if id:sub(1, #key) == key then return t end
    end
    return nil
end

-- Text colour for a module, as drawn (Night Mode values pre-inverted).
-- nil = leave SimpleUI's colour.
local function colorForModule(id)
    local t = moduleColors(id)
    if Screen.night_mode then
        local n = t and t.night
        if n ~= nil and n ~= "none" then return colorOf(n, true) end
        if n == nil and NIGHT_C then return NIGHT_C end
        -- "none" (inverts with the screen) falls through to the day colour
    end
    local d = t and t.text
    if d ~= nil then return colorOf(d) end   -- "none" -> nil
    return TEXT_C
end

-- ---- scopes -----------------------------------------------------------------------
local cur_color = nil  -- colour applied to text built right now
local suspended = 0    -- > 0: don't recolour (mask internals)
local flip_kind = nil  -- "nav" | "title" | "topbar" while building those
local icon_kind = nil  -- icons only: "quick_actions" | "menu_tab" | "menu_arrow"
local in_mask   = 0    -- > 0: painting through an alpha mask

local function pack(...) return { n = select("#", ...), ... } end

local keep_own  = 0    -- > 0: inside a module/title set to SimpleUI's own colour

local function withColor(c, fn, ...)
    if not c then
        keep_own = keep_own + 1
        local res = pack(pcall(fn, ...))
        keep_own = keep_own - 1
        if not res[1] then error(res[2], 0) end
        return unpack(res, 2, res.n)
    end
    local prev = cur_color
    cur_color = c
    local res = pack(pcall(fn, ...))
    cur_color = prev
    if not res[1] then error(res[2], 0) end
    return unpack(res, 2, res.n)
end

local function tabOn(name)
    return type(name) == "string" and cfg.menu_icons.tab[name] == true
end
local function anyTabOn() return next(cfg.menu_icons.tab) ~= nil end

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
-- A key the palette didn't have is saved as `false`, so restoring clears it.
local function swapAccents(C, saved)
    local ovr = Screen.night_mode and acc_ovr_night or acc_ovr_day
    for i = 1, #ACC_KEYS do
        local k = ACC_KEYS[i]
        local v = ovr[k]
        if v then
            -- raw only: SimpleUI 3.0 works some keys out live (track); those
            -- are cleared again afterwards, not set to today's value
            local was = rawget(C, k)
            if was then saved[k] = was else saved[k] = false end
            C[k] = v
        end
    end
end
local function restoreAccents(C, saved)
    for i = 1, #ACC_KEYS do
        local k = ACC_KEYS[i]
        -- rawequal/truthiness only: comparing a colour with nil crashes (its __eq)
        local was = saved[k]
        if rawequal(was, false) then C[k] = nil; saved[k] = nil
        elseif was then C[k] = was; saved[k] = nil end
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
        if cur_color or flip_kind then
            if cur_color and suspended == 0 and shouldRecolor(self.fgcolor) then
                self.fgcolor = cur_color
            end
            -- bold also applies inside masks (the mask shape IS the glyphs)
            if flip_kind and boldForKind(flip_kind) then self.bold = true end
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

-- Tabs other plugins recognise menus by, with KOReader's stock icon name.
-- Shortcuts Toolbar looks for these names to tell the library and reader
-- menus apart; SimpleUI's custom tab icons replace them.
local STOCK_TAB_ICON = {
    filemanager_settings = "appbar.filebrowser",
    navi                 = "appbar.navigation",
    typeset              = "appbar.typeset",
}

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
                        -- The icons are drawn now: give these tabs their stock
                        -- name back so other plugins still recognise the menu.
                        -- SimpleUI sets the custom name again before the menu
                        -- is next drawn.
                        local stock = STOCK_TAB_ICON[id]
                        if stock and tab.icon ~= stock then tab.icon = stock end
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
        -- Quick Actions icons get the Night Mode switch (checked when drawn)
        local prev_icon_kind = icon_kind
        if type(id) == "string" and id:sub(1, 13) == "quick_actions" then icon_kind = "quick_actions" end
        if accent then
            ok, w = pcall(withAccents, withColor, colorForModule(id), orig, ...)
        else
            ok, w = pcall(withColor, colorForModule(id), orig, ...)
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
                if isAccentModule(id) then
                    res = pack(pcall(withAccents, withColor, colorForModule(id), orig_upd, ...))
                else
                    res = pack(pcall(withColor, colorForModule(id), orig_upd, ...))
                end
                if res[1] then return unpack(res, 2, res.n) end
                logger.warn(TAG, fname, "failed for", id, res[2])
                return orig_upd(...)
            end
        end
    end
    return orig
end

-- Quote module: picking a quote saves its place in the shuffled deck as three
-- settings, and each save rewrites SimpleUI's whole settings file to disk;
-- it also writes debug lines to crash.log on every build. While it builds,
-- deck saves stay in memory (SimpleUI writes everything to disk on sleep and
-- exit) and those debug lines are skipped. Real warnings still get through.
local QUOTE_DEBUG = { "^simpleui quote: ", "^simpleui: quote: build source=", "^simpleui: quote: showing highlight" }
local function isQuoteDebug(msg)
    if type(msg) ~= "string" then return false end
    for i = 1, #QUOTE_DEBUG do
        if msg:find(QUOTE_DEBUG[i]) then return true end
    end
    return false
end
local function quietQuoteBuild(M)
    if type(M.build) ~= "function" or M._sui_tweaks_quiet then return end
    local Store = package.loaded["infra/sui_store"]
    if type(Store) ~= "table" or type(Store.saveSetting) ~= "function"
            or type(Store.setNoFlush) ~= "function" then return end
    M._sui_tweaks_quiet = true
    local orig_build = M.build
    M.build = function(...)
        local orig_save, orig_warn = Store.saveSetting, logger.warn
        Store.saveSetting = function(self, key, value, ...)
            if type(key) == "string" and key:find("^simpleui_quote_.*deck_") then
                return Store.setNoFlush(self, key, value)
            end
            return orig_save(self, key, value, ...)
        end
        logger.warn = function(msg, ...)
            if isQuoteDebug(msg) then return end
            return orig_warn(msg, ...)
        end
        local res = pack(pcall(orig_build, ...))
        Store.saveSetting, logger.warn = orig_save, orig_warn
        if not res[1] then error(res[2], 0) end
        return unpack(res, 2, res.n)
    end
end

-- ---- Currently Reading: swipe between books --------------------------------
-- Swipe left/right on the module to step through the most recent books still
-- in progress (from KOReader's reading history, finished ones skipped). Dots on
-- the cover show where you are. Only this module is repainted (SimpleUI's own
-- single-slot refresh, the one Cover Deck swipes use). A new home build (e.g.
-- after closing a book) starts again from the current book.
local swipe_state = {}   -- [screen pfx] = { ctx, top, idx, fps, n, dots = {} }
local SCAN_MAX = 30      -- history entries looked at, at most

local function inProgressList(ctx, n)
    local fps, seen = { ctx.current_fp }, { [ctx.current_fp] = true }
    local okh, RH = pcall(require, "readhistory")
    local hist = okh and type(RH) == "table" and RH.hist
    if type(hist) ~= "table" then return fps end
    local okl, lfs = pcall(require, "libs/libkoreader-lfs")
    local okb, SH = pcall(require, "modules/module_books_shared")
    for i = 1, math.min(#hist, SCAN_MAX) do
        if #fps >= n then break end
        local fp = hist[i] and hist[i].file
        if type(fp) == "string" and not seen[fp] then
            seen[fp] = true
            if okl and lfs.attributes(fp, "mode") == "file" then
                local pct, status
                local pd = type(ctx.prefetched) == "table" and ctx.prefetched[fp]
                if type(pd) == "table" and pd.percent ~= nil then
                    pct = pd.percent
                    status = type(pd.summary) == "table" and pd.summary.status or nil
                elseif okb and type(SH) == "table" and type(SH.getBookData) == "function" then
                    local okd, bd = pcall(SH.getBookData, fp)
                    if okd and type(bd) == "table" then pct, status = bd.percent, bd.status end
                end
                if not ((pct or 0) >= 1 or status == "complete") then fps[#fps + 1] = fp end
            end
        end
    end
    return fps
end

local function findTappable(w, depth)
    if type(w) ~= "table" or depth > 8 then return nil end
    if rawget(w, "_cover_slots") and rawget(w, "ges_events") then return w end
    for i = 1, #w do
        local t = findTappable(w[i], depth + 1)
        if t then return t end
    end
end

-- Dots in a small white pill at the bottom of the cover (no extra height).
-- Swipe lines go to the SimpleUI diagnostic's log while it's on (and within
-- its logging window); without it, nothing is written.
local function diagLog(fmt, ...)
    local D = package.loaded["simpleui_diagnostics"]
    if type(D) ~= "table" or type(D.log) ~= "function" then return end
    pcall(D.log, "swipe: " .. fmt, ...)
end

-- Dots in a row just below the module, centred under the cover. The module
-- reports itself that much taller (getSize), so SimpleUI lays out and
-- refreshes the extra row with it; the module's own widgets are untouched.
local DOT     = Screen:scaleBySize(9)   -- dot size
local DOT_GAP = Screen:scaleBySize(6)   -- space between dots
local RING    = math.max(2, Screen:scaleBySize(1.5))  -- outline width of the other dots
local DOTS_GAP = Screen:scaleBySize(5)  -- space between the cover and the dots

-- Drawn shapes, not text glyphs: a filled black dot for the book showing,
-- black outlined circles for the others (thin glyph outlines were too faint).
local function paintDots(bb, st, tap, x, y, base_h)
    local n = #st.fps
    local total = n * DOT + (n - 1) * DOT_GAP
    local cx, cw
    local slot = type(tap._cover_slots) == "table" and tap._cover_slots[1]
    if type(slot) == "table" and type(slot.container) == "table" then
        local c = slot.container[slot.idx or 1]
        local r = (type(c) == "table" and c.dimen and c.dimen.x and c.dimen) or slot.container.dimen
        if r and r.x and r.w then cx, cw = r.x, r.w end
    end
    if not cx then cx, cw = x, total end   -- no cover position: left edge
    local px = cx + math.floor((cw - total) / 2)
    local py = y + base_h + DOTS_GAP
    local radius = math.floor(DOT / 2)
    for i = 1, n do
        local dx = px + (i - 1) * (DOT + DOT_GAP)
        if i == st.idx then
            bb:paintRoundedRect(dx, py, DOT, DOT, Blitbuffer.COLOR_BLACK, radius)
        else
            bb:paintRoundedRect(dx, py, DOT, DOT, Blitbuffer.COLOR_WHITE, radius)
            bb:paintBorder(dx, py, DOT, DOT, RING, Blitbuffer.COLOR_BLACK, radius)
        end
    end
end

local function addSwipe(root, st, ctx)
    local tap = findTappable(root, 0)
    if not tap then
        diagLog("addSwipe: no tappable widget found, swipe not registered")
        return
    end
    diagLog("addSwipe: registered, %d books, idx=%d", #st.fps, st.idx)
    local BD = require("ui/bidi")
    -- SimpleUI's home screen catches every left/right swipe itself
    -- (ScreenWidget:onScreenSwipe) and hands it to the first widget with an
    -- onSwipe method inside a book module it lands on, else turns the page.
    -- So the handler has to be called onSwipe; a ges_events entry never fires.
    -- v2.9.4: tap gesture REMOVED (v2.9.2/v2.9.3 broke swipe; tap zone was
    -- invisible and confusing). Swipe only, as in working v2.9.1.
    local function advance(step, via)
        local n = #st.fps
        if n < 2 then return false end
        local old = st.idx
        st.idx = (st.idx - 1 + step) % n + 1
        if st.idx < 1 then st.idx = 1 elseif st.idx > n then st.idx = n end
        diagLog("%s: idx %d -> %d (n=%d)", via, old, st.idx, n)
        local scr = ctx._screen_widget
        if type(scr) == "table" then
            local ok, done = pcall(function()
                return scr._refreshBookModSlot and scr:_refreshBookModSlot("currently")
            end)
            diagLog("%s: _refreshBookModSlot ok=%s done=%s", via, tostring(ok), tostring(done))
            if not (ok and done) and scr._refreshImmediate then
                scr:_refreshImmediate(false)
                diagLog("%s: fallback _refreshImmediate(false) called", via)
            end
        else
            diagLog("%s: no _screen_widget, no refresh", via)
        end
        return true
    end
    tap.onSwipe = function(_self, _, ges)
        local dir = ges and ges.direction
        diagLog("swipe detected, dir=%s", tostring(dir))
        if BD.mirroredUILayout() then
            if dir == "west" then dir = "east" elseif dir == "east" then dir = "west" end
        end
        local step = (dir == "west" and 1) or (dir == "east" and -1) or nil
        if not step then
            diagLog("swipe: no step for dir=%s, ignoring", tostring(dir))
            return false
        end
        return advance(step, "swipe")
    end
    -- v2.9.7: dots back, in their own row below the cover (not on it).
    if rawget(root, "_sui_dots_hooked") then return end
    rawset(root, "_sui_dots_hooked", true)
    local Geom = require("ui/geometry")
    local orig_size, orig_paint = root.getSize, root.paintTo
    local extra = DOT + DOTS_GAP * 2
    root.getSize = function(self)
        local sz = orig_size(self)
        return Geom:new{ x = sz.x, y = sz.y, w = sz.w, h = sz.h + extra }
    end
    root.paintTo = function(self, bb, x, y, ...)
        orig_paint(self, bb, x, y, ...)
        local ok, base = pcall(orig_size, self)
        if ok and base then pcall(paintDots, bb, st, tap, x, y, base.h) end
    end
end

-- Days read / time left for a swiped-to book. The module only finds a book's
-- stats id (partial md5) in SimpleUI's prefetch, which holds the current
-- book; for the others it's read once from the book's sidecar and kept.
local function bookStats(M, st, fp, ctx)
    if type(M.fetchBookStatsForCtx) ~= "function" then return false end
    st.md5 = st.md5 or {}
    local md5 = st.md5[fp]
    if md5 == nil then
        local pd = type(ctx.prefetched) == "table" and ctx.prefetched[fp]
        md5 = type(pd) == "table" and pd.partial_md5_checksum or nil
        if not md5 then
            local okd, DS = pcall(require, "docsettings")
            local ok, ds = false, nil
            if okd and type(DS) == "table" then ok, ds = pcall(DS.open, DS, fp) end
            if ok and ds then
                md5 = ds:readSetting("partial_md5_checksum")
                pcall(function() ds:close() end)
            end
        end
        st.md5[fp] = md5 or false
    end
    if not md5 then return false end
    local ok, stats = pcall(M.fetchBookStatsForCtx, md5, ctx.db_conn)
    return (ok and stats) and { fp = fp, stats = stats } or false
end

local function patchCurrentlySwipe(M)
    if type(M.build) ~= "function" or wrapped[M.build] then return end
    local orig = M.build
    M.build = function(w, ctx, ...)
        if not cfg.currently_swipe or type(ctx) ~= "table" or not ctx.current_fp then
            return orig(w, ctx, ...)
        end
        local key = ctx.pfx or ""
        local n = math.max(2, math.min(6, tonumber(cfg.currently_books) or 4))
        -- Opening any book (even the same one) updates the top history entry's
        -- time, so that's what starts the list again from the current book.
        -- Not the ctx table: a full home rebuild makes a new one, and the
        -- swipe's fallback refresh is a full rebuild.
        local okh, RH = pcall(require, "readhistory")
        local h1 = okh and type(RH) == "table" and type(RH.hist) == "table" and RH.hist[1]
        local stamp = type(h1) == "table" and tostring(h1.file) .. "@" .. tostring(h1.time) or ""
        local st = swipe_state[key]
        if not st or st.stamp ~= stamp or st.top ~= ctx.current_fp or st.n ~= n then
            local okl, fps = pcall(inProgressList, ctx, n)
            st = { stamp = stamp, top = ctx.current_fp, idx = 1, n = n, dots = {},
                   fps = okl and fps or { ctx.current_fp } }
            swipe_state[key] = st
        end
        if #st.fps < 2 then return orig(w, ctx, ...) end
        if st.idx > #st.fps then st.idx = 1 end
        local use = ctx
        if st.idx > 1 then
            -- this build only: another book; reads and writes go to the real ctx
            local fp = st.fps[st.idx]
            use = setmetatable({ current_fp = fp, currently_book_stats = bookStats(M, st, fp, ctx) },
                               { __index = ctx, __newindex = ctx })
        end
        local widget = orig(w, use, ...)
        if widget ~= nil then
            local ok, err = pcall(addSwipe, widget, st, ctx)
            if not ok then logger.warn(TAG, "currently swipe:", err) end
        end
        return widget
    end
    wrapped[M.build] = true
end

local patchNewBooksModule   -- New Books (SimpleUI 2.7.5): defined below

-- Tiny Critter (SimpleUI 3.0): its bubble width is a constant in the module
-- (BUBBLE_DP, dp at 100% scale), shared by every function of the file. The
-- chosen width replaces it; 0 puts SimpleUI's own back. The module still
-- shrinks the bubble for decorations and to fit the row.
local critter_bubble = nil   -- { fn, idx, stock }
local function applyCritterBubble()
    local cb = critter_bubble
    if not cb then return end
    local want = tonumber(cfg.critter_bubble) or 0
    -- Dynamic: the module lays out the widest bubble; patchCritterBubbleBuild
    -- then narrows each bubble to what its text needs
    if want < 0 then want = 2000 end
    debug.setupvalue(cb.fn, cb.idx, want > 0 and want or cb.stock)
end
-- Tiny Critter size (SimpleUI 3.0, modules/critter/sprite). SimpleUI enlarges
-- pixel art by the largest whole factor that fits the row, so the critter is
-- often well short of the bubble. Only the critter's own images are touched
-- (decorations are made with a max_pixel and keep sharing its pixel size):
--   smaller  one whole step down
--   fill     scaled by nearest neighbour to the bubble's height (or the width
--            the module allows), cached like SimpleUI's own images
-- Tiny Critter row height: the module's row is a constant (BASE_H_DP, inside
-- its rowHeight(), which both build and getHeight use, so the home screen
-- lays out the taller row everywhere). The critter keeps its size unless
-- Fill Height is on: its images get the old height as their box.
local critter_row = nil   -- { fn = rowHeight, idx, stock }
local function rowPct()
    local v = tonumber(cfg.critter_row) or 100
    return (v >= 100 and v <= 200) and v or 100
end
local function applyCritterRow()
    local cr = critter_row
    if not cr then return end
    debug.setupvalue(cr.fn, cr.idx, math.floor(cr.stock * rowPct() / 100 + 0.5))
end
-- Whether the sprite being made is the home screen critter's (not Reading Log's).
local function fromCritterModule()
    for level = 3, 7 do
        local info = debug.getinfo(level, "S")
        if not info then return false end
        if (info.source or ""):find("modules/critter/module_critter", 1, true) then return true end
    end
    return false
end

local critter_sprite_on = false
local patchCritterSprite = function(Sprite)
    if type(Sprite) ~= "table" or type(Sprite.init) ~= "function" or type(Sprite._entry) ~= "function" then return false end
    if ours[Sprite.init] then return true end
    local RC = package.loaded["infra/sui_raster_cache"]
    if type(RC) ~= "table" or type(RC.get) ~= "function" then return false end
    local orig_init, orig_entry = Sprite.init, Sprite._entry

    local function fillFactor(self, e)
        local opaque = e.h - (e.foot or 0)
        if not e.bb or opaque <= 0 or e.w <= 0 then return nil end
        local f = math.min(self.max_h / opaque, self.max_w / e.w)
        return f > 1.02 and f or nil
    end
    local function buildFill(self)
        local e = orig_entry(self)
        local f = fillFactor(self, e)
        if not f then return { w = e.w, h = e.h, foot = e.foot or 0 } end
        local nw, nh = math.floor(e.w * f), math.floor(e.h * f)
        local bb = e.bb:scale(nw, nh)
        return { bb = bb, w = nw, h = nh, foot = math.floor((e.foot or 0) * f),
                 straight = e.straight, pixel = e.pixel }
    end

    Sprite.init = mine(function(self, ...)
        local mode = cfg.critter_size
        -- a taller row: the critter's own images keep the old height
        if self.max_pixel == nil and mode ~= "fill" and rowPct() > 100 and type(self.max_h) == "number"
                and critter_row and fromCritterModule() then
            self.max_h = math.floor(self.max_h * 100 / rowPct() + 0.5)
        end
        if self.max_pixel ~= nil or (mode ~= "smaller" and mode ~= "fill") then
            return orig_init(self, ...)
        end
        orig_init(self, ...)
        if not self.pixel then return end   -- not pixel art: SimpleUI's own scaling
        if mode == "smaller" then
            if self.pixel > 1 then
                self.max_pixel = self.pixel - 1
                return orig_init(self, ...)
            end
            return
        end
        local e = orig_entry(self)
        if not fillFactor(self, e) then return end
        self._tw_fill_key = self.key .. "|tweaks_fill"
        local fe = self:_entry()
        if fe.bb then
            self.dimen.w, self.dimen.h = fe.w, fe.h - fe.foot
        else
            self._tw_fill_key = nil
        end
    end)
    Sprite._entry = mine(function(self)
        if not self._tw_fill_key then return orig_entry(self) end
        return RC.get("critter", self._tw_fill_key, buildFill, self)
    end)
    critter_sprite_on = true
    return true
end

-- Dynamic bubble width: Bubble.build calls from the critter module (not
-- Reading Log's) get the narrowest width, from SimpleUI's own up to the room
-- the module gave, at which the text shows whole (main line and second line
-- in at most 2 lines each, inside the bubble's height). The row lays itself
-- out around the narrower bubble.
local _bh = {}
local function boxHeight(UI, face, bold, text, width)
    local key = table.concat({ tostring(face), tostring(bold), width, text }, "|")
    if _bh[key] then return _bh[key] end
    local ok, box = pcall(UI.makeTextBox, { text = text, face = face, bold = bold, width = width })
    if not ok or not box then return nil end
    local h = box:getSize().h
    pcall(box.free, box)
    local n = 0
    for _ in pairs(_bh) do n = n + 1 end
    if n > 200 then _bh = {} end
    _bh[key] = h
    return h
end

local function wholeAt(Bubble, UI, o, w)
    local _b, _p, reach, frame = Bubble.metrics(o.scale, o.side ~= nil, o.style, o.unit)
    local tw = w - reach - frame
    if tw <= 20 then return false end
    local mh, ml = boxHeight(UI, o.msg_face, o.msg_bold, o.message, tw), boxHeight(UI, o.msg_face, o.msg_bold, "Xg", tw)
    if not (mh and ml) then return true end
    if mh > 2 * ml + 1 then return false end
    local used = mh + frame
    if o.detail then
        local dh, dl = boxHeight(UI, o.det_face, o.det_bold, o.detail, tw), boxHeight(UI, o.det_face, o.det_bold, "Xg", tw)
        if not (dh and dl) then return true end
        if dh > 2 * dl + 1 then return false end
        used = used + dh + math.floor(Screen:scaleBySize(2) * (o.scale or 1))
    end
    return used <= o.h
end


-- Critter Text Colour: the ink of the speech bubble's text. The bubble has
-- its own background, so the text colours set for modules (Text Colour /
-- Night Text Colour, made for text on the page or wallpaper) don't apply
-- inside it: in night mode they could turn it the same as the bubble.
-- Auto: SimpleUI's ink, which always stands out on the bubble (white on a
-- dark bubble, e.g. in night mode); White / Black: as it should LOOK, so in
-- night mode (where the screen is inverted) the paint is swapped.
local function critterInk()
    local mode = cfg.critter_text or "auto"
    if (mode == "white" or mode == "black") and Screen.night_mode then
        mode = (mode == "white") and "black" or "white"
    end
    if mode == "black" then return Blitbuffer.COLOR_BLACK, Blitbuffer.COLOR_DARK_GRAY end
    if mode == "white" then return Blitbuffer.COLOR_WHITE, Blitbuffer.COLOR_LIGHT_GRAY end
    local S = package.loaded["features/sui_style"]
    local ok, v = pcall(function() return S.COLOR.surface:getColor8().a end)
    if ok and type(v) == "number" and v < 128 then return Blitbuffer.COLOR_WHITE, Blitbuffer.COLOR_LIGHT_GRAY end
    return nil
end
-- Runs fn with no module text colour applied (Tweaks' recolouring off).
local function ownInk(fn, ...)
    local prev_c, prev_k = cur_color, keep_own
    cur_color, keep_own, suspended = nil, keep_own + 1, suspended + 1
    local res = pack(pcall(fn, ...))
    cur_color, keep_own, suspended = prev_c, prev_k, suspended - 1
    if not res[1] then error(res[2], 0) end
    return unpack(res, 2, res.n)
end
local function withCritterInk(fn, ...)
    local S, U = package.loaded["features/sui_style"], package.loaded["infra/sui_core"]
    local ink, sub = critterInk()
    -- the module text colours stay out of the bubble
    if not ink or type(S) ~= "table" or type(S.COLOR) ~= "table" then return ownInk(fn, ...) end
    local old_ink = rawget(S.COLOR, "text_primary")
    local old_sub = type(U) == "table" and rawget(U, "CLR_TEXT_SUB") or nil
    rawset(S.COLOR, "text_primary", ink)
    if type(U) == "table" then rawset(U, "CLR_TEXT_SUB", sub) end
    local res = { pcall(ownInk, fn, ...) }
    rawset(S.COLOR, "text_primary", old_ink)
    if type(U) == "table" then rawset(U, "CLR_TEXT_SUB", old_sub) end
    if not res[1] then error(res[2], 0) end
    return unpack(res, 2, table.maxn(res))
end

local patchCritterBubbleBuild = function(Bubble)
    if type(Bubble) ~= "table" or type(Bubble.build) ~= "function" or type(Bubble.metrics) ~= "function" then return false end
    if ours[Bubble.build] then return true end
    local orig = Bubble.build
    local narrow
    Bubble.build = mine(function(o, ...)
        -- who's building it: the home screen critter (narrowing applies) or
        -- another (Reading Log's critter: ink only)
        local info = debug.getinfo(2, "S")
        local from_home = ((info and info.source) or ""):find("modules/critter/module_critter", 1, true) ~= nil
        return withCritterInk(narrow, from_home, o, ...)
    end)
    narrow = function(from_home, o, ...)
        local dynamic = (tonumber(cfg.critter_bubble) or 0) < 0
        if dynamic and critter_bubble and type(o) == "table"
                and type(o.w) == "number" and type(o.message) == "string" then
            if from_home then
                local UI = package.loaded["infra/sui_core"]
                local base = math.floor(Screen:scaleBySize(critter_bubble.stock) * (o.scale or 1))
                local top = o.w
                if dynamic and type(UI) == "table" and type(UI.makeTextBox) == "function" and top > base then
                    local pick = top
                    local steps = 6
                    for i = 0, steps do
                        local cand = base + math.floor((top - base) * i / steps)
                        if wholeAt(Bubble, UI, o, cand) then pick = cand break end
                    end
                    top = pick
                end
                if top < o.w then
                    local narrowed = {}
                    for k, v in pairs(o) do narrowed[k] = v end
                    narrowed.w = top
                    return orig(narrowed, ...)
                end
            end
        end
        return orig(o, ...)
    end
    return true
end

local function patchCritterBubble(build)
    if not critter_row then
        local rh = findUpvalue(build, "rowHeight")
        local v, idx = findUpvalue(rh, "BASE_H_DP")
        if type(v) == "number" and idx then
            critter_row = { fn = rh, idx = idx, stock = v }
            applyCritterRow()
        end
    end
    if critter_bubble then return end
    local v, idx = findUpvalue(build, "BUBBLE_DP")
    if type(v) ~= "number" or not idx then return end
    critter_bubble = { fn = build, idx = idx, stock = v }
    applyCritterBubble()
end

-- Critter Wanders (Dynamic only): a random side (critter left or right of the
-- bubble) and spot (left / centre / right) each build, read in place of
-- SimpleUI's own settings for that build only. The module lays out the
-- widest bubble and places the group only when it's narrower than the row,
-- so once the bubble has narrowed the row is placed here, also after the
-- phrase changes (fresh statistics, the chat's "something else" / replies).
local patchCritterWander
do
local wander_last, wander_last_align
local wander_roots = setmetatable({}, { __mode = "k" })
local wander_live = setmetatable({}, { __mode = "v" })
local function wanderOn()
    return (tonumber(cfg.critter_bubble) or 0) < 0 and cfg.critter_wander ~= false
end
-- Critter Position: where in the row the critter and its bubble go.
--   "wander" (default) left / centre / right while wandering, else SimpleUI's
--   "left" / "right" always that end of the row
--   "edges" the left or the right end, never the middle
local function posAligns()
    local p = cfg.critter_pos
    if p == "left" or p == "right" then return { p } end
    if p == "edges" then return { "left", "right" } end
    return nil
end
local function sideFixed()
    local v = cfg.critter_wander_side
    return (v == "left" or v == "right") and v or nil
end
local function wanderPick()
    local spots = {}
    -- Critter Side: "left" / "right" keeps the critter on that side of its
    -- bubble; "random" lets it switch too
    local sides = sideFixed() and { sideFixed() } or { "left", "right" }
    for _i, side in ipairs(sides) do
        for _j, align in ipairs(posAligns() or { "left", "center", "right" }) do
            local key = side .. "/" .. align
            if key ~= wander_last then spots[#spots + 1] = { side, align, key } end
        end
    end
    if #spots == 0 then   -- only one spot allowed: it repeats
        wander_last = nil
        return wanderPick()
    end
    local spot = spots[math.random(#spots)]
    wander_last = spot[3]
    return spot[1], spot[2]
end
local function wanderPlace(root)
    local st = wander_roots[root]
    local inner = type(root) == "table" and root[1]
    if not st or type(inner) ~= "table" or inner._tw_wander or type(inner.getSize) ~= "function" then return end
    local size = inner:getSize()
    if not (size and size.w and size.w < st.w) then return end   -- full row, or the module's own placing
    local Geom = require("ui/geometry")
    local box = require("ui/widget/container/" .. st.align .. "container")
    root[1] = box:new{ dimen = Geom:new{ w = st.w, h = st.h }, allow_mirroring = false, _tw_wander = true, inner }
end
function patchCritterWander(M)
    if type(M) ~= "table" or type(M.build) ~= "function" or ours[M.build] then return end
    local orig = M.build
    M.build = mine(function(w, ctx, ...)
        -- what this build overrides: the side and the spot while wandering,
        -- or just what Critter Side / Critter Position fix
        local side, align
        if wanderOn() and type(w) == "number" then
            side, align = wanderPick()
        else
            side = sideFixed()
            local aligns = posAligns()
            if aligns then
                if #aligns == 1 then align = aligns[1]
                else
                    local pick = {}
                    for _i, a in ipairs(aligns) do if a ~= wander_last_align then pick[#pick + 1] = a end end
                    align = pick[math.random(#pick)]
                end
                wander_last_align = align
            end
        end
        if not side and not align then return orig(w, ctx, ...) end
        local Config = package.loaded["infra/sui_config"]
        local ga = type(Config) == "table" and Config.getAlignment
        if type(ga) ~= "function" then return orig(w, ctx, ...) end
        local pfx = type(ctx) == "table" and ctx.pfx or "simpleui_hs_"
        Config.getAlignment = function(key, ...)
            if side and key == pfx .. "critter_side" then return side end
            if align and key == pfx .. "critter_align" then return align end
            return ga(key, ...)
        end
        local ok, root = pcall(orig, w, ctx, ...)
        Config.getAlignment = ga
        if not ok then error(root, 0) end
        if type(root) == "table" and align and type(w) == "number" then
            wander_roots[root] = { w = w, h = root.dimen and root.dimen.h or 0, align = align }
            wander_live[1] = root
            pcall(wanderPlace, root)
            local update = root.critter_update
            if type(update) == "function" then
                root.critter_update = function(...)
                    local changed = update(...)
                    pcall(wanderPlace, root)
                    return changed
                end
            end
        end
        return root
    end)
    -- the chat's "something else" and replies show a new phrase in the row
    local Talk = package.loaded["modules/critter/talk"]
    if type(Talk) == "table" and type(Talk.open) == "function" and not ours[Talk.open] then
        local orig_open = Talk.open
        Talk.open = mine(function(o, ...)
            local root = wander_live[1]
            if type(o) == "table" and root and wander_roots[root] then
                for _i, k in ipairs({ "on_other", "on_reply" }) do
                    local f = o[k]
                    if type(f) == "function" then
                        o[k] = function(...)
                            local r = f(...)
                            pcall(wanderPlace, root)
                            return r
                        end
                    end
                end
            end
            return orig_open(o, ...)
        end)
    end
end
end

-- Critter Insights (SimpleUI 3.0 Tiny Critter): remarks drawn from your
-- reading history, left waiting for the critter like SimpleUI's own reactions
-- (one at a time, the more important one kept):
--   tw_record     best reading day this month, in minutes (20 min+, a week in,
--                 beating each of 5+ earlier reading days this month)
--   tw_milestone  5 / 10 / 25 / 50 / 75 / 100 (then every 50) books this year,
--                 when the count goes up to it (finishing that book)
--   tw_momentum   2-5 reading days in a row after 4+ quiet ones, once per comeback
--   tw_quickwin   the book you're on is 25 minutes or less from the end
--   tw_pace       books left over days left ("one every 6 days"), on pace or
--                 catching up; weekly
--   tw_weekend    you read clearly more on weekends (or on weekdays): 4+ weekend
--                 and 8+ weekday reading days in 8 weeks; the verdict sticks
--   tw_recovery   3+ days without reading: a gentle nudge to your last book
-- Each comes once (a day, a week, a milestone or a quiet stretch), at most 3
-- a day, and only when the data backs it (enough days read, real minutes).
-- The history is one statistics query per day; nothing runs on a timer.
-- Also: in the critter's chat, a book offered once today isn't offered again.
-- Critter phrase bank: koreader/patches/critter-phrases.lua (next to this
-- patch; no leading number, so KOReader doesn't run it as a patch). It
-- returns { insights = { tw_* = { lines } }, minutes = { steps },
-- pages = { steps } }. Loaded once, with nothing but string and math in
-- reach; anything missing or malformed keeps the built-in lines.
-- CF: the critter extras (bank, pep), one table to stay under Lua's
-- 200 locals.
local CF = {}
do
local bank, tried
local function lineOk(l)
    return type(l) == "table" and type(l.text) == "function" and (l.sub == nil or type(l.sub) == "function")
        and type(l.mood) == "string"
end
local function stepsOk(st)
    if type(st) ~= "table" or #st == 0 then return false end
    local prev = 0
    for _i, x in ipairs(st) do
        if type(x) ~= "table" or type(x.upto) ~= "number" or x.upto <= prev or type(x.text) ~= "function"
            or type(x.subs) ~= "table" or #x.subs == 0 or type(x.mood) ~= "string" then return false end
        prev = x.upto
    end
    return prev == math.huge
end
local function bankPath()
    local src = debug.getinfo(1, "S").source or ""
    local dir = src:match("^@(.*)/[^/]*$")
    if dir then return dir .. "/critter-phrases.lua" end
    local ok, DS = pcall(require, "datastorage")
    return ok and DS:getDataDir() .. "/patches/critter-phrases.lua" or nil
end
function CF.bank()
    if tried then return bank end
    tried = true
    local path = bankPath()
    local f = path and loadfile(path)
    if not f then
        logger.info(TAG, "critter phrases: no critter-phrases.lua, built-in lines")
        return nil
    end
    setfenv(f, { string = string, math = math, tostring = tostring, tonumber = tonumber,
                 type = type, ipairs = ipairs, pairs = pairs, select = select })
    local ok, b = pcall(f)
    if not ok or type(b) ~= "table" then
        logger.warn(TAG, "critter phrases: critter-phrases.lua failed, built-in lines:", b)
        return nil
    end
    local out, n = { insights = {} }, 0
    if type(b.insights) == "table" then
        for kind, list in pairs(b.insights) do
            if type(kind) == "string" and kind:match("^tw_") and type(list) == "table" then
                local good = {}
                for _i, l in ipairs(list) do if lineOk(l) then good[#good + 1] = l end end
                if #good > 0 then out.insights[kind] = good; n = n + #good end
            end
        end
    end
    if type(b.voices) == "table" then out.voices = b.voices end
    -- insight_voices[critter][kind]: lists of lines, checked like the insights
    if type(b.insight_voices) == "table" then
        out.insight_voices = {}
        for cid, kinds in pairs(b.insight_voices) do
            if type(cid) == "string" and type(kinds) == "table" then
                local per = {}
                for kind, list in pairs(kinds) do
                    if type(kind) == "string" and kind:match("^tw_") and type(list) == "table" then
                        local good = {}
                        for _i, l in ipairs(list) do if lineOk(l) then good[#good + 1] = l end end
                        if #good > 0 then per[kind] = good end
                    end
                end
                out.insight_voices[cid] = per
            end
        end
    end
    if stepsOk(b.minutes) then out.minutes = b.minutes end
    if stepsOk(b.pages) then out.pages = b.pages end
    logger.info(TAG, string.format("critter phrases: %d insight lines, minutes %s, pages %s from %s",
        n, out.minutes and "yes" or "built-in", out.pages and "yes" or "built-in", path))
    bank = out
    return bank
end
end

local patchCritterInsights
do
local KEY = "simpleui_tweaks_insights"
local MIN_SECS = 60      -- a day with less than this is a day off
local BACK = 62          -- days of history read
local ins_ctx            -- the critter's last fresh statistics
local hist = { day = nil, days = {} }
local PRIORITY = { tw_milestone = 5.8, tw_record = 5.5, tw_quickwin = 3.4, tw_momentum = 3.2,
                   tw_pace = 2.8, tw_recovery = 2.2, tw_weekend = 1.5 }
local REWARD = { tw_milestone = 4, tw_record = 3, tw_momentum = 2 }

local function insightsOn() return cfg.critter_insights ~= false end

local function dayKey(back)
    local t = os.date("*t")
    return os.date("%Y-%m-%d", os.time{ year = t.year, month = t.month, day = t.day - back, hour = 12 })
end

-- seconds read per day ("YYYY-MM-DD"), the last BACK days; read once a day
local function history()
    local today = os.date("%Y-%m-%d")
    if hist.day == today then return hist.days end
    local days = {}
    pcall(function()
        local DataStorage = require("datastorage")
        local lfs = require("libs/libkoreader-lfs")
        local path = DataStorage:getSettingsDir() .. "/statistics.sqlite3"
        if lfs.attributes(path, "mode") ~= "file" then return end
        local SQ3 = require("lua-ljsqlite3/init")
        local conn = SQ3.open(path, "ro")
        pcall(function()
            conn:exec("PRAGMA busy_timeout=200;")
            local t = os.date("*t")
            local since = os.time{ year = t.year, month = t.month, day = t.day - BACK, hour = 0 }
            local stmt = conn:prepare("SELECT strftime('%Y-%m-%d', start_time, 'unixepoch', 'localtime'),"
                .. " sum(duration) FROM page_stat_data WHERE start_time >= ? GROUP BY 1")
            local row = stmt:reset():bind(since):step()
            while row do
                days[tostring(row[1])] = tonumber(row[2]) or 0
                row = stmt:step()
            end
            stmt:close()
        end)
        conn:close()
    end)
    hist = { day = today, days = days }
    return days
end

-- the book you're on: { title, left (minutes) } when it's nearly done; kept
-- while the book and today's reading stay the same
local qw_cache = {}
local function quickWin(today_secs)
    local fp = G_reader_settings and G_reader_settings:readSetting("lastfile")
    local key = tostring(fp) .. "|" .. tostring(today_secs) .. "|" .. os.date("%Y-%m-%d")
    if qw_cache.key == key then return qw_cache.value end
    local v = nil
    local ok_q, res = pcall(function()
        local SH = package.loaded["modules/module_books_shared"]
        if type(fp) ~= "string" or type(SH) ~= "table" or type(SH.getBookData) ~= "function" then return nil end
        local ok, b = pcall(SH.getBookData, fp)
        if not (ok and type(b) == "table") then return nil end
        local pct, pages, per = tonumber(b.percent) or 0, tonumber(b.pages), tonumber(b.avg_time)
        if b.status == "complete" or pct < 0.5 or pct >= 0.995 or not (pages and per and per > 0) then return nil end
        local left = math.floor((1 - pct) * pages * per / 60 + 0.5)
        if left < 3 or left > 25 then return nil end
        return { title = b.title, left = left }
    end)
    if ok_q then v = res end
    qw_cache = { key = key, value = v }
    return v
end

local function lastTitle()
    local fp = G_reader_settings and G_reader_settings:readSetting("lastfile")
    local SH = package.loaded["modules/module_books_shared"]
    if type(fp) ~= "string" or type(SH) ~= "table" or type(SH.getBookData) ~= "function" then return nil end
    local ok, b = pcall(SH.getBookData, fp)
    if ok and type(b) == "table" and b.status ~= "complete" and type(b.title) == "string" and b.title ~= "?" then return b.title end
    return nil
end

-- Remembered between visits (G_reader_settings, KEY), each with its own life:
--   day, count, daily   today: insights said and how many (reset each day)
--   ms, ms_due, seen_by milestones: said ("2026:25"), owed, and the count
--                       last seen (a milestone is owed only when the count
--                       goes up to it, so a refresh can't announce it again)
--   spans               once per comeback / quiet stretch / week: key -> the
--                       day it was said, dropped after 90 days
--   weekend             the weekend / weekday verdict, kept until the data
--                       clearly says otherwise
--   offered             books the chat offered today
local SPAN_DAYS = 90
local function readState()
    local s = G_reader_settings and G_reader_settings:readSetting(KEY)
    if type(s) ~= "table" then s = {} end
    s.done = nil   -- 2.12.5's single list
    local today = os.date("%Y-%m-%d")
    if s.day ~= today or type(s.daily) ~= "table" then s.day, s.count, s.daily = today, 0, {} end
    if type(s.ms) ~= "table" then s.ms = {} end
    if type(s.spans) ~= "table" then s.spans = {} end
    if type(s.offered) ~= "table" or s.offered_day ~= s.day then s.offered, s.offered_day = {}, s.day end
    return s
end
local function writeState(s)
    local year = tostring(os.date("*t").year)
    for k in pairs(s.ms) do if k:sub(1, 4) ~= year then s.ms[k] = nil end end
    local t = os.date("*t")
    local cutoff = os.date("%Y-%m-%d", os.time{ year = t.year, month = t.month, day = t.day - SPAN_DAYS, hour = 12 })
    for k, v in pairs(s.spans) do if type(v) ~= "string" or v < cutoff then s.spans[k] = nil end end
    G_reader_settings:saveSetting(KEY, s)
end
local function said(s, c) return (c.scope == "ms" and s.ms or c.scope == "span" and s.spans or s.daily)[c.key] ~= nil end
local function markSaid(s, c)
    if c.scope == "ms" then s.ms[c.key] = true; s.ms_due = nil
    elseif c.scope == "span" then s.spans[c.key] = s.day
    else s.daily[c.key] = true end
end

local MILESTONES = { [5] = true, [10] = true, [25] = true, [50] = true, [75] = true, [100] = true }
local function isMilestone(n) return MILESTONES[n] or (n > 100 and n % 50 == 0) end

-- "one every 6 days" / "3 a week"
local function every(days_left, left)
    local e = days_left / left
    if e >= 1.5 then return string.format("one every %d days", math.floor(e + 0.5)) end
    return string.format("%d a week", math.ceil(7 / e))
end

-- Which insights qualify right now: { kind, data, scope, key }, most
-- important first. The visit then says the first one not said yet (scope:
-- "daily", "span" or "ms"). Updates what `s` remembers (milestone count,
-- weekend verdict) and sets s._changed.
local function candidates(stats, s)
    local days = history()
    local today_secs = tonumber(stats.today_secs) or 0
    local function secs(i) if i == 0 then return today_secs end return days[dayKey(i)] or 0 end
    local function read(i) return secs(i) >= MIN_SECS end
    local t = os.date("*t")
    local out = {}
    local function add(kind, data, scope, key) out[#out + 1] = { kind = kind, data = data, scope = scope, key = key } end

    -- milestone: owed when the count goes up to one this year
    local by = tonumber(stats.books_year)
    if by then
        local prev = s.seen_by
        if not (type(prev) == "table" and prev.year == t.year and prev.n == by) then
            if type(prev) == "table" and prev.year == t.year and by > (tonumber(prev.n) or by) and isMilestone(by) then
                s.ms_due = t.year .. ":" .. by
            end
            s.seen_by = { year = t.year, n = by }
            s._changed = true
        end
        if type(s.ms_due) == "string" and s.ms_due == t.year .. ":" .. by then
            add("tw_milestone", { days = by }, "ms", s.ms_due)
        end
    end

    local any = false
    for i = 1, BACK - 1 do if read(i) then any = true break end end
    if not any and today_secs < MIN_SECS then
        table.sort(out, function(a, b) return PRIORITY[a.kind] > PRIORITY[b.kind] end)
        return out
    end

    -- best day this month, in minutes read: a week in, 20+ minutes, beating
    -- each of 5+ earlier reading days this month
    if t.day >= 7 and today_secs >= 1200 then
        local others, top = 0, 0
        for d = 1, t.day - 1 do
            local sv = secs(t.day - d)
            if sv >= MIN_SECS then others = others + 1; if sv > top then top = sv end end
        end
        if others >= 5 and today_secs > top then
            add("tw_record", { minutes = math.floor(today_secs / 60) }, "daily", "rec")
        end
    end
    -- the book you're on, nearly done (at that book's own pace)
    local qw = quickWin(today_secs)
    if qw then add("tw_quickwin", { title = qw.title, minutes = qw.left }, "daily", "qw:" .. tostring(qw.title)) end
    -- back on a roll: 2+ reading days in a row after 4+ quiet ones, once
    -- per comeback (keyed to the day the run started)
    local start = read(0) and 0 or 1
    local i, run = start, 0
    while i < BACK and read(i) do run = run + 1; i = i + 1 end
    local gap = 0
    while i < BACK and not read(i) do gap = gap + 1; i = i + 1 end
    if i < BACK and read(0) and run >= 2 and run <= 5 and gap >= 4 then
        add("tw_momentum", { days = run }, "span", "mo:" .. dayKey(run - 1))
    end
    -- goal pace: what's left over the days left, on pace or catching up;
    -- weekly, from mid-January
    local Goals = package.loaded["infra/sui_goals"]
    local okg, goal = pcall(function() return Goals.get("annual") end)
    goal = okg and tonumber(goal) or nil
    local doy = tonumber(os.date("%j")) or 1
    if goal and goal > 0 and by and by < goal and doy >= 14 then
        local diy = tonumber(os.date("%j", os.time{ year = t.year, month = 12, day = 31, hour = 12 })) or 365
        local days_left = diy - doy + 1
        local left = goal - by
        local expected = goal * doy / diy
        add("tw_pace", { days = left, minutes = days_left, years = goal,
                         which = (by >= expected - 0.5) and "on" or "behind" }, "span", "pace:" .. os.date("%Y-%W"))
    end
    -- a quiet stretch: a gentle nudge, once per stretch
    if not read(0) then
        local k = 1
        while k < BACK and not read(k) do k = k + 1 end
        local idle = k - 1
        if k < BACK and idle >= 3 then
            add("tw_recovery", { days = idle, title = lastTitle() }, "span", "rc:" .. dayKey(k))
        end
    end
    -- weekends against weekdays, the last 8 weeks: 4+ weekend and 8+ weekday
    -- reading days, a clear difference (1.6x) to say so, and kept until the
    -- difference is mostly gone (under 1.2x)
    local we, wd, we_n, wd_n = 0, 0, 0, 0
    for d = 1, 56 do
        local sv = secs(d)
        local wday = tonumber(os.date("%w", os.time{ year = t.year, month = t.month, day = t.day - d, hour = 12 }))
        if wday == 0 or wday == 6 then
            we = we + sv; if sv >= MIN_SECS then we_n = we_n + 1 end
        else
            wd = wd + sv; if sv >= MIN_SECS then wd_n = wd_n + 1 end
        end
    end
    if we_n >= 4 and wd_n >= 8 then
        local we_avg, wd_avg = we / 16, wd / 40
        local v
        if we_avg >= 1.6 * wd_avg then v = "weekend"
        elseif wd_avg >= 1.6 * we_avg then v = "weekday"
        elseif s.weekend == "weekend" and we_avg >= 1.2 * wd_avg then v = "weekend"
        elseif s.weekend == "weekday" and wd_avg >= 1.2 * we_avg then v = "weekday" end
        if v ~= s.weekend then s.weekend = v; s._changed = true end
    end
    if (s.weekend == "weekend" and (t.wday == 6 or t.wday == 7)) or (s.weekend == "weekday" and t.wday == 2) then
        add("tw_weekend", { which = s.weekend }, "span", "we:" .. os.date("%Y-%W"))
    end
    table.sort(out, function(a, b) return PRIORITY[a.kind] > PRIORITY[b.kind] end)
    return out
end

-- each home screen visit: the first qualifying insight not said yet waits
-- for the critter (3 a day at most; nothing while another reaction waits)
local function observeInsights(R)
    if not insightsOn() or not ins_ctx or ins_ctx.stale or type(ins_ctx.stats) ~= "table" then return end
    local s = readState()
    local list = candidates(ins_ctx.stats, s)
    local changed = s._changed
    s._changed = nil
    if (s.count or 0) < 3 and not R.read().pending then
        for _i, c in ipairs(list) do
            if not said(s, c) then
                R.record(c.kind, c.data)
                local now = R.read().pending
                if now and now.kind == c.kind then
                    markSaid(s, c)
                    s.count = (s.count or 0) + 1
                    changed = true
                    local M = package.loaded["modules/critter/mood"]
                    if REWARD[c.kind] and type(M) == "table" and type(M.reward) == "function" then
                        pcall(function() M.write(M.reward(M.read(), REWARD[c.kind])) end)
                    end
                end
                break
            end
        end
    end
    if changed then writeState(s) end
end

-- ---- what the critter says ----
local function q(s) return "\xE2\x80\x9C" .. tostring(s) .. "\xE2\x80\x9D" end
local function plural(n, one, many) return string.format(n == 1 and one or many, n) end
local LINES = {
    tw_milestone = {
        { mood = "party", text = function(d) return string.format("That's book %d this year!", d.days) end,
          sub = function() return "Your shelf is looking lighter." end,
          by_tier = { grumpy = { mood = "grumpy", text = function(d) return string.format("%d books. Fine, I'm impressed.", d.days) end },
                      radiant = { mood = "party", text = function(d) return string.format("%d books this year! You're unstoppable!", d.days) end } } },
        { mood = "love", text = function(d) return string.format("%d books finished this year.", d.days) end,
          sub = function() return "A milestone. I'm putting it on the fridge." end },
        { mood = "cheer", text = function(d) return string.format("Book number %d. Done.", d.days) end,
          sub = function() return "What's next on the pile?" end },
    },
    tw_record = {
        { mood = "surprised", text = function() return "Your best reading day this month!" end,
          sub = function(d) return string.format("%s and counting.", plural(d.minutes, "%d minute", "%d minutes")) end,
          by_tier = { grumpy = { mood = "grumpy", text = function() return "Best day this month. Don't let it go to your head." end },
                      radiant = { mood = "party", text = function() return "A record day! Look at you go!" end } } },
        { mood = "party", text = function(d) return string.format("%s today. A new monthly best.", plural(d.minutes, "%d minute", "%d minutes")) end,
          sub = function() return "I'll remember this one." end },
        { mood = "cheer", text = function() return "No day this month beats today." end,
          sub = function(d) return string.format("%s so far.", plural(d.minutes, "%d minute", "%d minutes")) end },
    },
    tw_quickwin = {
        { mood = "cheer", text = function(d) return string.format("Only %d min left in %s.", d.minutes, q(d.title)) end,
          sub = function() return "A little time to spare?" end,
          by_tier = { grumpy = { mood = "grumpy", text = function(d) return string.format("%s isn't going to finish itself.", q(d.title)) end,
                                 sub = function(d) return string.format("About %d minutes. You know you want to.", d.minutes) end },
                      meh = { mood = "sleepy", text = function(d) return string.format("%d minutes, then %s is done.", d.minutes, q(d.title)) end,
                              sub = function() return "Then we can both rest." end } } },
        { mood = "playful", text = function(d) return string.format("%s: about %d minutes to go.", q(d.title), d.minutes) end,
          sub = function() return "The finish line is right there." end },
        { mood = "curious", text = function(d) return string.format("Got %d minutes?", d.minutes) end,
          sub = function(d) return string.format("That's all %s needs.", q(d.title)) end },
    },
    tw_momentum = {
        { mood = "cheer", text = function(d) return string.format("%s in a row.", plural(d.days, "%d reading day", "%d reading days")) end,
          sub = function() return "You're getting back into the habit." end,
          by_tier = { grumpy = { mood = "playful", text = function(d) return string.format("%s in a row. Took you long enough.", plural(d.days, "%d day", "%d days")) end } } },
        { mood = "happy", text = function() return "Look who's back on a roll." end,
          sub = function(d) return string.format("%s running.", plural(d.days, "%d day", "%d days")) end },
        { mood = "love", text = function(d) return string.format("Day %d of reading again.", d.days) end,
          sub = function() return "This feels like the start of something." end },
    },
    tw_pace = {
        { mood = "curious",
          text = function(d)
              if d.which == "on" then return "You're on pace for your goal." end
              return string.format("%s to go, %d days left.", plural(d.days, "%d book", "%d books"), d.minutes)
          end,
          sub = function(d)
              if d.which == "on" then return string.format("%d to go: about %s.", d.days, every(d.minutes, d.days)) end
              return string.format("About %s catches you up.", every(d.minutes, d.days))
          end },
        { mood = "playful",
          text = function(d)
              if d.which == "on" then return string.format("Right on track for %d books.", d.years) end
              return string.format("Your %d-book goal is in reach.", d.years)
          end,
          sub = function(d)
              if d.which == "on" then return string.format("Keep it to %s.", every(d.minutes, d.days)) end
              return string.format("%s left: %s.", plural(d.days, "%d book", "%d books"), every(d.minutes, d.days))
          end },
        { mood = "cheer",
          text = function(d) return string.format("%s left this year.", plural(d.days, "%d book", "%d books")) end,
          sub = function(d)
              if d.which == "on" then return string.format("You're on pace. About %s does it.", every(d.minutes, d.days)) end
              return string.format("A little behind. About %s does it.", every(d.minutes, d.days))
          end,
          by_tier = { grumpy = { mood = "grumpy",
                                 text = function(d) return d.which == "on" and "On pace. Don't get cocky." or "Behind on the year goal." end,
                                 sub = function(d) return string.format("%s. Chop chop.", (every(d.minutes, d.days):gsub("^%l", string.upper))) end } } },
    },
    tw_recovery = {
        { mood = "shy", text = function(d) return d.title and string.format("It's been a while since %s.", q(d.title)) or "It's been a few quiet days." end,
          sub = function() return "Fancy a few pages?" end,
          by_tier = { grumpy = { mood = "grumpy", text = function(d) return string.format("%s. Not that I'm counting.", plural(d.days, "%d day", "%d days")) end,
                                 sub = function() return "A page would cheer me up." end } } },
        { mood = "curious", text = function(d) return d.title and string.format("%s misses you.", q(d.title)) or "Your books miss you." end,
          sub = function() return "Even ten minutes counts." end },
        { mood = "sleepy", text = function() return "Ready when you are." end,
          sub = function(d) return d.title and string.format("%s is right where you left it.", q(d.title)) or "No rush." end },
    },
    tw_weekend = {
        { mood = "curious", text = function(d) return d.which == "weekend" and "You read more on weekends." or "You read more on weekdays." end,
          sub = function(d) return d.which == "weekend" and "Got a book lined up for this one?" or "A fresh week, a fresh chapter." end },
        { mood = "playful", text = function(d) return d.which == "weekend" and "Weekend reader, I see." or "Weekdays are your reading days." end,
          sub = function(d) return d.which == "weekend" and "Your best time is almost here." or "Let's make this week count." end },
        { mood = "happy", text = function(d) return d.which == "weekend" and "Weekends are your reading time." or "You read best on weekdays." end,
          sub = function() return "Your stats don't lie." end },
    },
}

local done = {}
local function install()
    local R = package.loaded["modules/critter/reactions"]
    if not done.R and type(R) == "table" and type(R.PRIORITY) == "table" and type(R.observe) == "function" then
        done.R = true
        for k, v in pairs(PRIORITY) do R.PRIORITY[k] = v end
        local orig_observe = R.observe
        R.observe = function(...)
            local res = { orig_observe(...) }
            pcall(observeInsights, R)
            return unpack(res)
        end
    end
    local L = package.loaded["modules/critter/reaction_lines"]
    if not done.L and type(L) == "table" and type(L.LINES) == "table" then
        done.L = true
        local b = CF.bank()
        if b then for kind, list in pairs(b.insights) do if LINES[kind] then LINES[kind] = list end end end
        for kind, list in pairs(LINES) do
            for n, line in ipairs(list) do
                line.id, line.kind, line.group = kind .. "_" .. n, kind, "tw"
                line.when = function(d) return type(d) == "table" end
                L.LINES[#L.LINES + 1] = line
            end
        end
        -- 2.14.10: Donny, Blu and Donny & Blu's own wording (SimpleUI 3.0.2
        -- picks a critter's own line about half the time when it has one)
        if b and type(b.insight_voices) == "table" then
            for cid, kinds in pairs(b.insight_voices) do
                for kind, list in pairs(kinds) do
                    if LINES[kind] then
                        for n, l in ipairs(list) do
                            L.LINES[#L.LINES + 1] = { id = kind .. "_" .. cid .. "_" .. n, kind = kind, group = "tw",
                                critter = cid, mood = l.mood, text = l.text, sub = l.sub, by_tier = l.by_tier,
                                when = function(d) return type(d) == "table" end }
                        end
                    end
                end
            end
        end
    end
    -- the chat's book suggestion: not the same book twice in a day
    local Rec = package.loaded["modules/critter/recommend"]
    if not done.Rec and type(Rec) == "table" and type(Rec.nextBook) == "function" then
        done.Rec = true
        local orig_next = Rec.nextBook
        Rec.nextBook = function(skip_fp, ...)
            local s = readState()
            local book
            for _try = 1, 3 do
                book = orig_next(skip_fp, ...)
                if not (book and book.fp and s.offered[book.fp]) then break end
                skip_fp = book.fp
            end
            if book and book.fp then
                s.offered[book.fp] = true
                pcall(writeState, s)
            end
            return book
        end
    end
end

function patchCritterInsights(M)
    if type(M) ~= "table" or type(M.build) ~= "function" or ours[M.build] then return end
    install()
    local orig = M.build
    M.build = mine(function(w, ctx, ...)
        if type(ctx) == "table" then ins_ctx = { stats = ctx.stats, stale = ctx.stats_stale } end
        local root = orig(w, ctx, ...)
        if type(root) == "table" and type(root.critter_update) == "function" then
            local update = root.critter_update
            root.critter_update = function(new_ctx, ...)
                if type(new_ctx) == "table" then ins_ctx = { stats = new_ctx.stats, stale = new_ctx.stats_stale } end
                return update(new_ctx, ...)
            end
        end
        return root
    end)
end
end

-- Critter Pep Talk (SimpleUI 3.0 Tiny Critter): SimpleUI's "N minutes read
-- today! Nice work." and "N pages turned today!" say the same thing at 1
-- minute and at 2 hours. These steps make them grow with the day's reading.
-- The line is reworded where SimpleUI renders it (Phrases.pick for a new
-- phrase, Phrases.refresh when it rewrites the one on show with fresh
-- numbers), so a step up shows on the next home screen draw: no timers.
-- The wording holds for one phrase (until SimpleUI picks the next one).
do
local pep_n = 0 -- bumped per new phrase: the next phrase gets the next wording
local salt = 0  -- the wording of the phrase being worded (kept with it)

local function plural(n, one, many) return string.format(n == 1 and one or many, n) end
local function vary(list, i) return list[(salt + i) % #list + 1] end

local MIN_STEPS = {
    { upto = 4, mood = "curious",
      text = function(m) return plural(m, "%d minute read today.", "%d minutes read today.") end,
      subs = { "A start is a start.", "Five more and you're warmed up.",
               "The first page is the hardest one.", "Tiny reads still count." } },
    { upto = 14, mood = "happy",
      text = function(m) return string.format("%d minutes read today.", m) end,
      subs = { "Warming up nicely.", "Ten more? Just saying.", "The story's getting going." } },
    { upto = 29, mood = "happy",
      text = function(m) return string.format("%d minutes read today!", m) end,
      subs = { "Now that's a groove.", "Half an hour is right there.", "Proper reading time." } },
    { upto = 59, mood = "cheer",
      text = function(m) return string.format("%d minutes read today!", m) end,
      subs = { "A real session. Nice.", "The hour mark is calling.", "Look at you go." } },
    { upto = 89, mood = "party",
      text = function(m) return string.format("%d minutes read today!", m) end,
      subs = { "An hour plus! Snack break?", "That's a serious read.", "The book is winning today." } },
    { upto = math.huge, mood = "party",
      text = function(m) return string.format("%.1f hours read today!", m / 60) end,
      subs = { "Marathon mode.", "Did you even blink?", "Okay, bookworm." } },
}

local PAGE_STEPS = {
    { upto = 4, mood = "curious",
      text = function(p) return plural(p, "%d page turned today.", "%d pages turned today.") end,
      subs = { "Every page counts.", "A few more? The story won't mind." } },
    { upto = 19, mood = "happy",
      text = function(p) return string.format("%d pages turned today!", p) end,
      subs = { "One page at a time.", "Chapter's end is near, maybe." } },
    { upto = 49, mood = "cheer",
      text = function(p) return string.format("%d pages turned today!", p) end,
      subs = { "Turning pages like a pro.", "That's a chunk of book." } },
    { upto = math.huge, mood = "party",
      text = function(p) return string.format("%d pages today!", p) end,
      subs = { "That's a chapter or three.", "Your thumb needs a rest." } },
}

local function step(steps, v)
    for i, st in ipairs(steps) do if v <= st.upto then return st, i end end
end
local function bankSteps(kind, own)
    local b = CF.bank()
    return b and b[kind] or own
end

-- SimpleUI's line, reworded for the step reached; nil leaves it as it is.
local function pep(res, f)
    if cfg.critter_pep == false or type(res) ~= "table" or type(f) ~= "table" then return nil end
    local id = type(res.source) == "table" and res.source.id
    if id == "minutes" then
        local secs = tonumber(f.today_secs) or 0
        local m = math.floor(secs / 60)
        if m < 1 then return nil end
        local st, i = step(bankSteps("minutes", MIN_STEPS), m)
        local goal = tonumber(f.daily_goal_secs) or 0
        local sub = vary(st.subs, i)
        local mood = st.mood
        if type(sub) == "table" then sub, mood = tostring(sub[1] or ""), sub.mood or mood end
        if goal > 0 and secs < goal then
            local left = math.ceil((goal - secs) / 60)
            if left <= 10 then
                sub, mood = plural(left, "Just %d minute to your daily goal!", "Just %d minutes to your daily goal!"), "cheer"
            elseif (salt + i) % 2 == 0 then
                sub = string.format("%d minutes to your daily goal.", left)
            end
        end
        return { text = st.text(m), sub = sub, mood = mood, source = res.source }
    elseif id == "pages" then
        local p = tonumber(f.today_pages) or 0
        if p < 1 then return nil end
        local st, i = step(bankSteps("pages", PAGE_STEPS), p)
        local sub, mood = vary(st.subs, i), st.mood
        if type(sub) == "table" then sub, mood = tostring(sub[1] or ""), sub.mood or mood end
        return { text = st.text(p), sub = sub, mood = mood, source = res.source }
    end
end

-- Moods past SimpleUI's twelve, and the pose each falls back to for a
-- critter without its picture (SimpleUI's own fallback is neutral).
CF.MOOD_BASE = { reading = "neutral", proud = "cheer", hungry = "curious", cozy = "sleepy",
                 sipping = "happy", dreamy = "sleepy", festive = "happy", spooky = "surprised" }
local function seasonalMood(mood)
    local t = os.date("*t")
    if mood == "party" and t.month == 12 then return "festive" end
    if (mood == "party" or mood == "surprised") and t.month == 10 and t.day >= 25 then return "spooky" end
    return nil
end
-- Critter Mix: the ticked critters take turns, the next one with each new
-- remark (SimpleUI picking a phrase). The turn starts from the day, so a
-- restart doesn't always begin with the same one. The turn lives on
-- SimpleUI's Assets table (tw_turn), so Reading Log's critter can move it
-- on too.
local function turnOf(As)
    if type(As.tw_turn) ~= "number" then As.tw_turn = tonumber(os.date("%j")) or 0 end
    return As.tw_turn
end
local function mixList()
    local m = type(cfg.critter_mix) == "table" and cfg.critter_mix or {}
    return #m >= 2 and m or nil
end
function CF.mix()
    local As = package.loaded["modules/critter/assets"]
    if type(As) ~= "table" or type(As.get) ~= "function" or As._tw_mix then return end
    As._tw_mix = true
    local orig = As.get
    As.get = function(id, ...)
        local m = mixList()
        if m then
            local want = m[(turnOf(As) % #m) + 1]
            local e = orig(want, ...)
            if type(e) == "table" and e.id == want then return e end
        end
        return orig(id, ...)
    end
end

function CF.moods()
    local As = package.loaded["modules/critter/assets"]
    if type(As) ~= "table" or type(As.imagePath) ~= "function" or As._tw_moods then return end
    As._tw_moods = true
    local orig = As.imagePath
    As.imagePath = function(entry, mood, ...)
        local path = orig(entry, mood, ...)
        local okm, res = pcall(function()
            local neutral = orig(entry, "neutral")
            -- the season's look, when this critter has it
            local season = seasonalMood(mood)
            if season then
                local sp = orig(entry, season)
                if sp and sp ~= neutral then return sp end
            end
            local base = CF.MOOD_BASE[mood]
            if base and path == neutral then return orig(entry, base) end
            return nil
        end)
        return (okm and res) or path
    end
end

-- Critter voices (2.14.9): the phrase bank's voices (Donny, Blu, Donny & Blu)
-- join SimpleUI 3.0.2's own voice lines (modules/critter/voice_phrases), so
-- the home screen and Reading Log Tweaks both use them. Same situations and
-- rules as SimpleUI's critters.
local function atLeast(v, n) return v ~= nil and v >= n end
local VOICE_SIT = {
    greet_morning   = { cat = "greeting", when = function(f) return f.period == "morning" end },
    greet_afternoon = { cat = "greeting", when = function(f) return f.period == "afternoon" end },
    greet_evening   = { cat = "greeting", when = function(f) return f.period == "evening" end },
    greet_night     = { cat = "greeting", when = function(f) return f.period == "night" end },
    streak          = { cat = "streak",   when = function(f) return atLeast(f.streak, 2) end },
    streak_paused   = { cat = "streak",   when = function(f) return f.streak == 0 end },
    today           = { cat = "today",    when = function(f) return atLeast(f.today_secs, 60) end },
    books_year      = { cat = "books",    when = function(f) return atLeast(f.books_year, 1) end },
    book_progress   = { cat = "reading",  when = function(f) return f.book ~= nil and f.book.days < 3 and f.book.percent < 90 end },
    book_waiting    = { cat = "reading",  when = function(f) return f.book ~= nil and f.book.days >= 3 end },
    goal_day        = { cat = "special",  when = function(f)
                          return (f.daily_goal_secs or 0) > 0 and atLeast(f.today_secs, f.daily_goal_secs) end },
    monday          = { cat = "calendar", when = function(f) return f.weekday == 2 end },
    weekend         = { cat = "calendar", when = function(f) return f.weekday == 1 or f.weekday == 7 end },
    anytime         = { cat = "generic",  when = function() return true end },
}
local VOICE_ORDER = { "greet_morning", "greet_afternoon", "greet_evening", "greet_night", "streak", "streak_paused",
    "today", "books_year", "book_progress", "book_waiting", "goal_day", "monday", "weekend", "anytime" }
function CF.voices()
    local ok, V = pcall(require, "modules/critter/voice_phrases")
    if not ok or type(V) ~= "table" or V._tw_voices then return end
    local b = CF.bank()
    if not (b and type(b.voices) == "table") then return end
    V._tw_voices = true
    local ids = {}
    for cid in pairs(b.voices) do if type(cid) == "string" then ids[#ids + 1] = cid end end
    table.sort(ids)
    local n = 0
    for _i, cid in ipairs(ids) do
        local sits = b.voices[cid]
        if type(sits) == "table" then
            for _j, name in ipairs(VOICE_ORDER) do
                local sit, list = VOICE_SIT[name], sits[name]
                if type(list) == "table" then
                    for k, l in ipairs(list) do
                        if type(l) == "table" and type(l.text) == "function" then
                            V[#V + 1] = { id = string.format("tw_%s_%s_%d", cid, name, k), critter = cid,
                                cat = sit.cat, mood = l.mood or "happy", when = sit.when, text = l.text,
                                sub = type(l.sub) == "function" and l.sub or nil }
                            n = n + 1
                        end
                    end
                end
            end
        end
    end
    logger.info(TAG, "critter voices:", n, "lines for", table.concat(ids, ", "))
end
-- Reading Log Tweaks calls this before reading the voice lines.
package.loaded["simpleui_tweaks_voices"] = function() return pcall(CF.voices) end

function CF.pep()
    pcall(CF.voices)
    pcall(CF.moods)
    pcall(CF.mix)
    local ok, Ph = pcall(require, "modules/critter/phrases")
    if not ok or type(Ph) ~= "table" or Ph._tw_pep then return end
    Ph._tw_pep = true
    local pick, refresh = Ph.pick, Ph.refresh
    if type(pick) == "function" then
        Ph.pick = function(f, ...)
            local res = pick(f, ...)
            pep_n = pep_n + 1
            -- Critter Mix: the next critter
            local As = package.loaded["modules/critter/assets"]
            if type(As) == "table" then As.tw_turn = turnOf(As) + 1 end
            salt = pep_n
            local okp, mine_ = pcall(pep, res, f)
            local out = okp and mine_ or res
            if type(out) == "table" then out._tw_salt = salt end
            return out
        end
    end
    if type(refresh) == "function" then
        Ph.refresh = function(previous, f, ...)
            local res = refresh(previous, f, ...)
            salt = type(previous) == "table" and tonumber(previous._tw_salt) or pep_n
            local okp, mine_ = pcall(pep, res, f)
            local out = okp and mine_ or res
            if type(out) == "table" then out._tw_salt = salt end
            return out
        end
    end
end
end

local function patchModule(name, M)
    if type(M) ~= "table" then return false end
    local file_id = name:match("/module_([^/]+)$")
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
    if file_id == "quote" then quietQuoteBuild(M) end
    if file_id == "currently" then patchCurrentlySwipe(M) end
    if file_id == "new_books" and orig then pcall(patchNewBooksModule, orig) end
    if file_id == "critter" and orig then
        pcall(patchCritterBubble, orig)
        pcall(patchCritterWander, M)
        pcall(patchCritterInsights, M)
        pcall(CF.pep)
    end
    -- the clock's minute tick calls its local build() directly
    if file_id == "clock" and orig then
        local lb, idx = findUpvalue(orig, "build", function(v) return type(v) == "function" end)
        if type(lb) == "function" then
            debug.setupvalue(orig, idx, function(...)
                return withColor(colorForModule("clock"), lb, ...)
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
                if cur_color then fg = cur_color
                elseif keep_own == 0 then fg = colorForModule(nil) or fg end
                -- else: this module/title uses SimpleUI's own colour, leave it
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

-- Section titles on SimpleUI v3.0.0+: the label builder moved to
-- engines/sui_section_label (M.get). Hook it the same way the old inline
-- sectionLabel was hooked: track the module id and apply the configured
-- title colour around the build.
local function patchSectionLabel(SL)
    if type(SL) ~= "table" or type(SL.get) ~= "function" then return false end
    local orig = SL.get
    if ours[orig] then return true end
    SL.get = mine(function(cache, id, desc, w, landscape_factor, has_wallpaper, turn_page, inside)
        local prev = cur_title_id
        cur_title_id = id
        in_title = in_title + 1
        local res = pack(pcall(withColor, titleColor(id), flipScope, "title",
                               orig, cache, id, desc, w, landscape_factor, has_wallpaper, turn_page, inside))
        in_title = in_title - 1
        cur_title_id = prev
        if not res[1] then error(res[2], 0) end
        return unpack(res, 2, res.n)
    end)
    return true
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
                -- false: worked out live (SimpleUI 3.0 surface_flat), cleared after
                saved[k] = rawget(C, k) or false
                C[k] = inv_cache[k]
            end
        end
        local ok, err = pcall(orig, self, bb, x, y)
        for i = 1, #NAV_PALETTE_KEYS do
            local k = NAV_PALETTE_KEYS[i]
            local was = saved[k]   -- truthiness / rawequal only
            if rawequal(was, false) then rawset(C, k, nil); saved[k] = nil
            elseif was then C[k] = was; saved[k] = nil end
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

local patchBookshelfPark   -- Bookshelf: Close Bookshelf -> SimpleUI home (defined below)

-- ---- New Books: show a newly added book right away -----------------------------------
-- SimpleUI ranks "newest files" (New Books module, the side panel's Newly
-- Added view) at most every 5 minutes, even though its library scan already
-- notices a new or removed book straight away (it re-stats the library's
-- folders, the way Bookshelf's "Latest" does). So a book sent from Calibre
-- didn't show up for up to 5 minutes. Now the ranking is redone whenever that
-- scan has re-walked the library, and reused otherwise (no extra disk work).
local function patchBookSources(Sources)
    if type(Sources) ~= "table" or type(Sources.get) ~= "function" then return false end
    local ok, src = pcall(Sources.get, "new_books")
    if not ok or type(src) ~= "table" or type(src.getFileList) ~= "function" then return false end
    if ours[src.getFileList] then return true end
    local okl, LS = pcall(require, "engines/sui_library_scan")
    local getEntry = okl and type(LS) == "table" and findUpvalue(LS.getRaw, "getEntry")
    if type(getEntry) ~= "function" or type(LS.resolveHomeDir) ~= "function"
            or type(src.invalidate) ~= "function" then
        logger.warn(TAG, "new books: SimpleUI's library scan changed, left as is")
        return true
    end
    local orig, last = src.getFileList, nil
    src.getFileList = mine(function(...)
        -- same cheap folder check SimpleUI's scan does anyway; a new entry
        -- table means it re-walked the library (something was added/removed)
        local okh, home = pcall(LS.resolveHomeDir)
        if okh and home and home ~= "" then
            local oke, entry = pcall(getEntry, home)
            if oke and entry ~= nil and entry ~= last then
                last = entry
                pcall(src.invalidate)
            end
        end
        return orig(...)
    end)
    return true
end

-- SimpleUI 2.7.5 (release) has no book sources: its New Books module walks
-- the home folder itself, only every 5 minutes, and stops after 5000
-- entries (book sidecar folders and their files included), so on a bigger
-- library a new book can be missed for good. This ranking uses SimpleUI's
-- shared library scan instead (8 levels, 20000 entries, sidecars skipped,
-- re-walks as soon as a folder changes): newest files by date, recomputed
-- only when that scan re-walked. Used by the New Books module and the side
-- panel's Newly Added view.
local NEW_BOOKS_MAX = 15
local nb_entry, nb_list
local function newestBooks()
    local okl, LS = pcall(require, "engines/sui_library_scan")
    if not okl or type(LS) ~= "table" or type(LS.getRaw) ~= "function" then return nil end
    local okh, home = pcall(LS.resolveHomeDir)
    if not okh or not home or home == "" then return {} end
    local getEntry = findUpvalue(LS.getRaw, "getEntry")
    local entry
    if type(getEntry) == "function" then
        local oke, e = pcall(getEntry, home)
        if oke then entry = e end
    end
    if entry ~= nil and entry == nb_entry and nb_list then return nb_list end
    local okr, raw = pcall(LS.getRaw, home)
    if not okr or type(raw) ~= "table" then return nil end
    table.sort(raw, function(a, b)
        if (a.mtime or 0) ~= (b.mtime or 0) then return (a.mtime or 0) > (b.mtime or 0) end
        return tostring(a.fp) < tostring(b.fp)
    end)
    local fps = {}
    for i = 1, math.min(NEW_BOOKS_MAX, #raw) do fps[i] = raw[i].fp end
    nb_entry, nb_list = entry, fps
    return fps
end

-- New Books module (2.7.5): swap its own folder walk for newestBooks().
patchNewBooksModule = function(build)
    local spec = findUpvalue(build, "spec")
    if type(spec) ~= "table" or type(spec.getFileList) ~= "function" or ours[spec.getFileList] then return end
    local orig = spec.getFileList
    spec.getFileList = mine(function(...)
        local ok, fps = pcall(newestBooks)
        if ok and type(fps) == "table" then return fps end
        return orig(...)   -- library scan missing: SimpleUI's own walk
    end)
end

local function patcherFor(name)
    if name == "modules/critter/sprite" then return patchCritterSprite end
    if name == "modules/critter/bubble" then return patchCritterBubbleBuild end
    if name == "engines/sui_book_sources" then return patchBookSources end
    if name == "lib/bookshelf_reader_park" then return patchBookshelfPark end
    if name == "infra/sui_core" then return patchCore end
    if name == "engines/sui_screen_engine" then return patchEngine end
    if name == "engines/sui_section_label" then return patchSectionLabel end
    if name == "screens/sui_bottombar" then return patchBottombar end
    if name == "screens/sui_topbar" then return patchTopbar end
    if name == "infra/sui_config" then return patchConfig end
    -- modules/module_x (SimpleUI 2.x) and modules/<folder>/module_x (3.0:
    -- reading_stats, critter)
    if name:find("^modules/") and name:find("/module_[^/]+$") then
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

-- ---- Bookshelf: Close Bookshelf goes straight to SimpleUI home ----------------------
-- With SimpleUI home as the start screen, "Close Bookshelf" showed the stock
-- library for a moment: SimpleUI only brings its home back on the next tick,
-- and KOReader's menu redraws the screen in between (it repaints right after
-- a menu item's action). Here the home is shown in the same step the shelf
-- closes, so that redraw already shows it. Only for a user's Close Bookshelf
-- with no book held behind the shelf (Bookshelf asks its reader-park module
-- first, every time); everything else Bookshelf closes for is left alone.
local bs_close_home = false

patchBookshelfPark = function(Park)
    if type(Park) ~= "table" or type(Park.closeShelfToFileManager) ~= "function" then return false end
    local orig = Park.closeShelfToFileManager
    if ours[orig] then return true end
    Park.closeShelfToFileManager = mine(function(...)
        local res = pack(orig(...))
        if not res[1] then
            -- no book held: the caller now closes the shelf itself
            bs_close_home = true
            local UIManager = orig_require("ui/uimanager")
            UIManager:nextTick(function() bs_close_home = false end)
        end
        return unpack(res, 1, res.n)
    end)
    return true
end

local function showSimpleUIHome()
    if not (G_reader_settings and G_reader_settings:readSetting("start_with") == "homescreen_simpleui") then return end
    local UIManager = orig_require("ui/uimanager")
    if UIManager._exit_code ~= nil or UIManager._simpleui_exiting then return end
    local RUI = package.loaded["apps/reader/readerui"]
    if type(RUI) == "table" and RUI.instance then return end
    local HS = package.loaded["screens/sui_homescreen"]
    if type(HS) ~= "table" or HS._instance then return end
    local FM = package.loaded["apps/filemanager/filemanager"]
    local fm = type(FM) == "table" and FM.instance
    local plugin = type(fm) == "table" and (fm._simpleui_plugin or fm[sui_name])
    if type(plugin) ~= "table" or type(plugin._navigate) ~= "function" then return end
    plugin:_navigate("homescreen", plugin.ui or fm, nil, false)
end

do
    local UIManager = orig_require("ui/uimanager")
    local orig_close = UIManager.close
    if type(orig_close) == "function" and not ours[orig_close] then
        UIManager.close = mine(function(self, w, ...)
            if not (bs_close_home and type(w) == "table" and w.name == "bookshelf") then
                return orig_close(self, w, ...)
            end
            bs_close_home = false
            local res = pack(orig_close(self, w, ...))
            local ok, err = pcall(showSimpleUIHome)
            if not ok then logger.warn(TAG, "Bookshelf close -> home failed:", err) end
            return unpack(res, 1, res.n)
        end)
    end
end

-- ---- Keep SimpleUI home under windows opened from the menu ---------------------------
-- SimpleUI closes its home whenever a full-screen window opens, and brings it
-- back when that window closes, unless a dialog is still open. KOReader's
-- menu counts as one, so with the menu left open (e.g. Shortcuts Toolbar
-- items), closing the window showed the stock library behind the menu until
-- the menu closed too. When a full-screen window opens on top of the menu
-- while the home is under that menu, the home is kept (SimpleUI's own
-- _sui_keep_homescreen flag), so closing the window goes back to menu + home.
local function isTouchMenuContainer(w)
    local tm = type(w) == "table" and w[1]
    return type(tm) == "table" and type(tm.tab_item_table) == "table"
end

local function homeUnderOpenMenu()
    local UIManager = orig_require("ui/uimanager")
    local stack = UIManager._window_stack
    if type(stack) ~= "table" then return false end
    local hs_at
    for i = 1, #stack do
        local w = stack[i] and stack[i].widget
        if type(w) == "table" then
            if w.name == "homescreen" and not w._parked then hs_at = i
            elseif hs_at and isTouchMenuContainer(w) then return true end
        end
    end
    return false
end

-- Page Turn Flash: SimpleUI turns home screen pages with a quiet "ui"
-- update, which leaves the old page ghosting through. Normal adds KOReader's
-- UI flash to the turn, Strong a full refresh (clears dark pages too).
local function hookPageFlash(w)
    local owner = getmetatable(w)
    for _i = 1, 8 do
        if type(owner) ~= "table" or rawget(owner, "_setPage") ~= nil then break end
        owner = getmetatable(owner)
    end
    if type(owner) ~= "table" or type(rawget(owner, "_setPage")) ~= "function" or ours[owner._setPage] then return end
    local orig = owner._setPage
    owner._setPage = mine(function(self, page, ...)
        local before = self._current_page
        local res = pack(orig(self, page, ...))
        local mode = cfg.page_flash
        if (mode == "normal" or mode == "strong") and before ~= self._current_page then
            orig_require("ui/uimanager"):setDirty(self, mode == "strong" and "full" or "flashui")
        end
        return unpack(res, 1, res.n)
    end)
end

do
    local UIManager = orig_require("ui/uimanager")
    local orig_show = UIManager.show
    if type(orig_show) == "function" and not ours[orig_show] then
        UIManager.show = mine(function(self, w, ...)
            if type(w) == "table" and w.name == "homescreen" then
                -- Side panel lives in 2-simpleui-sidepanel.lua
                if package.loaded.simpleui_sidepanel
                        and type(package.loaded.simpleui_sidepanel.onHomeShow) == "function" then
                    pcall(package.loaded.simpleui_sidepanel.onHomeShow, w)
                end
                local ok2, err2 = pcall(hookPageFlash, w)
                if not ok2 then logger.warn(TAG, "page flash hook:", err2) end
            end
            if type(w) == "table" and w.covers_fullscreen and w.name ~= "homescreen"
                    and w.name ~= "ReaderUI" and not w._sui_keep_homescreen then
                local ok, yes = pcall(homeUnderOpenMenu)
                if ok and yes then w._sui_keep_homescreen = true end
            end
            return orig_show(self, w, ...)
        end)
    end
end

local function refreshTopbarNow()
    local T = package.loaded["screens/sui_topbar"]
    local p = suiInstance()
    if p and type(T) == "table" and type(T.refresh) == "function" then
        pcall(T.refresh, p)
    end
    -- no instance found: the change shows on SimpleUI's next minute tick
end

-- Shared notification contract v1: user-facing status notes go through the
-- installed notifier with the best style, in priority order: Network Tweaks,
-- ReadMastery notify, then our own InfoMessage default. Checks run at call
-- time, so patch load order doesn't matter. Never over the sleep screen.
local function shared_note(banner_text, minimal_text, timeout)
    local Device = orig_require("device")
    if Device.screen_saver_mode then return true end
    local NetworkMgr = orig_require("ui/network/manager")
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


local function askRestart()
    local UIManager = orig_require("ui/uimanager")
    if UIManager.askForRestart then
        UIManager:askForRestart(_("Restart KOReader to apply this change to the home screen."))
    elseif not shared_note(_("Restart KOReader to apply this change.")) then
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

-- Settings that change what the home screen builds: rebuild it now.
local function setHome(key, value)
    cfg[key] = value
    saveConfig()
    for k in pairs(swipe_state) do swipe_state[k] = nil end
    local UIManager = orig_require("ui/uimanager")
    for i = #(UIManager._window_stack or {}), 1, -1 do
        local w = UIManager._window_stack[i].widget
        if type(w) == "table" and w.name == "homescreen" and type(w._refreshImmediate) == "function" then
            pcall(w._refreshImmediate, w, false)
            return
        end
    end
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
                      if not shared_note(_("Not a valid colour. Use #RRGGBB."), nil, 3) then
                          UIManager:show(orig_require("ui/widget/infomessage"):new{
                              text = _("Not a valid colour. Use #RRGGBB."), timeout = 3 })
                      end
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

-- ---- Colour picker: named swatches, shown as they'll look on screen -------------------
local PALETTE = {
    { "Black",      "#000000" }, { "Charcoal",   "#333333" }, { "Dark grey", "#555555" }, { "Grey",   "#888888" },
    { "Silver",     "#AAAAAA" }, { "Light grey", "#CCCCCC" }, { "White",     "#FFFFFF" }, { "Navy",   "#1F3A68" },
    { "Blue",       "#2E6FD8" }, { "Sky",        "#6FB7E9" }, { "Teal",      "#1B8A8A" }, { "Green",  "#2E8B57" },
    { "Olive",      "#6B8E23" }, { "Gold",       "#D4A017" }, { "Orange",    "#E07B24" }, { "Red",    "#C62828" },
    { "Maroon",     "#7B1E2B" }, { "Pink",       "#E78FB3" }, { "Purple",    "#6A3D9A" }, { "Brown",  "#7A4E2D" },
    -- deep, fully saturated shades that hold up on colour e-ink
    { "Ink blue",   "#0040B0" }, { "Ink green",  "#00753A" }, { "Ink red",   "#B00018" }, { "Ink purple", "#5A14A0" },
    { "Ink orange", "#C25400" },
}

local function paletteName(hex)
    if type(hex) ~= "string" then return nil end
    for _i, p in ipairs(PALETTE) do
        if p[2] == hex:upper() then return p[1] end
    end
    return nil
end

-- Black or white label, whichever reads better on this swatch.
local function labelOn(hex)
    local r, g, b = parseRGB(hex)
    local lum = (0.299 * r + 0.587 * g + 0.114 * b)
    return lum < 140 and "#FFFFFF" or "#000000"
end

local function showColourPicker(current, on_pick)
    local UIManager       = orig_require("ui/uimanager")
    local InputContainer  = orig_require("ui/widget/container/inputcontainer")
    local FrameContainer  = orig_require("ui/widget/container/framecontainer")
    local CenterContainer = orig_require("ui/widget/container/centercontainer")
    local VerticalGroup   = orig_require("ui/widget/verticalgroup")
    local HorizontalGroup = orig_require("ui/widget/horizontalgroup")
    local VerticalSpan    = orig_require("ui/widget/verticalspan")
    local HorizontalSpan  = orig_require("ui/widget/horizontalspan")
    local TextWidget      = orig_require("ui/widget/textwidget")
    local ButtonTable     = orig_require("ui/widget/buttontable")
    local Font            = orig_require("ui/font")
    local Geom            = orig_require("ui/geometry")
    local GestureRange    = orig_require("ui/gesturerange")
    local Size            = orig_require("ui/size")

    -- What you pick is what you see: in Night Mode the swatch is drawn
    -- pre-inverted, so after the screen's inversion it shows the real colour.
    local function drawn(hex) return colorOf(hex, Screen.night_mode) end

    local sw, sh = Screen:getWidth(), Screen:getHeight()
    local gap = Screen:scaleBySize(6)
    local width = math.floor(math.min(sw, sh) * 0.9)
    -- 5 columns when swatches stay wide enough to read, else 4
    local cols = 5
    if (width - gap * 6) / 5 < Screen:scaleBySize(90) then cols = 4 end
    local nrows = math.ceil(#PALETTE / cols)
    local cell_w = math.floor((width - gap * (cols + 1)) / cols)
    -- Height: whatever fits. Title, buttons, padding and gaps are set aside
    -- first; the swatches share the rest (never taller than comfortable).
    local reserved = Screen:scaleBySize(40) + Screen:scaleBySize(70) + gap * (nrows + 6)
    local fit = math.floor((sh * 0.9 - reserved) / nrows)
    local cell_h = math.max(Screen:scaleBySize(28), math.min(Screen:scaleBySize(52), fit))
    local face = Font:getFace("cfont", cell_h < Screen:scaleBySize(40) and 14 or 16)
    local cur = type(current) == "string" and current:upper() or nil

    local picker
    local cells, box

    -- Builds the dialog with swatches of the given height.
    local function build(ch)
        cells = {}
        local rows = VerticalGroup:new{ align = "center" }
        local row
        for i, p in ipairs(PALETTE) do
            if (i - 1) % cols == 0 then
                row = HorizontalGroup:new{ align = "center" }
                rows[#rows + 1] = VerticalSpan:new{ width = gap }
                rows[#rows + 1] = row
            else
                row[#row + 1] = HorizontalSpan:new{ width = gap }
            end
            local selected = (cur == p[2])
            local frame = FrameContainer:new{
                background = drawn(p[2]),
                color = drawn("#000000"),
                bordersize = selected and Size.border.thick * 2 or Size.border.thin,
                padding = 0, margin = 0,
                CenterContainer:new{
                    dimen = Geom:new{ w = cell_w, h = ch },
                    TextWidget:new{
                        text = (selected and "\u{2713} " or "") .. p[1],
                        face = face,
                        fgcolor = drawn(labelOn(p[2])),
                        max_width = cell_w - gap,
                    },
                },
            }
            cells[#cells + 1] = { frame = frame, hex = p[2] }
            row[#row + 1] = frame
        end

        local buttons = ButtonTable:new{
            width = width - gap * 2,
            buttons = {{
                { text = _("Hex code…"), callback = function()
                    UIManager:close(picker)
                    customColorDialog(current, on_pick)
                end },
                { text = _("Cancel"), callback = function() UIManager:close(picker) end },
            }},
        }

        box = FrameContainer:new{
            background = Blitbuffer.COLOR_WHITE,
            bordersize = Size.border.window,
            radius = Size.radius.window,
            padding = gap,
            VerticalGroup:new{
                align = "center",
                TextWidget:new{ text = _("Pick a colour"), face = Font:getFace("tfont", 20) },
                rows,
                VerticalSpan:new{ width = gap * 2 },
                buttons,
            },
        }
    end

    -- Measure the real dialog and shrink the swatches until it fits.
    local limit = math.floor(sh * 0.94)
    for _try = 1, 6 do
        build(cell_h)
        local h = box:getSize().h
        if h <= limit or cell_h <= Screen:scaleBySize(24) then break end
        cell_h = math.max(Screen:scaleBySize(24), cell_h - math.ceil((h - limit) / nrows) - 1)
    end

    picker = InputContainer:new{
        dimen = Geom:new{ x = 0, y = 0, w = sw, h = sh },
        CenterContainer:new{ dimen = Geom:new{ w = sw, h = sh }, box },
    }
    picker.ges_events = {
        TapSelect = { GestureRange:new{ ges = "tap", range = Geom:new{ x = 0, y = 0, w = sw, h = sh } } },
    }
    function picker:onTapSelect(_arg, ges)
        for _i, c in ipairs(cells) do
            if c.frame.dimen and c.frame.dimen:contains(ges.pos) then
                UIManager:close(self)
                on_pick(c.hex)
                return true
            end
        end
        if box.dimen and not box.dimen:contains(ges.pos) then
            UIManager:close(self)   -- tap outside: cancel
        end
        return true
    end
    function picker:onCloseWidget()
        UIManager:setDirty(nil, "ui", self.dimen)
    end
    -- Ask for our own screen refresh over the whole dialog. Without it the
    -- picker relied on whatever refresh was already queued (e.g. just the
    -- menu's area), so the part below the menu could stay un-updated and
    -- look cut off. "flashui": a clean redraw so the swatch colours show true.
    UIManager:show(picker, function()
        return "flashui", box.dimen or picker.dimen
    end)
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
                return _("More colours") .. " (" .. (paletteName(v) or tostring(v)) .. ")"
            end
            return _("More colours…")
        end,
        radio = true,
        checked_func = function()
            local v = get()
            return v ~= nil and v ~= "none" and not isPreset(v)
        end,
        keep_menu_open = true,
        callback = function(touchmenu_instance)
            showColourPicker(get(), function(v)
                put(v)
                if touchmenu_instance then touchmenu_instance:updateItems() end
            end)
        end,
    }
    items[#items + 1] = {
        text = off_label or _("SimpleUI Default"), radio = true,
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
            text = pct == 100 and (pct .. "% " .. _("(Default)")) or (pct .. "%"),
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
                              if not shared_note(_("Enter a number from 50 to 300."), nil, 3) then
                                  UIManager:show(orig_require("ui/widget/infomessage"):new{
                                      text = _("Enter a number from 50 to 300."), timeout = 3 })
                              end
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
    local function accentMods() return cfg.accent_modules end

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

    -- Modules > Text colour: "All modules" defaults + one submenu per module
    local function modPut(id, field)
        return function(v)
            local t = cfg.module_colors[id] or {}
            t[field] = v
            if next(t) == nil then cfg.module_colors[id] = nil else cfg.module_colors[id] = t end
            saveConfig()
            applyConfig()
            askRestart()
        end
    end
    local function modGet(id, field)
        return function() local t = cfg.module_colors[id]; return t and t[field] end
    end
    local text_colour_items = {
        {
            text = _("All Modules"),
            sub_item_table = {
                { text = _("Colour"), sub_item_table = colorMenu("module_text", true) },
                { text = _("Colour In Night Mode"),
                  sub_item_table = colorMenu("night_text", true, _("Off (Inverts With The Screen)")) },
            },
            separator = true,
        },
    }
    for _i, m in ipairs(ALL_MODULES) do
        local id, name = m[1], m[2]
        text_colour_items[#text_colour_items + 1] = {
            text_func = function()
                return cfg.module_colors[id] and (name .. " •") or name   -- dot = customised
            end,
            sub_item_table = {
                { text = _("Colour"),
                  sub_item_table = colorMenuWith(modGet(id, "text"), modPut(id, "text"),
                                                 nil, _("Same As All Modules")) },
                { text = _("Colour In Night Mode"),
                  sub_item_table = colorMenuWith(modGet(id, "night"), modPut(id, "night"),
                                                 _("Off (Inverts With The Screen)"), _("Same As All Modules")) },
                { text = _("Reset This Module"),
                  callback = function()
                      cfg.module_colors[id] = nil
                      saveConfig(); applyConfig(); askRestart()
                  end },
            },
        }
    end

    local titles_items = {
        {
            text = _("All Sections"),
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
            text = _("Day Look In Night Mode"),
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
                                                 nil, _("Same As All Sections")) },
                { text = _("Bold"),
                  sub_item_table = {
                    { text = _("Same As All Sections"), radio = true,
                      checked_func = function() return sectionGet(id, "bold")() == nil end,
                      callback = function() sectionPut(id, "bold")(nil) end,
                      separator = true },
                    { text = _("Bold"), radio = true,
                      checked_func = function() return sectionGet(id, "bold")() == true end,
                      callback = function() sectionPut(id, "bold")(true) end },
                    { text = _("Not Bold"), radio = true,
                      checked_func = function() return sectionGet(id, "bold")() == false end,
                      callback = function() sectionPut(id, "bold")(false) end },
                  } },
                { text_func = function()
                      local v = sectionGet(id, "size")()
                      return _("Size") .. ": " .. (v and (v .. "%") or _("Same As All"))
                  end,
                  sub_item_table = sizeMenuWith(sectionGet(id, "size"), sectionPut(id, "size"),
                                                _("Same As All Sections")) },
                { text = _("Reset This Section"),
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
            -- Modules: toggles first, then colour options
            {
                text = _("Modules"),
                sub_item_table = {
                    { text = _("Currently Reading: Swipe Between Books"),
                      help_text = _("Swipe left or right on Currently Reading to step through your most recent books still in progress. Dots on the cover show where you are."),
                      checked_func = function() return cfg.currently_swipe end,
                      callback = function() setHome("currently_swipe", not cfg.currently_swipe) end },
                    { text_func = function()
                          return string.format(_("Books To Swipe Through: %d"), cfg.currently_books)
                      end,
                      enabled_func = function() return cfg.currently_swipe end,
                      sub_item_table_func = function()
                          local items = {}
                          for k = 2, 6 do
                              items[#items + 1] = { text = tostring(k), radio = true,
                                  checked_func = function() return cfg.currently_books == k end,
                                  callback = function() setHome("currently_books", k) end }
                          end
                          return items
                      end,
                      separator = true },
                    { text = _("Also Recolour Grey Text"),
                      checked_func = function() return cfg.recolor_all end,
                      callback = function() set("recolor_all", not cfg.recolor_all, true) end,
                      separator = true },
                    { text = _("Quick Actions Icons Keep Original Colours In Night Mode"),
                      checked_func = function() return cfg.qa_icons_original end,
                      callback = function() set("qa_icons_original", not cfg.qa_icons_original) end,
                      separator = true },
                    { text = _("Text Colour"),
                      sub_item_table = text_colour_items },
                    { text = _("Progress & Borders Colour"),
                      sub_item_table = colorMenu("accent", true) },
                    { text = _("Progress Track Colour"),
                      sub_item_table = colorMenu("track", true) },
                    { text = _("Use Progress Colours In"),
                      sub_item_table = accent_items,
                      separator = true },
                },
            },
            -- Critter: all Tiny Critter settings in one place (toggles first)
            {
                text = _("Critter"),
                sub_item_table = {
                    { text = _("Critter Insights"),
                      help_text = _("The Tiny Critter tells you about your reading: your best day this month, book milestones, getting back on a roll, the book you're on being minutes from the end, what this month needs for your yearly goal, a gentle nudge after a few quiet days, and whether you read more on weekends. Each comes once, at most 3 a day, only when your stats back it. In its chat, a book it offered today isn't offered again. Needs Reactions on in SimpleUI's critter settings."),
                      checked_func = function() return cfg.critter_insights ~= false end,
                      callback = function() setHome("critter_insights", cfg.critter_insights == false) end },
                    { text = _("Critter Pep Talk"),
                      help_text = _("SimpleUI's \"minutes read today\" and \"pages turned today\" lines grow with your reading: a nudge after a minute or two, a groove at 15 minutes, a cheer at half an hour, a party past an hour. Within 10 minutes of your daily goal it counts you in. The line moves up a step next time the home screen draws as you read. With critter-phrases.lua in koreader/patches/, this and Critter Insights take their lines from it."),
                      checked_func = function() return cfg.critter_pep ~= false end,
                      callback = function() setHome("critter_pep", cfg.critter_pep == false) end },
                    { text = _("Critter Wanders (Dynamic)"),
                      help_text = _("With Critter Bubble Width > Dynamic: each time the home screen draws the row, the critter and its bubble move to the left, centre or right, with the critter on either side of the bubble. SimpleUI's own Side and Alignment take over when this is off."),
                      enabled_func = function() return critter_bubble ~= nil and (tonumber(cfg.critter_bubble) or 0) < 0 end,
                      checked_func = function() return cfg.critter_wander ~= false end,
                      callback = function() setHome("critter_wander", cfg.critter_wander == false) end },
                    { text_func = function()
                          local names = { wander = _("SimpleUI's / wanders"), left = _("Left"), right = _("Right"), edges = _("Left or right") }
                          return string.format(_("Critter Position: %s"), names[cfg.critter_pos] or names.wander)
                      end,
                      help_text = _("Where in its row the critter and its speech bubble go. Left or Right keeps them at that end, so the middle of the row (and your wallpaper behind it) stays clear. The third choice picks one end each time, never the middle. The first choice uses SimpleUI's Alignment, or wanders left, centre and right with Critter Wanders on. A bubble that needs the whole row can't move."),
                      enabled_func = function() return critter_bubble ~= nil end,
                      sub_item_table_func = function()
                          local items = {}
                          for _i, opt in ipairs({ { "wander", _("SimpleUI's own (wanders with Critter Wanders)") }, { "left", _("Left") }, { "right", _("Right") }, { "edges", _("Left or right (never the middle)") } }) do
                              items[#items + 1] = { text = opt[2], radio = true,
                                  checked_func = function() return (cfg.critter_pos or "wander") == opt[1] end,
                                  callback = function() setHome("critter_pos", opt[1]) end }
                          end
                          return items
                      end },
                    { text_func = function()
                          local w = tonumber(cfg.critter_bubble) or 0
                          local names = { [0] = _("Default"), [360] = _("Wide"), [440] = _("Wider"), [2000] = _("Full Row"), [-1] = _("Dynamic") }
                          return string.format(_("Critter Bubble Width: %s"), names[w] or tostring(w))
                      end,
                      help_text = _("Width of the Tiny Critter's speech bubble (SimpleUI 3.0). Wider fits longer lines on fewer rows; its chat answers follow. Full Row takes all the room the critter and decorations leave. Dynamic keeps SimpleUI's width for short lines and grows only as much as a long line needs."),
                      enabled_func = function() return critter_bubble ~= nil end,
                      sub_item_table_func = function()
                          local items = {}
                          for _i, opt in ipairs({ { 0, _("Default") }, { -1, _("Dynamic") }, { 360, _("Wide") }, { 440, _("Wider") }, { 2000, _("Full Row") } }) do
                              items[#items + 1] = { text = opt[2], radio = true,
                                  checked_func = function() return (tonumber(cfg.critter_bubble) or 0) == opt[1] end,
                                  callback = function()
                                      cfg.critter_bubble = opt[1]
                                      applyCritterBubble()
                                      setHome("critter_bubble", opt[1])
                                  end }
                          end
                          return items
                      end,
                      separator = true },
                    { text_func = function()
                          local m = type(cfg.critter_mix) == "table" and cfg.critter_mix or {}
                          return #m >= 2 and _("Critter Mix: ") .. #m .. " " .. _("critters") or _("Critter Mix: off")
                      end,
                      help_text = _("Tick two or more critters and they take turns: the next one shows each time the critter picks something new to say (every 20 minutes or so, a new part of the day, or when you tap it). Reading Log's critter takes turns too: a new remark or a tap there moves it along. Tick fewer than two to go back to the one picked in SimpleUI's critter settings."),
                      sub_item_table_func = function()
                          local items = {}
                          local As = package.loaded["modules/critter/assets"]
                          local list = {}
                          if type(As) == "table" and type(As.list) == "function" then
                              local okl, l = pcall(As.list)
                              if okl and type(l) == "table" then list = l end
                          end
                          for _i, e in ipairs(list) do
                              local id = e.id
                              items[#items + 1] = {
                                  text = e.name or id,
                                  keep_menu_open = true,
                                  checked_func = function()
                                      for _j, v in ipairs(cfg.critter_mix or {}) do if v == id then return true end end
                                      return false
                                  end,
                                  callback = function()
                                      local new, had = {}, false
                                      for _j, v in ipairs(cfg.critter_mix or {}) do
                                          if v == id then had = true else new[#new + 1] = v end
                                      end
                                      if not had then new[#new + 1] = id end
                                      setHome("critter_mix", new)
                                  end,
                              }
                          end
                          if #items == 0 then
                              items[1] = { text = _("No critters found (SimpleUI 3.0's Tiny Critter)"), enabled = false }
                          end
                          return items
                      end },
                    { text_func = function()
                          local names = { auto = _("Auto"), white = _("White"), black = _("Black") }
                          return string.format(_("Critter Text Colour: %s"), names[cfg.critter_text] or names.auto)
                      end,
                      help_text = _("Colour of the Tiny Critter's speech text (and its bubble outline). Auto writes in white when the bubble is dark, as with a dark SimpleUI look, and leaves it alone otherwise. White or Black always. Reading Log's critter follows too."),
                      enabled_func = function() return critter_bubble ~= nil end,
                      sub_item_table_func = function()
                          local items = {}
                          for _i, opt in ipairs({ { "auto", _("Auto (white on a dark bubble)") }, { "white", _("White") }, { "black", _("Black") } }) do
                              items[#items + 1] = { text = opt[2], radio = true,
                                  checked_func = function() return (cfg.critter_text or "auto") == opt[1] end,
                                  callback = function() setHome("critter_text", opt[1]) end }
                          end
                          return items
                      end },
                    { text_func = function()
                          local names = { random = _("SimpleUI's / random"), left = _("Left of text"), right = _("Right of text") }
                          return string.format(_("Critter Side: %s"), names[cfg.critter_wander_side] or names.random)
                      end,
                      help_text = _("Which side of its text (speech bubble) the critter stands on: always left of the text, always right, or SimpleUI's own setting (with Critter Wanders on, it switches each time). The row can still wander left, centre or right."),
                      enabled_func = function() return critter_bubble ~= nil end,
                      sub_item_table_func = function()
                          local items = {}
                          for _i, opt in ipairs({ { "random", _("SimpleUI's own (random while wandering)") }, { "left", _("Left of text") }, { "right", _("Right of text") } }) do
                              items[#items + 1] = { text = opt[2], radio = true,
                                  checked_func = function() return (cfg.critter_wander_side or "random") == opt[1] end,
                                  callback = function() setHome("critter_wander_side", opt[1]) end }
                          end
                          return items
                      end },
                    { text_func = function()
                          local names = { [100] = _("Default"), [130] = _("Taller"), [160] = _("Tallest") }
                          return string.format(_("Critter Row Height: %s"), names[rowPct()] or (rowPct() .. "%"))
                      end,
                      help_text = _("Height of the Tiny Critter's row (SimpleUI 3.0). Taller gives the speech bubble room for its full lines; the row keeps that height for every phrase, so nothing below it moves. The critter keeps its size; Critter Size > Fill Height grows it to the new row."),
                      enabled_func = function() return critter_row ~= nil end,
                      sub_item_table_func = function()
                          local items = {}
                          for _i, opt in ipairs({ { 100, _("Default") }, { 130, _("Taller") }, { 160, _("Tallest") } }) do
                              items[#items + 1] = { text = opt[2], radio = true,
                                  checked_func = function() return rowPct() == opt[1] end,
                                  callback = function()
                                      cfg.critter_row = opt[1]
                                      applyCritterRow()
                                      setHome("critter_row", opt[1])
                                  end }
                          end
                          return items
                      end },
                    { text_func = function()
                          local names = { default = _("Default"), fill = _("Fill Height"), smaller = _("Smaller") }
                          return string.format(_("Critter Size: %s"), names[cfg.critter_size] or names.default)
                      end,
                      help_text = _("Size of the Tiny Critter (SimpleUI 3.0). Default is SimpleUI's: the largest whole pixel step that fits, often shorter than the bubble. Fill Height matches the bubble's height. Smaller is one step down. Decorations next to it follow."),
                      enabled_func = function() return critter_sprite_on end,
                      sub_item_table_func = function()
                          local items = {}
                          for _i, opt in ipairs({ { "default", _("Default") }, { "fill", _("Fill Height") }, { "smaller", _("Smaller") } }) do
                              items[#items + 1] = { text = opt[2], radio = true,
                                  checked_func = function() return (cfg.critter_size or "default") == opt[1] end,
                                  callback = function() setHome("critter_size", opt[1]) end }
                          end
                          return items
                      end,
                      separator = true }
                },
            },
            {
                text = _("Page Turns"),
                sub_item_table = {
                    { text_func = function()
                          if CF.early and CF.early.other then return _("Early Page Turn (off: 2-earlyturn.lua is installed)") end
                          return _("Early Page Turn")
                      end,
                      help_text = _("A sideways swipe turns the page as soon as your finger has moved far enough, instead of waiting for you to lift it. Works in books (page mode, not scroll or zoomed) and, with Also In Lists, in full-screen lists like the file browser, history, collections, table of contents and bookmarks. One turn per swipe. Off when KOReader's swipe page turns are off, or when swipes follow links or go back. Taps aren't changed."),
                      enabled_func = function() return not (CF.early and CF.early.other) end,
                      checked_func = function() return cfg.early_turn == true end,
                      callback = function() cfg.early_turn = not cfg.early_turn; saveConfig() end },
                    { text = _("Also In Lists"),
                      enabled_func = function() return cfg.early_turn == true end,
                      checked_func = function() return cfg.early_turn_lists ~= false end,
                      callback = function() cfg.early_turn_lists = (cfg.early_turn_lists == false); saveConfig() end },
                    { text_func = function()
                          return string.format(_("Swipe Distance: %d dp"), tonumber(cfg.early_turn_dp) or 35)
                      end,
                      help_text = _("How far your finger moves before the page turns. 35 dp is the shortest KOReader can see (about 7 mm on a 300 dpi Kobo); longer is harder to set off by accident."),
                      enabled_func = function() return cfg.early_turn == true end,
                      sub_item_table_func = function()
                          local items = {}
                          for _i, opt in ipairs({ { 35, _("35 dp (quickest)") }, { 50, _("50 dp") }, { 80, _("80 dp (needs a longer swipe)") } }) do
                              items[#items + 1] = { text = opt[2], radio = true,
                                  checked_func = function() return (tonumber(cfg.early_turn_dp) or 35) == opt[1] end,
                                  callback = function() cfg.early_turn_dp = opt[1]; saveConfig() end }
                          end
                          return items
                      end },
                },
            },
            {
                text = _("Appearance"),
                sub_item_table = {
                    {
                text_func = function()
                    local names = { off = _("Off"), normal = _("Normal"), strong = _("Strong") }
                    return string.format(_("Page Turn Flash: %s"), names[cfg.page_flash] or names.off)
                end,
                help_text = _("SimpleUI turns home screen pages (page 1 to 2 and back) with a quiet update, so the old page can ghost through. Normal adds a quick flash to each turn; Strong a full refresh, which also clears dark pages and night mode. Off keeps turns as fast as they are now."),
                sub_item_table_func = function()
                    local items = {}
                    for _i, opt in ipairs({ { "off", _("Off (fastest)") }, { "normal", _("Normal (quick flash)") }, { "strong", _("Strong (full refresh)") } }) do
                        items[#items + 1] = { text = opt[2], radio = true,
                            checked_func = function() return (cfg.page_flash or "off") == opt[1] end,
                            callback = function() cfg.page_flash = opt[1]; saveConfig() end }
                    end
                    return items
                end,
            },
                    {
                text = _("Section Titles"),
                sub_item_table = titles_items,
            },
                    {
                text = _("Status Bar"),
                sub_item_table = {
                    item(_("Bold"), toggle(boldTbl, "topbar", refreshTopbarNow)),
                    { text = _("Day Look In Night Mode"),
                      checked_func = function() return cfg.topbar_day_night end,
                      callback = function() set("topbar_day_night", not cfg.topbar_day_night) end },
                },
                separator = true,
            }
                },
            },
            {
                text = _("Bars & Menus"),
                sub_item_table = {
                    {
                text = _("Nav Bar"),
                sub_item_table = {
                    { text = _("Day Look In Night Mode"),
                      checked_func = function() return cfg.nav_labels_black end,
                      callback = function() set("nav_labels_black", not cfg.nav_labels_black) end },
                    { text = _("Icons Keep Original Colours In Night Mode"),
                      checked_func = function() return cfg.nav_icons_original end,
                      callback = function() set("nav_icons_original", not cfg.nav_icons_original) end },
                },
            },
                    {
                text = _("KOReader Menu"),
                sub_item_table = {
                    { text_func = function()
                          local n = 0
                          for _k in pairs(cfg.menu_icons.tab) do n = n + 1 end
                          return _("Tab icons keep original colours in Night Mode") .. (n > 0 and (": " .. n) or "")
                      end,
                      help_text = _("For colour icons you've swapped in (same file name in koreader/icons/). Plain black icons would disappear on the dark Night Mode menu. Applies the next time the menu opens."),
                      sub_item_table_func = tabItems },
                    { text = _("Arrows Keep Original Colours In Night Mode"),
                      help_text = _("Back arrow and page arrows. Only useful with colour arrow icons swapped in. Applies the next time the menu opens."),
                      checked_func = function() return cfg.menu_icons.arrows end,
                      callback = function() cfg.menu_icons.arrows = not cfg.menu_icons.arrows; saveConfig() end },
                },
            }
                },
            },
            {
                text = _("Reset To Defaults"),
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
            return { { text = _("Couldn't Load Settings (See Crash.log)"), enabled = false } }
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

-- ---- Early Page Turn ----------------------------------------------------------------
-- A horizontal swipe turns the page as soon as the finger has moved far
-- enough, instead of on lift. Works in books (page mode) and in full-screen
-- KOReader lists (file browser, history, collections, TOC, bookmarks, search).
-- One turn per gesture; the lift of that gesture is swallowed so nothing
-- turns twice. Settings are read live, so the toggle needs no restart.
-- Steps aside when ura23's 2-earlyturn.lua is installed (same job).
do
    local ET = { claimed = nil }
    CF.early = ET

    local okd, DataStorage = pcall(require, "datastorage")
    local okl, lfs = pcall(require, "libs/libkoreader-lfs")
    if okd and okl and DataStorage and lfs then
        local f = DataStorage:getDataDir() .. "/patches/2-earlyturn.lua"
        ET.other = lfs.attributes(f, "mode") == "file"
    end

    local okdev, Device = pcall(require, "device")
    local Screen = okdev and Device and Device.screen
    local is_touch = okdev and Device and Device.isTouchDevice and Device:isTouchDevice()

    local px_cache, px_dp, px_dpi
    local function stepPx()
        local dp = tonumber(cfg.early_turn_dp) or 35
        local dpi = Screen:getDPI()
        if px_dp ~= dp or px_dpi ~= dpi then
            px_dp, px_dpi = dp, dpi
            px_cache = Screen:scaleByDPI(dp)
        end
        return px_cache
    end

    local function active()
        return cfg.early_turn and is_touch and not ET.other
    end

    -- Direction of a pan that has gone far enough and is clearly sideways
    -- (at least twice as wide as tall); nil otherwise.
    local function farEnough(ges)
        if ges.mousewheel_direction then return nil end
        local d = ges.relative
        if type(d) ~= "table" or type(d.x) ~= "number" or type(d.y) ~= "number" then return nil end
        local ax = d.x < 0 and -d.x or d.x
        local ay = d.y < 0 and -d.y or d.y
        if ax < stepPx() or ax < 2 * ay then return nil end
        return d.x < 0 and "west" or "east"
    end

    -- Same gesture as the one already turned? (pans of one gesture share
    -- their start point)
    local function sameGesture(ges)
        local c, s = ET.claimed, ges.start_pos
        return c ~= nil and type(s) == "table" and c[1] == s.x and c[2] == s.y
    end
    local function claim(ges)
        local s = ges.start_pos
        ET.claimed = { s.x, s.y }
    end
    local function release()
        local had = ET.claimed ~= nil
        ET.claimed = nil
        return had
    end

    local okbd, BD = pcall(require, "ui/bidi")
    local function mirror(dir)
        if okbd and BD and BD.flipDirectionIfMirroredUILayout then
            return BD.flipDirectionIfMirroredUILayout(dir)
        end
        return dir
    end

    local function readerCanTurn(ui)
        local view = ui and ui.view
        if not view then return false end
        local s = G_reader_settings
        if s:isTrue("page_turns_disable_swipe") or s:isTrue("swipe_to_go_back")
                or s:isTrue("swipe_to_follow_nearest_link") then
            return false
        end
        if ui.rolling then return view.view_mode == "page" end
        if ui.paging then
            if view.page_scroll then return false end
            if ui.paging.page_flipping_mode or ui.paging.bookmark_flipping_mode then return false end
            if view.zoom_mode and view.zoom_mode ~= "page" then return false end
        end
        return true
    end

    local okev, Event = pcall(require, "ui/event")
    local function readerPan(module, ges)
        if not active() or not okev then return false end
        local UIManager = require("ui/uimanager")
        if UIManager._input_gestures_disabled then return false end
        if type(ges) ~= "table" or type(ges.start_pos) ~= "table" then return false end
        if ET.claimed and not sameGesture(ges) then ET.claimed = nil end
        if ET.claimed then return true end
        local dir = farEnough(ges)
        if not dir or not readerCanTurn(module.ui) then return false end
        dir = mirror(dir)
        local back = module.ui.view.inverse_reading_order == true
        local step = ((dir == "west") ~= back) and 1 or -1
        module.ui:handleEvent(Event:new("GotoViewRel", step))
        claim(ges)
        return true
    end

    local function hookReader(path)
        local ok, M = pcall(require, path)
        if not ok or type(M) ~= "table" or M._sui_early_turn then return end
        M._sui_early_turn = true
        local o_pan, o_swipe, o_rel = M.onPan, M.onSwipe, M.onPanRelease
        if o_pan then
            M.onPan = function(self, arg, ges)
                local okp, took = pcall(readerPan, self, ges)
                if okp and took then return true end
                return o_pan(self, arg, ges)
            end
        end
        if o_swipe then
            M.onSwipe = function(self, arg, ges)
                if ET.claimed and release() then return true end
                return o_swipe(self, arg, ges)
            end
        end
        if o_rel then
            M.onPanRelease = function(self, arg, ges)
                if ET.claimed and release() then return true end
                return o_rel(self, arg, ges)
            end
        end
    end

    local function hookLists()
        local okm, Menu = pcall(require, "ui/widget/menu")
        local oki, IC = pcall(require, "ui/widget/container/inputcontainer")
        if not okm or type(Menu) ~= "table" or Menu._sui_early_turn then return end
        Menu._sui_early_turn = true
        local parent = Menu.onGesture
        local fallback = oki and IC and IC.onGesture
        local function fullList(m)
            if m.is_popout then return false end
            if not (m.page and m.page_num and m.page_num > 1) then return false end
            local d = m.dimen
            return d ~= nil and d.w >= Screen:getWidth() * 0.9 and d.h >= Screen:getHeight() * 0.9
        end
        Menu.onGesture = function(self, ev)
            if ev and active() and cfg.early_turn_lists ~= false and fullList(self) then
                local kind = ev.ges
                if kind == "pan" and type(ev.start_pos) == "table" then
                    if ET.claimed and not sameGesture(ev) then ET.claimed = nil end
                    if ET.claimed then return true end
                    local dir = farEnough(ev)
                    if dir then
                        dir = mirror(dir)
                        if dir == "west" then pcall(self.onNextPage, self)
                        else pcall(self.onPrevPage, self) end
                        claim(ev)
                        return true
                    end
                elseif kind == "swipe" or kind == "multiswipe" then
                    if ET.claimed and release() then return true end
                elseif kind == "pan_release" or kind == "two_finger_pan_release" then
                    release()
                end
            end
            local h = parent or fallback
            if h then return h(self, ev) end
        end
    end

    if is_touch and Screen and not ET.other then
        hookReader("apps/reader/modules/readerpaging")
        hookReader("apps/reader/modules/readerrolling")
        hookLists()
    end
end

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

userpatch.registerPatchPluginFunc("simpleui", function(plugin)
    -- Remember SimpleUI's plugin name (its folder name), for suiInstance().
    if type(plugin) == "table" and type(plugin.name) == "string" then sui_name = plugin.name end
end)