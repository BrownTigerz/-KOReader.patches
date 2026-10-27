--[[
Shortcuts Toolbar – Quick Shelf (userpatch)
===========================================
Version: 1.2.2
For xusoo/shortcutstoolbar.koplugin

In the reader's Shortcuts toolbar, swipe left or right on the top row (the
book info panel) to flip between it and a strip of books. The shortcut icons
below stay where they are. Two dots show which page you're on. Each menu
open starts on the book panel.

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

Changelog
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

local PATCH_VERSION = "1.2.2"
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

local function setSource(id)
    local s = G_reader_settings:readSetting(SETTINGS_KEY) or {}
    s.source = id
    G_reader_settings:saveSetting(SETTINGS_KEY, s)
    G_reader_settings:delSetting(OLD_SETTINGS_KEY)
end

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
    }
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
        local cx = x + math.floor(w / 2)
        local cy = y + h - DOT_R - 1
        paintDot(bb, cx - DOT_GAP / 2 - DOT_R, cy, self.page == 1)
        paintDot(bb, cx + DOT_GAP / 2 + DOT_R, cy, self.page == 2)
    end

    -- The strip's cover images are freed with the menu, like the panel.
    local base_free = pager.free
    pager.free = function(self, ...)
        for i, p in ipairs(self.pages) do
            if p ~= self[1] and p.free then pcall(p.free, p) end
            self.pages[i] = nil
        end
        if base_free then return base_free(self, ...) end
    end

    return pager
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
        local ok_p, pager = pcall(makePager, panel, avail_w)
        if ok_p then return pager end
        logger.warn("shortcutstoolbar quick shelf:", pager)
        return panel
    end)
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
        end
    end
end)
