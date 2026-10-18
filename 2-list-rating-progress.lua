--[[
2-list-rating-progress.lua
Adds a star rating + reading progress bar to CoverBrowser's
list ("detailed list") view in the File Manager / History / Collections.

Drawn in the bottom-right of each book row, left of the dogear.
Nothing is drawn for books that have never been opened.

Drop into: koreader/patches/
]]

local VERSION = "1.0.0"

local userpatch = require("userpatch")

-- ---------------------------------------------------------------- config
local CFG = {
    show_stars    = true,
    show_bar      = true,
    show_percent  = true,
    star_size     = 14,     -- unscaled px
    bar_height    = 6,      -- unscaled px
    bar_width     = 0.30,   -- fraction of text column width
    bottom_margin = 6,      -- unscaled px from row bottom
    right_margin  = 22,     -- unscaled px, clears the dogear
    gap           = 8,      -- unscaled px between elements
    font_size     = 13,
}
-- ------------------------------------------------------------------------

local function patchCoverBrowser()
    local Blitbuffer = require("ffi/blitbuffer")
    local DocSettings = require("docsettings")
    local Font = require("ui/font")
    local IconWidget = require("ui/widget/iconwidget")
    local TextWidget = require("ui/widget/textwidget")
    local Screen = require("device").screen
    local lfs = require("libs/libkoreader-lfs")
    local logger = require("logger")

    local ok, ListMenu = pcall(require, "listmenu")
    if not ok or not ListMenu then
        logger.warn("list-rating-progress: listmenu not found")
        return
    end
    local ListMenuItem = userpatch.getUpValue(ListMenu._updateItemsBuildUI, "ListMenuItem")
    if not ListMenuItem then
        logger.warn("list-rating-progress: ListMenuItem upvalue not found")
        return
    end

    local S = function(v) return Screen:scaleBySize(v) end

    local function readInfo(filepath)
        if not filepath or lfs.attributes(filepath, "mode") ~= "file" then return end
        if not DocSettings:hasSidecarFile(filepath) then return end
        local ds = DocSettings:open(filepath)
        local summary = ds:readSetting("summary") or {}
        local pct = ds:readSetting("percent_finished")
        if summary.status == "complete" then pct = 1 end
        if not pct and not summary.rating then return end
        return {
            percent = pct and math.max(0, math.min(1, pct)) or nil,
            rating = tonumber(summary.rating),
        }
    end

    local orig_update = ListMenuItem.update
    function ListMenuItem:update(...)
        orig_update(self, ...)
        self._rp_info = readInfo(self.filepath)
    end

    local orig_paintTo = ListMenuItem.paintTo
    function ListMenuItem:paintTo(bb, x, y)
        orig_paintTo(self, bb, x, y)
        local info = self._rp_info
        if not info then return end

        local w, h = self.width or self.dimen.w, self.height or self.dimen.h
        local text_w = w - h - S(10) -- cover slot is h x h
        local right = x + w - S(CFG.right_margin)
        local bottom = y + h - S(CFG.bottom_margin)
        local gap = S(CFG.gap)

        -- stars (right-most)
        if CFG.show_stars and info.rating and info.rating > 0 then
            local sz = S(CFG.star_size)
            local sx = right - 5 * sz
            for i = 1, 5 do
                local icon = IconWidget:new{
                    icon = i <= info.rating and "star.full" or "star.empty",
                    width = sz, height = sz,
                }
                icon:paintTo(bb, sx + (i - 1) * sz, bottom - sz)
                icon:free()
            end
            right = sx - gap
        end

        if not info.percent then return end

        -- percent label
        if CFG.show_percent then
            local tw = TextWidget:new{
                text = string.format("%d%%", math.floor(info.percent * 100 + 0.5)),
                face = Font:getFace("cfont", CFG.font_size),
            }
            local tsz = tw:getSize()
            tw:paintTo(bb, right - tsz.w, bottom - tsz.h + S(2))
            right = right - tsz.w - gap
            tw:free()
        end

        -- progress bar
        if CFG.show_bar then
            local bh = S(CFG.bar_height)
            local bw = math.floor(text_w * CFG.bar_width)
            local bx = right - bw
            local by = bottom - bh - S(3)
            local border = Screen:scaleBySize(1)
            bb:paintRect(bx, by, bw, bh, Blitbuffer.COLOR_WHITE)
            bb:paintBorder(bx, by, bw, bh, border, Blitbuffer.COLOR_BLACK)
            local fill = math.floor((bw - 2 * border) * info.percent)
            if fill > 0 then
                bb:paintRect(bx + border, by + border, fill, bh - 2 * border,
                    Blitbuffer.COLOR_DARK_GRAY)
            end
        end
    end
end

userpatch.registerPatchPluginFunc("coverbrowser", patchCoverBrowser)
