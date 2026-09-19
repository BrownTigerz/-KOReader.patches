--[[--
ReadMastery - Quests & Tag Engine Patch (Phase 2: tag-based quests)
=================================================================

Drop this alongside 2-ReadMastery-notify.lua in your KOReader
`patches/` folder and restart. Independent, optional add-on - if
2-ReadMastery-notify.lua isn't installed, quest-complete popups
just fall back to a plain default box instead of your styled
notifications.

IMPORTANT: filename must start with "2-" (KOReader's patch loader
only scans specific priority prefixes - 0, 1, 2, 8, 9 - "3-7" are
not implemented and are silently never loaded).

Adds ONE new top-level menu toggle: "Quests (Enhanced)".

  OFF (default): zero overhead - the tracking hooks below do
  nothing, "View Quests" is greyed out. ReadMastery behaves
  exactly like stock.

  ON: tracks Daily / Weekly / Monthly / Seasonal quests (see list
  below) using ReadMastery's own live session data (pages/minutes/
  streak/book events) - no separate tracking system, no duplicate
  bookkeeping. On completion, awards XP through ReadMastery's own
  addXP() (so it shows up in your real XP/level, same as everything
  else), and fires a "Quest Complete" popup using the SAME styled +
  queued notification pipeline as your achievements (Full/Compact/
  Banner, your chosen font, position, duration - all of it,
  automatically, including queuing so several completions in a row
  don't overlap). If the XP happens to push you to a new level, the
  normal Level Up notification fires too.

  Turning it back OFF just pauses tracking - your daily/weekly/
  monthly/seasonal progress is kept, so switching it back on later
  resumes right where you left off. To actually reset quest
  progress, use ReadMastery's own Settings -> Reset Progress: that
  action now also clears quest state and Quest Stats in the same
  confirmed reset, alongside your level/XP/streak/achievements.
  Nothing here ever opens or writes ReadMastery's own data.json
  directly - it only hooks into that existing, already-confirmed
  reset action.

"View Quests" shows a live list with an inline progress bar per
quest (using ReadMastery's own icons.lua) - tap any quest to see
exactly what it needs and your current progress toward it.

Quests included:

  Daily (reset at local midnight): Daily Chapter (25 pages) and
  Focused Reader (20 min) are always active, plus ONE more quest
  that rotates in from a pool (chosen the same way every day, so
  it's fair over a week, not random): Deep Dive, Night Owl, First
  Light, Literary Lunch Break, Evening Escape.

  Weekly (reset Monday): Page Turner, Consistency Engine (streak),
  Close the Cover, Double Feature, Reading Marathon (single
  session), Iron Reader (single session pages), Chronicles of the
  Multiverse (tag-based pages), Expand the Mind (tag-based pages),
  Genre Explorer (finish 1 fantasy/sci-fi book).

  Monthly (reset on the 1st): Bibliophile, The Endurance Trial,
  The Brick Slayer / The Long Haul / Leviathan (finish a book of a
  given length), Lost in the Story (single session), Change of
  Scenery (finish 2 books across 2 different genres), Genre Hopper
  (finish 3 books across 3 different genres). Genre diversity tracks
  distinct finished books AND distinct genres separately, so a
  single book tagged with two genres still only counts as one
  finished book - it can't complete a "2 books" quest by itself.

  Reasoning for the split: a single matching book in a week is a
  realistic ask, but genuine multi-book genre variety needs a full
  month - so one-book genre quests live weekly, multi-book ones
  live monthly.

  Seasonal (active only during a specific month, resets fresh each
  year): Love Story in February (finish a romance-tagged book),
  Summer Reads in July (finish an adventure/thriller/romance-tagged
  book), Nightmares in Ink in October (finish a horror/gothic/
  spooky-tagged book), The Great Epic in December (finish a winter/
  epic-fantasy/classics-tagged book). Only shown in View Quests
  while actually active - no 11 months of dead entries in the list.

Tag-based quests read a book's own keywords/subject metadata (the
same thing Calibre tags usually end up in for EPUBs) once when you
open it, cached for that reading session - no scanning of the book's
actual text, no per-page cost beyond a table lookup. A book with no
usable tags simply doesn't advance tag quests; every other quest for
that book keeps working normally. Book-completion tag quests
(Genre Explorer, Change of Scenery, Genre Hopper, seasonal) are
checked once, when a book finishes - not by page count, since
"finish a book in this genre" is what they actually ask for.

Held back for a later phase: the remaining single-genre tag quests
(thriller/classics/history/biography), quest chains, wildcard
quests, and author/series quests - same reasoning as before: prove
the current set works well before stacking more on.
--]]--

local userpatch   = require("userpatch")
local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local UIManager   = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local Menu        = require("ui/widget/menu")
local Screen      = require("device").screen
local util        = require("util")

-- =================================================================
-- Settings / state (own file - ReadMastery's own data.json is
-- never opened or written by this patch)
-- =================================================================

local settings = LuaSettings:open(DataStorage:getSettingsDir() .. "/ReadMastery_quests.lua")

local Quest = {
    enabled = settings:isTrue("enabled"), -- default: false (opt-in)
    state = settings:readSetting("state") or {
        daily    = { key = nil, rotate_id = nil, progress = {} },
        weekly   = { key = nil, progress = {}, finished_paths = {} },
        monthly  = { key = nil, progress = {}, finished_paths = {} },
        seasonal = { keys = {}, progress = {} },
    },
    -- Lifetime counters only - unaffected by daily/weekly/monthly
    -- period boundaries or by the "Quests (Enhanced)" OFF toggle
    -- (that only clears in-progress state). The one exception is
    -- ReadMastery's own Reset Progress, which intentionally clears
    -- these too (see the resetProgress wrap below) - "lifetime"
    -- means "not tied to a period," not "immune to a full reset."
    -- Fixed size forever either way (one number per quest id, ~19
    -- total, plus two totals) so this never grows no matter how long
    -- the patch is used - no history log, by design.
    lifetime = settings:readSetting("lifetime") or {
        total_completed = 0,
        total_xp = 0,
        by_id = {},
    },
}

-- Migration: an existing saved state from before seasonal quests
-- existed won't have this field - add it rather than error later.
if not Quest.state.seasonal then
    Quest.state.seasonal = { keys = {}, progress = {} }
end

local function persist(flush_now)
    settings:saveSetting("enabled", Quest.enabled)
    settings:saveSetting("state", Quest.state)
    settings:saveSetting("lifetime", Quest.lifetime)
    if flush_now then
        settings:flush()
    end
end

-- Not persisted - just this session's diffing baseline, reset
-- whenever a new reading session starts.
local Runtime = { last_pages_read = 0, last_active_seconds = 0, current_book_groups = {} }

-- =================================================================
-- Quest definitions (Phase 1: no req_tag matching)
-- =================================================================

-- =================================================================
-- Genre groups (Phase 2: tag-based quests)
--
-- A book "matches" a group if its keywords metadata contains ANY of
-- these strings, exact match after lowercase/trim (no partial
-- matching). thriller/classic exist only to give the two "read from
-- N different genres" quests below more room to work with - no
-- dedicated single-genre quest for those two yet.
-- =================================================================

local GENRE_GROUPS = {
    fantasy    = { "fantasy", "epic fantasy", "high fantasy", "magic", "dark fantasy" },
    scifi      = { "sci-fi", "science fiction", "science-fiction", "cyberpunk", "space opera" },
    nonfiction = { "non-fiction", "nonfiction" },
    thriller   = { "thriller", "suspense", "mystery", "crime", "horror" },
    classic    = { "classic", "classics" },
    horror     = { "horror", "gothic", "spooky", "dark fantasy", "vampires", "ghosts" },
    winter     = { "winter", "mythology" },
    romance    = { "romance", "love story" },
    adventure  = { "adventure", "action" },
}

local DAILY_ALWAYS = {
    { id = "d_pages", title = "Daily Chapter",  type = "pages",   target = 25, reward_xp = 50 },
    { id = "d_time",  title = "Focused Reader", type = "minutes", target = 20, reward_xp = 60 },
}

local DAILY_ROTATE_POOL = {
    { id = "d_deep_dive",      title = "Deep Dive",              type = "single_session_minutes", target = 45, reward_xp = 100 },
    { id = "d_night_owl",      title = "Night Owl Reader",       type = "time_window_minutes",    target = 20, from = "21:00", to = "02:00", reward_xp = 75 },
    { id = "d_morning_reader", title = "First Light",            type = "time_window_minutes",    target = 15, from = "05:00", to = "09:00", reward_xp = 75 },
    { id = "d_lunch_reader",   title = "Literary Lunch Break",   type = "time_window_minutes",    target = 15, from = "11:00", to = "14:00", reward_xp = 60 },
    { id = "d_evening_reader", title = "Evening Escape",         type = "time_window_minutes",    target = 30, from = "18:00", to = "21:00", reward_xp = 80 },
}

local WEEKLY_QUESTS = {
    { id = "w_marathon",         title = "Page Turner",         type = "pages",                  target = 150, reward_xp = 350 },
    { id = "w_streak",           title = "Consistency Engine",  type = "streak_days",             target = 5,   reward_xp = 400 },
    { id = "w_finish_book",      title = "Close the Cover",     type = "books_finished",          target = 1,   reward_xp = 300 },
    { id = "w_two_books",        title = "Double Feature",      type = "books_finished",          target = 2,   reward_xp = 600 },
    { id = "w_marathon_session", title = "Reading Marathon",    type = "single_session_minutes",  target = 90,  reward_xp = 350 },
    { id = "w_iron_reader",      title = "Iron Reader",         type = "single_session_pages",    target = 75,  reward_xp = 450 },
    { id = "w_fantasy",   title = "Chronicles of the Multiverse", type = "tag_pages", target = 300, reward_xp = 500, tag_groups = { "fantasy" } },
    { id = "w_nonfiction", title = "Expand the Mind",             type = "tag_pages", target = 100, reward_xp = 350, tag_groups = { "nonfiction" } },
    { id = "w_genre_explorer", title = "Genre Explorer", type = "tag_book_finish", target = 1, reward_xp = 500, tag_groups = { "fantasy", "scifi" } },
}

local MONTHLY_QUESTS = {
    { id = "m_books",     title = "Bibliophile",        type = "books_finished",         target = 2,    reward_xp = 1000 },
    { id = "m_endurance", title = "The Endurance Trial", type = "minutes",                target = 1000, reward_xp = 1500 },
    { id = "m_brick",     title = "The Brick Slayer",    type = "book_min_page_count",    target = 600,  reward_xp = 1000 },
    { id = "m_long_read", title = "The Long Haul",       type = "book_min_page_count",    target = 400,  reward_xp = 600 },
    { id = "m_giant",     title = "Leviathan",           type = "book_min_page_count",    target = 800,  reward_xp = 1500 },
    { id = "m_immersion", title = "Lost in the Story",   type = "single_session_minutes", target = 120,  reward_xp = 800 },
    { id = "m_switchup",       title = "Change of Scenery", type = "tag_unique_book_finish", target = 2, reward_xp = 900 },
    { id = "m_polymath",       title = "Genre Hopper",      type = "tag_unique_book_finish", target = 3, reward_xp = 1400 },
}

-- Seasonal: active only during a specific month, resets (fresh key)
-- each year that month comes around. Only shown in View Quests while
-- actually active, so the list doesn't carry 11 months of dead
-- entries.
local SEASONAL_QUESTS = {
    { id = "s_spooky", title = "Nightmares in Ink", type = "tag_book_finish", target = 1, reward_xp = 1200, active_month = 10, tag_groups = { "horror" } },
    { id = "s_winter", title = "The Great Epic",    type = "tag_book_finish", target = 1, reward_xp = 1200, active_month = 12, tag_groups = { "fantasy", "classic", "winter" } },
    { id = "s_love",   title = "Love Story",        type = "tag_book_finish", target = 1, reward_xp = 1200, active_month = 2,  tag_groups = { "romance" } },
    { id = "s_summer", title = "Summer Reads",      type = "tag_book_finish", target = 1, reward_xp = 1200, active_month = 7,  tag_groups = { "adventure", "thriller", "romance" } },
}

local function findQuest(list, id)
    for _, q in ipairs(list) do
        if q.id == id then return q end
    end
    return nil
end

-- Plain-English "how to complete this" text, for the tap-to-detail
-- popup in View Quests.
local function describeQuest(quest)
    if quest.type == "pages" then
        return "Read " .. quest.target .. " pages."
    elseif quest.type == "minutes" then
        return "Read for a total of " .. quest.target .. " minutes."
    elseif quest.type == "time_window_minutes" then
        return "Read " .. quest.target .. " minutes with the clock between " .. quest.from .. " and " .. quest.to .. "."
    elseif quest.type == "single_session_minutes" then
        return "Keep one continuous reading session going for " .. quest.target .. " minutes (a long pause resets it)."
    elseif quest.type == "single_session_pages" then
        return "Read " .. quest.target .. " pages in one continuous session (a long pause resets it)."
    elseif quest.type == "streak_days" then
        return "Reach a " .. quest.target .. "-day reading streak."
    elseif quest.type == "books_finished" then
        return "Finish " .. quest.target .. (quest.target == 1 and " book." or " books.")
    elseif quest.type == "book_min_page_count" then
        return "Finish a single book that's at least " .. quest.target .. " pages long."
    elseif quest.type == "tag_pages" then
        return "Read " .. quest.target .. " pages in a book tagged " .. table.concat(quest.tag_groups, " or ")
               .. " (based on the book's own metadata - won't count if it isn't tagged)."
    elseif quest.type == "tag_book_finish" then
        return "Finish " .. quest.target .. (quest.target == 1 and " book" or " books")
               .. " tagged " .. table.concat(quest.tag_groups, " or ")
               .. " (based on the book's own metadata)."
    elseif quest.type == "tag_unique_book_finish" then
        return "Finish " .. quest.target .. " books, together covering " .. quest.target
               .. " different genres (based on each book's own metadata) - a single book "
               .. "tagged with multiple genres still only counts as one finished book."
    end
    return ""
end

-- =================================================================
-- Period keys / reset boundaries
-- =================================================================

local function todayKey(t)
    return os.date("%Y-%m-%d", t)
end

local function weekKey(t)
    t = t or os.time()
    local wday = tonumber(os.date("%w", t)) -- 0=Sunday..6=Saturday
    local days_since_monday = (wday == 0) and 6 or (wday - 1)
    local monday = t - (days_since_monday * 86400)
    return os.date("%Y-%m-%d", monday)
end

local function monthKey(t)
    return os.date("%Y-%m", t)
end

local function inTimeWindow(from_str, to_str, now_t)
    local function toMinutes(s)
        local h, m = s:match("(%d+):(%d+)")
        return tonumber(h) * 60 + tonumber(m)
    end
    local from_m, to_m = toMinutes(from_str), toMinutes(to_str)
    local cur_m = now_t.hour * 60 + now_t.min
    if from_m <= to_m then
        return cur_m >= from_m and cur_m < to_m
    else
        return cur_m >= from_m or cur_m < to_m -- crosses midnight
    end
end

-- Deterministic so it's fair over a week rather than random/luck
-- based, and stable for the whole day.
local function pickRotateId(now_t)
    local yday = now_t.yday or tonumber(os.date("%j"))
    local idx = (yday % #DAILY_ROTATE_POOL) + 1
    return DAILY_ROTATE_POOL[idx].id
end

local function ensurePeriod()
    local now = os.time()
    local now_t = os.date("*t", now)

    local tk = todayKey(now)
    if Quest.state.daily.key ~= tk then
        Quest.state.daily = { key = tk, rotate_id = pickRotateId(now_t), progress = {} }
    end

    local wk = weekKey(now)
    if Quest.state.weekly.key ~= wk then
        Quest.state.weekly = { key = wk, progress = {}, finished_paths = {} }
    end

    local mk = monthKey(now)
    if Quest.state.monthly.key ~= mk then
        Quest.state.monthly = { key = mk, progress = {}, finished_paths = {} }
    end

    -- Seasonal: each quest has its own independent reset key (they're
    -- active in different months), so this isn't one shared period
    -- key like the others - only reset the ones whose active month
    -- has come back around since they last reset (a fresh year).
    for _, sq in ipairs(SEASONAL_QUESTS) do
        if now_t.month == sq.active_month then
            local expected_key = tostring(now_t.year) .. "-" .. tostring(sq.active_month)
            if Quest.state.seasonal.keys[sq.id] ~= expected_key then
                Quest.state.seasonal.keys[sq.id] = expected_key
                Quest.state.seasonal.progress[sq.id] = { value = 0, completed = false }
            end
        end
    end

    return now_t
end

-- =================================================================
-- Generic progress helpers
-- =================================================================

-- Adds an amount toward a quest's target (pages, seconds, count).
-- Returns the quest def if this call just completed it.
local function addProgress(period_table, quest, amount, target_override)
    if not quest or not amount or amount <= 0 then return nil end
    local target = target_override or quest.target
    local p = period_table.progress[quest.id]
    if not p then
        p = { value = 0, completed = false }
        period_table.progress[quest.id] = p
    end
    if p.completed then return nil end
    p.value = p.value + amount
    if p.value >= target then
        p.completed = true
        return quest
    end
    return nil
end

-- Records the best/current value seen this period (for gauges like
-- "current continuous session length" or "current streak", not
-- cumulative totals). Returns the quest def if just completed.
local function checkThreshold(period_table, quest, current_value, target_override)
    if not quest or not current_value then return nil end
    local target = target_override or quest.target
    local p = period_table.progress[quest.id]
    if not p then
        p = { value = 0, completed = false }
        period_table.progress[quest.id] = p
    end
    if p.completed then return nil end
    if current_value > p.value then p.value = current_value end
    if p.value >= target then
        p.completed = true
        return quest
    end
    return nil
end

-- "Finish N books, each from a different genre" quests (Change of
-- Scenery, Genre Hopper). Called ONCE per newly-finished book (the
-- finished_paths guard upstream already ensures that), passing the
-- full set of genre-groups that ONE book matches.
--
-- Tracks two independent counts: how many distinct books have
-- contributed, and how many distinct genres have been touched by any
-- of them. Completes only when BOTH reach the target - a single
-- book tagged both fantasy AND sci-fi still only counts as ONE
-- finished book (book_count +1), even though it touches two genres;
-- it can't complete a "finish 2 books" quest by itself.
local function addCompletedBookGenreProgress(period_table, quest, book_groups)
    if not quest or not book_groups then return nil end
    local p = period_table.progress[quest.id]
    if not p then
        p = { value = 0, completed = false, book_count = 0, genres = {} }
        period_table.progress[quest.id] = p
    end
    if p.completed then return nil end

    p.book_count = p.book_count + 1
    for group_id in pairs(book_groups) do
        p.genres[group_id] = true
    end
    local genre_count = 0
    for _ in pairs(p.genres) do genre_count = genre_count + 1 end

    -- Display/progress-bar value is whichever requirement is further
    -- behind, so it reflects genuine progress toward both at once.
    p.value = math.min(p.book_count, genre_count)

    if p.book_count >= quest.target and genre_count >= quest.target then
        p.completed = true
        return quest
    end
    return nil
end

-- =================================================================
-- Patch the plugin
-- =================================================================

userpatch.registerPatchPluginFunc("ReadMastery", function(plugin)
  local ok, err = pcall(function()
    local MainMenu = require("ui/mainmenu")
    local Icons = require("icons")

    local TYPE_ICON = {
        pages = Icons.PAGE,
        minutes = Icons.CLOCK,
        time_window_minutes = Icons.CLOCK,
        single_session_minutes = Icons.LIGHTNING,
        single_session_pages = Icons.LIGHTNING,
        streak_days = Icons.FIRE,
        books_finished = Icons.BOOK,
        book_min_page_count = Icons.BOOKS,
        tag_pages = Icons.PAGE,
        tag_book_finish = Icons.BOOK,
        tag_unique_book_finish = Icons.CAT_DISCOVERY,
    }

    -- ---------------------------------------------------------------
    -- Book tag detection (Phase 2) - read once per book open, cached
    -- for the whole session. keywords is a single string that may
    -- contain multiple entries separated by newlines (how CRE
    -- aggregates EPUB <dc:subject> tags, e.g. Calibre tags). Exact
    -- match after lowercase/trim against GENRE_GROUPS, no partial
    -- matching. A book with no usable metadata just matches nothing -
    -- tag quests stay eligible-but-not-progressing for it, same as
    -- any other quest a book doesn't happen to advance.
    -- ---------------------------------------------------------------
    local function detectBookGroups(instance)
        local groups = {}
        if not (instance.ui and instance.ui.document and instance.ui.document.getProps) then
            return groups
        end
        local ok, props = pcall(function() return instance.ui.document:getProps() end)
        local raw = ok and props and props.keywords
        if not raw or raw == "" then return groups end
        for tag in raw:gmatch("[^\n]+") do
            local norm = tag:gsub("^%s+", ""):gsub("%s+$", ""):lower()
            if norm ~= "" then
                for group_id, aliases in pairs(GENRE_GROUPS) do
                    for _, alias in ipairs(aliases) do
                        if norm == alias then
                            groups[group_id] = true
                        end
                    end
                end
            end
        end
        return groups
    end

    -- ---------------------------------------------------------------
    -- Completion: award XP through ReadMastery's own addXP (so it's
    -- real XP, counted the same as everything else), pass any
    -- resulting level-up through to the normal Level Up popup, and
    -- fire our own "Quest Complete" popup via the notification
    -- patch's shared, queued render() if available, else a plain
    -- fallback.
    -- ---------------------------------------------------------------
    local function completeQuest(instance, quest)
        local level_before = instance.core and instance.core:getLevel() or nil
        if instance.core then
            instance.core:addXP(quest.reward_xp, "quest:" .. quest.id)
            instance.core:save()
        end
        local level_after = instance.core and instance.core:getLevel() or nil

        local title = Icons.TARGET .. " QUEST COMPLETE " .. Icons.TARGET
        local text = quest.title .. "\n+" .. quest.reward_xp .. " XP"

        Quest.lifetime.total_completed = Quest.lifetime.total_completed + 1
        Quest.lifetime.total_xp = Quest.lifetime.total_xp + quest.reward_xp
        Quest.lifetime.by_id[quest.id] = (Quest.lifetime.by_id[quest.id] or 0) + 1

        local bridge = _G.ReadMasteryNotify
        if bridge and bridge.render then
            bridge.render(title, text)
        else
            UIManager:show(InfoMessage:new{
                text = title .. "\n\n" .. text,
                timeout = 4,
            })
        end

        if level_after and level_before and level_after > level_before and instance.notifications then
            instance.notifications:showLevelUp(level_after, nil)
        end

        persist(true) -- flush immediately so a completion is never lost
    end

    -- ---------------------------------------------------------------
    -- Core tracking - called after ReadMastery's own onPageUpdate /
    -- onCloseDocument have already run, so instance.session already
    -- reflects the update. We only read it (diff pages/seconds), we
    -- never write to it.
    -- ---------------------------------------------------------------
    local function trackReading(instance)
        if not Quest.enabled then return end
        local session = instance.session
        if not session or not session.is_active then return end

        local now_t = ensurePeriod()

        local pages_now = session.pages_read or 0
        local secs_now  = session.active_reading_seconds or 0
        local delta_pages = pages_now - Runtime.last_pages_read
        local delta_secs  = secs_now - Runtime.last_active_seconds
        Runtime.last_pages_read = pages_now
        Runtime.last_active_seconds = secs_now
        if delta_pages < 0 then delta_pages = 0 end
        if delta_secs < 0 then delta_secs = 0 end

        local completed_list = {}
        local function note(q) if q then table.insert(completed_list, q) end end

        if delta_pages > 0 then
            note(addProgress(Quest.state.daily, findQuest(DAILY_ALWAYS, "d_pages"), delta_pages))
            note(addProgress(Quest.state.weekly, findQuest(WEEKLY_QUESTS, "w_marathon"), delta_pages))

            -- Tag-gated page quests (weekly only now) - only count
            -- toward these if the currently open book's cached genre
            -- match applies. The book-completion tag quests
            -- (Genre Explorer, Change of Scenery, Genre Hopper,
            -- seasonal) are checked in trackEndOfBook instead, since
            -- they care about whether a book gets FINISHED, not pages.
            local book_groups = Runtime.current_book_groups or {}
            local function bookMatches(quest)
                if not quest.tag_groups then return false end
                for _, g in ipairs(quest.tag_groups) do
                    if book_groups[g] then return true end
                end
                return false
            end

            local w_fantasy = findQuest(WEEKLY_QUESTS, "w_fantasy")
            if bookMatches(w_fantasy) then
                note(addProgress(Quest.state.weekly, w_fantasy, delta_pages))
            end
            local w_nonfiction = findQuest(WEEKLY_QUESTS, "w_nonfiction")
            if bookMatches(w_nonfiction) then
                note(addProgress(Quest.state.weekly, w_nonfiction, delta_pages))
            end
        end

        if delta_secs > 0 then
            local d_time = findQuest(DAILY_ALWAYS, "d_time")
            note(addProgress(Quest.state.daily, d_time, delta_secs, d_time.target * 60))

            local m_endurance = findQuest(MONTHLY_QUESTS, "m_endurance")
            note(addProgress(Quest.state.monthly, m_endurance, delta_secs, m_endurance.target * 60))

            -- Today's single rotating time-window quest, only while
            -- the clock is actually inside its window.
            local rotate_quest = findQuest(DAILY_ROTATE_POOL, Quest.state.daily.rotate_id)
            if rotate_quest and rotate_quest.type == "time_window_minutes"
               and inTimeWindow(rotate_quest.from, rotate_quest.to, now_t) then
                note(addProgress(Quest.state.daily, rotate_quest, delta_secs, rotate_quest.target * 60))
            end
        end

        -- Gauges (current continuous session, current streak) -
        -- re-checked every update, not accumulated.
        local d_deep_dive = Quest.state.daily.rotate_id == "d_deep_dive" and findQuest(DAILY_ROTATE_POOL, "d_deep_dive")
        if d_deep_dive and session.continuous_start_time then
            local continuous_secs = os.time() - session.continuous_start_time
            note(checkThreshold(Quest.state.daily, d_deep_dive, continuous_secs, d_deep_dive.target * 60))
        end

        local w_marathon_session = findQuest(WEEKLY_QUESTS, "w_marathon_session")
        if session.continuous_start_time then
            local continuous_secs = os.time() - session.continuous_start_time
            note(checkThreshold(Quest.state.weekly, w_marathon_session, continuous_secs, w_marathon_session.target * 60))
        end
        local m_immersion = findQuest(MONTHLY_QUESTS, "m_immersion")
        if session.continuous_start_time then
            local continuous_secs = os.time() - session.continuous_start_time
            note(checkThreshold(Quest.state.monthly, m_immersion, continuous_secs, m_immersion.target * 60))
        end

        local w_iron_reader = findQuest(WEEKLY_QUESTS, "w_iron_reader")
        note(checkThreshold(Quest.state.weekly, w_iron_reader, session.continuous_pages or 0))

        if instance.core then
            local w_streak = findQuest(WEEKLY_QUESTS, "w_streak")
            note(checkThreshold(Quest.state.weekly, w_streak, instance.core:getStreak() or 0))
        end

        for _, q in ipairs(completed_list) do
            completeQuest(instance, q)
        end
        persist(false) -- cheap in-memory save; disk flush happens on completion/session-end
    end

    -- ---------------------------------------------------------------
    -- Book-finished detection. ReadMastery itself has no "finished"
    -- hook today, so this adds KOReader's own real EndOfBook event
    -- fresh (chaining to ReadMastery's handler too, in case a future
    -- version adds one).
    -- ---------------------------------------------------------------
    local function trackEndOfBook(instance)
        if not Quest.enabled then return end
        ensurePeriod()
        local session = instance.session
        local path = session and session.book_path
        if not path then return end

        -- A content-based fingerprint rather than the raw path, so the
        -- same book isn't double-counted (or missed) if it exists as
        -- two files, gets renamed, or moves to a different folder -
        -- same mechanism KOReader itself uses for reading history.
        local hash_ok, book_id = pcall(function() return util.partialMD5(path) end)
        if not hash_ok or not book_id then
            book_id = path -- fall back to path if hashing fails for any reason
        end

        local page_count = nil
        if instance.ui and instance.ui.document and instance.ui.document.getPageCount then
            local ok2, count = pcall(function() return instance.ui.document:getPageCount() end)
            if ok2 then page_count = count end
        end

        local completed_list = {}
        local function note(q) if q then table.insert(completed_list, q) end end

        local book_groups = Runtime.current_book_groups or {}
        local function bookMatchesAny(quest)
            if not quest.tag_groups then return false end
            for _, g in ipairs(quest.tag_groups) do
                if book_groups[g] then return true end
            end
            return false
        end

        if not Quest.state.weekly.finished_paths[book_id] then
            Quest.state.weekly.finished_paths[book_id] = true
            note(addProgress(Quest.state.weekly, findQuest(WEEKLY_QUESTS, "w_finish_book"), 1))
            note(addProgress(Quest.state.weekly, findQuest(WEEKLY_QUESTS, "w_two_books"), 1))

            -- One-book genre completion lives at the weekly tier -
            -- finishing a single matching book in a week is a
            -- realistic ask; multi-book genre diversity (below)
            -- needs a full month.
            local w_genre_explorer = findQuest(WEEKLY_QUESTS, "w_genre_explorer")
            if bookMatchesAny(w_genre_explorer) then
                note(addProgress(Quest.state.weekly, w_genre_explorer, 1))
            end
        end
        if not Quest.state.monthly.finished_paths[book_id] then
            Quest.state.monthly.finished_paths[book_id] = true
            note(addProgress(Quest.state.monthly, findQuest(MONTHLY_QUESTS, "m_books"), 1))
            if page_count then
                -- Length tiers are mutually exclusive - a book only
                -- pays out the HIGHEST tier it qualifies for, not all
                -- three at once. An 787-page book pays Brick Slayer
                -- only; it doesn't also separately pay Long Haul.
                -- (A different, smaller book later in the same month
                -- can still independently complete a lower tier.)
                local m_giant = findQuest(MONTHLY_QUESTS, "m_giant")
                local m_brick = findQuest(MONTHLY_QUESTS, "m_brick")
                local m_long_read = findQuest(MONTHLY_QUESTS, "m_long_read")
                if page_count >= m_giant.target then
                    note(checkThreshold(Quest.state.monthly, m_giant, page_count))
                elseif page_count >= m_brick.target then
                    note(checkThreshold(Quest.state.monthly, m_brick, page_count))
                elseif page_count >= m_long_read.target then
                    note(checkThreshold(Quest.state.monthly, m_long_read, page_count))
                end
            end

            -- "Finish N books, each from a different genre" - only
            -- when this book actually matches a known genre (an
            -- untagged book can't demonstrate genre diversity). One
            -- call per quest per finished book - a book tagged both
            -- fantasy AND sci-fi still only adds 1 to book_count, it
            -- just also touches two genres in the same step.
            if next(book_groups) ~= nil then
                local m_switchup = findQuest(MONTHLY_QUESTS, "m_switchup")
                local m_polymath = findQuest(MONTHLY_QUESTS, "m_polymath")
                note(addCompletedBookGenreProgress(Quest.state.monthly, m_switchup, book_groups))
                note(addCompletedBookGenreProgress(Quest.state.monthly, m_polymath, book_groups))
            end

            -- Seasonal - only checked during the quest's active month
            -- (ensurePeriod already made sure its progress entry is
            -- fresh for this year if so).
            local now_t = os.date("*t")
            for _, sq in ipairs(SEASONAL_QUESTS) do
                if now_t.month == sq.active_month and bookMatchesAny(sq) then
                    note(addProgress(Quest.state.seasonal, sq, 1))
                end
            end
        end

        for _, q in ipairs(completed_list) do
            completeQuest(instance, q)
        end
        persist(true)
    end

    -- ---------------------------------------------------------------
    -- View Quests - fancy-ish list: icon + inline ASCII progress bar
    -- per quest, grouped by period. Tap any quest for a plain-
    -- English explanation of what it needs and your current progress.
    -- ---------------------------------------------------------------
    local function displayValue(quest, raw_value)
        if quest.type == "minutes" or quest.type == "time_window_minutes" or quest.type == "single_session_minutes" then
            return math.floor(raw_value / 60)
        end
        return raw_value
    end

    local function formatLine(quest, progress)
        local val = progress and progress.value or 0
        local done = progress and progress.completed
        local shown_val = displayValue(quest, val)
        local icon = TYPE_ICON[quest.type] or Icons.TARGET
        local pct = done and 100 or math.min(100, math.floor((shown_val / quest.target) * 100))
        local bar = Icons.progressBar(pct, 10)
        local status = done and (Icons.CHECK .. " DONE") or (shown_val .. "/" .. quest.target)
        return icon .. " " .. quest.title .. "  " .. bar .. " " .. status
    end

    local function showQuestDetail(quest, progress)
        if not quest then
            UIManager:show(InfoMessage:new{ text = "Quest details are unavailable.", timeout = 3 })
            return
        end

        local val = progress and tonumber(progress.value) or 0
        local done = progress and progress.completed == true
        local shown_val = displayValue(quest, val)
        local status = done and "Complete!" or (tostring(shown_val) .. " / " .. tostring(quest.target))
        local text = tostring(quest.title) .. "\n\n" .. tostring(describeQuest(quest))
                     .. "\n\nProgress: " .. status
                     .. "\nReward: +" .. tostring(quest.reward_xp) .. " XP"

        -- keep_menu_open on the row (below) means the list never closes
        -- on tap, so there's no race against a fullscreen menu tearing
        -- itself down - safe to show this synchronously, no deferral
        -- needed. Still pcall-wrapped so a bad popup surfaces its real
        -- error instead of silently doing nothing.
        local ok, err = pcall(function()
            UIManager:show(InfoMessage:new{ text = text })
        end)
        if not ok then
            UIManager:show(InfoMessage:new{
                text = "Quest detail error:\n\n" .. tostring(err),
                timeout = 8,
            })
        end
    end

    local function questItem(quest, progress)
        return {
            text = formatLine(quest, progress),
            keep_menu_open = true,
            callback = function() showQuestDetail(quest, progress) end,
        }
    end

    local function buildQuestListItems()
        ensurePeriod()
        local items = {}

        table.insert(items, { text = Icons.CALENDAR .. " -- Daily --", bold = true, select_enabled = false })
        table.insert(items, questItem(findQuest(DAILY_ALWAYS, "d_pages"), Quest.state.daily.progress["d_pages"]))
        table.insert(items, questItem(findQuest(DAILY_ALWAYS, "d_time"), Quest.state.daily.progress["d_time"]))
        local rotate_quest = findQuest(DAILY_ROTATE_POOL, Quest.state.daily.rotate_id)
        if rotate_quest then
            table.insert(items, questItem(rotate_quest, Quest.state.daily.progress[rotate_quest.id]))
        end

        table.insert(items, { text = Icons.CHART .. " -- Weekly --", bold = true, select_enabled = false })
        for _, q in ipairs(WEEKLY_QUESTS) do
            table.insert(items, questItem(q, Quest.state.weekly.progress[q.id]))
        end

        table.insert(items, { text = Icons.TROPHY .. " -- Monthly --", bold = true, select_enabled = false })
        for _, q in ipairs(MONTHLY_QUESTS) do
            table.insert(items, questItem(q, Quest.state.monthly.progress[q.id]))
        end

        -- Seasonal - only shown during its active month, so the list
        -- doesn't carry 11 months of dead entries.
        local now_t = os.date("*t")
        local active_seasonal = {}
        for _, sq in ipairs(SEASONAL_QUESTS) do
            if now_t.month == sq.active_month then
                table.insert(active_seasonal, sq)
            end
        end
        if #active_seasonal > 0 then
            table.insert(items, { text = Icons.SNOWFLAKE .. " -- Seasonal --", bold = true, select_enabled = false })
            for _, sq in ipairs(active_seasonal) do
                table.insert(items, questItem(sq, Quest.state.seasonal.progress[sq.id]))
            end
        end

        return items
    end

    local function showQuestList()
        local menu = Menu:new{
            title = "Quests (tap one for details)",
            item_table = buildQuestListItems(),
            width = Screen:getWidth(),
            height = Screen:getHeight(),
            covers_fullscreen = true,
            is_borderless = true,
            is_popout = false,
        }
        menu.close_callback = function()
            UIManager:close(menu)
        end
        UIManager:show(menu)
    end

    -- ---------------------------------------------------------------
    -- Quest Stats - lifetime totals. Unaffected by daily/weekly/
    -- monthly resets or by turning "Quests (Enhanced)" off; only
    -- ReadMastery's own Reset Progress clears these.
    -- ---------------------------------------------------------------
    local function buildQuestStatsItems()
        local items = {}
        table.insert(items, {
            text = Icons.TROPHY .. " Lifetime: " .. Quest.lifetime.total_completed
                   .. " quests completed, " .. Quest.lifetime.total_xp .. " XP earned",
            bold = true,
            select_enabled = false,
        })

        local function addSection(label, list)
            table.insert(items, { text = label, bold = true, select_enabled = false })
            for _, q in ipairs(list) do
                local count = Quest.lifetime.by_id[q.id] or 0
                local icon = TYPE_ICON[q.type] or Icons.TARGET
                table.insert(items, {
                    text = icon .. " " .. q.title .. "  -  " .. count .. "x",
                    select_enabled = false,
                })
            end
        end

        addSection(Icons.CALENDAR .. " -- Daily --", DAILY_ALWAYS)
        addSection("   (rotating)", DAILY_ROTATE_POOL)
        addSection(Icons.CHART .. " -- Weekly --", WEEKLY_QUESTS)
        addSection(Icons.BOOKS .. " -- Monthly --", MONTHLY_QUESTS)
        addSection(Icons.SNOWFLAKE .. " -- Seasonal --", SEASONAL_QUESTS)

        return items
    end

    local function showQuestStats()
        local menu = Menu:new{
            title = "Quest Stats",
            item_table = buildQuestStatsItems(),
            width = Screen:getWidth(),
            height = Screen:getHeight(),
            covers_fullscreen = true,
            is_borderless = true,
            is_popout = false,
        }
        menu.close_callback = function()
            UIManager:close(menu)
        end
        UIManager:show(menu)
    end

    -- ---------------------------------------------------------------
    -- Install reading hooks directly on the plugin class - `plugin`
    -- here (registerPatchPluginFunc's argument) IS ReadMastery's own
    -- class table (confirmed against pluginloader.lua: it's exactly
    -- what main.lua's methods like `function ReadMastery:onPageUpdate`
    -- are defined on), so patching it here applies immediately and
    -- directly, the same way the notification patch already reliably
    -- patches Notifications/MainMenu.
    --
    -- Guarded on the class itself (not a local flag) since this
    -- callback re-fires on every plugin instantiation (every new
    -- book/file manager open) but must only wrap each method once.
    -- ---------------------------------------------------------------
    if not plugin._readmastery_quest_hooks_installed then
        plugin._readmastery_quest_hooks_installed = true

        if plugin.onPageUpdate then
            local orig_onPageUpdate = plugin.onPageUpdate
            plugin.onPageUpdate = function(instance, page)
                local ret = orig_onPageUpdate(instance, page)
                trackReading(instance)
                return ret
            end
        end

        if plugin.onCloseDocument then
            local orig_onCloseDocument = plugin.onCloseDocument
            plugin.onCloseDocument = function(instance, ...)
                local ret = orig_onCloseDocument(instance, ...)
                trackReading(instance)
                return ret
            end
        end

        do
            local orig_onReaderReady = plugin.onReaderReady
            plugin.onReaderReady = function(instance, ...)
                local ret
                if orig_onReaderReady then ret = orig_onReaderReady(instance, ...) end
                Runtime.last_pages_read = 0
                Runtime.last_active_seconds = 0
                Runtime.current_book_groups = detectBookGroups(instance)
                return ret
            end
        end

        do
            -- ReadMastery has no onEndOfBook of its own today; this adds
            -- it fresh (and still chains to one if a future version adds it).
            local orig_onEndOfBook = plugin.onEndOfBook
            plugin.onEndOfBook = function(instance, ...)
                local ret
                if orig_onEndOfBook then ret = orig_onEndOfBook(instance, ...) end
                trackEndOfBook(instance)
                return ret
            end
        end

        if plugin.resetProgress then
            -- Piggyback on ReadMastery's own Reset Progress (Settings),
            -- which already has its own confirmation dialog - one
            -- reset action clears everything, quests included, rather
            -- than needing a second separate reset flow.
            local orig_resetProgress = plugin.resetProgress
            plugin.resetProgress = function(instance, ...)
                local ret = orig_resetProgress(instance, ...)
                Quest.state = {
                    daily    = { key = nil, rotate_id = nil, progress = {} },
                    weekly   = { key = nil, progress = {}, finished_paths = {} },
                    monthly  = { key = nil, progress = {}, finished_paths = {} },
                    seasonal = { keys = {}, progress = {} },
                }
                Quest.lifetime = {
                    total_completed = 0,
                    total_xp = 0,
                    by_id = {},
                }
                -- Re-sync the diffing baseline to whatever the CURRENT
                -- session counters actually are (if a book is open),
                -- instead of zeroing blindly. ReadMastery's own reset
                -- doesn't touch the live session object, so blindly
                -- zeroing here made the very next page turn compute a
                -- delta against the session's already-accumulated
                -- total instead of just the new pages - e.g. reading
                -- 38 pages, then resetting, then turning one more page,
                -- incorrectly counted all 38+ as a single delta.
                if instance.session then
                    Runtime.last_pages_read = instance.session.pages_read or 0
                    Runtime.last_active_seconds = instance.session.active_reading_seconds or 0
                else
                    Runtime.last_pages_read = 0
                    Runtime.last_active_seconds = 0
                end
                persist(true)
                return ret
            end
        end
    end

    -- ---------------------------------------------------------------
    -- Inject "Quests (Enhanced)" + "View Quests" into the same
    -- top-level menu the notification patch adds "Settings" items
    -- alongside (guarded separately from the hooks above, since
    -- MainMenu.getMenuTable only needs wrapping once, ever).
    -- ---------------------------------------------------------------
    if not MainMenu._readmastery_quests_menu_patched then
        MainMenu._readmastery_quests_menu_patched = true
        local orig_getMenuTable = MainMenu.getMenuTable
        MainMenu.getMenuTable = function(self)
            local items = orig_getMenuTable(self)

            -- Pull "Achievements" out of its original spot so it can
            -- sit right alongside our own quest items instead.
            local achievements_item = nil
            local remaining = {}
            for _, it in ipairs(items) do
                if it.text == "Achievements" and not achievements_item then
                    achievements_item = it
                else
                    table.insert(remaining, it)
                end
            end

            local extra = {
                {
                    text = "Quests (Enhanced)",
                    checked_func = function() return Quest.enabled end,
                    callback = function()
                        -- OFF just pauses tracking - progress is kept
                        -- so turning it back on later resumes cleanly.
                        -- To actually reset quest progress, use
                        -- ReadMastery's own Settings -> Reset Progress,
                        -- which now also clears quest state and Quest
                        -- Stats in that same action.
                        Quest.enabled = not Quest.enabled
                        if Quest.enabled then
                            -- Re-sync the diffing baseline to the
                            -- CURRENT session (if a book is already
                            -- open) rather than leaving it wherever it
                            -- was left off - otherwise turning this on
                            -- mid-session would count the whole
                            -- session-so-far as one big delta on the
                            -- next page turn, same bug as Reset
                            -- Progress had.
                            local session = self.plugin and self.plugin.session
                            if session then
                                Runtime.last_pages_read = session.pages_read or 0
                                Runtime.last_active_seconds = session.active_reading_seconds or 0
                            end
                        end
                        persist(true)
                    end,
                    keep_menu_open = true,
                },
                {
                    text = "View Quests",
                    enabled_func = function() return Quest.enabled end,
                    keep_menu_open = true,
                    callback = function()
                        showQuestList()
                    end,
                },
            }
            if achievements_item then
                table.insert(extra, achievements_item)
            end
            table.insert(extra, {
                text = "Quest Stats",
                keep_menu_open = true,
                callback = function()
                    showQuestStats()
                end,
            })

            local combined = {}
            for _, it in ipairs(extra) do table.insert(combined, it) end
            for _, it in ipairs(remaining) do table.insert(combined, it) end
            return combined
        end
    end
  end)
  if not ok then
      UIManager:show(InfoMessage:new{
          text = "ReadMastery Quests patch failed to load:\n" .. tostring(err),
          timeout = 8,
      })
  end
end)
