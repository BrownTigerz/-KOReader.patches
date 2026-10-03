--[[
Entity Footnotes patch for ultimatejimmy/xray.koplugin
https://github.com/Dukko/xray.koplugin

Version: 1.0.1 (2026-10-02) - See CHANGELOG below.

Versioning (for future updates to this file):
  1.0.x - fixes (e.g. adapting to an xray.koplugin internal rename)
  1.x.0 - new features
  2.0.0 - anything that changes how existing on-disk caches/backups work
          (i.e. an old cache file would no longer be read correctly)

Underlines AI-identified characters, historical figures, locations, and terms
directly in the reading text and shows a footnote-style popup with the AI
description on tap - the same in-text interaction the plugin already has for
unit conversions. Runs as a chunked, non-blocking scan so page turns stay
responsive.

Install: copy this file into koreader/patches/2-xray-entity-footnotes.lua
Requires: the official xray.koplugin plugin already installed and enabled.
Background: https://github.com/ultimatejimmy/xray.koplugin/pull/100

This patch does not modify xray.koplugin at all. It monkey-patches the
plugin's shared class table at runtime, via KOReader's own
userpatch.registerPatchPluginFunc API (frontend/userpatch.lua) - the
mechanism KOReader itself provides specifically for patching a plugin's
class table from outside, since plugins are dofile()'d rather than
require()'d and never end up in Lua's module cache. All credit for
X-Ray itself goes to ultimatejimmy.

===================================================================
CHANGELOG
===================================================================
1.0.1 (2026-10-02) - Fix: dropped the on-device version line from the
X-Ray submenu (kept the menu short); version is still visible in
crash.log on every startup (see the PATCH_VERSION log lines below).

1.0.0 (2026-10-02) - First release. Everything below was folded into this
initial version during development/review; future entries will be per-bump.

Correctness:
  - findAllText's 5000-hit cap could silently truncate results on a common
    name in a long book. A chunk that comes back at/near the cap now gets
    split in half and retried instead of accepted as final.
  - entity_matches_by_page went stale after any re-render (font/margin/
    rotation change renumbers pages). It is now keyed to the document's
    rendering hash and rebuilt when that hash changes.
  - a settings/data change that arrived WHILE a scan was already running
    used to be silently dropped (scanBookForEntities returns early while
    a scan is in progress). A pending-rescan flag now catches it and
    re-runs once the current scan finishes.
  - clearCache's effect is now verified against the entity list counts
    actually changing, instead of assuming the call always means "wipe
    everything" (it may be a confirm-dialog wrapper that the user cancels).
  - zero-hit chunks (a completely normal outcome) no longer take the
    same code path as a genuinely malformed regex and get logged as an
    error.
  - a missing/failing self._draw_underline is now logged once per book,
    not once per repaint.
  - the on-disk cache is now written atomically (tmp file + rename) so a
    crash mid-write can't leave a truncated file with a valid-looking
    signature line.
  - the cache signature now includes aliases, not just canonical names,
    so an alias-only change is detected.
  - the on-disk entity cache for a book is now deleted once that book is
    marked "complete" (read back at document-close time, since ReaderStatus
    has no event of its own for the mark-finished action - see the comment
    above _isBookMarkedComplete for why).
  - _normalize() no longer accidentally returns two values (gsub's count)
    from its final chained call.
  - overlapping matches (e.g. "King John" and "John" inside it) are now
    deduped by screen-box overlap, not just by identical end position.
  - deduping "first occurrence per page" now only considers boxes that
    are actually on/near the visible screen area, so an earlier, off-
    screen occurrence (scroll mode) can't suppress the visible one.
  - showEntityFootnote now always renders the compact anchored tooltip
    card for in-book taps, instead of routing through xray.koplugin's
    native full-panel detail viewers (showCharacterDetails/etc.) - see
    the comment on that function for why.

Performance / responsiveness:
  - scans and cache loads are no longer started synchronously from
    inside the paint path; they're deferred a tick so a single frame
    never both paints and kicks off file IO / a fresh scan.
  - MAX_REGEX_LEN lowered and per-chunk timing is logged, so a slow
    chunk shows up in the log instead of just "the screen paused".
  - a data/settings change no longer triggers an immediate rescan; it's
    debounced ~2s so several fetches in a row only cause one scan.
  - toggling a setting no longer force-bypasses the cache; the cache
    signature already covers settings, so a normal (non-forced) scan
    call is enough and can still hit the cache when applicable.
  - _buildMatchesByPage is now batched across several event-loop ticks
    instead of walking every match in one synchronous call.

Behavior:
  - Entity Footnotes starts OFF on every book open; the gesture (bind
    "Toggle entity footnote underlines" in Gesture Manager) or the
    "Enable Entity Footnotes" menu checkbox turns it on for that reading
    session only. No scanning or caching happens at all while off.
--]]

local PATCH_VERSION = "1.0.1"

local ok_userpatch, userpatch = pcall(require, "userpatch")
if not ok_userpatch or not userpatch or not userpatch.registerPatchPluginFunc then
    local ok_logger_boot, logger_boot = pcall(require, "logger")
    if ok_logger_boot then
        logger_boot.warn("xray-entity-footnotes patch: userpatch API not available, skipping")
    end
    return
end

local logger = require("logger")
local function log(msg)
    logger.info("EntityFootnotesPatch: " .. tostring(msg))
end

local UIManager = require("ui/uimanager")
local Screen = require("device").screen
local Blitbuffer = require("ffi/blitbuffer")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local TextBoxWidget = require("ui/widget/textboxwidget")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local DocSettings = require("docsettings")
local OverlapGroup = require("ui/widget/overlapgroup")

local M = {}

local CATEGORY_LABELS = {
    character = "Character",
    historical_figure = "Historical Figure",
    location = "Location",
    term = "Term",
}

local MIN_TERM_LEN = 3
-- Lowered from 3000: smaller regex chunks mean each findAllText() call does
-- less work, so a slow chunk shows up as a small hitch instead of a
-- multi-hundred-ms stall. See SLOW_CHUNK_SECONDS below for the log that
-- tells you if this is still too high for a given device/book.
local MAX_REGEX_LEN = 1200
-- findAllText caps out at 5000 hits per call. A chunk that returns at or
-- near the cap has its terms split in half and is retried (see step()) so
-- a very common name in a long book doesn't silently lose its back-half
-- mentions.
local FINDALLTEXT_HIT_CAP = 5000
local HIT_CAP_SPLIT_THRESHOLD = 4500
-- Any single findAllText() call slower than this gets logged, so a real
-- slowdown is visible in the log instead of just "the reader paused".
local SLOW_CHUNK_SECONDS = 0.3
-- How many matches to resolve to screen boxes per event-loop tick when
-- (re)building the page->matches bucket map. Keeps a single call from
-- walking thousands of matches synchronously.
local PAGE_BUCKET_BATCH = 300
-- How long to wait after the last detected data/settings change before
-- actually kicking off a rescan, so several changes in a row (e.g. a
-- multi-step "fetch more characters" flow) collapse into one scan.
local RESCAN_DEBOUNCE_SECONDS = 2

-- Every settings read in this file goes through here instead of repeating
-- "self.ai_helper and self.ai_helper.settings or {}" inline at each call site -
-- one place to change if ai_helper's shape ever changes, and one less chance of a
-- copy-paste typo silently reading the wrong field.
local function _settings(self)
    return (self.ai_helper and self.ai_helper.settings) or {}
end

-- Safe helper for current page
local function _getCurrentPage(plugin)
    if plugin.last_pageno then return plugin.last_pageno end
    if plugin.ui and plugin.ui.paging and plugin.ui.paging.getCurrentPage then
        local ok, pg = pcall(function() return plugin.ui.paging:getCurrentPage() end)
        if ok then return pg end
    end
    if plugin.ui and plugin.ui.pageno then
        return plugin.ui.pageno
    end
    return 1
end

local function escape_pattern(s)
    -- Backslash-escape ECMAScript regex SyntaxCharacters for the search engine's own
    -- regex flavor (crengine's findAllText, backed by SRELL, srell::regex::ECMAScript) -
    -- not Lua patterns. "-" and "%" are NOT special outside a character class in
    -- ECMAScript regex, so escaping them produces "\-" and "\%", and "\%" specifically
    -- isn't a recognized escape sequence - SRELL rejects the whole pattern as invalid
    -- (doc:checkRegex returns error_escape/102) the moment any term contains one,
    -- silently making findAllText return zero hits for that entire chunk.
    local esc = s:gsub("([%^%$%.%*%+%?%(%)%[%]%{%}|\\])", "\\%1")
    esc = esc:gsub("%s+", "\\s+")
    return esc
end

-- FIX: wrapped in parens so only the first return value (the string) comes
-- back. Without the parens, the final chained gsub's second return value
-- (its substitution count) would also be returned from _normalize, and any
-- caller doing `local a, b = _normalize(x)` or using it as the last/only
-- argument to another call could silently pick up that stray count.
local function _normalize(s)
    return ((s or ""):gsub("\194\160", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Byte-level "is this a word character" check used only to decide whether a
-- term needs \b word-boundary wrapping. %w is ASCII-only, so a name that
-- starts or ends with an accented/non-Latin letter (e.g. "Ana Beatriz",
-- Cyrillic names) used to fail the %w check and fall back to unwrapped
-- boundaries. Any byte >= 0x80 is treated as "word-like" here (UTF-8
-- continuation/lead bytes are all >= 0x80), which is a rough but safe
-- approximation for this purpose - it only affects whether \b is added.
local function _isWordByte(b)
    if not b then return false end
    return (b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b >= 128
end

local function _hasWordBoundaries(t)
    return _isWordByte(t:byte(1)) and _isWordByte(t:byte(-1))
end

-- Small, user-extendable list of capitalized words that are common enough
-- in ordinary prose (sentence-initial "Will", "Mark", "Rose", "May", ...)
-- that they frequently collide with genuine character names and cause
-- false underlines. Off by default (empty) so nothing is silently hidden;
-- add entries via settings.entity_exclude_terms (comma-separated) if a
-- specific book is noisy. Matching stays case-sensitive as before, so this
-- only ever suppresses the exact-case form listed.
local function _buildExcludeSet(settings)
    local set = {}
    local raw = settings.entity_exclude_terms
    if type(raw) == "string" and raw ~= "" then
        for word in raw:gmatch("[^,]+") do
            local w = _normalize(word):lower()
            if w ~= "" then set[w] = true end
        end
    end
    return set
end

-- Builds a name/alias -> {entity, category, canonical} lookup plus the flat list of
-- unique search terms (original case preserved), from the already-fetched entity lists.
-- Terms are matched case-sensitively (see step()) so common lowercase words that happen
-- to share spelling with a proper noun ("black" the color vs "Black" the character) and
-- lowercase substrings inside unrelated words ("than" containing "han") don't false-match
-- - entity names and aliases are capitalized proper nouns in practice, so requiring the
-- original case is a much tighter filter than \b word boundaries alone.
local function _collectEntityTerms(self, settings)
    local groups = {
        { list = self.characters, category = "character", enabled = settings.entity_cat_characters ~= false },
        { list = self.historical_figures, category = "historical_figure", enabled = settings.entity_cat_historical_figures ~= false },
        { list = self.locations, category = "location", enabled = settings.entity_cat_locations ~= false },
        { list = self.terms, category = "term", enabled = settings.entity_cat_terms ~= false },
    }

    local exclude = _buildExcludeSet(settings)
    local lookup = {}
    local terms = {}

    for _, group in ipairs(groups) do
        if group.enabled and group.list then
            for _, entity in ipairs(group.list) do
                local names = {}
                if entity.name and entity.name ~= "" then table.insert(names, entity.name) end
                if entity.aliases and type(entity.aliases) == "table" then
                    for _, alias in ipairs(entity.aliases) do
                        if type(alias) == "string" and alias ~= "" then table.insert(names, alias) end
                    end
                end
                for _, n in ipairs(names) do
                    local clean = _normalize(n)
                    if #clean >= MIN_TERM_LEN then
                        local lower = clean:lower()
                        if exclude[lower] then
                            -- skip: user-configured noisy/ambiguous term
                        elseif not lookup[lower] then
                            lookup[lower] = { entity = entity, category = group.category, canonical = entity.name }
                            table.insert(terms, clean)
                        elseif lookup[lower].canonical ~= entity.name then
                            -- FIX: previously silent. Two different entities sharing a
                            -- name/alias means one of them just won't get underlined -
                            -- worth knowing about when debugging "why isn't X showing up".
                            log("term collision: '" .. clean .. "' already mapped to "
                                .. tostring(lookup[lower].canonical) .. ", ignoring alias from "
                                .. tostring(entity.name))
                        end
                    end
                end
            end
        end
    end

    return terms, lookup
end

-- Splits terms into word-boundary-safe regex chunks, each under MAX_REGEX_LEN, to stay
-- within the text engine's regex size limits on large libraries of entities.
--
-- FIX: each chunk now carries its own escaped term list (not just the final
-- joined pattern string), so a chunk that turns out to return too many hits
-- (see step()/HIT_CAP_SPLIT_THRESHOLD) can be split in half and re-queued
-- without having to re-derive its terms from the pattern text.
local function _makeChunkPattern(escaped_terms, wrap_both)
    local body = table.concat(escaped_terms, "|")
    if wrap_both then
        return "\\b(" .. body .. ")\\b"
    end
    return "(" .. body .. ")"
end

local function _buildChunks(terms)
    table.sort(terms, function(a, b) return #a > #b end)

    local boundary_both = {}
    local boundary_none = {}
    for _, t in ipairs(terms) do
        local esc = escape_pattern(t)
        if _hasWordBoundaries(t) then
            table.insert(boundary_both, esc)
        else
            table.insert(boundary_none, esc)
        end
    end

    local function chunk_list(list, wrap_both)
        local chunks = {}
        local current = {}
        local current_len = 0
        for _, esc in ipairs(list) do
            if current_len + #esc + 1 > MAX_REGEX_LEN and #current > 0 then
                table.insert(chunks, current)
                current = {}
                current_len = 0
            end
            table.insert(current, esc)
            current_len = current_len + #esc + 1
        end
        if #current > 0 then table.insert(chunks, current) end

        local descriptors = {}
        for _, c in ipairs(chunks) do
            table.insert(descriptors, {
                terms = c,
                wrap_both = wrap_both,
                pattern = _makeChunkPattern(c, wrap_both),
            })
        end
        return descriptors
    end

    local descriptors = {}
    for _, d in ipairs(chunk_list(boundary_both, true)) do table.insert(descriptors, d) end
    for _, d in ipairs(chunk_list(boundary_none, false)) do table.insert(descriptors, d) end
    return descriptors
end

-- Splits an oversized chunk descriptor into two smaller ones (same
-- wrap_both), used when a chunk comes back at/near the findAllText hit cap.
local function _splitChunkDescriptor(desc)
    local terms = desc.terms
    if #terms <= 1 then return nil end
    local mid = math.floor(#terms / 2)
    local a, b = {}, {}
    for i = 1, mid do table.insert(a, terms[i]) end
    for i = mid + 1, #terms do table.insert(b, terms[i]) end
    return
        { terms = a, wrap_both = desc.wrap_both, pattern = _makeChunkPattern(a, desc.wrap_both) },
        { terms = b, wrap_both = desc.wrap_both, pattern = _makeChunkPattern(b, desc.wrap_both) }
end

-- ===== Overlay mount (paintTo) =====

function M:clearEntityUnderlines()
    self.entity_boxes = nil
    self.entity_xp_matches = nil
    self.entity_matches_by_page = nil
    self._entity_matches_by_page_hash = nil
    if self.ui and self.ui.view and self.ui.view.dialog then
        UIManager:setDirty(self.ui.view.dialog, "ui")
    end
end

-- Handles the "ToggleEntityFootnotes" Dispatcher event, which fires when the
-- user triggers whatever KOReader gesture they've bound to the
-- "Toggle entity footnote underlines" action (Settings > Taps and Gestures >
-- Gesture Manager). Ported from the earlier version of this patch, which is
-- also where that Dispatcher action is (re-)registered - see the
-- registerPatchPluginFunc callback below.
--
-- Uses the same settings/scan path as the "Enable Entity Footnotes" menu
-- checkbox (_settings/saveSettings, and a normal non-forced scanBookForEntities
-- call so a cache hit is still possible) rather than the toggle's own
-- lighter-weight original implementation, to stay consistent with the rest
-- of this file's fixes.
function M:onToggleEntityFootnotes()
    if not self.ai_helper then return true end
    local was_enabled = _settings(self).entity_footnotes_enabled ~= false
    self.ai_helper:saveSettings({ entity_footnotes_enabled = not was_enabled })
    if self.scanBookForEntities then self:scanBookForEntities(false, false) end
    local ok, Notification = pcall(require, "ui/widget/notification")
    if ok then
        Notification:notify(was_enabled
            and (self.loc:t("entity_footnotes_off_notify") or "X-Ray Footnotes: off")
            or (self.loc:t("entity_footnotes_on_notify") or "X-Ray Footnotes: on"))
    end
    return true
end

-- Gets the document's current rendering hash, if the backend exposes one.
-- Used to know when a re-render (font size, margins, rotation, ...) has
-- renumbered pages, so the page->matches bucket map (built against the
-- OLD page numbers) can be invalidated instead of silently going stale.
local function _getRenderingHash(doc)
    if not doc or not doc.getDocumentRenderingHash then return nil end
    local ok, hash = pcall(function() return doc:getDocumentRenderingHash() end)
    if ok then return hash end
    return nil
end

-- Buckets matches by page, batched across several event-loop ticks instead of
-- walking the full match list synchronously in one call - a name mentioned
-- hundreds of times in a long book could otherwise make this a real, single
-- blocking pause. Calls `done_cb(by_page_or_nil)` when finished (by_page is
-- nil if the doc doesn't support the cheap page lookup, or if resolution
-- never actually produced a bucket, matching the previous behaviour).
--
-- Only rolling (reflowable) documents expose the cheap doc:getPageFromXPointer
-- lookup this relies on; paginated documents (PDF etc.) fall back to the
-- unbucketed full-list resolve (done_cb(nil)).
local function _buildMatchesByPageAsync(self, doc, matches, done_cb)
    if not doc or not doc.getPageFromXPointer or #matches == 0 then
        done_cb(nil)
        return
    end

    local by_page = {}
    local resolved_any = false
    local idx = 0
    local n = #matches

    local function step()
        if self.destroyed or not self.ui or not self.ui.document then
            done_cb(nil)
            return
        end
        local processed = 0
        while idx < n and processed < PAGE_BUCKET_BATCH do
            idx = idx + 1
            local m = matches[idx]
            local ok, page = pcall(doc.getPageFromXPointer, doc, m.start_xp)
            if ok and page then
                by_page[page] = by_page[page] or {}
                table.insert(by_page[page], m)
                resolved_any = true
            end
            processed = processed + 1
        end
        if idx >= n then
            -- Some paginated backends expose getPageFromXPointer but it never
            -- actually resolves anything for their document type. Committing to
            -- an all-empty bucket map in that case would make
            -- _resolveEntityHighlightBoxes treat every page as having zero
            -- nearby matches - silently hiding every underline - instead of
            -- falling back to the full-list resolve it would otherwise use.
            done_cb(resolved_any and by_page or nil)
        else
            UIManager:scheduleIn(0, step)
        end
    end

    step()
end

function M:mountEntityUnderlineOverlay()
    if self._entity_paintTo_wrapped then return end
    local view = self.ui and self.ui.view
    if not view then return end
    local plugin = self
    local orig = view.paintTo
    view.paintTo = function(view_self, bb, x, y)
        orig(view_self, bb, x, y)
        -- FIX: was `pcall(function() plugin:_drawEntityUnderlines(bb) end)`,
        -- which allocates a fresh closure on every single paint. Passing the
        -- method and receiver directly to pcall avoids that per-paint
        -- allocation.
        local ok, err = pcall(plugin._drawEntityUnderlines, plugin, bb)
        if not ok then
            log("draw error: " .. tostring(err))
        end
    end
    self._entity_paintTo_wrapped = true
end

local function _getEntityCacheSig(self)
    local doc = self.ui and self.ui.document
    if not doc then return "" end
    local page = _getCurrentPage(self)
    local pos = ""
    if doc.getCurrentPos then
        pcall(function() pos = doc:getCurrentPos() end)
    end
    local hash = ""
    if doc.getDocumentRenderingHash then
        pcall(function() hash = doc:getDocumentRenderingHash() end)
    end
    local sw, sh = Screen:getWidth(), Screen:getHeight()
    return table.concat({ tostring(page), tostring(pos), tostring(hash), tostring(sw), tostring(sh) }, "|")
end

-- Rough on-screen rect for the current page, used to filter out boxes that
-- are technically resolved but aren't actually near the visible area (can
-- happen in scroll/continuous mode where "nearby pages" spans more area
-- than what's drawn right now). A generous margin is used since this is
-- only meant to exclude clearly-offscreen boxes, not do precise clipping.
local function _visibleRect()
    local margin = Screen:scaleBySize(400)
    return {
        x0 = -margin, y0 = -margin,
        x1 = Screen:getWidth() + margin, y1 = Screen:getHeight() + margin,
    }
end

local function _boxInRect(box, rect)
    return box.y < rect.y1 and (box.y + box.h) > rect.y0
        and box.x < rect.x1 and (box.x + box.w) > rect.x0
end

-- Rectangle-overlap test between two groups' overall bounding boxes, used to
-- dedupe overlapping matches (e.g. "King John" and the "John" inside it)
-- that don't happen to share an end position and so weren't already merged
-- by the longest-match-per-end-xpointer logic in step().
local function _groupBoundingBox(group)
    local x0, y0, x1, y1 = nil, nil, nil, nil
    for _, box in ipairs(group.boxes) do
        local bx1, by1 = box.x + box.w, box.y + box.h
        if not x0 or box.x < x0 then x0 = box.x end
        if not y0 or box.y < y0 then y0 = box.y end
        if not x1 or bx1 > x1 then x1 = bx1 end
        if not y1 or by1 > y1 then y1 = by1 end
    end
    return x0, y0, x1, y1
end

local function _rectOverlapArea(ax0, ay0, ax1, ay1, bx0, by0, bx1, by1)
    local ox0, oy0 = math.max(ax0, bx0), math.max(ay0, by0)
    local ox1, oy1 = math.min(ax1, bx1), math.min(ay1, by1)
    if ox1 <= ox0 or oy1 <= oy0 then return 0 end
    return (ox1 - ox0) * (oy1 - oy0)
end

function M:_resolveEntityHighlightBoxes()
    local sig = _getEntityCacheSig(self)
    if self._entity_box_cache_sig == sig and self.entity_boxes then
        return
    end

    self._entity_box_cache_sig = sig
    local doc = self.ui and self.ui.document
    if not doc or not self.entity_xp_matches or #self.entity_xp_matches == 0 then
        self.entity_boxes = {}
        return
    end

    -- If matches are bucketed by page, only resolve the handful near the current page
    -- instead of every match in the whole book (a name mentioned hundreds of times would
    -- otherwise make every page turn scan the entire book's match list).
    local matches_to_resolve = self.entity_xp_matches
    if self.entity_matches_by_page then
        local page = _getCurrentPage(self)
        matches_to_resolve = {}
        for _, pg in ipairs({ page - 1, page, page + 1 }) do
            local bucket = self.entity_matches_by_page[pg]
            if bucket then
                for _, m in ipairs(bucket) do table.insert(matches_to_resolve, m) end
            end
        end
    end

    -- Resolve each match to its screen box(es) first, keeping multi-line-wrapped matches
    -- grouped together (a single match can produce several boxes, one per visual line).
    local visible = _visibleRect()
    local groups = {}
    for _, match in ipairs(matches_to_resolve) do
        local ok, boxes = pcall(doc.getScreenBoxesFromPositions, doc, match.start_xp, match.end_xp, true)
        if ok and boxes and #boxes > 0 then
            local group_boxes = {}
            local top_y, top_x = nil, nil
            local any_visible = false
            for _, box in ipairs(boxes) do
                if _boxInRect(box, visible) then any_visible = true end
                table.insert(group_boxes, {
                    x = box.x,
                    y = box.y,
                    w = box.w,
                    h = box.h,
                    matched_text = match.matched_text,
                    category = match.category,
                    entity_name = match.entity_name,
                })
                if not top_y or box.y < top_y or (box.y == top_y and box.x < top_x) then
                    top_y, top_x = box.y, box.x
                end
            end
            -- FIX: previously any resolved match (even ones entirely off the
            -- visible area, e.g. an earlier occurrence higher up in scroll
            -- mode) could win the "first occurrence per page" dedupe below and
            -- suppress the on-screen occurrence. Skip groups with no box
            -- anywhere near the visible area.
            if any_visible then
                table.insert(groups, {
                    key = (match.category or "") .. "|" .. (match.entity_name or ""),
                    sort_y = top_y,
                    sort_x = top_x,
                    boxes = group_boxes,
                    matched_len = #(match.matched_text or ""),
                })
            end
        end
    end

    -- Reading order (top-to-bottom, then left-to-right) so the per-page dedup below keeps
    -- whichever mention appears first on the page, not an arbitrary one.
    table.sort(groups, function(a, b)
        if a.sort_y ~= b.sort_y then return a.sort_y < b.sort_y end
        return a.sort_x < b.sort_x
    end)

    -- FIX: drop groups whose bounding box substantially overlaps an
    -- already-kept group's bounding box (e.g. "John" inside "King John").
    -- Prefers the longer match when two overlap. O(n^2) but n is the tiny
    -- per-page/near-page match count, not the whole-book match count.
    local kept = {}
    for _, group in ipairs(groups) do
        local gx0, gy0, gx1, gy1 = _groupBoundingBox(group)
        local overlaps = false
        if gx0 then
            for _, k in ipairs(kept) do
                local kx0, ky0, kx1, ky1 = _groupBoundingBox(k)
                if kx0 then
                    local overlap_area = _rectOverlapArea(gx0, gy0, gx1, gy1, kx0, ky0, kx1, ky1)
                    local g_area = math.max(1, (gx1 - gx0) * (gy1 - gy0))
                    if overlap_area > 0 and (overlap_area / g_area) > 0.5 then
                        overlaps = true
                        break
                    end
                end
            end
        end
        if not overlaps then table.insert(kept, group) end
    end

    -- Only underline the first occurrence of a given entity per page - repeated mentions of
    -- the same name in the same paragraph/page would otherwise clutter the text.
    local seen = {}
    local resolved = {}
    for _, group in ipairs(kept) do
        if not seen[group.key] then
            seen[group.key] = true
            for _, box in ipairs(group.boxes) do
                table.insert(resolved, box)
            end
        end
    end

    self.entity_boxes = resolved
end

-- Besides settings, this also watches the *size* of the four entity lists
-- (self.characters/historical_figures/locations/terms). xray.koplugin populates those
-- same lists no matter which of its own internal fetch flows the user triggers (a full
-- book scan, "Fetch More Characters", a targeted inline lookup, a data merge, etc.) - so
-- rather than trying to hook those flows by name (private internals that get renamed
-- across xray.koplugin releases, per its own changelogs), watching the list sizes here
-- catches "new entity data arrived" generically and correctly regardless of how it
-- arrived. This is checked on every repaint, so it must stay O(1) per list (a bare `#`
-- length check) rather than building/comparing full name strings - that cost belongs in
-- _getEntitySettingsSignature, which only runs at actual scan/cache time, not per paint.
-- A list shrinking counts as a change too (e.g. after Clear Cache repopulates from
-- scratch), so this is a plain inequality check, not "grew".
local function _checkEntityStateChanged(self)
    local settings = _settings(self)
    local enabled = settings.entity_footnotes_enabled ~= false
    local cat_c = settings.entity_cat_characters ~= false
    local cat_h = settings.entity_cat_historical_figures ~= false
    local cat_l = settings.entity_cat_locations ~= false
    local cat_t = settings.entity_cat_terms ~= false
    local style = settings.unit_underline_style or "wavy"
    local thickness = settings.unit_underline_thickness or 2
    local intensity = settings.unit_underline_intensity or "light"

    local count_c = #(self.characters or {})
    local count_h = #(self.historical_figures or {})
    local count_l = #(self.locations or {})
    local count_t = #(self.terms or {})

    if self.last_entity_settings_state == nil then
        self.last_entity_settings_state = {
            enabled = enabled, cat_c = cat_c, cat_h = cat_h, cat_l = cat_l, cat_t = cat_t,
            style = style, thickness = thickness, intensity = intensity,
            count_c = count_c, count_h = count_h, count_l = count_l, count_t = count_t,
        }
        return false, false
    end

    local state = self.last_entity_settings_state
    local data_changed = (state.count_c ~= count_c) or (state.count_h ~= count_h) or
                         (state.count_l ~= count_l) or (state.count_t ~= count_t)
    local scan_changed = data_changed or (state.enabled ~= enabled) or (state.cat_c ~= cat_c) or
                         (state.cat_h ~= cat_h) or (state.cat_l ~= cat_l) or (state.cat_t ~= cat_t)
    local draw_changed = (state.style ~= style) or (state.thickness ~= thickness) or (state.intensity ~= intensity)

    if scan_changed or draw_changed then
        self.last_entity_settings_state = {
            enabled = enabled, cat_c = cat_c, cat_h = cat_h, cat_l = cat_l, cat_t = cat_t,
            style = style, thickness = thickness, intensity = intensity,
            count_c = count_c, count_h = count_h, count_l = count_l, count_t = count_t,
        }
    end

    return scan_changed, draw_changed
end

-- FIX: rescans used to fire the instant a change was detected, on the very
-- next repaint. If entity data arrives incrementally (several small updates
-- close together), that meant several back-to-back full-book scans. This
-- debounces: a change resets a short timer, and the actual scan only fires
-- once nothing has changed for RESCAN_DEBOUNCE_SECONDS.
local function _scheduleDebouncedRescan(self)
    if self._entity_rescan_timer_fn then
        UIManager:unschedule(self._entity_rescan_timer_fn)
        self._entity_rescan_timer_fn = nil
    end
    local plugin = self
    local fn
    fn = function()
        if plugin._entity_rescan_timer_fn ~= fn then return end -- superseded by a newer schedule
        plugin._entity_rescan_timer_fn = nil
        if plugin.destroyed or not plugin.ui or not plugin.ui.document then return end
        log("debounced rescan firing")
        plugin:scanBookForEntities(true)
    end
    self._entity_rescan_timer_fn = fn
    UIManager:scheduleIn(RESCAN_DEBOUNCE_SECONDS, fn)
end

function M:_drawEntityUnderlines(bb)
    local scan_needed, redraw_needed = _checkEntityStateChanged(self)
    if scan_needed then
        log("Entity data or settings changed, refreshing entity scan (debounced)")
        -- FIX: previously called self:scanBookForEntities(true) directly from
        -- inside the paint path - i.e. potentially kicking off file IO and a
        -- fresh multi-chunk scan synchronously, mid-frame. Now debounced and
        -- deferred instead.
        _scheduleDebouncedRescan(self)
        self._entity_box_cache_sig = nil
    elseif redraw_needed then
        self._entity_box_cache_sig = nil

        local settings = _settings(self)
        if settings.entity_footnotes_enabled == false then
            self:clearEntityUnderlines()
        elseif not self.entity_xp_matches then
            -- FIX: deferred a tick instead of running synchronously inside
            -- paintTo - loadEntityCache does file IO, and a cache miss falls
            -- straight into scanBookForEntities.
            local plugin = self
            UIManager:nextTick(function()
                if plugin.destroyed or not plugin.ui or not plugin.ui.document then return end
                if plugin.entity_xp_matches then return end -- already handled meanwhile
                local cache_loaded = plugin:loadEntityCache()
                if not cache_loaded then
                    plugin:scanBookForEntities(false, false)
                end
            end)
        end
    end

    local settings = _settings(self)
    if settings.entity_footnotes_enabled == false then return end

    self:_resolveEntityHighlightBoxes()
    if not self.entity_boxes or #self.entity_boxes == 0 then return end

    local underline_style = settings.unit_underline_style or "wavy"
    if underline_style == "invisible" then return end

    local raw_thickness = tonumber(settings.unit_underline_thickness) or 2
    local thickness = Screen:scaleBySize(raw_thickness)
    local intensity = settings.unit_underline_intensity or "light"

    local grey = 150
    if intensity == "light" then
        grey = 200
    elseif intensity == "dark" then
        grey = 30
    end

    -- FIX: a missing/failing self._draw_underline used to be discovered (and
    -- implicitly ignored, or errored via the outer pcall) on every single
    -- box, every single repaint. Check once per book and log once.
    if self._draw_underline == nil then
        if not self._entity_draw_underline_warned then
            self._entity_draw_underline_warned = true
            log("self._draw_underline is not available - underlines will not be drawn")
        end
        return
    end

    for _, box in ipairs(self.entity_boxes) do
        if box.x and box.y and box.w and box.h then
            local ok, err = pcall(self._draw_underline, bb, box, underline_style, grey, thickness, raw_thickness, self.path)
            if not ok and not self._entity_draw_underline_warned then
                self._entity_draw_underline_warned = true
                log("_draw_underline failed: " .. tostring(err))
            end
        end
    end
end

-- ===== Cache =====

function M:_getEntityCachePath()
    if not self.ui or not self.ui.document or not self.ui.document.file then return nil end
    local sidecar = DocSettings:getSidecarDir(self.ui.document.file)
    if not sidecar then return nil end
    return sidecar .. "/xray_entity_cache.cache"
end

-- Signature covers both the enabled categories and the entity data itself (name lists),
-- so the cache self-invalidates once the AI has fetched more characters/locations/etc,
-- without needing to hook every fetch completion path.
--
-- FIX: now includes aliases (not just canonical names), so a change that
-- only touches an entity's alias list is also detected instead of reusing
-- a stale cache built before the alias existed.
local function _getEntitySettingsSignature(self, settings)
    local function sig_list(list)
        local parts = {}
        if list then
            for _, e in ipairs(list) do
                table.insert(parts, e.name or "")
                if e.aliases and type(e.aliases) == "table" then
                    for _, alias in ipairs(e.aliases) do
                        if type(alias) == "string" then table.insert(parts, alias) end
                    end
                end
            end
        end
        return table.concat(parts, ",")
    end

    local cat_c = settings.entity_cat_characters ~= false
    local cat_h = settings.entity_cat_historical_figures ~= false
    local cat_l = settings.entity_cat_locations ~= false
    local cat_t = settings.entity_cat_terms ~= false

    return table.concat({
        "v2", -- bumped: signature now includes aliases (see comment above)
        tostring(cat_c), tostring(cat_h), tostring(cat_l), tostring(cat_t),
        sig_list(self.characters), sig_list(self.historical_figures),
        sig_list(self.locations), sig_list(self.terms),
    }, "|")
end

function M:loadEntityCache(expected_sig)
    local cache_file = self:_getEntityCachePath()
    if not cache_file then return false end

    local f = io.open(cache_file, "r")
    if not f then return false end

    local signature = f:read("*l")
    if not signature then
        f:close()
        return false
    end
    signature = signature:gsub("%s+$", "")

    expected_sig = expected_sig or _getEntitySettingsSignature(self, _settings(self))
    if signature ~= expected_sig then
        f:close()
        return false
    end

    local matches = {}
    for line in f:lines() do
        line = line:gsub("\r", "")
        local start_xp, end_xp, matched_text, category, entity_name = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
        if start_xp then
            table.insert(matches, {
                start_xp = start_xp,
                end_xp = end_xp,
                matched_text = matched_text,
                category = category,
                entity_name = entity_name,
            })
        end
    end
    f:close()

    self.entity_xp_matches = matches
    self._entity_box_cache_sig = nil
    self.entity_matches_by_page = nil
    self._entity_matches_by_page_hash = nil

    -- FIX: bucketing is now async/batched (see _buildMatchesByPageAsync) so
    -- loading a large cached match list can't itself become a synchronous
    -- stall. self.entity_boxes/underlines will simply resolve against the
    -- unbucketed full list until the bucket map finishes filling in a tick
    -- or two later, at which point a redraw is requested.
    local plugin = self
    local doc = self.ui and self.ui.document
    self._entity_matches_by_page_hash = _getRenderingHash(doc)
    _buildMatchesByPageAsync(self, doc, matches, function(by_page)
        if plugin.destroyed then return end
        plugin.entity_matches_by_page = by_page
        plugin._entity_box_cache_sig = nil
        if plugin.ui and plugin.ui.view then
            if plugin.ui.view.dialog then UIManager:setDirty(plugin.ui.view.dialog, "ui") end
            UIManager:setDirty(nil, "ui")
        end
    end)

    log("loadEntityCache: loaded " .. tostring(#matches) .. " matches from cache")
    if self.ui and self.ui.view then
        if self.ui.view.dialog then
            UIManager:setDirty(self.ui.view.dialog, "ui")
        end
        UIManager:setDirty(nil, "ui")
    end
    return true
end

function M:saveEntityCache(signature)
    local cache_file = self:_getEntityCachePath()
    if not cache_file then return end

    signature = signature or _getEntitySettingsSignature(self, _settings(self))

    local dir = cache_file:match("^(.+)/[^/]+$")
    if dir then
        local ok_lfs, lfs = pcall(require, "libs/libkoreader-lfs")
        if ok_lfs and lfs then
            if lfs.attributes(dir, "mode") ~= "directory" then
                lfs.mkdir(dir)
            end
        end
    end

    -- FIX: write to a temp file and rename into place, so a crash or power
    -- loss mid-write can't leave a truncated file behind that still starts
    -- with a valid signature line (which loadEntityCache would then happily
    -- treat as a complete, matching cache).
    local tmp_file = cache_file .. ".tmp"
    local ok, err = pcall(function()
        local f, open_err = io.open(tmp_file, "w")
        if f then
            f:write(signature .. "\n")
            for _, m in ipairs(self.entity_xp_matches or {}) do
                local matched_clean = (m.matched_text or ""):gsub("\r", " "):gsub("\n", " ")
                local name_clean = (m.entity_name or ""):gsub("\r", " "):gsub("\n", " ")
                f:write(string.format("%s\t%s\t%s\t%s\t%s\n",
                    tostring(m.start_xp or ""),
                    tostring(m.end_xp or ""),
                    matched_clean,
                    m.category or "",
                    name_clean))
            end
            f:close()
            local renamed, rename_err = os.rename(tmp_file, cache_file)
            if not renamed then
                log("saveEntityCache: rename failed: " .. tostring(rename_err))
                os.remove(tmp_file)
            end
        else
            log("saveEntityCache: failed to open cache: " .. tostring(open_err))
        end
    end)
    if not ok then
        log("saveEntityCache: unexpected error writing cache: " .. tostring(err))
        os.remove(tmp_file)
    end
end

-- ===== Scan =====

-- force: bypass the cache and rescan from scratch.
-- manual: true only when the user explicitly tapped "Scan/Rescan" - gates
-- the "N footnotes found" completion toast so automatic/background rescans
-- (triggered by a debounced data/settings change) don't pop up a toast the
-- user didn't ask for. The "Scanning book..." starting toast is unaffected;
-- it's still useful either way on a big book.
function M:scanBookForEntities(force, manual)
    if not self.ui or not self.ui.document then return end

    local settings = _settings(self)
    if settings.entity_footnotes_enabled == false then
        self:clearEntityUnderlines()
        return
    end

    if self._entity_scan_in_progress then
        -- FIX: previously this change was simply dropped. Remember that a
        -- fresh scan is still owed once the in-progress one finishes.
        self._entity_rescan_pending = true
        self._entity_rescan_pending_manual = self._entity_rescan_pending_manual or manual
        log("scanBookForEntities: scan already in progress, queuing a follow-up rescan")
        return
    end

    local resolved_sig = _getEntitySettingsSignature(self, settings)
    if not force then
        local cache_loaded = self:loadEntityCache(resolved_sig)
        if cache_loaded then
            log("scanBookForEntities: returning early due to cached hits")
            return
        end
    end

    local terms, lookup = _collectEntityTerms(self, settings)
    log("scanBookForEntities: collected " .. #terms .. " unique term(s) from "
        .. (#(self.characters or {})) .. " character(s), "
        .. (#(self.historical_figures or {})) .. " historical figure(s), "
        .. (#(self.locations or {})) .. " location(s), "
        .. (#(self.terms or {})) .. " term(s)")
    if #terms == 0 then
        -- Mark as "scanned, nothing to show" (not nil) so the paint-time check in
        -- _drawEntityUnderlines doesn't treat this as "never scanned" and rescan every repaint.
        self.entity_xp_matches = {}
        self.entity_boxes = {}
        self.entity_matches_by_page = nil
        self._entity_matches_by_page_hash = nil
        self._entity_box_cache_sig = nil
        if self.ui and self.ui.view and self.ui.view.dialog then
            UIManager:setDirty(self.ui.view.dialog, "ui")
        end
        return
    end

    self._entity_scan_in_progress = true
    local doc = self.ui.document
    local Notification = require("ui/widget/notification")

    -- Runs as a chunked background task: one regex chunk is matched per event-loop tick
    -- (scheduleIn(0, step) yields back to UIManager between chunks) instead of looping
    -- through every chunk inside a single blocking call. Unlike the unit converter, which
    -- only scans once per book open, this scan re-runs every time new entity data arrives
    -- (detected generically via the entity-list-size check in _checkEntityStateChanged,
    -- since xray.koplugin's own fetch flows are private internals we don't hook by name -
    -- see that function's comment), so it must not freeze reading/input while it works.
    local patterns = _buildChunks(terms)
    local total_patterns = math.max(1, #patterns)
    -- Keyed by end xpointer, holding the already-normalized/looked-up match record
    -- (not the raw findAllText hit). Dedup + lookup happen per-chunk in step() below
    -- instead of as two extra full-book passes at the end - this is the only table
    -- that stays alive for the whole scan, replacing what used to be three (raw hits,
    -- a dedup map, and the final array) all resident at once at scan completion.
    local xp_by_end = {}
    local idx = 0

    local function finishScan()
        local ok_finish, err_finish = pcall(function()
            local xp_matches = {}
            for _, m in pairs(xp_by_end) do
                table.insert(xp_matches, m)
            end

            self.entity_xp_matches = xp_matches
            self._entity_box_cache_sig = nil
            log("scanBookForEntities: found " .. tostring(#xp_matches) .. " entity mentions")

            local plugin = self
            self._entity_matches_by_page_hash = _getRenderingHash(doc)
            self.entity_matches_by_page = nil
            _buildMatchesByPageAsync(self, doc, xp_matches, function(by_page)
                if plugin.destroyed then return end
                plugin.entity_matches_by_page = by_page
                plugin._entity_box_cache_sig = nil
                if plugin.ui and plugin.ui.view then
                    if plugin.ui.view.dialog then UIManager:setDirty(plugin.ui.view.dialog, "ui") end
                    UIManager:setDirty(nil, "ui")
                end
            end)

            if manual then
                UIManager:show(Notification:new{
                    text = tostring(#xp_matches) .. " footnotes found",
                    timeout = 3,
                    toast = true,
                })
            end
            if self.ui and self.ui.view then
                if self.ui.view.dialog then
                    UIManager:setDirty(self.ui.view.dialog, "ui")
                end
                UIManager:setDirty(nil, "ui")
            end

            UIManager:scheduleIn(0.5, function()
                if not self.destroyed then
                    self:saveEntityCache(resolved_sig)
                end
            end)
        end)

        self._entity_scan_in_progress = false
        if not ok_finish then
            log("scanBookForEntities finish error: " .. tostring(err_finish))
        end

        -- FIX: a data/settings change that arrived while this scan was
        -- running is picked up here instead of being lost.
        if self._entity_rescan_pending then
            local was_manual = self._entity_rescan_pending_manual
            self._entity_rescan_pending = false
            self._entity_rescan_pending_manual = false
            log("scanBookForEntities: running queued follow-up rescan")
            self:scanBookForEntities(true, was_manual)
        end
    end

    local function step()
        if self.destroyed or not self.ui or not self.ui.document then
            self._entity_scan_in_progress = false
            return
        end

        idx = idx + 1
        local desc = patterns[idx]
        if not desc then
            finishScan()
            return
        end
        local pat = desc.pattern

        -- case_insensitive=false: entity names/aliases are matched in their original
        -- (proper-noun) case only, see _collectEntityTerms.
        local t0 = os.clock()
        local ok1, hits1 = pcall(function()
            return doc:findAllText(pat, false, 0, FINDALLTEXT_HIT_CAP, true)
        end)
        local dt = os.clock() - t0
        if dt > SLOW_CHUNK_SECONDS then
            log(string.format("scanBookForEntities: slow chunk %d/%d took %.2fs (%d term(s), pattern_len=%d)",
                idx, total_patterns, dt, #desc.terms, #pat))
        end

        if ok1 and hits1 then
            -- FIX: a chunk that comes back at/near the hit cap may have had
            -- later, real matches silently dropped by findAllText itself.
            -- Split this chunk's terms in half and retry with the smaller
            -- halves instead of accepting a possibly-truncated result.
            if #hits1 >= HIT_CAP_SPLIT_THRESHOLD and #desc.terms > 1 then
                local a, b = _splitChunkDescriptor(desc)
                if a and b then
                    log(string.format(
                        "scanBookForEntities: chunk %d/%d returned %d hits (near the %d cap) - splitting %d term(s) into two smaller chunks and retrying",
                        idx, total_patterns, #hits1, FINDALLTEXT_HIT_CAP, #desc.terms))
                    table.remove(patterns, idx)
                    table.insert(patterns, idx, b)
                    table.insert(patterns, idx, a)
                    total_patterns = #patterns
                    idx = idx - 1 -- retry at the same position (now the first half)
                    UIManager:scheduleIn(0, step)
                    return
                end
            end

            -- Resolve against lookup and dedupe by end xpointer immediately, per chunk,
            -- instead of stockpiling every raw hit for a single pass later. Non-matching
            -- hits (case mismatches that slipped past word boundaries, etc.) are discarded
            -- here rather than carried in memory until finishScan.
            for _, h in ipairs(hits1) do
                local matched = _normalize(h.matched_text or "")
                local entry = lookup[matched:lower()]
                if entry then
                    local end_xp = h["end"]
                    local existing = xp_by_end[end_xp]
                    if not existing or #matched > #existing.matched_text then
                        xp_by_end[end_xp] = {
                            start_xp = h.start,
                            end_xp = end_xp,
                            matched_text = matched,
                            category = entry.category,
                            entity_name = entry.canonical,
                        }
                    end
                end
            end
        elseif ok1 then
            -- FIX: hits1 == nil/false with ok1 == true just means "this chunk
            -- had zero matches", which is completely normal (most chunks in
            -- most books will have some terms with zero hits). This used to
            -- fall into the same branch as a genuinely malformed regex below,
            -- running checkRegex and logging the full pattern text as if
            -- something had gone wrong.
        else
            -- doc:checkRegex validates a pattern against crengine's own regex compiler
            -- without searching, so a mismatch between "checkRegex says fine" and
            -- "findAllText still failed" pins the failure down to the search call itself
            -- rather than the pattern being malformed.
            local regex_check = "n/a"
            if doc.checkRegex then
                local ok_chk, chk = pcall(function() return doc:checkRegex(pat) end)
                regex_check = ok_chk and tostring(chk) or ("pcall error: " .. tostring(chk))
            end
            log("scanBookForEntities: findAllText failed chunk=" .. idx .. "/" .. total_patterns
                .. " pattern_len=" .. #pat .. " checkRegex=" .. regex_check
                .. " result=" .. tostring(hits1))
            log("scanBookForEntities: failed pattern text: " .. pat)
        end

        -- Yield back to the event loop between chunks so page turns, taps, and menu
        -- input keep being processed while the scan continues in the background.
        UIManager:scheduleIn(0, step)
    end

    if total_patterns >= 3 then
        UIManager:show(Notification:new{
            text = self.loc:t("entity_scanning_book") or "Scanning book for footnotes...",
            timeout = 2,
            toast = true,
        })
    end

    UIManager:scheduleIn(0, step)
end

-- ===== Tooltip / footnote popup =====

local function _getPopupFontSize(plugin)
    local size
    if plugin and plugin.ui and plugin.ui.font and plugin.ui.font.configurable then
        size = plugin.ui.font.configurable.font_size
    elseif G_reader_settings then
        size = G_reader_settings:readSetting("cre_font_size")
              or G_reader_settings:readSetting("kopt_font_size")
    end
    if size then return size end
    if Screen.scaleBySize then
        return Screen:scaleBySize(22)
    end
    return 22
end

local function getFontSafe(preferred_family, size)
    if preferred_family and preferred_family ~= "" then
        local ok, credoc = pcall(require, "document/credocument")
        if ok and credoc and credoc.engineInit then
            local ok2, cre = pcall(credoc.engineInit, credoc)
            if ok2 and cre and cre.getFontFaceFilenameAndFaceIndex then
                local filename, faceindex = cre.getFontFaceFilenameAndFaceIndex(preferred_family)
                if not filename then
                    filename, faceindex = cre.getFontFaceFilenameAndFaceIndex(preferred_family, nil, true)
                end
                if filename then
                    local face_ok, face = pcall(Font.getFace, Font, filename, size, faceindex)
                    if face_ok and face then return face end
                end
            end
        end
    end
    return Font:getFace("cfont", size)
end

local EntityFootnote = InputContainer:extend{
    box = nil,
    entity = nil,
    category = nil,
    title_text = "",
    description_text = "",
    plugin = nil,
    timeout = 8,
    timer_fn = nil,
    _closed = false,
}

function EntityFootnote:init()
    local sw, sh = Screen:getWidth(), Screen:getHeight()
    local sc = function(n) return Screen:scaleBySize(n) end

    local fs = _getPopupFontSize(self.plugin)
    local doc_family
    if self.plugin and self.plugin.ui and self.plugin.ui.font then
        doc_family = self.plugin.ui.font.font_face
    end
    if not doc_family and G_reader_settings then
        doc_family = G_reader_settings:readSetting("cre_font_family")
    end
    local face = getFontSafe(doc_family, fs)
    local small_face = getFontSafe(doc_family, math.max(12, fs - 4))

    local pad_h = 24
    local pad_v = math.floor(fs * 0.55)
    local card_w = math.floor(math.min(sw, sh) * 0.82)
    local text_w = card_w - pad_h * 2

    local vg = VerticalGroup:new{ align = "left" }
    table.insert(vg, TextBoxWidget:new{
        text = self.title_text,
        face = face,
        width = text_w,
        bold = true,
    })

    local label = CATEGORY_LABELS[self.category]
    if label then
        table.insert(vg, VerticalSpan:new{ width = math.max(2, math.floor(fs * 0.15)) })
        table.insert(vg, TextBoxWidget:new{
            text = label,
            face = small_face,
            width = text_w,
        })
    end

    table.insert(vg, VerticalSpan:new{ width = math.max(6, math.floor(fs * 0.35)) })
    -- FIX: a long AI-generated description had no way to scroll inside the
    -- fixed-height card and would simply overflow. Cap the description box's
    -- own height and let it scroll internally if TextBoxWidget on this
    -- KOReader build supports it (it does on recent versions); on older
    -- builds this option is simply ignored and behaviour is unchanged.
    table.insert(vg, TextBoxWidget:new{
        text = self.description_text,
        face = face,
        width = text_w,
        height = math.floor(sh * 0.45),
        height_adjust = true,
        height_overflow_show_ellipsis = false,
    })

    local card = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = sc(2),
        color = Blitbuffer.COLOR_DARK_GRAY,
        radius = 0,
        padding_top = pad_v,
        padding_bottom = pad_v,
        padding_left = pad_h,
        padding_right = pad_h,
        width = card_w,
        vg,
    }

    local card_size = card:getSize()
    card_w = card_size.w
    local card_h = math.min(card_size.h, sh - sc(40))

    local margin = sc(10)
    local box = self.box
    local ref_x = box.x + box.w / 2
    local ref_bottom = box.y + box.h
    local ref_top = box.y

    local arrow_w = sc(16)
    local arrow_h = sc(8)
    local border_px = sc(2)

    local popup_x = math.max(0, math.min(sw - card_w, math.floor(ref_x - card_w / 2)))
    local popup_y
    local popup_below_word
    if ref_bottom + margin + card_h <= sh then
        popup_y = ref_bottom + margin
        popup_below_word = true
    else
        popup_y = ref_top - margin - card_h - arrow_h + border_px
        popup_below_word = false
    end

    if popup_below_word then
        popup_y = math.max(arrow_h - border_px, math.min(sh - card_h, popup_y))
    else
        popup_y = math.max(0, math.min(sh - card_h - arrow_h + border_px, popup_y))
    end
    card.overlap_offset = { popup_x, popup_y }

    local apex_min = popup_x + arrow_w / 2 + sc(4)
    local apex_max = popup_x + card_w - arrow_w / 2 - sc(4)
    local apex_x
    if apex_min <= apex_max then
        apex_x = math.max(apex_min, math.min(apex_max, ref_x))
    else
        apex_x = popup_x + card_w / 2
    end

    local arrow_x = math.floor(apex_x - arrow_w / 2)
    local arrow_y
    local arrow_dir
    if popup_below_word then
        arrow_dir = "up"
        arrow_y = popup_y - arrow_h + border_px
    else
        arrow_dir = "down"
        arrow_y = popup_y + card_h - border_px
    end

    local PointerArrowClass = self.plugin and self.plugin._PointerArrow
    local arrow
    if PointerArrowClass then
        arrow = PointerArrowClass:new{
            width = arrow_w,
            height = arrow_h,
            direction = arrow_dir,
            apex_offset = arrow_w / 2,
            border_size = border_px,
            border_color = Blitbuffer.COLOR_DARK_GRAY,
            fill_color = Blitbuffer.COLOR_WHITE,
        }
        arrow.overlap_offset = { arrow_x, arrow_y }
    end

    self.dimen = Geom:new{ x = 0, y = 0, w = sw, h = sh }
    self.ges_events = {
        TapOutside = {
            GestureRange:new{
                ges = "tap",
                range = Geom:new{ x = 0, y = 0, w = sw, h = sh }
            }
        }
    }

    -- FIX: no key-based close existed for button-only (non-touch) devices;
    -- the unit-converter-style popups elsewhere in this codebase bind
    -- AnyKeyPressed for exactly this reason.
    local Device = require("device")
    if Device:hasKeys() then
        self.key_events = self.key_events or {}
        self.key_events.AnyKeyPressed = { { Device.input.group.Any } }
    end

    local children = { dimen = Geom:new{ w = sw, h = sh }, card }
    if arrow then table.insert(children, arrow) end
    self[1] = OverlapGroup:new(children)
end

function EntityFootnote:onTapOutside()
    self:dismiss()
    return true
end

function EntityFootnote:onClose()
    self:dismiss()
    return true
end

function EntityFootnote:onAnyKeyPressed()
    self:dismiss()
    return true
end

function EntityFootnote:dismiss()
    -- FIX: UIManager:scheduleIn does not reliably return a cancellable
    -- handle across KOReader versions/backends. Keep the scheduled
    -- function itself and unschedule by reference instead of calling
    -- :cancel() on whatever scheduleIn happened to return.
    if self.timer_fn then
        UIManager:unschedule(self.timer_fn)
        self.timer_fn = nil
    end
    if not self._closed then
        self._closed = true
        UIManager:close(self)
    end
end

function EntityFootnote:onShow()
    if self.timeout and self.timeout > 0 then
        local this = self
        local fn
        fn = function()
            if this.timer_fn ~= fn then return end
            this.timer_fn = nil
            if not this._closed then
                this:dismiss()
            end
        end
        self.timer_fn = fn
        UIManager:scheduleIn(self.timeout, fn)
    end
    UIManager:setDirty(self, "ui")
    return true
end

function M:_findEntityByNameAndCategory(name, category)
    local list
    if category == "character" then list = self.characters
    elseif category == "historical_figure" then list = self.historical_figures
    elseif category == "location" then list = self.locations
    elseif category == "term" then list = self.terms
    end
    if not list then return nil end

    local lower = (name or ""):lower()
    for _, e in ipairs(list) do
        if (e.name or ""):lower() == lower then return e end
    end
    return nil
end

function M:showEntityFootnote(box)
    if not box then return end
    local entity = self:_findEntityByNameAndCategory(box.entity_name, box.category)
    if not entity then return end

    -- Always render the compact anchored tooltip card (EntityFootnote) for in-book
    -- taps, rather than the plugin's native full-screen/bottom-panel detail viewers
    -- (showCharacterDetails/showHistoricalFigureDetails/showLocationDetails/
    -- showTermDetails) that X-Ray's own menu uses. Those viewers are untouched and
    -- still used elsewhere (e.g. opening an entry from the X-Ray menu) - this only
    -- changes what happens when you tap an underlined word in the text.
    local desc
    if box.category == "term" then
        desc = entity.definition or entity.expanded
    elseif self.resolveDescriptionForPage then
        local current_page = _getCurrentPage(self)
        desc = self:resolveDescriptionForPage(entity, current_page)
    else
        desc = entity.description or entity.biography
    end
    if not desc or desc == "" or desc == "---" then
        desc = self.loc:t("entity_no_description") or "No description available yet."
    end

    local settings = _settings(self)
    local timeout = tonumber(settings.entity_tooltip_timeout) or 8

    local footnote = EntityFootnote:new{
        box = box,
        entity = entity,
        category = box.category,
        title_text = entity.name or box.matched_text or "",
        description_text = desc,
        plugin = self,
        timeout = timeout,
    }
    UIManager:show(footnote)
end

-- ===== Tap handling =====

-- Mount tap handler via monkey patching self.ui.highlight.onTap. Chains after the unit
-- converter's tap handler (if mounted), so both features can coexist without conflicting.
--
-- NOTE (not auto-fixable without knowing xray's/the unit-converter patch's tap
-- ordering): if a highlight and an entity mention overlap, whichever handler
-- runs first in this chain wins the tap. Verify this behaves as expected if
-- both patches are installed together.
function M:mountEntityTapHandler()
    if self._entityTapHandler_wrapped then return end
    local plugin = self
    local hl = self.ui and self.ui.highlight
    if not hl then return end
    local orig_tap = hl.onTap
    hl.onTap = function(hl_self, _, ges)
        if ges and plugin:_handleEntityTap(ges) then return true end
        if orig_tap then return orig_tap(hl_self, _, ges) end
    end
    self._entityTapHandler_wrapped = true
end

function M:_handleEntityTap(ges)
    local settings = _settings(self)
    if settings.entity_footnotes_enabled == false then return false end

    if not self.entity_boxes or #self.entity_boxes == 0 then
        return false
    end
    local tx, ty = ges.pos.x, ges.pos.y
    -- FIX: was a hardcoded 6px slop, unscaled for screen DPI. Scaled so the
    -- tap target is a consistent physical size across devices.
    local slop = Screen:scaleBySize(6)
    for _, box in ipairs(self.entity_boxes) do
        if tx >= box.x and tx <= box.x + box.w
        and ty >= box.y - slop and ty <= box.y + box.h + slop then
            self:showEntityFootnote(box)
            return true
        end
    end
    return false
end

-- userpatch.registerPatchPluginFunc hands us the actual, in-use plugin class table
-- (via PluginLoader:createPluginInstance) every time a new instance is about to be
-- created - this runs once per book/FileManager open, so the guard below makes sure
-- we only apply our monkey-patches to the class table once, not once per open.
userpatch.registerPatchPluginFunc("xray", function(XRayPlugin)
if XRayPlugin.__entity_footnotes_patched then return end
XRayPlugin.__entity_footnotes_patched = true

-- Apply the mixin onto the shared plugin class table, exactly like xray.koplugin's own
-- main.lua does for its built-in modules (safeRequireMixin/applyMixin).
--
-- FIX: only fill in keys that don't already exist on the class table, rather
-- than unconditionally overwriting. If a future xray.koplugin release adds
-- native support for any of this (the header links to exactly that PR),
-- this patch no longer clobbers the native implementation - it just quietly
-- stops adding the ones that now exist natively.
for k, v in pairs(M) do
    if XRayPlugin[k] == nil then
        XRayPlugin[k] = v
    else
        log("skipping mixin key '" .. tostring(k) .. "' - already defined on XRayPlugin (native support?)")
    end
end

-- Registers a Dispatcher action so "Toggle entity footnote underlines" shows up
-- in KOReader's own Gesture Manager (Settings > Taps and Gestures > Gesture
-- Manager) as an assignable action, distinct from xray.koplugin's own native
-- "X-Ray Quick Menu" gesture action (which just opens the X-Ray menu). This
-- was present in an earlier version of this patch and got dropped in a
-- later rewrite - re-added here. The event name ("ToggleEntityFootnotes")
-- must match what Dispatcher fires, which XRayPlugin:onToggleEntityFootnotes
-- (mixed in above from M) handles.
local ok_dispatcher, Dispatcher = pcall(require, "dispatcher")
if ok_dispatcher then
    local ok_gettext, gettext = pcall(require, "gettext")
    local _T = ok_gettext and gettext or function(s) return s end
    Dispatcher:registerAction("xray_entity_footnotes_toggle", {
        category = "none",
        event = "ToggleEntityFootnotes",
        title = _T("Toggle entity footnote underlines"),
        reader = true,
    })
else
    log("gesture action registration skipped: dispatcher module not available")
end

-- xray.koplugin's own Localization:t() falls back to returning the raw key string
-- itself for any key it doesn't recognize (translation = fallbacks[key] or key), never
-- nil - so the "self.loc:t(key) or english_text" pattern used throughout this patch
-- never actually falls through to our english_text. These entries get injected
-- straight into the shared translations table below so :t() finds a real value
-- before it ever reaches that fallback.
local ENTITY_FOOTNOTES_EN_STRINGS = {
    menu_entity_footnotes = "Entity Footnotes",
    entity_footnotes_enabled = "Enable Entity Footnotes",
    entity_manual_scan_button = "Scan/Rescan",
    entity_style_settings = "Style & Underline Settings",
    menu_entity_categories = "Entity Categories",
    entity_cat_characters = "Characters",
    entity_cat_historical_figures = "Historical Figures",
    entity_cat_locations = "Locations",
    entity_cat_terms = "Terms",
    entity_scanning_book = "Scanning book for footnotes...",
    entity_no_description = "No description available yet.",
    entity_footnotes_on_notify = "X-Ray Footnotes: on",
    entity_footnotes_off_notify = "X-Ray Footnotes: off",
}

-- userpatch.registerPatchPluginFunc calls the plugin's own createPluginInstance (which
-- runs :init()) BEFORE calling this patch function - so for the very first xray instance
-- created after KOReader starts, wrapping :init() below is already too late; it only
-- takes effect from the second book/instance onward within the same session. The
-- onReaderReady hook further down closes that gap (see the comment there) - the init
-- and getSubMenuItems hooks stay in place as harmless, idempotent fallbacks for anything
-- that reaches this class table without going through ReaderUI's onReaderReady event
-- (e.g. a FileManager-only instantiation). ensureEntityFootnotesSetup is the single
-- shared entry point all three hooks call into, safe to call redundantly from any or
-- all of them for the same instance.
local function ensureEntityFootnotesSetup(self)
    local ok1, err1 = pcall(function()
        -- self.loc:init() reloads self.loc.translations from scratch on every book open,
        -- so this can't be a one-time thing - it has to be redone whenever that happens.
        if not self.loc or not self.loc.translations then
            log("loc injection skipped: self.loc or self.loc.translations missing")
            return
        end
        local injected = 0
        for k, v in pairs(ENTITY_FOOTNOTES_EN_STRINGS) do
            if not self.loc.translations[k] or self.loc.translations[k] == "" then
                self.loc.translations[k] = v
                injected = injected + 1
            end
        end
        if injected > 0 then
            log("loc injection: " .. injected .. " key(s) written, current_language=" .. tostring(self.loc.current_language))
        end
    end)
    if not ok1 then log("loc injection error: " .. tostring(err1)) end

    local ok2, err2 = pcall(function()
        if self.mountEntityUnderlineOverlay then self:mountEntityUnderlineOverlay() end
        if self.mountEntityTapHandler then self:mountEntityTapHandler() end
    end)
    if not ok2 then log("mount error: " .. tostring(err2)) end

    local ok3, err3 = pcall(function()
        local settings = _settings(self)
        if self.scanBookForEntities and settings.entity_footnotes_enabled ~= false
                and not self.entity_xp_matches and not self._entity_scan_in_progress then
            self:scanBookForEntities(false, false)
        end
    end)
    if not ok3 then log("initial scan error: " .. tostring(err3)) end
end

-- Hook per-document init: covers the mount/scan/loc setup for the second book onward
-- within a session (see the comment on ensureEntityFootnotesSetup above for why the
-- very first book of a session can't rely on this alone).
local orig_init = XRayPlugin.init
function XRayPlugin:init(...)
    local ret = orig_init(self, ...)
    -- Entity Footnotes starts OFF on every book open (per user choice) - the
    -- gesture (Toggle entity footnote underlines) or the "Enable Entity
    -- Footnotes" menu checkbox turns it on for that reading session only.
    -- Ported from the earlier version of this patch, which had this
    -- behavior. This deliberately overwrites whatever entity_footnotes_enabled
    -- was last saved as, rather than persisting it across book opens.
    if self.ai_helper and self.ai_helper.settings then
        self.ai_helper.settings.entity_footnotes_enabled = false
    end
    ensureEntityFootnotesSetup(self)
    return ret
end

-- Hook onReaderReady: ReaderUI fires this once per book, strictly after the whole
-- ReaderUI/plugin-instantiation sequence for that book has completed - which means it
-- always fires *after* registerPatchPluginFunc's callback above has already patched the
-- class table, even for the very first book opened in a KOReader session. That's the
-- fix for the "nothing shows until I open the menu and scan manually" gap: previously
-- only the init hook (too early for book 1, see comment above) and the menu hook
-- (requires the user to open it) could trigger ensureEntityFootnotesSetup, so the very
-- first book never got underlines until a manual scan. This hook covers that case
-- automatically. Kept alongside the init/menu hooks rather than replacing them, since
-- onReaderReady is a ReaderUI (document-view) event and won't fire for any
-- FileManager-only instantiation of the plugin.
local orig_onReaderReady = XRayPlugin.onReaderReady
function XRayPlugin:onReaderReady(...)
    local ret
    if orig_onReaderReady then
        ret = orig_onReaderReady(self, ...)
    end
    ensureEntityFootnotesSetup(self)
    return ret
end

-- Hook the X-Ray menu: getSubMenuItems is called fresh every time the menu opens, so this
-- doesn't need to run at any particular startup phase relative to menu construction, and
-- reliably runs even for the first book of a session (see ensureEntityFootnotesSetup).
local orig_getSubMenuItems = XRayPlugin.getSubMenuItems
function XRayPlugin:getSubMenuItems(...)
    ensureEntityFootnotesSetup(self)
    local items = orig_getSubMenuItems(self, ...)
    if not items then return items end

    -- FIX: checked_func/callback below now go through _settings(self) instead
    -- of reaching into self.ai_helper.settings directly, consistent with
    -- every other settings read in this file (and nil-safe if ai_helper
    -- isn't set up yet for some reason).
    local entity_menu_entry = {
        is_entity_footnotes = true,
        text = self.loc:t("menu_entity_footnotes") or "Entity Footnotes",
        keep_menu_open = true,
        sub_item_table = {
            {
                text = self.loc:t("entity_footnotes_enabled") or "Enable Entity Footnotes",
                checked_func = function()
                    return _settings(self).entity_footnotes_enabled ~= false
                end,
                callback = function()
                    local current = _settings(self).entity_footnotes_enabled ~= false
                    self.ai_helper:saveSettings({ entity_footnotes_enabled = not current })
                    -- FIX: was scanBookForEntities(true) (force, bypassing the
                    -- cache). The cache signature already covers this
                    -- setting, so a normal call is enough and can still hit
                    -- the cache if the resulting signature matches a
                    -- previously-saved one.
                    if self.scanBookForEntities then self:scanBookForEntities(false, false) end
                end
            },
            {
                text = self.loc:t("entity_manual_scan_button") or "Scan/Rescan",
                keep_menu_open = true,
                callback = function()
                    if self.scanBookForEntities then self:scanBookForEntities(true, true) end
                end,
                separator = true,
            },
            {
                text = self.loc:t("entity_style_settings") or "Style & Underline Settings",
                keep_menu_open = true,
                callback = function()
                    self:showUnitStyleCard()
                end
            },
            {
                text = self.loc:t("menu_entity_categories") or "Entity Categories",
                keep_menu_open = true,
                sub_item_table = {
                    {
                        text = self.loc:t("entity_cat_characters") or "Characters",
                        checked_func = function()
                            return _settings(self).entity_cat_characters ~= false
                        end,
                        callback = function()
                            local curr = _settings(self).entity_cat_characters ~= false
                            self.ai_helper:saveSettings({ entity_cat_characters = not curr })
                            if self.scanBookForEntities then self:scanBookForEntities(false, false) end
                        end
                    },
                    {
                        text = self.loc:t("entity_cat_historical_figures") or "Historical Figures",
                        checked_func = function()
                            return _settings(self).entity_cat_historical_figures ~= false
                        end,
                        callback = function()
                            local curr = _settings(self).entity_cat_historical_figures ~= false
                            self.ai_helper:saveSettings({ entity_cat_historical_figures = not curr })
                            if self.scanBookForEntities then self:scanBookForEntities(false, false) end
                        end
                    },
                    {
                        text = self.loc:t("entity_cat_locations") or "Locations",
                        checked_func = function()
                            return _settings(self).entity_cat_locations ~= false
                        end,
                        callback = function()
                            local curr = _settings(self).entity_cat_locations ~= false
                            self.ai_helper:saveSettings({ entity_cat_locations = not curr })
                            if self.scanBookForEntities then self:scanBookForEntities(false, false) end
                        end
                    },
                    {
                        text = self.loc:t("entity_cat_terms") or "Terms",
                        checked_func = function()
                            return _settings(self).entity_cat_terms ~= false
                        end,
                        callback = function()
                            local curr = _settings(self).entity_cat_terms ~= false
                            self.ai_helper:saveSettings({ entity_cat_terms = not curr })
                            if self.scanBookForEntities then self:scanBookForEntities(false, false) end
                        end
                    },
                }
            },
        },
        separator = true,
    }

    table.insert(items, math.max(1, #items), entity_menu_entry)
    return items
end

-- Delete the on-disk entity cache once a book is marked "complete".
--
-- ReaderStatus (the core module behind the "reached the end - mark this book as
-- finished?" popup) does NOT fire its own event when the user taps that button -
-- it just writes summary.status = "complete" into the book's doc settings. So
-- rather than hooking a specific ReaderStatus function (whose exact name has
-- moved around between KOReader releases - it was an onXXX event handler in
-- older versions, a plain method in newer ones per koreader#12343), this reads
-- the result back from doc settings at document-close time instead, which is
-- version-independent and matches how other KOReader sync tools handle the
-- same gap.
--
-- Trigger point is onCloseDocument (every plugin registered with ReaderUI gets
-- this event, same as the onCloseDocument hook the companion quest-engine
-- patch already uses) rather than the moment the popup is answered, since
-- there's no reliable event for the latter. In practice this means: mark the
-- book finished, then close it (switch books, go back to the file browser,
-- etc.) - the cache is removed at that point. Re-checking on every close is
-- deliberately cheap and idempotent (os.remove on an already-missing file is
-- a harmless no-op), so no separate "did status just change" tracking is
-- needed.
local function _isBookMarkedComplete(self)
    local summary
    local doc_settings = self.ui and self.ui.doc_settings
    if doc_settings and doc_settings.readSetting then
        local ok, s = pcall(function() return doc_settings:readSetting("summary") end)
        if ok then summary = s end
    end
    if not summary then
        -- Fallback: doc_settings wasn't reachable off self.ui for some reason -
        -- read the sidecar straight from disk instead.
        local file = self.ui and self.ui.document and self.ui.document.file
        if file then
            local ok_ds, ds = pcall(function() return DocSettings:open(file) end)
            if ok_ds and ds then
                local ok_s, s = pcall(function() return ds:readSetting("summary") end)
                if ok_s then summary = s end
            end
        end
    end
    return type(summary) == "table" and summary.status == "complete"
end

local function _deleteCacheIfBookComplete(self)
    if not _isBookMarkedComplete(self) then return end
    local cache_file = self._getEntityCachePath and self:_getEntityCachePath()
    if not cache_file then return end
    local f = io.open(cache_file, "r")
    if not f then return end -- nothing to delete
    f:close()
    if os.remove(cache_file) then
        log("book marked complete - deleted entity cache: " .. cache_file)
    else
        log("book marked complete - failed to delete entity cache: " .. cache_file)
    end
    -- Also clear in-memory state, so if this instance somehow gets reused
    -- without a fresh :init()/onReaderReady (not expected, but cheap to be
    -- safe about) it doesn't keep serving underlines from the now-deleted data.
    self.entity_xp_matches = nil
    self.entity_boxes = nil
    self.entity_matches_by_page = nil
    self._entity_matches_by_page_hash = nil
    self._entity_box_cache_sig = nil
end

local orig_onCloseDocument_ef = XRayPlugin.onCloseDocument
function XRayPlugin:onCloseDocument(...)
    local ret
    if orig_onCloseDocument_ef then ret = orig_onCloseDocument_ef(self, ...) end
    local ok, err = pcall(_deleteCacheIfBookComplete, self)
    if not ok then log("delete-cache-on-complete error: " .. tostring(err)) end
    return ret
end

-- Hook Clear Cache: it wipes self.characters/historical_figures/locations/terms (the
-- entity lists our scan is built from) but has no idea our overlay exists, so without
-- this the underline overlay and tap targets kept showing entity mentions from the
-- book's now-discarded data until something unrelated (a settings toggle, a menu
-- reopen on the next book) happened to trigger a rescan. Also drop the on-disk entity
-- cache so a stale signature can't get reused if a later fetch happens to reproduce
-- the same entity names.
--
-- FIX: this used to run unconditionally the instant clearCache was called, which
-- is only correct if clearCache IS the confirmed action itself (not a menu
-- callback that shows its own confirm dialog first and may be cancelled).
-- Now it checks the entity list counts before/after orig_clearCache and only
-- treats it as a real clear if the lists actually became empty/changed -
-- so a cancelled confirm dialog (counts unchanged) is a no-op here too.
if XRayPlugin.clearCache then
    local orig_clearCache = XRayPlugin.clearCache
    function XRayPlugin:clearCache(...)
        local before_c = #(self.characters or {})
        local before_h = #(self.historical_figures or {})
        local before_l = #(self.locations or {})
        local before_t = #(self.terms or {})

        local ret = orig_clearCache(self, ...)

        local after_c = #(self.characters or {})
        local after_h = #(self.historical_figures or {})
        local after_l = #(self.locations or {})
        local after_t = #(self.terms or {})
        local actually_changed = (before_c ~= after_c) or (before_h ~= after_h)
            or (before_l ~= after_l) or (before_t ~= after_t)

        if actually_changed then
            self:clearEntityUnderlines()
            self.last_entity_settings_state = nil
            local cache_file = self._getEntityCachePath and self:_getEntityCachePath()
            if cache_file then pcall(os.remove, cache_file) end
        else
            log("clearCache: entity list counts unchanged after call - assuming cancelled/no-op, leaving entity cache/underlines as-is")
        end
        return ret
    end
end

log("v" .. PATCH_VERSION .. " applied to xray.koplugin class table")
end)

log("Entity Footnotes patch v" .. PATCH_VERSION .. " registered")
