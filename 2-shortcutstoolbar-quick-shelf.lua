--[[
Shortcuts Toolbar – Quick Shelf (userpatch)
===========================================
Version: 1.5.0
For xusoo/shortcutstoolbar.koplugin

In the reader's Shortcuts toolbar, swipe left or right on the top row (the
book info panel) to flip between it and a strip of books. The shortcut icons
below stay where they are. Two dots show which page you're on. Each menu
open starts on the book panel.

Optional: Critter Remarks (Shortcuts toolbar menu, all off by default).
  • While Reading       - SimpleUI's Tiny Critter and a speech bubble in the
                          book panel's free strip, about where you are in
                          this book: pages and time left, the chapter end,
                          your pace this sitting, milestones, late nights.
  • On Library Toolbar  - the critter in the empty stretch of the file
                          browser menu's tab bar: sassy about the tab or
                          submenu you open, or the time of day.
Tap the critter for another remark. It's your home screen's critter, in its
own voice when it has lines (Donny, Blu, Donny & Blu). The lines are in
critter-phrases.lua 1.1.0+ (next to this patch; a few built-in ones stand
in without it). Pace lines need KOReader's reading statistics on. Without
SimpleUI's critter you still get the remark.

The strip (the Quick Shelf) shows, per Shortcuts toolbar → Quick Shelf Shows:
  • Books In Progress  - your reading history, most recent first: books
                         you've started and not finished (the open book
                         left out). Progress under each cover.
  • To Be Read         - the To Be Read collection (the same list
                         SimpleUI and Bookshelf use).
Tap a cover to switch to that book.

Reader only: the library toolbar and the SimpleUI module are unchanged.

Cost: nothing until you swipe. The strip is built on the first swipe of a
menu open and reused after that. Covers come from thumbnails SimpleUI
(or CoverBrowser) already keeps. A book is never opened to pull its cover.
A book with no saved thumbnail gets a title tile instead. Covers are kept
already sized between menu opens, up to 10. A swipe redraws only the top
row, so the menu doesn't resize. No timers.

Install: drop in koreader/patches/ and restart KOReader. Loads after
2-shortcutstoolbar-icon-tweaks.lua (file order), which it works with.

Tap the book panel (1.3.0, optional): Shortcuts toolbar → Book Panel Tap →
Opens BookOrbit "This Book" makes a tap on the book panel open BookOrbit's
This book sheet (sync status, sync now, progress) instead of KOReader's
book details. Hold Opens Book Details (on by default) keeps the details a
long-press away. Without BookOrbit, or not signed in, a tap does what it
always did.

Changelog
  1.5.0  Smarter remarks. While Reading goes by what's happening in this
         book: pages and time left (at your usual pace), the chapter
         ending, this sitting's pace against your usual (wow fast / slow
         going / steady), long and late sessions, quarter / halfway /
         home stretch, the finish, and sweet little remarks any time.
         Picks what fits now, never the same thing twice in a row, in
         your critter's own voice about half the time when it has lines
         (Donny, Blu, Donny & Blu). On Library Toolbar notices the tab and
         submenu you open (fonts, Wi-Fi, the sleep screen, your Add-ons...)
         and says something about it; submenus are known by name on
         KOReader 2025.10 too (Quick Shelf notes each one you open). Lines
         are in critter-phrases.lua 1.1.0 (editable, updatable). Some use
         your name, the one you gave SimpleUI's critter (Your name);
         without one they're skipped. Donny and Blu's extra poses show the
         base pose on other critters. With the Quick Shelf diagnostic
         installed, each menu remark is logged.
  1.4.3  Critter Remarks show SimpleUI's Tiny Critter (the one you picked)
         with its speech bubble. While Reading: in the book panel's free
         strip, under the title / author / page line, right of the cover;
         it measures the strip so it never covers the text. On Library
         Toolbar: in the empty stretch of the menu's tab bar before the last
         tab icon, instead of a row of its own. Tap the critter for another
         remark. It's the critter your home screen shows: SimpleUI Tweaks'
         Critter Mix (today's turn) when two or more are ticked, else the
         one picked in SimpleUI. (1.4.2's line on the book panel never
         painted: its text call had its arguments out of order.)
  1.4.2  Critter text draw fix (RenderText width API) so the book-panel
         remark actually paints; library row insert cleaned up. Both still
         off until enabled under Critter Remarks.
  1.4.1  Critter On Library Toolbar (off by default): a short remark in the
         empty area of the file-browser Shortcuts Toolbar home (near the
         top strip by Search / Menu), not on the swipe shelf.
  1.4.0  Critter On Book Panel (off by default): a remark about the open
         book on the toolbar's book panel when you pull it down — not on
         the swipe shelf. Tap the line for another remark.
  1.3.2  Clean-up: This Book trace lines removed from crash.log.
  1.3.1  Book Panel Tap: more reliable BookOrbit This Book (Dispatcher/event fallbacks;
         pager forwards taps on the book panel page).
  1.3.0  Book Panel Tap (Shortcuts toolbar menu): tap the book panel to
         open BookOrbit's This book sheet, with Hold Opens Book Details
         so KOReader's book details stay a long-press away. Off by
         default; nothing changes until you turn it on.
  1.2.2  Covers are kept between menu opens, already sized, so the first
         swipe of a menu open doesn't resize them again (about 25 ms a
         cover on a Clara Colour). Up to 10 covers are kept. A SimpleUI
         cover that changes is picked up straight away.
  1.2.1  Suspend dismisses the shelf: if the Quick Shelf page is showing
         when the device sleeps, the pager drops back to the book panel.
  1.2.0  Renamed Quick Shelf (was Recent Books: it shows To Be Read too).
         File is now 2-shortcutstoolbar-quick-shelf.lua: delete
         2-shortcutstoolbar-recent-books.lua. Your list choice carries
         over. If the old file is still there it's kept from doing
         anything, so the toolbar isn't patched twice.
  1.1.0  Swipe left or right: either flips to the other page (loops). No
         more ghosting: a page change flashes just the book row once.
  1.0.0  First release.
--]]

local Device = require("device")
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local userpatch = require("userpatch")
local _ = require("gettext")
local Screen = Device.screen

local PATCH_VERSION = "1.5.0"
local SETTINGS_KEY = "shortcutstoolbar_quick_shelf"
local OLD_SETTINGS_KEY = "shortcutstoolbar_recent_books" -- before 1.2.0
local MAX_BOOKS = 5
local HISTORY_SCAN = 30

local SOURCES = {
    { id = "reading", text = _("Books In Progress") },
    { id = "tbr",     text = _("To Be Read") },
}

local function source()
    local s = G_reader_settings:readSetting(SETTINGS_KEY)
        or G_reader_settings:readSetting(OLD_SETTINGS_KEY)
    return (type(s) == "table" and s.source == "tbr") and "tbr" or "reading"
end

-- Book panel tap (1.3.0): { tap_bookorbit = bool, hold_details = bool }
local function opt(key, default)
    local s = G_reader_settings:readSetting(SETTINGS_KEY)
    if type(s) == "table" and s[key] ~= nil then return s[key] end
    return default
end
local function setOpt(key, value)
    local s = G_reader_settings:readSetting(SETTINGS_KEY) or {}
    s[key] = value
    G_reader_settings:saveSetting(SETTINGS_KEY, s)
end

local function setSource(id)
    local s = G_reader_settings:readSetting(SETTINGS_KEY) or {}
    s.source = id
    G_reader_settings:saveSetting(SETTINGS_KEY, s)
    G_reader_settings:delSetting(OLD_SETTINGS_KEY)
end

-- openThisBook / showBookDetails are assigned later; pager closes over these locals.
local openThisBook, showBookDetails

-- --------------------------------------------------------------------------
-- Book lists
-- --------------------------------------------------------------------------

local function bookInfo(fp)
    local ok, BookList = pcall(require, "ui/widget/booklist")
    if not ok or type(BookList.getBookInfo) ~= "function" then return nil end
    local ok2, info = pcall(BookList.getBookInfo, fp)
    return ok2 and info or nil
end

local function currentFile()
    local ok, ReaderUI = pcall(require, "apps/reader/readerui")
    local ui = ok and ReaderUI.instance
    return ui and ui.document and ui.document.file
end

-- Started and not finished (KOReader's "Reading" status), newest first.
local function inProgress()
    local ok, RH = pcall(require, "readhistory")
    local hist = ok and type(RH) == "table" and RH.hist
    if type(hist) ~= "table" then return {} end
    local cur = currentFile()
    local fps, seen = {}, {}
    for i = 1, math.min(#hist, HISTORY_SCAN) do
        local fp = hist[i] and hist[i].file
        if type(fp) == "string" and fp ~= cur and not seen[fp] then
            seen[fp] = true
            local info = bookInfo(fp)
            if info and info.been_opened and info.status == "reading"
                    and lfs.attributes(fp, "mode") == "file" then
                fps[#fps + 1] = fp
                if #fps >= MAX_BOOKS then break end
            end
        end
    end
    return fps
end

-- Same source as the SimpleUI Tweaks side panel: SimpleUI's TBR module,
-- else KOReader's "To Be Read" collection directly.
local TBR_COLL = "To Be Read"
local function toBeRead()
    local raw
    local okm, TBR = pcall(require, "modules/module_tbr")
    if okm and type(TBR) == "table" and type(TBR.getTBRList) == "function" then
        local ok, list = pcall(TBR.getTBRList)
        if ok and type(list) == "table" then raw = list end
    end
    if not raw then
        local okr, RC = pcall(require, "readcollection")
        local coll = okr and type(RC) == "table" and RC.coll and RC.coll[TBR_COLL]
        raw = {}
        if type(coll) == "table" then
            local items = {}
            for _k, it in pairs(coll) do
                if type(it) == "table" and it.file then items[#items + 1] = it end
            end
            table.sort(items, function(a, b) return (a.order or 0) < (b.order or 0) end)
            for i, it in ipairs(items) do raw[i] = it.file end
        end
    end
    local cur = currentFile()
    local fps = {}
    for _i, it in ipairs(raw) do
        local fp = type(it) == "table" and it.file or it
        if type(fp) == "string" and fp ~= cur and lfs.attributes(fp, "mode") == "file" then
            fps[#fps + 1] = fp
            if #fps >= MAX_BOOKS then break end
        end
    end
    return fps
end

-- --------------------------------------------------------------------------
-- Covers and tiles
-- --------------------------------------------------------------------------

local function titleOf(fp)
    local SH = package.loaded["modules/module_books_shared"]
    if type(SH) == "table" and type(SH.getBookData) == "function" then
        local ok, bd = pcall(SH.getBookData, fp)
        if ok and type(bd) == "table" and bd.title and bd.title ~= "" then return bd.title end
    end
    return ((fp:match("([^/]+)$") or fp):gsub("%.[^.]+$", ""))
end

-- Covers already sized for the strip, kept between menu opens (up to
-- COVER_KEEP, oldest let go first): key "path|WxH" -> entry.
--   SimpleUI: its cover widget's image, kept with the resized picture it
--             drew (its own free is held off). Reused while SimpleUI still
--             hands out the same cover; a changed cover is drawn again.
--   CoverBrowser: the resized cover itself.
local COVER_KEEP = 10
local cover_kept, cover_order = {}, {}
local function keepCover(key, entry)
    if not cover_kept[key] then
        cover_order[#cover_order + 1] = key
        if #cover_order > COVER_KEEP then
            local old = table.remove(cover_order, 1)
            local e = cover_kept[old]
            cover_kept[old] = nil
            if e and e.release then pcall(e.release) end
        end
    elseif cover_kept[key].release then
        pcall(cover_kept[key].release)
    end
    cover_kept[key] = entry
end

-- A cached thumbnail only: SimpleUI's covers, else CoverBrowser's cache.
local function coverWidget(fp, w, h)
    local key = fp .. "|" .. w .. "x" .. h
    local SH = package.loaded["modules/module_books_shared"]
    if type(SH) == "table" and type(SH.getBookCover) == "function" then
        local ok, wd = pcall(SH.getBookCover, fp, w, h)
        if ok and wd then
            -- SimpleUI's frame around an image of its own cached cover
            local img = type(wd) == "table" and wd[1]
            local src = type(img) == "table" and rawget(img, "image")
            if src then
                local e = cover_kept[key]
                if e and e.src == src and e.img then
                    wd[1] = e.img -- the one already drawn at this size
                else
                    -- kept: closing or freeing the strip mustn't drop its picture
                    img.free = function() end
                    img.onCloseWidget = function() end
                    keepCover(key, { src = src, img = img, release = function()
                        img.free, img.onCloseWidget = nil, nil
                        img:free()
                    end })
                end
            end
            return wd
        end
    end
    local e = cover_kept[key]
    if e and e.scaled then
        return require("ui/widget/imagewidget"):new{ image = e.scaled, image_disposable = false,
            width = e.w, height = e.h }
    end
    local BIM = package.loaded["bookinfomanager"]
    if type(BIM) == "table" and type(BIM.getBookInfo) == "function" then
        local ok, bi = pcall(BIM.getBookInfo, BIM, fp, true)
        local bb = ok and type(bi) == "table" and bi.cover_bb
        if bb then
            local bw, bh = bb:getWidth(), bb:getHeight()
            local scale = math.min(w / bw, h / bh)
            local sw = math.max(1, math.floor(bw * scale))
            local shh = math.max(1, math.floor(bh * scale))
            local ok_s, scaled = pcall(function()
                return require("ui/renderimage"):scaleBlitBuffer(bb, sw, shh, true)
            end)
            if ok_s and scaled then
                keepCover(key, { scaled = scaled, w = sw, h = shh, release = function() scaled:free() end })
                return require("ui/widget/imagewidget"):new{ image = scaled, image_disposable = false,
                    width = sw, height = shh }
            end
        end
    end
    return nil
end

local function titleTile(fp, w, h)
    local FrameContainer = require("ui/widget/container/framecontainer")
    local CenterContainer = require("ui/widget/container/centercontainer")
    local TextBoxWidget = require("ui/widget/textboxwidget")
    local Font = require("ui/font")
    local Geom = require("ui/geometry")
    local Size = require("ui/size")
    local inner = w - 2 * (Size.border.thin + Size.padding.small)
    return FrameContainer:new{
        bordersize = Size.border.thin, padding = 0, margin = 0,
        CenterContainer:new{
            dimen = Geom:new{ w = w - 2 * Size.border.thin, h = h - 2 * Size.border.thin },
            TextBoxWidget:new{
                text = titleOf(fp), face = Font:getFace("xx_smallinfofont"),
                width = inner, alignment = "center",
                height = h - 2 * Size.border.thin, height_adjust = true,
                height_overflow_show_ellipsis = true,
            },
        },
    }
end

local function progressText(fp)
    local info = bookInfo(fp)
    local pct = info and info.been_opened and info.percent_finished
    if type(pct) == "number" and pct > 0 then
        return string.format("%d%%", math.floor(pct * 100 + 0.5))
    end
    return _("Not started")
end

local function openBook(fp)
    UIManager:nextTick(function()
        local ok, ReaderUI = pcall(require, "apps/reader/readerui")
        local ui = ok and ReaderUI.instance
        if ui and type(ui.switchDocument) == "function" then
            ui:switchDocument(fp)
        elseif ok then
            ReaderUI:showReader(fp)
        end
    end)
end

-- The strip page: same width and height as the book panel it replaces.
local function buildStrip(w, h)
    local CenterContainer = require("ui/widget/container/centercontainer")
    local HorizontalGroup = require("ui/widget/horizontalgroup")
    local HorizontalSpan = require("ui/widget/horizontalspan")
    local InputContainer = require("ui/widget/container/inputcontainer")
    local VerticalGroup = require("ui/widget/verticalgroup")
    local VerticalSpan = require("ui/widget/verticalspan")
    local TextWidget = require("ui/widget/textwidget")
    local GestureRange = require("ui/gesturerange")
    local Font = require("ui/font")
    local Geom = require("ui/geometry")
    local Size = require("ui/size")

    local src = source()
    local list = (src == "tbr") and toBeRead() or inProgress()
    local face = Font:getFace("xx_smallinfofont")

    if #list == 0 then
        return CenterContainer:new{
            dimen = Geom:new{ w = w, h = h },
            TextWidget:new{
                text = (src == "tbr") and _("To Be Read is empty")
                    or _("Nothing else in progress"),
                face = face,
            },
        }
    end

    -- Same margins as the plugin's book panel.
    local leading = Screen:scaleBySize(10) + Size.padding.default
    local top_pad = Screen:scaleBySize(12)
    local bot_pad = Screen:scaleBySize(6)
    local gap = Screen:scaleBySize(8)
    local label_gap = Screen:scaleBySize(3)
    local label_h = TextWidget:new{ text = "100%", face = face }:getSize().h

    local cover_h = math.max(Screen:scaleBySize(40), h - top_pad - bot_pad - label_gap - label_h)
    local cover_w = math.floor(cover_h * 2 / 3)
    local fit = math.floor((w - leading + gap) / (cover_w + gap))
    local count = math.max(1, math.min(#list, fit))

    local row = HorizontalGroup:new{ align = "top", HorizontalSpan:new{ width = leading } }
    for i = 1, count do
        local fp = list[i]
        local cover = coverWidget(fp, cover_w, cover_h) or titleTile(fp, cover_w, cover_h)
        local tile = InputContainer:new{
            dimen = Geom:new{ w = cover_w, h = cover_h + label_gap + label_h },
            VerticalGroup:new{
                align = "center",
                CenterContainer:new{ dimen = Geom:new{ w = cover_w, h = cover_h }, cover },
                VerticalSpan:new{ width = label_gap },
                TextWidget:new{ text = progressText(fp), face = face, max_width = cover_w },
            },
        }
        tile.ges_events = {
            TapBook = { GestureRange:new{ ges = "tap", range = function() return tile.dimen end } },
        }
        function tile:onTapBook() openBook(fp) return true end
        row[#row + 1] = tile
        if i < count then row[#row + 1] = HorizontalSpan:new{ width = gap } end
    end

    return VerticalGroup:new{
        align = "left",
        VerticalSpan:new{ width = top_pad },
        row,
    }
end

-- --------------------------------------------------------------------------
-- The pager: holds the book panel or the strip, swipes between them
-- --------------------------------------------------------------------------

local DOT_R = math.max(2, Screen:scaleBySize(2.5))
local DOT_GAP = Screen:scaleBySize(8)

local function paintDot(bb, cx, cy, filled)
    local Blitbuffer = require("ffi/blitbuffer")
    local col = Blitbuffer.COLOR_BLACK
    for dy = -DOT_R, DOT_R do
        local hw = math.floor(math.sqrt(DOT_R * DOT_R - dy * dy) + 0.5)
        if filled or math.abs(dy) == DOT_R then
            bb:paintRect(cx - hw, cy + dy, hw * 2 + 1, 1, col)
        else
            bb:paintRect(cx - hw, cy + dy, 1, 1, col)
            bb:paintRect(cx + hw, cy + dy, 1, 1, col)
        end
    end
end

-- The window holding the pager, for its redraw.
local function windowOf(widget)
    if UIManager.isSubwidgetShown then
        local ok, matched, _d, w = pcall(UIManager.isSubwidgetShown, UIManager, widget)
        if ok and matched and w then return w end
    end
    local stack = UIManager._window_stack
    if type(stack) == "table" then
        for i = #stack, 1, -1 do
            local w = stack[i].widget
            if w and not w.invisible and not w.toast then return w end
        end
    end
end

-- --------------------------------------------------------------------------
-- Critter Remarks (1.4.x): SimpleUI's Tiny Critter with a speech bubble.
--   While Reading: in the book panel's free strip, under the book's title,
--     author and page line, right of the cover.
--   On Library Toolbar: in the empty stretch of the menu's tab bar, before
--     the last tab icon (file browser only).
-- Tap the critter for another remark. Without SimpleUI 3.0's critter files
-- it's the remark alone.
-- --------------------------------------------------------------------------

local function libraryRemark()
    local hour = tonumber(os.date("%H")) or 12
    if hour < 5 then return "Late pages. The shelf can wait." end
    if hour < 12 then return "Morning. Pick something good." end
    if hour < 17 then return "Afternoon light. Good reading weather." end
    if hour < 21 then return "Evening. One more chapter?" end
    return "Night shelf. Quiet picks."
end
local LIBRARY_LINES = {
    "The shelf has ideas. Tap a cover.",
    "Morning. Pick something good.",
    "Afternoon light. Good reading weather.",
    "Evening. One more chapter?",
    "Night shelf. Quiet picks.",
    "Late pages. The shelf can wait.",
}
local _lib_i = 0
local function nextLibraryRemark()
    _lib_i = _lib_i % #LIBRARY_LINES + 1
    return LIBRARY_LINES[_lib_i]
end

local function sui(name)
    local m = package.loaded[name]
    if m ~= nil then return m end
    local ok, mod = pcall(require, name)
    return ok and mod or nil
end

-- The critter the home screen shows: SimpleUI Tweaks' Critter Mix (two or
-- more ticked: today's turn), else SimpleUI's chosen critter (one setting for
-- every screen since 3.0.2), else the home screen's own older setting.
local function critterId(Assets)
    local tw = G_reader_settings and G_reader_settings:readSetting("simpleui_mod")
    local mix = type(tw) == "table" and type(tw.critter_mix) == "table" and tw.critter_mix or nil
    if mix and #mix >= 2 then
        local turn = type(Assets.tw_turn) == "number" and Assets.tw_turn or (tonumber(os.date("%j")) or 0)
        return mix[(turn % #mix) + 1]
    end
    local CS = sui("modules/critter/settings")
    if type(CS) == "table" and type(CS.pick) == "function" then
        local ok, id = pcall(CS.pick)
        if ok and id ~= nil then return id end
    end
    local Store = sui("infra/sui_store")
    if type(Store) == "table" and type(Store.get) == "function" then
        local ok, id = pcall(Store.get, Store, "simpleui_hs_critter_pick")
        if ok then return id end
    end
end

-- --------------------------------------------------------------------------
-- Remarks (1.5.0): what the critter says. Lines live in critter-phrases.lua
-- (reading, reading_voices, menus, menu_voices, menu_words), next
-- to the patch; a few built-in ones stand in without it. Everything is
-- worked out when a remark is needed (menu open, tab change, tap): nothing
-- runs while you read.
-- --------------------------------------------------------------------------

local function builtinBank()
    local function pg(n) return string.format(n == 1 and "%d page" or "%d pages", n or 0) end
    local function c(text) return function() return text end end
    return {
        reading = {
            finished = { { mood = "party", text = c("The end! You did it."), sub = c("What's next?") } },
            finish_now = { { mood = "cheer", text = function(f) return "Only " .. pg(f.left) .. " left!" end, sub = c("Don't stop now.") } },
            chapter_last = { { mood = "curious", text = c("Last page of the chapter."), sub = c("Stop here? Or one more...") } },
            chapter_soon = { { mood = "curious", text = function(f) return pg(f.ch_left) .. " left in this chapter." end } },
            pages_left = { { mood = "reading", text = function(f) return string.format("Page %d of %d.", f.page, f.total) end,
                             sub = function(f) return pg(f.left) .. " to go." end } },
        },
        menus = { any = { { mood = "curious", text = function(f) return (f.menu or "This menu") .. "? Interesting." end } } },
    }
end

local _bank, _bank_tried
local function phraseBank()
    if _bank_tried then return _bank end
    _bank_tried = true
    local ok_ds, DS = pcall(require, "datastorage")
    local path = ok_ds and DS and DS.getDataDir and (DS:getDataDir() .. "/patches/critter-phrases.lua")
    local fn = path and lfs.attributes(path, "mode") == "file" and loadfile(path)
    if fn then
        setfenv(fn, { string = string, math = math, tostring = tostring, tonumber = tonumber,
                      type = type, ipairs = ipairs, pairs = pairs, select = select })
        local ok, b = pcall(fn)
        if ok and type(b) == "table" and type(b.reading) == "table" then
            _bank = b
        else
            logger.warn("shortcutstoolbar quick shelf: critter-phrases.lua",
                ok and "has no reading lines (needs 1.1.0+), using built-in lines" or tostring(b))
        end
    end
    _bank = _bank or builtinBank()
    return _bank
end

local function readerUI()
    local ok, ReaderUI = pcall(require, "apps/reader/readerui")
    local ui = ok and ReaderUI.instance
    return ui and ui.document and ui or nil
end

-- The name you gave SimpleUI's critter (its settings: Your name), or nil.
local function userName()
    local CS = sui("modules/critter/settings")
    if type(CS) == "table" and type(CS.userName) == "function" then
        local ok, name = pcall(CS.userName)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
end

-- This sitting: KOReader's statistics start a new period on every wake.
local _sess = {}
local function readingFacts()
    local ui = readerUI()
    if not ui then return nil end
    local doc = ui.document
    local okp, page = pcall(ui.getCurrentPage, ui)
    local okt, total = pcall(doc.getPageCount, doc)
    page, total = okp and tonumber(page), okt and tonumber(total)
    if not page or not total or total < 1 then return nil end
    local f = { page = page, total = total, hour = tonumber(os.date("%H")) or 12, user_name = userName() }
    f.left = math.max(0, total - page)
    f.pct = f.left == 0 and 100 or math.min(99, math.floor(page / total * 100 + 0.5))
    f.title = titleOf(doc.file)
    f.book = { title = f.title }
    local toc = ui.toc
    if type(toc) == "table" and type(toc.getChapterPagesLeft) == "function" then
        local ok, cl = pcall(toc.getChapterPagesLeft, toc, page, true)
        if ok and type(cl) == "number" and cl >= 0 then f.ch_left = cl end
        if f.ch_left and type(toc.getTocTitleByPage) == "function" then
            local okc, ct = pcall(toc.getTocTitleByPage, toc, page)
            if okc and type(ct) == "string" and ct ~= "" then
                f.chapter = #ct > 24 and (ct:sub(1, 23):gsub("[\192-\255][\128-\191]*$", "") .. "…") or ct
            end
        end
    end
    local st = ui.statistics
    if type(st) == "table" and type(st.settings) == "table" and st.settings.is_enabled then
        local flushed_p, flushed_s = tonumber(st.book_read_pages) or 0, tonumber(st.book_read_time) or 0
        local pages = flushed_p + (tonumber(st.mem_read_pages) or 0)
        local secs = flushed_s + (tonumber(st.mem_read_time) or 0)
        if pages >= 5 and secs > 0 then
            f.secs_page = secs / pages
            f.pph = 3600 / f.secs_page
            f.book_mins = f.left * f.secs_page / 60
            if f.ch_left then f.ch_mins = (f.ch_left + 1) * f.secs_page / 60 end
        end
        if secs > 0 then f.read_mins = secs / 60 end
        local period = tonumber(st.start_current_period)
        if period and period > 0 then
            if _sess.file ~= doc.file or _sess.period ~= period then
                _sess = { file = doc.file, period = period, pages = flushed_p, secs = flushed_s }
            end
            f.sess_pages = math.max(0, pages - _sess.pages)
            f.sess_mins = math.max(0, (os.time() - period) / 60)
            local read = secs - _sess.secs
            if f.sess_pages >= 3 and read >= 60 then f.sess_pph = f.sess_pages * 3600 / read end
        end
    end
    return f
end

-- { situation, weight, when }: the timelier, the heavier.
local SITUATIONS = {
    { "finished",       6, function(f) return f.left == 0 end },
    { "finish_now",     5, function(f) return f.left > 0 and f.left <= 10 end },
    { "finish_tonight", 4, function(f) return f.left > 10 and f.book_mins and f.book_mins <= 60 end },
    { "chapter_last",   4, function(f) return f.ch_left == 0 and f.left > 0 end },
    { "chapter_soon",   3, function(f) return f.ch_left and f.ch_left >= 1 and f.ch_left <= 3 end },
    { "chapter_quick",  2, function(f) return f.ch_left and f.ch_left > 3 and f.ch_mins and f.ch_mins <= 10 end },
    { "chapter_long",   2, function(f) return f.ch_mins and f.ch_mins >= 45 end },
    { "fast",           4, function(f) return f.sess_pph and f.pph and f.sess_pages >= 5 and f.sess_pph >= f.pph * 1.35 end },
    { "slow",           3, function(f) return f.sess_pph and f.pph and f.sess_mins >= 10 and f.sess_pph <= f.pph * 0.6 end },
    { "steady",         1, function(f) return f.sess_pph and f.pph and f.sess_pages >= 5
                                              and f.sess_pph > f.pph * 0.6 and f.sess_pph < f.pph * 1.35 end },
    { "marathon",       4, function(f) return f.sess_mins and f.sess_mins >= 60 end },
    { "big_session",    3, function(f) return f.sess_pages and f.sess_pages >= 50 end },
    { "just_opened",    2, function(f) return f.sess_mins and f.sess_mins <= 3 and (f.sess_pages or 0) <= 1 and f.left > 0 end },
    { "late_night",     2, function(f) return f.hour >= 23 or f.hour < 4 end },
    { "early",          2, function(f) return f.hour >= 5 and f.hour < 8 end },
    { "start",          2, function(f) return f.pct < 5 and f.left > 0 end },
    { "quarter",        3, function(f) return f.pct >= 24 and f.pct <= 27 end },
    { "halfway",        4, function(f) return f.pct >= 48 and f.pct <= 53 end },
    { "three_quarter",  3, function(f) return f.pct >= 74 and f.pct <= 77 end },
    { "home_stretch",   3, function(f) return f.pct >= 85 and f.left > 10 end },
    { "big_book",       1, function(f) return f.total >= 600 and f.left > 0 end },
    { "short_book",     1, function(f) return f.total <= 150 and f.left > 0 end },
    { "speedy",         1, function(f) return f.secs_page and f.secs_page <= 40 end },
    { "unhurried",      1, function(f) return f.secs_page and f.secs_page >= 150 end },
    { "invested",       1, function(f) return f.read_mins and f.read_mins >= 600 end },
    { "pages_left",     1, function(f) return f.left > 0 end },
    { "time_left",      1, function(f) return f.book_mins and f.book_mins > 60 end },
    { "sweet",          2, function(f) return true end },
}

local _seeded
local function rnd(n)
    if not _seeded then _seeded = true math.randomseed(os.time()) end
    return n and math.random(n) or math.random()
end

-- A list's lines, without the ones that use {name} when there's no name,
-- or {menu} when the menu has no name to show.
local function listOr(t, named, has_menu)
    if type(t) ~= "table" or #t == 0 then return nil end
    if named and has_menu ~= false then return t end
    local out
    for i, l in ipairs(t) do
        if type(l) == "table" and ((l.needs_name and not named) or (l.needs_menu and has_menu == false)) then
            if not out then
                out = {}
                for j = 1, i - 1 do out[j] = t[j] end
            end
        elseif out then
            out[#out + 1] = l
        end
    end
    if not out then return t end
    return #out > 0 and out or nil
end
local function linesFor(group, voices, key, cid, named, has_menu)
    local shared = listOr(type(group) == "table" and group[key], named, has_menu)
    local own = cid and type(voices) == "table" and type(voices[cid]) == "table" and listOr(voices[cid][key], named, has_menu) or nil
    return shared, own
end

local _last_line, _last_sit
local function pickLine(shared, own)
    local list = shared
    if own and (not shared or rnd() < 0.5) then list = own end
    if not list then return nil end
    local i = rnd(#list)
    if list[i] == _last_line and #list > 1 then i = i % #list + 1 end
    if list[i] == _last_line then
        -- a one-line list said it last time: the other list, if there is one
        local other = (list == own) and shared or own
        if other then
            list = other
            i = rnd(#list)
            if list[i] == _last_line and #list > 1 then i = i % #list + 1 end
        end
    end
    return list[i]
end

local function render(line, f)
    if type(line) ~= "table" or type(line.text) ~= "function" then return nil end
    local ok, text = pcall(line.text, f)
    if not ok or type(text) ~= "string" or text == "" then return nil end
    local sub
    if type(line.sub) == "function" then
        local ok2, s2 = pcall(line.sub, f)
        if ok2 and type(s2) == "string" and s2 ~= "" then sub = s2 end
    end
    _last_line = line
    return { text = text, sub = sub, mood = type(line.mood) == "string" and line.mood or "happy" }
end

local function critterNow()
    local Assets = sui("modules/critter/assets")
    if type(Assets) ~= "table" then return nil end
    local ok, id = pcall(critterId, Assets)
    return ok and id or nil
end

-- A remark about the open book, or nil (no book).
local function readingRemark()
    local f = readingFacts()
    if not f then return nil end
    local b, cid = phraseBank(), critterNow()
    local pool, total = {}, 0
    for _, s in ipairs(SITUATIONS) do
        local ok, yes = pcall(s[3], f)
        if ok and yes then
            local shared, own = linesFor(b.reading, b.reading_voices, s[1], cid, f.user_name ~= nil)
            if shared or own then
                local w = (s[1] == _last_sit) and 0 or s[2]
                pool[#pool + 1] = { s[1], w, shared, own }
                total = total + w
            end
        end
    end
    if #pool == 0 then return nil end
    if total == 0 then
        for _, p in ipairs(pool) do p[2] = 1 end
        total = #pool
    end
    local r = rnd() * total
    local pick = pool[#pool]
    for _, p in ipairs(pool) do
        r = r - p[2]
        if r <= 0 then pick = p break end
    end
    _last_sit = pick[1]
    return render(pickLine(pick[3], pick[4]), f)
end

-- The open menu: tab, depth and the submenu names, deepest first.
local TAB_KEYS = {
    ["appbar.navigation"] = "tab_navigation", ["appbar.typeset"] = "tab_typeset",
    ["appbar.settings"] = "tab_settings", ["appbar.tools"] = "tab_tools",
    ["appbar.search"] = "tab_search", ["appbar.filebrowser"] = "tab_files",
    ["appbar.menu"] = "tab_main",
}
-- KOReader's own ids for the tabs (set by its menu sorter, also with a menu
-- customizer's order), for when an icon was swapped for a custom one.
local TAB_IDS = {
    navi = "tab_navigation", typeset = "tab_typeset", setting = "tab_settings",
    tools = "tab_tools", search = "tab_search", filemanager = "tab_files", main = "tab_main",
}
local TAB_WORDS = { navigation = "tab_navigation", typeset = "tab_typeset", setting = "tab_settings",
    tools = "tab_tools", search = "tab_search", filebrowser = "tab_files", menu = "tab_main" }
local function tabKey(menu, tab, ti)
    if type(ti) == "table" then
        if TAB_KEYS[ti.icon] then return TAB_KEYS[ti.icon] end
        if TAB_IDS[ti.id] then return TAB_IDS[ti.id] end
    end
    local icons = type(menu.bar) == "table" and menu.bar.icon_widgets
    local iw = type(icons) == "table" and icons[tab]
    for i = 1, 2 do
        local nm
        if i == 1 then nm = type(ti) == "table" and ti.icon else nm = type(iw) == "table" and iw.icon end
        if type(nm) == "string" then
            if TAB_KEYS[nm] then return TAB_KEYS[nm] end
            local low = nm:lower()
            for w, k in pairs(TAB_WORDS) do
                if low:find(w, 1, true) then return k end
            end
        end
    end
end
local function menuContext(menu)
    local tab = type(menu) == "table" and tonumber(menu.cur_tab)
    if not tab or tab < 1 then return "home" end
    local ti = type(menu.tab_item_table) == "table" and menu.tab_item_table[tab]
    local tabkey = tabKey(menu, tab, ti)
    -- the submenus opened, deepest first: KOReader's own record (newer
    -- versions), else the one hookMenuBar keeps (2025.10 has none)
    local depth = type(menu.item_table_stack) == "table" and #menu.item_table_stack or 0
    local ps, names = menu.path_stack, {}
    if type(ps) ~= "table" or #ps == 0 then ps = menu._qs_path end
    if type(ps) == "table" then
        for i = math.min(depth, #ps), 1, -1 do
            local e = ps[i]
            local tx = type(e) == "table" and e.text or e
            if type(tx) == "string" and tx ~= "" then names[#names + 1] = tx end
        end
    end
    return tab .. ":" .. depth .. ":" .. (names[1] or ""), tabkey, names
end

local function shortName(s)
    s = tostring(s):gsub("[\r\n].*$", ""):gsub("%s*:.*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if #s > 22 then s = s:sub(1, 21):gsub("[\192-\255][\128-\191]*$", "") .. "…" end
    return s
end

-- A remark about the open menu (library).
local function menuRemark(tabkey, names)
    local b, cid = phraseBank(), critterNow()
    local key, name = nil, nil
    local words = type(b.menu_words) == "table" and b.menu_words or {}
    for _, nm in ipairs(names) do
        local low = nm:lower()
        for _, e in ipairs(words) do
            if type(e) == "table" and type(e.key) == "string" and type(e.words) == "table" then
                for _, w in ipairs(e.words) do
                    if type(w) == "string" and w ~= "" and low:find(w, 1, true) then key, name = e.key, nm break end
                end
            end
            if key then break end
        end
        if key then break end
    end
    if not key then
        if names[1] then key, name = "any", names[1] else key = tabkey or "any" end
    end
    local f = { user_name = userName() }
    local named, has_menu = f.user_name ~= nil, name ~= nil
    local shared, own = linesFor(b.menus, b.menu_voices, key, cid, named, has_menu)
    if not (shared or own) and key ~= "any" then shared, own = linesFor(b.menus, b.menu_voices, "any", cid, named, has_menu) end
    if not (shared or own) then return nil end
    f.menu = name and shortName(name) or nil
    local rem = render(pickLine(shared, own), f)
    local dbg = package.loaded["quick_shelf_critter_debug"]
    if type(dbg) == "function" then
        pcall(dbg, { names = names, tabkey = tabkey, key = key, critter = cid,
                     text = rem and rem.text, has_bank = b.VERSION or "built-in" })
    end
    return rem
end

-- Bubble faces like SimpleUI's critter, else KOReader's small fonts.
local function bubbleFaces(scale)
    local ok, mf, mb, df, db = pcall(function()
        local Config, Style = sui("infra/sui_config"), sui("features/sui_style")
        local styles = Config.resolveTextStyles(nil, "critter", { "message", "detail" })
        local a, ab = Style.getTextFace(styles.message, math.max(8, math.floor(Style.FS_BODY * scale * styles.message.scale)))
        local b, bb = Style.getTextFace(styles.detail, math.max(7, math.floor(Style.FS_DETAIL * scale * styles.detail.scale)))
        return a, ab, b, bb
    end)
    if ok and mf and df then return mf, mb, df, db end
    local Font = require("ui/font")
    return Font:getFace("cfont", math.floor(18 * scale)), true, Font:getFace("cfont", math.floor(15 * scale)), false
end

-- The critter (right) and its bubble (left) in at most max_w x h, or the
-- remark alone without SimpleUI's critter. nil when there's no room.
-- Does the second line fit the bubble too (main and second line, 2 rows
-- each, inside its height)? Without SimpleUI's text helpers: tall rows only.
local function detailFits(Bubble, o)
    local UI = sui("infra/sui_core")
    if type(Bubble.metrics) ~= "function" or type(UI) ~= "table" or type(UI.makeTextBox) ~= "function" then
        return o.h >= Screen:scaleBySize(52)
    end
    local ok, res = pcall(function()
        local _b, _p, reach, frame = Bubble.metrics(o.scale, true, o.style, o.unit)
        local tw = o.w - reach - frame
        if tw <= 20 then return false end
        local function hgt(face, bold, text)
            local box = UI.makeTextBox{ text = text, face = face, bold = bold, width = tw }
            local hh = box:getSize().h
            if box.free then box:free() end
            return hh
        end
        local mh, ml = hgt(o.msg_face, o.msg_bold, o.message), hgt(o.msg_face, o.msg_bold, "Xg")
        local dh, dl = hgt(o.det_face, o.det_bold, o.detail), hgt(o.det_face, o.det_bold, "Xg")
        if mh > 2 * ml + 1 or dh > 2 * dl + 1 then return false end
        return mh + dh + frame + math.floor(Screen:scaleBySize(2) * (o.scale or 1)) <= o.h
    end)
    return ok and res == true
end

-- Donny and Blu's extra poses; another critter shows the one they're drawn from.
local BASE_MOOD = { reading = "neutral", proud = "cheer", hungry = "curious", cozy = "sleepy",
    dreamy = "sleepy", sipping = "happy", festive = "happy", spooky = "surprised" }

local function critterGroup(message, mood, max_w, h, detail)
    local HorizontalGroup = require("ui/widget/horizontalgroup")
    local HorizontalSpan = require("ui/widget/horizontalspan")
    local Sprite, Bubble, Assets = sui("modules/critter/sprite"), sui("modules/critter/bubble"), sui("modules/critter/assets")
    local CS = sui("modules/critter/settings")
    if type(Sprite) == "table" and type(Bubble) == "table" and type(Assets) == "table"
            and type(Bubble.build) == "function" and type(Assets.get) == "function" then
        local ok, group = pcall(function()
            local want = critterId(Assets)
            local entry = Assets.get(want)
            -- Critter Mix already swaps Assets.get once SimpleUI Tweaks hooked it;
            -- otherwise ask for the one we want by name
            if type(entry) == "table" and want and entry.id ~= want and type(Assets.list) == "function" then
                for _i, e in ipairs(Assets.list()) do
                    if e.id == want then entry = e break end
                end
            end
            local path = entry and (Assets.imagePath(entry, mood)
                or (BASE_MOOD[mood] and Assets.imagePath(entry, BASE_MOOD[mood]))
                or Assets.imagePath(entry, "happy"))
            if not path then return nil end
            local sprite = Sprite:new{ path = path, max_w = math.floor(max_w * 0.35), max_h = h }
            if not (sprite.dimen and sprite.dimen.w > 0) then return nil end
            local style = (type(CS) == "table" and type(CS.bubbleStyle) == "function") and CS.bubbleStyle() or "pixel"
            if style ~= "smooth" then style = "pixel" end
            local unit = sprite.pixel or math.max(1, Screen:scaleBySize(2))
            local scale = math.max(0.6, math.min(1, h / Screen:scaleBySize(56)))
            local gap = Screen:scaleBySize(4)
            local bw = max_w - sprite.dimen.w - gap
            local mf, mb, df, db = bubbleFaces(scale)
            local o = {
                w = bw, h = h, side = "right", message = message,
                msg_face = mf, msg_bold = mb, det_face = df, det_bold = db,
                scale = scale, style = style, unit = unit,
            }
            if detail and bw > 0 then
                o.detail = detail
                if not detailFits(Bubble, o) then o.detail = nil end
            end
            local bubble = bw > 0 and Bubble.build(o) or nil
            local g = HorizontalGroup:new{ align = "bottom" }
            if bubble then
                g[#g + 1] = bubble
                g[#g + 1] = HorizontalSpan:new{ width = gap }
            end
            g[#g + 1] = sprite
            return g
        end)
        if ok and group then return group end
        if not ok then logger.warn("shortcutstoolbar quick shelf: critter failed:", group) end
    end
    -- no critter files: the remark alone
    local TextBoxWidget = require("ui/widget/textboxwidget")
    local Font = require("ui/font")
    local face = Font:getFace("xx_smallinfofont")
    local tb = TextBoxWidget:new{ text = detail and (message .. "\n" .. detail) or message, face = face, width = max_w, alignment = "right",
        height = h, height_adjust = true, height_overflow_show_ellipsis = true }
    return tb
end

-- The book panel's free strip, relative to the panel: under its title /
-- author / page lines (the meta column), right of the cover, above the dots.
local function panelStrip(panel, w, h)
    local padded = type(panel) == "table" and panel[1]
    local row = type(padded) == "table" and padded[2]
    if type(row) ~= "table" or #row < 1 then return nil end
    local meta = row[#row]
    if type(meta) ~= "table" or type(meta.getSize) ~= "function" then return nil end
    local x0 = 0
    for i = 1, #row - 1 do
        local c = row[i]
        x0 = x0 + ((type(c) == "table" and c.getSize) and c:getSize().w or 0)
    end
    local top = ((padded[1] and padded[1].width) or 0) + meta:getSize().h + Screen:scaleBySize(4)
    local bottom = h - 2 * DOT_R - Screen:scaleBySize(4)
    local sw = w - x0 - Screen:scaleBySize(8)
    local sh = bottom - top
    if sw < Screen:scaleBySize(80) or sh < Screen:scaleBySize(24) then return nil end
    return { x = x0, y = top, w = sw, h = sh }
end

-- The library menu's tab bar (On Library Toolbar): the critter in the
-- stretch before the last tab icon. It notices the tab and submenu you open
-- and says something about it; on the toolbar's home view, a remark for the
-- time of day. Not in the reader.
local function hookMenuBar()
    local ok, TouchMenu = pcall(require, "ui/widget/touchmenu")
    if not ok or type(TouchMenu) ~= "table" or TouchMenu.__qs_critter then return end
    TouchMenu.__qs_critter = true
    local GestureRange = require("ui/gesturerange")
    local Geom = require("ui/geometry")
    -- Which submenus you opened (by name), for menuContext.
    local orig_select = TouchMenu.onMenuSelect
    if type(orig_select) == "function" then
        TouchMenu.onMenuSelect = function(m, item, ...)
            local before = type(m.item_table_stack) == "table" and #m.item_table_stack or 0
            local res = orig_select(m, item, ...)
            local after = type(m.item_table_stack) == "table" and #m.item_table_stack or 0
            if after > before and type(item) == "table" then
                local text = item.text
                if type(item.text_func) == "function" then
                    local ok_t, tf = pcall(item.text_func)
                    if ok_t and type(tf) == "string" then text = tf end
                end
                m._qs_path = m._qs_path or {}
                m._qs_path[after] = type(text) == "string" and text or ""
                for i = after + 1, #m._qs_path do m._qs_path[i] = nil end
            end
            return res
        end
    end
    local orig_init = TouchMenu.init
    TouchMenu.init = function(self, ...)
        orig_init(self, ...)
        local menu, bar = self, self.bar
        if type(bar) ~= "table" or type(bar.paintTo) ~= "function" then return end
        local bar_paint = bar.paintTo
        local crit, rem, kind, sig
        local function drop()
            if crit and crit.free then pcall(crit.free, crit) end
            crit = nil
        end
        local function remarkFor(ctx_sig, tabkey, names)
            if ctx_sig == "home" then
                return { text = rem and kind == "home" and nextLibraryRemark() or libraryRemark(), mood = "happy" }, "home"
            end
            return menuRemark(tabkey, names), "menu"
        end
        bar.paintTo = function(b, bb, x, y)
            bar_paint(b, bb, x, y)
            b._qs_crit_geom = nil
            if currentFile() or not opt("critter_on_library", false) then return end
            local ctx_sig, tabkey, names = menuContext(menu)
            local icons = b.icon_widgets
            local n = type(icons) == "table" and #icons or 0
            if n < 2 or not (icons[n - 1].dimen and icons[n].dimen and icons[n].dimen.x) then return end
            local left = icons[n - 1].dimen.x + icons[n - 1].dimen.w + Screen:scaleBySize(8)
            local right = icons[n].dimen.x - Screen:scaleBySize(8)
            local h = icons[n].dimen.h
            if right - left < Screen:scaleBySize(120) or not h or h <= 0 then return end
            b._qs_stretch = Geom:new{ x = left, y = icons[n].dimen.y, w = right - left, h = h }
            if ctx_sig ~= sig then
                sig = ctx_sig
                drop()
                rem, kind = remarkFor(ctx_sig, tabkey, names)
            end
            if not rem then return end
            if not crit then crit = critterGroup(rem.text, rem.mood, right - left, h, rem.sub) end
            if not crit then return end
            local cs = crit:getSize()
            local cx, cy = right - cs.w, icons[n].dimen.y + math.floor((h - cs.h) / 2)
            crit:paintTo(bb, cx, cy)
            b._qs_crit_geom = Geom:new{ x = cx, y = cy, w = cs.w, h = cs.h }
        end
        bar.ges_events = bar.ges_events or {}
        bar.ges_events.TapQSCritter = { GestureRange:new{ ges = "tap", range = function()
            return bar._qs_crit_geom or Geom:new{ x = -1, y = -1, w = 0, h = 0 }
        end } }
        -- Tap: another line.
        function bar:onTapQSCritter()
            if not self._qs_crit_geom then return false end
            local ctx_sig, tabkey, names = menuContext(menu)
            local r, k = remarkFor(ctx_sig, tabkey, names)
            if r then rem, kind, sig = r, k, ctx_sig end
            drop()
            local d = self._qs_stretch or self._qs_crit_geom
            UIManager:setDirty(self.show_parent or menu.show_parent or menu, function() return "ui", d, true end)
            return true
        end
        local bar_free = bar.free
        bar.free = function(b, ...)
            drop()
            if bar_free then return bar_free(b, ...) end
        end
    end
end

local function makePager(panel, avail_w)
    local InputContainer = require("ui/widget/container/inputcontainer")
    local GestureRange = require("ui/gesturerange")
    local Geom = require("ui/geometry")
    local BD = require("ui/bidi")

    local sz = panel:getSize()
    local w, h = math.max(sz.w, avail_w or 0), sz.h
    local pager = InputContainer:new{ dimen = Geom:new{ w = w, h = h }, panel }
    pager.page = 1
    pager.pages = { panel }

    pager.ges_events = {
        SwipePager = { GestureRange:new{ ges = "swipe", range = function() return pager.dimen end } },
        TapPager = { GestureRange:new{ ges = "tap", range = function() return pager.dimen end } },
        HoldPager = { GestureRange:new{ ges = "hold", range = function() return pager.dimen end } },
    }
    -- When on the book panel page, forward tap/hold so BookOrbit This Book works
    function pager:onTapPager(arg, ges)
        if self.page ~= 1 then return false end
        -- the critter: another remark
        local g, pos = self._qs_crit_geom, ges and ges.pos
        if g and pos and pos.x >= g.x and pos.x <= g.x + g.w and pos.y >= g.y and pos.y <= g.y + g.h then
            self._qs_rem = readingRemark() or self._qs_rem
            if self._qs_crit and self._qs_crit.free then pcall(self._qs_crit.free, self._qs_crit) end
            self._qs_crit = nil
            local win = windowOf(self)
            if win then
                local d = self.dimen
                UIManager:setDirty(win, function() return "ui", d, true end)
            end
            return true
        end
        local p = self.pages[1]
        if type(p) == "table" then
            if opt("tap_bookorbit", false) and openThisBook() then return true end
            if type(p.onTap) == "function" then return p:onTap(arg, ges) end
            for _, n in ipairs({ "onTapBookInfo", "onTapPanel", "onTapTitle" }) do
                if type(p[n]) == "function" then return p[n](p, arg, ges) end
            end
        end
        if opt("tap_bookorbit", false) and openThisBook() then return true end
        showBookDetails()
        return true
    end
    function pager:onHoldPager(...)
        if self.page ~= 1 then return false end
        local p = self.pages[1]
        if type(p) == "table" and type(p.onHoldBookPanel) == "function" then
            return p:onHoldBookPanel(...)
        end
        if opt("tap_bookorbit", false) and opt("hold_details", true) then
            showBookDetails()
            return true
        end
        return false
    end
    function pager:onSwipePager(_arg, ges)
        local dir = ges and BD.flipDirectionIfMirroredUILayout(ges.direction)
        -- Left or right both go to the other page (two pages: it loops).
        -- Up/down stay the menu's: swipe up closes it, and opening the menu
        -- by swiping down ends with a down-swipe that would flip the page.
        if dir ~= "west" and dir ~= "east" then return false end
        local want = (self.page == 1) and 2 or 1
        if want == 2 and not self.pages[2] then
            local ok, strip = pcall(buildStrip, w, h)
            if not ok then
                logger.warn("shortcutstoolbar quick shelf:", strip)
                return true
            end
            self.pages[2] = strip
        end
        self.page = want
        self[1] = self.pages[want]
        -- "flashui": one quick flash of just this row, so the previous page
        -- leaves no ghost (a plain "ui" refresh skips the flash, and on
        -- colour e-ink the old covers/text linger). Dithered for the covers.
        local win = windowOf(self)
        if win then
            local d = self.dimen
            UIManager:setDirty(win, function() return "flashui", d, true end)
        end
        return true
    end

    -- On suspend the shelf dismisses: the menu wakes on the book panel,
    -- not the strip. (Nothing is consumed: the event keeps propagating.)
    function pager:onSuspend()
        if self.page ~= 1 then
            self.page = 1
            self[1] = self.pages[1]
        end
    end

    -- Two dots, bottom centre, in the panel's bottom padding.
    local base_paint = pager.paintTo
    pager.paintTo = function(self, bb, x, y)
        base_paint(self, bb, x, y)
        self._qs_crit_geom = nil
        if self.page == 1 and opt("critter_on_panel", false) then
            if self._qs_strip == nil then self._qs_strip = panelStrip(panel, w, h) or false end
            local st = self._qs_strip
            if st and not self._qs_crit then
                self._qs_rem = self._qs_rem or readingRemark() or { text = "Happy reading.", mood = "reading" }
                local r = self._qs_rem
                self._qs_crit = critterGroup(r.text, r.mood, st.w, st.h, r.sub)
            end
            if st and self._qs_crit then
                local cs = self._qs_crit:getSize()
                local cx, cy = x + st.x + st.w - cs.w, y + st.y + st.h - cs.h
                self._qs_crit:paintTo(bb, cx, cy)
                self._qs_crit_geom = { x = cx, y = cy, w = cs.w, h = cs.h }
            end
        end
        local cx = x + math.floor(w / 2)
        local cy = y + h - DOT_R - 1
        paintDot(bb, cx - DOT_GAP / 2 - DOT_R, cy, self.page == 1)
        paintDot(bb, cx + DOT_GAP / 2 + DOT_R, cy, self.page == 2)
    end

    -- The strip's cover images are freed with the menu, like the panel.
    local base_free = pager.free
    pager.free = function(self, ...)
        if self._qs_crit and self._qs_crit.free then pcall(self._qs_crit.free, self._qs_crit) end
        self._qs_crit = nil
        for i, p in ipairs(self.pages) do
            if p ~= self[1] and p.free then pcall(p.free, p) end
            self.pages[i] = nil
        end
        if base_free then return base_free(self, ...) end
    end

    return pager
end

-- --------------------------------------------------------------------------
-- Book panel tap and hold (1.3.0)
-- --------------------------------------------------------------------------

-- The open book's BookOrbit plugin, when it's there.
local function bookOrbit()
    local RUI = package.loaded["apps/reader/readerui"]
    local ui = type(RUI) == "table" and RUI.instance
    if type(ui) ~= "table" then return nil end
    for _, key in ipairs({ "bookorbit", "BookOrbit" }) do
        local bo = ui[key]
        if type(bo) == "table" and (
                type(bo.onBookOrbitThisBook) == "function"
                or type(bo.openBookSheet) == "function") then
            return bo
        end
    end
    -- Last resort: scan ui plugins
    for _k, v in pairs(ui) do
        if type(v) == "table" and type(v.onBookOrbitThisBook) == "function" then
            return v
        end
    end
    return nil
end

showBookDetails = function()
    local Event = require("ui/event")
    UIManager:broadcastEvent(Event:new("ShowBookStatus"))
end

-- BookOrbit's This book sheet (it asks you to sign in when you're not).
-- Returns false when BookOrbit isn't installed, so the tap falls back.
openThisBook = function()
    local bo = bookOrbit()
    if bo then
        if type(bo.onBookOrbitThisBook) == "function" then
            local ok, err = pcall(bo.onBookOrbitThisBook, bo)
            if ok then return true end
            logger.warn("shortcutstoolbar quick shelf: onBookOrbitThisBook failed:", err)
        end
        if type(bo.openBookSheet) == "function" then
            local ok, err = pcall(bo.openBookSheet, bo)
            if ok then return true end
            logger.warn("shortcutstoolbar quick shelf: openBookSheet failed:", err)
        end
    end
    -- Dispatcher / event paths (same as the registered gesture action)
    local ok_d, Dispatcher = pcall(require, "dispatcher")
    if ok_d and type(Dispatcher) == "table" and type(Dispatcher.execute) == "function" then
        local ok = pcall(Dispatcher.execute, Dispatcher, "bookorbit_this_book")
        if ok then return true end
    end
    local ok_ev, Event = pcall(require, "ui/event")
    if ok_ev then
        local ok = pcall(function()
            UIManager:sendEvent(Event:new("BookOrbitThisBook"))
        end)
        if ok then return true end
    end
    logger.warn("shortcutstoolbar quick shelf: BookOrbit This book unavailable")
    return false
end

-- The plugin's panel is an InputContainer whose tap shows the book details.
-- With the option on, the tap opens BookOrbit's This book instead, and a
-- long-press (Hold Opens Book Details) still shows the details.
local function wireTaps(panel)
    if type(panel) ~= "table" or type(panel.ges_events) ~= "table" or panel.__qs_taps then return end
    panel.__qs_taps = true
    local GestureRange = require("ui/gesturerange")
    -- Hook every common tap handler name the stock panel may use
    local function handleTap(...)
        if opt("tap_bookorbit", false) and openThisBook() then return true end
        return nil -- fall through
    end
    for _, name in ipairs({ "onTap", "onTapBookInfo", "onTapPanel", "onTapTitle" }) do
        local orig = panel[name]
        if type(orig) == "function" or name == "onTap" then
            panel[name] = function(self, ...)
                local handled = handleTap(...)
                if handled then return true end
                if type(orig) == "function" then return orig(self, ...) end
                if name == "onTap" then
                    showBookDetails()
                    return true
                end
            end
        end
    end
    -- Ensure a Tap gesture range exists so InputContainer dispatches
    if not panel.ges_events.Tap and not panel.ges_events.TapBookInfo then
        panel.ges_events.Tap = { GestureRange:new{ ges = "tap", range = function() return panel.dimen end } }
    end
    panel.ges_events.HoldBookPanel = { GestureRange:new{ ges = "hold", range = function() return panel.dimen end } }
    function panel:onHoldBookPanel()
        if not opt("tap_bookorbit", false) then return false end
        if opt("hold_details", true) then
            showBookDetails()
            return true
        end
        return false
    end
end

-- --------------------------------------------------------------------------
-- Hook: wrap the plugin's book panel builder (reader toolbar only)
-- --------------------------------------------------------------------------

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

-- The plugin's own createHomeContent, wherever it sits behind wrappers
-- (e.g. icon tweaks): the function holding the "createBookInfoPanel" upvalue.
local function findBuilder(fn, depth, seen)
    if type(fn) ~= "function" or depth > 4 or seen[fn] then return nil end
    seen[fn] = true
    local idx = findUpvalue(fn, "createBookInfoPanel")
    if idx then return fn, idx end
    local i = 1
    while true do
        local n, v = debug.getupvalue(fn, i)
        if not n then return nil end
        if type(v) == "function" then
            local f, j = findBuilder(v, depth + 1, seen)
            if f then return f, j end
        end
        i = i + 1
    end
end


local function hookPanel()
    local ok, HC = pcall(require, "home_content")
    if not ok or type(HC) ~= "table" or HC.__stb_quick_shelf then return end
    local builder, idx = findBuilder(HC.createHomeContent, 0, {})
    if not builder then
        logger.warn("shortcutstoolbar quick shelf: book panel not found (plugin changed?), not active")
        return
    end
    HC.__stb_quick_shelf = true
    HC.__stb_recent_books = true -- an old 2-shortcutstoolbar-recent-books.lua still installed then does nothing
    local _n, orig_panel = debug.getupvalue(builder, idx)
    debug.setupvalue(builder, idx, function(avail_w, ...)
        local panel = orig_panel(avail_w, ...)
        if not panel then return panel end
        pcall(wireTaps, panel)
        local ok_p, pager = pcall(makePager, panel, avail_w)
        if ok_p then return pager end
        logger.warn("shortcutstoolbar quick shelf:", pager)
        return panel
    end)

    -- Library: the critter sits in the menu's tab bar (hookMenuBar).
    hookMenuBar()
end

-- --------------------------------------------------------------------------
-- Menu: Shortcuts toolbar → Quick Shelf Shows
-- --------------------------------------------------------------------------

local function menuItem()
    local T = require("ffi/util").template
    local items = {}
    for _i, s in ipairs(SOURCES) do
        items[#items + 1] = {
            text = s.text,
            radio = true,
            checked_func = function() return source() == s.id end,
            callback = function() setSource(s.id) end,
        }
    end
    return {
        text_func = function()
            local cur = source()
            for _i, s in ipairs(SOURCES) do
                if s.id == cur then return T(_("Quick Shelf Shows: %1"), s.text) end
            end
        end,
        help_text = _("Quick Shelf: in the reader, swipe left or right on the toolbar's top row to flip between the book panel and the Quick Shelf."),
        sub_item_table = items,
    }
end

local function critterMenuItem()
    return {
        text = _("Critter Remarks"),
        help_text = _("Optional short lines from the critter on the Shortcuts Toolbar. Not on the swipe Quick Shelf strip."),
        sub_item_table = {
            {
                text = _("While Reading"),
                help_text = _("When you pull the toolbar down while reading: SimpleUI's critter and a speech bubble about this book in the book panel, under its title, author and page line. It goes by what's happening: pages and time left, the chapter ending, your pace this sitting against your usual, long or late sessions, milestones. Your critter's own voice when it has lines for it (Donny, Blu). Pace remarks need KOReader's reading statistics on. Tap the critter for another remark. Off by default."),
                checked_func = function() return opt("critter_on_panel", false) == true end,
                callback = function() setOpt("critter_on_panel", not opt("critter_on_panel", false)) end,
            },
            {
                text = _("On Library Toolbar"),
                help_text = _("In the file browser: the critter in the empty stretch of the menu's tab bar, before the last tab icon. A remark for the time of day, and about the tab and submenu you open. Tap the critter for another remark. Off by default."),
                checked_func = function() return opt("critter_on_library", false) == true end,
                callback = function() setOpt("critter_on_library", not opt("critter_on_library", false)) end,
            },
        },
    }
end

local function tapMenuItem()
    return {
        text_func = function()
            return opt("tap_bookorbit", false) and _("Book Panel Tap: BookOrbit This Book") or _("Book Panel Tap: Book Details")
        end,
        help_text = _("What a tap on the toolbar's book panel (the cover and title at the top) opens while reading."),
        sub_item_table = {
            {
                text = _("Opens BookOrbit \"This Book\""),
                help_text = _("Tap the book panel to open BookOrbit's This book sheet: whether this book is synced, Sync now, and its BookOrbit progress. Without BookOrbit installed the tap shows the book details as before."),
                checked_func = function() return opt("tap_bookorbit", false) == true end,
                callback = function() setOpt("tap_bookorbit", not opt("tap_bookorbit", false)) end,
            },
            {
                text = _("Hold Opens Book Details"),
                help_text = _("With the tap on BookOrbit: a long-press on the book panel shows KOReader's book details (status, rating, review)."),
                enabled_func = function() return opt("tap_bookorbit", false) == true end,
                checked_func = function() return opt("hold_details", true) == true end,
                callback = function() setOpt("hold_details", not opt("hold_details", true)) end,
            },
        },
    }
end

logger.info("shortcutstoolbar quick shelf v" .. PATCH_VERSION)

userpatch.registerPatchPluginFunc("shortcutstoolbar", function(plugin)
    hookPanel()
    if plugin.__stb_quick_shelf_menu then return end
    plugin.__stb_quick_shelf_menu = true
    plugin.__stb_recent_books_menu = true -- old file: no second menu entry
    local orig_add = plugin.addToMainMenu
    plugin.addToMainMenu = function(self, menu_items)
        orig_add(self, menu_items)
        local root = menu_items.shortcutstoolbar
        if root and root.sub_item_table then
            table.insert(root.sub_item_table, menuItem())
            table.insert(root.sub_item_table, tapMenuItem())
            table.insert(root.sub_item_table, critterMenuItem())
        end
    end
end)
